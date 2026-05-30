import 'package:flutter/material.dart';

import '../core/constants/schooldesk_glossary.dart';
import '../routes/app_routes.dart';
import '../services/backend_api_client.dart';
import '../services/logout_service.dart';
import '../services/notification_service.dart';
import '../theme/design_tokens.dart';
import 'erp_navigation.dart';

class AdminDrawer extends StatefulWidget {
  final int selectedIndex;
  final Function(int) onDestinationSelected;

  const AdminDrawer({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  @override
  State<AdminDrawer> createState() => _AdminDrawerState();
}

class _AdminDrawerState extends State<AdminDrawer> {
  NotificationService? _notifService;
  int _unreadCount = 0;
  String _schoolName = 'School';
  String _schoolSubtitle = 'Operations';
  String _userName = 'Admin';
  String _userSubtitle = 'Administrator';

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
      _unreadCount = svc.getUnreadCountForRole('admin');
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
      setState(() {
        _schoolName = _text(school['name'], fallback: 'School');
        _schoolSubtitle = _text(
          school['affiliation_board'],
          fallback: _text(school['school_type'], fallback: 'Operations'),
        );
        _userName = profile.name.trim().isEmpty ? 'Admin' : profile.name.trim();
        _userSubtitle = profile.roleName.trim().isEmpty
            ? 'Administrator'
            : profile.roleName.trim();
      });
    } catch (_) {
      // Keep neutral labels if the backend is temporarily unavailable.
    }
  }

