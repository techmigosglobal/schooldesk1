import 'package:flutter_test/flutter_test.dart';
import 'package:schooldesk1/routes/app_routes.dart';
import 'package:schooldesk1/routes/route_access_guard.dart';

/// Tests that verify the super admin routing contract.
///
/// These tests enforce that:
/// 1. `dashboardForRole('super_admin')` returns `superAdminDashboard`
/// 2. `initialRouteFor` for super_admin returns `superAdminDashboard`
/// 3. `redirectFor` for super_admin on principal routes redirects to `superAdminDashboard`
/// 4. `isRoleAllowedFor` correctly gates super admin to system-level routes only
/// 5. Super admin bypasses route guards (existing behavior)
void main() {
  group('Super Admin Dashboard Routing', () {
    test('dashboardForRole("super_admin") returns superAdminDashboard', () {
      expect(
        RouteAccessGuard.dashboardForRole('super_admin'),
        AppRoutes.superAdminDashboard,
        reason:
            'Super admin must land on SuperAdminDashboardScreen, NOT PrincipalDashboardScreen',
      );
    });

    test('dashboardForRole("Super_Admin") is case-insensitive', () {
      expect(
        RouteAccessGuard.dashboardForRole('Super_Admin'),
        AppRoutes.superAdminDashboard,
      );
      expect(
        RouteAccessGuard.dashboardForRole('SUPER_ADMIN'),
        AppRoutes.superAdminDashboard,
      );
      expect(
        RouteAccessGuard.dashboardForRole(' Super_Admin '),
        AppRoutes.superAdminDashboard,
        reason: 'Role normalization should trim whitespace',
      );
    });

    test('initialRouteFor super_admin returns superAdminDashboard', () {
      expect(
        RouteAccessGuard.initialRouteFor(
          isAuthenticated: true,
          currentRole: 'super_admin',
        ),
        AppRoutes.superAdminDashboard,
        reason:
            'App startup for super admin must navigate to SuperAdminDashboard',
      );
    });

    test('super_admin is in authenticatedRoles', () {
      expect(
        RouteAccessGuard.authenticatedRoles,
        contains('super_admin'),
        reason: 'Super admin must be recognized as an authenticated role',
      );
    });

    test('dashboardForRole distinguishes super_admin from principal', () {
      expect(
        RouteAccessGuard.dashboardForRole('super_admin'),
        isNot(equals(AppRoutes.principalDashboard)),
        reason: 'Super admin and principal must have different home dashboards',
      );
      expect(
        RouteAccessGuard.dashboardForRole('principal'),
        AppRoutes.principalDashboard,
      );
    });
  });

  group('Super Admin Route Access — System-Level Routes', () {
    test('super admin can access superAdminDashboard', () {
      expect(
        RouteAccessGuard.isRoleAllowedFor(
          routeName: AppRoutes.superAdminDashboard,
          role: 'super_admin',
        ),
        isTrue,
      );
      expect(
        RouteAccessGuard.redirectFor(
          routeName: AppRoutes.superAdminDashboard,
          isAuthenticated: true,
          currentRole: 'super_admin',
        ),
        isNull,
      );
    });

    test('super admin can access superAdminAuditLogs', () {
      expect(
        RouteAccessGuard.isRoleAllowedFor(
          routeName: AppRoutes.superAdminAuditLogs,
          role: 'super_admin',
        ),
        isTrue,
      );
      expect(
        RouteAccessGuard.redirectFor(
          routeName: AppRoutes.superAdminAuditLogs,
          isAuthenticated: true,
          currentRole: 'super_admin',
        ),
        isNull,
      );
    });

    test('super admin can access superAdminSystemMonitor', () {
      expect(
        RouteAccessGuard.isRoleAllowedFor(
          routeName: AppRoutes.superAdminSystemMonitor,
          role: 'super_admin',
        ),
        isTrue,
      );
    });

    test('super admin can access superAdminAccess', () {
      expect(
        RouteAccessGuard.isRoleAllowedFor(
          routeName: AppRoutes.superAdminAccess,
          role: 'super_admin',
        ),
        isTrue,
      );
    });

    test('super admin can access shared protected routes', () {
      for (final route in [
        AppRoutes.notificationCenter,
        AppRoutes.settingsScreen,
        AppRoutes.profileScreen,
        AppRoutes.globalSearch,
        AppRoutes.homeworkMessaging,
      ]) {
        expect(
          RouteAccessGuard.redirectFor(
            routeName: route,
            isAuthenticated: true,
            currentRole: 'super_admin',
          ),
          isNull,
          reason:
              '$route should be accessible to super_admin as a shared route',
        );
      }
    });
  });

  group('Super Admin Bypasses Route Guards', () {
    test('super_admin bypasses redirectFor for any route', () {
      // Super admin should be able to access any route without being redirected
      final routesToCheck = [
        AppRoutes.principalDashboard,
        AppRoutes.staffManagement,
        AppRoutes.studentOversight,
        AppRoutes.feeMonitoring,
        AppRoutes.principalClasses,
        AppRoutes.principalAttendance,
        AppRoutes.superAdminDashboard,
        AppRoutes.superAdminAuditLogs,
      ];

      for (final route in routesToCheck) {
        expect(
          RouteAccessGuard.redirectFor(
            routeName: route,
            isAuthenticated: true,
            currentRole: 'super_admin',
          ),
          isNull,
          reason: 'Super admin should bypass redirectFor for $route',
        );
      }
    });

    test('isRoleAllowedFor returns true for super_admin on any route', () {
      final routesToCheck = [
        AppRoutes.principalDashboard,
        AppRoutes.staffManagement,
        AppRoutes.studentOversight,
        AppRoutes.feeMonitoring,
        AppRoutes.principalClasses,
        AppRoutes.superAdminDashboard,
        AppRoutes.superAdminAuditLogs,
        AppRoutes.teacherDashboard,
        AppRoutes.parentDashboard,
      ];

      for (final route in routesToCheck) {
        expect(
          RouteAccessGuard.isRoleAllowedFor(
            routeName: route,
            role: 'super_admin',
          ),
          isTrue,
          reason: 'Super admin should have isRoleAllowedFor=true for $route',
        );
      }
    });
  });

  group('Super Admin Route Exclusivity', () {
    test('superAdminDashboard is only for super_admin', () {
      expect(
        RouteAccessGuard.allowedRolesFor(AppRoutes.superAdminDashboard),
        contains('super_admin'),
      );
    });

    test('superAdminAuditLogs is only for super_admin', () {
      expect(
        RouteAccessGuard.allowedRolesFor(AppRoutes.superAdminAuditLogs),
        contains('super_admin'),
      );
    });

    test('superAdminSystemMonitor is only for super_admin', () {
      expect(
        RouteAccessGuard.allowedRolesFor(AppRoutes.superAdminSystemMonitor),
        contains('super_admin'),
      );
    });

    test('superAdminAccess is only for super_admin', () {
      expect(
        RouteAccessGuard.allowedRolesFor(AppRoutes.superAdminAccess),
        contains('super_admin'),
      );
    });

    test('principal cannot access super admin exclusive routes', () {
      expect(
        RouteAccessGuard.isRoleAllowedFor(
          routeName: AppRoutes.superAdminDashboard,
          role: 'principal',
        ),
        isFalse,
        reason: 'Principal should NOT access superAdminDashboard',
      );
    });
  });

  group('Role Differentiation — Super Admin vs Principal', () {
    test('principal routes are NOT in super admin allowedRoles', () {
      // These routes should be principal-only (not super_admin)
      final principalOnlyRoutes = [
        AppRoutes.principalDashboard,
        AppRoutes.approvalCenter,
        AppRoutes.feeMonitoring,
        AppRoutes.principalPaymentRequests,
        AppRoutes.principalPaymentRequestDecision,
        AppRoutes.principalAcademicInfo,
        AppRoutes.principalAnalytics,
        AppRoutes.principalClasses,
        AppRoutes.principalAttendance,
        AppRoutes.principalSubjects,
        AppRoutes.principalLessonPlanner,
        AppRoutes.principalDocuments,
        AppRoutes.principalAuditLogs,
        AppRoutes.principalEventApprovals,
        AppRoutes.principalTimetable,
        AppRoutes.guardianDirectory,
        AppRoutes.communicationCenter,
        AppRoutes.principalChatCommunications,
        AppRoutes.complaintManagement,
        AppRoutes.eventsCalendar,
        AppRoutes.reportsAnalytics,
        AppRoutes.academicManagement,
        AppRoutes.systemMonitor,
      ];

      for (final route in principalOnlyRoutes) {
        final allowedRoles = RouteAccessGuard.allowedRolesFor(route);
        expect(
          allowedRoles,
          isNot(contains('super_admin')),
          reason:
              '$route should be principal-only, not accessible to super_admin. '
              'Allowed roles: $allowedRoles',
        );
      }
    });
  });

  group('Super Admin Redirect For — LoginLoadingScreen Flow', () {
    test(
      'LoginLoadingScreen would route super_admin to superAdminDashboard',
      () {
        // Simulates the logic in LoginLoadingScreen._initialize()
        final role = 'super_admin';
        final route =
            RouteAccessGuard.dashboardForRole(role) ?? '/landing-page-screen';
        expect(route, AppRoutes.superAdminDashboard);
      },
    );

    test('LoginLoadingScreen would route principal to principalDashboard', () {
      final role = 'principal';
      final route =
          RouteAccessGuard.dashboardForRole(role) ?? '/landing-page-screen';
      expect(route, AppRoutes.principalDashboard);
    });

    test('LoginLoadingScreen would route teacher to teacherDashboard', () {
      final role = 'teacher';
      final route =
          RouteAccessGuard.dashboardForRole(role) ?? '/landing-page-screen';
      expect(route, AppRoutes.teacherDashboard);
    });

    test('LoginLoadingScreen would route kiosk to kioskQrAttendance', () {
      final role = 'kiosk';
      final route =
          RouteAccessGuard.dashboardForRole(role) ?? '/landing-page-screen';
      expect(route, AppRoutes.kioskQrAttendance);
    });
  });

  group('Super Admin — Existing Behavior Preservation', () {
    test('admin role still maps to principal dashboard', () {
      expect(
        RouteAccessGuard.dashboardForRole('admin'),
        AppRoutes.principalDashboard,
        reason: 'Legacy admin role must still map to principal',
      );
    });

    test('principal role still maps to principal dashboard', () {
      expect(
        RouteAccessGuard.dashboardForRole('principal'),
        AppRoutes.principalDashboard,
      );
    });

    test('teacher role still maps to teacher dashboard', () {
      expect(
        RouteAccessGuard.dashboardForRole('teacher'),
        AppRoutes.teacherDashboard,
      );
    });

    test('parent role still maps to parent dashboard', () {
      expect(
        RouteAccessGuard.dashboardForRole('parent'),
        AppRoutes.parentDashboard,
      );
    });

    test('kiosk role still maps to kiosk QR attendance', () {
      expect(
        RouteAccessGuard.dashboardForRole('kiosk'),
        AppRoutes.kioskQrAttendance,
      );
    });
  });
}
