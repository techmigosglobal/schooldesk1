import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/services/parent_child_selection_service.dart';
import 'package:schooldesk1/core/theme/design_tokens.dart';
import 'package:schooldesk1/core/widgets/erp_components.dart';
import 'package:schooldesk1/core/widgets/erp_module_scaffold.dart';
import 'package:schooldesk1/core/widgets/event_post_media_preview.dart';
import 'package:schooldesk1/core/widgets/parent_navigation.dart';
import 'package:schooldesk1/core/utils/event_post_media_parser.dart';
import 'package:schooldesk1/core/utils/extensions.dart';
import 'package:schooldesk1/routes/app_routes.dart';
import 'package:schooldesk1/features/dashboard/presentation/widgets/todays_highlights_card.dart';

class ParentDashboardScreen extends StatefulWidget {
  const ParentDashboardScreen({super.key});

  @override
  State<ParentDashboardScreen> createState() => _ParentDashboardScreenState();
}

class _ParentDashboardScreenState extends State<ParentDashboardScreen> {
  int _selectedNavIndex = 0;
  int _activeChildIndex = 0;
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _dashboard = const {};
  List<Map<String, dynamic>> _children = const [];
  List<dynamic> _eventPosts = [];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = BackendApiClient.instance;
      final results = await Future.wait([
        api.getDashboard('parent'),
        api.getMyStudents(),
        api.getHomeFeedEventPosts().catchError(
          (_) => const <Map<String, dynamic>>[],
        ),
      ]);

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

      final rawEvents = (results[2] as List).whereType<Map<String, dynamic>>();

      final List<Map<String, dynamic>> feedItems = [];
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
          // Keep raw event type for image detection
          'media_type': ev['media_type'] ?? ev['mediaType'] ?? '',
          'destinations': ev['destinations'] ?? '',
        });
      }
      feedItems.sort(
        (a, b) => (b['sort_date']?.toString() ?? '').compareTo(
          a['sort_date']?.toString() ?? '',
        ),
      );

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
          onPressed: _loadDashboardData,
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
}

// ---------------------------------------------------------------------------
// Feed view — the only screen content for parents.
// Design reference: Google Classroom parent/guardian summary view.
// Child selector pill at top, scrollable post-card feed below. Nothing else.
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
        const TodaysHighlightsCard(role: 'parent'),
        SizedBox(height: tokens.spacing.lg),
        Text(
          'School Feed',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        SizedBox(height: tokens.spacing.sm),
        _SchoolFeedList(eventPosts: eventPosts),
        SizedBox(height: tokens.spacing.lg),
        _ParentChildPillSelector(
          children: children,
          activeIndex: activeChildIndex,
          onChanged: onChildSelected,
          color: parentColor,
        ),
        SizedBox(height: tokens.spacing.lg),
        _ParentSummaryGrid(dashboard: dashboard, child: activeChild),
        SizedBox(height: tokens.spacing.lg),
        const _ParentWorkflowShortcuts(),
      ],
    );
  }
}

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
      minTileWidth: 180,
      spacing: 12,
      children: [
        _SummaryTile(
          icon: Icons.how_to_reg_rounded,
          label: 'Attendance',
          value:
              '${_number(child['attendance_pct'] ?? attendance['attendance_pct'])}%',
          route: AppRoutes.parentAttendance,
        ),
        _SummaryTile(
          icon: Icons.assignment_turned_in_rounded,
          label: 'Homework Due',
          value: _number(child['homework_due'] ?? metrics['open_homework']),
          route: AppRoutes.parentHomework,
        ),
        _SummaryTile(
          icon: Icons.account_balance_wallet_rounded,
          label: 'Fees Due',
          value: _money(
            child['pending_fee_balance'] ?? metrics['pending_fee_balance'],
          ),
          route: AppRoutes.parentFees,
        ),
        _SummaryTile(
          icon: Icons.chat_rounded,
          label: 'Messages',
          value: _number(metrics['unread_messages']),
          route: AppRoutes.parentTeacherChat,
        ),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String route;

  const _SummaryTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.route,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;
    final color = tokens.roleColor(SchoolDeskRole.parent);
    return InkWell(
      borderRadius: BorderRadius.circular(tokens.radius.card),
      onTap: () => Navigator.pushNamed(context, route),
      child: Container(
        padding: EdgeInsets.all(tokens.spacing.md),
        decoration: BoxDecoration(
          color: tokens.panel,
          borderRadius: BorderRadius.circular(tokens.radius.card),
          border: Border.all(color: tokens.panelBorder),
          boxShadow: tokens.elevation.card,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withAlpha(24),
                borderRadius: BorderRadius.circular(tokens.radius.control),
              ),
              child: Icon(icon, color: color),
            ),
            SizedBox(width: tokens.spacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SchoolDeskAdaptiveText(
                    value,
                    maxLines: 1,
                    minFontSize: 15,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SchoolDeskAdaptiveText(
                    label,
                    maxLines: 1,
                    minFontSize: 10,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: tokens.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ParentWorkflowShortcuts extends StatelessWidget {
  const _ParentWorkflowShortcuts();

  @override
  Widget build(BuildContext context) {
    final actions = [
      _ShortcutAction(
        'Attendance',
        Icons.how_to_reg_rounded,
        AppRoutes.parentAttendance,
      ),
      _ShortcutAction(
        'Homework',
        Icons.assignment_rounded,
        AppRoutes.parentHomework,
      ),
      _ShortcutAction(
        'Pay Fees',
        Icons.receipt_long_rounded,
        AppRoutes.parentFees,
      ),
      _ShortcutAction('Leave', Icons.event_busy_rounded, AppRoutes.parentLeave),
      _ShortcutAction(
        'PTM',
        Icons.family_restroom_rounded,
        AppRoutes.parentTeacherChat,
      ),
      _ShortcutAction(
        'Documents',
        Icons.description_rounded,
        AppRoutes.parentDocuments,
      ),
    ];
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;
    return Wrap(
      spacing: tokens.spacing.sm,
      runSpacing: tokens.spacing.sm,
      children: [
        for (final action in actions)
          ActionChip(
            avatar: Icon(
              action.icon,
              size: 18,
              color: theme.colorScheme.primary,
            ),
            label: Text(
              action.label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
            backgroundColor: theme.colorScheme.surface,
            side: BorderSide(color: theme.colorScheme.outlineVariant),
            onPressed: () => Navigator.pushNamed(context, action.route),
          ),
      ],
    );
  }
}

class _ShortcutAction {
  final String label;
  final IconData icon;
  final String route;

  const _ShortcutAction(this.label, this.icon, this.route);
}

// ---------------------------------------------------------------------------
// Child selector pill (unchanged design)
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
    final child = Container(
      constraints: const BoxConstraints(minHeight: 42),
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.md,
        vertical: tokens.spacing.sm,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(tokens.radius.pill),
        boxShadow: tokens.elevation.card,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: SchoolDeskAdaptiveText(
              _childSelectorLabel(activeChild),
              maxLines: 1,
              minFontSize: 11,
              style: theme.textTheme.labelLarge?.copyWith(
                color: context.appTheme.surface,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          SizedBox(width: tokens.spacing.xs),
          const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Colors.white,
            size: 20,
          ),
        ],
      ),
    );
    if (children.length <= 1) return child;
    return PopupMenuButton<int>(
      tooltip: 'Select child',
      onSelected: onChanged,
      itemBuilder: (context) => [
        for (var index = 0; index < children.length; index++)
          PopupMenuItem(
            value: index,
            child: Text(_childSelectorLabel(children[index])),
          ),
      ],
      child: child,
    );
  }
}

// ---------------------------------------------------------------------------
// Google Classroom-inspired post feed
// ---------------------------------------------------------------------------

/// Feed widget — shows empty state or a list of post cards.
class _SchoolFeedList extends StatelessWidget {
  final List<dynamic> eventPosts;

  const _SchoolFeedList({required this.eventPosts});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;
    final parentColor = tokens.roleColor(SchoolDeskRole.parent);

    if (eventPosts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 64),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: parentColor.withAlpha(20),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.campaign_outlined,
                  size: 36,
                  color: parentColor,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'No posts yet',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'School events and activity posts will\nappear here once published.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: tokens.textMuted,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final post in eventPosts)
          _PostCard(
            post: Map<String, dynamic>.from(
              post is Map ? post : <String, dynamic>{},
            ),
          ),
      ],
    );
  }
}

