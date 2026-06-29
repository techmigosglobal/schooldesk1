import 'package:schooldesk1/routes/app_routes.dart';

class RouteAccessGuard {
  RouteAccessGuard._();

  static const Set<String> authenticatedRoles = {
    'principal',
    'teacher',
    'parent',
    'kiosk',
  };

  static const Set<String> publicRoutes = {
    AppRoutes.initial,
    AppRoutes.landingPage,
    AppRoutes.onboarding,
    AppRoutes.principalLogin,
    AppRoutes.teacherLogin,
    AppRoutes.parentLogin,
    AppRoutes.kioskLogin,
  };

  static const Set<String> sharedProtectedRoutes = {
    AppRoutes.notificationCenter,
    AppRoutes.settingsScreen,
    AppRoutes.profileScreen,
    AppRoutes.globalSearch,
    AppRoutes.homeworkMessaging,
  };

  static const Map<String, Set<String>> _routeRoles = {
    AppRoutes.idCardGeneration: {'principal'},
    // Principal routes
    AppRoutes.principalDashboard: {'principal'},
    AppRoutes.staffManagement: {'principal'},
    AppRoutes.staffForm: {'principal'},
    AppRoutes.studentOversight: {'principal'},
    AppRoutes.approvalCenter: {'principal'},
    AppRoutes.feeMonitoring: {'principal'},
    AppRoutes.principalPaymentRequests: {'principal'},
    AppRoutes.principalPaymentRequestDecision: {'principal'},
    AppRoutes.communicationCenter: {'principal'},
    AppRoutes.principalChatCommunications: {'principal'},
    AppRoutes.complaintManagement: {'principal'},
    AppRoutes.eventsCalendar: {'principal'},
    AppRoutes.reportsAnalytics: {'principal'},
    AppRoutes.academicManagement: {'principal'},
    AppRoutes.academicYearDetail: {'principal'},
    AppRoutes.academicYearClasswiseExport: {'principal'},
    AppRoutes.academicYearUsersExport: {'principal'},
    AppRoutes.academicYearFeesExport: {'principal'},
    AppRoutes.academicYearForm: {'principal'},
    AppRoutes.academicSubjectForm: {'principal'},
    AppRoutes.academicClassForm: {'principal'},
    AppRoutes.academicCurriculumForm: {'principal'},
    AppRoutes.principalAcademicInfo: {'principal'},
    AppRoutes.principalAnalytics: {'principal'},
    AppRoutes.principalUserManagement: {'principal'},
    AppRoutes.principalClasses: {'principal'},
    AppRoutes.principalAttendance: {'principal'},
    AppRoutes.principalSubjects: {'principal'},
    AppRoutes.principalLessonPlanner: {'principal'},
    AppRoutes.principalEventApprovals: {'principal'},
    AppRoutes.principalTimetable: {'principal'},
    AppRoutes.principalDocuments: {'principal'},
    AppRoutes.principalAuditLogs: {'principal'},
    AppRoutes.guardianDirectory: {'principal'},
    AppRoutes.principalAccountCreate: {'principal'},
    AppRoutes.principalAccountEdit: {'principal'},
    AppRoutes.principalParentChildAssignment: {'principal'},
    AppRoutes.principalSchoolProfile: {'principal'},
    AppRoutes.systemMonitor: {'principal'},
    // Teacher routes
    AppRoutes.teacherDashboard: {'teacher'},
    AppRoutes.teacherClasses: {'teacher'},
    AppRoutes.teacherTimetable: {'teacher'},
    AppRoutes.teacherCalendar: {'teacher'},
    AppRoutes.teacherAttendance: {'teacher'},
    AppRoutes.teacherAttendanceHistory: {'teacher'},
    AppRoutes.teacherMyAttendance: {'teacher'},
    AppRoutes.teacherCommunication: {'teacher'},
    AppRoutes.teacherParentInteraction: {'teacher'},
    AppRoutes.teacherLeave: {'teacher'},
    AppRoutes.teacherLeaveRequestForm: {'teacher'},
    AppRoutes.teacherDiary: {'teacher'},
    AppRoutes.teacherEventPosts: {'teacher'},
    AppRoutes.teacherLessonPlanner: {'teacher'},
    AppRoutes.teacherStudentNotes: {'teacher'},
    AppRoutes.teacherDocuments: {'teacher'},
    // Shared routes
    AppRoutes.schoolGallery: {'principal', 'teacher', 'parent'},
    AppRoutes.kioskQrAttendance: {'kiosk'},
    // Parent routes
    AppRoutes.parentDashboard: {'parent'},
    AppRoutes.parentAttendance: {'parent'},
    AppRoutes.parentHomework: {'parent'},
    AppRoutes.parentHomeworkSubmit: {'parent'},
    AppRoutes.parentNotices: {'parent'},
    AppRoutes.parentTeacherChat: {'parent'},
    AppRoutes.parentFees: {'parent'},
    AppRoutes.parentPaymentRequestForm: {'parent'},
    AppRoutes.parentLeave: {'parent'},
    AppRoutes.parentLeaveRequestForm: {'parent'},
    AppRoutes.parentTimetable: {'parent'},
    AppRoutes.parentPTMBooking: {'parent'},
    AppRoutes.parentCalendar: {'parent'},
    AppRoutes.parentDocuments: {'parent'},
    AppRoutes.parentDiary: {'parent'},
    AppRoutes.feePaymentReceipt: {'parent'},
    AppRoutes.parentLessonPlanner: {'parent'},
    AppRoutes.parentPaymentSelection: {'parent'},
  };

