import 'package:schooldesk1/routes/app_routes.dart';
import 'package:schooldesk1/routes/route_access_guard.dart';

class NotificationRouteTarget {
  final String route;
  final Object? arguments;

  const NotificationRouteTarget({required this.route, this.arguments});
}

class NotificationRouteResolver {
  NotificationRouteResolver._();

  static NotificationRouteTarget resolve({
    required Map<String, dynamic> data,
    required String? currentRole,
  }) {
    final role = (currentRole ?? data['role'] ?? '').toString().toLowerCase();
    final referenceType = (data['reference_type'] ?? data['type'] ?? '')
        .toString()
        .toLowerCase()
        .trim();
    final action = (data['action'] ?? data['sub_type'] ?? '')
        .toString()
        .toLowerCase()
        .trim();
    final homeworkFeedback =
        referenceType == 'homework' &&
        (action == 'feedback' ||
            action == 'submission_feedback' ||
            action == 'needs_revision' ||
            action == 'revision_requested');
    final requestedRoute = (data['route'] ?? '').toString().trim();
    if (homeworkFeedback && role == 'parent') {
      return NotificationRouteTarget(
        route: AppRoutes.parentHomeworkSubmit,
        arguments: _argumentsFor(AppRoutes.parentHomeworkSubmit, role, data),
      );
    }
    if (_isRouteAllowed(requestedRoute, role)) {
      return NotificationRouteTarget(
        route:
            homeworkFeedback &&
                role == 'parent' &&
                requestedRoute == AppRoutes.parentHomework
            ? AppRoutes.parentHomeworkSubmit
            : requestedRoute,
        arguments: _argumentsFor(
          homeworkFeedback &&
                  role == 'parent' &&
                  requestedRoute == AppRoutes.parentHomework
              ? AppRoutes.parentHomeworkSubmit
              : requestedRoute,
          role,
          data,
        ),
      );
    }

    final fallbackRoute = switch (referenceType) {
      'announcement' || 'notice' => _communicationRouteFor(role),
      'message' => _messageRouteFor(role),
      'homework' => _homeworkRouteFor(role, data),
      'fee' => _feeRouteFor(role),
      'exam' || 'exam_schedule' => _examRouteFor(role),
      'ptm' || 'parent_teacher_meeting' => _ptmRouteFor(role),
      'event' || 'event_post' => _eventRouteFor(role),
      'approval' => AppRoutes.approvalCenter,
      'leave' => _leaveRouteFor(role),
      'staff_attendance' ||
      'staff_attendance_daily_report' ||
      'staff_attendance_monthly_report' => _attendanceRouteFor(role),
      'lesson_planner_weekly_digest' => _lessonPlannerRouteFor(role),
      'lesson_planner' || 'lesson_plan' => _lessonPlannerRouteFor(role),
      'health' || 'health_reminder' => _healthRouteFor(role),
      'birthday' || 'birthday_reminder' => _birthdayRouteFor(role),
      _ => AppRoutes.notificationCenter,
    };
    return NotificationRouteTarget(
      route: fallbackRoute,
      arguments: _argumentsFor(fallbackRoute, role, data),
    );
  }

  static bool _isRouteAllowed(String route, String role) {
    if (route.isEmpty || !AppRoutes.routes.containsKey(route)) return false;
    return RouteAccessGuard.redirectFor(
          routeName: route,
          isAuthenticated: true,
          currentRole: role,
        ) ==
        null;
  }

  static Object? _argumentsFor(
    String route,
    String role,
    Map<String, dynamic> data,
  ) {
    if (route == AppRoutes.notificationCenter ||
        route == AppRoutes.settingsScreen ||
        route == AppRoutes.profileScreen) {
      return role.isEmpty ? 'principal' : role;
    }
    final referenceType = (data['reference_type'] ?? data['type'] ?? '')
        .toString()
        .toLowerCase()
        .trim();
    final referenceId = (data['reference_id'] ?? data['referenceId'] ?? '')
        .toString()
        .trim();
    if (referenceId.isEmpty) return null;
    if (route == AppRoutes.principalEventApprovals &&
        (referenceType == 'event_post' || referenceType == 'event')) {
      return {
        'referenceType': 'event_post',
        'referenceId': referenceId,
        'initialTab': 'event_posts',
      };
    }
    if (route == AppRoutes.approvalCenter || referenceType == 'approval') {
      return {
        'referenceType': referenceType.isEmpty ? 'approval' : referenceType,
        'referenceId': referenceId,
        'initialTab': 'approvals',
      };
    }
    if (route == AppRoutes.teacherEventPosts &&
        (referenceType == 'event_post' || referenceType == 'event')) {
      return {
        'referenceType': 'event_post',
        'referenceId': referenceId,
        'initialTab': 'event_posts',
      };
    }
    if (referenceType == 'homework' ||
        route == AppRoutes.teacherHomeworkSubmissions ||
        route == AppRoutes.parentHomeworkSubmit ||
        route == AppRoutes.parentHomework ||
        route == AppRoutes.teacherHomework) {
      return {
        'homework': {
          'id': referenceId,
          'homework_id': referenceId,
          'reference_id': referenceId,
        },
        'reference_id': referenceId,
        'id': referenceId,
        if (route == AppRoutes.parentHomeworkSubmit) 'open_feedback': true,
      };
    }
    return null;
  }

