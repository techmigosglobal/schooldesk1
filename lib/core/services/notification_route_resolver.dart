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
      'issue' || 'complaint' => _issueRouteFor(role),
      'homework' => _homeworkRouteFor(role, data),
      'fee' => _feeRouteFor(role),
      'exam' || 'exam_schedule' => _examRouteFor(role),
      'event' || 'event_post' => _eventRouteFor(role),
      'approval' => AppRoutes.approvalCenter,
      'leave' || 'student_leave' => _leaveRouteFor(role),
      'staff_attendance' ||
      'staff_attendance_daily_report' ||
      'staff_attendance_monthly_report' => _attendanceRouteFor(role),
      'attendance' || 'attendance_marked' => _attendanceRouteFor(role),
      'lesson_planner_weekly_digest' => _lessonPlannerRouteFor(role),
      'lesson_planner' || 'lesson_plan' => _lessonPlannerRouteFor(role),
      'health' || 'health_reminder' => _healthRouteFor(role),
      'birthday' || 'birthday_reminder' => _birthdayRouteFor(role),
      'admission_inquiry' => AppRoutes.admissionInquiries,
      _ => AppRoutes.notificationCenter,
    };
    final safeRoute = _safeFallbackRoute(fallbackRoute, role);
    return NotificationRouteTarget(
      route: safeRoute,
      arguments: _argumentsFor(safeRoute, role, data),
    );
  }

  static String _safeFallbackRoute(String candidate, String role) {
    if (_isRouteAllowed(candidate, role)) return candidate;
    if (_isRouteAllowed(AppRoutes.notificationCenter, role)) {
      return AppRoutes.notificationCenter;
    }
    return RouteAccessGuard.dashboardForRole(role) ?? AppRoutes.landingPage;
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
    final referenceId =
        (data['reference_id'] ??
                data['referenceId'] ??
                data['homework_id'] ??
                data['homeworkId'] ??
                '')
            .toString()
            .trim();
    final studentId = (data['student_id'] ?? data['studentId'] ?? '')
        .toString()
        .trim();
    final parentChildContext = role == 'parent' && studentId.isNotEmpty
        ? <String, dynamic>{
            // Preserve the direct backend key in the child-scoped route
            // contract; the resolved value above still supports legacy keys.
            // 'student_id': data['student_id'].toString().trim()
            'student_id': studentId,
            'selected_student_id': studentId,
          }
        : const <String, dynamic>{};
    if (route == AppRoutes.approvalCenter || referenceType == 'approval') {
      final isLeave =
          referenceType == 'leave' || referenceType == 'student_leave';
      return {
        'referenceType': referenceType.isEmpty ? 'approval' : referenceType,
        'referenceId': referenceId,
        'initialTab': isLeave ? 'leave' : 'approvals',
      };
    }
    if (referenceId.isEmpty) {
      return parentChildContext.isEmpty ? null : parentChildContext;
    }
    if (route == AppRoutes.principalEventApprovals &&
        (referenceType == 'event_post' || referenceType == 'event')) {
      return {
        'referenceType': 'event_post',
        'referenceId': referenceId,
        'initialTab': 'event_posts',
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
        'homework_id': referenceId,
        ...parentChildContext,
        if ((data['student_name'] ?? '').toString().trim().isNotEmpty)
          'student_name': data['student_name'].toString().trim(),
        if (route == AppRoutes.parentHomeworkSubmit) 'open_feedback': true,
      };
    }
    return parentChildContext.isEmpty ? null : parentChildContext;
  }

  static String _communicationRouteFor(String role) {
    return switch (role) {
      'parent' => AppRoutes.parentTeacherChat,
      'teacher' => AppRoutes.teacherCommunication,
      'principal' || 'coordinator' => AppRoutes.communicationCenter,
      _ => AppRoutes.notificationCenter,
    };
  }

  static String _messageRouteFor(String role) {
    return switch (role) {
      'parent' => AppRoutes.parentTeacherChat,
      'teacher' => AppRoutes.teacherCommunication,
      'principal' || 'coordinator' => AppRoutes.communicationCenter,
      _ => AppRoutes.notificationCenter,
    };
  }

  static String _issueRouteFor(String role) {
    return switch (role) {
      'principal' || 'coordinator' => AppRoutes.complaintManagement,
      'teacher' => AppRoutes.teacherComplaints,
      'parent' => AppRoutes.parentComplaints,
      'super_admin' => AppRoutes.superAdminIssues,
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

  static String _eventRouteFor(String role) {
    return switch (role) {
      'parent' => AppRoutes.schoolGallery,
      'teacher' => AppRoutes.teacherEventPosts,
      'principal' || 'coordinator' => AppRoutes.principalEventApprovals,
      _ => AppRoutes.notificationCenter,
    };
  }

  static String _attendanceRouteFor(String role) {
    return switch (role) {
      'principal' || 'coordinator' => AppRoutes.principalAttendance,
      'teacher' => AppRoutes.teacherMyAttendance,
      'parent' => AppRoutes.parentAttendance,
      _ => AppRoutes.notificationCenter,
    };
  }

  static String _lessonPlannerRouteFor(String role) {
    return switch (role) {
      'principal' || 'coordinator' => AppRoutes.principalLessonPlanner,
      'teacher' => AppRoutes.teacherLessonPlanner,
      'parent' => AppRoutes.parentLessonPlanner,
      _ => AppRoutes.notificationCenter,
    };
  }

  static String _healthRouteFor(String role) {
    return switch (role) {
      'parent' => AppRoutes.parentHealth,
      // Teachers have no separate health workspace; the communication hub is
      // where they can act on a parent reminder with the family.
      'teacher' => AppRoutes.teacherCommunication,
      'principal' || 'coordinator' => AppRoutes.notificationCenter,
      _ => AppRoutes.notificationCenter,
    };
  }

  static String _birthdayRouteFor(String role) {
    // Teachers can act on birthday notices through the communication hub;
    // other roles retain the notification center as their meaningful target.
    return role == 'teacher'
        ? AppRoutes.teacherCommunication
        : AppRoutes.notificationCenter;
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
