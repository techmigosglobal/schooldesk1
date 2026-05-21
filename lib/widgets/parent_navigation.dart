import 'package:flutter/material.dart';

import '../core/constants/schooldesk_glossary.dart';
import '../routes/app_routes.dart';
import '../services/backend_api_client.dart';
import '../services/logout_service.dart';
import '../services/notification_service.dart';
import '../services/role_access_service.dart';
import '../theme/design_tokens.dart';
import 'erp_navigation.dart';

class ParentDrawer extends StatefulWidget {
  final int selectedIndex;
  final Function(int) onDestinationSelected;

  const ParentDrawer({
    super.key,
    required this.selectedIndex,
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
        _schoolName = _text(school['name'], fallback: 'School');
        _schoolSubtitle = _text(
          school['affiliation_board'],
          fallback: _text(school['school_type'], fallback: 'Family access'),
        );
        _userId = profile.id;
        _userName = profile.name.trim().isEmpty
            ? _text(profile.username, fallback: 'Parent')
            : profile.name.trim();
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
      initials: _initials(_userName, fallback: 'PA'),
      portalIcon: Icons.family_restroom_rounded,
      selectedIndex: widget.selectedIndex,
      onDestinationSelected: widget.onDestinationSelected,
      sections: [
        const SchoolDeskNavigationSection(
          label: 'Overview',
          items: [
            SchoolDeskNavigationItem(
              index: 0,
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
              index: 1,
              icon: Icons.trending_up_outlined,
              activeIcon: Icons.trending_up_rounded,
              label: 'Academic Progress',
              route: AppRoutes.parentAcademicProgress,
            ),
            SchoolDeskNavigationItem(
              index: 2,
              icon: Icons.how_to_reg_outlined,
              activeIcon: Icons.how_to_reg_rounded,
              label: 'Attendance',
              route: AppRoutes.parentAttendance,
            ),
            SchoolDeskNavigationItem(
              index: 3,
              icon: Icons.assignment_outlined,
              activeIcon: Icons.assignment_rounded,
              label: 'Homework',
              route: AppRoutes.parentHomework,
            ),
            SchoolDeskNavigationItem(
              index: 13,
              icon: Icons.menu_book_outlined,
              activeIcon: Icons.menu_book_rounded,
              label: 'Class Diary',
              route: AppRoutes.parentDiary,
            ),
          ],
        ),
        SchoolDeskNavigationSection(
          label: 'Communication',
          items: [
            SchoolDeskNavigationItem(
              index: 4,
              icon: Icons.campaign_outlined,
              activeIcon: Icons.campaign_rounded,
              label: 'School Notices',
              route: AppRoutes.parentNotices,
              badgeCount: _unreadCount,
            ),
            const SchoolDeskNavigationItem(
              index: 5,
              icon: Icons.chat_outlined,
              activeIcon: Icons.chat_rounded,
              label: 'Teacher Chat / PTM',
              route: AppRoutes.parentTeacherChat,
            ),
            SchoolDeskNavigationItem(
              index: 14,
              icon: Icons.feedback_outlined,
              activeIcon: Icons.feedback_rounded,
              label: 'Homework Feedback',
              route: AppRoutes.homeworkMessaging,
              arguments: {
                'role': 'parent',
                'userId': _userId,
                'userName': _userName,
              },
            ),
          ],
        ),
        const SchoolDeskNavigationSection(
          label: 'Finance & Admin',
          items: [
            SchoolDeskNavigationItem(
              index: 6,
              icon: Icons.account_balance_wallet_outlined,
              activeIcon: Icons.account_balance_wallet_rounded,
              label: SchoolDeskGlossary.fees,
              route: AppRoutes.parentFees,
            ),
            SchoolDeskNavigationItem(
              index: 15,
              icon: Icons.receipt_long_outlined,
              activeIcon: Icons.receipt_long_rounded,
              label: 'Pay & Receipts',
              route: AppRoutes.feePaymentReceipt,
            ),
            SchoolDeskNavigationItem(
              index: 7,
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
              index: 8,
              icon: Icons.calendar_month_outlined,
              activeIcon: Icons.calendar_month_rounded,
              label: SchoolDeskGlossary.calendar,
              route: AppRoutes.parentCalendar,
            ),
            SchoolDeskNavigationItem(
              index: 9,
              icon: Icons.description_outlined,
              activeIcon: Icons.description_rounded,
              label: SchoolDeskGlossary.documents,
              route: AppRoutes.parentDocuments,
            ),
          ],
        ),
        const SchoolDeskNavigationSection(
          label: 'School Info',
          items: [
            SchoolDeskNavigationItem(
              index: 12,
              icon: Icons.auto_stories_outlined,
              activeIcon: Icons.auto_stories_rounded,
              label: 'Academic Info',
              route: AppRoutes.parentAcademicInfo,
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
