import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:schooldesk1/routes/app_routes.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/services/notification_service.dart';
import 'package:schooldesk1/core/services/notification_route_resolver.dart';
import 'package:schooldesk1/core/services/push_notification_service.dart';

import 'package:schooldesk1/core/navigation/role_nav_indices.dart';
import 'package:schooldesk1/core/theme/design_tokens.dart';
import 'package:schooldesk1/core/widgets/dashboard_fab_widget.dart';
import 'package:schooldesk1/core/widgets/app_navigation.dart';
import 'package:schooldesk1/core/widgets/erp_module_scaffold.dart';
import 'package:schooldesk1/core/widgets/parent_navigation.dart';
import 'package:schooldesk1/core/widgets/teacher_navigation.dart';
import 'package:schooldesk1/core/utils/extensions.dart';
import 'package:schooldesk1/core/desktop/desktop_responsive_breakpoints.dart';
import 'package:schooldesk1/core/widgets/desktop_screen_wrapper.dart';

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
  bool _markingAllRead = false;
  bool _runningPushDiagnostic = false;
  String? _error;
  String _parentFilter = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: _tabCountForRole(widget.role),
      vsync: this,
    );
    _init();
  }

  Future<void> _init({bool forceRefresh = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _service = await NotificationService.getInstance();
      if (forceRefresh || widget.role.trim().toLowerCase() == 'principal') {
        await _service?.refresh();
      }
    } on Object catch (error) {
      _error = error.toString();
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
    if (widget.role.trim().toLowerCase() == 'principal') {
      return all.where((n) => _principalCategory(n) == category).toList();
    }
    return all.where((n) => n.category == category).toList();
  }

  int _tabCountForRole(String role) {
    return switch (role.trim().toLowerCase()) {
      'teacher' => 5,
      'principal' => 6,
      _ => 5,
    };
  }

  @override
  Widget build(BuildContext context) {


  final isDesktop = DesktopBreakpoints.isDesktopWidth(


        MediaQuery.sizeOf(context).width,


      );


      if (isDesktop) {


        return DesktopScreenWrapper(


          breadcrumbs: ['Communication', 'Notifications'],


          title: 'Notifications',


          actions: const [],


          child: Card(


            elevation: 0,


            child: Padding(


              padding: const EdgeInsets.all(32),


              child: Center(


                child: Column(


                  mainAxisSize: MainAxisSize.min,


                  children: [


                    Icon(Icons.desktop_windows_rounded, size: 48, color: Theme.of(context).colorScheme.primary),


                    const SizedBox(height: 16),


                    Text('Notifications', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),


                    const SizedBox(height: 8),


                    Text('Desktop view coming soon', style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.5))),


                  ],


                ),


              ),


            ),


          ),


        );


      }

    if (widget.role.trim().toLowerCase() == 'parent') {
      return _buildParentNotificationCenter(context);
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark
        ? const Color(0xFF151C26)
        : context.appTheme.background;
    final surfaceColor = isDark
        ? const Color(0xFF1E2530)
        : context.appTheme.surface;
    final onSurfaceColor = isDark
        ? const Color(0xFFE8EDF2)
        : context.appTheme.onSurface;
    final mutedColor = isDark
        ? const Color(0xFF90A4AE)
        : context.appTheme.muted;

    return SchoolDeskModuleScaffold(
      title: 'Notifications',
      subtitle: '${_roleLabel(widget.role)} alerts and updates',
      drawer: _drawerForRole(),
      showGlobalToolbarActions: false,
      actions: _notificationHeaderActions(context, widget.role),
      bottom: TabBar(
        controller: _tabController,
        isScrollable: true,
        labelStyle: GoogleFonts.dmSans(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.dmSans(fontSize: 12),
        labelColor: context.appTheme.primary,
        unselectedLabelColor: mutedColor,
        indicatorColor: context.appTheme.primary,
        tabs: _tabsForRole(widget.role),
      ),
      body: ColoredBox(
        color: bgColor,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                controller: _tabController,
                children: widget.role.trim().toLowerCase() == 'teacher'
                    ? [
                        _buildList(
                          null,
                          bgColor,
                          surfaceColor,
                          onSurfaceColor,
                          mutedColor,
                        ),
                        _buildList(
                          NotificationCategory.homework,
                          bgColor,
                          surfaceColor,
                          onSurfaceColor,
                          mutedColor,
                        ),
                        _buildList(
                          NotificationCategory.birthday,
                          bgColor,
                          surfaceColor,
                          onSurfaceColor,
                          mutedColor,
                        ),
                        _buildList(
                          NotificationCategory.healthAlert,
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
                      ]
                    : widget.role.trim().toLowerCase() == 'principal'
                    ? [
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
                          NotificationCategory.birthday,
                          bgColor,
                          surfaceColor,
                          onSurfaceColor,
                          mutedColor,
                        ),
                        _buildList(
                          NotificationCategory.healthAlert,
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
                          NotificationCategory.event,
                          bgColor,
                          surfaceColor,
                          onSurfaceColor,
                          mutedColor,
                        ),
                      ]
                    : [
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

  List<Tab> _tabsForRole(String role) {
    return switch (role.trim().toLowerCase()) {
      'teacher' => const [
        Tab(text: 'All'),
        Tab(text: 'Homework'),
        Tab(text: 'Birthdays'),
        Tab(text: 'Health'),
        Tab(text: 'Circulars'),
      ],
      'principal' => const [
        Tab(text: 'All'),
        Tab(text: 'Approvals'),
        Tab(text: 'Birthdays'),
        Tab(text: 'Health'),
        Tab(text: 'Fees'),
        Tab(text: 'Events'),
      ],
      _ => const [
        Tab(text: 'All'),
        Tab(text: 'Approvals'),
        Tab(text: 'Fees'),
        Tab(text: 'Events'),
        Tab(text: 'Circulars'),
      ],
    };
  }

  String _principalCategory(AppNotification notification) {
    final text =
        '${notification.title} ${notification.body} ${notification.route} ${notification.referenceType}'
            .toLowerCase();
    if (notification.category == NotificationCategory.pendingApproval ||
        text.contains('approval') ||
        text.contains('approve') ||
        text.contains('leave request')) {
      return NotificationCategory.pendingApproval;
    }
    if (notification.category == NotificationCategory.feeDue ||
        text.contains('fee') ||
        text.contains('payment')) {
      return NotificationCategory.feeDue;
    }
    if (notification.category == NotificationCategory.event ||
        text.contains('event') ||
        text.contains('calendar')) {
      return NotificationCategory.event;
    }
    return notification.category;
  }

  Widget _buildParentNotificationCenter(BuildContext context) {
    final tokens = Theme.of(context).schoolDesk;
    final items = _parentFilteredNotifications();
    final horizontal = SchoolDeskResponsive.contentHorizontalPaddingForWidth(
      MediaQuery.sizeOf(context).width,
      tokens.spacing,
    );
    return SchoolDeskModuleScaffold(
      title: 'Notifications',
      subtitle: 'School alerts, fee reminders, and updates',
      drawer: ParentDrawer(
        selectedIndex: ParentNav.notices,
        onDestinationSelected: (_) {},
      ),
      showGlobalToolbarActions: false,
      actions: _notificationHeaderActions(context, 'parent'),
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

  List<Widget> _notificationHeaderActions(BuildContext context, String role) {
    final unreadCount = _service?.getUnreadCountForRole(role) ?? 0;
    final canMarkAll = unreadCount > 0 && !_loading && !_markingAllRead;
    final compact = MediaQuery.sizeOf(context).width < 700;
    final refresh = IconButton(
      tooltip: 'Refresh notifications',
      onPressed: _loading ? null : () => _init(forceRefresh: true),
      icon: const Icon(Icons.refresh_rounded),
    );
    final markIcon = _markingAllRead
        ? const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(Icons.done_all_rounded);

    if (compact) {
      return [
        refresh,
        IconButton(
          tooltip: 'Mark all as read',
          onPressed: canMarkAll ? () => _markAllAsRead(role) : null,
          icon: markIcon,
        ),
      ];
    }

    return [
      refresh,
      TextButton.icon(
        onPressed: canMarkAll ? () => _markAllAsRead(role) : null,
        icon: markIcon,
        label: const Text('Mark all read'),
      ),
    ];
  }

  Future<void> _markAllAsRead(String role) async {
    if (_markingAllRead || _loading) return;
    final unreadCount = _service?.getUnreadCountForRole(role) ?? 0;
    if (unreadCount == 0) return;
    setState(() => _markingAllRead = true);
    try {
      await _service?.markAllAsRead(role);
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not mark all notifications as read: $error'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _markingAllRead = false);
    }
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
    if (item.category == NotificationCategory.pendingApproval) {
      return true;
    }
    final haystack = '${item.title} ${item.body}'.toLowerCase();
    return haystack.contains('homework') ||
        haystack.contains('attendance') ||
        haystack.contains('academ') ||
        haystack.contains('leave') ||
        haystack.contains('exam');
  }

  IconData _parentNotificationIcon(AppNotification item) {
    final text = '${item.title} ${item.body}'.toLowerCase();
    if (item.category == NotificationCategory.feeDue || text.contains('fee')) {
      return Icons.account_balance_wallet_rounded;
    }
    if (item.category == NotificationCategory.birthday) {
      return Icons.cake_rounded;
    }
    if (item.category == NotificationCategory.healthAlert) {
      return Icons.medical_services_rounded;
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
    if (item.category == NotificationCategory.birthday) {
      return const Color(0xFFE91E63);
    }
    if (item.category == NotificationCategory.healthAlert) {
      return const Color(0xFFFF9800);
    }
    if (text.contains('homework')) return const Color(0xFF2563EB);
    if (text.contains('leave')) return const Color(0xFF16A34A);
    if (text.contains('attendance')) return const Color(0xFF16A34A);
    return const Color(0xFF2563EB);
  }

  Widget _drawerForRole() {
    switch (widget.role.trim().toLowerCase()) {
      case 'principal':
        return PrincipalDrawer(onDestinationSelected: (_) {});
      case 'super_admin':
        return SuperAdminDrawer(onDestinationSelected: (_) {});
      case 'teacher':
        return TeacherDrawer(onDestinationSelected: (_) {});
      case 'parent':
        return ParentDrawer(onDestinationSelected: (_) {});
      case 'admin':
      default:
        return PrincipalDrawer(
          selectedIndex: PrincipalNav.messages,
          onDestinationSelected: (_) {},
        );
    }
  }

  String _roleLabel(String role) {
    switch (role.trim().toLowerCase()) {
      case 'principal':
        return 'Principal';
      case 'super_admin':
        return 'Super Admin';
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
    return RefreshIndicator(
      onRefresh: () => _init(forceRefresh: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _NotificationSummaryPanel(
            allCount: _filtered(null).length,
            visibleCount: items.length,
            unreadCount: _service?.getUnreadCountForRole(widget.role) ?? 0,
            categoryLabel: _categoryLabel(category),
            hasBackendIssue: _error != null,
            runtimeStatus: PushNotificationService.instance.runtimeStatus,
            showPushDiagnostics:
                widget.role.trim().toLowerCase() == 'principal',
            diagnosticsInFlight: _runningPushDiagnostic,
            onRunPushDiagnostics: _runPushDiagnostics,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            _NotificationIssueBanner(message: _error!),
          ],
          const SizedBox(height: 12),
          if (items.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 36),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.appTheme.outlineVariant),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.notifications_none_rounded,
                    size: 48,
                    color: mutedColor,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No notifications',
                    style: GoogleFonts.dmSans(
                      fontSize: 15,
                      color: mutedColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _error == null
                        ? 'New alerts from the backend will appear here.'
                        : 'Refresh after the notification service is reachable.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.dmSans(fontSize: 12, color: mutedColor),
                  ),
                ],
              ),
            )
          else
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildNotifCard(
                  item,
                  surfaceColor,
                  onSurfaceColor,
                  mutedColor,
                ),
              ),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String _categoryLabel(String? category) {
    switch (category) {
      case NotificationCategory.pendingApproval:
        return 'Approvals';
      case NotificationCategory.feeDue:
        return 'Fees';
      case NotificationCategory.event:
        return 'Events';
      case NotificationCategory.general:
        return 'Circulars';
      case NotificationCategory.birthday:
        return 'Birthdays';
      case NotificationCategory.healthAlert:
        return 'Health';
      default:
        return 'All';
    }
  }

  Future<void> _runPushDiagnostics() async {
    if (_runningPushDiagnostic) return;
    setState(() => _runningPushDiagnostic = true);
    try {
      await PushNotificationService.instance.registerDeviceTokenIfPossible();
      final report = await BackendApiClient.instance.runPushDiagnostics();
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (context) => _PushDiagnosticsSheet(
          runtimeStatus: PushNotificationService.instance.runtimeStatus,
          report: report,
        ),
      );
      await _init(forceRefresh: true);
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Push diagnostics failed: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _runningPushDiagnostic = false);
    }
  }

  Future<void> _openNotification(AppNotification notif) async {
    try {
      await _service?.markAsRead(notif.id);
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not mark notification as read: $error'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
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

  Widget _buildNotifCard(
    AppNotification notif,
    Color surfaceColor,
    Color onSurfaceColor,
    Color mutedColor,
  ) {
    final effectiveCategory = widget.role.trim().toLowerCase() == 'principal'
        ? _principalCategory(notif)
        : notif.category;
    final categoryIcon = _getCategoryIcon(effectiveCategory);
    final categoryColor = _getCategoryColor(effectiveCategory);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unreadBg = isDark
        ? const Color(0xFF1A3A5C)
        : context.appTheme.primaryContainer;
    final outlineColor = isDark
        ? const Color(0xFF2D3748)
        : context.appTheme.outlineVariant;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openNotification(notif),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: notif.isRead ? surfaceColor : unreadBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: notif.isRead
                  ? outlineColor
                  : context.appTheme.primaryLight.withAlpha(80),
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
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: mutedColor,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildPriorityChip(notif.priority),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            _categoryLabel(effectiveCategory),
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.dmSans(
                              fontSize: 11,
                              color: mutedColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
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
        ? context.appTheme.error
        : priority == NotificationPriority.medium
        ? context.appTheme.warning
        : context.appTheme.success;
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
      case NotificationCategory.event:
        return Icons.event_available_rounded;
      case NotificationCategory.health:
        return Icons.health_and_safety_rounded;
      case NotificationCategory.homework:
        return Icons.assignment_turned_in_rounded;
      case NotificationCategory.birthday:
        return Icons.cake_rounded;
      case NotificationCategory.healthAlert:
        return Icons.medical_services_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case NotificationCategory.pendingApproval:
        return context.appTheme.warning;
      case NotificationCategory.feeDue:
        return context.appTheme.error;
      case NotificationCategory.event:
        return context.appTheme.success;
      case NotificationCategory.health:
        return context.appTheme.info;
      case NotificationCategory.homework:
        return context.appTheme.primary;
      case NotificationCategory.birthday:
        return const Color(0xFFE91E63);
      case NotificationCategory.healthAlert:
        return const Color(0xFFFF9800);
      default:
        return context.appTheme.muted;
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

class _NotificationSummaryPanel extends StatelessWidget {
  final int allCount;
  final int visibleCount;
  final int unreadCount;
  final String categoryLabel;
  final bool hasBackendIssue;
  final PushNotificationRuntimeStatus runtimeStatus;
  final Future<void> Function()? onRunPushDiagnostics;
  final bool showPushDiagnostics;
  final bool diagnosticsInFlight;

  const _NotificationSummaryPanel({
    required this.allCount,
    required this.visibleCount,
    required this.unreadCount,
    required this.categoryLabel,
    required this.hasBackendIssue,
    required this.runtimeStatus,
    this.onRunPushDiagnostics,
    this.showPushDiagnostics = false,
    this.diagnosticsInFlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.appTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.appTheme.outlineVariant),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _NotificationMetricPill(
            label: 'Inbox',
            value: allCount,
            icon: Icons.notifications_active_rounded,
            color: context.appTheme.primary,
          ),
          _NotificationMetricPill(
            label: categoryLabel,
            value: visibleCount,
            icon: Icons.filter_alt_rounded,
            color: context.appTheme.info,
          ),
          _NotificationMetricPill(
            label: 'Unread',
            value: unreadCount,
            icon: Icons.mark_email_unread_rounded,
            color: unreadCount == 0
                ? context.appTheme.success
                : context.appTheme.warning,
          ),
          _NotificationMetricPill(
            label: 'Backend',
            value: hasBackendIssue ? 1 : 0,
            icon: hasBackendIssue
                ? Icons.cloud_off_rounded
                : Icons.cloud_done_rounded,
            color: hasBackendIssue
                ? context.appTheme.error
                : context.appTheme.success,
          ),
          _NotificationMetricPill(
            label: 'Push',
            value: runtimeStatus.deviceRegistrationSucceeded ? 1 : 0,
            icon: runtimeStatus.deviceRegistrationSucceeded
                ? Icons.notifications_active_rounded
                : Icons.notifications_off_rounded,
            color: runtimeStatus.deviceRegistrationSucceeded
                ? context.appTheme.success
                : context.appTheme.warning,
          ),
          if (showPushDiagnostics)
            FilledButton.icon(
              onPressed: diagnosticsInFlight ? null : onRunPushDiagnostics,
              icon: diagnosticsInFlight
                  ? const SizedBox.square(
                      dimension: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.bug_report_rounded, size: 16),
              label: const Text('Test Push'),
            ),
        ],
      ),
    );
  }
}

class _PushDiagnosticsSheet extends StatelessWidget {
  final PushNotificationRuntimeStatus runtimeStatus;
  final Map<String, dynamic> report;

  const _PushDiagnosticsSheet({
    required this.runtimeStatus,
    required this.report,
  });

  String _boolLabel(bool value) => value ? 'yes' : 'no';

  String _prettyJson(Object? value) {
    if (value == null) return 'null';
    if (value is String) return value;
    return const JsonEncoder.withIndent('  ').convert(value);
  }

  List<String> _diagnosisLines(Map<String, dynamic> summary) {
    final sent = ((report['processor_run'] as Map?)?['body'] as Map?)?['sent'];
    final activeCount = summary['active_canonical_device_count'] ?? 0;
    final lines = <String>[];
    if (!runtimeStatus.firebaseAvailable) {
      lines.add(
        'Local Firebase initialization failed before any push work started.',
      );
    }
    if (!runtimeStatus.hasDeviceToken) {
      lines.add('This device does not currently have an FCM token.');
    }
    if (!runtimeStatus.deviceRegistrationSucceeded) {
      lines.add(
        'The app has not confirmed backend token registration on this device.',
      );
    }
    if ((summary['processor_health_ok'] ?? false) != true) {
      lines.add(
        'The notification processor healthcheck failed, so env or OAuth is broken server-side.',
      );
    }
    if (activeCount == 0) {
      lines.add(
        'The backend has no active canonical device tokens for this user.',
      );
    }
    if ((summary['event_processed'] ?? false) == true &&
        (sent ?? 0) == 0 &&
        activeCount > 0) {
      lines.add(
        'The event reached the processor but no push send was recorded; inspect token validity and FCM response details in the full report.',
      );
    }
    if (lines.isEmpty) {
      lines.add(
        'No obvious blocker was detected by the quick heuristics. Use the full report to inspect token state and processor output.',
      );
    }
    return lines;
  }

  @override
  Widget build(BuildContext context) {
    final summary = Map<String, dynamic>.from(
      report['summary'] as Map? ?? const {},
    );
    final actor = Map<String, dynamic>.from(
      report['actor'] as Map? ?? const {},
    );
    final preference = Map<String, dynamic>.from(
      report['preference'] as Map? ?? const {},
    );
    final processorHealth = Map<String, dynamic>.from(
      report['processor_health'] as Map? ?? const {},
    );
    final processorRun = Map<String, dynamic>.from(
      report['processor_run'] as Map? ?? const {},
    );
    final eventAfter = Map<String, dynamic>.from(
      report['notification_event_after'] as Map? ?? const {},
    );
    final diagnosis = _diagnosisLines(summary);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Push Diagnostics',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Runs the existing notification pipeline for your principal account and shows where it succeeded or failed.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.72,
              child: ListView(
                children: [
                  _DiagnosticSection(
                    title: 'Local Device',
                    lines: [
                      'firebaseAvailable: ${_boolLabel(runtimeStatus.firebaseAvailable)}',
                      'localNotificationsReady: ${_boolLabel(runtimeStatus.localNotificationsReady)}',
                      'hasDeviceToken: ${_boolLabel(runtimeStatus.hasDeviceToken)}',
                      'deviceTokenPreview: ${runtimeStatus.deviceTokenPreview.isEmpty ? '<missing>' : runtimeStatus.deviceTokenPreview}',
                      'deviceRegistrationSucceeded: ${_boolLabel(runtimeStatus.deviceRegistrationSucceeded)}',
                      'permissionStatus: ${runtimeStatus.permissionStatus}',
                      'lastRegistrationError: ${runtimeStatus.lastRegistrationError.isEmpty ? '<none>' : runtimeStatus.lastRegistrationError}',
                    ],
                  ),
                  _DiagnosticSection(
                    title: 'Backend Summary',
                    lines: [
                      'actorRole: ${actor['role'] ?? '<unknown>'}',
                      'pushEnabled: ${preference['enable_push'] ?? true}',
                      'canonicalDeviceCount: ${summary['canonical_device_count'] ?? 0}',
                      'activeCanonicalDeviceCount: ${summary['active_canonical_device_count'] ?? 0}',
                      'legacyDeviceCount: ${summary['legacy_device_count'] ?? 0}',
                      'processorHealthOk: ${summary['processor_health_ok'] ?? false}',
                      'processorRunOk: ${summary['processor_run_ok'] ?? false}',
                      'eventProcessed: ${summary['event_processed'] ?? false}',
                    ],
                  ),
                  _DiagnosticSection(title: 'Likely Issue', lines: diagnosis),
                  _DiagnosticSection(
                    title: 'Processor Health',
                    code: _prettyJson(processorHealth),
                  ),
                  _DiagnosticSection(
                    title: 'Processor Run',
                    code: _prettyJson(processorRun),
                  ),
                  _DiagnosticSection(
                    title: 'Event After Processing',
                    code: _prettyJson(eventAfter),
                  ),
                  _DiagnosticSection(
                    title: 'Full Report',
                    code: _prettyJson(report),
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

class _DiagnosticSection extends StatelessWidget {
  final String title;
  final List<String> lines;
  final String? code;

  const _DiagnosticSection({
    required this.title,
    this.lines = const [],
    this.code,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.appTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.appTheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          if (lines.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(line, style: Theme.of(context).textTheme.bodySmall),
              ),
          ],
          if (code != null) ...[
            const SizedBox(height: 8),
            SelectableText(
              code!,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: context.appTheme.onSurface,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NotificationMetricPill extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color color;

  const _NotificationMetricPill({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 108),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withAlpha(22),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$value',
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: context.appTheme.onSurface,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color,
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

class _NotificationIssueBanner extends StatelessWidget {
  final String message;

  const _NotificationIssueBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.appTheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.appTheme.error.withAlpha(70)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: context.appTheme.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.dmSans(
                fontSize: 12,
                height: 1.35,
                color: context.appTheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
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
