import 'package:flutter_test/flutter_test.dart';
import 'package:schooldesk1/routes/app_routes.dart';
import 'package:schooldesk1/routes/route_access_guard.dart';

void main() {
  group('RouteAccessGuard', () {
    test('allows public routes without authentication', () {
      for (final route in [
        AppRoutes.initial,
        AppRoutes.landingPage,
        AppRoutes.onboarding,
        AppRoutes.principalLogin,
        AppRoutes.teacherLogin,
        AppRoutes.parentLogin,
        AppRoutes.kioskLogin,
      ]) {
        expect(
          RouteAccessGuard.redirectFor(
            routeName: route,
            isAuthenticated: false,
            currentRole: null,
          ),
          isNull,
          reason: '$route should be public',
        );
      }
    });

    test('redirects unauthenticated protected routes to landing', () {
      expect(
        RouteAccessGuard.redirectFor(
          routeName: AppRoutes.principalDashboard,
          isAuthenticated: false,
          currentRole: null,
        ),
        AppRoutes.landingPage,
      );
    });

    test('does not treat admin as an authenticated app role', () {
      expect(RouteAccessGuard.authenticatedRoles, isNot(contains('admin')));
      expect(RouteAccessGuard.dashboardForRole('Admin'), isNull);
      expect(
        RouteAccessGuard.initialRouteFor(
          isAuthenticated: true,
          currentRole: 'Admin',
        ),
        AppRoutes.initial,
      );
      expect(
        RouteAccessGuard.redirectFor(
          routeName: AppRoutes.principalDashboard,
          isAuthenticated: true,
          currentRole: 'Admin',
        ),
        AppRoutes.landingPage,
      );
    });

    test('guards principal setup and monitoring routes by principal role', () {
      const principalRoutes = [
        AppRoutes.principalDashboard,
        AppRoutes.staffManagement,
        AppRoutes.staffForm,
        AppRoutes.studentOversight,
        AppRoutes.approvalCenter,
        AppRoutes.feeMonitoring,
        AppRoutes.principalPaymentRequests,
        AppRoutes.principalPaymentRequestDecision,
        AppRoutes.academicManagement,
        AppRoutes.principalClasses,
        AppRoutes.principalAttendance,
        AppRoutes.principalSubjects,
        AppRoutes.principalLessonPlanner,
        AppRoutes.principalAccountCreate,
        AppRoutes.principalAccountEdit,
        AppRoutes.principalParentChildAssignment,
        AppRoutes.eventsCalendar,
        AppRoutes.principalEventApprovals,
        AppRoutes.principalChatCommunications,
      ];

      for (final route in principalRoutes) {
        expect(RouteAccessGuard.allowedRolesFor(route), {'principal'});
        expect(
          RouteAccessGuard.redirectFor(
            routeName: route,
            isAuthenticated: true,
            currentRole: 'Principal',
          ),
          isNull,
          reason: '$route should be reachable for Principal',
        );
        expect(
          RouteAccessGuard.redirectFor(
            routeName: route,
            isAuthenticated: true,
            currentRole: 'Teacher',
          ),
          AppRoutes.teacherDashboard,
          reason: '$route should redirect Teacher away',
        );
      }
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

    test('allows active teacher module routes for teacher role', () {
      const teacherRoutes = [
        AppRoutes.teacherDashboard,
        AppRoutes.teacherClasses,
        AppRoutes.teacherTimetable,
        AppRoutes.teacherAttendance,
        AppRoutes.teacherAttendanceHistory,
        AppRoutes.teacherMyAttendance,
        AppRoutes.teacherHomework,
        AppRoutes.teacherHomeworkForm,
        AppRoutes.teacherHomeworkSubmissions,
        AppRoutes.teacherCommunication,
        AppRoutes.teacherLeave,
        AppRoutes.teacherLeaveRequestForm,
        AppRoutes.teacherReports,
        AppRoutes.teacherDiary,
        AppRoutes.teacherEventPosts,
        AppRoutes.teacherLessonPlanner,
        AppRoutes.schoolGallery,
        AppRoutes.notificationCenter,
        AppRoutes.profileScreen,
        AppRoutes.settingsScreen,
        AppRoutes.homeworkMessaging,
      ];

      for (final route in teacherRoutes) {
        expect(
          RouteAccessGuard.allowedRolesFor(route),
          contains('teacher'),
          reason: '$route should explicitly list Teacher as an allowed role',
        );
        expect(
          RouteAccessGuard.redirectFor(
            routeName: route,
            isAuthenticated: true,
            currentRole: 'Teacher',
          ),
          isNull,
          reason: '$route should be reachable for Teacher',
        );
      }
    });

    test('guards homework input and submission screens by role', () {
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
      expect(
        RouteAccessGuard.initialRouteFor(
          isAuthenticated: true,
          currentRole: 'Kiosk',
        ),
        AppRoutes.kioskQrAttendance,
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
