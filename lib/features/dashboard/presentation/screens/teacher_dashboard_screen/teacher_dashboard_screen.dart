import 'package:flutter/material.dart';

import 'package:schooldesk1/core/navigation/role_nav_indices.dart';
import 'package:schooldesk1/routes/app_routes.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/services/role_access_service.dart';
import 'package:schooldesk1/core/services/notification_service.dart';
import 'package:schooldesk1/core/services/demo_local_api_service.dart';
import 'package:schooldesk1/core/services/realtime_refresh_service.dart';
import 'package:schooldesk1/core/widgets/erp_components.dart';
import 'package:schooldesk1/core/widgets/teacher_flow_ui.dart';
import 'package:schooldesk1/core/utils/extensions.dart';
import 'package:schooldesk1/features/dashboard/presentation/widgets/todays_highlights_card.dart';
import 'package:schooldesk1/core/desktop/desktop_responsive_breakpoints.dart';
import 'package:schooldesk1/features/dashboard/presentation/widgets/teacher_dashboard_desktop_shell.dart';
import 'package:schooldesk1/features/dashboard/presentation/widgets/school_feed_preview.dart';

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
  int _unreadNotifications = 0;
  int _attendancePending = 0;
  StaffAttendanceModel? _myAttendance;
  List<Map<String, dynamic>> _timetable = const [];
  int _weeklyTimetableCount = 0;
  List<AnnouncementModel> _announcements = const [];
  List<Map<String, dynamic>> _eventPosts = const [];
  RealtimeRefreshSubscription? _realtimeSubscription;

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
    _realtimeSubscription = RealtimeRefreshService.instance.subscribe(
      channelName: 'teacher-dashboard',
      modules: const {'announcements', 'event_posts', 'attendance'},
      onRefresh: () {
        if (mounted) _loadDashboardData(forceRefresh: true);
      },
    );
  }

  @override
  void dispose() {
    _realtimeSubscription?.dispose();
    super.dispose();
  }

  Future<void> _loadDashboardData({bool forceRefresh = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await RoleAccessService.initialize();
      final api = BackendApiClient.instance;
      final results = await Future.wait([
        api.getAnnouncements(forceRefresh: forceRefresh),
        _loadMyAttendanceSafely(api),
        _loadUnreadNotificationsCount(),
        api.getHomeFeedEventPosts().catchError(
          (_) => const <Map<String, dynamic>>[],
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _roleScopeLoaded = true;
        _teacherName = RoleAccessService.teacherName;
        _assignedClass = RoleAccessService.teacherClassName;
        _assignedSubject = RoleAccessService.teacherSubject;
        _timetable = RoleAccessService.teacherTimetableToday;
        _weeklyTimetableCount = RoleAccessService.teacherTimetable.length;
        _attendancePending = _timetable
            .where(
              (row) => teacherFlowText(row['done']).toLowerCase() != 'true',
            )
            .length;
        _myAttendance = results[1] as StaffAttendanceModel?;
        _announcements = (results[0] as List)
            .whereType<AnnouncementModel>()
            .toList();
        _eventPosts = (results[3] as List)
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList();
        _unreadNotifications = results[2] as int? ?? 0;
        _loading = false;
      });
    } on Object catch (_) {
      if (!mounted) return;
      setState(() {
        _roleScopeLoaded = true;
        _loading = false;
        _error = DemoLocalApiService.instance.isActive
            ? 'Unable to load offline demo data.'
            : 'Unable to load teacher dashboard from backend.';
      });
    }
  }

  Future<StaffAttendanceModel?> _loadMyAttendanceSafely(
    BackendApiClient api,
  ) async {
    try {
      return await api.getMyStaffAttendanceToday();
    } on Object catch (_) {
      return null;
    }
  }

  Future<int> _loadUnreadNotificationsCount() async {
    try {
      final service = await NotificationService.getInstance();
      return service.getUnreadCountForRole('teacher');
    } on Object catch (_) {
      return 0;
    }
  }

  Future<void> _openMyAttendance() async {
    await Navigator.pushNamed(
      context,
      AppRoutes.teacherMyAttendance,
      arguments: {'auto_scan': true},
    );
    if (mounted) await _loadDashboardData(forceRefresh: true);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = DesktopBreakpoints.isDesktopWidth(width);
    final shortName = _teacherName.split(' ').take(2).join(' ');

    return TeacherFlowScaffold(
      title: 'Arish Ville Preschool',
      subtitle: DemoLocalApiService.instance.isActive
          ? 'Offline Demo · $shortName · classroom flow'
          : '$shortName · classroom flow',
      selectedIndex: TeacherNav.dashboard,
      actions: [
        IconButton(
          tooltip: 'How to use the application',
          icon: const Icon(Icons.help_outline_rounded),
          onPressed: () => Navigator.pushNamed(context, AppRoutes.help),
        ),
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
                    border: Border.all(color: teacherFlowBackground, width: 2),
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
      onRefresh: () => _loadDashboardData(forceRefresh: true),
      child: isDesktop
          ? TeacherDashboardDesktopBody(
              teacherName: _teacherName,
              assignedClass: _assignedClass,
              assignedSubject: _assignedSubject,
              timetable: _timetable,
              announcements: _announcements,
              eventPosts: _eventPosts,
              attendancePending: _attendancePending,
              roleScopeLoaded: _roleScopeLoaded,
              hasStaffLink: RoleAccessService.hasTeacherStaffLink,
              hasAssignedClasses: RoleAccessService.hasAssignedClasses,
              myAttendance: _myAttendance,
              onRefresh: () => _loadDashboardData(forceRefresh: true),
            )
          : TeacherFlowScrollView(
              children: [
                if (_roleScopeLoaded && !RoleAccessService.hasTeacherStaffLink)
                  const TeacherFlowCard(
                    icon: Icons.badge_outlined,
                    title:
                        'Your teacher account is not linked to a staff profile.',
                    subtitle: 'Please contact Admin/Principal.',
                  )
                else if (_roleScopeLoaded &&
                    !RoleAccessService.hasAssignedClasses)
                  const TeacherFlowCard(
                    icon: Icons.class_outlined,
                    title: 'No classes assigned yet.',
                    subtitle:
                        'Your classes, timetable, and attendance workflow will appear after assignment.',
                  )
                else
                  TeacherCurrentClassCard(
                    greeting: 'Hello, $shortName',
                    classLabel: _currentClassTitle,
                    subject: _currentSubject,
                    timeLabel: _currentTimeLabel,
                    avatar: RoleAccessService.teacherAvatarUrl,
                    actions: [
                      TeacherFlowAction(
                        label: 'My Login',
                        icon: Icons.qr_code_scanner_rounded,
                        filled: true,
                        onTap: _openMyAttendance,
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
                const SizedBox(height: 14),
                const TodaysHighlightsCard(role: 'teacher'),
                const SizedBox(height: 18),
                const TeacherFlowSectionHeader(title: 'Quick Actions'),
                const SizedBox(height: 10),
                _TeacherQuickActionGrid(),
                const SizedBox(height: 18),
                TeacherFlowSectionHeader(
                  title: 'Today Action Queue',
                  actionLabel: 'Refresh',
                  onAction: () => _loadDashboardData(forceRefresh: true),
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
                const SizedBox(height: 18),
                SchoolFeedPreview(
                  posts: _eventPosts,
                  accentColor: teacherFlowAccent,
                  showParentVisibility: true,
                  actionLabel: 'Manage',
                  onAction: () =>
                      Navigator.pushNamed(context, AppRoutes.teacherEventPosts),
                ),
                if (_announcements.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  TeacherFlowSectionHeader(
                    title: 'School Notices',
                    actionLabel: 'Open',
                    onAction: () => Navigator.pushNamed(
                      context,
                      AppRoutes.teacherCommunication,
                    ),
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
          onTap: _openMyAttendance,
        ),
      ),
    );
    if (_timetable.isEmpty) {
      final hasWeeklyTimetable = _weeklyTimetableCount > 0;
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: TeacherTimelineItem(
            time: 'Today',
            title: hasWeeklyTimetable
                ? 'No classes scheduled today'
                : 'No timetable period found',
            subtitle: hasWeeklyTimetable
                ? 'Your weekly timetable is available in My Timetable.'
                : 'Your backend timetable is empty for today.',
            icon: Icons.event_busy_rounded,
            color: Colors.orange,
            onTap: () => Navigator.pushNamed(
              context,
              hasWeeklyTimetable
                  ? AppRoutes.teacherTimetable
                  : AppRoutes.teacherClasses,
            ),
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
              subtitle: 'Review the class period and plan next steps.',
              icon: Icons.auto_stories_rounded,
              onTap: () =>
                  Navigator.pushNamed(context, AppRoutes.teacherLessonPlanner),
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
      const _QuickAction(
        'My Classes',
        'Assigned sections',
        SchoolDeskUiIllustrations.classRoutine,
        AppRoutes.teacherClasses,
      ),
      const _QuickAction(
        'Timetable',
        'Today and week',
        SchoolDeskUiIllustrations.calendar,
        AppRoutes.teacherTimetable,
      ),
      const _QuickAction(
        'Student Attendance',
        'Mark your class',
        SchoolDeskUiIllustrations.attendance,
        AppRoutes.teacherAttendance,
      ),
      const _QuickAction(
        'Lesson Planner',
        'Weekly plans',
        SchoolDeskUiIllustrations.lessonPlanner,
        AppRoutes.teacherLessonPlanner,
      ),
      const _QuickAction(
        'Dairy',
        'Assignments & review',
        SchoolDeskUiIllustrations.homework,
        AppRoutes.teacherHomework,
      ),
      const _QuickAction(
        'Leaves',
        'Apply and track',
        SchoolDeskUiIllustrations.calendar,
        AppRoutes.teacherLeave,
      ),
      const _QuickAction(
        'Event Posts',
        'School updates',
        SchoolDeskUiIllustrations.notices,
        AppRoutes.teacherEventPosts,
      ),
      const _QuickAction(
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
