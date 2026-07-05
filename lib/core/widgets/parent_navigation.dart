import 'package:flutter/material.dart';

import 'package:schooldesk1/core/constants/schooldesk_glossary.dart';
import 'package:schooldesk1/core/navigation/role_nav_indices.dart';
import 'package:schooldesk1/routes/app_routes.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/services/logout_service.dart';
import 'package:schooldesk1/core/services/notification_service.dart';
import 'package:schooldesk1/core/services/role_access_service.dart';
import 'package:schooldesk1/core/theme/design_tokens.dart';
import 'package:schooldesk1/core/utils/text_utils.dart';
import 'package:schooldesk1/core/widgets/erp_navigation.dart';

class ParentDrawer extends StatefulWidget {
  final int? selectedIndex;
  final Function(int) onDestinationSelected;

  const ParentDrawer({
    super.key,
    this.selectedIndex,
    required this.onDestinationSelected,
  });

  @override
  State<ParentDrawer> createState() => _ParentDrawerState();
}

class _ParentDrawerState extends State<ParentDrawer> {
  NotificationService? _notifService;
  int _unreadCount = 0;
  String _schoolName = 'School';
  String _schoolSubtitle = 'Family access';
  String _userId = '';
  String _userName = 'Parent';
  String _userSubtitle = 'Parent Portal';

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _loadIdentity();
  }

  Future<void> _loadNotifications() async {
    final svc = await NotificationService.getInstance();
    if (!mounted) return;
    setState(() {
      _notifService = svc;
      _unreadCount = svc.getUnreadCountForRole('parent');
    });
    svc.addListener(_onNotifChanged);
  }

  Future<void> _loadIdentity() async {
    final api = BackendApiClient.instance;
    try {
      final results = await Future.wait([
        api.getCurrentSchool(),
        api.getProfile(),
      ]);
      if (!mounted) return;
      final school = results[0] as Map<String, dynamic>;
      final profile = results[1] as UserResponse;
      final childNames = RoleAccessService.parentChildNames;
      setState(() {
        _schoolName = safeText(school['name'], fallback: 'School');
        _schoolSubtitle = safeText(
          school['affiliation_board'],
          fallback: safeText(school['school_type'], fallback: 'Family access'),
        );
        _userId = profile.id;
        _userName = safeText(
          profile.name,
          fallback: safeText(profile.username, fallback: 'Parent'),
        );
        _userSubtitle = childNames.isEmpty
            ? 'Parent Portal'
            : 'Parent - ${childNames.join(', ')}';
      });
    } catch (_) {
      // Keep neutral labels if the backend is temporarily unavailable.
    }
  }

  void _onNotifChanged() {
    if (!mounted) return;
    setState(() {
      _unreadCount = _notifService?.getUnreadCountForRole('parent') ?? 0;
    });
  }

  @override
  void dispose() {
    _notifService?.removeListener(_onNotifChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SchoolDeskNavigationDrawer(
      role: SchoolDeskRole.parent,
      portalLabel: 'Parent Portal',
      organizationName: _schoolName,
      organizationSubtitle: _schoolSubtitle,
      userName: _userName,
      userSubtitle: _userSubtitle,
      initials: safeInitials(_userName, fallback: 'PA'),
      portalIcon: Icons.family_restroom_rounded,
      selectedIndex: widget.selectedIndex,
      onDestinationSelected: widget.onDestinationSelected,
      sections: [
        const SchoolDeskNavigationSection(
          label: 'Overview',
          items: [
            SchoolDeskNavigationItem(
              index: ParentNav.dashboard,
              icon: Icons.dashboard_outlined,
              activeIcon: Icons.dashboard_rounded,
              label: 'Dashboard',
              route: AppRoutes.parentDashboard,
            ),
          ],
        ),
        const SchoolDeskNavigationSection(
          label: 'Child Academics',
          items: [
            SchoolDeskNavigationItem(
              index: ParentNav.attendance,
              icon: Icons.how_to_reg_outlined,
              activeIcon: Icons.how_to_reg_rounded,
              label: 'Attendance',
              route: AppRoutes.parentAttendance,
            ),
            SchoolDeskNavigationItem(
              index: ParentNav.homework,
              icon: Icons.assignment_outlined,
              activeIcon: Icons.assignment_rounded,
              label: 'Homework',
              route: AppRoutes.parentHomework,
            ),

            SchoolDeskNavigationItem(
              index: ParentNav.timetable,
              icon: Icons.calendar_view_week_outlined,
              activeIcon: Icons.calendar_view_week_rounded,
              label: 'Timetable',
              route: AppRoutes.parentTimetable,
            ),
            SchoolDeskNavigationItem(
              index: ParentNav.lessonPlanner,
              icon: Icons.auto_stories_outlined,
              activeIcon: Icons.auto_stories_rounded,
              label: 'Lesson Planner',
              route: AppRoutes.parentLessonPlanner,
            ),
            SchoolDeskNavigationItem(
              index: ParentNav.health,
              icon: Icons.medical_information_outlined,
              activeIcon: Icons.medical_information_rounded,
              label: 'Health Reminders',
              route: AppRoutes.parentHealth,
            ),
          ],
        ),
        SchoolDeskNavigationSection(
          label: 'Communication',
          items: [
            const SchoolDeskNavigationItem(
              index: ParentNav.chat,
              icon: Icons.chat_outlined,
              activeIcon: Icons.chat_rounded,
              label: 'Messages',
              route: AppRoutes.parentTeacherChat,
            ),
            const SchoolDeskNavigationItem(
              index: ParentNav.ptm,
              icon: Icons.event_available_outlined,
              activeIcon: Icons.event_available_rounded,
              label: 'PTM Slots',
              route: AppRoutes.parentPTMBooking,
            ),
          ],
        ),
        const SchoolDeskNavigationSection(
          label: 'Finance & Admin',
          items: [
            SchoolDeskNavigationItem(
              index: ParentNav.fees,
              icon: Icons.account_balance_wallet_outlined,
              activeIcon: Icons.account_balance_wallet_rounded,
              label: SchoolDeskGlossary.fees,
              route: AppRoutes.parentFees,
            ),
            SchoolDeskNavigationItem(
              index: ParentNav.leave,
              icon: Icons.event_busy_outlined,
              activeIcon: Icons.event_busy_rounded,
              label: 'Leave Requests',
              route: AppRoutes.parentLeave,
            ),
          ],
        ),
        const SchoolDeskNavigationSection(
          label: 'School',
          items: [
            SchoolDeskNavigationItem(
              index: ParentNav.calendar,
              icon: Icons.calendar_month_outlined,
              activeIcon: Icons.calendar_month_rounded,
              label: 'Academic Calendar',
              route: AppRoutes.parentCalendar,
            ),
            SchoolDeskNavigationItem(
              index: ParentNav.documents,
              icon: Icons.description_outlined,
              activeIcon: Icons.description_rounded,
              label: SchoolDeskGlossary.documents,
              route: AppRoutes.parentDocuments,
            ),
            SchoolDeskNavigationItem(
              index: ParentNav.gallery,
              icon: Icons.photo_library_outlined,
              activeIcon: Icons.photo_library_rounded,
              label: 'Gallery',
              route: AppRoutes.schoolGallery,
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
          arguments: 'parent',
          badgeCount: _unreadCount,
        ),
        const SchoolDeskNavigationFooterAction(
          icon: Icons.account_circle_outlined,
          label: 'Profile',
          route: AppRoutes.profileScreen,
          arguments: 'parent',
        ),
        const SchoolDeskNavigationFooterAction(
          icon: Icons.settings_outlined,
          label: 'Settings',
          route: AppRoutes.settingsScreen,
          arguments: 'parent',
        ),
        SchoolDeskNavigationFooterAction(
          icon: Icons.logout_rounded,
          label: 'Sign Out',
          color: Theme.of(context).colorScheme.error,
          onPressed: (context) => LogoutService.confirmAndSignOut(
            context,
            portalName: 'Parent portal',
          ),
        ),
      ],
    );
  }
}
