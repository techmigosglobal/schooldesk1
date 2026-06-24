import 'package:flutter_test/flutter_test.dart';
import 'package:schooldesk1/routes/app_routes.dart';
import 'package:schooldesk1/core/services/notification_route_resolver.dart';

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
            'route': AppRoutes.feeMonitoring,
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

    test('falls back to homework and retired exam-safe routes', () {
      final homework = NotificationRouteResolver.resolve(
        data: {'reference_type': 'homework'},
        currentRole: 'parent',
      );
      final exam = NotificationRouteResolver.resolve(
        data: {'reference_type': 'exam_schedule'},
        currentRole: 'teacher',
      );

      expect(homework.route, AppRoutes.parentHomework);
      expect(exam.route, AppRoutes.notificationCenter);
      expect(exam.arguments, 'teacher');
    });

    test('routes principal messages to the communication center', () {
      final target = NotificationRouteResolver.resolve(
        data: {'reference_type': 'message'},
        currentRole: 'principal',
      );

      expect(target.route, AppRoutes.communicationCenter);
    });

    test('routes role-based push report and event references', () {
      final dailyAttendance = NotificationRouteResolver.resolve(
        data: {'reference_type': 'staff_attendance_daily_report'},
        currentRole: 'principal',
      );
      final monthlyAttendance = NotificationRouteResolver.resolve(
        data: {'reference_type': 'staff_attendance_monthly_report'},
        currentRole: 'principal',
      );
      final eventForPrincipal = NotificationRouteResolver.resolve(
        data: {'reference_type': 'event_post'},
        currentRole: 'principal',
      );
      final eventForTeacher = NotificationRouteResolver.resolve(
        data: {'reference_type': 'event_post'},
        currentRole: 'teacher',
      );
      final lessonPlannerDigest = NotificationRouteResolver.resolve(
        data: {'reference_type': 'lesson_planner_weekly_digest'},
        currentRole: 'principal',
      );

      expect(dailyAttendance.route, AppRoutes.principalAttendance);
      expect(monthlyAttendance.route, AppRoutes.principalAttendance);
      expect(eventForPrincipal.route, AppRoutes.principalEventApprovals);
      expect(eventForTeacher.route, AppRoutes.teacherEventPosts);
      expect(lessonPlannerDigest.route, AppRoutes.principalLessonPlanner);
    });
  });
}
