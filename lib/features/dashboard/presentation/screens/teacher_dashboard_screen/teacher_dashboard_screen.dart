import 'package:flutter/material.dart';

import 'package:schooldesk1/core/navigation/role_nav_indices.dart';
import 'package:schooldesk1/routes/app_routes.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/services/role_access_service.dart';
import 'package:schooldesk1/core/services/notification_service.dart';
import 'package:schooldesk1/core/widgets/erp_components.dart';
import 'package:schooldesk1/core/widgets/teacher_flow_ui.dart';
import 'package:schooldesk1/core/utils/extensions.dart';

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
  bool _loading = false;
  late bool _roleScopeLoaded;
  String? _error;
  String _teacherName = 'Teacher';
  String _assignedClass = 'Not assigned';
  String _assignedSubject = 'General';
  int _assignedClasses = 0;
  int _homeworkDue = 0;
  int _homeworkTotal = 0;
  int _homeworkToday = 0;
  String _homeworkReminderStatus = 'pending';
  int _unreadMessages = 0;
  int _unreadNotifications = 0;
  int _attendancePending = 0;
  int _attendancePresentToday = 0;
  int _attendanceMarkedToday = 0;
  StaffAttendanceModel? _myAttendance;
  List<Map<String, dynamic>> _timetable = const [];
  List<AnnouncementModel> _announcements = const [];

  @override
  void initState() {
    super.initState();
    _roleScopeLoaded = false;
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
        _loadMyAttendanceSafely(api),
        _loadHomeworkReminderSafely(api),
        _loadUnreadNotificationsCount(),
      ]);
      final dashboard = Map<String, dynamic>.from(results[0] as Map);
      final metrics = Map<String, dynamic>.from(
        dashboard['metrics'] as Map? ?? const {},
      );
      final todayAttendance = Map<String, dynamic>.from(
        dashboard['today_attendance'] as Map? ?? const {},
      );
      if (!mounted) return;
      setState(() {
        _roleScopeLoaded = true;
        _teacherName = RoleAccessService.teacherName;
        _assignedClass = RoleAccessService.teacherClassName;
        _assignedSubject = RoleAccessService.teacherSubject;
        _timetable = RoleAccessService.teacherTimetableToday;
        _assignedClasses =
            RoleAccessService.teacherClassTeacherClasses.isNotEmpty ? 1 : 0;
        _homeworkDue = teacherFlowInt(metrics['homework_due']);
        _homeworkTotal = teacherFlowInt(metrics['homework_total']);
        _homeworkToday = teacherFlowInt(metrics['homework_today']);
        final reminder = Map<String, dynamic>.from(results[3] as Map);
        _homeworkReminderStatus = teacherFlowText(
          reminder['status'] ?? metrics['homework_reminder_status'],
          fallback: _homeworkToday > 0 ? 'assigned' : 'pending',
        ).toLowerCase();
        _unreadMessages = teacherFlowInt(metrics['unread_messages']);
        _attendancePending = _timetable
            .where(
              (row) => teacherFlowText(row['done']).toLowerCase() != 'true',
            )
            .length;
        _attendancePresentToday = teacherFlowInt(todayAttendance['present']);
        _attendanceMarkedToday = teacherFlowInt(todayAttendance['marked']);
        _myAttendance = results[2] as StaffAttendanceModel?;
        _announcements = (results[1] as List)
            .whereType<AnnouncementModel>()
            .toList();
        _unreadNotifications = results[4] as int? ?? 0;
        _loading = false;
      });
      _checkEndOfDayReminder();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _roleScopeLoaded = true;
        _loading = false;
        _error = 'Unable to load teacher dashboard from backend.';
      });
    }
  }

  Future<void> _checkEndOfDayReminder() async {
    // Only show a reminder after 3 PM if no homework has been assigned today.
    // Route the reminder into the teacher's permanent Diary workflow.
    final now = DateTime.now();
    if (now.hour >= 15 &&
        _homeworkToday == 0 &&
        _homeworkReminderStatus == 'pending') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('End of Day Reminder'),
            content: const Text(
              'You have not updated today\'s class diary. Would you like to add the class summary now?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Dismiss'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, AppRoutes.teacherDiary);
                },
                child: const Text('Open Diary'),
              ),
            ],
          ),
        );
      });
    }
  }

  Future<StaffAttendanceModel?> _loadMyAttendanceSafely(
    BackendApiClient api,
  ) async {
    try {
      return await api.getMyStaffAttendanceToday();
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> _loadHomeworkReminderSafely(
    BackendApiClient api,
  ) async {
    try {
      return await api.getTodayHomeworkReminderStatus(
        sectionId: RoleAccessService.teacherClassId,
      );
    } catch (_) {
      return const {};
    }
  }

  Future<int> _loadUnreadNotificationsCount() async {
    try {
      final service = await NotificationService.getInstance();
      return service.getUnreadCountForRole('teacher');
    } catch (_) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final shortName = _teacherName.split(' ').take(2).join(' ');
    return TeacherFlowScaffold(
      title: 'Teacher',
      subtitle: '$shortName · classroom flow',
      selectedIndex: TeacherNav.dashboard,
      actions: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              tooltip: 'Notifications',
              icon: const Icon(Icons.notifications_none_rounded),
              onPressed: () => Navigator.pushNamed(
                context,
                AppRoutes.notificationCenter,
                arguments: 'teacher',
              ),
            ),
            if (_unreadNotifications > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: context.appTheme.error,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: teacherFlowBackground,
                      width: 2,
                    ),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  child: Text(
                    _unreadNotifications > 9 ? '9+' : '$_unreadNotifications',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ],
      loading: _loading,
      error: _error,
      onRefresh: _loadDashboardData,
      child: TeacherFlowScrollView(
        children: [
          if (_roleScopeLoaded && !RoleAccessService.hasTeacherStaffLink)
            const TeacherFlowCard(
              icon: Icons.badge_outlined,
              title: 'Your teacher account is not linked to a staff profile.',
              subtitle: 'Please contact Admin/Principal.',
            )
          else if (_roleScopeLoaded && !RoleAccessService.hasAssignedClasses)
            const TeacherFlowCard(
              icon: Icons.class_outlined,
              title: 'No classes assigned yet.',
              subtitle:
                  'Your classes, timetable, and attendance workflow will appear after assignment.',
            )
          else
            TeacherCurrentClassCard(
              greeting: 'Good morning, $shortName',
              classLabel: _currentClassTitle,
              subject: _currentSubject,
              timeLabel: _currentTimeLabel,
              actions: [
                TeacherFlowAction(
                  label: 'My QR Check-in',
                  icon: Icons.qr_code_scanner_rounded,
                  filled: true,
                  onTap: () => Navigator.pushNamed(
                    context,
                    AppRoutes.teacherMyAttendance,
                    arguments: {'auto_scan': true},
                  ),
                ),
                TeacherFlowAction(
                  label: 'Student Attendance',
                  icon: Icons.how_to_reg_rounded,
                  onTap: () =>
                      Navigator.pushNamed(context, AppRoutes.teacherAttendance),
                ),
                TeacherFlowAction(
                  label: 'Timetable',
                  icon: Icons.calendar_month_rounded,
                  onTap: () =>
                      Navigator.pushNamed(context, AppRoutes.teacherTimetable),
                ),
              ],
            ),
          if (_timetable.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              '$_currentSubject - $_currentClassTitle',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: teacherFlowInk,
              ),
            ),
          ],
          const SizedBox(height: 18),
          const TeacherFlowSectionHeader(title: 'Quick Actions'),
          const SizedBox(height: 10),
          _TeacherQuickActionGrid(),
          const SizedBox(height: 18),
          TeacherFlowMetricGrid(
            metrics: [
              TeacherFlowMetric(
                label: 'Classes',
                value: '$_assignedClasses',
                icon: Icons.groups_rounded,
                color: teacherFlowAccent,
                tone: const Color(0xFFE3FAF5),
              ),
              TeacherFlowMetric(
                label: 'Attendance',
                value: _attendanceMarkedToday > 0
                    ? '$_attendancePresentToday/$_attendanceMarkedToday'
                    : '$_attendancePending pending',
                icon: Icons.fact_check_rounded,
                color: Colors.indigo,
                tone: const Color(0xFFEAF0FF),
              ),
              TeacherFlowMetric(
                label: 'Practice',
                value: '$_homeworkDue/$_homeworkTotal',
                icon: Icons.menu_book_outlined,
                color: Colors.orange,
                tone: const Color(0xFFFFF4E5),
              ),
              TeacherFlowMetric(
                label: 'Messages',
                value: '${_unreadMessages + _announcements.length}',
                icon: Icons.markunread_rounded,
                color: Colors.purple,
                tone: const Color(0xFFF5EAFE),
              ),
            ],
          ),
          const SizedBox(height: 18),
          TeacherFlowSectionHeader(
            title: 'Today Action Queue',
            actionLabel: 'Refresh',
            onAction: _loadDashboardData,
          ),
          const SizedBox(height: 10),
          ..._teacherActionQueue(context),
          const SizedBox(height: 18),
          TeacherFlowSectionHeader(
            title: 'Today Feed',
            actionLabel: 'Classes',
            onAction: () =>
                Navigator.pushNamed(context, AppRoutes.teacherClasses),
          ),
          const SizedBox(height: 10),
          ..._todayFeed(context),
          if (_announcements.isNotEmpty) ...[
            const SizedBox(height: 18),
            TeacherFlowSectionHeader(
              title: 'School Notices',
              actionLabel: 'Open',
              onAction: () =>
                  Navigator.pushNamed(context, AppRoutes.teacherCommunication),
            ),
            const SizedBox(height: 10),
            ..._announcements
                .take(3)
                .map(
                  (notice) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: TeacherFlowCard(
                      icon: Icons.campaign_rounded,
                      title: notice.title,
                      subtitle: notice.content,
                      status: notice.isUrgent ? 'Urgent' : 'Notice',
                      statusColor: notice.isUrgent
                          ? context.appTheme.error
                          : teacherFlowAccent,
                    ),
                  ),
                ),
          ],
        ],
      ),
    );
  }

  // A teacher is assigned one class for the whole day and teaches all subjects
  // for that class. We no longer try to guess the "current" slot from time strings.

  /// Returns the teacher's assigned class name (from timetable or profile).
  String get _currentClassTitle {
    if (_timetable.isNotEmpty) {
      final classLabel = teacherFlowText(_timetable.first['class']);
      if (classLabel.isNotEmpty) return classLabel;
    }
    return _assignedClass;
  }

  /// Returns a comma-separated list of all subjects the teacher covers today.
  String get _currentSubject {
    if (_timetable.isNotEmpty) {
      final subjects = _timetable
          .map((row) => teacherFlowText(row['subject']))
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList();
      if (subjects.isNotEmpty) return subjects.join(', ');
    }
    return _assignedSubject;
  }

  /// Since the teacher covers one class all day, the time label is always 'All Day'.
  String get _currentTimeLabel => 'All Day';

  List<Widget> _todayFeed(BuildContext context) {
    final rows = <Widget>[];
    final punchStatus = _myAttendance == null
        ? 'Punch-in pending'
        : 'Punch-in ${_myAttendance!.checkInTimeLabel}';
    rows.add(
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TeacherTimelineItem(
          time: 'Now',
          title: 'Self Attendance',
          subtitle: punchStatus,
          icon: Icons.qr_code_scanner_rounded,
          onTap: () => Navigator.pushNamed(
            context,
            AppRoutes.teacherMyAttendance,
            arguments: {'auto_scan': true},
          ),
        ),
      ),
    );
    if (_timetable.isEmpty) {
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: TeacherTimelineItem(
            time: 'Today',
            title: 'No timetable period found',
            subtitle: 'Your backend timetable is empty for today.',
            icon: Icons.event_busy_rounded,
            color: Colors.orange,
            onTap: () => Navigator.pushNamed(context, AppRoutes.teacherClasses),
          ),
        ),
      );
    } else {
      final uniqueSubjects = _timetable
          .map((row) => teacherFlowText(row['subject']))
          .toSet()
          .toList();
      final classLabel = teacherFlowText(
        _timetable.first['class'],
        fallback: 'Class',
      );
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: TeacherTimelineItem(
            time: 'All Day',
            title: 'Today\'s Assigned Class: $classLabel',
            subtitle: 'Subjects: ${uniqueSubjects.join(', ')}',
            icon: Icons.class_rounded,
            color: teacherFlowAccent,
            onTap: () {},
          ),
        ),
      );
      for (final row in _timetable) {
        final subject = teacherFlowText(row['subject'], fallback: 'Subject');
        final time = teacherFlowText(row['time'], fallback: 'Period');
        rows.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: TeacherTimelineItem(
              time: time,
              title: '$subject - $classLabel',
              subtitle: 'Attendance, diary, and notes ready.',
              icon: Icons.auto_stories_rounded,
              onTap: () => Navigator.pushNamed(context, AppRoutes.teacherDiary),
            ),
          ),
        );
      }
    }
    return rows;
  }

  List<Widget> _teacherActionQueue(BuildContext context) {
    final rows = <Widget>[
      _teacherActionItem(
        context,
        time: 'Required',
        title: 'Mark Student Attendance',
        subtitle: _attendancePending > 0
            ? 'Finish attendance for $_attendancePending pending period${_attendancePending == 1 ? '' : 's'}.'
            : 'Open attendance when your class is ready.',
        icon: Icons.how_to_reg_rounded,
        color: Colors.indigo,
        route: AppRoutes.teacherAttendance,
      ),
      _teacherActionItem(
        context,
        time: 'After class',
        title: 'Record Class Diary',
        subtitle: 'Capture what was taught and the next class plan.',
        icon: Icons.bookmarks_rounded,
        color: teacherFlowAccent,
        route: AppRoutes.teacherDiary,
      ),
      _teacherActionItem(
        context,
        time: 'Today',
        title: 'Update Diary',
        subtitle: _homeworkToday > 0
            ? 'Today\'s diary practice is recorded.'
            : 'Capture today\'s class work before end of day.',
        icon: Icons.menu_book_rounded,
        color: Colors.orange,
        route: AppRoutes.teacherDiary,
      ),
      _teacherActionItem(
        context,
        time: 'Parents',
        title: 'Review PTM Slots',
        subtitle: 'Check upcoming parent meeting slots and requests.',
        icon: Icons.event_available_rounded,
        color: Colors.teal,
        route: AppRoutes.teacherParentInteraction,
      ),
      _teacherActionItem(
        context,
        time: 'Admin',
        title: 'Track Leave',
        subtitle: 'Review your leave requests and approval status.',
        icon: Icons.event_busy_rounded,
        color: Colors.purple,
        route: AppRoutes.teacherLeave,
      ),
    ];
    return rows;
  }

  Widget _teacherActionItem(
    BuildContext context, {
    required String time,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String route,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TeacherTimelineItem(
        time: time,
        title: title,
        subtitle: subtitle,
        icon: icon,
        color: color,
        onTap: () => Navigator.pushNamed(context, route),
      ),
    );
  }
}

