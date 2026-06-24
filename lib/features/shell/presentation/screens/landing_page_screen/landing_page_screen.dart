import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    HapticFeedback.lightImpact();
    Navigator.pushNamed(context, AppRoutes.principalLogin);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isSmall = size.width < 400;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFEBF5FF),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Column(
                    children: [
                      // ── TOP HEADER ──────────────────────────────────────
                      _LandingHeader(onSignIn: _openLogin, isSmall: isSmall),
                      // ── SLIDE CAROUSEL ──────────────────────────────────
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: isSmall ? 8 : 16,
                          ),
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
                      ),
                      // ── BOTTOM FOOTER ───────────────────────────────────
                      _LandingFooter(
                        activeIndex: _activeSlide,
                        itemCount: _slideAssets.length,
                        onToggleAutoSlide: _reduceMotion
                            ? null
                            : _toggleAutoSlide,
                        isAutoSlidePaused:
                            _reduceMotion || _autoSlidePausedByUser,
                        isSmall: isSmall,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header — single clean bar with logo left, sign-in right
// ─────────────────────────────────────────────────────────────────────────────

class _LandingHeader extends StatelessWidget {
  const _LandingHeader({required this.onSignIn, required this.isSmall});

  final VoidCallback onSignIn;
  final bool isSmall;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.fromLTRB(isSmall ? 8 : 16, 10, isSmall ? 8 : 16, 8),
      padding: EdgeInsets.symmetric(horizontal: isSmall ? 10 : 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1565C0).withAlpha(18),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Logo
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset(
              'assets/branding/ArishVilleLogo.png',
              height: isSmall ? 44 : 52,
              width: isSmall ? 44 : 52,
              fit: BoxFit.cover,
              semanticLabel: 'School logo',
            ),
          ),
          const SizedBox(width: 10),
          // School name
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Arish Ville Preschool',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: isSmall ? 15 : 17,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0D1B2A),
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  'Learn Today, Lead Tomorrow',
                  style: TextStyle(
                    fontSize: isSmall ? 10 : 11,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF1565C0).withAlpha(180),
                  ),
                ),
              ],
            ),
          ),
          // Sign In button
          const SizedBox(width: 8),
          _SignInButton(
            key: const Key('sign_in_button'),
            onPressed: onSignIn,
            isSmall: isSmall,
          ),
        ],
      ),
    );
  }
}

class _SignInButton extends StatelessWidget {
  const _SignInButton({
    required this.onPressed,
    required this.isSmall,
    super.key,
  });

  final VoidCallback onPressed;
  final bool isSmall;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Sign in to Arish Ville',
      child: Material(
        color: const Color(0xFF1565C0),
        borderRadius: BorderRadius.circular(12),
        elevation: 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onPressed,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isSmall ? 12 : 16,
              vertical: isSmall ? 9 : 11,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.login_rounded,
                  size: isSmall ? 15 : 16,
                  color: Colors.white,
                ),
                const SizedBox(width: 5),
                Text(
                  'Sign in',
                  style: TextStyle(
                    fontSize: isSmall ? 12 : 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Footer — dots centre, pause left, Techmigos brand right
// ─────────────────────────────────────────────────────────────────────────────

class _LandingFooter extends StatelessWidget {
  const _LandingFooter({
    required this.activeIndex,
    required this.itemCount,
    required this.onToggleAutoSlide,
    required this.isAutoSlidePaused,
    required this.isSmall,
  });

  final int activeIndex;
  final int itemCount;
  final VoidCallback? onToggleAutoSlide;
  final bool isAutoSlidePaused;
  final bool isSmall;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.fromLTRB(isSmall ? 8 : 16, 8, isSmall ? 8 : 16, 12),
      padding: EdgeInsets.symmetric(
        horizontal: isSmall ? 10 : 14,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1565C0).withAlpha(18),
            blurRadius: 16,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Techmigos brand (left)
          _TechmigasBrand(isSmall: isSmall),
          // Slide indicator (centre)
          Expanded(
            child: Center(
              child: _SlidePositionIndicator(
                activeIndex: activeIndex,
                itemCount: itemCount,
              ),
            ),
          ),
          // Pause/play (right)
          if (onToggleAutoSlide != null)
            _PauseButton(
              isAutoSlidePaused: isAutoSlidePaused,
              onPressed: onToggleAutoSlide!,
              isSmall: isSmall,
            )
          else
            SizedBox(width: isSmall ? 32 : 40),
        ],
      ),
    );
  }
}

class _TechmigasBrand extends StatelessWidget {
  const _TechmigasBrand({required this.isSmall});
  final bool isSmall;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/branding/techmigos_logo.png',
          height: isSmall ? 26 : 30,
          width: isSmall ? 26 : 30,
          fit: BoxFit.contain,
          semanticLabel: 'TechMigos logo',
        ),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Powered by',
              style: TextStyle(
                fontSize: isSmall ? 8.5 : 9.5,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF607D8B),
              ),
            ),
            Text(
              'TechMigos',
              style: TextStyle(
                fontSize: isSmall ? 10 : 11,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1565C0),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PauseButton extends StatelessWidget {
  const _PauseButton({
    required this.isAutoSlidePaused,
    required this.onPressed,
    required this.isSmall,
  });

  final bool isAutoSlidePaused;
  final VoidCallback onPressed;
  final bool isSmall;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: isAutoSlidePaused ? 'Resume slideshow' : 'Pause slideshow',
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: isSmall ? 32 : 38,
          height: isSmall ? 32 : 38,
          decoration: BoxDecoration(
            color: const Color(0xFFE3F0FF),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            isAutoSlidePaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
            size: isSmall ? 17 : 20,
            color: const Color(0xFF1565C0),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Slide indicator — pill for active, dot for inactive
// ─────────────────────────────────────────────────────────────────────────────

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
        mainAxisSize: MainAxisSize.min,
        children: List.generate(itemCount, (index) {
          final isActive = index == activeIndex;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: isActive ? 22 : 7,
            height: 7,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: isActive
                  ? const Color(0xFF1565C0)
                  : const Color(0xFFB0C4DE),
            ),
          );
        }),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Artwork slide with rounded corners and shadow
// ─────────────────────────────────────────────────────────────────────────────

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
          child: Container(
            width: posterWidth,
            height: constraints.maxHeight,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1565C0).withAlpha(22),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
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

class _ArtworkFallback extends StatelessWidget {
  const _ArtworkFallback();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFEBF5FF),
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
