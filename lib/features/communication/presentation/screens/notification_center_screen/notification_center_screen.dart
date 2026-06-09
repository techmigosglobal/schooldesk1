import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:schooldesk1/routes/app_routes.dart';
import 'package:schooldesk1/core/services/notification_service.dart';
import 'package:schooldesk1/core/services/notification_route_resolver.dart';
import 'package:schooldesk1/core/theme/app_theme.dart';
import 'package:schooldesk1/core/theme/design_tokens.dart';
import 'package:schooldesk1/core/widgets/dashboard_fab_widget.dart';
import 'package:schooldesk1/core/widgets/admin_navigation.dart';
import 'package:schooldesk1/core/widgets/app_navigation.dart';
import 'package:schooldesk1/core/widgets/erp_module_scaffold.dart';
import 'package:schooldesk1/core/widgets/parent_navigation.dart';
import 'package:schooldesk1/core/widgets/teacher_navigation.dart';

class NotificationCenterScreen extends StatefulWidget {
  final String role;
  const NotificationCenterScreen({super.key, required this.role});

  @override
  State<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  NotificationService? _service;
  bool _loading = true;
  String _parentFilter = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _init();
  }

  Future<void> _init() async {
    try {
      _service = await NotificationService.getInstance();
    } catch (_) {
      // Keep the notification center usable even if the backend is temporarily unavailable.
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<AppNotification> _filtered(String? category) {
    final all = _service?.getNotificationsForRole(widget.role) ?? [];
    if (category == null) return all;
    return all.where((n) => n.category == category).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.role.trim().toLowerCase() == 'parent') {
      return _buildParentNotificationCenter(context);
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF151C26) : AppTheme.background;
    final surfaceColor = isDark ? const Color(0xFF1E2530) : AppTheme.surface;
    final onSurfaceColor = isDark
        ? const Color(0xFFE8EDF2)
        : AppTheme.onSurface;
    final mutedColor = isDark ? const Color(0xFF90A4AE) : AppTheme.muted;

    return SchoolDeskModuleScaffold(
      title: 'Notifications',
      subtitle: '${_roleLabel(widget.role)} alerts and updates',
      drawer: _drawerForRole(),
      actions: [
        TextButton.icon(
          onPressed: () async {
            await _service?.markAllAsRead(widget.role);
            if (mounted) setState(() {});
          },
          icon: const Icon(Icons.done_all_rounded, size: 18),
          label: const Text('Mark all read'),
        ),
      ],
      bottom: TabBar(
        controller: _tabController,
        isScrollable: true,
        labelStyle: GoogleFonts.dmSans(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.dmSans(fontSize: 12),
        labelColor: AppTheme.primary,
        unselectedLabelColor: mutedColor,
        indicatorColor: AppTheme.primary,
        tabs: const [
          Tab(text: 'All'),
          Tab(text: 'Approvals'),
          Tab(text: 'Fees'),
          Tab(text: 'Exams'),
          Tab(text: 'Circulars'),
        ],
      ),
      body: ColoredBox(
        color: bgColor,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildList(
                    null,
                    bgColor,
                    surfaceColor,
                    onSurfaceColor,
                    mutedColor,
                  ),
                  _buildList(
                    NotificationCategory.pendingApproval,
                    bgColor,
                    surfaceColor,
                    onSurfaceColor,
                    mutedColor,
                  ),
                  _buildList(
                    NotificationCategory.feeDue,
                    bgColor,
                    surfaceColor,
                    onSurfaceColor,
                    mutedColor,
                  ),
                  _buildList(
                    NotificationCategory.examReminder,
                    bgColor,
                    surfaceColor,
                    onSurfaceColor,
                    mutedColor,
                  ),
                  _buildList(
                    NotificationCategory.general,
                    bgColor,
                    surfaceColor,
                    onSurfaceColor,
                    mutedColor,
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildParentNotificationCenter(BuildContext context) {
    final tokens = Theme.of(context).schoolDesk;
    final unreadCount = _service?.getUnreadCountForRole('parent') ?? 0;
    final items = _parentFilteredNotifications();
    final horizontal = SchoolDeskResponsive.contentHorizontalPaddingForWidth(
      MediaQuery.sizeOf(context).width,
      tokens.spacing,
    );
    return SchoolDeskModuleScaffold(
      title: 'Notifications',
      subtitle: 'School alerts, fee reminders, and updates',
      drawer: ParentDrawer(selectedIndex: 99, onDestinationSelected: (_) {}),
      actions: [
        IconButton(
          tooltip: 'Refresh notifications',
          icon: const Icon(Icons.refresh_rounded),
          onPressed: _init,
        ),
      ],
      floatingActionButton: const DashboardFabWidget(
        role: DashboardRole.parent,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bodyIsScrollable: true,
      body: Padding(
        padding: EdgeInsets.fromLTRB(
          horizontal,
          tokens.spacing.md,
          horizontal,
          tokens.spacing.xxl,
        ),
        child: _loading
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ParentNotificationFilters(
                    activeFilter: _parentFilter,
                    onChanged: (filter) =>
                        setState(() => _parentFilter = filter),
                  ),
                  SizedBox(height: tokens.spacing.lg),
                  _ParentUnreadSummaryCard(unreadCount: unreadCount),
                  SizedBox(height: tokens.spacing.lg),
                  Text(
                    'Today',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: tokens.spacing.sm),
                  if (items.isEmpty)
                    _ParentNotificationEmptyCard(filter: _parentFilter)
                  else
                    for (final item in items) ...[
                      _ParentNotificationCard(
                        notification: item,
                        icon: _parentNotificationIcon(item),
                        color: _parentNotificationColor(item),
                        onTap: () => _openNotification(item),
                      ),
                      SizedBox(height: tokens.spacing.sm),
                    ],
                ],
              ),
      ),
    );
  }

  List<AppNotification> _parentFilteredNotifications() {
    final items = _service?.getNotificationsForRole('parent') ?? const [];
    switch (_parentFilter) {
      case 'unread':
        return items.where((item) => !item.isRead).toList();
      case 'fees':
        return items
            .where((item) => item.category == NotificationCategory.feeDue)
            .toList();
      case 'academics':
        return items.where(_isAcademicParentNotification).toList();
      case 'all':
      default:
        return items;
    }
  }

  bool _isAcademicParentNotification(AppNotification item) {
    if (item.category == NotificationCategory.examReminder ||
        item.category == NotificationCategory.pendingApproval) {
      return true;
    }
    final haystack = '${item.title} ${item.body}'.toLowerCase();
    return haystack.contains('homework') ||
        haystack.contains('attendance') ||
        haystack.contains('academ') ||
        haystack.contains('leave') ||
        haystack.contains('exam');
  }

  Future<void> _openNotification(AppNotification notif) async {
    await _service?.markAsRead(notif.id);
    if (mounted) setState(() {});
    if (!mounted) return;
    final target = NotificationRouteResolver.resolve(
      data: notif.routingData,
      currentRole: widget.role,
    );
    if (target.route != AppRoutes.notificationCenter) {
      await Navigator.of(
        context,
      ).pushNamed(target.route, arguments: target.arguments);
    }
  }

  IconData _parentNotificationIcon(AppNotification item) {
    final text = '${item.title} ${item.body}'.toLowerCase();
    if (item.category == NotificationCategory.feeDue || text.contains('fee')) {
      return Icons.account_balance_wallet_rounded;
    }
    if (text.contains('homework')) return Icons.assignment_rounded;
    if (text.contains('leave')) return Icons.verified_user_rounded;
    if (text.contains('attendance')) return Icons.bar_chart_rounded;
    return Icons.campaign_rounded;
  }

  Color _parentNotificationColor(AppNotification item) {
    final text = '${item.title} ${item.body}'.toLowerCase();
    if (item.category == NotificationCategory.feeDue || text.contains('fee')) {
      return const Color(0xFFEA580C);
    }
    if (text.contains('homework')) return const Color(0xFF2563EB);
    if (text.contains('leave')) return const Color(0xFF16A34A);
    if (text.contains('attendance')) return const Color(0xFF16A34A);
    return const Color(0xFF2563EB);
  }

  Widget _drawerForRole() {
    switch (widget.role.trim().toLowerCase()) {
      case 'principal':
        return PrincipalDrawer(
          selectedIndex: 99,
          onDestinationSelected: (_) {},
        );
      case 'teacher':
        return TeacherDrawer(selectedIndex: 99, onDestinationSelected: (_) {});
      case 'parent':
        return ParentDrawer(selectedIndex: 99, onDestinationSelected: (_) {});
      case 'admin':
      default:
        return AdminDrawer(selectedIndex: 99, onDestinationSelected: (_) {});
    }
  }

  String _roleLabel(String role) {
    switch (role.trim().toLowerCase()) {
      case 'principal':
        return 'Principal';
      case 'teacher':
        return 'Teacher';
      case 'parent':
        return 'Parent';
      case 'admin':
      default:
        return 'Admin';
    }
  }

  Widget _buildList(
    String? category,
    Color bgColor,
    Color surfaceColor,
    Color onSurfaceColor,
    Color mutedColor,
  ) {
    final items = _filtered(category);
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_none_rounded, size: 48, color: mutedColor),
            const SizedBox(height: 12),
            Text(
              'No notifications',
              style: GoogleFonts.dmSans(
                fontSize: 15,
                color: mutedColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) =>
          _buildNotifCard(items[i], surfaceColor, onSurfaceColor, mutedColor),
    );
  }

  Widget _buildNotifCard(
    AppNotification notif,
    Color surfaceColor,
    Color onSurfaceColor,
    Color mutedColor,
  ) {
    final categoryIcon = _getCategoryIcon(notif.category);
    final categoryColor = _getCategoryColor(notif.category);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unreadBg = isDark
        ? const Color(0xFF1A3A5C)
        : AppTheme.primaryContainer;
    final outlineColor = isDark
        ? const Color(0xFF2D3748)
        : AppTheme.outlineVariant;

    return GestureDetector(
      onTap: () async {
        await _service?.markAsRead(notif.id);
        if (mounted) setState(() {});
        if (!mounted) return;
        final target = NotificationRouteResolver.resolve(
          data: notif.routingData,
          currentRole: widget.role,
        );
        if (target.route != AppRoutes.notificationCenter) {
          await Navigator.of(
            context,
          ).pushNamed(target.route, arguments: target.arguments);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: notif.isRead ? surfaceColor : unreadBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: notif.isRead
                ? outlineColor
                : AppTheme.primaryLight.withAlpha(80),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: categoryColor.withAlpha(30),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(categoryIcon, color: categoryColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notif.title,
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            fontWeight: notif.isRead
                                ? FontWeight.w500
                                : FontWeight.w700,
                            color: onSurfaceColor,
                          ),
                        ),
                      ),
                      if (!notif.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: categoryColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notif.body,
                    style: GoogleFonts.dmSans(fontSize: 12, color: mutedColor),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _buildPriorityChip(notif.priority),
                      const Spacer(),
                      Text(
                        _formatTime(notif.timestamp),
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          color: mutedColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriorityChip(NotificationPriority priority) {
    final label = priority == NotificationPriority.high
        ? 'High'
        : priority == NotificationPriority.medium
        ? 'Medium'
        : 'Low';
    final color = priority == NotificationPriority.high
        ? AppTheme.error
        : priority == NotificationPriority.medium
        ? AppTheme.warning
        : AppTheme.success;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: GoogleFonts.dmSans(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case NotificationCategory.pendingApproval:
        return Icons.pending_actions_rounded;
      case NotificationCategory.feeDue:
        return Icons.account_balance_wallet_rounded;
      case NotificationCategory.examReminder:
        return Icons.quiz_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case NotificationCategory.pendingApproval:
        return AppTheme.warning;
      case NotificationCategory.feeDue:
        return AppTheme.error;
      case NotificationCategory.examReminder:
        return AppTheme.primary;
      default:
        return AppTheme.muted;
    }
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    // Handle future timestamps gracefully
    if (diff.isNegative) return 'Just now';
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('dd MMM').format(dt);
  }
}

class _ParentNotificationFilters extends StatelessWidget {
  final String activeFilter;
  final ValueChanged<String> onChanged;

  const _ParentNotificationFilters({
    required this.activeFilter,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final filters = const [
      ('all', 'All', 72.0),
      ('unread', 'Unread', 86.0),
      ('fees', 'Fees', 76.0),
      ('academics', 'Academics', 100.0),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 8.0;
        const baseWidth = 72.0 + 86.0 + 76.0 + 100.0;
        final availableForChips = constraints.maxWidth - (gap * 3);
        final scale = availableForChips < baseWidth
            ? (availableForChips / baseWidth).clamp(0.82, 1.0)
            : 1.0;
        return Row(
          children: [
            for (var index = 0; index < filters.length; index++) ...[
              SizedBox(
                width: filters[index].$3 * scale,
                child: _ParentFilterPill(
                  label: filters[index].$2,
                  selected: activeFilter == filters[index].$1,
                  onTap: () => onChanged(filters[index].$1),
                ),
              ),
              if (index != filters.length - 1) const SizedBox(width: gap),
            ],
          ],
        );
      },
    );
  }
}

class _ParentFilterPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ParentFilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;
    const green = Color(0xFF1A6B4A);
    return InkWell(
      borderRadius: BorderRadius.circular(tokens.radius.pill),
      onTap: onTap,
      child: AnimatedContainer(
        duration: tokens.motion.fast,
        constraints: const BoxConstraints(minHeight: 40),
        padding: EdgeInsets.symmetric(horizontal: tokens.spacing.sm),
        decoration: BoxDecoration(
          color: selected ? green : tokens.panelMuted,
          borderRadius: BorderRadius.circular(tokens.radius.pill),
          border: Border.all(color: selected ? green : tokens.panelBorder),
        ),
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            style: theme.textTheme.labelLarge?.copyWith(
              color: selected ? Colors.white : theme.colorScheme.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _ParentUnreadSummaryCard extends StatelessWidget {
  final int unreadCount;

  const _ParentUnreadSummaryCard({required this.unreadCount});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;
    const green = Color(0xFF16A34A);
    return Container(
      padding: EdgeInsets.all(tokens.spacing.lg),
      decoration: BoxDecoration(
        color: tokens.panel,
        borderRadius: BorderRadius.circular(tokens.radius.card),
        border: Border.all(color: tokens.panelBorder),
        boxShadow: tokens.elevation.card,
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: green.withAlpha(18),
              borderRadius: BorderRadius.circular(tokens.radius.card),
            ),
            child: const Icon(
              Icons.notifications_none_rounded,
              color: green,
              size: 32,
            ),
          ),
          SizedBox(width: tokens.spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'You have $unreadCount unread notification${unreadCount == 1 ? '' : 's'}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: tokens.spacing.xs),
                Text(
                  "Stay updated with your child's activities",
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: tokens.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: tokens.textMuted),
        ],
      ),
    );
  }
}

class _ParentNotificationEmptyCard extends StatelessWidget {
  final String filter;

  const _ParentNotificationEmptyCard({required this.filter});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;
    return Container(
      padding: EdgeInsets.all(tokens.spacing.lg),
      decoration: BoxDecoration(
        color: tokens.panel,
        borderRadius: BorderRadius.circular(tokens.radius.card),
        border: Border.all(color: tokens.panelBorder),
      ),
      child: Column(
        children: [
          Icon(Icons.notifications_none_rounded, color: tokens.textMuted),
          SizedBox(height: tokens.spacing.sm),
          Text(
            filter == 'all' ? 'No notifications' : 'No matching notifications',
            style: theme.textTheme.labelLarge?.copyWith(
              color: tokens.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _ParentNotificationCard extends StatelessWidget {
  final AppNotification notification;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ParentNotificationCard({
    required this.notification,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;
    return InkWell(
      borderRadius: BorderRadius.circular(tokens.radius.card),
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(tokens.spacing.md),
        decoration: BoxDecoration(
          color: tokens.panel,
          borderRadius: BorderRadius.circular(tokens.radius.card),
          border: Border.all(color: tokens.panelBorder),
          boxShadow: tokens.elevation.card,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withAlpha(18),
                borderRadius: BorderRadius.circular(tokens.radius.card),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            SizedBox(width: tokens.spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      SizedBox(width: tokens.spacing.sm),
                      Text(
                        _formatParentTimestamp(notification.timestamp),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: tokens.textMuted,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: tokens.spacing.xs),
                  Text(
                    notification.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: tokens.textMuted,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            if (!notification.isRead) ...[
              SizedBox(width: tokens.spacing.sm),
              Container(
                width: 12,
                height: 12,
                margin: const EdgeInsets.only(top: 26),
                decoration: const BoxDecoration(
                  color: Color(0xFF2563EB),
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _formatParentTimestamp(DateTime timestamp) {
  final now = DateTime.now();
  if (_sameDate(now, timestamp)) return DateFormat('hh:mm a').format(timestamp);
  if (_sameDate(now.subtract(const Duration(days: 1)), timestamp)) {
    return 'Yesterday';
  }
  return DateFormat('d MMM yyyy').format(timestamp);
}

bool _sameDate(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}
