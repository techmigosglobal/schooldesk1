import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:schooldesk1/core/constants/app_constants.dart';
import 'package:schooldesk1/core/repositories/repository_state.dart';
import 'package:schooldesk1/core/services/token_storage_service.dart';
import 'package:schooldesk1/core/utils/event_post_media_parser.dart';
import 'package:schooldesk1/modules/communication/data/api_event_post_repository.dart';
import 'package:schooldesk1/modules/communication/domain/event_post_repository.dart';
import 'package:schooldesk1/routes/app_routes.dart';

import 'package:schooldesk1/core/navigation/schooldesk_navigation.dart';
import 'package:schooldesk1/core/widgets/repository_state_view.dart';

class LandingPageScreen extends StatefulWidget {
  final EventPostRepository? eventPostRepository;

  const LandingPageScreen({super.key, this.eventPostRepository});

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

  // Network-fetched landing post images (prepend to static assets when loaded)
  List<String> _networkImageUrls = const [];
  RepositoryState<List<String>> _landingState =
      const RepositoryState<List<String>>(
        data: _slideAssets,
        source: RepositorySource.remote,
      );

  EventPostRepository get _eventPostRepository =>
      widget.eventPostRepository ?? ApiEventPostRepository.legacyDefault;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
    _fetchLandingPosts();
  }

  Future<void> _fetchLandingPosts() async {
    final schoolId = await TokenStorageService.getSchoolId() ?? '';
    if (schoolId.isEmpty) return;
    try {
      final posts = await _eventPostRepository.loadLandingPosts(
        schoolId: schoolId,
      );
      final urls = <String>[];
      for (final post in posts) {
        final items = EventPostMediaItem.parseList(post['media_urls']);
        for (final item in items) {
          if (item.isImage && item.url.isNotEmpty) {
            urls.add(item.url);
          }
        }
      }
      if (urls.isEmpty || !mounted) return;
      setState(() {
        _networkImageUrls = urls;
        _landingState = RepositoryState<List<String>>(
          data: urls,
          source: RepositorySource.remote,
          lastUpdated: DateTime.now().toUtc(),
        );
        // Reset to first slide when new content loads
        _activeSlide = 0;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _landingState = RepositoryState<List<String>>(
          data: _slideAssets,
          source: RepositorySource.cache,
          isStale: true,
          error: error,
        );
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    for (final asset in _slideAssets) {
      precacheImage(AssetImage(asset), context); // static fallback assets
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

  List<String> get _allSlides =>
      _networkImageUrls.isNotEmpty ? _networkImageUrls : _slideAssets;

  void _restartAutoSlideTimer() {
    _stopAutoSlideTimer();
    if (_reduceMotion || _autoSlidePausedByUser || _autoSlidePausedByTouch) {
      return;
    }
    _autoSlideTimer = Timer.periodic(_autoSlideInterval, (_) {
      if (!mounted || !_controller.hasClients) return;
      final next = (_activeSlide + 1) % _allSlides.length;
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
    SchoolDeskNavigation.push(context, AppRoutes.principalLogin);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isSmall = size.width < 400;
    final isNarrow = size.width < 350;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Column(
                    children: [
                      _LandingHeader(
                        onSignIn: _openLogin,
                        isSmall: isSmall,
                        isNarrow: isNarrow,
                      ),
                      SizedBox(height: isSmall ? 2 : 4),
                      Flexible(
                        fit: FlexFit.loose,
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: isSmall ? 8 : 16,
                          ),
                          child: SchoolDeskRepositoryStateView<List<String>>(
                            state: _landingState,
                            onRetry: _fetchLandingPosts,
                            errorTitle: 'Unable to load school updates',
                            data: (_) => _LandingCarousel(
                              controller: _controller,
                              slides: _allSlides,
                              networkSlideCount: _networkImageUrls.length,
                              onPageChanged: (index) =>
                                  setState(() => _activeSlide = index),
                              onScrollStart: _pauseAutoSlide,
                              onScrollEnd: _resumeAutoSlide,
                              onPrevious: () => _goToSlide(
                                (_activeSlide - 1 + _allSlides.length) %
                                    _allSlides.length,
                                manual: true,
                              ),
                              onNext: () => _goToSlide(
                                (_activeSlide + 1) % _allSlides.length,
                                manual: true,
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: isSmall ? 2 : 4),
                      _LandingFooter(
                        activeIndex: _activeSlide,
                        itemCount: _allSlides.length,
                        onToggleAutoSlide: _reduceMotion
                            ? null
                            : _toggleAutoSlide,
                        isAutoSlidePaused:
                            _reduceMotion || _autoSlidePausedByUser,
                        isSmall: isSmall,
                        isNarrow: isNarrow,
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
  const _LandingHeader({
    required this.onSignIn,
    required this.isSmall,
    required this.isNarrow,
  });

  final VoidCallback onSignIn;
  final bool isSmall;
  final bool isNarrow;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.fromLTRB(isSmall ? 8 : 16, 8, isSmall ? 8 : 16, 0),
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
              height: isNarrow ? 38 : (isSmall ? 44 : 52),
              width: isNarrow ? 38 : (isSmall ? 44 : 52),
              fit: BoxFit.cover,
              semanticLabel: 'School logo',
            ),
          ),
          SizedBox(width: isNarrow ? 8 : 10),
          // School name
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AppConstants.schoolName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: isSmall ? 15 : 17,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0D1B2A),
                    letterSpacing: 0,
                  ),
                ),
                Text(
                  'Learn Today, Lead Tomorrow',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
          SizedBox(width: isNarrow ? 6 : 8),
          _SignInButton(
            key: const Key('sign_in_button'),
            onPressed: onSignIn,
            isSmall: isSmall,
            isNarrow: isNarrow,
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
    required this.isNarrow,
    super.key,
  });

  final VoidCallback onPressed;
  final bool isSmall;
  final bool isNarrow;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Sign in to ${AppConstants.appName}',
      child: Material(
        color: const Color(0xFF1565C0),
        borderRadius: BorderRadius.circular(12),
        elevation: 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onPressed,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isNarrow ? 9 : (isSmall ? 12 : 16),
              vertical: isSmall ? 9 : 11,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.login_rounded,
                  size: isNarrow ? 14 : (isSmall ? 15 : 16),
                  color: Colors.white,
                ),
                SizedBox(width: isNarrow ? 4 : 5),
                Text(
                  'Sign in',
                  style: TextStyle(
                    fontSize: isNarrow ? 11 : (isSmall ? 12 : 13),
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0,
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

class _LandingCarousel extends StatelessWidget {
  const _LandingCarousel({
    required this.controller,
    required this.slides,
    required this.networkSlideCount,
    required this.onPageChanged,
    required this.onScrollStart,
    required this.onScrollEnd,
    required this.onPrevious,
    required this.onNext,
  });

  final PageController controller;
  // Combined list: network images first (if any), then static asset paths.
  final List<String> slides;
  final int networkSlideCount;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onScrollStart;
  final VoidCallback onScrollEnd;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final frame = _posterFrameFor(constraints.biggest);

        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: frame.width,
            height: frame.height,
            child: Stack(
              fit: StackFit.expand,
              children: [
                NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (notification is ScrollStartNotification) {
                      onScrollStart();
                    } else if (notification is ScrollEndNotification) {
                      onScrollEnd();
                    }
                    return false;
                  },
                  child: PageView.builder(
                    controller: controller,
                    onPageChanged: onPageChanged,
                    itemCount: slides.length,
                    itemBuilder: (context, index) {
                      if (index < networkSlideCount) {
                        return _NetworkImageSlide(url: slides[index]);
                      }
                      return _ArtworkSlide(assetPath: slides[index]);
                    },
                  ),
                ),
                _ArtworkHotspots(onPrevious: onPrevious, onNext: onNext),
              ],
            ),
          ),
        );
      },
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
    required this.isNarrow,
  });

  final int activeIndex;
  final int itemCount;
  final VoidCallback? onToggleAutoSlide;
  final bool isAutoSlidePaused;
  final bool isSmall;
  final bool isNarrow;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.fromLTRB(isSmall ? 8 : 16, 0, isSmall ? 8 : 16, 8),
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
          Flexible(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: _TechmigasBrand(isSmall: isSmall, isNarrow: isNarrow),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: _SlidePositionIndicator(
                activeIndex: activeIndex,
                itemCount: itemCount,
              ),
            ),
          ),
          if (onToggleAutoSlide != null)
            _PauseButton(
              isAutoSlidePaused: isAutoSlidePaused,
              onPressed: onToggleAutoSlide!,
              isSmall: isSmall,
              isNarrow: isNarrow,
            )
          else
            SizedBox(width: isNarrow ? 30 : (isSmall ? 32 : 40)),
        ],
      ),
    );
  }
}

