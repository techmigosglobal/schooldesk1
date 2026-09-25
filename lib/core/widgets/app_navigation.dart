import 'package:flutter/material.dart';

import 'package:schooldesk1/core/config/env_config.dart';
import 'package:schooldesk1/core/constants/schooldesk_glossary.dart';
import 'package:schooldesk1/core/navigation/role_nav_indices.dart';
import 'package:schooldesk1/routes/app_routes.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/services/logout_service.dart';
import 'package:schooldesk1/core/services/notification_service.dart';
import 'package:schooldesk1/core/theme/design_tokens.dart';
import 'package:schooldesk1/core/utils/text_utils.dart';
import 'package:schooldesk1/core/utils/media_url.dart';
import 'package:schooldesk1/core/widgets/erp_components.dart';
import 'package:schooldesk1/core/widgets/erp_navigation.dart';

import 'package:schooldesk1/core/navigation/schooldesk_navigation.dart';

class PrincipalDrawer extends StatefulWidget {
  final int? selectedIndex;
  final Function(int) onDestinationSelected;

  const PrincipalDrawer({
    super.key,
    this.selectedIndex,
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
  String _userAvatar = '';

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
      _unreadCount = svc.getUnreadCountForRole(_leadershipRole);
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
        _schoolName = safeText(
          school['organization_name'] ?? school['name'],
          fallback: 'School',
        );
        _schoolSubtitle = safeText(
          school['affiliation_board'],
          fallback: safeText(
            school['school_type'],
            fallback: 'Manage school details',
          ),
        );
        _schoolLogo = safeText(school['logo_url'], fallback: '');
        _userName = profile.name.trim().isEmpty
            ? safeText(profile.username, fallback: 'Principal')
            : profile.name.trim();
        _userSubtitle = profile.roleName.trim().isEmpty
            ? 'Principal'
            : profile.roleName.trim();
        _userAvatar = safeText(profile.avatar, fallback: '');
      });
    } on Object catch (_) {
      // Keep neutral labels if the backend is temporarily unavailable.
    }
  }

  void _onNotifChanged() {
    if (!mounted) return;
    setState(() {
      _unreadCount = _notifService?.getUnreadCountForRole(_leadershipRole) ?? 0;
    });
  }

  @override
  void dispose() {
    _notifService?.removeListener(_onNotifChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isCoordinator = _leadershipRole == 'coordinator';
    return SchoolDeskNavigationDrawer(
      role: isCoordinator
          ? SchoolDeskRole.coordinator
          : SchoolDeskRole.principal,
      portalLabel: isCoordinator ? 'Coordinator Portal' : 'Principal Portal',
      organizationName: _schoolName,
      organizationSubtitle: _schoolSubtitle,
      organizationLogo: _schoolLogo.isEmpty
          ? null
          : Image.network(
              resolveOriginalImageUrl(_assetUrl(_schoolLogo)),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  const Icon(Icons.account_balance_rounded),
            ),
      userName: _userName,
      userSubtitle: _userSubtitle,
      initials: safeInitials(_userName, fallback: 'PR'),
      userAvatar: _userAvatar.isEmpty
          ? null
          : Image.network(
              resolveOriginalImageUrl(_assetUrl(_userAvatar)),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const Icon(Icons.person_rounded),
            ),
      portalIcon: Icons.account_balance_rounded,
      hiddenRoutes: isCoordinator ? {AppRoutes.feeMonitoring} : const {},
      selectedIndex: widget.selectedIndex,
      onDestinationSelected: widget.onDestinationSelected,
      sections: const [
        SchoolDeskNavigationSection(
          label: 'Overview',
          items: [
            SchoolDeskNavigationItem(
              index: PrincipalNav.dashboard,
              icon: Icons.dashboard_outlined,
              activeIcon: Icons.dashboard_rounded,
              label: SchoolDeskGlossary.dashboard,
              route: AppRoutes.principalDashboard,
            ),
            SchoolDeskNavigationItem(
              index: PrincipalNav.schoolProfile,
              icon: Icons.apartment_outlined,
              activeIcon: Icons.apartment_rounded,
              label: SchoolDeskGlossary.schoolProfile,
              route: AppRoutes.principalSchoolProfile,
            ),
          ],
        ),
        SchoolDeskNavigationSection(
          label: 'Oversight',
          items: [
            SchoolDeskNavigationItem(
              index: PrincipalNav.staff,
              icon: Icons.people_outline_rounded,
              activeIcon: Icons.people_rounded,
              label: SchoolDeskGlossary.staff,
              route: AppRoutes.staffManagement,
            ),
            SchoolDeskNavigationItem(
              index: PrincipalNav.students,
              icon: Icons.school_outlined,
              activeIcon: Icons.school_rounded,
              label: SchoolDeskGlossary.studentOversight,
              route: AppRoutes.studentOversight,
            ),
            SchoolDeskNavigationItem(
              index: PrincipalNav.admissionInquiries,
              icon: Icons.markunread_outlined,
              activeIcon: Icons.markunread_rounded,
              label: 'Admission Inquiries',
              route: AppRoutes.admissionInquiries,
            ),
            SchoolDeskNavigationItem(
              index: PrincipalNav.guardians,
              icon: Icons.family_restroom_outlined,
              activeIcon: Icons.family_restroom_rounded,
              label: 'Parents',
              route: AppRoutes.guardianDirectory,
            ),
            SchoolDeskNavigationItem(
              index: PrincipalNav.approvals,
              icon: Icons.task_alt_outlined,
              activeIcon: Icons.task_alt_rounded,
              label: SchoolDeskGlossary.approvalCenter,
              route: AppRoutes.approvalCenter,
            ),
            SchoolDeskNavigationItem(
              index: PrincipalNav.attendance,
              icon: Icons.fact_check_outlined,
              activeIcon: Icons.fact_check_rounded,
              label: SchoolDeskGlossary.attendance,
              route: AppRoutes.principalAttendance,
            ),
          ],
        ),
        SchoolDeskNavigationSection(
          label: 'Academic Records',
          items: [
            SchoolDeskNavigationItem(
              index: PrincipalNav.classes,
              icon: Icons.grid_view_outlined,
              activeIcon: Icons.grid_view_rounded,
              label: 'Class Hub',
              route: AppRoutes.principalClasses,
            ),
            SchoolDeskNavigationItem(
              index: PrincipalNav.subjects,
              icon: Icons.menu_book_outlined,
              activeIcon: Icons.menu_book_rounded,
              label: 'Subjects',
              route: AppRoutes.principalSubjects,
            ),
            SchoolDeskNavigationItem(
              index: PrincipalNav.academics,
              icon: Icons.auto_stories_outlined,
              activeIcon: Icons.auto_stories_rounded,
              label: SchoolDeskGlossary.academicManagement,
              route: AppRoutes.academicManagement,
            ),
            SchoolDeskNavigationItem(
              index: PrincipalNav.timetable,
              icon: Icons.calendar_month_outlined,
              activeIcon: Icons.calendar_month_rounded,
              label: 'Timetable',
              route: AppRoutes.principalTimetable,
            ),
            SchoolDeskNavigationItem(
              index: PrincipalNav.lessonPlanner,
              icon: Icons.event_note_outlined,
              activeIcon: Icons.event_note_rounded,
              label: 'Lesson Planners',
              route: AppRoutes.principalLessonPlanner,
            ),
          ],
        ),
        SchoolDeskNavigationSection(
          label: 'Finance',
          items: [
            SchoolDeskNavigationItem(
              index: PrincipalNav.fees,
              icon: Icons.account_balance_wallet_outlined,
              activeIcon: Icons.account_balance_wallet_rounded,
              label: SchoolDeskGlossary.feeMonitoring,
              route: AppRoutes.feeMonitoring,
            ),
          ],
        ),
        SchoolDeskNavigationSection(
          label: 'Messages',
          items: [
            SchoolDeskNavigationItem(
              index: PrincipalNav.messages,
              icon: Icons.forum_outlined,
              activeIcon: Icons.forum_rounded,
              label: 'Messages & Chats',
              route: AppRoutes.principalChatCommunications,
            ),
            SchoolDeskNavigationItem(
              index: PrincipalNav.eventPosts,
              icon: Icons.campaign_outlined,
              activeIcon: Icons.campaign_rounded,
              label: 'School Posts',
              route: AppRoutes.principalEventPosts,
            ),
            SchoolDeskNavigationItem(
              index: PrincipalNav.complaints,
              icon: Icons.support_agent_outlined,
              activeIcon: Icons.support_agent_rounded,
              label: 'Raise an Issue',
              route: AppRoutes.complaintManagement,
            ),
            SchoolDeskNavigationItem(
              index: PrincipalNav.calendar,
              icon: Icons.event_outlined,
              activeIcon: Icons.event_rounded,
              label: 'Academic Calendar',
              route: AppRoutes.eventsCalendar,
            ),
            SchoolDeskNavigationItem(
              index: PrincipalNav.gallery,
              icon: Icons.photo_library_outlined,
              activeIcon: Icons.photo_library_rounded,
              label: 'Gallery',
              route: AppRoutes.schoolGallery,
            ),
          ],
        ),
        SchoolDeskNavigationSection(
          label: 'Records & Reports',
          items: [
            SchoolDeskNavigationItem(
              index: PrincipalNav.documents,
              icon: Icons.description_outlined,
              activeIcon: Icons.description_rounded,
              label: SchoolDeskGlossary.documents,
              route: AppRoutes.principalDocuments,
            ),
            SchoolDeskNavigationItem(
              index: PrincipalNav.reports,
              icon: Icons.bar_chart_outlined,
              activeIcon: Icons.bar_chart_rounded,
              label: SchoolDeskGlossary.reports,
              route: AppRoutes.reportsAnalytics,
            ),
            SchoolDeskNavigationItem(
              index: PrincipalNav.analytics,
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
          arguments: _leadershipRole,
          badgeCount: _unreadCount,
        ),
        SchoolDeskNavigationFooterAction(
          icon: Icons.account_circle_outlined,
          label: SchoolDeskGlossary.profile,
          route: AppRoutes.profileScreen,
          arguments: _leadershipRole,
        ),
        SchoolDeskNavigationFooterAction(
          icon: Icons.settings_outlined,
          label: SchoolDeskGlossary.settings,
          route: AppRoutes.settingsScreen,
          arguments: _leadershipRole,
        ),
        SchoolDeskNavigationFooterAction(
          icon: Icons.logout_rounded,
          label: SchoolDeskGlossary.signOut,
          color: Theme.of(context).colorScheme.error,
          onPressed: (context) => LogoutService.confirmAndSignOut(
            context,
            portalName: isCoordinator
                ? 'Coordinator portal'
                : 'Principal portal',
          ),
        ),
      ],
    );
  }

  String get _leadershipRole {
    final role = BackendApiClient.instance.currentRoleName
        ?.trim()
        .toLowerCase();
    return role == 'coordinator' ? 'coordinator' : 'principal';
  }

  String _assetUrl(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    return '${EnvConfig.apiOrigin}$path';
  }
}

class PrincipalShellBottomBar extends StatefulWidget {
  const PrincipalShellBottomBar({super.key});

  @override
  State<PrincipalShellBottomBar> createState() =>
      _PrincipalShellBottomBarState();
}

class _PrincipalShellBottomBarState extends State<PrincipalShellBottomBar> {
  String _avatarPath = '';

  @override
  void initState() {
    super.initState();
    _loadAvatar();
  }

  Future<void> _loadAvatar() async {
    final cached = BackendApiClient.instance.cachedProfile;
    if (cached != null) {
      if (mounted) {
        setState(() {
          _avatarPath = cached.avatar;
        });
      }
      return;
    }
    try {
      final profile = await BackendApiClient.instance.getProfile();
      if (mounted) {
        setState(() {
          _avatarPath = profile.avatar;
        });
      }
    } on Object catch (_) {}
  }

  Widget? _buildAvatarIcon(bool selected) {
    final avatar = _avatarPath.trim();
    if (avatar.isEmpty) return null;
    final theme = Theme.of(context);
    final isSelected = selected;
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected ? theme.colorScheme.primary : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: ClipOval(
        child: avatar.startsWith('assets/')
            ? Image.asset(avatar, fit: BoxFit.cover)
            : Image.network(
                resolveOriginalImageUrl(
                  avatar.startsWith('http')
                      ? avatar
                      : '${EnvConfig.apiOrigin}$avatar',
                ),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Icon(
                  isSelected
                      ? Icons.account_circle_rounded
                      : Icons.account_circle_outlined,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.schoolDesk.textMuted,
                  size: 24,
                ),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cached = BackendApiClient.instance.cachedProfile;
    if (cached != null && cached.avatar != _avatarPath) {
      _avatarPath = cached.avatar;
    }

    final currentRoute = ModalRoute.of(context)?.settings.name;
    final role =
        BackendApiClient.instance.currentRoleName?.trim().toLowerCase() ==
            'coordinator'
        ? 'coordinator'
        : 'principal';
    final destinations = [
      _PrincipalShellDestination(
        label: 'Home',
        icon: Icons.home_outlined,
        activeIcon: Icons.home_rounded,
        route: role == 'coordinator'
            ? AppRoutes.coordinatorDashboard
            : AppRoutes.principalDashboard,
      ),
      _PrincipalShellDestination(
        label: SchoolDeskGlossary.search,
        icon: Icons.search_rounded,
        activeIcon: Icons.manage_search_rounded,
        route: AppRoutes.globalSearch,
        arguments: role,
      ),
      _PrincipalShellDestination(
        label: SchoolDeskGlossary.notifications,
        icon: Icons.notifications_none_rounded,
        activeIcon: Icons.notifications_rounded,
        route: AppRoutes.notificationCenter,
        arguments: role,
      ),
      _PrincipalShellDestination(
        label: SchoolDeskGlossary.profile,
        icon: Icons.account_circle_outlined,
        activeIcon: Icons.account_circle_rounded,
        route: AppRoutes.profileScreen,
        arguments: role,
      ),
    ];

    return SchoolDeskBottomNavigationBar(
      items: [
        for (final destination in destinations) ...[
          (() {
            final isProfile =
                destination.label == SchoolDeskGlossary.profile ||
                destination.label.toLowerCase() == 'profile';
            return SchoolDeskBottomNavItem(
              label: destination.label,
              icon: destination.icon,
              activeIcon: destination.activeIcon,
              selected: currentRoute == destination.route,
              customIcon: isProfile ? _buildAvatarIcon(false) : null,
              customActiveIcon: isProfile ? _buildAvatarIcon(true) : null,
              onTap: () => _navigate(context, destination),
            );
          })(),
        ],
      ],
    );
  }

  void _navigate(BuildContext context, _PrincipalShellDestination destination) {
    final navigator = Navigator.of(context);
    final currentRoute = ModalRoute.of(context)?.settings.name;
    if (currentRoute == destination.route) return;
    if (destination.route == AppRoutes.principalDashboard ||
        destination.route == AppRoutes.coordinatorDashboard) {
      SchoolDeskNavigation.goFromNavigator(
        navigator,
        destination.route,
        legacyPredicate: (_) => false,
      );
      return;
    }
    SchoolDeskNavigation.pushFromNavigator(
      navigator,
      destination.route,
      arguments: destination.arguments,
    );
  }
}

class _PrincipalShellDestination {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final String route;
  final Object? arguments;

  const _PrincipalShellDestination({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.route,
    this.arguments,
  });
}

// ─── SuperAdmin Navigation ──────────────────────────────────────────────────

class SuperAdminDrawer extends StatefulWidget {
  final int? selectedIndex;
  final Function(int) onDestinationSelected;

  const SuperAdminDrawer({
    super.key,
    this.selectedIndex,
    required this.onDestinationSelected,
  });

  @override
  State<SuperAdminDrawer> createState() => _SuperAdminDrawerState();
}

class _SuperAdminDrawerState extends State<SuperAdminDrawer> {
  NotificationService? _notifService;
  int _unreadCount = 0;
  String _schoolName = 'School';
  String _schoolSubtitle = 'Manage school details';
  String _schoolLogo = '';
  String _userName = 'Super Admin';
  String _userSubtitle = 'Super Administrator';
  String _userAvatar = '';

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
      _unreadCount = svc.getUnreadCountForRole('super_admin');
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
        _schoolName = safeText(
          school['organization_name'] ?? school['name'],
          fallback: 'School',
        );
        _schoolSubtitle = safeText(
          school['affiliation_board'],
          fallback: safeText(
            school['school_type'],
            fallback: 'Manage school details',
          ),
        );
        _schoolLogo = safeText(school['logo_url'], fallback: '');
        _userName = profile.name.trim().isEmpty
            ? safeText(profile.username, fallback: 'Super Admin')
            : profile.name.trim();
        _userSubtitle = profile.roleName.trim().isEmpty
            ? 'Super Administrator'
            : profile.roleName.trim();
        _userAvatar = safeText(profile.avatar, fallback: '');
      });
    } on Object catch (_) {
      // Keep neutral labels if the backend is temporarily unavailable.
    }
  }

  void _onNotifChanged() {
    if (!mounted) return;
    setState(() {
      _unreadCount = _notifService?.getUnreadCountForRole('super_admin') ?? 0;
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
      portalLabel: 'Super Admin Portal',
      organizationName: _schoolName,
      organizationSubtitle: _schoolSubtitle,
      organizationLogo: _schoolLogo.isEmpty
          ? null
          : Image.network(
              resolveOriginalImageUrl(_assetUrl(_schoolLogo)),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const Icon(Icons.security_rounded),
            ),
      userName: _userName,
      userSubtitle: _userSubtitle,
      initials: safeInitials(_userName, fallback: 'SA'),
      userAvatar: _userAvatar.isEmpty
          ? null
          : Image.network(
              resolveOriginalImageUrl(_assetUrl(_userAvatar)),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const Icon(Icons.person_rounded),
            ),
      portalIcon: Icons.security_rounded,
      selectedIndex: widget.selectedIndex,
      onDestinationSelected: widget.onDestinationSelected,
      sections: const [
        SchoolDeskNavigationSection(
          label: 'Overview',
          items: [
            SchoolDeskNavigationItem(
              index: SuperAdminNav.dashboard,
              icon: Icons.dashboard_outlined,
              activeIcon: Icons.dashboard_rounded,
              label: 'Dashboard',
              route: AppRoutes.superAdminDashboard,
            ),
          ],
        ),
        SchoolDeskNavigationSection(
          label: 'System Administration',
          items: [
            SchoolDeskNavigationItem(
              index: SuperAdminNav.auditLogs,
              icon: Icons.history_rounded,
              activeIcon: Icons.history_rounded,
              label: 'Audit Logs',
              route: AppRoutes.superAdminAuditLogs,
            ),
            SchoolDeskNavigationItem(
              index: SuperAdminNav.systemMonitor,
              icon: Icons.monitor_heart_outlined,
              activeIcon: Icons.monitor_heart_rounded,
              label: 'System Monitor',
              route: AppRoutes.superAdminSystemMonitor,
            ),
            SchoolDeskNavigationItem(
              index: SuperAdminNav.complaints,
              icon: Icons.support_agent_outlined,
              activeIcon: Icons.support_agent_rounded,
              label: 'Issue Management',
              route: AppRoutes.superAdminIssues,
            ),
          ],
        ),
        SchoolDeskNavigationSection(
          label: 'School Management',
          items: [
            SchoolDeskNavigationItem(
              index: SuperAdminNav.schoolProfile,
              icon: Icons.apartment_outlined,
              activeIcon: Icons.apartment_rounded,
              label: SchoolDeskGlossary.schoolProfile,
              route: AppRoutes.principalSchoolProfile,
            ),
            SchoolDeskNavigationItem(
              index: SuperAdminNav.access,
              icon: Icons.manage_accounts_outlined,
              activeIcon: Icons.manage_accounts_rounded,
              label: SchoolDeskGlossary.accessPermissions,
              route: AppRoutes.superAdminAccess,
            ),
          ],
        ),
        SchoolDeskNavigationSection(
          label: 'Support',
          items: [
            SchoolDeskNavigationItem(
              index: SuperAdminNav.gallery,
              icon: Icons.help_outline_rounded,
              activeIcon: Icons.help_rounded,
              label: 'Help & Documentation',
              route: AppRoutes.help,
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
          arguments: 'super_admin',
          badgeCount: _unreadCount,
        ),
        const SchoolDeskNavigationFooterAction(
          icon: Icons.account_circle_outlined,
          label: SchoolDeskGlossary.profile,
          route: AppRoutes.profileScreen,
          arguments: 'super_admin',
        ),
        const SchoolDeskNavigationFooterAction(
          icon: Icons.settings_outlined,
          label: SchoolDeskGlossary.settings,
          route: AppRoutes.settingsScreen,
          arguments: 'super_admin',
        ),
        SchoolDeskNavigationFooterAction(
          icon: Icons.logout_rounded,
          label: SchoolDeskGlossary.signOut,
          color: Theme.of(context).colorScheme.error,
          onPressed: (context) => LogoutService.confirmAndSignOut(
            context,
            portalName: 'Super Admin portal',
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

class SuperAdminShellBottomBar extends StatefulWidget {
  const SuperAdminShellBottomBar({super.key});

  @override
  State<SuperAdminShellBottomBar> createState() =>
      _SuperAdminShellBottomBarState();
}

class _SuperAdminShellBottomBarState extends State<SuperAdminShellBottomBar> {
  String _avatarPath = '';

  @override
  void initState() {
    super.initState();
    _loadAvatar();
  }

  Future<void> _loadAvatar() async {
    final cached = BackendApiClient.instance.cachedProfile;
    if (cached != null) {
      if (mounted) {
        setState(() {
          _avatarPath = cached.avatar;
        });
      }
      return;
    }
    try {
      final profile = await BackendApiClient.instance.getProfile();
      if (mounted) {
        setState(() {
          _avatarPath = profile.avatar;
        });
      }
    } on Object catch (_) {}
  }

  Widget? _buildAvatarIcon(bool selected) {
    final avatar = _avatarPath.trim();
    if (avatar.isEmpty) return null;
    final theme = Theme.of(context);
    final isSelected = selected;
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected ? theme.colorScheme.primary : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: ClipOval(
        child: avatar.startsWith('assets/')
            ? Image.asset(avatar, fit: BoxFit.cover)
            : Image.network(
                resolveOriginalImageUrl(
                  avatar.startsWith('http')
                      ? avatar
                      : '${EnvConfig.apiOrigin}$avatar',
                ),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Icon(
                  isSelected
                      ? Icons.account_circle_rounded
                      : Icons.account_circle_outlined,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.schoolDesk.textMuted,
                  size: 24,
                ),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cached = BackendApiClient.instance.cachedProfile;
    if (cached != null && cached.avatar != _avatarPath) {
      _avatarPath = cached.avatar;
    }

    final currentRoute = ModalRoute.of(context)?.settings.name;
    final destinations = const [
      _SuperAdminShellDestination(
        label: 'Home',
        icon: Icons.home_outlined,
        activeIcon: Icons.home_rounded,
        route: AppRoutes.superAdminDashboard,
      ),
      _SuperAdminShellDestination(
        label: SchoolDeskGlossary.search,
        icon: Icons.search_rounded,
        activeIcon: Icons.manage_search_rounded,
        route: AppRoutes.globalSearch,
        arguments: 'super_admin',
      ),
      _SuperAdminShellDestination(
        label: SchoolDeskGlossary.notifications,
        icon: Icons.notifications_none_rounded,
        activeIcon: Icons.notifications_rounded,
        route: AppRoutes.notificationCenter,
        arguments: 'super_admin',
      ),
      _SuperAdminShellDestination(
        label: SchoolDeskGlossary.profile,
        icon: Icons.account_circle_outlined,
        activeIcon: Icons.account_circle_rounded,
        route: AppRoutes.profileScreen,
        arguments: 'super_admin',
      ),
    ];

    return SchoolDeskBottomNavigationBar(
      items: [
        for (final destination in destinations) ...[
          (() {
            final isProfile =
                destination.label == SchoolDeskGlossary.profile ||
                destination.label.toLowerCase() == 'profile';
            return SchoolDeskBottomNavItem(
              label: destination.label,
              icon: destination.icon,
              activeIcon: destination.activeIcon,
              selected: currentRoute == destination.route,
              customIcon: isProfile ? _buildAvatarIcon(false) : null,
              customActiveIcon: isProfile ? _buildAvatarIcon(true) : null,
              onTap: () => _navigate(context, destination),
            );
          })(),
        ],
      ],
    );
  }

  void _navigate(
    BuildContext context,
    _SuperAdminShellDestination destination,
  ) {
    final navigator = Navigator.of(context);
    final currentRoute = ModalRoute.of(context)?.settings.name;
    if (currentRoute == destination.route) return;
    if (destination.route == AppRoutes.superAdminDashboard) {
      SchoolDeskNavigation.goFromNavigator(
        navigator,
        destination.route,
        legacyPredicate: (_) => false,
      );
      return;
    }
    SchoolDeskNavigation.pushFromNavigator(
      navigator,
      destination.route,
      arguments: destination.arguments,
    );
  }
}

class _SuperAdminShellDestination {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final String route;
  final Object? arguments;

  const _SuperAdminShellDestination({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.route,
    this.arguments,
  });
}
