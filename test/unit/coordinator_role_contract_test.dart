import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:schooldesk1/core/authorization/role_access_policy.dart';
import 'package:schooldesk1/core/auth/role_context.dart';
import 'package:schooldesk1/routes/app_routes.dart';
import 'package:schooldesk1/routes/route_access_guard.dart';

void main() {
  group('Coordinator role contract', () {
    test('has principal parity outside finance and a separate home route', () {
      expect(
        RouteAccessGuard.dashboardForRole('coordinator'),
        AppRoutes.coordinatorDashboard,
      );
      expect(
        RouteAccessGuard.isRoleAllowedFor(
          routeName: AppRoutes.principalAttendance,
          role: 'coordinator',
        ),
        isTrue,
      );
      expect(
        RouteAccessGuard.isRoleAllowedFor(
          routeName: AppRoutes.principalChatCommunications,
          role: 'coordinator',
        ),
        isTrue,
      );
      expect(
        RouteAccessGuard.isRoleAllowedFor(
          routeName: AppRoutes.reportsAnalytics,
          role: 'coordinator',
        ),
        isTrue,
      );
      expect(
        RouteAccessGuard.isRoleAllowedFor(
          routeName: AppRoutes.principalSchoolProfile,
          role: 'coordinator',
        ),
        isTrue,
      );
      expect(
        RoleAccessPolicy.allows(
          const RoleContext(
            accountId: 'coordinator',
            schoolId: 'assigned-branch',
            branchId: null,
            role: SchoolDeskRole.coordinator,
          ),
          SchoolDeskCapability.viewReports,
        ),
        isTrue,
      );
    });

    test('cannot enter finance routes', () {
      for (final route in [
        AppRoutes.feeMonitoring,
        AppRoutes.principalPaymentRequests,
        AppRoutes.principalFees,
      ]) {
        expect(
          RouteAccessGuard.isRoleAllowedFor(
            routeName: route,
            role: 'coordinator',
          ),
          isFalse,
          reason: 'Coordinator must never access $route',
        );
      }
    });

    test(
      'communication backend owns direct threads and exposes class groups',
      () {
        final source = File(
          'supabase/functions/api/handlers/communications.ts',
        ).readAsStringSync();
        expect(source, contains('leader_id'));
        expect(source, contains('role does not match session'));
        expect(source, contains('class_sections'));
        expect(source, contains('"coordinator"'));
        expect(source, contains('conversationLeaderId'));
        expect(
          source,
          contains('leader_id: conversationType === "parent_teacher"'),
        );
      },
    );

    test('fees handler remains an explicit coordinator exclusion', () {
      final source = File(
        'supabase/functions/api/handlers/fees.ts',
      ).readAsStringSync();
      expect(source, contains('["admin", "principal", "super_admin"]'));
      expect(source, isNot(contains('"coordinator"')));
    });

    test('coordinator report UI removes fee reports and branch switching', () {
      final reports = File(
        'lib/features/reports/presentation/screens/reports_analytics_screen/reports_analytics_screen.dart',
      ).readAsStringSync();
      final dashboard = File(
        'lib/features/dashboard/presentation/screens/principal_dashboard_screen/principal_dashboard_screen.dart',
      ).readAsStringSync();
      final navigation = File('lib/core/widgets/app_navigation.dart')
          .readAsStringSync();

      expect(reports, contains("if (!_isCoordinator) const Tab(text: 'Fee')"));
      expect(reports, contains("if (!_isCoordinator) _buildFeeTab()"));
      expect(
        reports,
        contains("if (_isCoordinator && lower.contains('fee')) return;"),
      );
      expect(dashboard, contains('if (!_isCoordinator) BranchSwitcher'));
      expect(
        navigation,
        contains('hiddenRoutes: isCoordinator ? {AppRoutes.feeMonitoring}'),
      );
    });

    test('coordinator student and analytics UI hides finance features', () {
      final students = File(
        'lib/features/people/presentation/screens/student_oversight_screen/student_oversight_screen.dart',
      ).readAsStringSync();
      final analytics = File(
        'lib/features/reports/presentation/screens/principal_analytics_screen/principal_analytics_screen.dart',
      ).readAsStringSync();
      final analyticsRepository = File(
        'lib/roles/principal/data/api_principal_analytics_repository.dart',
      ).readAsStringSync();
      final classes = File(
        'lib/features/academics/presentation/screens/principal_classes_screen/principal_classes_screen.dart',
      ).readAsStringSync();

      expect(students, contains('showFinanceFields: !_isCoordinator'));
      expect(students, contains('if (!_isCoordinator) ...['));
      expect(
        analytics,
        contains('TabController(length: _isCoordinator ? 3 : 4'),
      );
      expect(analyticsRepository, contains("== 'coordinator'"));
      expect(classes, contains('showFees: !_isCoordinator'));
      expect(classes, contains('if (showFees)'));
    });

    test('coordinator account access stays within assigned branch', () {
      final users = File(
        'lib/features/people/presentation/screens/admin_user_access_screen/admin_user_access_screen.dart',
      ).readAsStringSync();
      final form = File(
        'lib/features/people/presentation/screens/admin_user_access_screen/account_access_form_screen.dart',
      ).readAsStringSync();

      expect(users, contains('_effectiveOwnerRole'));
      expect(users, contains("const ['Coordinator', 'Teacher', 'Parent']"));
      expect(users, contains('DashboardRole.coordinator'));
      expect(form, contains("const ['Coordinator', 'Teacher', 'Parent']"));
      expect(
        RoleAccessPolicy.allows(
          const RoleContext(
            accountId: 'coordinator',
            schoolId: 'assigned-branch',
            branchId: null,
            role: SchoolDeskRole.coordinator,
          ),
          SchoolDeskCapability.manageAccounts,
        ),
        isTrue,
      );
    });

    test('leadership notifications and principal UI gates include coordinator', () {
      final birthdays = File(
        'supabase/functions/api/handlers/birthday_alerts.ts',
      ).readAsStringSync();
      final notifications = File(
        'lib/features/communication/presentation/screens/notification_center_screen/notification_center_screen.dart',
      ).readAsStringSync();
      final calendar = File(
        'lib/features/calendar/presentation/screens/events_calendar_screen/events_calendar_screen.dart',
      ).readAsStringSync();
      final classHub = File(
        'lib/features/academics/presentation/screens/principal_classes_screen/principal_classes_screen.dart',
      ).readAsStringSync();

      expect(birthdays, contains('targetRole !== "coordinator"'));
      expect(notifications, contains("'coordinator'"));
      expect(notifications, contains('if (!_isCoordinator)'));
      expect(calendar, contains("role == 'coordinator'"));
      expect(classHub, contains("arguments: _isCoordinator ? 'coordinator' : 'principal'"));
    });

    test(
      'account mutations normalize coordinator in profile and Auth metadata',
      () {
        final source = File(
          'supabase/functions/api/handlers/users.ts',
        ).readAsStringSync();
        expect(source, contains('trim().toLowerCase() || "staff"'));
        expect(
          source,
          contains(
            'app_metadata: { school_id: school, role_name: resolvedRole }',
          ),
        );
        expect(source, contains('role_name: normalizedRole'));
      },
    );
  });
}
