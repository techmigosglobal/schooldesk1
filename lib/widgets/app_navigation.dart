import 'package:flutter/material.dart';

import '../core/config/env_config.dart';
import '../core/constants/schooldesk_glossary.dart';
import '../routes/app_routes.dart';
import '../services/backend_api_client.dart';
import '../services/logout_service.dart';
import '../services/notification_service.dart';
import '../theme/design_tokens.dart';
import 'erp_navigation.dart';

class PrincipalDrawer extends StatefulWidget {
  final int selectedIndex;
  final Function(int) onDestinationSelected;

  const PrincipalDrawer({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  @override
  State<PrincipalDrawer> createState() => _PrincipalDrawerState();
}

class _PrincipalDrawerState extends State<PrincipalDrawer> {
  NotificationService? _notifService;
  int _unreadCount = 0;
  String _schoolName = 'School';
  String _schoolSubtitle = 'Manage school details';
  String _schoolLogo = '';
  String _userName = 'Principal';
  String _userSubtitle = 'Principal';

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
      _unreadCount = svc.getUnreadCountForRole('principal');
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
          fallback: _text(
            school['school_type'],
            fallback: 'Manage school details',
          ),
        );
        _schoolLogo = _text(school['logo_url'], fallback: '');
        _userName = profile.name.trim().isEmpty
            ? _text(profile.username, fallback: 'Principal')
            : profile.name.trim();
        _userSubtitle = profile.roleName.trim().isEmpty
            ? 'Principal'
            : profile.roleName.trim();
      });
    } catch (_) {
      // Keep neutral labels if the backend is temporarily unavailable.
    }
  }

  void _onNotifChanged() {
    if (!mounted) return;
    setState(() {
      _unreadCount = _notifService?.getUnreadCountForRole('principal') ?? 0;
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
      role: SchoolDeskRole.principal,
      portalLabel: 'Principal Portal',
      organizationName: _schoolName,
      organizationSubtitle: _schoolSubtitle,
      organizationLogo: _schoolLogo.isEmpty
          ? null
          : Image.network(
              _assetUrl(_schoolLogo),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  const Icon(Icons.account_balance_rounded),
            ),
      userName: _userName,
      userSubtitle: _userSubtitle,
      initials: _initials(_userName, fallback: 'PR'),
      portalIcon: Icons.account_balance_rounded,
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
              route: AppRoutes.principalDashboard,
            ),
            SchoolDeskNavigationItem(
              index: 14,
              icon: Icons.apartment_outlined,
              activeIcon: Icons.apartment_rounded,
              label: SchoolDeskGlossary.schoolProfile,
              route: AppRoutes.principalSchoolProfile,
            ),
            SchoolDeskNavigationItem(
              index: 1,
              icon: Icons.manage_accounts_outlined,
              activeIcon: Icons.manage_accounts_rounded,
              label: SchoolDeskGlossary.accessPermissions,
              route: AppRoutes.principalUserManagement,
            ),
          ],
        ),
        SchoolDeskNavigationSection(
          label: 'Oversight',
          items: [
            SchoolDeskNavigationItem(
              index: 2,
              icon: Icons.school_outlined,
              activeIcon: Icons.school_rounded,
              label: SchoolDeskGlossary.studentOversight,
              route: AppRoutes.studentOversight,
            ),
            SchoolDeskNavigationItem(
              index: 3,
              icon: Icons.task_alt_outlined,
              activeIcon: Icons.task_alt_rounded,
              label: SchoolDeskGlossary.approvalCenter,
              route: AppRoutes.approvalCenter,
            ),
          ],
        ),
        SchoolDeskNavigationSection(
          label: 'Academic Records',
          items: [
            SchoolDeskNavigationItem(
              index: 4,
              icon: Icons.calendar_view_week_outlined,
              activeIcon: Icons.calendar_view_week_rounded,
              label: SchoolDeskGlossary.timetableRecords,
              route: AppRoutes.timetableManagement,
            ),
            SchoolDeskNavigationItem(
              index: 5,
              icon: Icons.menu_book_outlined,
              activeIcon: Icons.menu_book_rounded,
              label: SchoolDeskGlossary.syllabusRecords,
              route: AppRoutes.syllabusMonitoring,
            ),
            SchoolDeskNavigationItem(
              index: 6,
              icon: Icons.quiz_outlined,
              activeIcon: Icons.quiz_rounded,
              label: SchoolDeskGlossary.examRecords,
              route: AppRoutes.examsResults,
            ),
            SchoolDeskNavigationItem(
              index: 12,
              icon: Icons.auto_stories_outlined,
              activeIcon: Icons.auto_stories_rounded,
              label: SchoolDeskGlossary.academicManagement,
              route: AppRoutes.academicManagement,
            ),
          ],
        ),
        SchoolDeskNavigationSection(
          label: 'Finance',
          items: [
            SchoolDeskNavigationItem(
              index: 7,
              icon: Icons.account_balance_wallet_outlined,
              activeIcon: Icons.account_balance_wallet_rounded,
              label: SchoolDeskGlossary.feeMonitoring,
              route: AppRoutes.feeMonitoring,
            ),
          ],
        ),
        SchoolDeskNavigationSection(
          label: 'Communication',
          items: [
            SchoolDeskNavigationItem(
              index: 8,
              icon: Icons.campaign_outlined,
              activeIcon: Icons.campaign_rounded,
              label: SchoolDeskGlossary.communicationCenter,
              route: AppRoutes.communicationCenter,
            ),
            SchoolDeskNavigationItem(
              index: 9,
              icon: Icons.support_agent_outlined,
              activeIcon: Icons.support_agent_rounded,
              label: SchoolDeskGlossary.complaints,
              route: AppRoutes.complaintManagement,
            ),
            SchoolDeskNavigationItem(
              index: 10,
              icon: Icons.event_outlined,
              activeIcon: Icons.event_rounded,
              label: SchoolDeskGlossary.calendar,
              route: AppRoutes.eventsCalendar,
            ),
          ],
        ),
        SchoolDeskNavigationSection(
          label: 'Reports',
          items: [
            SchoolDeskNavigationItem(
              index: 11,
              icon: Icons.bar_chart_outlined,
              activeIcon: Icons.bar_chart_rounded,
              label: SchoolDeskGlossary.reports,
              route: AppRoutes.reportsAnalytics,
            ),
            SchoolDeskNavigationItem(
              index: 13,
              icon: Icons.analytics_outlined,
              activeIcon: Icons.analytics_rounded,
              label: SchoolDeskGlossary.analytics,
              route: AppRoutes.principalAnalytics,
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
          arguments: 'principal',
          badgeCount: _unreadCount,
        ),
        const SchoolDeskNavigationFooterAction(
          icon: Icons.account_circle_outlined,
          label: SchoolDeskGlossary.profile,
          route: AppRoutes.profileScreen,
          arguments: 'principal',
        ),
        const SchoolDeskNavigationFooterAction(
          icon: Icons.settings_outlined,
          label: SchoolDeskGlossary.settings,
          route: AppRoutes.settingsScreen,
          arguments: 'principal',
        ),
        SchoolDeskNavigationFooterAction(
          icon: Icons.logout_rounded,
          label: SchoolDeskGlossary.signOut,
          color: Theme.of(context).colorScheme.error,
          onPressed: (context) => LogoutService.confirmAndSignOut(
            context,
            portalName: 'Principal portal',
          ),
        ),
      ],
    );
  }

  String _assetUrl(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    return '${EnvConfig.apiOrigin}$path';
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
