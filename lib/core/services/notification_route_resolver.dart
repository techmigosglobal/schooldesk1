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
    final requestedRoute = (data['route'] ?? '').toString().trim();
    if (_isRouteAllowed(requestedRoute, role)) {
      return NotificationRouteTarget(
        route: requestedRoute,
        arguments: _argumentsFor(requestedRoute, role, data),
      );
    }

    final referenceType = (data['reference_type'] ?? data['type'] ?? '')
        .toString()
        .toLowerCase()
        .trim();
    final fallbackRoute = switch (referenceType) {
      'announcement' || 'notice' => _communicationRouteFor(role),
      'message' => _messageRouteFor(role),
      'homework' => _homeworkRouteFor(role),
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
      'health' => AppRoutes.notificationCenter,
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

  static String _homeworkRouteFor(String role) {
    return switch (role) {
      'parent' => AppRoutes.parentHomework,
      'teacher' => AppRoutes.teacherHomework,
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

  static String _leaveRouteFor(String role) {
    return switch (role) {
      'parent' => AppRoutes.parentLeave,
      'teacher' => AppRoutes.teacherLeave,
      'principal' => AppRoutes.approvalCenter,
      _ => AppRoutes.notificationCenter,
    };
  }
}
