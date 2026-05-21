import 'package:flutter_test/flutter_test.dart';
import 'package:schooldesk1/routes/app_routes.dart';
import 'package:schooldesk1/services/notification_route_resolver.dart';

void main() {
  group('NotificationRouteResolver', () {
    test('opens an explicitly allowed route for the logged-in role', () {
      final target = NotificationRouteResolver.resolve(
        data: {
          'route': AppRoutes.parentNotices,
          'reference_type': 'announcement',
          'role': 'parent',
        },
        currentRole: 'parent',
      );

      expect(target.route, AppRoutes.parentNotices);
      expect(target.arguments, isNull);
    });

    test(
      'falls back to a role-safe route when payload route is not allowed',
      () {
        final target = NotificationRouteResolver.resolve(
          data: {
            'route': AppRoutes.adminFees,
            'reference_type': 'fee',
            'role': 'parent',
          },
          currentRole: 'parent',
        );

        expect(target.route, AppRoutes.parentFees);
      },
    );

    test('routes shared notification center with the active role argument', () {
      final target = NotificationRouteResolver.resolve(
        data: {'reference_type': 'unknown'},
        currentRole: 'teacher',
      );

      expect(target.route, AppRoutes.notificationCenter);
      expect(target.arguments, 'teacher');
    });

    test('falls back to homework and exam role-safe routes', () {
      final homework = NotificationRouteResolver.resolve(
        data: {'reference_type': 'homework'},
        currentRole: 'parent',
      );
      final exam = NotificationRouteResolver.resolve(
        data: {'reference_type': 'exam_schedule'},
        currentRole: 'teacher',
      );

      expect(homework.route, AppRoutes.parentHomework);
      expect(exam.route, AppRoutes.teacherPerformance);
    });
  });
}