  static String _communicationRouteFor(String role) {
    return switch (role) {
      'parent' => AppRoutes.parentNotices,
      'teacher' => AppRoutes.teacherCommunication,
      'principal' => AppRoutes.communicationCenter,
      _ => AppRoutes.notificationCenter,
    };
  }

  static String _messageRouteFor(String role) {
    return switch (role) {
      'parent' => AppRoutes.parentTeacherChat,
      'teacher' => AppRoutes.teacherCommunication,
      'principal' => AppRoutes.communicationCenter,
      _ => AppRoutes.notificationCenter,
    };
  }

  static String _feeRouteFor(String role) {
    return switch (role) {
      'parent' => AppRoutes.parentFees,
      'principal' => AppRoutes.feeMonitoring,
      _ => AppRoutes.notificationCenter,
    };
  }

  static String _homeworkRouteFor(String role, Map<String, dynamic> data) {
    final action = (data['action'] ?? data['sub_type'] ?? '')
        .toString()
        .toLowerCase();
    return switch (role) {
      'parent' =>
        (action == 'assignment' ||
                action == 'feedback' ||
                action == 'submission_feedback' ||
                action == 'reviewed' ||
                action == 'needs_revision' ||
                action == 'revision_requested' ||
                action == 'created')
            ? AppRoutes.parentHomeworkSubmit
            : AppRoutes.parentHomework,
      'teacher' =>
        (action == 'submission')
            ? AppRoutes.teacherHomeworkSubmissions
            : AppRoutes.teacherHomework,
      _ => AppRoutes.notificationCenter,
    };
  }

  static String _examRouteFor(String role) {
    return AppRoutes.notificationCenter;
  }

  static String _ptmRouteFor(String role) {
    return switch (role) {
      'parent' => AppRoutes.parentPTMBooking,
      'teacher' => AppRoutes.teacherParentInteraction,
      _ => AppRoutes.notificationCenter,
    };
  }

  static String _eventRouteFor(String role) {
    return switch (role) {
      'parent' => AppRoutes.schoolGallery,
      'teacher' => AppRoutes.teacherEventPosts,
      'principal' => AppRoutes.principalEventApprovals,
      _ => AppRoutes.notificationCenter,
    };
  }

  static String _attendanceRouteFor(String role) {
    return switch (role) {
      'principal' => AppRoutes.principalAttendance,
      'teacher' => AppRoutes.teacherMyAttendance,
      'parent' => AppRoutes.parentAttendance,
      _ => AppRoutes.notificationCenter,
    };
  }

  static String _lessonPlannerRouteFor(String role) {
    return switch (role) {
      'principal' => AppRoutes.principalLessonPlanner,
      'teacher' => AppRoutes.teacherLessonPlanner,
      'parent' => AppRoutes.parentLessonPlanner,
      _ => AppRoutes.notificationCenter,
    };
  }

  static String _healthRouteFor(String role) {
    return switch (role) {
      'parent' => AppRoutes.parentHealth,
      'teacher' => AppRoutes.teacherCommunication,
      'principal' => AppRoutes.communicationCenter,
      _ => AppRoutes.notificationCenter,
    };
  }

  static String _birthdayRouteFor(String role) {
    return switch (role) {
      'parent' => AppRoutes.parentNotices,
      'teacher' => AppRoutes.teacherCommunication,
      'principal' => AppRoutes.communicationCenter,
      _ => AppRoutes.notificationCenter,
    };
  }

  static String _leaveRouteFor(String role) {
    return switch (role) {
      'parent' => AppRoutes.parentLeave,
      'teacher' => AppRoutes.teacherLeave,
      'principal' => AppRoutes.approvalCenter,
      _ => AppRoutes.notificationCenter,
    };
  }
}
