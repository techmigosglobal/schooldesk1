import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

import 'package:schooldesk1/core/constants/app_constants.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/routes/schooldesk_screen_registry.dart';
import 'package:schooldesk1/routes/route_access_guard.dart';
import 'package:schooldesk1/core/theme/design_tokens.dart';
import 'package:schooldesk1/core/desktop/desktop_platform.dart';
import 'package:schooldesk1/core/widgets/app_navigation.dart';
import 'package:schooldesk1/core/widgets/teacher_navigation.dart';
import 'package:schooldesk1/core/widgets/parent_navigation.dart';
import 'package:go_router/go_router.dart';
import 'package:schooldesk1/core/navigation/role_nav_indices.dart';
import 'package:schooldesk1/routes/app_routes.dart';
import 'package:schooldesk1/routes/feature_manifest_registry.dart';
import 'package:schooldesk1/core/widgets/erp_components.dart';

import 'package:schooldesk1/core/navigation/schooldesk_navigation.dart';

class SchoolDeskRouteFrame extends StatefulWidget {
  final SchoolDeskScreenMetadata metadata;
  final Widget child;

  const SchoolDeskRouteFrame({
    super.key,
    required this.metadata,
    required this.child,
  });

  @override
  State<SchoolDeskRouteFrame> createState() => _SchoolDeskRouteFrameState();
}

class _SchoolDeskRouteFrameState extends State<SchoolDeskRouteFrame> {
  DateTime? _lastBackPressedAt;

  bool get _isPortalHomeRoute {
    switch (widget.metadata.route) {
      case '/principal-dashboard-screen':
      case '/coordinator-dashboard-screen':
      case '/super-admin-dashboard-screen':
      case '/teacher-dashboard-screen':
      case '/parent-dashboard-screen':
      case '/kiosk-qr-attendance-screen':
        return true;
      default:
        return false;
    }
  }

  bool get _canExitOnBack {
    if (widget.metadata.isPublic) return true;
    if (_isPortalHomeRoute) return false;
    return Navigator.of(context).canPop() ||
        (GoRouter.maybeOf(context)?.canPop() ?? false);
  }

  void _handleBackWithoutPop() {
    if (widget.metadata.isPublic) return;
    if (!_isPortalHomeRoute) {
      _returnToPortalHome();
      return;
    }

    final now = DateTime.now();
    final last = _lastBackPressedAt;
    if (last != null && now.difference(last) <= const Duration(seconds: 2)) {
      SystemNavigator.pop();
      return;
    }

    _lastBackPressedAt = now;
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Press back again to exit ${AppConstants.appName}'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
  }

  void _returnToPortalHome() {
    final target = _homeRouteForCurrentContext();
    if (target == null || target == widget.metadata.route) return;

    final router = GoRouter.maybeOf(context);
    if (router != null) {
      if (router.canPop()) {
        router.pop();
      } else {
        router.go(target);
      }
      return;
    }

    SchoolDeskNavigation.goFromNavigator(
      Navigator.of(context),
      target,
      legacyPredicate: (route) => false,
    );
  }

  String? _homeRouteForCurrentContext() {
    // A role may open leadership-owned screens whose metadata belongs to a
    // different portal. The active session role must win over the screen's
    // owning portal when choosing the back destination.
    final activeRole = BackendApiClient.instance.currentRoleName
        ?.trim()
        .toLowerCase();
    final roleHome = RouteAccessGuard.dashboardForRole(activeRole);
    if (roleHome != null) {
      return roleHome;
    }

    switch (widget.metadata.portal) {
      case 'principal':
        return '/principal-dashboard-screen';
      case 'coordinator':
        return '/coordinator-dashboard-screen';
      case 'super_admin':
        return '/super-admin-dashboard-screen';
      case 'teacher':
        return '/teacher-dashboard-screen';
      case 'parent':
        return '/parent-dashboard-screen';
      case 'kiosk':
        return '/kiosk-qr-attendance-screen';
      case 'shared':
        return _homeRouteForRole(BackendApiClient.instance.currentRoleName);
      default:
        return null;
    }
  }

  String? _homeRouteForRole(String? role) {
    switch ((role ?? '').trim().toLowerCase()) {
      case 'principal':
      case 'admin':
        return '/principal-dashboard-screen';
      case 'coordinator':
        return '/coordinator-dashboard-screen';
      case 'super_admin':
        return '/super-admin-dashboard-screen';
      case 'teacher':
        return '/teacher-dashboard-screen';
      case 'parent':
        return '/parent-dashboard-screen';
      case 'kiosk':
        return '/kiosk-qr-attendance-screen';
      default:
        return null;
    }
  }

