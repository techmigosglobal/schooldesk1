import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';

import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/theme/design_tokens.dart';
import 'package:schooldesk1/core/widgets/erp_components.dart';
import 'package:schooldesk1/core/widgets/erp_module_scaffold.dart';
import 'package:schooldesk1/core/widgets/parent_navigation.dart';
import 'package:schooldesk1/core/utils/extensions.dart';

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
      // Only load what the parent feed actually shows: linked students and
      // school event/activity posts. Homework and lesson planner data are
      // available from their dedicated parent screens, not this feed.
      final results = await Future.wait([
        api.getMyStudents(),
        api.dio
            .get('/event-posts/home-feed')
            .catchError(
              (_) => Response(
                requestOptions: RequestOptions(path: ''),
                data: [],
              ),
            ),
      ]);

      if (!mounted) return;
      final children = (results[0] as List)
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();

      final res1 = results[1] is Response
          ? (results[1] as Response).data
          : results[1];
      final rawEvents = res1 is List
          ? res1
          : (res1 is Map ? (res1['data'] as List? ?? []) : []);

      final List<Map<String, dynamic>> feedItems = [];
      for (final ev in rawEvents) {
        feedItems.add({
          'title': ev['title'] ?? 'School Post',
          'description': ev['description'] ?? '',
          'date': ev['event_date'] ?? ev['created_at'],
          'sort_date': ev['created_at'] ?? '',
          'category': ev['category'] ?? '',
          'author': ev['author'] ?? ev['posted_by'] ?? '',
        });
      }
      feedItems.sort(
        (a, b) => (b['sort_date']?.toString() ?? '').compareTo(
          a['sort_date']?.toString() ?? '',
        ),
      );

      setState(() {
        _children = children;
        _eventPosts = feedItems;
        if (_activeChildIndex >= _children.length) _activeChildIndex = 0;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load school feed.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SchoolDeskModuleScaffold(
      title: 'School Feed',
      subtitle: 'Posts and activity from your school',
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
        message: 'Loading school feed…',
      );
    } else if (_error != null) {
      child = SchoolDeskStatusPanel.error(
        title: 'Feed unavailable',
        message: _error!,
        onAction: _loadDashboardData,
      );
    } else if (_children.isEmpty) {
      child = const SchoolDeskStatusPanel.empty(
        title: 'No linked students',
        message: 'Ask the school admin to link students to this parent account.',
      );
    } else {
      child = _ParentFeedView(
        children: _children,
        activeChildIndex: _activeChildIndex,
        onChildSelected: (index) => setState(() => _activeChildIndex = index),
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
}

// ---------------------------------------------------------------------------
// Feed view — the only screen content for parents.
// Design reference: Google Classroom parent/guardian summary view.
// Child selector pill at top, scrollable post-card feed below. Nothing else.
// ---------------------------------------------------------------------------

class _ParentFeedView extends StatelessWidget {
  final List<Map<String, dynamic>> children;
  final int activeChildIndex;
  final ValueChanged<int> onChildSelected;
  final List<dynamic> eventPosts;

  const _ParentFeedView({
    required this.children,
    required this.activeChildIndex,
    required this.onChildSelected,
    required this.eventPosts,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).schoolDesk;
    final parentColor = tokens.roleColor(SchoolDeskRole.parent);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Child selector pill — same green pill from before
        _ParentChildPillSelector(
          children: children,
          activeIndex: activeChildIndex,
          onChanged: onChildSelected,
          color: parentColor,
        ),
        SizedBox(height: tokens.spacing.lg),
        // Post feed — the only content
        _SchoolFeedList(eventPosts: eventPosts),
      ],
    );
  }
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

String _firstText(Map<String, dynamic> row, List<String> keys) {
  for (final key in keys) {
    final text = _text(row[key]);
    if (text.isNotEmpty) return text;
  }
  return '';
}
