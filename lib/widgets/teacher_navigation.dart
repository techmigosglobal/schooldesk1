import 'package:flutter/material.dart';

import '../routes/app_routes.dart';
import '../services/backend_api_client.dart';
import '../services/logout_service.dart';
import '../services/notification_service.dart';
import '../services/role_access_service.dart';
import '../theme/design_tokens.dart';
import 'erp_navigation.dart';

class TeacherDrawer extends StatefulWidget {
  final int selectedIndex;
  final Function(int) onDestinationSelected;

  const TeacherDrawer({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  @override
  State<TeacherDrawer> createState() => _TeacherDrawerState();
}

class _TeacherDrawerState extends State<TeacherDrawer> {
  NotificationService? _notifService;
  int _unreadCount = 0;
  String _schoolName = 'School';
  String _schoolSubtitle = 'Teacher workspace';

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _loadSchoolIdentity();
  }

  Future<void> _loadNotifications() async {
    final svc = await NotificationService.getInstance();
    if (!mounted) return;
    setState(() {
      _notifService = svc;
      _unreadCount = svc.getUnreadCountForRole('teacher');
    });
    svc.addListener(_onNotifChanged);
  }

  Future<void> _loadSchoolIdentity() async {
    try {
      final school = await BackendApiClient.instance.getCurrentSchool();
      if (!mounted) return;
      setState(() {
        _schoolName = _text(school['name'], fallback: 'School');
        _schoolSubtitle = _text(
          school['affiliation_board'],
          fallback: _text(school['school_type'], fallback: 'Teacher workspace'),
        );
      });
    } catch (_) {
      // Keep neutral labels if the backend is temporarily unavailable.
    }
  }

  void _onNotifChanged() {
    if (!mounted) return;
    setState(() {
      _unreadCount = _notifService?.getUnreadCountForRole('teacher') ?? 0;
    });
  }

  @override
  void dispose() {
    _notifService?.removeListener(_onNotifChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final teacherName = RoleAccessService.teacherName;
    final className = RoleAccessService.teacherClassName;
    return SchoolDeskNavigationDrawer(
      role: SchoolDeskRole.teacher,
      portalLabel: 'Teacher Portal',
      organizationName: _schoolName,
      organizationSubtitle: _schoolSubtitle,
      userName: teacherName,
      userSubtitle: 'Class Teacher - $className',
      initials: _initials(teacherName, fallback: 'TE'),
      portalIcon: Icons.cast_for_education_rounded,
      selectedIndex: widget.selectedIndex,
      onDestinationSelected: widget.onDestinationSelected,
      sections: [
        const SchoolDeskNavigationSection(
          label: 'Today',
          items: [
            SchoolDeskNavigationItem(
              index: 0,
              icon: Icons.dashboard_outlined,
              activeIcon: Icons.dashboard_rounded,
              label: 'Dashboard',
              route: AppRoutes.teacherDashboard,
            ),
            SchoolDeskNavigationItem(
              index: 14,
              icon: Icons.qr_code_scanner_outlined,
              activeIcon: Icons.qr_code_scanner_rounded,
              label: 'My Attendance',
              route: AppRoutes.teacherMyAttendance,
            ),
          ],
        ),
        SchoolDeskNavigationSection(
          label: 'Classroom Flow',
          items: [
            const SchoolDeskNavigationItem(
              index: 1,
              icon: Icons.class_outlined,
              activeIcon: Icons.class_rounded,
              label: 'My Classes',
              route: AppRoutes.teacherClasses,
            ),
            const SchoolDeskNavigationItem(
              index: 2,
              icon: Icons.how_to_reg_outlined,
              activeIcon: Icons.how_to_reg_rounded,
              label: 'Student Attendance',
              route: AppRoutes.teacherAttendance,
            ),
            SchoolDeskNavigationItem(
              index: 3,
              icon: Icons.assignment_outlined,
              activeIcon: Icons.assignment_rounded,
              label: 'Homework / Diary',
              route: AppRoutes.teacherHomework,
              badgeCount: RoleAccessService.teacherHomeworkDue,
            ),
            const SchoolDeskNavigationItem(
              index: 13,
              icon: Icons.menu_book_outlined,
              activeIcon: Icons.menu_book_rounded,
              label: 'Class Diary',
              route: AppRoutes.teacherDiary,
            ),
          ],
        ),
        const SchoolDeskNavigationSection(
          label: 'Learning Support',
          items: [
            SchoolDeskNavigationItem(
              index: 5,
              icon: Icons.trending_up_outlined,
              activeIcon: Icons.trending_up_rounded,
              label: 'Student Performance',
              route: AppRoutes.teacherPerformance,
            ),
            SchoolDeskNavigationItem(
              index: 6,
              icon: Icons.note_alt_outlined,
              activeIcon: Icons.note_alt_rounded,
              label: 'Student Notes',
              route: AppRoutes.teacherStudentNotes,
            ),
          ],
        ),
        SchoolDeskNavigationSection(
          label: 'Communication',
          items: [
            SchoolDeskNavigationItem(
              index: 8,
              icon: Icons.chat_outlined,
              activeIcon: Icons.chat_rounded,
              label: 'Communication',
              route: AppRoutes.teacherCommunication,
              badgeCount: RoleAccessService.teacherUnreadMessages,
            ),
            const SchoolDeskNavigationItem(
              index: 9,
              icon: Icons.family_restroom_outlined,
              activeIcon: Icons.family_restroom_rounded,
              label: 'Parent Interaction',
              route: AppRoutes.teacherParentInteraction,
            ),
            SchoolDeskNavigationItem(
              index: 16,
              icon: Icons.feedback_outlined,
              activeIcon: Icons.feedback_rounded,
              label: 'Homework Feedback',
              route: AppRoutes.homeworkMessaging,
              arguments: {
                'role': 'teacher',
                'userId': RoleAccessService.teacherUserId,
                'staffId': RoleAccessService.teacherStaffId,
                'userName': teacherName,
              },
            ),
          ],
        ),
        const SchoolDeskNavigationSection(
          label: 'Operations',
          items: [
            SchoolDeskNavigationItem(
              index: 10,
              icon: Icons.event_busy_outlined,
              activeIcon: Icons.event_busy_rounded,
              label: 'Leave',
              route: AppRoutes.teacherLeave,
            ),
            SchoolDeskNavigationItem(
              index: 11,
              icon: Icons.report_problem_outlined,
              activeIcon: Icons.report_problem_rounded,
              label: 'Discipline / Incidents',
              route: AppRoutes.teacherDiscipline,
            ),
            SchoolDeskNavigationItem(
              index: 12,
              icon: Icons.bar_chart_outlined,
              activeIcon: Icons.bar_chart_rounded,
              label: 'Reports',
              route: AppRoutes.teacherReports,
            ),
          ],
        ),
        const SchoolDeskNavigationSection(
          label: 'School Info',
          items: [
            SchoolDeskNavigationItem(
              index: 15,
              icon: Icons.auto_stories_outlined,
              activeIcon: Icons.auto_stories_rounded,
              label: 'Academic Info',
              route: AppRoutes.teacherAcademicInfo,
            ),
          ],
        ),
      ],
      footerActions: [
        const SchoolDeskNavigationFooterAction(
          icon: Icons.search_rounded,
          label: 'Global Search',
          route: AppRoutes.globalSearch,
        ),
        SchoolDeskNavigationFooterAction(
          icon: Icons.notifications_outlined,
          label: 'Notifications',
          route: AppRoutes.notificationCenter,
          arguments: 'teacher',
          badgeCount: _unreadCount,
        ),
        const SchoolDeskNavigationFooterAction(
          icon: Icons.account_circle_outlined,
          label: 'Profile',
          route: AppRoutes.profileScreen,
          arguments: 'teacher',
        ),
        const SchoolDeskNavigationFooterAction(
          icon: Icons.settings_outlined,
          label: 'Settings',
          route: AppRoutes.settingsScreen,
          arguments: 'teacher',
        ),
        SchoolDeskNavigationFooterAction(
          icon: Icons.logout_rounded,
          label: 'Sign Out',
          color: Theme.of(context).colorScheme.error,
          onPressed: (context) => LogoutService.confirmAndSignOut(
            context,
            portalName: 'Teacher portal',
          ),
        ),
      ],
    );
  }
}

String _text(dynamic value, {required String fallback}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

String _initials(String name, {required String fallback}) {
  final parts = name
      .split(RegExp(r'\s+'))
      .where((part) => part.trim().isNotEmpty)
      .take(2)
      .map((part) => part.trim()[0].toUpperCase())
      .join();
  return parts.isEmpty ? fallback : parts;
}
