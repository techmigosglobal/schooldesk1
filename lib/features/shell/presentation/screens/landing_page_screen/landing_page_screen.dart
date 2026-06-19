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
        child: LayoutBuilder(
          builder: (context, constraints) {
            final topBandHeight = (constraints.maxHeight * 0.17).clamp(
              108.0,
              152.0,
            );
            final footerBandHeight = (constraints.maxHeight * 0.13).clamp(
              90.0,
              128.0,
            );

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  children: [
                    SizedBox(
                      height: topBandHeight,
                      child: _LandingHeader(
                        activeIndex: _activeSlide,
                        itemCount: _slideAssets.length,
                        onSignIn: _openLogin,
                      ),
                    ),
                    Expanded(
                      child: Stack(
                        children: [
                          NotificationListener<ScrollNotification>(
                            onNotification: (notification) {
                              if (notification is ScrollStartNotification) {
                                _pauseAutoSlide();
                              } else if (notification
                                  is ScrollEndNotification) {
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
                                return _ArtworkSlide(
                                  assetPath: _slideAssets[index],
                                );
                              },
                            ),
                          ),
                          _ArtworkHotspots(
                            onPrevious: () => _goToSlide(
                              (_activeSlide - 1 + _slideAssets.length) %
                                  _slideAssets.length,
                              manual: true,
                            ),
                            onNext: () => _goToSlide(
                              (_activeSlide + 1) % _slideAssets.length,
                              manual: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: footerBandHeight,
                      child: _LandingFooter(
                        onToggleAutoSlide: _reduceMotion
                            ? null
                            : _toggleAutoSlide,
                        isAutoSlidePaused:
                            _reduceMotion || _autoSlidePausedByUser,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _LandingHeader extends StatelessWidget {
  const _LandingHeader({
    required this.activeIndex,
    required this.itemCount,
    required this.onSignIn,
  });

  final int activeIndex;
  final int itemCount;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isCompact = width < 380;
        final logoHeight = isCompact ? 50.0 : 58.0;
        final sideInset = isCompact ? 12.0 : 20.0;

        return Stack(
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: EdgeInsets.only(top: isCompact ? 8 : 12),
                child: Image.asset(
                  'assets/images/header.png',
                  height: logoHeight,
                  fit: BoxFit.contain,
                  semanticLabel: 'SchoolDesk branding',
                ),
              ),
            ),
            Positioned(
              left: sideInset,
              right: sideInset,
              top: isCompact ? 72 : 78,
              child: _SlidePositionIndicator(
                activeIndex: activeIndex,
                itemCount: itemCount,
              ),
            ),
            Positioned(
              right: sideInset,
              top: isCompact ? 58 : 64,
              child: _SignInButton(onPressed: onSignIn),
            ),
          ],
        );
      },
    );
  }
}

class _SignInButton extends StatelessWidget {
  const _SignInButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Sign in',
      child: Material(
        color: context.appTheme.primary,
        borderRadius: BorderRadius.circular(24),
        elevation: 3,
        shadowColor: context.appTheme.primary.withAlpha(70),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48, minWidth: 84),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.login_rounded,
                    size: 16,
                    color: context.appTheme.onPrimary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Sign in',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: context.appTheme.onPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LandingFooter extends StatelessWidget {
  const _LandingFooter({
    required this.onToggleAutoSlide,
    required this.isAutoSlidePaused,
  });

  final VoidCallback? onToggleAutoSlide;
  final bool isAutoSlidePaused;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 380;
        final footerHeight = isCompact ? 34.0 : 40.0;

        return Stack(
          children: [
            if (onToggleAutoSlide != null)
              Positioned(
                right: isCompact ? 12 : 20,
                top: isCompact ? 4 : 8,
                child: _PauseButton(
                  isAutoSlidePaused: isAutoSlidePaused,
                  onPressed: onToggleAutoSlide!,
                ),
              ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.only(bottom: isCompact ? 10 : 14),
                child: Image.asset(
                  'assets/images/footer.png',
                  height: footerHeight,
                  fit: BoxFit.contain,
                  semanticLabel: 'SchoolDesk footer',
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PauseButton extends StatelessWidget {
  const _PauseButton({
    required this.isAutoSlidePaused,
    required this.onPressed,
  });

  final bool isAutoSlidePaused;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      tooltip: isAutoSlidePaused ? 'Resume carousel' : 'Pause carousel',
      onPressed: onPressed,
      style: IconButton.styleFrom(
        fixedSize: const Size.square(44),
        backgroundColor: context.appTheme.surface.withAlpha(225),
        foregroundColor: context.appTheme.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      icon: Icon(
        isAutoSlidePaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
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
        final maxPosterWidth = constraints.maxHeight * _kPosterAspectRatio;
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
  const _ArtworkHotspots({required this.onPrevious, required this.onNext});

  final VoidCallback onPrevious;
  final VoidCallback onNext;

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
    return Semantics(
      label: 'Slide ${activeIndex + 1} of $itemCount',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(itemCount, (index) {
          final isActive = index == activeIndex;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.symmetric(horizontal: 12),
            width: isActive ? 10 : 9,
            height: isActive ? 10 : 9,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive
                  ? context.appTheme.primary
                  : context.appTheme.outlineVariant.withAlpha(150),
            ),
          );
        }),
      ),
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

/// Target width-to-height ratio for the poster frame.
/// Chosen to accommodate all slide images (ratios 0.68–0.72)
/// while keeping a consistent page size for the carousel.
const double _kPosterAspectRatio = 0.70;

Rect _posterFrameFor(Size size) {
  final posterWidth = size.width < size.height * _kPosterAspectRatio
      ? size.width
      : size.height * _kPosterAspectRatio;
  final posterHeight = posterWidth / _kPosterAspectRatio;
  return Rect.fromLTWH(
    (size.width - posterWidth) / 2,
    (size.height - posterHeight) / 2,
    posterWidth,
    posterHeight,
  );
}
