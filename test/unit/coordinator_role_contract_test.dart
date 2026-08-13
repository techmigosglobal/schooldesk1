import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
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

      expect(birthdays, contains('targetRole !== "coordinator"'));
      expect(notifications, contains("'coordinator'"));
      expect(notifications, contains('if (!_isCoordinator)'));
      expect(calendar, contains("role == 'coordinator'"));
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
