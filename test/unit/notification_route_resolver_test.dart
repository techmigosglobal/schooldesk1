import 'package:flutter_test/flutter_test.dart';
import 'package:schooldesk1/routes/app_routes.dart';
import 'package:schooldesk1/core/services/notification_route_resolver.dart';

void main() {
  group('NotificationRouteResolver', () {
    test('opens an explicitly allowed route for the logged-in role', () {
      final target = NotificationRouteResolver.resolve(
        data: {
          'route': AppRoutes.parentTeacherChat,
          'reference_type': 'announcement',
          'role': 'parent',
        },
        currentRole: 'parent',
      );

      expect(target.route, AppRoutes.parentTeacherChat);
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

    test(
      'routes issue notifications to the role-specific complaint screen',
      () {
        final principal = NotificationRouteResolver.resolve(
          data: {'reference_type': 'issue'},
          currentRole: 'principal',
        );
        final teacher = NotificationRouteResolver.resolve(
          data: {'reference_type': 'complaint'},
          currentRole: 'teacher',
        );

        expect(principal.route, AppRoutes.complaintManagement);
        expect(teacher.route, AppRoutes.teacherComplaints);
      },
    );

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

    test('routes a parent attendance notification to child attendance', () {
      final target = NotificationRouteResolver.resolve(
        data: {'reference_type': 'attendance'},
        currentRole: 'parent',
      );

      expect(target.route, AppRoutes.parentAttendance);
    });

    test('routes principal student leave notifications to the Leave tab', () {
      final inAppTarget = NotificationRouteResolver.resolve(
        data: {'reference_type': 'student_leave', 'reference_id': 'leave-123'},
        currentRole: 'principal',
      );
      final pushTarget = NotificationRouteResolver.resolve(
        data: {'reference_type': 'leave'},
        currentRole: 'principal',
      );

      expect(inAppTarget.route, AppRoutes.approvalCenter);
      final inAppArgs = inAppTarget.arguments! as Map<String, dynamic>;
      expect(inAppArgs['referenceId'], 'leave-123');
      expect(inAppArgs['initialTab'], 'leave');
      expect(pushTarget.route, AppRoutes.approvalCenter);
      final pushArgs = pushTarget.arguments! as Map<String, dynamic>;
      expect(pushArgs['initialTab'], 'leave');
    });

    test('passes event post reference context into principal approvals', () {
      final target = NotificationRouteResolver.resolve(
        data: {
          'route': AppRoutes.principalEventApprovals,
          'reference_type': 'event_post',
          'reference_id': 'post-123',
          'role': 'principal',
        },
        currentRole: 'principal',
      );

      expect(target.route, AppRoutes.principalEventApprovals);
      expect(target.arguments, isA<Map<String, dynamic>>());
      final args = target.arguments! as Map<String, dynamic>;
      expect(args['referenceType'], 'event_post');
      expect(args['referenceId'], 'post-123');
      expect(args['initialTab'], 'event_posts');
    });

    test('routes teacher feature notifications to actionable screens', () {
      final approvedPost = NotificationRouteResolver.resolve(
        data: {'reference_type': 'event_post', 'action': 'approved'},
        currentRole: 'teacher',
      );
      final circular = NotificationRouteResolver.resolve(
        data: {'reference_type': 'announcement'},
        currentRole: 'teacher',
      );
      final homework = NotificationRouteResolver.resolve(
        data: {'reference_type': 'homework'},
        currentRole: 'teacher',
      );
      final homeworkSubmission = NotificationRouteResolver.resolve(
        data: {'reference_type': 'homework', 'action': 'submission'},
        currentRole: 'teacher',
      );
      final health = NotificationRouteResolver.resolve(
        data: {'reference_type': 'health_reminder'},
        currentRole: 'teacher',
      );
      final birthday = NotificationRouteResolver.resolve(
        data: {'reference_type': 'birthday'},
        currentRole: 'teacher',
      );
      final lessonPlan = NotificationRouteResolver.resolve(
        data: {'reference_type': 'lesson_planner'},
        currentRole: 'teacher',
      );
      final leave = NotificationRouteResolver.resolve(
        data: {'reference_type': 'leave'},
        currentRole: 'teacher',
      );

      expect(approvedPost.route, AppRoutes.teacherEventPosts);
      expect(circular.route, AppRoutes.teacherCommunication);
      expect(homework.route, AppRoutes.teacherHomework);
      expect(homeworkSubmission.route, AppRoutes.teacherHomeworkSubmissions);
      expect(health.route, AppRoutes.teacherCommunication);
      expect(birthday.route, AppRoutes.teacherCommunication);
      expect(lessonPlan.route, AppRoutes.teacherLessonPlanner);
      expect(leave.route, AppRoutes.teacherLeave);
    });
  });
}