  int? _getSelectedIndexForRoute(String route, String portal) {
    if (portal == 'principal') {
      switch (route) {
        case AppRoutes.principalDashboard:
          return PrincipalNav.dashboard;
        case AppRoutes.principalSchoolProfile:
          return PrincipalNav.schoolProfile;
        case AppRoutes.principalUserManagement:
          return PrincipalNav.access;
        case AppRoutes.staffManagement:
          return PrincipalNav.staff;
        case AppRoutes.studentOversight:
          return PrincipalNav.students;
        case AppRoutes.guardianDirectory:
          return PrincipalNav.guardians;
        case AppRoutes.approvalCenter:
          return PrincipalNav.approvals;
        case AppRoutes.principalAttendance:
          return PrincipalNav.attendance;
        case AppRoutes.principalClasses:
          return PrincipalNav.classes;
        case AppRoutes.principalSubjects:
          return PrincipalNav.subjects;
        case AppRoutes.principalAcademicInfo:
          return PrincipalNav.academics;
        case AppRoutes.academicManagement:
          return PrincipalNav.academics;
        case AppRoutes.principalTimetable:
          return PrincipalNav.timetable;
        case AppRoutes.principalLessonPlanner:
          return PrincipalNav.lessonPlanner;
        case AppRoutes.feeMonitoring:
          return PrincipalNav.fees;
        case AppRoutes.principalChatCommunications:
          return PrincipalNav.messages;
        case AppRoutes.principalEventApprovals:
        case AppRoutes.principalEventPosts:
          return PrincipalNav.eventPosts;
        case AppRoutes.complaintManagement:
          return PrincipalNav.complaints;
        case AppRoutes.eventsCalendar:
          return PrincipalNav.calendar;
        case AppRoutes.principalDocuments:
          return PrincipalNav.documents;
        case AppRoutes.reportsAnalytics:
          return PrincipalNav.reports;
        case AppRoutes.principalAnalytics:
          return PrincipalNav.analytics;
        case AppRoutes.schoolGallery:
          return PrincipalNav.gallery;
        default:
          return null;
      }
    } else if (portal == 'teacher') {
      switch (route) {
        case AppRoutes.teacherDashboard:
          return TeacherNav.dashboard;
        case AppRoutes.teacherClasses:
          return TeacherNav.classes;
        case AppRoutes.teacherTimetable:
          return TeacherNav.timetable;
        case AppRoutes.teacherCalendar:
          return TeacherNav.calendar;
        case AppRoutes.teacherMyAttendance:
          return TeacherNav.myAttendance;
        case AppRoutes.teacherAttendance:
          return TeacherNav.attendance;
        case AppRoutes.teacherAttendanceHistory:
          return TeacherNav.attendanceHistory;
        case AppRoutes.teacherEventPosts:
          return TeacherNav.eventPosts;
        case AppRoutes.teacherLessonPlanner:
          return TeacherNav.lessonPlanner;
        case AppRoutes.schoolGallery:
          return TeacherNav.gallery;
        case AppRoutes.teacherCommunication:
          return TeacherNav.communication;
        case AppRoutes.teacherLeave:
          return TeacherNav.leave;
        case AppRoutes.teacherDocuments:
          return TeacherNav.documents;
        case AppRoutes.teacherHomework:
          return TeacherNav.homework;
        case AppRoutes.teacherComplaints:
          return TeacherNav.complaints;
        default:
          return null;
      }
    } else if (portal == 'parent') {
      switch (route) {
        case AppRoutes.parentDashboard:
          return ParentNav.dashboard;
        case AppRoutes.parentAttendance:
          return ParentNav.attendance;
        case AppRoutes.parentHomework:
          return ParentNav.homework;
        case AppRoutes.parentTimetable:
          return ParentNav.timetable;
        case AppRoutes.parentLessonPlanner:
          return ParentNav.lessonPlanner;
        case AppRoutes.parentTeacherChat:
          return ParentNav.chat;
        case AppRoutes.parentFees:
          return ParentNav.fees;
        case AppRoutes.parentLeave:
          return ParentNav.leave;
        case AppRoutes.parentCalendar:
          return ParentNav.calendar;
        case AppRoutes.parentDocuments:
          return ParentNav.documents;
        case AppRoutes.schoolGallery:
          return ParentNav.gallery;
        case AppRoutes.parentHealth:
          return ParentNav.health;
        case AppRoutes.parentComplaints:
          return ParentNav.complaints;
        default:
          return null;
      }
    } else if (portal == 'super_admin') {
      switch (route) {
        case AppRoutes.superAdminDashboard:
          return SuperAdminNav.dashboard;
        case AppRoutes.superAdminAuditLogs:
          return SuperAdminNav.auditLogs;
        case AppRoutes.superAdminSystemMonitor:
          return SuperAdminNav.systemMonitor;
        case AppRoutes.idCardGeneration:
          return SuperAdminNav.idCards;
        case AppRoutes.principalSchoolProfile:
          return SuperAdminNav.schoolProfile;
        case AppRoutes.superAdminAccess:
          return SuperAdminNav.access;
        case AppRoutes.staffManagement:
          return SuperAdminNav.staff;
        case AppRoutes.studentOversight:
          return SuperAdminNav.students;
        case AppRoutes.superAdminIssues:
          return SuperAdminNav.complaints;
        default:
          return null;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final sync = BackendApiClient.instance.offlineSync;
    if (sync == null) return _buildFrame(context, isOffline: false);
    return AnimatedBuilder(
      animation: sync,
      builder: (context, _) => _buildFrame(context, isOffline: sync.isOffline),
    );
  }

  Widget _buildFrame(BuildContext context, {required bool isOffline}) {
    final tokens = Theme.of(context).schoolDesk;

    Widget content = widget.child;

    final bool isDesktop = DesktopPlatform.shouldUsePersistentSidebar(context);
    final bool isPublic = widget.metadata.isPublic;
    final bool isKiosk = widget.metadata.portal == 'kiosk';

    if (isDesktop && !isPublic && !isKiosk) {
      final selectedIndex = _getSelectedIndexForRoute(
        widget.metadata.route,
        widget.metadata.portal,
      );

      Widget sidebar;
      switch (widget.metadata.portal) {
        case 'principal':
        case 'coordinator':
          sidebar = PrincipalDrawer(
            selectedIndex: selectedIndex,
            onDestinationSelected: (_) {},
          );
          break;
        case 'super_admin':
          sidebar = SuperAdminDrawer(
            selectedIndex: selectedIndex,
            onDestinationSelected: (_) {},
          );
          break;
        case 'teacher':
          sidebar = TeacherDrawer(
            selectedIndex: selectedIndex,
            onDestinationSelected: (_) {},
          );
          break;
        case 'parent':
          sidebar = ParentDrawer(
            selectedIndex: selectedIndex,
            onDestinationSelected: (_) {},
          );
          break;
        case 'shared':
          final currentRole = BackendApiClient.instance.currentRoleName
              ?.trim()
              .toLowerCase();
          switch (currentRole) {
            case 'principal':
            case 'coordinator':
            case 'admin':
              sidebar = PrincipalDrawer(
                selectedIndex: selectedIndex,
                onDestinationSelected: (_) {},
              );
              break;
            case 'super_admin':
              sidebar = SuperAdminDrawer(
                selectedIndex: selectedIndex,
                onDestinationSelected: (_) {},
              );
              break;
            case 'teacher':
              sidebar = TeacherDrawer(
                selectedIndex: selectedIndex,
                onDestinationSelected: (_) {},
              );
              break;
            case 'parent':
              sidebar = ParentDrawer(
                selectedIndex: selectedIndex,
                onDestinationSelected: (_) {},
              );
              break;
            default:
              sidebar = const SizedBox.shrink();
          }
          break;
        default:
          sidebar = const SizedBox.shrink();
      }

      content = Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          sidebar,
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(child: widget.child),
        ],
      );
    }

    final manifest = FeatureManifestRegistry.manifestForRoute(
      widget.metadata.route,
    );
    if (isOffline && manifest.onlineOnlyMutation) {
      final sync = BackendApiClient.instance.offlineSync;
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SchoolDeskOnlineRequiredBanner(
            onRetry: sync == null ? null : () => unawaited(sync.syncNow()),
          ),
          Expanded(child: content),
        ],
      );
    }

    return PopScope(
      canPop: _canExitOnBack,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBackWithoutPop();
      },
      child: FocusTraversalGroup(
        policy: ReadingOrderTraversalPolicy(),
        child: Semantics(
          label: widget.metadata.semanticLabel,
          container: true,
          explicitChildNodes: true,
          child: DecoratedBox(
            decoration: BoxDecoration(color: tokens.pageBackground),
            child: content,
          ),
        ),
      ),
    );
  }
}
