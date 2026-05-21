import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../routes/app_routes.dart';
import '../../services/backend_api_client.dart';
import '../../services/role_access_service.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/erp_components.dart';
import '../../widgets/erp_module_scaffold.dart';
import '../../widgets/teacher_navigation.dart';

class TeacherDashboardScreen extends StatefulWidget {
  final bool loadData;
  final List<Map<String, dynamic>> initialTimetable;

  const TeacherDashboardScreen({
    super.key,
    this.loadData = true,
    this.initialTimetable = const [],
  });

  @override
  State<TeacherDashboardScreen> createState() => _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends State<TeacherDashboardScreen> {
  int _selectedNavIndex = 0;
  bool _loading = false;
  String? _error;
  String _teacherName = 'Teacher';
  String _assignedClass = 'Not assigned';
  String _assignedSubject = 'General';
  int _leaveBalance = 0;
  int _assignedStudents = 0;
  int _homeworkDue = 0;
  int _homeworkTotal = 0;
  int _unreadMessages = 0;
  double _attendancePct = 0;
  int _attendancePresent = 0;
  int _attendanceMarked = 0;
  List<Map<String, dynamic>> _timetable = const [];
  List<AnnouncementModel> _announcements = const [];

  @override
  void initState() {
    super.initState();
    _timetable = widget.initialTimetable
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList();
    if (widget.loadData) {
      _loadDashboardData();
    }
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await RoleAccessService.initialize();
      final api = BackendApiClient.instance;
      final results = await Future.wait([
        api.getDashboard('teacher'),
        api.getAnnouncements(),
      ]);
      final dashboard = Map<String, dynamic>.from(results[0] as Map);
      final metrics = Map<String, dynamic>.from(
        dashboard['metrics'] as Map? ?? const {},
      );
      final attendance = Map<String, dynamic>.from(
        dashboard['today_attendance'] as Map? ?? const {},
      );

      if (!mounted) return;
      setState(() {
        _teacherName = RoleAccessService.teacherName;
        _assignedClass = RoleAccessService.teacherClassName;
        _assignedSubject = RoleAccessService.teacherSubject;
        _leaveBalance = RoleAccessService.teacherLeaveBalance;
        _timetable = RoleAccessService.teacherTimetableToday;
        _assignedStudents = _intValue(metrics['assigned_students']);
        _homeworkDue = _intValue(metrics['homework_due']);
        _homeworkTotal = _intValue(metrics['homework_total']);
        _unreadMessages = _intValue(metrics['unread_messages']);
        _attendancePct = _doubleValue(attendance['attendance_pct']);
        _attendancePresent = _intValue(attendance['present']);
        _attendanceMarked = _intValue(attendance['marked']);
        _announcements = (results[1] as List)
            .whereType<AnnouncementModel>()
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load teacher dashboard from backend.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final shortName = _teacherName.split(' ').take(2).join(' ');
    return SchoolDeskModuleScaffold(
      title: 'Teacher',
      subtitle:
          'Good morning, $shortName · $_assignedClass · $_assignedSubject',
      drawer: TeacherDrawer(
        selectedIndex: _selectedNavIndex,
        onDestinationSelected: (i) => setState(() => _selectedNavIndex = i),
      ),
      actions: [
        IconButton(
          tooltip: 'Notifications',
          icon: const Icon(Icons.notifications_outlined),
          onPressed: () => Navigator.pushNamed(
            context,
            AppRoutes.notificationCenter,
            arguments: 'teacher',
          ),
        ),
        IconButton(
          tooltip: 'Profile',
          icon: const Icon(Icons.account_circle_outlined),
          onPressed: () => Navigator.pushNamed(
            context,
            AppRoutes.profileScreen,
            arguments: 'teacher',
          ),
        ),
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
          label: 'Classes',
          icon: Icons.class_outlined,
          activeIcon: Icons.class_rounded,
          route: AppRoutes.teacherClasses,
        ),
        SchoolDeskModuleBottomAction(
          label: 'Attend',
          icon: Icons.how_to_reg_outlined,
          activeIcon: Icons.how_to_reg_rounded,
          route: AppRoutes.teacherAttendance,
        ),
        SchoolDeskModuleBottomAction(
          label: 'Homework',
          icon: Icons.assignment_outlined,
          activeIcon: Icons.assignment_rounded,
          route: AppRoutes.teacherHomework,
        ),
        SchoolDeskModuleBottomAction(
          label: 'More',
          icon: Icons.menu_rounded,
          activeIcon: Icons.menu_rounded,
          route: SchoolDeskModuleScaffold.openNavigationAction,
        ),
      ],
      bodyIsScrollable: true,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final tokens = Theme.of(context).schoolDesk;
    final horizontal = MediaQuery.sizeOf(context).width >= 760
        ? tokens.spacing.lg
        : tokens.spacing.md;

    Widget child;
    if (_loading) {
      child = const SchoolDeskStatusPanel.loading(
        message: 'Loading teacher dashboard',
      );
    } else if (_error != null) {
      child = SchoolDeskStatusPanel.error(
        title: 'Dashboard unavailable',
        message: _error!,
        onAction: _loadDashboardData,
      );
    } else {
      child = _TeacherDashboardContent(
        teacherName: _teacherName,
        assignedClass: _assignedClass,
        assignedSubject: _assignedSubject,
        assignedStudents: _assignedStudents,
        leaveBalance: _leaveBalance,
        homeworkDue: _homeworkDue,
        homeworkTotal: _homeworkTotal,
        unreadMessages: _unreadMessages,
        attendancePct: _attendancePct,
        attendancePresent: _attendancePresent,
        attendanceMarked: _attendanceMarked,
        timetable: _timetable,
        announcements: _announcements,
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

  int _intValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  double _doubleValue(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class _TeacherDashboardContent extends StatelessWidget {
  final String teacherName;
  final String assignedClass;
  final String assignedSubject;
  final int assignedStudents;
  final int leaveBalance;
  final int homeworkDue;
  final int homeworkTotal;
  final int unreadMessages;
  final double attendancePct;
  final int attendancePresent;
  final int attendanceMarked;
  final List<Map<String, dynamic>> timetable;
  final List<AnnouncementModel> announcements;

  const _TeacherDashboardContent({
    required this.teacherName,
    required this.assignedClass,
    required this.assignedSubject,
    required this.assignedStudents,
    required this.leaveBalance,
    required this.homeworkDue,
    required this.homeworkTotal,
    required this.unreadMessages,
    required this.attendancePct,
    required this.attendancePresent,
    required this.attendanceMarked,
    required this.timetable,
    required this.announcements,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;
    final teacherColor = tokens.roleColor(SchoolDeskRole.teacher);
    final compact = MediaQuery.sizeOf(context).width < 700;

    if (compact) {
      return _TeacherMobileWireframeDashboard(
        assignedClass: assignedClass,
        assignedSubject: assignedSubject,
        assignedStudents: assignedStudents,
        leaveBalance: leaveBalance,
        homeworkDue: homeworkDue,
        homeworkTotal: homeworkTotal,
        unreadMessages: unreadMessages,
        attendancePct: attendancePct,
        attendancePresent: attendancePresent,
        attendanceMarked: attendanceMarked,
        timetable: timetable,
        teacherColor: teacherColor,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SchoolDeskPageHeader(
          title: 'Teaching Workspace',
          subtitle:
              'Attendance, timetable, homework, and parent communication for $assignedClass.',
          actions: [
            FilledButton.icon(
              onPressed: () =>
                  Navigator.pushNamed(context, AppRoutes.teacherAttendance),
              icon: const Icon(Icons.how_to_reg_rounded, size: 18),
              label: const Text('Mark attendance'),
            ),
            OutlinedButton.icon(
              onPressed: () =>
                  Navigator.pushNamed(context, AppRoutes.teacherHomework),
              icon: const Icon(Icons.assignment_rounded, size: 18),
              label: const Text('Homework'),
            ),
          ],
        ),
        _TeacherQuickActions(teacherColor: teacherColor),
        SizedBox(height: tokens.spacing.md),
        SchoolDeskResponsiveGrid(
          minTileWidth: 210,
          mainAxisExtent: 118,
          children: [
            SchoolDeskKpiCard(
              title: 'My class',
              value: assignedClass,
              subtitle: assignedSubject,
              icon: Icons.class_rounded,
              color: teacherColor,
              onTap: () =>
                  Navigator.pushNamed(context, AppRoutes.teacherClasses),
            ),
            SchoolDeskKpiCard(
              title: 'Today periods',
              value: '${timetable.length}',
              subtitle: 'Backend timetable',
              icon: Icons.schedule_rounded,
              color: theme.colorScheme.secondary,
            ),
            SchoolDeskKpiCard(
              title: 'Students',
              value: '$assignedStudents',
              subtitle: 'Assigned total',
              icon: Icons.people_rounded,
              color: theme.colorScheme.primary,
              onTap: () =>
                  Navigator.pushNamed(context, AppRoutes.teacherClasses),
            ),
            SchoolDeskKpiCard(
              title: 'Attendance',
              value: '${attendancePct.toStringAsFixed(0)}%',
              subtitle: '$attendancePresent/$attendanceMarked marked',
              icon: Icons.how_to_reg_rounded,
              color: theme.colorScheme.secondary,
              onTap: () =>
                  Navigator.pushNamed(context, AppRoutes.teacherAttendance),
            ),
            SchoolDeskKpiCard(
              title: 'Homework due',
              value: '$homeworkDue',
              subtitle: '$homeworkTotal total',
              icon: Icons.assignment_late_rounded,
              color: theme.colorScheme.error,
              onTap: () =>
                  Navigator.pushNamed(context, AppRoutes.teacherHomework),
            ),
            SchoolDeskKpiCard(
              title: 'Leave balance',
              value: '$leaveBalance',
              subtitle: 'Days remaining',
              icon: Icons.event_available_rounded,
              color: teacherColor,
              onTap: () => Navigator.pushNamed(context, AppRoutes.teacherLeave),
            ),
          ],
        ),
        SizedBox(height: tokens.spacing.lg),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;
            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: _TimetableCard(rows: timetable)),
                  SizedBox(width: tokens.spacing.md),
                  Expanded(
                    flex: 2,
                    child: Column(
                      children: [
                        _TaskCard(
                          homeworkDue: homeworkDue,
                          unreadMessages: unreadMessages,
                        ),
                        SizedBox(height: tokens.spacing.md),
                        _AnnouncementsCard(announcements: announcements),
                      ],
                    ),
                  ),
                ],
              );
            }
            return Column(
              children: [
                _TimetableCard(rows: timetable),
                SizedBox(height: tokens.spacing.md),
                _TaskCard(
                  homeworkDue: homeworkDue,
                  unreadMessages: unreadMessages,
                ),
                SizedBox(height: tokens.spacing.md),
                _AnnouncementsCard(announcements: announcements),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _TeacherMobileWireframeDashboard extends StatelessWidget {
  final String assignedClass;
  final String assignedSubject;
  final int assignedStudents;
  final int leaveBalance;
  final int homeworkDue;
  final int homeworkTotal;
  final int unreadMessages;
  final double attendancePct;
  final int attendancePresent;
  final int attendanceMarked;
  final List<Map<String, dynamic>> timetable;
  final Color teacherColor;

  const _TeacherMobileWireframeDashboard({
    required this.assignedClass,
    required this.assignedSubject,
    required this.assignedStudents,
    required this.leaveBalance,
    required this.homeworkDue,
    required this.homeworkTotal,
    required this.unreadMessages,
    required this.attendancePct,
    required this.attendancePresent,
    required this.attendanceMarked,
    required this.timetable,
    required this.teacherColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;
    final nextClass = timetable.isEmpty ? null : timetable.first;
    final pendingTasks = homeworkDue + unreadMessages;
    final actions = [
      _TeacherVisualActionSpec(
        label: 'Routine',
        value: '${timetable.length}',
        illustrationAsset: SchoolDeskUiIllustrations.classRoutine,
        color: teacherColor,
        route: AppRoutes.teacherClasses,
      ),
      _TeacherVisualActionSpec(
        label: 'Attendance',
        value: '${attendancePct.toStringAsFixed(0)}%',
        illustrationAsset: SchoolDeskUiIllustrations.attendance,
        color: theme.colorScheme.secondary,
        route: AppRoutes.teacherAttendance,
      ),
      _TeacherVisualActionSpec(
        label: 'Homework',
        value: '$homeworkDue',
        illustrationAsset: SchoolDeskUiIllustrations.homework,
        color: theme.colorScheme.primary,
        route: AppRoutes.teacherHomework,
      ),
      _TeacherVisualActionSpec(
        label: 'Chat',
        value: '$unreadMessages',
        illustrationAsset: SchoolDeskUiIllustrations.chat,
        color: theme.colorScheme.primary,
        route: AppRoutes.teacherCommunication,
      ),
      _TeacherVisualActionSpec(
        label: 'Resources',
        value: 'Open',
        illustrationAsset: SchoolDeskUiIllustrations.resources,
        color: teacherColor,
        route: AppRoutes.teacherResources,
      ),
      _TeacherVisualActionSpec(
        label: 'Planner',
        value: '$leaveBalance',
        illustrationAsset: SchoolDeskUiIllustrations.lessonPlanner,
        color: theme.colorScheme.secondary,
        route: AppRoutes.teacherLessonPlanner,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text("Today's Overview", style: theme.textTheme.titleMedium),
        SizedBox(height: tokens.spacing.md),
        SchoolDeskVisualSummaryRecord(
          title: nextClass == null ? 'No Class Now' : 'Next Class',
          subtitle: nextClass == null
              ? '$assignedClass - $assignedSubject'
              : _nextClassSubtitle(nextClass),
          value: nextClass == null ? '0' : _periodLabel(nextClass),
          icon: Icons.class_rounded,
          color: teacherColor,
          onTap: () => Navigator.pushNamed(context, AppRoutes.teacherClasses),
        ),
        SizedBox(height: tokens.spacing.sm),
        SchoolDeskVisualSummaryRecord(
          title: 'Pending Tasks',
          subtitle:
              '$homeworkDue homework, $unreadMessages messages, $homeworkTotal total',
          value: '$pendingTasks',
          icon: Icons.pending_actions_rounded,
          color: pendingTasks > 0
              ? theme.colorScheme.error
              : theme.colorScheme.secondary,
          onTap: () => Navigator.pushNamed(context, AppRoutes.teacherHomework),
        ),
        SizedBox(height: tokens.spacing.sm),
        SchoolDeskVisualSummaryRecord(
          title: 'Attendance',
          subtitle: '$attendancePresent/$attendanceMarked marked',
          value: '${attendancePct.toStringAsFixed(0)}%',
          icon: Icons.how_to_reg_rounded,
          color: theme.colorScheme.secondary,
          onTap: () =>
              Navigator.pushNamed(context, AppRoutes.teacherAttendance),
        ),
        SizedBox(height: tokens.spacing.sm),
        SchoolDeskVisualSummaryRecord(
          title: 'Class Students',
          subtitle: assignedClass,
          value: '$assignedStudents',
          icon: Icons.groups_rounded,
          color: teacherColor,
          onTap: () => Navigator.pushNamed(context, AppRoutes.teacherClasses),
        ),
        SizedBox(height: tokens.spacing.md),
        SchoolDeskVisualPanel(
          title: 'Quick Actions',
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

  String _nextClassSubtitle(Map<String, dynamic> row) {
    final subject = '${row['subject'] ?? assignedSubject}'.trim();
    final className = '${row['class'] ?? assignedClass}'.trim();
    return '$subject - $className';
  }

  String _periodLabel(Map<String, dynamic> row) {
    final value = '${row['period'] ?? ''}'.trim();
    return value.isEmpty ? '${timetable.length}' : 'P$value';
  }
}

class _TeacherVisualActionSpec {
  final String label;
  final String value;
  final String illustrationAsset;
  final Color color;
  final String route;

  const _TeacherVisualActionSpec({
    required this.label,
    required this.value,
    required this.illustrationAsset,
    required this.color,
    required this.route,
  });
}

class _TimetableCard extends StatelessWidget {
  final List<Map<String, dynamic>> rows;

  const _TimetableCard({required this.rows});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;
    if (rows.isEmpty) {
      return const SchoolDeskSectionCard(
        title: 'Today timetable',
        subtitle: 'Class periods assigned to you today.',
        child: SchoolDeskStatusPanel.empty(
          title: 'No periods today',
          message: 'Your backend timetable has no sessions for today.',
        ),
      );
    }

    return SchoolDeskSectionCard(
      title: 'Today timetable',
      subtitle: 'Class periods assigned to you today.',
      action: TextButton(
        onPressed: () => Navigator.pushNamed(context, AppRoutes.teacherClasses),
        child: const Text('Open classes'),
      ),
      child: Column(
        children: [
          for (final row in rows)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                radius: 18,
                backgroundColor: theme.colorScheme.primaryContainer,
                foregroundColor: theme.colorScheme.primary,
                child: Text('${row['period'] ?? '-'}'),
              ),
              title: Text(
                '${row['subject'] ?? 'Subject'} - ${row['class'] ?? 'Class'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge,
              ),
              subtitle: Text(
                '${row['time'] ?? 'Time not set'}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: tokens.textMuted,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TeacherQuickActions extends StatelessWidget {
  final Color teacherColor;

  const _TeacherQuickActions({required this.teacherColor});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final actions = [
      _TeacherAction(
        'Take attendance',
        'Mark today',
        SchoolDeskUiIllustrations.attendance,
        AppRoutes.teacherAttendance,
        theme.colorScheme.secondary,
      ),
      _TeacherAction(
        'Homework',
        'Assign and review',
        SchoolDeskUiIllustrations.homework,
        AppRoutes.teacherHomework,
        teacherColor,
      ),
      _TeacherAction(
        'Class communication',
        'Parents and notices',
        SchoolDeskUiIllustrations.chat,
        AppRoutes.teacherCommunication,
        theme.colorScheme.primary,
      ),
      _TeacherAction(
        'Lesson planner',
        'Plan classes',
        SchoolDeskUiIllustrations.lessonPlanner,
        AppRoutes.teacherLessonPlanner,
        teacherColor,
      ),
    ];

    return SchoolDeskSectionCard(
      title: 'Today quick actions',
      subtitle: 'Fast access to class execution workflows.',
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

class _TeacherAction {
  final String label;
  final String subtitle;
  final String illustrationAsset;
  final String route;
  final Color color;

  const _TeacherAction(
    this.label,
    this.subtitle,
    this.illustrationAsset,
    this.route,
    this.color,
  );
}

class _TaskCard extends StatelessWidget {
  final int homeworkDue;
  final int unreadMessages;

  const _TaskCard({required this.homeworkDue, required this.unreadMessages});

  @override
  Widget build(BuildContext context) {
    final tasks = [
      if (homeworkDue > 0)
        _Task(
          '$homeworkDue homework item${homeworkDue == 1 ? '' : 's'} due',
          'Open homework',
          AppRoutes.teacherHomework,
          Icons.assignment_late_rounded,
        ),
      if (unreadMessages > 0)
        _Task(
          '$unreadMessages unread parent message${unreadMessages == 1 ? '' : 's'}',
          'Open communication',
          AppRoutes.teacherCommunication,
          Icons.chat_rounded,
        ),
    ];

    if (tasks.isEmpty) {
      return const SchoolDeskSectionCard(
        title: 'Priority tasks',
        subtitle: 'Actionable teaching work from backend metrics.',
        child: SchoolDeskStatusPanel.empty(
          title: 'No urgent tasks',
          message: 'Homework and parent messages are clear right now.',
        ),
      );
    }

    return SchoolDeskSectionCard(
      title: 'Priority tasks',
      subtitle: 'Actionable teaching work from backend metrics.',
      child: Column(
        children: [
          for (final task in tasks)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(task.icon),
              title: Text(task.title),
              trailing: TextButton(
                onPressed: () => Navigator.pushNamed(context, task.route),
                child: Text(task.action),
              ),
            ),
        ],
      ),
    );
  }
}

class _AnnouncementsCard extends StatelessWidget {
  final List<AnnouncementModel> announcements;

  const _AnnouncementsCard({required this.announcements});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;
    if (announcements.isEmpty) {
      return const SchoolDeskSectionCard(
        title: 'Announcements',
        subtitle: 'School notices visible to teachers.',
        child: SchoolDeskStatusPanel.empty(
          title: 'No announcements',
          message: 'Published announcements will appear here.',
        ),
      );
    }

    return SchoolDeskSectionCard(
      title: 'Announcements',
      subtitle: 'School notices visible to teachers.',
      child: Column(
        children: [
          for (final announcement in announcements.take(4))
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                announcement.isUrgent
                    ? Icons.priority_high_rounded
                    : Icons.campaign_rounded,
                color: announcement.isUrgent
                    ? theme.colorScheme.error
                    : theme.colorScheme.primary,
              ),
              title: Text(
                announcement.title.isEmpty
                    ? 'Announcement'
                    : announcement.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                _publishedLabel(announcement.publishedAt),
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

class _Task {
  final String title;
  final String action;
  final String route;
  final IconData icon;

  const _Task(this.title, this.action, this.route, this.icon);
}
