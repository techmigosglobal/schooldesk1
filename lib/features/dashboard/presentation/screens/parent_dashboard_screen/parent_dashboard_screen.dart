import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:schooldesk1/routes/app_routes.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/theme/design_tokens.dart';
import 'package:schooldesk1/core/widgets/dashboard_fab_widget.dart';
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
      title: 'Child Profile',
      subtitle: 'Linked student details and quick actions',
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
      floatingActionButton: const DashboardFabWidget(
        role: DashboardRole.parent,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
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
        dashboard: dashboard,
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
  final Map<String, dynamic> dashboard;
  final Map<String, dynamic> child;
  final Color parentColor;

  const _ParentMobileWireframeDashboard({
    required this.children,
    required this.activeChildIndex,
    required this.onChildSelected,
    required this.dashboard,
    required this.child,
    required this.parentColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;
    final childName = _name(child, fallback: 'Student');
    final classLabel = _classLabel(child);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: _ParentChildPillSelector(
            children: children,
            activeIndex: activeChildIndex,
            onChanged: onChildSelected,
            color: parentColor,
          ),
        ),
        SizedBox(height: tokens.spacing.md),
        _ParentProfileCard(
          childName: childName,
          classLabel: classLabel,
          child: child,
          parentColor: parentColor,
        ),
        SizedBox(height: tokens.spacing.md),
        _ParentSectionTitle('Academic Snapshot'),
        SizedBox(height: tokens.spacing.sm),
        _AcademicSnapshotCard(
          child: child,
          dashboard: dashboard,
          parentColor: parentColor,
        ),
        SizedBox(height: tokens.spacing.md),
        _GuardianContactCard(child: child, parentColor: parentColor),
        SizedBox(height: tokens.spacing.md),
        _ParentSectionTitle('Quick Actions'),
        SizedBox(height: tokens.spacing.sm),
        _ParentQuickActionGrid(parentColor: parentColor),
      ],
    );
  }
}

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
                color: Colors.white,
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

class _ParentProfileCard extends StatelessWidget {
  final String childName;
  final String classLabel;
  final Map<String, dynamic> child;
  final Color parentColor;

