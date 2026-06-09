import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:schooldesk1/routes/app_routes.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/services/backend_data_service.dart';
import 'package:schooldesk1/core/theme/design_tokens.dart';
import 'package:schooldesk1/core/widgets/admin_navigation.dart';
import 'package:schooldesk1/core/widgets/erp_components.dart';
import 'package:schooldesk1/core/widgets/erp_module_scaffold.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool _loading = true;
  String? _error;
  int _students = 0;
  int _staff = 0;
  int _classes = 0;
  int _pendingInvoices = 0;
  int _approvalPendingSubmissions = 0;
  int _approvalChangesRequested = 0;
  int _approvalResolved = 0;
  double _collected = 0;
  double _pending = 0;
  List<Map<String, dynamic>> _alerts = const [];

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
      final storage = await BackendDataService.getInstance();
      final results = await Future.wait([
        storage.getList(BackendDataService.kAdminStudents),
        storage.getList(BackendDataService.kAdminTeachers),
        storage.getList(BackendDataService.kAcademicClasses),
        storage.getList(BackendDataService.kRuntimeNotifications),
        storage.getList(BackendDataService.kStudentFees),
        BackendApiClient.instance.getApprovalRequests(),
      ]);

      final invoices = results[4];
      final approvals = results[5];
      var collected = 0.0;
      var pending = 0.0;
      var pendingInvoices = 0;
      var approvalPendingSubmissions = 0;
      var approvalChangesRequested = 0;
      var approvalResolved = 0;

      for (final invoice in invoices) {
        final total =
            _numValue(invoice['total_amount']) ??
            _numValue(invoice['net_amount']) ??
            _numValue(invoice['amount']) ??
            0;
        final paid =
            _numValue(invoice['paid_amount']) ??
            (total - (_numValue(invoice['balance']) ?? 0)).clamp(0, total);
        final balance = _numValue(invoice['balance']) ?? (total - paid);
        collected += paid;
        pending += balance;
        if (balance > 0) pendingInvoices++;
      }

      for (final approval in approvals) {
        final status = _approvalStatus(approval['status']);
        if (status == 'pending') {
          approvalPendingSubmissions++;
        } else if (status == 'changes_requested') {
          approvalChangesRequested++;
        } else if (status == 'approved' || status == 'rejected') {
          approvalResolved++;
        }
      }

      if (!mounted) return;
      setState(() {
        _students = results[0].length;
        _staff = results[1].length;
        _classes = results[2].length;
        _alerts = results[3];
        _approvalPendingSubmissions = approvalPendingSubmissions;
        _approvalChangesRequested = approvalChangesRequested;
        _approvalResolved = approvalResolved;
        _collected = collected;
        _pending = pending;
        _pendingInvoices = pendingInvoices;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load admin dashboard from backend.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SchoolDeskModuleScaffold(
      title: 'Admin',
      drawer: AdminDrawer(selectedIndex: 0, onDestinationSelected: (_) {}),
      actions: [
        IconButton(
          tooltip: 'Refresh dashboard',
          icon: const Icon(Icons.refresh_rounded),
          onPressed: _loadDashboardData,
        ),
      ],
      mobileBottomActions: const [
        SchoolDeskModuleBottomAction(
          label: 'Home',
          icon: Icons.home_outlined,
          activeIcon: Icons.home_rounded,
          route: AppRoutes.initial,
        ),
        SchoolDeskModuleBottomAction(
          label: 'Students',
          icon: Icons.school_outlined,
          activeIcon: Icons.school_rounded,
          route: AppRoutes.adminStudents,
        ),
        SchoolDeskModuleBottomAction(
          label: 'Staff',
          icon: Icons.groups_outlined,
          activeIcon: Icons.groups_rounded,
          route: AppRoutes.adminTeachers,
        ),
        SchoolDeskModuleBottomAction(
          label: 'Chat',
          icon: Icons.chat_bubble_outline_rounded,
          activeIcon: Icons.chat_bubble_rounded,
          route: AppRoutes.adminCommunication,
        ),
      ],
      bodyIsScrollable: true,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;
    final horizontal = SchoolDeskResponsive.contentHorizontalPaddingForWidth(
      MediaQuery.sizeOf(context).width,
      tokens.spacing,
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(
        horizontal,
        tokens.spacing.lg,
        horizontal,
        tokens.spacing.xxl,
      ),
      child: AnimatedSwitcher(
        duration: tokens.motion.normal,
        child: _loading
            ? const SchoolDeskStatusPanel.loading(
                message: 'Loading operational dashboard',
              )
            : _error != null
            ? SchoolDeskStatusPanel.error(
                title: 'Dashboard unavailable',
                message: _error!,
                onAction: _loadDashboardData,
              )
            : _DashboardContent(
                students: _students,
                staff: _staff,
                classes: _classes,
                approvalPendingSubmissions: _approvalPendingSubmissions,
                approvalChangesRequested: _approvalChangesRequested,
                approvalResolved: _approvalResolved,
                collected: _collected,
                pending: _pending,
                pendingInvoices: _pendingInvoices,
                alerts: _alerts,
                money: _money,
              ),
      ),
    );
  }

  String _money(double value) {
    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    ).format(value);
  }

  double? _numValue(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  String _approvalStatus(Object? value) {
    final status = '${value ?? 'pending'}'.trim().toLowerCase();
    return switch (status) {
      'submitted' || 'principal_review' => 'pending',
      'changes requested' || 'changes_requested' => 'changes_requested',
      'applied' => 'approved',
      _ => status.isEmpty ? 'pending' : status,
    };
  }
}

class _DashboardContent extends StatelessWidget {
  final int students;
  final int staff;
  final int classes;
  final int approvalPendingSubmissions;
  final int approvalChangesRequested;
  final int approvalResolved;
  final double collected;
  final double pending;
  final int pendingInvoices;
  final List<Map<String, dynamic>> alerts;
  final String Function(double) money;

  const _DashboardContent({
    required this.students,
    required this.staff,
    required this.classes,
    required this.approvalPendingSubmissions,
    required this.approvalChangesRequested,
    required this.approvalResolved,
    required this.collected,
    required this.pending,
    required this.pendingInvoices,
    required this.alerts,
    required this.money,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;
    final adminColor = tokens.roleColor(SchoolDeskRole.admin);
    final compact = MediaQuery.sizeOf(context).width < 700;

    if (compact) {
      return _AdminMobileWireframeDashboard(
        students: students,
        staff: staff,
        classes: classes,
        approvalPendingSubmissions: approvalPendingSubmissions,
        approvalChangesRequested: approvalChangesRequested,
        approvalResolved: approvalResolved,
        collected: collected,
        pending: pending,
        pendingInvoices: pendingInvoices,
        alerts: alerts,
        money: money,
        adminColor: adminColor,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SchoolDeskPageHeader(
          title: 'Operational Overview',
          subtitle:
              'Live school operations, finance, access, and communication health.',
          actions: [
            FilledButton.icon(
              onPressed: () =>
                  Navigator.pushNamed(context, AppRoutes.adminStudents),
              icon: const Icon(Icons.person_add_rounded, size: 18),
              label: const Text('Prepare Student Request'),
            ),
            OutlinedButton.icon(
              onPressed: () =>
                  Navigator.pushNamed(context, AppRoutes.adminCommunication),
              icon: const Icon(Icons.campaign_rounded, size: 18),
              label: const Text('Submit Notice for Approval'),
            ),
          ],
        ),
        SchoolDeskResponsiveGrid(
          minTileWidth: 210,
          mainAxisExtent: 118,
          children: [
            SchoolDeskKpiCard(
              title: 'Students',
              value: '$students',
              subtitle: 'Active records',
              icon: Icons.school_rounded,
              color: adminColor,
              onTap: () =>
                  Navigator.pushNamed(context, AppRoutes.adminStudents),
            ),
            SchoolDeskKpiCard(
              title: 'Staff',
              value: '$staff',
              subtitle: 'Backend staff list',
              icon: Icons.people_rounded,
              color: theme.colorScheme.secondary,
              onTap: () =>
                  Navigator.pushNamed(context, AppRoutes.adminTeachers),
            ),
            SchoolDeskKpiCard(
              title: 'Classes',
              value: '$classes',
              subtitle: 'Configured sections',
              icon: Icons.badge_rounded,
              color: theme.colorScheme.tertiary,
              onTap: () =>
                  Navigator.pushNamed(context, AppRoutes.academicManagement),
            ),
            SchoolDeskKpiCard(
              title: 'Fee collected',
              value: money(collected),
              subtitle: 'Backend invoices',
              icon: Icons.account_balance_wallet_rounded,
              color: theme.colorScheme.secondary,
              onTap: () => Navigator.pushNamed(context, AppRoutes.adminFees),
            ),
            SchoolDeskKpiCard(
              title: 'Pending dues',
              value: money(pending),
              subtitle: '$pendingInvoices invoices',
              icon: Icons.warning_rounded,
              color: theme.colorScheme.error,
              onTap: () => Navigator.pushNamed(context, AppRoutes.adminFees),
            ),
            SchoolDeskKpiCard(
              title: 'Alerts',
              value: '${alerts.length}',
              subtitle: 'Notification center',
              icon: Icons.notifications_active_rounded,
              color: theme.colorScheme.primary,
              onTap: () => Navigator.pushNamed(
                context,
                AppRoutes.notificationCenter,
                arguments: 'admin',
              ),
            ),
            SchoolDeskKpiCard(
              title: 'Pending submissions',
              value: '$approvalPendingSubmissions',
              subtitle: 'Principal approval queue',
              icon: Icons.pending_actions_rounded,
              color: theme.colorScheme.primary,
            ),
            SchoolDeskKpiCard(
              title: 'Changes requested',
              value: '$approvalChangesRequested',
              subtitle: 'Needs Admin revision',
              icon: Icons.rule_folder_rounded,
              color: theme.colorScheme.tertiary,
            ),
            SchoolDeskKpiCard(
              title: 'Recently approved/rejected',
              value: '$approvalResolved',
              subtitle: 'Resolved request states',
              icon: Icons.fact_check_rounded,
              color: theme.colorScheme.secondary,
            ),
          ],
        ),
        SizedBox(height: tokens.spacing.lg),
        LayoutBuilder(
          builder: (context, constraints) {
            final sideBySide = constraints.maxWidth >= 840;
            final children = [
              Expanded(child: _QuickActionsCard(adminColor: adminColor)),
              SizedBox(width: sideBySide ? tokens.spacing.md : 0),
              Expanded(child: _AlertsCard(alerts: alerts)),
            ];
            if (sideBySide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children,
              );
            }
            return Column(
              children: [
                _QuickActionsCard(adminColor: adminColor),
                SizedBox(height: tokens.spacing.md),
                _AlertsCard(alerts: alerts),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _AdminMobileWireframeDashboard extends StatelessWidget {
  final int students;
  final int staff;
  final int classes;
  final int approvalPendingSubmissions;
  final int approvalChangesRequested;
  final int approvalResolved;
  final double collected;
  final double pending;
  final int pendingInvoices;
  final List<Map<String, dynamic>> alerts;
  final String Function(double) money;
  final Color adminColor;

  const _AdminMobileWireframeDashboard({
    required this.students,
    required this.staff,
    required this.classes,
    required this.approvalPendingSubmissions,
    required this.approvalChangesRequested,
    required this.approvalResolved,
    required this.collected,
    required this.pending,
    required this.pendingInvoices,
    required this.alerts,
    required this.money,
    required this.adminColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;
    final featureCards = [
      _AdminFeatureSpec(
        label: 'Students',
        value: '$students',
        icon: Icons.school_rounded,
        color: adminColor,
        route: AppRoutes.adminStudents,
      ),
      _AdminFeatureSpec(
        label: 'Staff',
        value: '$staff',
        icon: Icons.groups_rounded,
        color: theme.colorScheme.secondary,
        route: AppRoutes.adminTeachers,
      ),
      _AdminFeatureSpec(
        label: 'Timetable',
        value: '$classes',
        icon: Icons.calendar_view_week_rounded,
        color: theme.colorScheme.primary,
        route: AppRoutes.adminTimetable,
      ),
      _AdminFeatureSpec(
        label: 'Fees',
        value: money(collected),
        icon: Icons.account_balance_wallet_rounded,
        color: theme.colorScheme.secondary,
        route: AppRoutes.adminFees,
      ),
      _AdminFeatureSpec(
        label: 'Access',
        value: 'Roles',
        icon: Icons.manage_accounts_rounded,
        color: adminColor,
        route: AppRoutes.adminUserAccess,
      ),
      _AdminFeatureSpec(
        label: 'Reports',
        value: 'View',
        icon: Icons.bar_chart_rounded,
        color: theme.colorScheme.primary,
        route: AppRoutes.adminReports,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AdminSummaryRecord(
          title: 'Total Students',
          subtitle: 'Student records',
          value: '$students',
          icon: Icons.school_rounded,
          color: adminColor,
          route: AppRoutes.adminStudents,
        ),
        SizedBox(height: tokens.spacing.sm),
        _AdminSummaryRecord(
          title: 'Total Staff',
          subtitle: 'Teachers and staff',
          value: '$staff',
          icon: Icons.groups_rounded,
          color: theme.colorScheme.secondary,
          route: AppRoutes.adminTeachers,
        ),
        SizedBox(height: tokens.spacing.sm),
        _AdminSummaryRecord(
          title: "Today's Classes",
          subtitle: 'Configured sections',
          value: '$classes',
          icon: Icons.class_rounded,
          color: theme.colorScheme.primary,
          route: AppRoutes.adminTimetable,
        ),
        SizedBox(height: tokens.spacing.sm),
        _AdminSummaryRecord(
          title: 'Pending Submissions',
          subtitle: 'Principal approval queue',
          value: '$approvalPendingSubmissions',
          icon: Icons.pending_actions_rounded,
          color: approvalPendingSubmissions == 0
              ? theme.colorScheme.primary
              : theme.colorScheme.error,
          route: AppRoutes.adminDashboard,
        ),
        SizedBox(height: tokens.spacing.sm),
        _AdminSummaryRecord(
          title: 'Changes Requested',
          subtitle: 'Revise and resubmit',
          value: '$approvalChangesRequested',
          icon: Icons.rule_folder_rounded,
          color: approvalChangesRequested == 0
              ? theme.colorScheme.secondary
              : theme.colorScheme.tertiary,
          route: AppRoutes.adminDashboard,
        ),
        SizedBox(height: tokens.spacing.sm),
        _AdminSummaryRecord(
          title: 'Approved / Rejected',
          subtitle: 'Recently resolved requests',
          value: '$approvalResolved',
          icon: Icons.fact_check_rounded,
          color: theme.colorScheme.secondary,
          route: AppRoutes.adminDashboard,
        ),
        SizedBox(height: tokens.spacing.sm),
        _AdminSummaryRecord(
          title: 'Fee Dues',
          subtitle: '$pendingInvoices invoices pending',
          value: money(pending),
          icon: Icons.warning_rounded,
          color: pending > 0
              ? theme.colorScheme.error
              : theme.colorScheme.secondary,
          route: AppRoutes.adminFees,
        ),
        SizedBox(height: tokens.spacing.md),
        _AdminVisualPanel(
          title: 'Quick Access',
          child: SchoolDeskResponsiveGrid(
            minTileWidth: 142,
            mainAxisExtent: 116,
            spacing: tokens.spacing.sm,
            children: [
              for (final feature in featureCards)
                _AdminFeatureTile(feature: feature),
            ],
          ),
        ),
      ],
    );
  }
}

class _AdminVisualPanel extends StatelessWidget {
  final String title;
  final Widget child;

  const _AdminVisualPanel({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;
    return Container(
      padding: EdgeInsets.all(tokens.spacing.md),
      decoration: BoxDecoration(
        color: tokens.panel,
        borderRadius: BorderRadius.circular(tokens.radius.card),
        border: Border.all(color: tokens.panelBorder),
        boxShadow: tokens.elevation.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          SizedBox(height: tokens.spacing.md),
          child,
        ],
      ),
    );
  }
}

class _AdminSummaryRecord extends StatelessWidget {
  final String title;
  final String subtitle;
  final String value;
  final IconData icon;
  final Color color;
  final String route;

  const _AdminSummaryRecord({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.icon,
    required this.color,
    required this.route,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;
    return Semantics(
      button: true,
      label: '$title, $value, $subtitle',
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(tokens.radius.card),
          onTap: () => Navigator.pushNamed(context, route),
          child: Container(
            constraints: const BoxConstraints(minHeight: 104),
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
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: color.withAlpha(tokens.isDark ? 56 : 24),
                    borderRadius: BorderRadius.circular(tokens.radius.control),
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                SizedBox(width: tokens.spacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: tokens.spacing.xs),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: tokens.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: tokens.spacing.sm),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 116),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      value,
                      maxLines: 1,
                      textAlign: TextAlign.right,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
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

class _AdminFeatureTile extends StatelessWidget {
  final _AdminFeatureSpec feature;

  const _AdminFeatureTile({required this.feature});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;
    return Semantics(
      button: true,
      label: '${feature.label}, ${feature.value}',
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(tokens.radius.card),
          onTap: () => Navigator.pushNamed(context, feature.route),
          child: Container(
            padding: EdgeInsets.all(tokens.spacing.sm),
            decoration: BoxDecoration(
              color: tokens.panelMuted,
              borderRadius: BorderRadius.circular(tokens.radius.card),
              border: Border.all(color: tokens.panelBorder),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: feature.color.withAlpha(tokens.isDark ? 56 : 28),
                    borderRadius: BorderRadius.circular(tokens.radius.control),
                  ),
                  child: Icon(feature.icon, color: feature.color, size: 26),
                ),
                SizedBox(height: tokens.spacing.sm),
                Text(
                  feature.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: tokens.spacing.xs),
                Text(
                  feature.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: tokens.textMuted,
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

class _AdminFeatureSpec {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String route;

  const _AdminFeatureSpec({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.route,
  });
}

class _QuickActionsCard extends StatelessWidget {
  final Color adminColor;

  const _QuickActionsCard({required this.adminColor});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final actions = [
      _QuickAction(
        'Prepare student request',
        'Draft for Principal approval',
        Icons.person_add_rounded,
        AppRoutes.adminStudents,
      ),
      _QuickAction(
        'Prepare staff request',
        'Submit staff changes for review',
        Icons.person_add_alt_1_rounded,
        AppRoutes.adminTeachers,
      ),
      _QuickAction(
        'Submit fee request',
        'Prepare fee changes',
        Icons.payment_rounded,
        AppRoutes.adminFees,
      ),
      _QuickAction(
        'Submit timetable request',
        'Prepare periods for approval',
        Icons.calendar_view_week_rounded,
        AppRoutes.adminTimetable,
      ),
      _QuickAction(
        'Prepare access request',
        'Accounts and roles review',
        Icons.manage_accounts_rounded,
        AppRoutes.adminUserAccess,
      ),
      _QuickAction(
        'Reports',
        'Exports and compliance',
        Icons.bar_chart_rounded,
        AppRoutes.adminReports,
      ),
    ];

    return SchoolDeskSectionCard(
      title: 'Quick actions',
      subtitle: 'Frequent admin workflows, routed to live modules.',
      child: SchoolDeskResponsiveGrid(
        minTileWidth: 150,
        mainAxisExtent: 126,
        children: [
          for (final action in actions)
            SchoolDeskQuickActionTile(
              label: action.label,
              subtitle: action.subtitle,
              icon: action.icon,
              color: action.route == AppRoutes.adminFees
                  ? theme.colorScheme.secondary
                  : adminColor,
              onTap: () => Navigator.pushNamed(context, action.route),
            ),
        ],
      ),
    );
  }
}

class _AlertsCard extends StatelessWidget {
  final List<Map<String, dynamic>> alerts;

  const _AlertsCard({required this.alerts});

  @override
  Widget build(BuildContext context) {
    if (alerts.isEmpty) {
      return const SchoolDeskSectionCard(
        title: 'Alerts',
        subtitle: 'Backend notifications and urgent school events.',
        child: SchoolDeskStatusPanel.empty(
          title: 'No active alerts',
          message: 'New backend notifications will appear here.',
        ),
      );
    }

    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;
    return SchoolDeskSectionCard(
      title: 'Alerts',
      subtitle: 'Backend notifications and urgent school events.',
      action: TextButton(
        onPressed: () => Navigator.pushNamed(
          context,
          AppRoutes.notificationCenter,
          arguments: 'admin',
        ),
        child: const Text('View all'),
      ),
      child: Column(
        children: [
          for (final alert in alerts.take(5))
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                radius: 16,
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Icon(
                  Icons.notifications_active_rounded,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
              ),
              title: Text(
                _alertTitle(alert),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge,
              ),
              subtitle: Text(
                _alertSubtitle(alert),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: tokens.textMuted,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _alertTitle(Map<String, dynamic> alert) {
    return '${alert['title'] ?? alert['message'] ?? 'Notification'}'.trim();
  }

  String _alertSubtitle(Map<String, dynamic> alert) {
    final value = alert['created_at'] ?? alert['body'] ?? alert['priority'];
    return '${value ?? 'Backend notification'}'.trim();
  }
}

class _QuickAction {
  final String label;
  final String subtitle;
  final IconData icon;
  final String route;

  const _QuickAction(this.label, this.subtitle, this.icon, this.route);
}
