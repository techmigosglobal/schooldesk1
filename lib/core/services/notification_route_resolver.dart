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
        arguments: _argumentsFor(requestedRoute, role),
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
      'event' => _eventRouteFor(role),
      'approval' => AppRoutes.approvalCenter,
      'leave' => _leaveRouteFor(role),
      _ => AppRoutes.notificationCenter,
    };
    return NotificationRouteTarget(
      route: fallbackRoute,
      arguments: _argumentsFor(fallbackRoute, role),
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

  static Object? _argumentsFor(String route, String role) {
    if (route == AppRoutes.notificationCenter ||
        route == AppRoutes.settingsScreen ||
        route == AppRoutes.profileScreen) {
      return role.isEmpty ? 'admin' : role;
    }
    return null;
  }

  static String _communicationRouteFor(String role) {
    return switch (role) {
      'parent' => AppRoutes.parentNotices,
      'teacher' => AppRoutes.teacherCommunication,
      'admin' => AppRoutes.adminCommunication,
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
      'admin' => AppRoutes.adminFees,
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
    return switch (role) {
      'parent' => AppRoutes.parentCalendar,
      'teacher' => AppRoutes.teacherPerformance,
      'admin' => AppRoutes.adminExams,
      'principal' => AppRoutes.examsResults,
      _ => AppRoutes.notificationCenter,
    };
  }

  static String _eventRouteFor(String role) {
    return switch (role) {
      'parent' => AppRoutes.parentCalendar,
      'principal' => AppRoutes.eventsCalendar,
      _ => AppRoutes.notificationCenter,
    };
  }

  static String _leaveRouteFor(String role) {
    return switch (role) {
      'parent' => AppRoutes.parentLeave,
      'teacher' => AppRoutes.teacherLeave,
      'principal' || 'admin' => AppRoutes.approvalCenter,
      _ => AppRoutes.notificationCenter,
    };
  }
}
