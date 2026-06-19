import 'dart:async';

import 'package:flutter/material.dart';

import 'package:schooldesk1/core/utils/extensions.dart';
import 'package:schooldesk1/routes/app_routes.dart';

class LandingPageScreen extends StatefulWidget {
  const LandingPageScreen({super.key});

  @override
  State<LandingPageScreen> createState() => _LandingPageScreenState();
}

class _LandingPageScreenState extends State<LandingPageScreen> {
  static const Duration _autoSlideInterval = Duration(seconds: 7);
  static const Duration _slideAnimationDuration = Duration(milliseconds: 520);
  static const List<String> _slideAssets = [
    'assets/images/landing_slide_1.png',
    'assets/images/landing_slide_2.png',
    'assets/images/landing_slide_3.png',
    'assets/images/landing_slide_4.png',
    'assets/images/landing_slide_5.png',
    'assets/images/landing_slide_6.png',
  ];

  late final PageController _controller;
  Timer? _autoSlideTimer;
  int _activeSlide = 0;
  bool _autoSlidePausedByUser = false;
  bool _autoSlidePausedByTouch = false;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    for (final asset in _slideAssets) {
      precacheImage(AssetImage(asset), context);
    }
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion == reduceMotion && _autoSlideTimer != null) return;
    _reduceMotion = reduceMotion;
    if (_reduceMotion) {
      _stopAutoSlideTimer();
    } else {
      _restartAutoSlideTimer();
    }
  }

  @override
  void dispose() {
    _stopAutoSlideTimer();
    _controller.dispose();
    super.dispose();
  }

  void _stopAutoSlideTimer() {
    _autoSlideTimer?.cancel();
    _autoSlideTimer = null;
  }

  void _restartAutoSlideTimer() {
    _stopAutoSlideTimer();
    if (_reduceMotion || _autoSlidePausedByUser || _autoSlidePausedByTouch) {
      return;
    }
    _autoSlideTimer = Timer.periodic(_autoSlideInterval, (_) {
      if (!mounted || !_controller.hasClients) return;
      final next = (_activeSlide + 1) % _slideAssets.length;
      _goToSlide(next);
    });
  }

  void _pauseAutoSlide({bool fromUser = false}) {
    if (fromUser) {
      setState(() => _autoSlidePausedByUser = true);
    } else {
      _autoSlidePausedByTouch = true;
    }
    _stopAutoSlideTimer();
  }

  void _resumeAutoSlide({bool fromUser = false}) {
    if (fromUser) {
      setState(() => _autoSlidePausedByUser = false);
    } else {
      _autoSlidePausedByTouch = false;
    }
    _restartAutoSlideTimer();
  }

  void _toggleAutoSlide() {
    if (_autoSlidePausedByUser) {
      _resumeAutoSlide(fromUser: true);
    } else {
      _pauseAutoSlide(fromUser: true);
    }
  }

  void _goToSlide(int index, {bool manual = false}) {
    if (!_controller.hasClients || index == _activeSlide) {
      if (manual) _restartAutoSlideTimer();
      return;
    }
    if (manual) _restartAutoSlideTimer();
    _controller.animateToPage(
      index,
      duration: _reduceMotion ? Duration.zero : _slideAnimationDuration,
      curve: Curves.easeOutCubic,
    );
  }

  void _openLogin() {
    Navigator.pushNamed(context, AppRoutes.principalLogin);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAF6FF),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Stack(
              children: [
                NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (notification is ScrollStartNotification) {
                      _pauseAutoSlide();
                    } else if (notification is ScrollEndNotification) {
                      _resumeAutoSlide();
                    }
                    return false;
                  },
                  child: PageView.builder(
                    controller: _controller,
                    onPageChanged: (index) =>
                        setState(() => _activeSlide = index),
                    itemCount: _slideAssets.length,
                    itemBuilder: (context, index) {
                      return _ArtworkSlide(assetPath: _slideAssets[index]);
                    },
                  ),
                ),
                _ArtworkHotspots(
                  onLogin: _openLogin,
                  onPrevious: () => _goToSlide(
                    (_activeSlide - 1 + _slideAssets.length) %
                        _slideAssets.length,
                    manual: true,
                  ),
                  onNext: () => _goToSlide(
                    (_activeSlide + 1) % _slideAssets.length,
                    manual: true,
                  ),
                  onToggleAutoSlide: _reduceMotion ? null : _toggleAutoSlide,
                  isAutoSlidePaused: _reduceMotion || _autoSlidePausedByUser,
                ),
                _SlidePositionIndicator(
                  activeIndex: _activeSlide,
                  itemCount: _slideAssets.length,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ArtworkSlide extends StatelessWidget {
  const _ArtworkSlide({required this.assetPath});

  final String assetPath;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxPosterWidth = constraints.maxHeight * (941 / 1672);
        final posterWidth = constraints.maxWidth < maxPosterWidth
            ? constraints.maxWidth
            : maxPosterWidth;

        return Center(
          child: SizedBox(
            width: posterWidth,
            height: constraints.maxHeight,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                assetPath,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
                semanticLabel: 'School landing artwork',
                errorBuilder: (context, error, stackTrace) =>
                    const _ArtworkFallback(),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ArtworkHotspots extends StatelessWidget {
  const _ArtworkHotspots({
    required this.onLogin,
    required this.onPrevious,
    required this.onNext,
    required this.onToggleAutoSlide,
    required this.isAutoSlidePaused,
  });

  final VoidCallback onLogin;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback? onToggleAutoSlide;
  final bool isAutoSlidePaused;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final frame = _posterFrameFor(constraints.biggest);
        final left = frame.left;
        final top = frame.top;
        final width = frame.width;
        final height = frame.height;

        return Stack(
          children: [
            _ArtworkHotspot(
              label: 'Artwork login',
              tooltip: 'Login',
              onTap: onLogin,
              rect: Rect.fromLTWH(
                left + (width * 0.68),
                top + (height * 0.065),
                width * 0.2,
                height * 0.055,
              ),
            ),
            _ArtworkHotspot(
              label: 'Previous slide',
              tooltip: 'Previous',
              onTap: onPrevious,
              rect: Rect.fromLTWH(
                left + (width * 0.19),
                top + (height * 0.88),
                width * 0.12,
                height * 0.075,
              ),
            ),
            _ArtworkHotspot(
              label: 'Next slide',
              tooltip: 'Next',
              onTap: onNext,
              rect: Rect.fromLTWH(
                left + (width * 0.68),
                top + (height * 0.88),
                width * 0.12,
                height * 0.075,
              ),
            ),
            if (onToggleAutoSlide != null)
              Positioned(
                right: 12,
                bottom: 12,
                child: IconButton.filledTonal(
                  tooltip: isAutoSlidePaused
                      ? 'Resume carousel'
                      : 'Pause carousel',
                  onPressed: onToggleAutoSlide,
                  icon: Icon(
                    isAutoSlidePaused
                        ? Icons.play_arrow_rounded
                        : Icons.pause_rounded,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ArtworkHotspot extends StatelessWidget {
  const _ArtworkHotspot({
    required this.label,
    required this.tooltip,
    required this.onTap,
    required this.rect,
  });

  final String label;
  final String tooltip;
  final VoidCallback onTap;
  final Rect rect;

  @override
  Widget build(BuildContext context) {
    return Positioned.fromRect(
      rect: rect,
      child: Semantics(
        button: true,
        label: label,
        child: Tooltip(
          message: tooltip,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: onTap,
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
  }
}

class _SlidePositionIndicator extends StatelessWidget {
  const _SlidePositionIndicator({
    required this.activeIndex,
    required this.itemCount,
  });

  final int activeIndex;
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final frame = _posterFrameFor(constraints.biggest);
        return Positioned(
          left: frame.left + (frame.width * 0.38),
          right: frame.left + (frame.width * 0.38),
          bottom: constraints.maxHeight - frame.bottom + (frame.height * 0.067),
          child: Semantics(
            label: 'Slide ${activeIndex + 1} of $itemCount',
            child: SizedBox(
              height: 14,
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(
                      itemCount,
                      (_) => Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: context.appTheme.outlineVariant.withAlpha(170),
                        ),
                      ),
                    ),
                  ),
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    left: itemCount <= 1
                        ? 0
                        : activeIndex *
                              ((frame.width * 0.24 - 9) / (itemCount - 1)),
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: context.appTheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ArtworkFallback extends StatelessWidget {
  const _ArtworkFallback();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.appTheme.surface,
      child: Center(
        child: Text(
          'Landing artwork unavailable',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
    );
  }
}

Rect _posterFrameFor(Size size) {
  final posterWidth = size.width < size.height * (941 / 1672)
      ? size.width
      : size.height * (941 / 1672);
  final posterHeight = posterWidth * (1672 / 941);
  return Rect.fromLTWH(
    (size.width - posterWidth) / 2,
    (size.height - posterHeight) / 2,
    posterWidth,
    posterHeight,
  );
}