  const _ParentProfileCard({
    required this.childName,
    required this.classLabel,
    required this.child,
    required this.parentColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;
    final admission = _rollLabel(child);
    return _ParentReferenceCard(
      padding: EdgeInsets.all(tokens.spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 38,
                backgroundColor: parentColor.withAlpha(22),
                foregroundColor: const Color(0xFF0F172A),
                child: Text(
                  _initials(childName),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              SizedBox(width: tokens.spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SchoolDeskAdaptiveText(
                      childName,
                      maxLines: 1,
                      minFontSize: 16,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: tokens.spacing.sm),
                    Wrap(
                      spacing: tokens.spacing.sm,
                      runSpacing: tokens.spacing.xs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          classLabel,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: tokens.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '|',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: tokens.panelBorder,
                          ),
                        ),
                        Text(
                          admission == 'Not published'
                              ? 'Adm No: Not published'
                              : 'Adm No: $admission',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: tokens.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: tokens.spacing.sm),
                    _ParentStatusPill(
                      label: _studentStatusLabel(child),
                      color: parentColor,
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: tokens.spacing.md),
          Divider(color: tokens.panelBorder),
          SizedBox(height: tokens.spacing.xs),
          Row(
            children: [
              Expanded(
                child: _ParentProfileInfo(
                  icon: Icons.calendar_today_outlined,
                  label: 'Date of Birth',
                  value: _dateOfBirthLabel(child),
                  color: tokens.textMuted,
                ),
              ),
              SizedBox(
                height: 44,
                child: VerticalDivider(color: tokens.panelBorder),
              ),
              Expanded(
                child: _ParentProfileInfo(
                  icon: Icons.groups_2_outlined,
                  label: 'Blood Group',
                  value: _bloodGroupLabel(child),
                  color: tokens.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ParentStatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _ParentStatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(24),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ParentProfileInfo extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _ParentProfileInfo({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 24, color: color),
        SizedBox(width: tokens.spacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: tokens.textMuted,
                ),
              ),
              SizedBox(height: tokens.spacing.xs),
              SchoolDeskAdaptiveText(
                value,
                maxLines: 1,
                minFontSize: 11,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ParentSectionTitle extends StatelessWidget {
  final String title;

  const _ParentSectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
    );
  }
}

class _AcademicSnapshotCard extends StatelessWidget {
  final Map<String, dynamic> child;
  final Map<String, dynamic> dashboard;
  final Color parentColor;

  const _AcademicSnapshotCard({
    required this.child,
    required this.dashboard,
    required this.parentColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _ParentReferenceCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: _SnapshotTile(
              icon: Icons.how_to_reg_rounded,
              value: _attendanceFromChildOrDashboard(child, dashboard),
              label: 'Attendance\n(This Month)',
              color: const Color(0xFF16A34A),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _SnapshotTile(
              icon: Icons.assignment_rounded,
              value: _homeworkFromChildOrDashboard(child, dashboard),
              label: 'Pending\nHomework',
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _SnapshotTile(
              icon: Icons.account_balance_wallet_rounded,
              value: _feeCompactLabel(child),
              label: 'Fee Status',
              color: const Color(0xFFEA580C),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _SnapshotTile(
              icon: Icons.star_rounded,
              value: _latestMarksLabel(child),
              label: 'Marks\n(Latest)',
              color: const Color(0xFF7C3AED),
            ),
          ),
        ],
      ),
    );
  }
}

class _SnapshotTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _SnapshotTile({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;
    return Container(
      constraints: const BoxConstraints(minHeight: 106),
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.xs,
        vertical: tokens.spacing.compact,
      ),
      decoration: BoxDecoration(
        color: color.withAlpha(14),
        borderRadius: BorderRadius.circular(tokens.radius.card),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          SizedBox(height: tokens.spacing.sm),
          SchoolDeskAdaptiveText(
            value,
            maxLines: 1,
            textAlign: TextAlign.center,
            minFontSize: 10,
            style: theme.textTheme.titleMedium?.copyWith(
              color: value == 'No Dues' ? const Color(0xFFEA580C) : null,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: tokens.spacing.xs),
          SchoolDeskAdaptiveText(
            label,
            maxLines: 2,
            textAlign: TextAlign.center,
            minFontSize: 8,
            style: theme.textTheme.bodySmall?.copyWith(
              color: tokens.textMuted,
              height: 1.15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _GuardianContactCard extends StatelessWidget {
  final Map<String, dynamic> child;
  final Color parentColor;

  const _GuardianContactCard({required this.child, required this.parentColor});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;
    final guardian = _guardianMap(child);
    final name = _guardianName(guardian);
    final relationship = _guardianRelationship(guardian);
    final phone = _guardianPhone(guardian);
    final email = _guardianEmail(guardian);
    final contactLine = [
      phone,
      email,
    ].where((part) => part != 'Not published').join('  •  ');

    return _ParentReferenceCard(
      padding: EdgeInsets.all(tokens.spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ParentSectionTitle('Guardian & Contact'),
          SizedBox(height: tokens.spacing.sm),
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: parentColor.withAlpha(18),
                  borderRadius: BorderRadius.circular(tokens.radius.control),
                ),
                child: Icon(Icons.person_rounded, color: parentColor),
              ),
              SizedBox(width: tokens.spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SchoolDeskAdaptiveText(
                      name,
                      maxLines: 1,
                      minFontSize: 12,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: tokens.spacing.xs),
                    Text(
                      relationship,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: tokens.textMuted,
                      ),
                    ),
                    SizedBox(height: tokens.spacing.xs),
                    SchoolDeskAdaptiveText(
                      contactLine.isEmpty ? 'Not published' : contactLine,
                      maxLines: 1,
                      minFontSize: 9,
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
          SizedBox(height: tokens.spacing.sm),
          Text(
            'Keep your contact details updated for important school communications.',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: tokens.textMuted,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

class _ParentQuickActionGrid extends StatelessWidget {
  final Color parentColor;

  const _ParentQuickActionGrid({required this.parentColor});

  @override
  Widget build(BuildContext context) {
    final actions = [
      _ParentQuickAction(
        label: 'Academic\nProgress',
        icon: Icons.trending_up_rounded,
        color: parentColor,
        route: AppRoutes.parentAcademicProgress,
      ),
      _ParentQuickAction(
        label: 'Attendance',
        icon: Icons.how_to_reg_rounded,
        color: const Color(0xFF16A34A),
        route: AppRoutes.parentAttendance,
      ),
      _ParentQuickAction(
        label: 'Documents',
        icon: Icons.description_rounded,
        color: const Color(0xFF2563EB),
        route: AppRoutes.parentDocuments,
      ),
      _ParentQuickAction(
        label: 'Leave\nRequest',
        icon: Icons.event_busy_rounded,
        color: const Color(0xFFDC2626),
        route: AppRoutes.parentLeave,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 360;
        return GridView.count(
          crossAxisCount: compact ? 2 : 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: compact ? 1.15 : 0.78,
          children: [
            for (final action in actions)
              _ParentQuickActionTile(action: action),
          ],
        );
      },
    );
  }
}

class _ParentQuickAction {
  final String label;
  final IconData icon;
  final Color color;
  final String route;

  const _ParentQuickAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.route,
  });
}

class _ParentQuickActionTile extends StatelessWidget {
  final _ParentQuickAction action;

  const _ParentQuickActionTile({required this.action});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;
    return InkWell(
      borderRadius: BorderRadius.circular(tokens.radius.card),
      onTap: () => Navigator.pushNamed(context, action.route),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spacing.xs,
          vertical: tokens.spacing.md,
        ),
        decoration: BoxDecoration(
          color: tokens.panel,
          borderRadius: BorderRadius.circular(tokens.radius.card),
          border: Border.all(color: tokens.panelBorder),
          boxShadow: tokens.elevation.card,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: action.color.withAlpha(18),
                borderRadius: BorderRadius.circular(tokens.radius.control),
              ),
              child: Icon(action.icon, color: action.color, size: 24),
            ),
            SizedBox(height: tokens.spacing.md),
            SchoolDeskAdaptiveText(
              action.label,
              maxLines: 2,
              textAlign: TextAlign.center,
              minFontSize: 9,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w800,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ParentReferenceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const _ParentReferenceCard({required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).schoolDesk;
    return Container(
      padding: padding ?? EdgeInsets.all(tokens.spacing.lg),
      decoration: BoxDecoration(
        color: tokens.panel,
        borderRadius: BorderRadius.circular(tokens.radius.card),
        border: Border.all(color: tokens.panelBorder),
        boxShadow: tokens.elevation.card,
      ),
      child: child,
    );
  }
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

String _childSelectorLabel(Map<String, dynamic> child) {
  final name = _name(child, fallback: 'Student');
  final grade = _firstText(child, ['class', 'class_name', 'grade_name']);
  return grade.isEmpty ? name : '$name ($grade)';
}

String _studentStatusLabel(Map<String, dynamic> child) {
  final label = _firstText(child, ['student_status_label', 'status_label']);
  if (label.isNotEmpty && label != 'Not marked') return label;
  final status = _firstText(child, ['status']);
  if (status.isEmpty) return 'Active';
  return status[0].toUpperCase() + status.substring(1).toLowerCase();
}

String _dateOfBirthLabel(Map<String, dynamic> child) {
  final raw = _firstText(child, ['date_of_birth', 'dob', 'birth_date']);
  if (raw.isEmpty) return 'Not published';
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return raw;
  return DateFormat('d MMM yyyy').format(parsed.toLocal());
}

String _bloodGroupLabel(Map<String, dynamic> child) {
  final medical = _mapValue(child['medical_record']);
  final value = _firstText(
    {...child, ...medical},
    ['blood_group', 'bloodGroup', 'blood_type'],
  );
  return value.isEmpty ? 'Not published' : value;
}

String _attendanceFromChildOrDashboard(
  Map<String, dynamic> child,
  Map<String, dynamic> dashboard,
) {
  final childLabel = _attendanceLabel(child);
  if (childLabel != 'Not published') return childLabel;
  final attendance = _mapValue(dashboard['attendance']);
  final raw = _firstExisting(attendance, ['attendance_pct', 'percent']);
  if (raw == null) return 'Not published';
  if (raw is num) return '${raw.toStringAsFixed(0)}%';
  final text = _text(raw);
  return text.isEmpty ? 'Not published' : text;
}

String _homeworkFromChildOrDashboard(
  Map<String, dynamic> child,
  Map<String, dynamic> dashboard,
) {
  final childCount = _homeworkDueCount(child);
  if (childCount != null) return '$childCount';
  final metrics = _mapValue(dashboard['metrics']);
  final raw = _firstExisting(metrics, ['open_homework', 'homework_open']);
  if (raw == null) return 'Not published';
  if (raw is num) return '${raw.toInt()}';
  final text = _text(raw);
  return text.isEmpty ? 'Not published' : text;
}

String _feeCompactLabel(Map<String, dynamic> child) {
  final label = _feeDueLabel(child);
  if (label == 'No pending dues') return 'No Dues';
  if (label == 'Not published') return 'Not published';
  return 'Due';
}

String _latestMarksLabel(Map<String, dynamic> child) {
  final direct = _firstText(child, ['latest_marks', 'marks_latest']);
  if (direct.isNotEmpty) return direct;
  final performance = _mapValue(child['performance_summary']);
  final marksCount = _intValue(performance['marks_count']);
  if (marksCount <= 0) return '-';
  final grade = _text(performance['grade']);
  if (grade.isNotEmpty && grade != 'N/A') return grade;
  final percent = _numValue(performance['average_percent']);
  return percent <= 0 ? '-' : '${percent.toStringAsFixed(0)}%';
}

Map<String, dynamic> _guardianMap(Map<String, dynamic> child) {
  final primary = _mapValue(child['primary_guardian']);
  if (primary.isNotEmpty) return primary;
  final guardians = _listMap(child['guardians']);
  if (guardians.isNotEmpty) return guardians.first;
  final parents = _listMap(child['parent_accounts']);
  if (parents.isNotEmpty) return parents.first;
  return const <String, dynamic>{};
}

String _guardianName(Map<String, dynamic> guardian) {
  final value = _firstText(guardian, [
    'full_name',
    'name',
    'username',
    'parent_name',
  ]);
  return value.isEmpty ? 'Not published' : value;
}

String _guardianRelationship(Map<String, dynamic> guardian) {
  final value = _firstText(guardian, ['relationship', 'relation']);
  return value.isEmpty ? 'Guardian' : value;
}

String _guardianPhone(Map<String, dynamic> guardian) {
  final value = _firstText(guardian, ['phone', 'mobile', 'contact_number']);
  return value.isEmpty ? 'Not published' : value;
}

String _guardianEmail(Map<String, dynamic> guardian) {
  final value = _firstText(guardian, ['email']);
  return value.isEmpty ? 'Not published' : value;
}

Map<String, dynamic> _mapValue(dynamic value) {
  if (value is! Map) return const <String, dynamic>{};
  return Map<String, dynamic>.from(value);
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
