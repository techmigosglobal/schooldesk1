import 'package:flutter/material.dart';

import 'package:schooldesk1/routes/app_routes.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/services/role_access_service.dart';
import 'package:schooldesk1/core/theme/app_theme.dart';
import 'package:schooldesk1/core/widgets/erp_components.dart';
import 'package:schooldesk1/core/widgets/teacher_flow_ui.dart';

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
  String? _error;
  String _teacherName = 'Teacher';
  String _assignedClass = 'Not assigned';
  String _assignedSubject = 'General';
  int _assignedStudents = 0;
  int _homeworkDue = 0;
  int _homeworkTotal = 0;
  int _unreadMessages = 0;
  double _attendancePct = 0;
  StaffAttendanceModel? _myAttendance;
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
        _loadMyAttendanceSafely(api),
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
        _timetable = RoleAccessService.teacherTimetableToday;
        _assignedStudents = teacherFlowInt(metrics['assigned_students']);
        _homeworkDue = teacherFlowInt(metrics['homework_due']);
        _homeworkTotal = teacherFlowInt(metrics['homework_total']);
        _unreadMessages = teacherFlowInt(metrics['unread_messages']);
        _attendancePct = _doubleValue(attendance['attendance_pct']);
        _myAttendance = results[2] as StaffAttendanceModel?;
        _announcements = (results[1] as List)
            .whereType<AnnouncementModel>()
            .toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Unable to load teacher dashboard from backend.';
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

  @override
  Widget build(BuildContext context) {
    final shortName = _teacherName.split(' ').take(2).join(' ');
    return TeacherFlowScaffold(
      title: 'Teacher',
      subtitle: '$shortName · classroom flow',
      selectedIndex: 0,
      loading: _loading,
      error: _error,
      onRefresh: _loadDashboardData,
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
      ],
      child: TeacherFlowScrollView(
        children: [
          TeacherCurrentClassCard(
            greeting: 'Good morning, $shortName',
            classLabel: _currentClassTitle,
            subject: _currentSubject,
            timeLabel: _currentTimeLabel,
            actions: [
              TeacherFlowAction(
                label: 'Scan QR',
                icon: Icons.qr_code_scanner_rounded,
                filled: true,
                onTap: () =>
                    Navigator.pushNamed(context, AppRoutes.teacherMyAttendance),
              ),
              TeacherFlowAction(
                label: 'Student Attendance',
                icon: Icons.how_to_reg_rounded,
                onTap: () =>
                    Navigator.pushNamed(context, AppRoutes.teacherAttendance),
              ),
              TeacherFlowAction(
                label: 'Homework',
                icon: Icons.assignment_rounded,
                onTap: () =>
                    Navigator.pushNamed(context, AppRoutes.teacherHomework),
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
                label: 'Students',
                value: '$_assignedStudents',
                icon: Icons.groups_rounded,
                color: teacherFlowAccent,
                tone: const Color(0xFFE3FAF5),
              ),
              TeacherFlowMetric(
                label: 'Attendance',
                value: '${_attendancePct.toStringAsFixed(0)}%',
                icon: Icons.fact_check_rounded,
                color: Colors.indigo,
                tone: const Color(0xFFEAF0FF),
              ),
              TeacherFlowMetric(
                label: 'Homework',
                value: '$_homeworkDue/$_homeworkTotal',
                icon: Icons.assignment_outlined,
                color: Colors.orange,
                tone: const Color(0xFFFFF4E5),
              ),
              TeacherFlowMetric(
                label: 'Messages',
                value: '$_unreadMessages',
                icon: Icons.markunread_rounded,
                color: Colors.purple,
                tone: const Color(0xFFF5EAFE),
              ),
            ],
          ),
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
                          ? AppTheme.error
                          : teacherFlowAccent,
                    ),
                  ),
                ),
          ],
        ],
      ),
    );
  }

  String get _currentClassTitle {
    final slot = _currentSlot;
    final slotClass = teacherFlowText(slot['class']);
    if (slotClass.isNotEmpty) return slotClass;
    return _assignedClass;
  }

  String get _currentSubject {
    final slot = _currentSlot;
    final slotSubject = teacherFlowText(slot['subject']);
    if (slotSubject.isNotEmpty) return slotSubject;
    return _assignedSubject;
  }

  String get _currentTimeLabel {
    final slot = _currentSlot;
    final slotTime = teacherFlowText(slot['time']);
    return slotTime.isEmpty ? 'Next teaching moment' : slotTime;
  }

  Map<String, dynamic> get _currentSlot {
    if (_timetable.isEmpty) return const {};
    final upcoming = _timetable.where((row) {
      final start = _slotStart(row);
      if (start == null) return false;
      return !start.isBefore(DateTime.now());
    }).toList();
    if (upcoming.isNotEmpty) {
      upcoming.sort((a, b) => _slotStart(a)!.compareTo(_slotStart(b)!));
      return upcoming.first;
    }
    final sorted = [..._timetable]
      ..sort((a, b) {
        final aStart = _slotStart(a);
        final bStart = _slotStart(b);
        if (aStart == null && bStart == null) return 0;
        if (aStart == null) return 1;
        if (bStart == null) return -1;
        return bStart.compareTo(aStart);
      });
    return sorted.first;
  }

  DateTime? _slotStart(Map<String, dynamic> row) {
    final time = teacherFlowText(row['time']);
    final match = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(time);
    if (match == null) return null;
    final now = DateTime.now();
    final hour = int.tryParse(match.group(1) ?? '') ?? 0;
    final minute = int.tryParse(match.group(2) ?? '') ?? 0;
    return DateTime(now.year, now.month, now.day, hour, minute);
  }

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
          onTap: () =>
              Navigator.pushNamed(context, AppRoutes.teacherMyAttendance),
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
      for (final row in _timetable.take(4)) {
        final subject = teacherFlowText(row['subject'], fallback: 'Subject');
        final classLabel = teacherFlowText(row['class'], fallback: 'Class');
        final time = teacherFlowText(row['time'], fallback: 'Period');
        rows.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: TeacherTimelineItem(
              time: time,
              title: '$subject - $classLabel',
              subtitle: 'Attendance, homework, and notes ready.',
              icon: Icons.auto_stories_rounded,
              onTap: () =>
                  Navigator.pushNamed(context, AppRoutes.teacherHomework),
            ),
          ),
        );
      }
    }
    return rows;
  }

  double _doubleValue(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('${value ?? ''}') ?? 0;
  }
}

class _TeacherQuickActionGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final actions = [
      _QuickAction(
        'My Classes',
        'Open schedule',
        SchoolDeskUiIllustrations.classRoutine,
        AppRoutes.teacherClasses,
      ),
      _QuickAction(
        'Class Attendance',
        'First period flow',
        SchoolDeskUiIllustrations.attendance,
        AppRoutes.teacherAttendance,
      ),
      _QuickAction(
        'Homework / Diary',
        'Share or log no homework',
        SchoolDeskUiIllustrations.homework,
        AppRoutes.teacherHomework,
      ),
      _QuickAction(
        'Communication',
        'Chats and notices',
        SchoolDeskUiIllustrations.chat,
        AppRoutes.teacherCommunication,
      ),
      _QuickAction(
        'My Leaves',
        'Apply and track',
        SchoolDeskUiIllustrations.calendar,
        AppRoutes.teacherLeave,
      ),
      _QuickAction(
        'Reports',
        'Daily teaching log',
        SchoolDeskUiIllustrations.resources,
        AppRoutes.teacherReports,
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
