import 'package:schooldesk1/routes/app_routes.dart';

class RouteAccessGuard {
  RouteAccessGuard._();

  static const Set<String> authenticatedRoles = {
    'principal',
    'admin',
    'teacher',
    'parent',
  };

  static const Set<String> publicRoutes = {
    AppRoutes.initial,
    AppRoutes.landingPage,
    AppRoutes.onboarding,
    AppRoutes.principalLogin,
    AppRoutes.adminLogin,
    AppRoutes.teacherLogin,
    AppRoutes.parentLogin,
  };

  static const Set<String> sharedProtectedRoutes = {
    AppRoutes.notificationCenter,
    AppRoutes.settingsScreen,
    AppRoutes.profileScreen,
    AppRoutes.globalSearch,
    AppRoutes.homeworkMessaging,
  };

  static const Map<String, Set<String>> _routeRoles = {
    AppRoutes.principalDashboard: {'principal'},
    AppRoutes.guidedAssistant: {'principal', 'admin'},
    AppRoutes.staffManagement: {'principal', 'admin'},
    AppRoutes.staffForm: {'principal', 'admin'},
    AppRoutes.studentOversight: {'principal'},
    AppRoutes.approvalCenter: {'principal'},
    AppRoutes.principalInbox: {'principal'},
    AppRoutes.feeMonitoring: {'principal'},
    AppRoutes.timetableManagement: {'principal'},
    AppRoutes.syllabusMonitoring: {'principal'},
    AppRoutes.examsResults: {'principal'},
    AppRoutes.communicationCenter: {'principal'},
    AppRoutes.principalChatCommunications: {'principal'},
    AppRoutes.complaintManagement: {'principal'},
    AppRoutes.eventsCalendar: {'principal'},
    AppRoutes.reportsAnalytics: {'principal'},
    AppRoutes.academicManagement: {'principal', 'admin'},
    AppRoutes.academicYearForm: {'principal', 'admin'},
    AppRoutes.academicSubjectForm: {'principal', 'admin'},
    AppRoutes.academicClassForm: {'principal', 'admin'},
    AppRoutes.academicCurriculumForm: {'principal', 'admin'},
    AppRoutes.principalAcademicInfo: {'principal'},
    AppRoutes.principalAnalytics: {'principal'},
    AppRoutes.principalUserManagement: {'principal'},
    AppRoutes.guardianDirectory: {'principal'},
    AppRoutes.principalClasses: {'principal'},
    AppRoutes.principalAttendance: {'principal'},
    AppRoutes.principalSubjects: {'principal'},
    AppRoutes.principalTimetable: {'principal'},
    AppRoutes.principalExams: {'principal'},
    AppRoutes.principalResults: {'principal'},
    AppRoutes.principalAccountCreate: {'principal'},
    AppRoutes.principalAccountEdit: {'principal'},
    AppRoutes.principalParentChildAssignment: {'principal'},
    AppRoutes.principalSchoolProfile: {'principal'},
    AppRoutes.adminDashboard: {'admin'},
    AppRoutes.adminStudents: {'admin'},
    AppRoutes.adminTeachers: {'admin'},
    AppRoutes.adminAttendance: {'admin'},
    AppRoutes.adminFees: {'admin'},
    AppRoutes.adminFeeStructureForm: {'principal', 'admin'},
    AppRoutes.adminInvoiceGenerationForm: {'principal', 'admin'},
    AppRoutes.adminPaymentRecordForm: {'principal', 'admin'},
    AppRoutes.adminPaymentRequests: {'admin'},
    AppRoutes.adminPaymentRequestDecision: {'admin'},
    AppRoutes.adminTimetable: {'admin'},
    AppRoutes.adminTimetableGenerationForm: {'admin'},
    AppRoutes.adminTimetablePeriodForm: {'admin'},
    AppRoutes.adminTimetableSubstitutionForm: {'admin'},
    AppRoutes.adminExams: {'admin'},
    AppRoutes.adminExamForm: {'principal', 'admin'},
    AppRoutes.adminExamScheduleForm: {'principal', 'admin'},
    AppRoutes.adminCommunication: {'admin'},
    AppRoutes.adminHelpdesk: {'admin'},
    AppRoutes.adminDocuments: {'admin'},
    AppRoutes.adminUserAccess: {'admin'},
    AppRoutes.adminAccountCreate: {'admin'},
    AppRoutes.adminAccountEdit: {'admin'},
    AppRoutes.adminParentChildAssignment: {'admin'},
    AppRoutes.adminReports: {'admin'},
    AppRoutes.adminAcademicInfo: {'admin'},
    AppRoutes.idCardGeneration: {'admin'},
    AppRoutes.reportCardGenerator: {'admin'},
    AppRoutes.teacherDashboard: {'teacher'},
    AppRoutes.teacherClasses: {'teacher'},
    AppRoutes.teacherAttendance: {'teacher'},
    AppRoutes.teacherMyAttendance: {'teacher'},
    AppRoutes.teacherHomework: {'teacher'},
    AppRoutes.teacherHomeworkForm: {'teacher'},
    AppRoutes.teacherHomeworkSubmissions: {'teacher'},
    AppRoutes.teacherPerformance: {'teacher'},
    AppRoutes.teacherStudentNotes: {'teacher'},
    AppRoutes.teacherCommunication: {'teacher'},
    AppRoutes.teacherParentInteraction: {'teacher'},
    AppRoutes.teacherLeave: {'teacher'},
    AppRoutes.teacherLeaveRequestForm: {'teacher'},
    AppRoutes.teacherDiscipline: {'teacher'},
    AppRoutes.teacherReports: {'teacher'},
    AppRoutes.teacherDiary: {'teacher'},
    AppRoutes.teacherAcademicInfo: {'teacher'},
    AppRoutes.parentDashboard: {'parent'},
    AppRoutes.parentAcademicProgress: {'parent'},
    AppRoutes.parentAttendance: {'parent'},
    AppRoutes.parentHomework: {'parent'},
    AppRoutes.parentHomeworkSubmit: {'parent'},
    AppRoutes.parentNotices: {'parent'},
    AppRoutes.parentTeacherChat: {'parent'},
    AppRoutes.parentFees: {'parent'},
    AppRoutes.parentPaymentRequestForm: {'parent'},
    AppRoutes.parentLeave: {'parent'},
    AppRoutes.parentLeaveRequestForm: {'parent'},
    AppRoutes.parentCalendar: {'parent'},
    AppRoutes.parentDocuments: {'parent'},
    AppRoutes.parentDiary: {'parent'},
    AppRoutes.parentAcademicInfo: {'parent'},
    AppRoutes.feePaymentReceipt: {'parent'},
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

    final allowedRoles = _routeRoles[routeName];
    if (allowedRoles == null || allowedRoles.isEmpty) {
      return null;
    }

    final normalizedRole = _normalizeRole(currentRole);
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
      case 'admin':
        return AppRoutes.adminDashboard;
      case 'teacher':
        return AppRoutes.teacherDashboard;
      case 'parent':
        return AppRoutes.parentDashboard;
      default:
        return null;
    }
  }

  static String _normalizeRole(String? role) {
    return (role ?? '').trim().toLowerCase();
  }
}
