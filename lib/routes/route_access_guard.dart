import 'package:schooldesk1/routes/app_routes.dart';

class RouteAccessGuard {
  RouteAccessGuard._();

  static const Set<String> authenticatedRoles = {
    'principal',
    'coordinator',
    'teacher',
    'parent',
    'kiosk',
    'super_admin',
  };

  static const Set<String> publicRoutes = {
    AppRoutes.initial,
    AppRoutes.landingPage,
    AppRoutes.onboarding,
    AppRoutes.principalLogin,
    AppRoutes.teacherLogin,
    AppRoutes.parentLogin,
    AppRoutes.kioskLogin,
    AppRoutes.demoRoleSelector,
  };

  static const Set<String> sharedProtectedRoutes = {
    AppRoutes.notificationCenter,
    AppRoutes.settingsScreen,
    AppRoutes.profileScreen,
    AppRoutes.globalSearch,
    AppRoutes.homeworkMessaging,
    AppRoutes.help,
  };

  static const Map<String, Set<String>> _routeRoles = {
    AppRoutes.idCardGeneration: {'principal'},
    // Principal routes
    AppRoutes.principalDashboard: {'principal'},
    AppRoutes.coordinatorDashboard: {'coordinator'},
    AppRoutes.staffManagement: {'principal'},
    AppRoutes.staffForm: {'principal'},
    AppRoutes.studentOversight: {'principal'},
    AppRoutes.approvalCenter: {'principal'},
    AppRoutes.feeMonitoring: {'principal'},
    AppRoutes.feeHome: {'principal'},
    AppRoutes.feeStructures: {'principal'},
    AppRoutes.feeCollect: {'principal'},
    AppRoutes.feeLedger: {'principal'},
    AppRoutes.feeReports: {'principal'},
    AppRoutes.principalPaymentRequests: {'principal'},
    AppRoutes.principalPaymentRequestDecision: {'principal'},
    AppRoutes.principalFeeStructureForm: {'principal'},
    AppRoutes.principalInvoiceGenerationForm: {'principal'},
    AppRoutes.principalPaymentRecordForm: {'principal'},
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
    AppRoutes.principalEventPosts: {'principal'},
    AppRoutes.principalTimetable: {'principal'},
    AppRoutes.principalDocuments: {'principal'},
    AppRoutes.principalAuditLogs: {'principal'},
    AppRoutes.guardianDirectory: {'principal'},
    AppRoutes.principalAccountCreate: {'principal'},
    AppRoutes.principalAccountEdit: {'principal'},
    AppRoutes.principalParentChildAssignment: {'principal'},
    AppRoutes.principalSchoolProfile: {'principal'},
    AppRoutes.admissionInquiries: {'principal', 'coordinator'},
    AppRoutes.systemMonitor: {'principal'},
    // Super Admin routes
    AppRoutes.superAdminDashboard: {'super_admin'},
    AppRoutes.superAdminAuditLogs: {'super_admin'},
    AppRoutes.superAdminSystemMonitor: {'super_admin'},
    AppRoutes.superAdminAccess: {'super_admin'},
    AppRoutes.superAdminIssues: {'super_admin'},
    // Teacher routes
    AppRoutes.teacherDashboard: {'teacher'},
    AppRoutes.teacherClasses: {'teacher'},
    AppRoutes.teacherTimetable: {'teacher'},
    AppRoutes.teacherCalendar: {'teacher'},
    AppRoutes.teacherAttendance: {'teacher'},
    AppRoutes.teacherAttendanceHistory: {'teacher'},
    AppRoutes.teacherMyAttendance: {'teacher'},
    AppRoutes.teacherCommunication: {'teacher'},
    AppRoutes.teacherComplaints: {'teacher'},
    AppRoutes.teacherParentInteraction: {'teacher'},
    AppRoutes.teacherLeave: {'teacher'},
    AppRoutes.teacherLeaveRequestForm: {'teacher'},
    AppRoutes.teacherHomework: {'teacher'},
    AppRoutes.teacherHomeworkForm: {'teacher'},
    AppRoutes.teacherHomeworkSubmissions: {'teacher'},
    AppRoutes.teacherEventPosts: {'teacher'},
    AppRoutes.teacherLessonPlanner: {'teacher'},
    AppRoutes.teacherDocuments: {'teacher'},
    // Shared routes
    AppRoutes.schoolGallery: {'principal', 'teacher', 'parent'},
    AppRoutes.kioskQrAttendance: {'kiosk'},
    // Parent routes
    AppRoutes.parentDashboard: {'parent'},
    AppRoutes.parentAttendance: {'parent'},
    AppRoutes.parentHomework: {'parent'},
    AppRoutes.parentHomeworkSubmit: {'parent'},
    AppRoutes.parentTeacherChat: {'parent'},
    AppRoutes.parentComplaints: {'parent'},
    AppRoutes.parentFees: {'parent'},
    AppRoutes.parentPaymentRequestForm: {'parent'},
    AppRoutes.parentLeave: {'parent'},
    AppRoutes.parentLeaveRequestForm: {'parent'},
    AppRoutes.parentTimetable: {'parent'},
    AppRoutes.parentPTMBooking: {'parent'},
    AppRoutes.parentCalendar: {'parent'},
    AppRoutes.parentDocuments: {'parent'},
    AppRoutes.parentLessonPlanner: {'parent'},
    AppRoutes.parentPaymentSelection: {'parent'},
    AppRoutes.parentPaymentFlow: {'parent'},
    AppRoutes.parentPaymentHistory: {'parent'},
    AppRoutes.parentReceipt: {'parent'},
    AppRoutes.parentHealth: {'parent'},
    AppRoutes.principalFees: {'principal'},
    AppRoutes.principalFeeConcessions: {'principal'},
    AppRoutes.feePaymentConfig: {'principal'},
    AppRoutes.legacyParentFees: {'parent'},
    AppRoutes.legacyPrincipalPaymentRequests: {'principal'},
    AppRoutes.legacyPrincipalFeeStructures: {'principal'},
    AppRoutes.legacyPrincipalInvoiceGenerate: {'principal'},
    AppRoutes.legacyPrincipalCollectFee: {'principal'},
    AppRoutes.legacyPrincipalFeeReports: {'principal'},
    AppRoutes.legacyPrincipalPaymentConfig: {'principal'},
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
    if (normalizedRole == 'super_admin') {
      return null;
    }
    final allowedRoles = allowedRolesFor(routeName);
    if (allowedRoles.isEmpty) {
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
    final configured = _routeRoles[routeName] ?? const <String>{};
    if (configured.contains('principal') && !_isFinanceRoute(routeName)) {
      return {...configured, 'coordinator'};
    }
    return configured;
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
    if (normalizedRole == 'super_admin') {
      return true;
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
      case 'coordinator':
        return AppRoutes.coordinatorDashboard;
      case 'super_admin':
        return AppRoutes.superAdminDashboard;
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
    // Legacy: the 'admin' role was historically equivalent to 'principal' in this
    // app. Any backend user assigned role='admin' receives principal-level access.
    // If 'admin' should have its own restricted scope, remove this mapping and
    // add an explicit 'admin' case to _routeRoles and dashboardForRole.
    if (normalized == 'admin') return 'principal';
    return normalized;
  }

  static bool _isFinanceRoute(String routeName) {
    return <String>{
      AppRoutes.feeMonitoring,
      AppRoutes.feeHome,
      AppRoutes.feeStructures,
      AppRoutes.feeCollect,
      AppRoutes.feeLedger,
      AppRoutes.feeReports,
      AppRoutes.feePaymentConfig,
      AppRoutes.principalPaymentRequests,
      AppRoutes.principalPaymentRequestDecision,
      AppRoutes.principalFeeStructureForm,
      AppRoutes.principalInvoiceGenerationForm,
      AppRoutes.principalPaymentRecordForm,
      AppRoutes.principalFees,
      AppRoutes.principalFeeConcessions,
      AppRoutes.legacyPrincipalPaymentRequests,
      AppRoutes.legacyPrincipalFeeStructures,
      AppRoutes.legacyPrincipalInvoiceGenerate,
      AppRoutes.legacyPrincipalCollectFee,
      AppRoutes.legacyPrincipalFeeReports,
      AppRoutes.legacyPrincipalPaymentConfig,
      AppRoutes.academicYearFeesExport,
    }.contains(routeName);
  }
}
