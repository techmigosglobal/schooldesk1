import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/services/parent_child_selection_service.dart';
import 'package:schooldesk1/core/services/realtime_refresh_service.dart';
import 'package:schooldesk1/core/theme/design_tokens.dart';
import 'package:schooldesk1/core/widgets/erp_components.dart';
import 'package:schooldesk1/core/widgets/erp_module_scaffold.dart';
import 'package:schooldesk1/core/widgets/event_post_media_preview.dart';
import 'package:schooldesk1/core/widgets/parent_navigation.dart';
import 'package:schooldesk1/core/widgets/school_desk_animations.dart';
import 'package:schooldesk1/core/utils/event_post_media_parser.dart';
import 'package:schooldesk1/routes/app_routes.dart';
import 'package:schooldesk1/features/dashboard/presentation/widgets/todays_highlights_card.dart';
import 'package:schooldesk1/core/desktop/desktop_responsive_breakpoints.dart';
import 'package:schooldesk1/features/dashboard/presentation/widgets/parent_dashboard_desktop_shell.dart';

class ParentDashboardScreen extends StatefulWidget {
  const ParentDashboardScreen({super.key});

  @override
  State<ParentDashboardScreen> createState() => _ParentDashboardScreenState();
}

class _ParentDashboardScreenState extends State<ParentDashboardScreen>
    with WidgetsBindingObserver {
  static const Duration _autoRefreshInterval = Duration(seconds: 120);
  DateTime? _lastRefreshAt;
  int _selectedNavIndex = 0;
  int _activeChildIndex = 0;
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _dashboard = const {};
  List<Map<String, dynamic>> _children = const [];
  List<dynamic> _eventPosts = [];
  String _schoolName = 'School';
  Timer? _autoRefreshTimer;
  RealtimeRefreshSubscription? _realtimeSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadDashboardData();
    _realtimeSubscription = RealtimeRefreshService.instance.subscribe(
      channelName: 'parent-dashboard',
      modules: const {'announcements', 'event_posts', 'attendance', 'fees'},
      onRefresh: () {
        if (mounted) {
          unawaited(_loadDashboardData(forceRefresh: true, showSpinner: false));
        }
      },
    );
    _autoRefreshTimer = Timer.periodic(
      _autoRefreshInterval,
      (_) => _loadDashboardData(
        forceRefresh: true,
        showSpinner: false,
        includeFeedPosts: false,
      ),
    );
  }

  Future<void> _loadDashboardData({
    bool forceRefresh = false,
    bool showSpinner = true,
    bool includeFeedPosts = true,
  }) async {
    final now = DateTime.now();
    if (showSpinner &&
        _lastRefreshAt != null &&
        now.difference(_lastRefreshAt!) < const Duration(seconds: 10)) {
      return;
    }
    _lastRefreshAt = now;
    if (showSpinner) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final api = BackendApiClient.instance;
      final futures = <Future<dynamic>>[
        api.getDashboard('parent', forceRefresh: forceRefresh),
        api.getMyStudents(
          refreshNonce: forceRefresh
              ? DateTime.now().millisecondsSinceEpoch
              : null,
        ),
        api.getCurrentSchool().catchError((_) => const <String, dynamic>{}),
      ];
      if (includeFeedPosts) {
        futures.add(
          api.getHomeFeedEventPosts().catchError(
            (_) => const <Map<String, dynamic>>[],
          ),
        );
      }
      final results = await Future.wait(futures);
      if (!mounted) return;
      final dashboard = Map<String, dynamic>.from(results[0] as Map);
      final dashboardChildren =
          (dashboard['children'] as List?)
              ?.whereType<Map>()
              .map((row) => Map<String, dynamic>.from(row))
              .toList() ??
          const <Map<String, dynamic>>[];
      final linkedChildren = (results[1] as List)
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
      final children = dashboardChildren.isNotEmpty
          ? dashboardChildren
          : linkedChildren;
      final selectedChildIndex = await ParentChildSelectionService.indexFor(
        children,
        fallback: _activeChildIndex,
      );
      final feedItems = includeFeedPosts
          ? _mapFeedItems(results[3] as List)
          : _eventPosts
                .whereType<Map>()
                .map((row) => Map<String, dynamic>.from(row))
                .toList();
      setState(() {
        _dashboard = dashboard;
        _children = children;
        _eventPosts = feedItems;
        _schoolName = 'Arish Ville Preschool';
        _activeChildIndex = selectedChildIndex;
        _loading = false;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load parent dashboard.';
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> _mapFeedItems(List<dynamic> rows) {
    final rawEvents = rows.whereType<Map<String, dynamic>>();
    final feedItems = <Map<String, dynamic>>[];
    for (final ev in rawEvents) {
      feedItems.add({
        'title': ev['title'] ?? 'School Post',
        'description': ev['description'] ?? '',
        'date': ev['event_date'] ?? ev['created_at'],
        'sort_date': ev['created_at'] ?? '',
        'category': ev['category'] ?? '',
        'author': ev['author'] ?? ev['posted_by'] ?? '',
        'media_urls': ev['media_urls'],
        'media': _normalizedFeedMedia(ev),
        'media_url': ev['media_url'],
        'mediaUrl': ev['mediaUrl'],
        'attachments': ev['attachments'],
        'media_type': ev['media_type'] ?? ev['mediaType'] ?? '',
        'destinations': ev['destinations'] ?? '',
      });
    }
    feedItems.sort(
      (a, b) => (b['sort_date']?.toString() ?? '').compareTo(
        a['sort_date']?.toString() ?? '',
      ),
    );
    return feedItems;
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = DesktopBreakpoints.isDesktopWidth(width);

    return SchoolDeskModuleScaffold(
      title: _schoolName,
      subtitle: 'School updates and your child overview',
      isPortalRoot: true,
      fallbackRoute: AppRoutes.parentDashboard,
      drawer: ParentDrawer(
        selectedIndex: _selectedNavIndex,
        onDestinationSelected: (i) => setState(() => _selectedNavIndex = i),
      ),
      actions: [
        if (_children.isNotEmpty)
          _ParentChildTopSwitcher(
            children: _children,
            selectedIndex: _activeChildIndex,
            onSelected: _selectChild,
          ),
        IconButton(
          tooltip: 'Refresh',
          icon: const Icon(Icons.refresh_rounded),
          onPressed: () => _loadDashboardData(forceRefresh: true),
        ),
      ],
      bodyIsScrollable: !isDesktop,
      body: isDesktop ? _buildDesktopBody() : _buildBody(),
    );
  }

  Widget _buildDesktopBody() {
    if (_loading) {
      return const SchoolDeskStatusPanel.loading(
        message: 'Loading parent dashboard…',
      );
    }
    if (_error != null) {
      return SchoolDeskStatusPanel.error(
        title: 'Dashboard unavailable',
        message: _error!,
        onAction: () => _loadDashboardData(forceRefresh: true),
      );
    }
    if (_children.isEmpty) {
      return const SchoolDeskStatusPanel.empty(
        title: 'No linked students',
        message:
            'Ask the school admin to link students to this parent account.',
      );
    }

    return ParentDashboardDesktopBody(
      children: _children,
      dashboard: _dashboard,
      activeChildIndex: _activeChildIndex,
      eventPosts: _eventPosts,
      onChildSelected: _selectChild,
    );
  }

  Widget _buildBody() {
    final tokens = Theme.of(context).schoolDesk;
    final horizontal = SchoolDeskResponsive.contentHorizontalPaddingForWidth(
      MediaQuery.sizeOf(context).width,
      tokens.spacing,
    );

    Widget child;
    if (_loading) {
      child = const SchoolDeskStatusPanel.loading(
        message: 'Loading parent dashboard…',
      );
    } else if (_error != null) {
      child = SchoolDeskStatusPanel.error(
        title: 'Dashboard unavailable',
        message: _error!,
        onAction: _loadDashboardData,
      );
    } else if (_children.isEmpty) {
      child = const SchoolDeskStatusPanel.empty(
        title: 'No linked students',
        message:
            'Ask the school admin to link students to this parent account.',
      );
    } else {
      child = _ParentFeedView(
        children: _children,
        dashboard: _dashboard,
        activeChildIndex: _activeChildIndex,
        onChildSelected: _selectChild,
        eventPosts: _eventPosts,
      );
    }

    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFFFFFDF9), // Extremely soft warm cream
                  Color(0xFFFFF4F4), // Extremely soft warm rose
                  Color(0xFFF2F7FD), // Extremely soft clean blue
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ),
        const Positioned.fill(child: _ParentHomePattern()),
        Padding(
          padding: EdgeInsets.fromLTRB(
            horizontal,
            tokens.spacing.md,
            horizontal,
            tokens.spacing.xxl,
          ),
          child: AnimatedSwitcher(duration: tokens.motion.normal, child: child),
        ),
      ],
    );
  }

  void _selectChild(int index) {
    setState(() => _activeChildIndex = index);
    ParentChildSelectionService.saveIndex(_children, index);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(
        _loadDashboardData(
          forceRefresh: true,
          showSpinner: false,
          includeFeedPosts: false,
        ),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoRefreshTimer?.cancel();
    _realtimeSubscription?.dispose();
    super.dispose();
  }
}