  void _onNotifChanged() {
    if (!mounted) return;
    setState(() {
      _unreadCount = _notifService?.getUnreadCountForRole('admin') ?? 0;
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
      role: SchoolDeskRole.admin,
      portalLabel: 'Admin Portal',
      organizationName: _schoolName,
      organizationSubtitle: _schoolSubtitle,
      userName: _userName,
      userSubtitle: _userSubtitle,
      initials: _initials(_userName, fallback: 'AD'),
      portalIcon: Icons.manage_accounts_rounded,
      selectedIndex: widget.selectedIndex,
      onDestinationSelected: widget.onDestinationSelected,
      sections: const [
        SchoolDeskNavigationSection(
          label: 'Overview',
          items: [
            SchoolDeskNavigationItem(
              index: 0,
              icon: Icons.dashboard_outlined,
              activeIcon: Icons.dashboard_rounded,
              label: SchoolDeskGlossary.dashboard,
              route: AppRoutes.adminDashboard,
            ),
            SchoolDeskNavigationItem(
              index: 16,
              icon: Icons.assistant_direction_outlined,
              activeIcon: Icons.assistant_direction_rounded,
              label: 'Guided Assistant',
              route: AppRoutes.guidedAssistant,
            ),
          ],
        ),
        SchoolDeskNavigationSection(
          label: 'Administration',
          items: [
            SchoolDeskNavigationItem(
              index: 1,
              icon: Icons.school_outlined,
              activeIcon: Icons.school_rounded,
              label: SchoolDeskGlossary.students,
              route: AppRoutes.adminStudents,
            ),
            SchoolDeskNavigationItem(
              index: 2,
              icon: Icons.people_outline_rounded,
              activeIcon: Icons.people_rounded,
              label: SchoolDeskGlossary.staff,
              route: AppRoutes.adminTeachers,
            ),
            SchoolDeskNavigationItem(
              index: 3,
              icon: Icons.how_to_reg_outlined,
              activeIcon: Icons.how_to_reg_rounded,
              label: SchoolDeskGlossary.attendance,
              route: AppRoutes.adminAttendance,
            ),
          ],
        ),
        SchoolDeskNavigationSection(
          label: 'Finance',
          items: [
            SchoolDeskNavigationItem(
              index: 4,
              icon: Icons.account_balance_wallet_outlined,
              activeIcon: Icons.account_balance_wallet_rounded,
              label: SchoolDeskGlossary.fees,
              route: AppRoutes.adminFees,
            ),
          ],
        ),
        SchoolDeskNavigationSection(
          label: 'Academics',
          items: [
            SchoolDeskNavigationItem(
              index: 5,
              icon: Icons.calendar_view_week_outlined,
              activeIcon: Icons.calendar_view_week_rounded,
              label: SchoolDeskGlossary.timetable,
              route: AppRoutes.adminTimetable,
            ),
            SchoolDeskNavigationItem(
              index: 6,
              icon: Icons.quiz_outlined,
              activeIcon: Icons.quiz_rounded,
              label: SchoolDeskGlossary.exams,
              route: AppRoutes.adminExams,
            ),
            SchoolDeskNavigationItem(
              index: 15,
              icon: Icons.auto_stories_outlined,
              activeIcon: Icons.auto_stories_rounded,
              label: SchoolDeskGlossary.academicManagement,
              route: AppRoutes.academicManagement,
            ),
          ],
        ),
        SchoolDeskNavigationSection(
          label: 'Communication',
          items: [
            SchoolDeskNavigationItem(
              index: 7,
              icon: Icons.campaign_outlined,
              activeIcon: Icons.campaign_rounded,
              label: SchoolDeskGlossary.communication,
              route: AppRoutes.adminCommunication,
            ),
            SchoolDeskNavigationItem(
              index: 8,
              icon: Icons.support_agent_outlined,
              activeIcon: Icons.support_agent_rounded,
              label: SchoolDeskGlossary.helpdesk,
              route: AppRoutes.adminHelpdesk,
            ),
          ],
        ),
        SchoolDeskNavigationSection(
          label: 'Records',
          items: [
            SchoolDeskNavigationItem(
              index: 9,
              icon: Icons.description_outlined,
              activeIcon: Icons.description_rounded,
              label: SchoolDeskGlossary.documents,
              route: AppRoutes.adminDocuments,
            ),
            SchoolDeskNavigationItem(
              index: 10,
              icon: Icons.manage_accounts_outlined,
              activeIcon: Icons.manage_accounts_rounded,
              label: SchoolDeskGlossary.access,
              route: AppRoutes.adminUserAccess,
            ),
            SchoolDeskNavigationItem(
              index: 11,
              icon: Icons.bar_chart_outlined,
              activeIcon: Icons.bar_chart_rounded,
              label: SchoolDeskGlossary.reports,
              route: AppRoutes.adminReports,
            ),
          ],
        ),
        SchoolDeskNavigationSection(
          label: 'School Info',
          items: [
            SchoolDeskNavigationItem(
              index: 14,
              icon: Icons.info_outline_rounded,
              activeIcon: Icons.info_rounded,
              label: SchoolDeskGlossary.academicInfo,
              route: AppRoutes.adminAcademicInfo,
            ),
            SchoolDeskNavigationItem(
              index: 12,
              icon: Icons.badge_outlined,
              activeIcon: Icons.badge_rounded,
              label: SchoolDeskGlossary.idCards,
              route: AppRoutes.idCardGeneration,
            ),
          ],
        ),
      ],
      footerActions: [
        const SchoolDeskNavigationFooterAction(
          icon: Icons.search_rounded,
          label: SchoolDeskGlossary.globalSearch,
          route: AppRoutes.globalSearch,
        ),
        SchoolDeskNavigationFooterAction(
          icon: Icons.notifications_outlined,
          label: SchoolDeskGlossary.notifications,
          route: AppRoutes.notificationCenter,
          arguments: 'admin',
          badgeCount: _unreadCount,
        ),
        const SchoolDeskNavigationFooterAction(
          icon: Icons.account_circle_outlined,
          label: SchoolDeskGlossary.profile,
          route: AppRoutes.profileScreen,
          arguments: 'admin',
        ),
        const SchoolDeskNavigationFooterAction(
          icon: Icons.settings_outlined,
          label: SchoolDeskGlossary.settings,
          route: AppRoutes.settingsScreen,
          arguments: 'admin',
        ),
        SchoolDeskNavigationFooterAction(
          icon: Icons.logout_rounded,
          label: SchoolDeskGlossary.signOut,
          color: Theme.of(context).colorScheme.error,
          onPressed: (context) => LogoutService.confirmAndSignOut(
            context,
            portalName: 'Admin portal',
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