/// A single activity post card — Google Classroom post card style.
/// Header: coloured tinted background + circular icon avatar + title/meta.
/// Body: description text with comfortable line-height.
class _PostCard extends StatelessWidget {
  final Map<String, dynamic> post;

  const _PostCard({required this.post});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;
    final parentColor = tokens.roleColor(SchoolDeskRole.parent);

    final title = _text(post['title']).isEmpty
        ? 'School Post'
        : _text(post['title']);
    final description = _text(post['description']);
    final rawDate = _text(post['date']);
    final category = _text(post['category']);
    final author = _text(post['author']);
    final formattedDate = _formatPostDate(rawDate);
    final mediaType = _eventPostMediaType(post);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: tokens.panel,
        borderRadius: BorderRadius.circular(tokens.radius.card),
        border: Border.all(color: tokens.panelBorder),
        boxShadow: tokens.elevation.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: tinted background + icon avatar + title + date
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: BoxDecoration(
              color: parentColor.withAlpha(16),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(tokens.radius.card),
                topRight: Radius.circular(tokens.radius.card),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Circular icon avatar
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: parentColor,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.campaign_rounded,
                    color: Colors.white,
                    size: 20,
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
                          height: 1.3,
                        ),
                      ),
                      if (author.isNotEmpty || category.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          [
                            if (author.isNotEmpty) author,
                            if (category.isNotEmpty) category,
                          ].join(' • '),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: tokens.textMuted,
                          ),
                        ),
                      ],
                      if (mediaType.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _FeedMediaTypeChip(type: mediaType),
                      ],
                    ],
                  ),
                ),
                if (formattedDate.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 8, top: 2),
                    child: Text(
                      formattedDate,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: tokens.textMuted,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          _SchoolFeedMediaPreview(post: post),
          // Body: description
          if (description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Text(
                description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  height: 1.6,
                  color: theme.colorScheme.onSurface.withAlpha(210),
                ),
              ),
            ),
          if (description.isEmpty) const SizedBox(height: 12),
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
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(tokens.radius.control),
        child: SizedBox(
          height: 210,
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
                    height: 210,
                    onImageTap: () => openEventPostMediaPreview(context, item),
                  ),
                  if (mediaItems.length > 1)
                    Positioned(
                      right: 10,
                      bottom: 10,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.58),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          child: Text(
                            '${index + 1}/${mediaItems.length}',
                            style: Theme.of(context).textTheme.labelSmall
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

  const _FeedMediaTypeChip({required this.type});

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).schoolDesk;
    final color = tokens.roleColor(SchoolDeskRole.parent);
    final label = type.isEmpty ? 'Media' : type;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(tokens.radius.pill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_eventPostMediaIcon(label), color: Colors.white, size: 14),
            const SizedBox(width: 5),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pure helper functions (no widgets)
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
  final parsed = value is num
      ? value.toDouble()
      : double.tryParse(_text(value));
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