class _TechmigasBrand extends StatelessWidget {
  const _TechmigasBrand({required this.isSmall, required this.isNarrow});
  final bool isSmall;
  final bool isNarrow;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/branding/techmigos_logo.png',
          height: isNarrow ? 22 : (isSmall ? 26 : 30),
          width: isNarrow ? 22 : (isSmall ? 26 : 30),
          fit: BoxFit.contain,
          semanticLabel: 'TechMigos logo',
        ),
        SizedBox(width: isNarrow ? 5 : 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Powered by',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: isNarrow ? 8 : (isSmall ? 8.5 : 9.5),
                fontWeight: FontWeight.w500,
                color: const Color(0xFF607D8B),
              ),
            ),
            Text(
              'TechMigos',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: isNarrow ? 9.5 : (isSmall ? 10 : 11),
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
    required this.isNarrow,
  });

  final bool isAutoSlidePaused;
  final VoidCallback onPressed;
  final bool isSmall;
  final bool isNarrow;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: isAutoSlidePaused ? 'Resume slideshow' : 'Pause slideshow',
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: isNarrow ? 30 : (isSmall ? 32 : 38),
          height: isNarrow ? 30 : (isSmall ? 32 : 38),
          decoration: BoxDecoration(
            color: const Color(0xFFE3F0FF),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            isAutoSlidePaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
            size: isNarrow ? 16 : (isSmall ? 17 : 20),
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
      child: FittedBox(
        fit: BoxFit.scaleDown,
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
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Network image slide (event post images from backend)
// ─────────────────────────────────────────────────────────────────────────────

class _NetworkImageSlide extends StatelessWidget {
  const _NetworkImageSlide({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final frame = _posterFrameFor(constraints.biggest);

        return Center(
          child: Container(
            width: frame.width,
            height: frame.height,
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
              child: Image.network(
                url,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
                semanticLabel: 'School event image',
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const ColoredBox(
                    color: Color(0xFFEBF5FF),
                    child: Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF1565C0),
                      ),
                    ),
                  );
                },
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
        final frame = _posterFrameFor(constraints.biggest);

        return Center(
          child: Container(
            width: frame.width,
            height: frame.height,
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
                fit: BoxFit.fill,
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
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;

        return Stack(
          children: [
            _ArtworkHotspot(
              label: 'Previous slide',
              tooltip: 'Previous',
              onTap: onPrevious,
              rect: Rect.fromLTWH(
                width * 0.19,
                height * 0.88,
                width * 0.12,
                height * 0.075,
              ),
            ),
            _ArtworkHotspot(
              label: 'Next slide',
              tooltip: 'Next',
              onTap: onNext,
              rect: Rect.fromLTWH(
                width * 0.68,
                height * 0.88,
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

Rect _posterFrameFor(Size size) {
  return Rect.fromLTWH(0, 0, size.width, size.height);
}
