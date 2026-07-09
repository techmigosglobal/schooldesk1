import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/services/parent_child_selection_service.dart';
import 'package:schooldesk1/core/theme/design_tokens.dart';
import 'package:schooldesk1/core/widgets/erp_components.dart';
import 'package:schooldesk1/core/widgets/erp_module_scaffold.dart';
import 'package:schooldesk1/core/widgets/event_post_media_preview.dart';
import 'package:schooldesk1/core/widgets/parent_navigation.dart';
import 'package:schooldesk1/core/widgets/school_desk_animations.dart';
import 'package:schooldesk1/core/utils/event_post_media_parser.dart';
import 'package:schooldesk1/routes/app_routes.dart';
import 'package:schooldesk1/features/dashboard/presentation/widgets/todays_highlights_card.dart';

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
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadDashboardData(forceRefresh: true);
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
      final children =
          dashboardChildren.isNotEmpty ? dashboardChildren : linkedChildren;
      final selectedChildIndex = await ParentChildSelectionService.indexFor(
        children,
        fallback: _activeChildIndex,
      );
      final feedItems = includeFeedPosts
          ? _mapFeedItems(results[2] as List)
          : _eventPosts
                .whereType<Map>()
                .map((row) => Map<String, dynamic>.from(row))
                .toList();
      setState(() {
        _dashboard = dashboard;
        _children = children;
        _eventPosts = feedItems;
        _activeChildIndex = selectedChildIndex;
        _loading = false;
      });
    } catch (e) {
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
        'media': ev['media'],
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
    return SchoolDeskModuleScaffold(
      title: 'School Feed',
      subtitle: 'Child summary, actions, and school updates',
      isPortalRoot: true,
      fallbackRoute: AppRoutes.parentDashboard,
      drawer: ParentDrawer(
        selectedIndex: _selectedNavIndex,
        onDestinationSelected: (i) => setState(() => _selectedNavIndex = i),
      ),
      actions: [
        IconButton(
          tooltip: 'Refresh',
          icon: const Icon(Icons.refresh_rounded),
          onPressed: () => _loadDashboardData(forceRefresh: true),
        ),
      ],
      bodyIsScrollable: true,
      body: _buildBody(),
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

    return Padding(
      padding: EdgeInsets.fromLTRB(
        horizontal,
        tokens.spacing.md,
        horizontal,
        tokens.spacing.xxl,
      ),
      child: AnimatedSwitcher(duration: tokens.motion.normal, child: child),
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
    super.dispose();
  }
}

// ---------------------------------------------------------------------------
// Feed view
// ---------------------------------------------------------------------------

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
            // ── Child selector ───────────────────────────────────────────
            _ParentChildPillSelector(
              children: children,
              activeIndex: activeChildIndex,
              onChanged: onChildSelected,
              color: parentColor,
            ),
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
    if (widget.eventPosts.length <= 1) return;
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (_paused || !mounted) return;
      final next = (_currentPage + 1) % widget.eventPosts.length;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 480),
        curve: Curves.easeInOut,
      );
    });
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
          height: 260,
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.eventPosts.length,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemBuilder: (context, index) {
              final post = Map<String, dynamic>.from(
                widget.eventPosts[index] is Map
                    ? widget.eventPosts[index] as Map
                    : <String, dynamic>{},
              );
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: _PostCard(post: post),
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
              child: Icon(Icons.campaign_outlined, size: 32, color: parentColor),
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

// ---------------------------------------------------------------------------
// Redesigned post card — tall, vivid, card-style
// ---------------------------------------------------------------------------

class _PostCard extends StatelessWidget {
  final Map<String, dynamic> post;

  const _PostCard({required this.post});

  // Gradient palette for posts (cycles by index via hashCode)
  static const List<List<Color>> _gradients = [
    [Color(0xFF0F766E), Color(0xFF0D9488)],
    [Color(0xFF1D4ED8), Color(0xFF3B82F6)],
    [Color(0xFF7C3AED), Color(0xFFA78BFA)],
    [Color(0xFFEA580C), Color(0xFFFB923C)],
    [Color(0xFF0284C7), Color(0xFF38BDF8)],
    [Color(0xFF15803D), Color(0xFF4ADE80)],
    [Color(0xFFB91C1C), Color(0xFFF87171)],
    [Color(0xFF92400E), Color(0xFFFBBF24)],
  ];

  List<Color> _gradientFor(String title) {
    final index = title.hashCode.abs() % _gradients.length;
    return _gradients[index];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;

    final title =
        _text(post['title']).isEmpty ? 'School Post' : _text(post['title']);
    final description = _text(post['description']);
    final rawDate = _text(post['date']);
    final category = _text(post['category']);
    final author = _text(post['author']);
    final formattedDate = _formatPostDate(rawDate);
    final mediaType = _eventPostMediaType(post);
    final gradient = _gradientFor(title);

    return Container(
      decoration: BoxDecoration(
        color: tokens.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tokens.panelBorder),
        boxShadow: [
          BoxShadow(
            color: gradient[0].withAlpha(tokens.isDark ? 50 : 30),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Gradient header ─────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(40),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.campaign_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.3,
                        ),
                      ),
                      if (author.isNotEmpty || category.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          [
                            if (author.isNotEmpty) author,
                            if (category.isNotEmpty) category,
                          ].join(' • '),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white.withAlpha(200),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (formattedDate.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(35),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      formattedDate,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // ── Media type badge ─────────────────────────────────────────
          if (mediaType.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: _FeedMediaTypeChip(type: mediaType, color: gradient[0]),
            ),
          // ── Media preview ─────────────────────────────────────────────
          _SchoolFeedMediaPreview(post: post),
          // ── Body description ──────────────────────────────────────────
          if (description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              child: Text(
                description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  height: 1.6,
                  color: theme.colorScheme.onSurface.withAlpha(200),
                ),
              ),
            ),
          if (description.isEmpty) const SizedBox(height: 10),
        ],
      ),
    );
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
}

// ---------------------------------------------------------------------------
// Media preview (unchanged logic)
// ---------------------------------------------------------------------------

class _SchoolFeedMediaPreview extends StatelessWidget {
  final Map<String, dynamic> post;

  const _SchoolFeedMediaPreview({required this.post});

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).schoolDesk;
    final mediaItems = EventPostMediaItem.parseList(
      post['media'] ??
          post['media_urls'] ??
          post['mediaUrls'] ??
          post['media_url'] ??
          post['mediaUrl'] ??
          post['attachments'],
    );
    if (mediaItems.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(tokens.radius.control),
        child: SizedBox(
          height: 160,
          width: double.infinity,
          child: PageView.builder(
            itemCount: mediaItems.length,
            itemBuilder: (context, index) {
              final item = mediaItems[index];
              return Stack(
                fit: StackFit.expand,
                children: [
                  EventPostMediaPreview(
                    item: item,
                    height: 160,
                    onImageTap: () => openEventPostMediaPreview(context, item),
                  ),
                  if (mediaItems.length > 1)
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.55),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          child: Text(
                            '${index + 1}/${mediaItems.length}',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _FeedMediaTypeChip extends StatelessWidget {
  final String type;
  final Color color;

  const _FeedMediaTypeChip({required this.type, required this.color});

  @override
  Widget build(BuildContext context) {
    final label = type.isEmpty ? 'Media' : type;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_eventPostMediaIcon(label), color: color, size: 13),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
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
    final attendance = dashboard['attendance'] is Map
        ? Map<String, dynamic>.from(dashboard['attendance'] as Map)
        : const <String, dynamic>{};

    return SchoolDeskResponsiveGrid(
      minTileWidth: 160,
      spacing: 12,
      children: [
        _StatCard(
          icon: Icons.how_to_reg_rounded,
          label: 'Attendance',
          value:
              '${_number(child['attendance_pct'] ?? attendance['attendance_pct'])}%',
          gradientColors: const [Color(0xFF0F766E), Color(0xFF14B8A6)],
          route: AppRoutes.parentAttendance,
        ),
        _StatCard(
          icon: Icons.assignment_turned_in_rounded,
          label: 'Homework Due',
          value: _number(child['homework_due'] ?? metrics['open_homework']),
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
          label: 'Messages',
          value: _number(metrics['unread_messages']),
          gradientColors: const [Color(0xFF1D4ED8), Color(0xFF60A5FA)],
          route: AppRoutes.parentTeacherChat,
        ),
      ],
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
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.pushNamed(context, route),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: gradientColors[0].withAlpha(tokens.isDark ? 60 : 50),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(35),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(height: 12),
              SchoolDeskAdaptiveText(
                value,
                maxLines: 1,
                minFontSize: 16,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              SchoolDeskAdaptiveText(
                label,
                maxLines: 1,
                minFontSize: 10,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.white.withAlpha(210),
                  fontWeight: FontWeight.w600,
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
// Quick-access cards — horizontal scroll row
// ---------------------------------------------------------------------------

class _ParentQuickAccessRow extends StatelessWidget {
  const _ParentQuickAccessRow();

  static const _actions = [
    _QuickAction(
      label: 'Attendance',
      icon: Icons.how_to_reg_rounded,
      route: AppRoutes.parentAttendance,
      color: Color(0xFF0F766E),
    ),
    _QuickAction(
      label: 'Homework',
      icon: Icons.assignment_rounded,
      route: AppRoutes.parentHomework,
      color: Color(0xFF7C3AED),
    ),
    _QuickAction(
      label: 'Fees',
      icon: Icons.receipt_long_rounded,
      route: AppRoutes.parentFees,
      color: Color(0xFFEA580C),
    ),
    _QuickAction(
      label: 'Leave',
      icon: Icons.event_busy_rounded,
      route: AppRoutes.parentLeave,
      color: Color(0xFFDC2626),
    ),
    _QuickAction(
      label: 'Messages',
      icon: Icons.chat_bubble_rounded,
      route: AppRoutes.parentTeacherChat,
      color: Color(0xFF1D4ED8),
    ),
    _QuickAction(
      label: 'Calendar',
      icon: Icons.calendar_month_rounded,
      route: AppRoutes.parentCalendar,
      color: Color(0xFF0284C7),
    ),
    _QuickAction(
      label: 'Documents',
      icon: Icons.description_rounded,
      route: AppRoutes.parentDocuments,
      color: Color(0xFF15803D),
    ),
    _QuickAction(
      label: 'Timetable',
      icon: Icons.calendar_view_week_rounded,
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
  final String route;
  final Color color;

  const _QuickAction({
    required this.label,
    required this.icon,
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
                child: Icon(action.icon, color: action.color, size: 20),
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
// Child selector pill (unchanged functionality, improved style)
// ---------------------------------------------------------------------------

class _ParentChildPillSelector extends StatelessWidget {
  final List<Map<String, dynamic>> children;
  final int activeIndex;
  final ValueChanged<int> onChanged;
  final Color color;

  const _ParentChildPillSelector({
    required this.children,
    required this.activeIndex,
    required this.onChanged,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;
    final activeChild = children[activeIndex];

    final pillContent = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, Color.alphaBlend(Colors.white.withAlpha(30), color)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(tokens.radius.pill),
        boxShadow: [
          BoxShadow(
            color: color.withAlpha(80),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(40),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.child_care_rounded,
              color: Colors.white,
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: SchoolDeskAdaptiveText(
              _childSelectorLabel(activeChild),
              maxLines: 1,
              minFontSize: 11,
              style: theme.textTheme.labelLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (children.length > 1) ...[
            const SizedBox(width: 6),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Colors.white,
              size: 20,
            ),
          ],
        ],
      ),
    );

    if (children.length <= 1) return pillContent;

    return PopupMenuButton<int>(
      tooltip: 'Select child',
      onSelected: onChanged,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (context) => [
        for (var i = 0; i < children.length; i++)
          PopupMenuItem(
            value: i,
            child: Row(
              children: [
                Icon(
                  Icons.person_rounded,
                  size: 16,
                  color: i == activeIndex ? color : theme.colorScheme.onSurface,
                ),
                const SizedBox(width: 8),
                Text(
                  _childSelectorLabel(children[i]),
                  style: TextStyle(
                    fontWeight: i == activeIndex
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: i == activeIndex ? color : null,
                  ),
                ),
              ],
            ),
          ),
      ],
      child: pillContent,
    );
  }
}

// ---------------------------------------------------------------------------
// Pure helper functions
// ---------------------------------------------------------------------------

String _childSelectorLabel(Map<String, dynamic> child) {
  final name = _name(child, fallback: 'Student');
  final grade = _firstText(child, ['class', 'class_name', 'grade_name']);
  return grade.isEmpty ? name : '$name ($grade)';
}

String _name(Map<String, dynamic> row, {required String fallback}) {
  for (final key in ['name', 'full_name', 'student_name']) {
    final name = _text(row[key]);
    if (name.isNotEmpty) return name;
  }
  final combined = [
    _text(row['first_name']),
    _text(row['last_name']),
  ].where((part) => part.isNotEmpty).join(' ');
  return combined.isEmpty ? fallback : combined;
}

String _text(dynamic value) => value?.toString().trim() ?? '';

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

String _money(dynamic value) {
  final parsed =
      value is num ? value.toDouble() : double.tryParse(_text(value));
  final amount = parsed ?? 0;
  if (amount >= 100000) return '₹${(amount / 100000).toStringAsFixed(1)}L';
  if (amount >= 1000) return '₹${(amount / 1000).toStringAsFixed(1)}K';
  return '₹${amount.toStringAsFixed(0)}';
}

String _firstText(Map<String, dynamic> row, List<String> keys) {
  for (final key in keys) {
    final text = _text(row[key]);
    if (text.isNotEmpty) return text;
  }
  return '';
}

String _eventPostMediaType(Map<String, dynamic> post) {
  final explicit = _firstText(post, [
    'media_type',
    'mediaType',
    'file_type',
    'fileType',
    'type',
  ]).toLowerCase();
  if (explicit.contains('video')) return 'Video';
  if (explicit.contains('photo')) return 'Photo';
  if (explicit.contains('image')) return 'Photo';

  final media = EventPostMediaItem.parseList(
    post['media'] ??
        post['media_urls'] ??
        post['mediaUrls'] ??
        post['media_url'] ??
        post['mediaUrl'] ??
        post['attachments'],
  );
  if (media.isEmpty) return '';
  return switch (media.first.kind) {
    EventPostMediaKind.video => 'Video',
    EventPostMediaKind.image => 'Photo',
    EventPostMediaKind.pdf || EventPostMediaKind.document => 'Document',
    EventPostMediaKind.media => 'Media',
  };
}

IconData _eventPostMediaIcon(String type) {
  final normalized = type.toLowerCase();
  if (normalized.contains('video')) return Icons.play_circle_fill_rounded;
  if (normalized.contains('photo') || normalized.contains('image')) {
    return Icons.image_rounded;
  }
  return Icons.attach_file_rounded;
}