// ---------------------------------------------------------------------------
// Feed view
// ---------------------------------------------------------------------------

/// Keeps the selected student's identity in the header, instead of consuming
/// a large card below the feed. The menu only appears as a switcher when the
/// parent actually has more than one linked student.
class _ParentChildTopSwitcher extends StatelessWidget {
  final List<Map<String, dynamic>> children;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const _ParentChildTopSwitcher({
    required this.children,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final selected = children[selectedIndex.clamp(0, children.length - 1)];
    final name = _childName(selected);
    final photo = _childPhoto(selected);
    final parentColor = Theme.of(
      context,
    ).schoolDesk.roleColor(SchoolDeskRole.parent);
    return PopupMenuButton<int>(
      tooltip: children.length > 1 ? 'Switch student' : '$name profile',
      onSelected: onSelected,
      offset: const Offset(0, 48),
      itemBuilder: (context) => [
        for (var index = 0; index < children.length; index++)
          PopupMenuItem<int>(
            value: index,
            enabled: index != selectedIndex,
            child: Row(
              children: [
                _HeaderStudentAvatar(
                  child: children[index],
                  selected: index == selectedIndex,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _childName(children[index]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (index == selectedIndex)
                  Icon(Icons.check_rounded, color: parentColor, size: 18),
              ],
            ),
          ),
      ],
      child: Semantics(
        button: true,
        label: children.length > 1
            ? 'Selected student $name. Switch student.'
            : '$name profile',
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: _HeaderStudentAvatar(
            child: selected,
            selected: true,
            imageUrl: photo,
          ),
        ),
      ),
    );
  }
}

class _HeaderStudentAvatar extends StatelessWidget {
  final Map<String, dynamic> child;
  final bool selected;
  final String? imageUrl;

  const _HeaderStudentAvatar({
    required this.child,
    required this.selected,
    this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).schoolDesk.roleColor(SchoolDeskRole.parent);
    final photo = resolveEventPostMediaUrl(imageUrl ?? _childPhoto(child));
    final name = _childName(child);
    return CircleAvatar(
      radius: 18,
      backgroundColor: color.withAlpha(selected ? 32 : 18),
      foregroundColor: color,
      backgroundImage: photo.isEmpty ? null : NetworkImage(photo),
      onBackgroundImageError: photo.isEmpty ? null : (_, _) {},
      child: photo.isEmpty
          ? Text(
              _initials(name),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            )
          : null,
    );
  }
}

class _ParentFeedView extends StatelessWidget {
  final List<Map<String, dynamic>> children;
  final Map<String, dynamic> dashboard;
  final int activeChildIndex;
  final ValueChanged<int> onChildSelected;
  final List<dynamic> eventPosts;

  const _ParentFeedView({
    required this.children,
    required this.dashboard,
    required this.activeChildIndex,
    required this.onChildSelected,
    required this.eventPosts,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).schoolDesk;
    final parentColor = tokens.roleColor(SchoolDeskRole.parent);
    final activeChild = children[activeChildIndex];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StaggeredFadeIn(
          children: [
            const TodaysHighlightsCard(role: 'parent'),
            SizedBox(height: tokens.spacing.lg),
            // ── Section header ──────────────────────────────────────────
            _SectionHeader(
              label: 'School Feed',
              icon: Icons.campaign_rounded,
              color: parentColor,
            ),
            SizedBox(height: tokens.spacing.sm),
            // ── Auto-scrolling carousel ──────────────────────────────────
            _SchoolFeedCarousel(eventPosts: eventPosts),
            SizedBox(height: tokens.spacing.lg),
            // ── Summary stats ────────────────────────────────────────────
            _SectionHeader(
              label: "Child's Overview",
              icon: Icons.bar_chart_rounded,
              color: parentColor,
            ),
            SizedBox(height: tokens.spacing.sm),
            _ParentSummaryGrid(dashboard: dashboard, child: activeChild),
            SizedBox(height: tokens.spacing.lg),
            // ── Quick-access cards ───────────────────────────────────────
            _SectionHeader(
              label: 'Quick Access',
              icon: Icons.grid_view_rounded,
              color: parentColor,
            ),
            SizedBox(height: tokens.spacing.sm),
            const _ParentQuickAccessRow(),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Section header with accent line
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _SectionHeader({
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Auto-scrolling horizontal carousel for school posts
// ---------------------------------------------------------------------------

class _SchoolFeedCarousel extends StatefulWidget {
  final List<dynamic> eventPosts;

  const _SchoolFeedCarousel({required this.eventPosts});

  @override
  State<_SchoolFeedCarousel> createState() => _SchoolFeedCarouselState();
}

class _SchoolFeedCarouselState extends State<_SchoolFeedCarousel> {
  late PageController _pageController;
  int _currentPage = 0;
  bool _paused = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.92);
    _startAutoScroll();
  }

  void _startAutoScroll() {
    _timer?.cancel();
    if (_paused || widget.eventPosts.length <= 1) return;
    _timer = Timer(_displayDurationForCurrentPost(), () {
      if (!mounted || _paused || widget.eventPosts.length <= 1) return;
      final next = (_currentPage + 1) % widget.eventPosts.length;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 480),
        curve: Curves.easeInOut,
      );
    });
  }

  Duration _displayDurationForCurrentPost() {
    final post = Map<String, dynamic>.from(
      widget.eventPosts[_currentPage] is Map
          ? widget.eventPosts[_currentPage] as Map
          : <String, dynamic>{},
    );
    final media = EventPostMediaItem.parseList(
      post['media'] ??
          post['media_urls'] ??
          post['mediaUrls'] ??
          post['media_url'] ??
          post['mediaUrl'] ??
          post['attachments'],
    );
    if (media.isEmpty) return const Duration(seconds: 5);
    final seconds = media.fold<int>(
      0,
      (total, item) => total + (item.isVideo ? 8 : 3),
    );
    return Duration(seconds: seconds);
  }

  @override
  void didUpdateWidget(_SchoolFeedCarousel old) {
    super.didUpdateWidget(old);
    if (old.eventPosts.length != widget.eventPosts.length) {
      _startAutoScroll();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _togglePause() {
    setState(() => _paused = !_paused);
    _startAutoScroll();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).schoolDesk;
    final parentColor = tokens.roleColor(SchoolDeskRole.parent);

    if (widget.eventPosts.isEmpty) {
      return _EmptyFeed(parentColor: parentColor);
    }

    return Column(
      children: [
        SizedBox(
          height: _feedCardHeight(MediaQuery.sizeOf(context)),
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.eventPosts.length,
            onPageChanged: (i) {
              setState(() => _currentPage = i);
              _startAutoScroll();
            },
            itemBuilder: (context, index) {
              final post = Map<String, dynamic>.from(
                widget.eventPosts[index] is Map
                    ? widget.eventPosts[index] as Map
                    : <String, dynamic>{},
              );
              return AnimatedBuilder(
                animation: _pageController,
                builder: (context, child) {
                  double value = 1.0;
                  if (_pageController.position.haveDimensions) {
                    value = (_pageController.page ?? 0) - index;
                    value = (1 - (value.abs() * 0.3)).clamp(0.0, 1.0);
                  } else {
                    value = index == _currentPage ? 1.0 : 0.7;
                  }
                  final opacity = value.clamp(0.0, 1.0);
                  return Opacity(
                    opacity: opacity,
                    child: Transform.scale(
                      scale: 0.94 + (value * 0.06),
                      child: child,
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: _InteractiveBouncingCard(
                    onTap: () {
                      _showPostDetailsBottomSheet(
                        context,
                        post,
                        _gradientFor(post['title'] ?? ''),
                      );
                    },
                    child: _PostCard(
                      post: post,
                      isActive: index == _currentPage,
                      onOpenDetails: () => _showPostDetailsBottomSheet(
                        context,
                        post,
                        _gradientFor(post['title'] ?? ''),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        // Dots + pause button
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Dot indicators
            ...List.generate(
              math.min(widget.eventPosts.length, 8),
              (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeInOut,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _currentPage ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: i == _currentPage
                      ? parentColor
                      : parentColor.withAlpha(60),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            if (widget.eventPosts.length > 1) ...[
              const SizedBox(width: 12),
              GestureDetector(
                onTap: _togglePause,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _paused
                        ? parentColor.withAlpha(30)
                        : parentColor.withAlpha(18),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: parentColor.withAlpha(_paused ? 120 : 50),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _paused
                            ? Icons.play_arrow_rounded
                            : Icons.pause_rounded,
                        size: 14,
                        color: parentColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _paused ? 'Resume' : 'Pause',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: parentColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Empty feed state
// ---------------------------------------------------------------------------

class _EmptyFeed extends StatelessWidget {
  final Color parentColor;

  const _EmptyFeed({required this.parentColor});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: parentColor.withAlpha(12),
        borderRadius: BorderRadius.circular(tokens.radius.card),
        border: Border.all(color: parentColor.withAlpha(40)),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: parentColor.withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.campaign_outlined,
                size: 32,
                color: parentColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No posts yet',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'School events and activity posts will appear here.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: tokens.textMuted,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

double _feedCardHeight(Size size) {
  final widthDriven = size.width * 1.22;
  final heightDriven = size.height * 0.60;
  return math.max(500, math.min(650, math.max(widthDriven, heightDriven)));
}

// ---------------------------------------------------------------------------
// Redesigned post card — tall, vivid, card-style
// ---------------------------------------------------------------------------

class _InteractiveBouncingCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const _InteractiveBouncingCard({required this.child, required this.onTap});

  @override
  State<_InteractiveBouncingCard> createState() =>
      _InteractiveBouncingCardState();
}

class _InteractiveBouncingCardState extends State<_InteractiveBouncingCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scale = Tween<double>(
      begin: 1.0,
      end: 0.96,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: widget.onTap,
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}

class _ParentHomePattern extends StatelessWidget {
  const _ParentHomePattern();

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(painter: _ParentHomePatternPainter());
  }
}

class _ParentHomePatternPainter extends CustomPainter {
  const _ParentHomePatternPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final icons = <IconData>[
      Icons.favorite_outline_rounded,
      Icons.child_care_rounded,
      Icons.menu_book_rounded,
      Icons.family_restroom_rounded,
      Icons.star_outline_rounded,
      Icons.chat_bubble_outline_rounded,
    ];
    final textPainter = TextPainter(textDirection: ui.TextDirection.ltr);
    var iconIndex = 0;
    for (double y = 28; y < size.height; y += 128) {
      for (double x = 20; x < size.width; x += 138) {
        final icon = icons[iconIndex % icons.length];
        iconIndex++;
        textPainter.text = TextSpan(
          text: String.fromCharCode(icon.codePoint),
          style: TextStyle(
            fontFamily: icon.fontFamily,
            package: icon.fontPackage,
            fontSize: 26,
            color: const Color(0xFFF43F5E).withOpacity(0.035),
          ),
        );
        textPainter.layout();
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate((iconIndex.isEven ? -1 : 1) * 0.18);
        textPainter.paint(canvas, Offset.zero);
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

void _showPostDetailsBottomSheet(
  BuildContext context,
  Map<String, dynamic> post,
  List<Color> gradient,
) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (context) {
        final title = _text(post['title']).isEmpty
            ? 'School Post'
            : _text(post['title']);
        final description = _text(post['description']);
        final author = _text(post['author']);
        final category = _text(post['category']);
        final rawDate = _text(post['date']);
        final formattedDate = _formatPostDate(rawDate);

        final mediaItems = EventPostMediaItem.parseList(
          post['media'] ??
              post['media_urls'] ??
              post['mediaUrls'] ??
              post['media_url'] ??
              post['mediaUrl'] ??
              post['attachments'],
        );

        return Scaffold(
          appBar: AppBar(
            title: const Text('Feed Detail'),
            actions: [
              IconButton(
                tooltip: 'Share post',
                icon: const Icon(Icons.share_outlined),
                onPressed: () => Share.share(
                  [
                    title,
                    description,
                  ].where((value) => value.isNotEmpty).join('\n\n'),
                  subject: title,
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
                  children: [
                    Row(
                      children: [
                        if (category.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: gradient[0].withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              category.toUpperCase(),
                              style: GoogleFonts.dmSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: gradient[0],
                              ),
                            ),
                          ),
                        const Spacer(),
                        Text(
                          formattedDate,
                          style: GoogleFonts.dmSans(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      title,
                      style: GoogleFonts.dmSans(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    if (author.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Posted by $author',
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    if (mediaItems.isNotEmpty) ...[
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final mediaHeight = math
                              .max(330, constraints.maxWidth * 1.1)
                              .clamp(330, 560)
                              .toDouble();
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: SizedBox(
                              height: mediaHeight,
                              child: _PostMediaCarousel(
                                mediaItems: mediaItems,
                                isActive: true,
                                height: mediaHeight,
                                autoAdvance: false,
                                imageFit: BoxFit.contain,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                    ],
                    Text(
                      description,
                      style: GoogleFonts.dmSans(
                        fontSize: 15,
                        height: 1.6,
                        color: const Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

/// Displays every attachment in a post before the enclosing school-feed card
/// advances. Images slide horizontally; videos begin muted and can be unmuted.
class _PostMediaCarousel extends StatefulWidget {
  final List<EventPostMediaItem> mediaItems;
  final bool isActive;
  final double height;
  final bool autoAdvance;
  final BoxFit imageFit;
  final VoidCallback? onImageTap;

  const _PostMediaCarousel({
    required this.mediaItems,
    required this.isActive,
    required this.height,
    this.autoAdvance = true,
    this.imageFit = BoxFit.cover,
    this.onImageTap,
  });

  @override
  State<_PostMediaCarousel> createState() => _PostMediaCarouselState();
}

class _PostMediaCarouselState extends State<_PostMediaCarousel> {
  late final PageController _controller;
  Timer? _timer;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
    _scheduleNextMedia();
  }

  @override
  void didUpdateWidget(_PostMediaCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive ||
        oldWidget.mediaItems.length != widget.mediaItems.length) {
      _scheduleNextMedia();
    }
  }

  void _scheduleNextMedia() {
    _timer?.cancel();
    if (!widget.autoAdvance ||
        !widget.isActive ||
        widget.mediaItems.length <= 1) {
      return;
    }
    final current = widget.mediaItems[_currentIndex];
    _timer = Timer(Duration(seconds: current.isVideo ? 8 : 3), () {
      if (!mounted || !widget.isActive || widget.mediaItems.length <= 1) {
        return;
      }
      final next = (_currentIndex + 1) % widget.mediaItems.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: _controller,
          itemCount: widget.mediaItems.length,
          onPageChanged: (index) {
            setState(() => _currentIndex = index);
            _scheduleNextMedia();
          },
          itemBuilder: (context, index) {
            final item = widget.mediaItems[index];
            if (item.isVideo) {
              return EventPostVideoPreview(
                key: ValueKey('event-video-${item.url}'),
                url: resolveEventPostMediaUrl(item.url),
                height: widget.height,
                autoPlay: widget.isActive && index == _currentIndex,
                muted: true,
                loadOnInit: false,
                onTap: () => openEventPostMediaPreview(context, item),
              );
            }
            return EventPostMediaPreview(
              key: ValueKey('event-image-${item.url}'),
              item: item,
              height: widget.height,
              imageFit: widget.imageFit,
              onImageTap:
                  widget.onImageTap ??
                  () => openEventPostMediaPreview(context, item),
            );
          },
        ),
        if (widget.mediaItems.length > 1)
          Positioned(
            bottom: 8,
            right: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_currentIndex + 1}/${widget.mediaItems.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _PostCard extends StatelessWidget {
  final Map<String, dynamic> post;
  final bool isActive;
  final VoidCallback onOpenDetails;

  const _PostCard({
    required this.post,
    required this.isActive,
    required this.onOpenDetails,
  });

  @override
  Widget build(BuildContext context) {
    final title = _text(post['title']).isEmpty
        ? 'School Post'
        : _text(post['title']);
    final rawDate = _text(post['date']);
    final category = _text(post['category']);
    final author = _text(post['author']);
    final formattedDate = _formatPostDate(rawDate);
    final gradient = _gradientFor(title);

    final mediaItems = EventPostMediaItem.parseList(
      post['media'] ??
          post['media_urls'] ??
          post['mediaUrls'] ??
          post['media_url'] ??
          post['mediaUrl'] ??
          post['attachments'],
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (mediaItems.isNotEmpty)
                  _PostMediaCarousel(
                    mediaItems: mediaItems,
                    isActive: isActive,
                    height: 240,
                    onImageTap: onOpenDetails,
                  )
                else
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: gradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.campaign_rounded,
                        color: Colors.white.withOpacity(0.9),
                        size: 56,
                      ),
                    ),
                  ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.black54,
                            Colors.transparent,
                            Colors.black45,
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ),
                ),
                if (category.isNotEmpty)
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        category.toUpperCase(),
                        style: GoogleFonts.dmSans(
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          color: gradient[0],
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                if (formattedDate.isNotEmpty)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        formattedDate,
                        style: GoogleFonts.dmSans(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  bottom: 10,
                  left: 12,
                  right: 12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.dmSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          shadows: [
                            const Shadow(
                              color: Colors.black45,
                              blurRadius: 3,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                      if (author.isNotEmpty) ...[
                        const SizedBox(height: 1),
                        Text(
                          'by $author',
                          style: GoogleFonts.dmSans(
                            fontSize: 10,
                            color: Colors.white70,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

const List<List<Color>> _gradients = [
  [Color(0xFFFE7A36), Color(0xFFF35F30)],
  [Color(0xFF2196F3), Color(0xFF1976D2)],
  [Color(0xFF9C27B0), Color(0xFF7B1FA2)],
  [Color(0xFF4CAF50), Color(0xFF388E3C)],
  [Color(0xFFFF9800), Color(0xFFF57C00)],
  [Color(0xFFE91E63), Color(0xFFC2185B)],
];

List<Color> _gradientFor(String title) {
  final index = title.hashCode.abs() % _gradients.length;
  return _gradients[index];
}

String _formatPostDate(String raw) {
  if (raw.isEmpty) return '';
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return raw;
  final now = DateTime.now();
  final diff = now.difference(parsed);
  if (diff.inDays == 0) {
    if (diff.inHours == 0) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return DateFormat('d MMM').format(parsed);
}

// ---------------------------------------------------------------------------
// Summary grid — vivid gradient stat cards
// ---------------------------------------------------------------------------

class _ParentSummaryGrid extends StatelessWidget {
  final Map<String, dynamic> dashboard;
  final Map<String, dynamic> child;

  const _ParentSummaryGrid({required this.dashboard, required this.child});

  @override
  Widget build(BuildContext context) {
    final metrics = dashboard['metrics'] is Map
        ? Map<String, dynamic>.from(dashboard['metrics'] as Map)
        : const <String, dynamic>{};
    final cards = <Widget>[
      _StatCard(
        icon: Icons.how_to_reg_rounded,
        label: 'Attendance',
        value: _percentage(child['attendance_pct']),
        gradientColors: const [Color(0xFF0F766E), Color(0xFF14B8A6)],
        route: AppRoutes.parentAttendance,
      ),
      _StatCard(
        icon: Icons.assignment_turned_in_rounded,
        label: 'Dairy Due',
        value: _metricNumber(child['homework_due']),
        gradientColors: const [Color(0xFF7C3AED), Color(0xFFA78BFA)],
        route: AppRoutes.parentHomework,
      ),
      _StatCard(
        icon: Icons.account_balance_wallet_rounded,
        label: 'Fees Due',
        value: _money(
          child['pending_fee_balance'] ?? metrics['pending_fee_balance'],
        ),
        gradientColors: const [Color(0xFFEA580C), Color(0xFFFB923C)],
        route: AppRoutes.parentFees,
      ),
      _StatCard(
        icon: Icons.chat_bubble_rounded,
        label: 'Unread Messages',
        value: _metricNumber(metrics['unread_messages']),
        gradientColors: const [Color(0xFF1D4ED8), Color(0xFF60A5FA)],
        route: AppRoutes.parentTeacherChat,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 8.0;
        final columns = constraints.maxWidth >= 700 ? 4 : 2;
        final width =
            (constraints.maxWidth - (spacing * (columns - 1))) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: cards
              .map((card) => SizedBox(width: width, child: card))
              .toList(),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final List<Color> gradientColors;
  final String route;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.gradientColors,
    required this.route,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.pushNamed(context, route),
        child: Container(
          height: 72,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: tokens.isDark
                ? gradientColors[0].withAlpha(38)
                : Colors.white.withAlpha(235),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: gradientColors[0].withAlpha(45)),
            boxShadow: [
              BoxShadow(
                color: gradientColors[0].withAlpha(tokens.isDark ? 28 : 18),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: gradientColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SchoolDeskAdaptiveText(
                      value,
                      maxLines: 1,
                      minFontSize: 13,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: tokens.onSurface,
                      ),
                    ),
                    SchoolDeskAdaptiveText(
                      label,
                      maxLines: 1,
                      minFontSize: 9,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: tokens.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: gradientColors[0].withAlpha(150),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Quick-access cards — horizontal scroll row
// ---------------------------------------------------------------------------

class _ParentQuickAccessRow extends StatelessWidget {
  const _ParentQuickAccessRow();

  static const _actions = [
    _QuickAction(
      label: 'Attendance',
      icon: Icons.how_to_reg_rounded,
      asset: SchoolDeskUiIllustrations.attendance,
      route: AppRoutes.parentAttendance,
      color: Color(0xFF0F766E),
    ),
    _QuickAction(
      label: 'Dairy',
      icon: Icons.assignment_rounded,
      asset: SchoolDeskUiIllustrations.homework,
      route: AppRoutes.parentHomework,
      color: Color(0xFF7C3AED),
    ),
    _QuickAction(
      label: 'Fees',
      icon: Icons.receipt_long_rounded,
      asset: SchoolDeskUiIllustrations.principalFees,
      route: AppRoutes.parentFees,
      color: Color(0xFFEA580C),
    ),
    _QuickAction(
      label: 'Leave',
      icon: Icons.event_busy_rounded,
      asset: SchoolDeskUiIllustrations.calendar,
      route: AppRoutes.parentLeave,
      color: Color(0xFFDC2626),
    ),
    _QuickAction(
      label: 'Messages',
      icon: Icons.chat_bubble_rounded,
      asset: SchoolDeskUiIllustrations.chat,
      route: AppRoutes.parentTeacherChat,
      color: Color(0xFF1D4ED8),
    ),
    _QuickAction(
      label: 'Calendar',
      icon: Icons.calendar_month_rounded,
      asset: SchoolDeskUiIllustrations.principalEvents,
      route: AppRoutes.parentCalendar,
      color: Color(0xFF0284C7),
    ),
    _QuickAction(
      label: 'Documents',
      icon: Icons.description_rounded,
      asset: SchoolDeskUiIllustrations.resources,
      route: AppRoutes.parentDocuments,
      color: Color(0xFF15803D),
    ),
    _QuickAction(
      label: 'Timetable',
      icon: Icons.calendar_view_week_rounded,
      asset: SchoolDeskUiIllustrations.classRoutine,
      route: AppRoutes.parentTimetable,
      color: Color(0xFFB45309),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        itemCount: _actions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) =>
            _QuickAccessCard(action: _actions[index]),
      ),
    );
  }
}

class _QuickAction {
  final String label;
  final IconData icon;
  final String asset;
  final String route;
  final Color color;

  const _QuickAction({
    required this.label,
    required this.icon,
    required this.asset,
    required this.route,
    required this.color,
  });
}

class _QuickAccessCard extends StatelessWidget {
  final _QuickAction action;

  const _QuickAccessCard({required this.action});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.pushNamed(context, action.route),
        child: Container(
          width: 80,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            color: tokens.panel,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: action.color.withAlpha(50)),
            boxShadow: [
              BoxShadow(
                color: action.color.withAlpha(tokens.isDark ? 40 : 20),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: action.color.withAlpha(tokens.isDark ? 40 : 22),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SchoolDeskIllustration(
                  asset: action.asset,
                  size: 34,
                  semanticLabel: '${action.label} illustration',
                ),
              ),
              const SizedBox(height: 6),
              Text(
                action.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pure helper functions
// ---------------------------------------------------------------------------

String _text(dynamic value) => value?.toString().trim() ?? '';

dynamic _normalizedFeedMedia(Map<String, dynamic> post) {
  final raw =
      post['media'] ??
      post['media_urls'] ??
      post['mediaUrls'] ??
      post['media_url'] ??
      post['mediaUrl'] ??
      post['attachments'];
  final mediaType = _text(post['media_type'] ?? post['mediaType']);
  if (mediaType.isEmpty || raw == null) return raw;
  if (raw is List) {
    return raw.map((item) {
      if (item is Map) return item;
      return {'url': item, 'mime_type': mediaType};
    }).toList();
  }
  return [
    {'url': raw, 'mime_type': mediaType},
  ];
}

String _childName(Map<String, dynamic> child) {
  for (final value in [
    child['name'],
    child['full_name'],
    child['student_name'],
    [
      child['first_name'],
      child['last_name'],
    ].map(_text).where((part) => part.isNotEmpty).join(' '),
  ]) {
    final text = _text(value);
    if (text.isNotEmpty) return text;
  }
  return 'Student';
}

String _childPhoto(Map<String, dynamic> child) {
  for (final value in [child['photo_url'], child['photo'], child['avatar']]) {
    final text = _text(value);
    if (text.isNotEmpty) return text;
  }
  return '';
}

String _initials(String name) {
  final parts = name.split(RegExp(r'\s+')).where((part) => part.isNotEmpty);
  return parts.take(2).map((part) => part[0].toUpperCase()).join();
}

String _number(dynamic value) {
  if (value is int) return '$value';
  if (value is num) {
    final rounded = value.roundToDouble();
    return rounded == value
        ? value.toInt().toString()
        : value.toStringAsFixed(1);
  }
  final parsed = double.tryParse(_text(value));
  if (parsed == null) return '0';
  return parsed.roundToDouble() == parsed
      ? parsed.toInt().toString()
      : parsed.toStringAsFixed(1);
}

String _metricNumber(dynamic value) {
  if (value == null || _text(value).isEmpty) return '—';
  return _number(value);
}

String _percentage(dynamic value) {
  if (value == null || _text(value).isEmpty) return 'Not marked';
  return '${_number(value)}%';
}

String _money(dynamic value) {
  final parsed = value is num
      ? value.toDouble()
      : double.tryParse(_text(value));
  final amount = parsed ?? 0;
  if (amount >= 100000) return '₹${(amount / 100000).toStringAsFixed(1)}L';
  if (amount >= 1000) return '₹${(amount / 1000).toStringAsFixed(1)}K';
  return '₹${amount.toStringAsFixed(0)}';
}