  static String? redirectFor({
    required String? routeName,
    required bool isAuthenticated,
    required String? currentRole,
  }) {
    if (routeName == null || publicRoutes.contains(routeName)) {
      return null;
    }

    if (!isAuthenticated) {
      return AppRoutes.landingPage;
    }

    if (sharedProtectedRoutes.contains(routeName)) {
      return null;
    }

    final normalizedRole = _normalizeRole(currentRole);
    final allowedRoles = _routeRoles[routeName];
    if (allowedRoles == null || allowedRoles.isEmpty) {
      return null;
    }

    if (normalizedRole.isEmpty) {
      return AppRoutes.landingPage;
    }

    if (allowedRoles.contains(normalizedRole)) {
      return null;
    }

    return dashboardForRole(normalizedRole) ?? AppRoutes.landingPage;
  }

  static Set<String> allowedRolesFor(String routeName) {
    if (publicRoutes.contains(routeName)) {
      return const <String>{};
    }
    if (sharedProtectedRoutes.contains(routeName)) {
      return authenticatedRoles;
    }
    return _routeRoles[routeName] ?? const <String>{};
  }

  static bool isRoleAllowedFor({
    required String routeName,
    required String? role,
  }) {
    if (publicRoutes.contains(routeName)) {
      return true;
    }

    final normalizedRole = _normalizeRole(role);
    if (normalizedRole.isEmpty) {
      return false;
    }

    return allowedRolesFor(routeName).contains(normalizedRole);
  }

  static String initialRouteFor({
    required bool isAuthenticated,
    required String? currentRole,
  }) {
    if (!isAuthenticated) {
      return AppRoutes.initial;
    }
    return dashboardForRole(currentRole) ?? AppRoutes.initial;
  }

  static String? dashboardForRole(String? role) {
    switch (_normalizeRole(role)) {
      case 'principal':
        return AppRoutes.principalDashboard;
      case 'teacher':
        return AppRoutes.teacherDashboard;
      case 'parent':
        return AppRoutes.parentDashboard;
      case 'kiosk':
        return AppRoutes.kioskQrAttendance;
      default:
        return null;
    }
  }

  static String _normalizeRole(String? role) {
    final normalized = (role ?? '').trim().toLowerCase();
    if (normalized == 'admin') return 'principal';
    return normalized;
  }
}