class _TeacherQuickActionGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final actions = [
      _QuickAction(
        'My Classes',
        'Assigned sections',
        SchoolDeskUiIllustrations.classRoutine,
        AppRoutes.teacherClasses,
      ),
      _QuickAction(
        'Timetable',
        'Today and week',
        SchoolDeskUiIllustrations.calendar,
        AppRoutes.teacherTimetable,
      ),
      _QuickAction(
        'Student Attendance',
        'Mark your class',
        SchoolDeskUiIllustrations.attendance,
        AppRoutes.teacherAttendance,
      ),
      _QuickAction(
        'Diary',
        'Today and practice',
        SchoolDeskUiIllustrations.resources,
        AppRoutes.teacherDiary,
      ),
      _QuickAction(
        'Lesson Planner',
        'Weekly plans',
        SchoolDeskUiIllustrations.lessonPlanner,
        AppRoutes.teacherLessonPlanner,
      ),
      _QuickAction(
        'Event Posts',
        'School updates',
        SchoolDeskUiIllustrations.notices,
        AppRoutes.teacherEventPosts,
      ),
      _QuickAction(
        'Gallery',
        'School photos',
        SchoolDeskUiIllustrations.resources,
        AppRoutes.schoolGallery,
      ),
    ];
    return SchoolDeskResponsiveGrid(
      spacing: 16,
      children: [
        for (final action in actions)
          SchoolDeskIllustratedActionTile(
            label: action.title,
            subtitle: action.subtitle,
            illustrationAsset: action.illustrationAsset,
            color: teacherFlowAccent,
            onTap: () => Navigator.pushNamed(context, action.route),
          ),
      ],
    );
  }
}

class _QuickAction {
  final String title;
  final String subtitle;
  final String illustrationAsset;
  final String route;

  const _QuickAction(
    this.title,
    this.subtitle,
    this.illustrationAsset,
    this.route,
  );
}
