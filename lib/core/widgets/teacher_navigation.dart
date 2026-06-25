import 'package:flutter/material.dart';

import 'package:schooldesk1/core/navigation/role_nav_indices.dart';
import 'package:schooldesk1/routes/app_routes.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/services/logout_service.dart';
import 'package:schooldesk1/core/services/notification_service.dart';
import 'package:schooldesk1/core/services/role_access_service.dart';
import 'package:schooldesk1/core/theme/design_tokens.dart';
import 'package:schooldesk1/core/utils/text_utils.dart';
import 'package:schooldesk1/core/widgets/erp_navigation.dart';

class TeacherDrawer extends StatefulWidget {
  final int? selectedIndex;
  final Function(int) onDestinationSelected;

  const TeacherDrawer({
    super.key,
    this.selectedIndex,
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
        _schoolName = safeText(school['name'], fallback: 'School');
        _schoolSubtitle = safeText(
          school['affiliation_board'],
          fallback: safeText(
            school['school_type'],
            fallback: 'Teacher workspace',
          ),
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
      initials: safeInitials(teacherName, fallback: 'TE'),
      portalIcon: Icons.cast_for_education_rounded,
      selectedIndex: widget.selectedIndex,
      onDestinationSelected: widget.onDestinationSelected,
      sections: [
        const SchoolDeskNavigationSection(
          label: 'Today',
          items: [
            SchoolDeskNavigationItem(
              index: TeacherNav.dashboard,
              icon: Icons.dashboard_outlined,
              activeIcon: Icons.dashboard_rounded,
              label: 'Dashboard',
              route: AppRoutes.teacherDashboard,
            ),
            SchoolDeskNavigationItem(
              index: TeacherNav.classes,
              icon: Icons.class_outlined,
              activeIcon: Icons.class_rounded,
              label: 'My Classes',
              route: AppRoutes.teacherClasses,
            ),
            SchoolDeskNavigationItem(
              index: TeacherNav.timetable,
              icon: Icons.calendar_month_outlined,
              activeIcon: Icons.calendar_month_rounded,
              label: 'Timetable',
              route: AppRoutes.teacherTimetable,
            ),
            SchoolDeskNavigationItem(
              index: TeacherNav.calendar,
              icon: Icons.event_note_outlined,
              activeIcon: Icons.event_note_rounded,
              label: 'School Calendar',
              route: AppRoutes.teacherCalendar,
            ),
            SchoolDeskNavigationItem(
              index: TeacherNav.myAttendance,
              icon: Icons.qr_code_scanner_outlined,
              activeIcon: Icons.qr_code_scanner_rounded,
              label: 'My Staff Attendance',
              route: AppRoutes.teacherMyAttendance,
            ),
          ],
        ),
        SchoolDeskNavigationSection(
          label: 'Academic Work',
          items: [
            const SchoolDeskNavigationItem(
              index: TeacherNav.attendance,
              icon: Icons.how_to_reg_outlined,
              activeIcon: Icons.how_to_reg_rounded,
              label: 'Attendance',
              route: AppRoutes.teacherAttendance,
            ),
            const SchoolDeskNavigationItem(
              index: TeacherNav.attendanceHistory,
              icon: Icons.fact_check_outlined,
              activeIcon: Icons.fact_check_rounded,
              label: 'Attendance History',
              route: AppRoutes.teacherAttendanceHistory,
            ),
            SchoolDeskNavigationItem(
              index: TeacherNav.diary,
              icon: Icons.menu_book_outlined,
              activeIcon: Icons.menu_book_rounded,
              label: 'Diary',
              route: AppRoutes.teacherDiary,
            ),
            const SchoolDeskNavigationItem(
              index: TeacherNav.eventPosts,
              icon: Icons.post_add_outlined,
              activeIcon: Icons.post_add_rounded,
              label: 'Event Posts',
              route: AppRoutes.teacherEventPosts,
            ),
            const SchoolDeskNavigationItem(
              index: TeacherNav.lessonPlanner,
              icon: Icons.auto_stories_outlined,
              activeIcon: Icons.auto_stories_rounded,
              label: 'Lesson Planner',
              route: AppRoutes.teacherLessonPlanner,
            ),
            const SchoolDeskNavigationItem(
              index: TeacherNav.studentNotes,
              icon: Icons.sticky_note_2_outlined,
              activeIcon: Icons.sticky_note_2_rounded,
              label: 'Student Notes',
              route: AppRoutes.teacherStudentNotes,
            ),
            const SchoolDeskNavigationItem(
              index: TeacherNav.gallery,
              icon: Icons.photo_library_outlined,
              activeIcon: Icons.photo_library_rounded,
              label: 'Gallery',
              route: AppRoutes.schoolGallery,
            ),
          ],
        ),
        SchoolDeskNavigationSection(
          label: 'Communication',
          items: [
            SchoolDeskNavigationItem(
              index: TeacherNav.communication,
              icon: Icons.chat_outlined,
              activeIcon: Icons.chat_rounded,
              label: 'Parent Messages',
              route: AppRoutes.teacherCommunication,
              badgeCount: RoleAccessService.teacherUnreadMessages,
            ),
            const SchoolDeskNavigationItem(
              index: TeacherNav.ptm,
              icon: Icons.event_available_outlined,
              activeIcon: Icons.event_available_rounded,
              label: 'PTM Slots',
              route: AppRoutes.teacherParentInteraction,
            ),
            SchoolDeskNavigationItem(
              index: TeacherNav.documents,
              icon: Icons.description_outlined,
              activeIcon: Icons.description_rounded,
              label: 'Documents',
              route: AppRoutes.teacherDocuments,
            ),
          ],
        ),
        const SchoolDeskNavigationSection(
          label: 'Administration',
          items: [
            SchoolDeskNavigationItem(
              index: TeacherNav.leave,
              icon: Icons.event_busy_outlined,
              activeIcon: Icons.event_busy_rounded,
              label: 'Leave Requests',
              route: AppRoutes.teacherLeave,
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
