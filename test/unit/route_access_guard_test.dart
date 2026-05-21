import 'package:flutter_test/flutter_test.dart';
import 'package:schooldesk1/routes/app_routes.dart';
import 'package:schooldesk1/routes/route_access_guard.dart';

void main() {
  group('RouteAccessGuard', () {
    test('allows public routes without authentication', () {
      expect(
        RouteAccessGuard.redirectFor(
          routeName: AppRoutes.adminLogin,
          isAuthenticated: false,
          currentRole: null,
        ),
        isNull,
      );
    });

    test('redirects unauthenticated protected routes to landing', () {
      expect(
        RouteAccessGuard.redirectFor(
          routeName: AppRoutes.adminDashboard,
          isAuthenticated: false,
          currentRole: null,
        ),
        AppRoutes.landingPage,
      );
    });

    test('allows authenticated users into shared protected routes', () {
      expect(
        RouteAccessGuard.redirectFor(
          routeName: AppRoutes.settingsScreen,
          isAuthenticated: true,
          currentRole: 'teacher',
        ),
        isNull,
      );
    });

    test('allows a matching role into its own route group', () {
      expect(
        RouteAccessGuard.redirectFor(
          routeName: AppRoutes.teacherAttendance,
          isAuthenticated: true,
          currentRole: 'Teacher',
        ),
        isNull,
      );
    });

    test('guards routed account input screens by owner role', () {
      expect(
        RouteAccessGuard.redirectFor(
          routeName: AppRoutes.adminAccountCreate,
          isAuthenticated: true,
          currentRole: 'Admin',
        ),
        isNull,
      );
      expect(
        RouteAccessGuard.redirectFor(
          routeName: AppRoutes.adminAccountEdit,
          isAuthenticated: true,
          currentRole: 'Admin',
        ),
        isNull,
      );
      expect(
        RouteAccessGuard.redirectFor(
          routeName: AppRoutes.adminParentChildAssignment,
          isAuthenticated: true,
          currentRole: 'Admin',
        ),
        isNull,
      );
      expect(
        RouteAccessGuard.redirectFor(
          routeName: AppRoutes.staffForm,
          isAuthenticated: true,
          currentRole: 'Admin',
        ),
        isNull,
      );
      expect(
        RouteAccessGuard.redirectFor(
          routeName: AppRoutes.staffForm,
          isAuthenticated: true,
          currentRole: 'Principal',
        ),
        isNull,
      );
      expect(
        RouteAccessGuard.redirectFor(
          routeName: AppRoutes.staffForm,
          isAuthenticated: true,
          currentRole: 'Teacher',
        ),
        AppRoutes.teacherDashboard,
      );
      expect(
        RouteAccessGuard.redirectFor(
          routeName: AppRoutes.principalAccountCreate,
          isAuthenticated: true,
          currentRole: 'Principal',
        ),
        isNull,
      );
      expect(
        RouteAccessGuard.redirectFor(
          routeName: AppRoutes.principalAccountEdit,
          isAuthenticated: true,
          currentRole: 'Principal',
        ),
        isNull,
      );
      expect(
        RouteAccessGuard.redirectFor(
          routeName: AppRoutes.principalParentChildAssignment,
          isAuthenticated: true,
          currentRole: 'Principal',
        ),
        isNull,
      );
      expect(
        RouteAccessGuard.redirectFor(
          routeName: AppRoutes.principalAccountCreate,
          isAuthenticated: true,
          currentRole: 'admin',
        ),
        AppRoutes.adminDashboard,
      );
      expect(
        RouteAccessGuard.redirectFor(
          routeName: AppRoutes.adminAccountCreate,
          isAuthenticated: true,
          currentRole: 'parent',
        ),
        AppRoutes.parentDashboard,
      );
    });

    test('guards routed admin timetable input screens by admin role', () {
      for (final route in [
        AppRoutes.adminTimetableGenerationForm,
        AppRoutes.adminTimetablePeriodForm,
        AppRoutes.adminTimetableSubstitutionForm,
      ]) {
        expect(
          RouteAccessGuard.redirectFor(
            routeName: route,
            isAuthenticated: true,
            currentRole: 'Admin',
          ),
          isNull,
        );
        expect(
          RouteAccessGuard.redirectFor(
            routeName: route,
            isAuthenticated: true,
            currentRole: 'Principal',
          ),
          AppRoutes.principalDashboard,
        );
      }
    });

    test('guards routed admin exam input screens by admin role', () {
      for (final route in [
        AppRoutes.adminExamForm,
        AppRoutes.adminExamScheduleForm,
      ]) {
        expect(
          RouteAccessGuard.redirectFor(
            routeName: route,
            isAuthenticated: true,
            currentRole: 'Admin',
          ),
          isNull,
        );
        expect(
          RouteAccessGuard.redirectFor(
            routeName: route,
            isAuthenticated: true,
            currentRole: 'Teacher',
          ),
          AppRoutes.teacherDashboard,
        );
      }
    });

    test('guards routed teacher leave input screen by teacher role', () {
      expect(
        RouteAccessGuard.redirectFor(
          routeName: AppRoutes.teacherLeaveRequestForm,
          isAuthenticated: true,
          currentRole: 'Teacher',
        ),
        isNull,
      );
      expect(
        RouteAccessGuard.redirectFor(
          routeName: AppRoutes.teacherLeaveRequestForm,
          isAuthenticated: true,
          currentRole: 'Admin',
        ),
        AppRoutes.adminDashboard,
      );
    });

    test('guards routed homework input and submission screens by role', () {
      for (final route in [
        AppRoutes.teacherHomeworkForm,
        AppRoutes.teacherHomeworkSubmissions,
      ]) {
        expect(
          RouteAccessGuard.redirectFor(
            routeName: route,
            isAuthenticated: true,
            currentRole: 'Teacher',
          ),
          isNull,
        );
        expect(
          RouteAccessGuard.redirectFor(
            routeName: route,
            isAuthenticated: true,
            currentRole: 'Parent',
          ),
          AppRoutes.parentDashboard,
        );
      }
      expect(
        RouteAccessGuard.redirectFor(
          routeName: AppRoutes.parentHomeworkSubmit,
          isAuthenticated: true,
          currentRole: 'Parent',
        ),
        isNull,
      );
      expect(
        RouteAccessGuard.redirectFor(
          routeName: AppRoutes.parentHomeworkSubmit,
          isAuthenticated: true,
          currentRole: 'Teacher',
        ),
        AppRoutes.teacherDashboard,
      );
    });

    test('redirects wrong-role access to the authenticated role dashboard', () {
      expect(
        RouteAccessGuard.redirectFor(
          routeName: AppRoutes.adminStudents,
          isAuthenticated: true,
          currentRole: 'parent',
        ),
        AppRoutes.parentDashboard,
      );
    });

    test(
      'redirects role-specific routes when the authenticated role is unknown',
      () {
        expect(
          RouteAccessGuard.redirectFor(
            routeName: AppRoutes.principalDashboard,
            isAuthenticated: true,
            currentRole: null,
          ),
          AppRoutes.landingPage,
        );
      },
    );

    test('starts authenticated users on their restored role dashboard', () {
      expect(
        RouteAccessGuard.initialRouteFor(
          isAuthenticated: true,
          currentRole: 'Principal',
        ),
        AppRoutes.principalDashboard,
      );
      expect(
        RouteAccessGuard.initialRouteFor(
          isAuthenticated: true,
          currentRole: 'Admin',
        ),
        AppRoutes.adminDashboard,
      );
      expect(
        RouteAccessGuard.initialRouteFor(
          isAuthenticated: true,
          currentRole: 'Teacher',
        ),
        AppRoutes.teacherDashboard,
      );
      expect(
        RouteAccessGuard.initialRouteFor(
          isAuthenticated: true,
          currentRole: 'Parent',
        ),
        AppRoutes.parentDashboard,
      );
    });

    test('starts unauthenticated or role-less sessions on landing', () {
      expect(
        RouteAccessGuard.initialRouteFor(
          isAuthenticated: false,
          currentRole: 'Principal',
        ),
        AppRoutes.initial,
      );
      expect(
        RouteAccessGuard.initialRouteFor(
          isAuthenticated: true,
          currentRole: null,
        ),
        AppRoutes.initial,
      );
    });
  });
}
