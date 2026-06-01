import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:schooldesk1/routes/app_routes.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/theme/design_tokens.dart';
import 'package:schooldesk1/core/widgets/erp_components.dart';
import 'package:schooldesk1/core/widgets/erp_module_scaffold.dart';
import 'package:schooldesk1/core/widgets/parent_navigation.dart';

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
  List<AnnouncementModel> _notices = const [];
  Map<String, dynamic> _dashboard = const {};

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
      // Backend integration: keep this screen API-backed only. Do not seed
      // local child metrics; leave missing fields as not published.
      final results = await Future.wait([
        api.getMyStudents(),
        api.getAnnouncements(),
        api.getDashboard('parent'),
      ]);

      if (!mounted) return;
      final children = (results[0] as List)
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
      final dashboard = Map<String, dynamic>.from(results[2] as Map);
      final dashboardChildren = _listMap(dashboard['children']);
      final feeByStudentId = {
        for (final child in dashboardChildren) '${child['id']}': child,
      };
      for (final child in children) {
        final studentId = '${child['id'] ?? child['student_id'] ?? ''}';
        final feeRow = feeByStudentId[studentId];
        if (feeRow == null) continue;
        child['pending_fee_balance'] = feeRow['pending_fee_balance'];
        child['pending_invoices'] = feeRow['pending_invoices'];
      }
      // Backend integration: add attendance, homeworkDue, classTeacher, and
      // fee summary fields to the parent dashboard response when available.
      setState(() {
        _children = children;
        _notices = (results[1] as List).whereType<AnnouncementModel>().toList();
        _dashboard = dashboard;
        if (_activeChildIndex >= _children.length) _activeChildIndex = 0;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load parent dashboard from backend.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SchoolDeskModuleScaffold(
      title: 'Parent',
      subtitle: 'Child overview, homework, fees, notices, and teacher contact',
      drawer: ParentDrawer(
        selectedIndex: _selectedNavIndex,
        onDestinationSelected: (i) => setState(() => _selectedNavIndex = i),
      ),
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
          label: 'Child',
          icon: Icons.badge_outlined,
          activeIcon: Icons.badge_rounded,
          route: AppRoutes.parentAcademicProgress,
        ),
        SchoolDeskModuleBottomAction(
          label: 'Homework',
          icon: Icons.assignment_outlined,
          activeIcon: Icons.assignment_rounded,
          route: AppRoutes.parentHomework,
        ),
        SchoolDeskModuleBottomAction(
          label: 'Fees',
          icon: Icons.account_balance_wallet_outlined,
          activeIcon: Icons.account_balance_wallet_rounded,
          route: AppRoutes.parentFees,
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
        message: 'Loading linked student dashboard',
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
      child = _ParentDashboardContent(
        children: _children,
        activeChildIndex: _activeChildIndex,
        onChildSelected: (index) => setState(() => _activeChildIndex = index),
        notices: _notices,
        dashboard: _dashboard,
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(
        horizontal,
        tokens.spacing.lg,
        horizontal,
        tokens.spacing.xxl,
      ),
      child: AnimatedSwitcher(duration: tokens.motion.normal, child: child),
    );
  }
}

class _ParentDashboardContent extends StatelessWidget {
  final List<Map<String, dynamic>> children;
  final int activeChildIndex;
  final ValueChanged<int> onChildSelected;
  final List<AnnouncementModel> notices;
  final Map<String, dynamic> dashboard;

  const _ParentDashboardContent({
    required this.children,
    required this.activeChildIndex,
    required this.onChildSelected,
    required this.notices,
    required this.dashboard,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;
    final parentColor = tokens.roleColor(SchoolDeskRole.parent);
    final child = children[activeChildIndex];
    final compact = MediaQuery.sizeOf(context).width < 700;

    if (compact) {
      return _ParentMobileWireframeDashboard(
        children: children,
        activeChildIndex: activeChildIndex,
        onChildSelected: onChildSelected,
        notices: notices,
        child: child,
        parentColor: parentColor,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SchoolDeskPageHeader(
          title: 'Child Overview',
          subtitle: DateFormat('EEEE, d MMMM yyyy').format(DateTime.now()),
          actions: [
            OutlinedButton.icon(
              onPressed: () =>
                  Navigator.pushNamed(context, AppRoutes.parentTeacherChat),
              icon: const Icon(Icons.chat_rounded, size: 18),
              label: const Text('Contact teacher'),
            ),
            FilledButton.icon(
              onPressed: () =>
                  Navigator.pushNamed(context, AppRoutes.parentFees),
              icon: const Icon(Icons.account_balance_wallet_rounded, size: 18),
              label: Text(_feeActionLabel(dashboard)),
            ),
          ],
        ),
        _ChildSelector(
          children: children,
          activeIndex: activeChildIndex,
          onChanged: onChildSelected,
          color: parentColor,
        ),
        SizedBox(height: tokens.spacing.md),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;
            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 2, child: _ChildProfileCard(child: child)),
                  SizedBox(width: tokens.spacing.md),
                  Expanded(
                    flex: 3,
                    child: _ParentActionAndNoticePanel(
                      child: child,
                      notices: notices,
                    ),
                  ),
                ],
              );
            }
            return Column(
              children: [
                _ChildProfileCard(child: child),
                SizedBox(height: tokens.spacing.md),
                _ParentActionAndNoticePanel(child: child, notices: notices),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ParentMobileWireframeDashboard extends StatelessWidget {
  final List<Map<String, dynamic>> children;
  final int activeChildIndex;
  final ValueChanged<int> onChildSelected;
  final List<AnnouncementModel> notices;
  final Map<String, dynamic> child;
  final Color parentColor;

  const _ParentMobileWireframeDashboard({
    required this.children,
    required this.activeChildIndex,
    required this.onChildSelected,
    required this.notices,
    required this.child,
    required this.parentColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;
    final childName = _name(child, fallback: 'Student');
    final classLabel = _classLabel(child);
    final attendanceLabel = _attendanceLabel(child);
    final homeworkDue = _homeworkDueLabel(child);
    final homeworkDueCount = _homeworkDueCount(child);
    final feeDue = _feeDueLabel(child);
    final feeState = _feeStateLabel(child);
    final actions = [
      _ParentVisualActionSpec(
        label: 'Attendance',
        value: attendanceLabel,
        illustrationAsset: SchoolDeskUiIllustrations.attendance,
        color: parentColor,
        route: AppRoutes.parentAttendance,
      ),
      _ParentVisualActionSpec(
        label: 'Homework',
        value: homeworkDue,
        illustrationAsset: SchoolDeskUiIllustrations.homework,
        color: theme.colorScheme.primary,
        route: AppRoutes.parentHomework,
      ),
      _ParentVisualActionSpec(
        label: 'Notice',
        value: '${notices.length}',
        illustrationAsset: SchoolDeskUiIllustrations.notices,
        color: theme.colorScheme.primary,
        route: AppRoutes.parentNotices,
      ),
      _ParentVisualActionSpec(
        label: 'Fees',
        value: feeState,
        illustrationAsset: SchoolDeskUiIllustrations.fees,
        color: theme.colorScheme.secondary,
        route: AppRoutes.parentFees,
      ),
      _ParentVisualActionSpec(
        label: 'Chat',
        value: 'Open',
        illustrationAsset: SchoolDeskUiIllustrations.chat,
        color: parentColor,
        route: AppRoutes.parentTeacherChat,
      ),
      _ParentVisualActionSpec(
        label: 'Calendar',
        value: 'Open',
        illustrationAsset: SchoolDeskUiIllustrations.calendar,
        color: theme.colorScheme.secondary,
        route: AppRoutes.parentCalendar,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ParentChildBanner(
          childName: childName,
          classLabel: classLabel,
          color: parentColor,
          child: _ChildSelector(
            children: children,
            activeIndex: activeChildIndex,
            onChanged: onChildSelected,
            color: parentColor,
          ),
        ),
        SizedBox(height: tokens.spacing.md),
        Text("Today's Overview", style: theme.textTheme.titleMedium),
        SizedBox(height: tokens.spacing.md),
        SchoolDeskVisualSummaryRecord(
          title: 'Attendance',
          subtitle: 'Daily record',
          value: attendanceLabel,
          icon: Icons.how_to_reg_rounded,
          color: parentColor,
          onTap: () => Navigator.pushNamed(context, AppRoutes.parentAttendance),
        ),
        SizedBox(height: tokens.spacing.sm),
        SchoolDeskVisualSummaryRecord(
          title: 'Homework',
          subtitle: 'Assignments due',
          value: homeworkDue,
          icon: Icons.assignment_rounded,
          color: (homeworkDueCount ?? 0) > 0
              ? theme.colorScheme.error
              : theme.colorScheme.primary,
          onTap: () => Navigator.pushNamed(context, AppRoutes.parentHomework),
        ),
        SizedBox(height: tokens.spacing.sm),
        SchoolDeskVisualSummaryRecord(
          title: 'Fee Dues',
          subtitle: feeDue,
          value: feeState,
          icon: Icons.account_balance_wallet_rounded,
          color: theme.colorScheme.secondary,
          onTap: () => Navigator.pushNamed(context, AppRoutes.parentFees),
        ),
        SizedBox(height: tokens.spacing.sm),
        SchoolDeskVisualSummaryRecord(
          title: 'Notices',
          subtitle: 'School communication',
          value: '${notices.length}',
          icon: Icons.campaign_rounded,
          color: notices.any((notice) => notice.isUrgent)
              ? theme.colorScheme.error
              : theme.colorScheme.primary,
          onTap: () => Navigator.pushNamed(context, AppRoutes.parentNotices),
        ),
        SizedBox(height: tokens.spacing.md),
        SchoolDeskVisualPanel(
          title: 'Quick Access',
          child: SchoolDeskResponsiveGrid(
            minTileWidth: 142,
            mainAxisExtent: 158,
            spacing: tokens.spacing.sm,
            children: [
              for (final action in actions)
                SchoolDeskIllustratedActionTile(
                  label: action.label,
                  subtitle: action.value,
                  illustrationAsset: action.illustrationAsset,
                  color: action.color,
                  onTap: () => Navigator.pushNamed(context, action.route),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ParentChildBanner extends StatelessWidget {
  final String childName;
  final String classLabel;
  final Widget child;
  final Color color;

  const _ParentChildBanner({
    required this.childName,
    required this.classLabel,
    required this.child,
    required this.color,
  });

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
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: color.withAlpha(tokens.isDark ? 56 : 28),
                foregroundColor: color,
                child: Text(
                  _initials(childName),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              SizedBox(width: tokens.spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      childName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: tokens.spacing.xs),
                    Text(
                      classLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: tokens.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: tokens.spacing.md),
          child,
        ],
      ),
    );
  }
}

class _ParentVisualActionSpec {
  final String label;
  final String value;
  final String illustrationAsset;
  final Color color;
  final String route;

  const _ParentVisualActionSpec({
    required this.label,
    required this.value,
    required this.illustrationAsset,
    required this.color,
    required this.route,
  });
}

class _ChildSelector extends StatelessWidget {
  final List<Map<String, dynamic>> children;
  final int activeIndex;
  final ValueChanged<int> onChanged;
  final Color color;

  const _ChildSelector({
    required this.children,
    required this.activeIndex,
    required this.onChanged,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;
    return Semantics(
      label: 'Child selector',
      child: Wrap(
        spacing: tokens.spacing.sm,
        runSpacing: tokens.spacing.sm,
        children: [
          for (var i = 0; i < children.length; i++)
            ChoiceChip(
              selected: i == activeIndex,
              label: Text(_name(children[i], fallback: 'Student')),
              avatar: CircleAvatar(
                backgroundColor: i == activeIndex
                    ? theme.colorScheme.onPrimary
                    : color.withAlpha(32),
                foregroundColor: color,
                child: Text(_initials(_name(children[i], fallback: 'S'))),
              ),
              onSelected: (_) => onChanged(i),
            ),
        ],
      ),
    );
  }
}

class _ChildProfileCard extends StatelessWidget {
  final Map<String, dynamic> child;

  const _ChildProfileCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;
    final name = _name(child, fallback: 'Student');
    final classLabel = _classLabel(child);

    return SchoolDeskSectionCard(
      title: name,
      subtitle: classLabel,
      child: Column(
        children: [
          _InfoRow(
            icon: Icons.badge_rounded,
            label: 'Roll / admission',
            value: _rollLabel(child),
          ),
          _InfoRow(
            icon: Icons.how_to_reg_rounded,
            label: 'Attendance',
            value: _attendanceLabel(child),
          ),
          _InfoRow(
            icon: Icons.assignment_turned_in_rounded,
            label: 'Homework due',
            value: _homeworkDueLabel(child),
          ),
          _InfoRow(
            icon: Icons.account_balance_wallet_rounded,
            label: 'Fee due',
            value: _feeDueLabel(child),
          ),
          _InfoRow(
            icon: Icons.person_rounded,
            label: 'Class teacher',
            value: _classTeacherLabel(child),
          ),
          SizedBox(height: tokens.spacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: () => Navigator.pushNamed(
                context,
                AppRoutes.parentAcademicProgress,
              ),
              icon: const Icon(Icons.trending_up_rounded, size: 18),
              label: const Text('View progress'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ParentActionAndNoticePanel extends StatelessWidget {
  final Map<String, dynamic> child;
  final List<AnnouncementModel> notices;

  const _ParentActionAndNoticePanel({
    required this.child,
    required this.notices,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).schoolDesk;
    return Column(
      children: [
        _QuickActionsCard(),
        SizedBox(height: tokens.spacing.md),
        _NoticesCard(notices: notices),
      ],
    );
  }
}

class _QuickActionsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final parentColor = theme.schoolDesk.roleColor(SchoolDeskRole.parent);
    final actions = [
      _Action(
        'Attendance',
        'Daily records',
        SchoolDeskUiIllustrations.attendance,
        AppRoutes.parentAttendance,
        parentColor,
      ),
      _Action(
        'Homework',
        'Tasks and feedback',
        SchoolDeskUiIllustrations.homework,
        AppRoutes.parentHomework,
        theme.colorScheme.primary,
      ),
      _Action(
        'Fees',
        'Dues and receipts',
        SchoolDeskUiIllustrations.fees,
        AppRoutes.parentFees,
        theme.colorScheme.secondary,
      ),
      _Action(
        'Leave',
        'Student requests',
        SchoolDeskUiIllustrations.calendar,
        AppRoutes.parentLeave,
        theme.colorScheme.error,
      ),
      _Action(
        'Calendar',
        'Events and dates',
        SchoolDeskUiIllustrations.calendar,
        AppRoutes.parentCalendar,
        parentColor,
      ),
      _Action(
        'Documents',
        'School records',
        SchoolDeskUiIllustrations.resources,
        AppRoutes.parentDocuments,
        theme.colorScheme.primary,
      ),
    ];

    return SchoolDeskSectionCard(
      title: 'Child quick actions',
      subtitle: 'Task-first access to the linked child workflows.',
      child: SchoolDeskResponsiveGrid(
        minTileWidth: 150,
        mainAxisExtent: 158,
        children: [
          for (final action in actions)
            SchoolDeskIllustratedActionTile(
              label: action.label,
              subtitle: action.subtitle,
              illustrationAsset: action.illustrationAsset,
              color: action.color,
              onTap: () => Navigator.pushNamed(context, action.route),
            ),
        ],
      ),
    );
  }
}

class _NoticesCard extends StatelessWidget {
  final List<AnnouncementModel> notices;

  const _NoticesCard({required this.notices});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;
    if (notices.isEmpty) {
      return const SchoolDeskSectionCard(
        title: 'Recent notices',
        subtitle: 'Published school communication for parents.',
        child: SchoolDeskStatusPanel.empty(
          title: 'No notices yet',
          message: 'Published school notices will appear here.',
        ),
      );
    }

    return SchoolDeskSectionCard(
      title: 'Recent notices',
      subtitle: 'Published school communication for parents.',
      action: TextButton(
        onPressed: () => Navigator.pushNamed(context, AppRoutes.parentNotices),
        child: const Text('View all'),
      ),
      child: Column(
        children: [
          for (final notice in notices.take(4))
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                radius: 16,
                backgroundColor: notice.isUrgent
                    ? theme.colorScheme.errorContainer
                    : theme.colorScheme.primaryContainer,
                foregroundColor: notice.isUrgent
                    ? theme.colorScheme.error
                    : theme.colorScheme.primary,
                child: Icon(
                  notice.isUrgent
                      ? Icons.priority_high_rounded
                      : Icons.campaign_rounded,
                  size: 16,
                ),
              ),
              title: Text(
                notice.title.isEmpty ? 'Notice' : notice.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge,
              ),
              subtitle: Text(
                _publishedLabel(notice.publishedAt),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: tokens.textMuted,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _publishedLabel(String date) {
    final parsed = DateTime.tryParse(date);
    if (parsed == null) return date.isEmpty ? 'Published notice' : date;
    return DateFormat('d MMM yyyy').format(parsed);
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: tokens.spacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: tokens.roleColor(SchoolDeskRole.parent)),
          SizedBox(width: tokens.spacing.sm),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: tokens.textMuted,
              ),
            ),
          ),
          SizedBox(width: tokens.spacing.sm),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: theme.textTheme.labelLarge,
            ),
          ),
        ],
      ),
    );
  }
}

class _Action {
  final String label;
  final String subtitle;
  final String illustrationAsset;
  final String route;
  final Color color;

  const _Action(
    this.label,
    this.subtitle,
    this.illustrationAsset,
    this.route,
    this.color,
  );
}

String _text(dynamic value) => value?.toString().trim() ?? '';

List<Map<String, dynamic>> _listMap(dynamic value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((row) => Map<String, dynamic>.from(row))
      .toList();
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

String _classLabel(Map<String, dynamic> row) {
  final grade = _firstText(row, ['class', 'class_name', 'grade_name']);
  final section = _firstText(row, ['section', 'section_name']);
  final label = [grade, section].where((part) => part.isNotEmpty).join(' ');
  return label.isEmpty ? 'Class not assigned' : label;
}

String _rollLabel(Map<String, dynamic> row) {
  final value = _firstText(row, [
    'rollNo',
    'roll_no',
    'admission_no',
    'student_code',
  ]);
  return value.isEmpty ? 'Not published' : value;
}

String _attendanceLabel(Map<String, dynamic> row) {
  final raw = _firstExisting(row, [
    'attendance',
    'attendance_percentage',
    'attendance_pct',
  ]);
  if (raw == null) return 'Not published';
  if (raw is num) return '${raw.toStringAsFixed(0)}%';
  final text = _text(raw);
  return text.isEmpty ? 'Not published' : text;
}

String _homeworkDueLabel(Map<String, dynamic> row) {
  final count = _homeworkDueCount(row);
  return count == null ? 'Not published' : '$count';
}

int? _homeworkDueCount(Map<String, dynamic> row) {
  final raw = _firstExisting(row, [
    'homeworkDue',
    'homework_due',
    'pending_homework_count',
  ]);
  if (raw == null) return null;
  if (raw is num) return raw.toInt();
  return int.tryParse(_text(raw));
}

String _classTeacherLabel(Map<String, dynamic> row) {
  final value = _firstText(row, [
    'classTeacher',
    'class_teacher',
    'class_teacher_name',
  ]);
  return value.isEmpty ? 'Not published' : value;
}

String _feeDueLabel(Map<String, dynamic> child) {
  final hasAmount = _hasExisting(child, 'pending_fee_balance');
  final hasCount = _hasExisting(child, 'pending_invoices');
  if (!hasAmount && !hasCount) return 'Not published';
  final amount = _numValue(child['pending_fee_balance']);
  final count = _intValue(child['pending_invoices']);
  if (!hasAmount && count > 0) {
    return '$count pending invoice${count == 1 ? '' : 's'}';
  }
  if (hasAmount && !hasCount) {
    return amount <= 0
        ? 'No pending dues'
        : '₹${amount.toStringAsFixed(0)} due';
  }
  if (amount <= 0 && count <= 0) return 'No pending dues';
  if (count <= 0) return '₹${amount.toStringAsFixed(0)} due';
  return '₹${amount.toStringAsFixed(0)} ($count invoice${count == 1 ? '' : 's'})';
}

String _feeStateLabel(Map<String, dynamic> child) {
  final label = _feeDueLabel(child);
  if (label == 'Not published') return 'Not published';
  return label == 'No pending dues' ? 'Clear' : 'Due';
}

String _feeActionLabel(Map<String, dynamic> dashboard) {
  final metrics = dashboard['metrics'];
  final source = metrics is Map ? metrics : const {};
  final amount = _numValue(source['pending_fee_balance']);
  if (amount <= 0) return 'Fees';
  return 'Fees ₹${amount.toStringAsFixed(0)} due';
}

double _numValue(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse('${value ?? ''}') ?? 0;
}

int _intValue(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse('${value ?? ''}') ?? 0;
}

String _firstText(Map<String, dynamic> row, List<String> keys) {
  for (final key in keys) {
    final text = _text(row[key]);
    if (text.isNotEmpty) return text;
  }
  return '';
}

dynamic _firstExisting(Map<String, dynamic> row, List<String> keys) {
  for (final key in keys) {
    if (_hasExisting(row, key)) return row[key];
  }
  return null;
}

bool _hasExisting(Map<String, dynamic> row, String key) {
  if (!row.containsKey(key) || row[key] == null) return false;
  if (row[key] is String) return _text(row[key]).isNotEmpty;
  return true;
}

String _initials(String name) {
  final value = name
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .take(2)
      .map((part) => part[0].toUpperCase())
      .join();
  return value.isEmpty ? 'S' : value;
}
