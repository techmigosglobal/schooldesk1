import 'package:flutter/material.dart';

import 'package:schooldesk1/features/academics/academics.dart';
import 'package:schooldesk1/features/attendance/attendance.dart';
import 'package:schooldesk1/features/communication/communication.dart';
import 'package:schooldesk1/features/dashboard/dashboard.dart';
import 'package:schooldesk1/features/documents/documents.dart';
import 'package:schooldesk1/features/finance/finance.dart';
import 'package:schooldesk1/features/operations/operations.dart';
import 'package:schooldesk1/features/auth/auth.dart';
import 'package:schooldesk1/features/reports/reports.dart';
import 'package:schooldesk1/features/people/people.dart';
import 'package:schooldesk1/features/calendar/calendar.dart';
import 'package:schooldesk1/features/shell/shell.dart';
import 'package:schooldesk1/features/homework/homework.dart';
import 'package:schooldesk1/features/leave/leave.dart';
import 'package:schooldesk1/features/profile/profile.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/widgets/admin_navigation.dart';
import 'package:schooldesk1/core/widgets/app_navigation.dart';
import 'package:schooldesk1/core/widgets/blank_role_module_screen.dart';
import 'package:schooldesk1/core/widgets/parent_navigation.dart';
import 'package:schooldesk1/core/widgets/schooldesk_route_frame.dart';
import 'package:schooldesk1/core/widgets/teacher_navigation.dart';
import 'package:schooldesk1/routes/schooldesk_screen_registry.dart';

class AppRoutes {
  static const String initial = '/';
  static const String landingPage = '/landing-page-screen';
  static const String onboarding = '/onboarding-screen';
  static const String principalLogin = '/principal-login-screen';
  static const String principalDashboard = '/principal-dashboard-screen';
  static const String guidedAssistant = '/guided-assistant-screen';
  static const String staffManagement = '/staff-management-screen';
  static const String staffForm = '/staff-management-screen/form';
  static const String studentOversight = '/student-oversight-screen';
  static const String approvalCenter = '/approval-center-screen';
  static const String principalInbox = '/principal-inbox-screen';
  static const String feeMonitoring = '/fee-monitoring-screen';
  static const String timetableManagement = '/timetable-management-screen';
  static const String syllabusMonitoring = '/syllabus-monitoring-screen';
  static const String examsResults = '/exams-results-screen';
  static const String communicationCenter = '/communication-center-screen';
  static const String principalChatCommunications =
      '/principal-chat-communications-screen';
  static const String complaintManagement = '/complaint-management-screen';
  static const String eventsCalendar = '/events-calendar-screen';
  static const String reportsAnalytics = '/reports-analytics-screen';
  static const String academicManagement = '/academic-management-screen';
  static const String academicYearForm = '/academic-management-screen/year';
  static const String academicSubjectForm =
      '/academic-management-screen/subject';
  static const String academicClassForm = '/academic-management-screen/class';
  static const String academicCurriculumForm =
      '/academic-management-screen/curriculum';
  static const String principalAcademicInfo = '/principal-academic-info-screen';
  static const String teacherAcademicInfo = '/teacher-academic-info-screen';
  static const String adminAcademicInfo = '/admin-academic-info-screen';
  static const String parentAcademicInfo = '/parent-academic-info-screen';
  // Admin Module Routes
  static const String adminLogin = '/admin-login-screen';
  static const String adminDashboard = '/admin-dashboard-screen';
  static const String adminStudents = '/admin-students-screen';
  static const String adminTeachers = '/admin-teachers-screen';
  static const String adminAttendance = '/admin-attendance-screen';
  static const String adminFees = '/admin-fees-screen';
  static const String adminFeeStructureForm =
      '/admin-fees-screen/structures/form';
  static const String adminInvoiceGenerationForm =
      '/admin-fees-screen/invoices/generate';
  static const String adminPaymentRecordForm =
      '/admin-fees-screen/payments/record';
  static const String adminPaymentRequests =
      '/admin-fees-screen/payment-requests';
  static const String adminPaymentRequestDecision =
      '/admin-fees-screen/payment-requests/decision';
  static const String adminTimetable = '/admin-timetable-screen';
  static const String adminTimetableGenerationForm =
      '/admin-timetable-screen/generate';
  static const String adminTimetablePeriodForm =
      '/admin-timetable-screen/period';
  static const String adminTimetableSubstitutionForm =
      '/admin-timetable-screen/substitution';
  static const String adminExams = '/admin-exams-screen';
  static const String adminExamForm = '/admin-exams-screen/form';
  static const String adminExamScheduleForm = '/admin-exams-screen/schedule';
  static const String adminCommunication = '/admin-communication-screen';
  static const String adminHelpdesk = '/admin-helpdesk-screen';
  static const String adminDocuments = '/admin-documents-screen';
  static const String adminUserAccess = '/admin-user-access-screen';
  static const String adminAccountCreate = '/admin-user-access-screen/create';
  static const String adminAccountEdit = '/admin-user-access-screen/edit';
  static const String adminParentChildAssignment =
      '/admin-user-access-screen/assign-children';
  static const String adminReports = '/admin-reports-screen';
  // Teacher Module Routes
  static const String teacherLogin = '/teacher-login-screen';
  static const String teacherDashboard = '/teacher-dashboard-screen';
  static const String teacherClasses = '/teacher-classes-screen';
  static const String teacherAttendance = '/teacher-attendance-screen';
  static const String teacherMyAttendance = '/teacher-my-attendance-screen';
  static const String teacherHomework = '/teacher-homework-screen';
  static const String teacherHomeworkForm = '/teacher-homework-screen/form';
  static const String teacherHomeworkSubmissions =
      '/teacher-homework-screen/submissions';
  static const String teacherPerformance = '/teacher-performance-screen';
  static const String teacherStudentNotes = '/teacher-student-notes-screen';
  static const String teacherCommunication = '/teacher-communication-screen';
  static const String teacherParentInteraction =
      '/teacher-parent-interaction-screen';
  static const String teacherLeave = '/teacher-leave-screen';
  static const String teacherLeaveRequestForm = '/teacher-leave-screen/request';
  static const String teacherDiscipline = '/teacher-discipline-screen';
  static const String teacherReports = '/teacher-reports-screen';
  // Parent Module Routes
  static const String parentLogin = '/parent-login-screen';
  static const String parentDashboard = '/parent-dashboard-screen';
  static const String parentAcademicProgress =
      '/parent-academic-progress-screen';
  static const String parentAttendance = '/parent-attendance-screen';
  static const String parentHomework = '/parent-homework-screen';
  static const String parentHomeworkSubmit = '/parent-homework-screen/submit';
  static const String parentNotices = '/parent-notices-screen';
  static const String parentTeacherChat = '/parent-teacher-chat-screen';
  static const String parentFees = '/parent-fees-screen';
  static const String parentPaymentRequestForm = '/parent-fees-screen/payment';
  static const String parentLeave = '/parent-leave-screen';
  static const String parentLeaveRequestForm = '/parent-leave-screen/request';
  static const String parentCalendar = '/parent-calendar-screen';
  static const String parentDocuments = '/parent-documents-screen';
  static const String teacherDiary = '/teacher-diary-screen';
  static const String parentDiary = '/parent-diary-screen';
  // New Screens
  static const String notificationCenter = '/notification-center-screen';
  static const String settingsScreen = '/settings-screen';
  static const String profileScreen = '/profile-screen';
  static const String globalSearch = '/global-search-screen';
  static const String idCardGeneration = '/id-card-generation-screen';
  static const String reportCardGenerator = '/report-card-generator-screen';
  static const String homeworkMessaging = '/homework-messaging-screen';
  static const String feePaymentReceipt = '/fee-payment-receipt-screen';
  static const String principalAnalytics = '/principal-analytics-screen';
  static const String principalUserManagement =
      '/principal-user-management-screen';
  static const String guardianDirectory = '/guardian-directory-screen';
  static const String principalClasses = '/principal-classes-screen';
  static const String principalAttendance = '/principal-attendance-screen';
  static const String principalSubjects = '/principal-subjects-screen';
  static const String principalTimetable = '/principal-timetable-screen';
  static const String principalExams = '/principal-exams-screen';
  static const String principalResults = '/principal-results-screen';
  static const String principalAccountCreate =
      '/principal-user-management-screen/create';
  static const String principalAccountEdit =
      '/principal-user-management-screen/edit';
  static const String principalParentChildAssignment =
      '/principal-user-management-screen/assign-children';
  static const String principalSchoolProfile =
      '/principal-school-profile-screen';
  static const bool blankRoleModuleScreens = true;

  static Map<String, WidgetBuilder> routes = {
    initial: (context) => const LandingPageScreen(),
    landingPage: (context) => const LandingPageScreen(),
    onboarding: (context) => const OnboardingScreen(),
    principalLogin: (context) => const AuthLoginScreen(),
    principalDashboard: (context) => const PrincipalDashboardScreen(),
    guidedAssistant: (context) => const GuidedAssistantScreen(),
    principalSchoolProfile: (context) => const SchoolProfileScreen(),
    staffManagement: (context) => const StaffManagementScreen(),
    staffForm: (context) => StaffFormScreen(args: _staffFormArgs(context)),
    studentOversight: (context) => const StudentOversightScreen(),
    approvalCenter: (context) => const ApprovalCenterScreen(),
    principalInbox: (context) => const PrincipalOperationalInboxScreen(),
    feeMonitoring: (context) => const FeeMonitoringScreen(),
    timetableManagement: (context) => const PrincipalTimetableScreen(),
    syllabusMonitoring: (context) => const SyllabusMonitoringScreen(),
    examsResults: (context) => const ExamsResultsScreen(),
    communicationCenter: (context) => const CommunicationCenterScreen(),
    principalChatCommunications: (context) =>
        const PrincipalChatCommunicationsScreen(),
    complaintManagement: (context) => const ComplaintManagementScreen(),
    eventsCalendar: (context) => const EventsCalendarScreen(),
    reportsAnalytics: (context) => const ReportsAnalyticsScreen(),
    academicManagement: (context) {
      final role = BackendApiClient.instance.currentRoleName?.toLowerCase();
      return AcademicManagementScreen(
        ownerRole: role == 'principal' ? 'principal' : 'admin',
      );
    },
    academicYearForm: (context) =>
        AcademicYearFormScreen(args: _academicYearFormArgs(context)),
    academicSubjectForm: (context) =>
        AcademicSubjectFormScreen(args: _academicSubjectFormArgs(context)),
    academicClassForm: (context) =>
        AcademicClassFormScreen(args: _academicClassFormArgs(context)),
    academicCurriculumForm: (context) => AcademicCurriculumFormScreen(
      args: _academicCurriculumFormArgs(context),
    ),
    principalAcademicInfo: (context) => AcademicInfoScreen(
      role: 'principal',
      drawer: PrincipalDrawer(selectedIndex: 12, onDestinationSelected: (_) {}),
      drawerIndex: 12,
    ),
    teacherAcademicInfo: (context) => AcademicInfoScreen(
      role: 'teacher',
      drawer: TeacherDrawer(selectedIndex: 15, onDestinationSelected: (_) {}),
      drawerIndex: 15,
    ),
    adminAcademicInfo: (context) => AcademicInfoScreen(
      role: 'admin',
      drawer: AdminDrawer(selectedIndex: 14, onDestinationSelected: (_) {}),
      drawerIndex: 14,
    ),
    parentAcademicInfo: (context) => AcademicInfoScreen(
      role: 'parent',
      drawer: ParentDrawer(selectedIndex: 12, onDestinationSelected: (_) {}),
      drawerIndex: 12,
    ),
    // Admin Module,
    adminLogin: (context) => const AuthLoginScreen(),
    adminDashboard: (context) => const AdminDashboardScreen(),
    adminStudents: (context) => const AdminStudentsScreen(ownerRole: 'admin'),
    adminTeachers: (context) => const StaffManagementScreen(ownerRole: 'admin'),
    adminAttendance: (context) => const AdminAttendanceScreen(),
    adminFees: (context) => const AdminFeesScreen(),
    adminFeeStructureForm: (context) =>
        AdminFeeStructureFormScreen(args: _adminFeeStructureFormArgs(context)),
    adminInvoiceGenerationForm: (context) => AdminInvoiceGenerationFormScreen(
      args: _adminInvoiceGenerationFormArgs(context),
    ),
    adminPaymentRecordForm: (context) => AdminPaymentRecordFormScreen(
      args: _adminPaymentRecordFormArgs(context),
    ),
    adminPaymentRequests: (context) => const AdminPaymentRequestsScreen(),
    adminPaymentRequestDecision: (context) => AdminPaymentRequestDecisionScreen(
      args: _adminPaymentRequestDecisionArgs(context),
    ),
    adminTimetable: (context) => const AdminTimetableScreen(),
    adminTimetableGenerationForm: (context) =>
        AdminTimetableGenerationFormScreen(
          args: _adminTimetableGenerationFormArgs(context),
        ),
    adminTimetablePeriodForm: (context) => AdminTimetablePeriodFormScreen(
      args: _adminTimetablePeriodFormArgs(context),
    ),
    adminTimetableSubstitutionForm: (context) =>
        AdminTimetableSubstitutionFormScreen(
          args: _adminTimetableSubstitutionFormArgs(context),
        ),
    adminExams: (context) => const AdminExamsScreen(),
    adminExamForm: (context) =>
        AdminExamFormScreen(args: _adminExamFormArgs(context)),
    adminExamScheduleForm: (context) =>
        AdminExamScheduleFormScreen(args: _adminExamScheduleFormArgs(context)),
    adminCommunication: (context) => const AdminCommunicationScreen(),
    adminHelpdesk: (context) => const AdminHelpdeskScreen(),
    adminDocuments: (context) => const AdminDocumentsScreen(),
    adminUserAccess: (context) => const AdminUserAccessScreen(),
    adminAccountCreate: (context) =>
        AccountAccessFormScreen(args: _accountFormArgs(context, 'admin')),
    adminAccountEdit: (context) =>
        AccountAccessFormScreen(args: _accountFormArgs(context, 'admin')),
    adminParentChildAssignment: (context) => AccountChildAssignmentScreen(
      args: _childAssignmentArgs(context, 'admin'),
    ),
    principalUserManagement: (context) =>
        const AdminUserAccessScreen(ownerRole: 'principal'),
    guardianDirectory: (context) =>
        const GuardianDirectoryScreen(ownerRole: 'principal'),
    principalClasses: (context) => const PrincipalClassesScreen(),
    principalAttendance: (context) => const PrincipalAttendanceScreen(),
    principalSubjects: (context) => const PrincipalSubjectsScreen(),
    principalTimetable: (context) => const PrincipalTimetableScreen(),
    principalExams: (context) => const PrincipalExamsScreen(),
    principalResults: (context) => const PrincipalResultsScreen(),
    principalAccountCreate: (context) =>
        AccountAccessFormScreen(args: _accountFormArgs(context, 'principal')),
    principalAccountEdit: (context) =>
        AccountAccessFormScreen(args: _accountFormArgs(context, 'principal')),
    principalParentChildAssignment: (context) => AccountChildAssignmentScreen(
      args: _childAssignmentArgs(context, 'principal'),
    ),
    adminReports: (context) => const AdminReportsScreen(),
    // Teacher Module,
    teacherLogin: (context) => const AuthLoginScreen(),
    teacherDashboard: (context) => const TeacherDashboardScreen(),
    teacherClasses: (context) => const TeacherClassesScreen(),
    teacherAttendance: (context) => const TeacherAttendanceScreen(),
    teacherMyAttendance: (context) => const TeacherMyAttendanceScreen(),
    teacherHomework: (context) => const TeacherHomeworkScreen(),
    teacherHomeworkForm: (context) =>
        TeacherHomeworkFormScreen(args: _teacherHomeworkFormArgs(context)),
    teacherHomeworkSubmissions: (context) => TeacherHomeworkSubmissionsScreen(
      args: _teacherHomeworkSubmissionsArgs(context),
    ),
    teacherPerformance: (context) => const TeacherPerformanceScreen(),
    teacherStudentNotes: (context) => const TeacherStudentNotesScreen(),
    teacherCommunication: (context) => const TeacherCommunicationScreen(),
    teacherParentInteraction: (context) =>
        const TeacherParentInteractionScreen(),
    teacherLeave: (context) => const TeacherLeaveScreen(),
    teacherLeaveRequestForm: (context) =>
        TeacherLeaveRequestFormScreen(args: _teacherLeaveFormArgs(context)),
    teacherDiscipline: (context) => const TeacherDisciplineScreen(),
    teacherReports: (context) => const TeacherReportsScreen(),
    // Parent Module,
    parentLogin: (context) => const AuthLoginScreen(),
    parentDashboard: (context) => const ParentDashboardScreen(),
    parentAcademicProgress: (context) => const ParentAcademicProgressScreen(),
    parentAttendance: (context) => const ParentAttendanceScreen(),
    parentHomework: (context) => const ParentHomeworkScreen(),
    parentHomeworkSubmit: (context) => ParentHomeworkSubmissionScreen(
      args: _parentHomeworkSubmissionArgs(context),
    ),
    parentNotices: (context) => const ParentNoticesScreen(),
    parentTeacherChat: (context) => const ParentTeacherChatScreen(),
    parentFees: (context) => const ParentFeesScreen(),
    parentPaymentRequestForm: (context) =>
        ParentPaymentRequestFormScreen(args: _parentPaymentFormArgs(context)),
    parentLeave: (context) => const ParentLeaveScreen(),
    parentLeaveRequestForm: (context) =>
        ParentLeaveRequestFormScreen(args: _parentLeaveFormArgs(context)),
    parentCalendar: (context) => const ParentCalendarScreen(),
    parentDocuments: (context) => const ParentDocumentsScreen(),
    teacherDiary: (context) => const TeacherDiaryScreen(),
    parentDiary: (context) => const ParentDiaryScreen(),
    // New Screens,
    notificationCenter: (context) {
      final role =
          ModalRoute.of(context)?.settings.arguments as String? ?? 'admin';
      return NotificationCenterScreen(role: role);
    },
    settingsScreen: (context) {
      final role =
          ModalRoute.of(context)?.settings.arguments as String? ?? 'admin';
      return AppSettingsScreen(role: role);
    },
    profileScreen: (context) {
      final role =
          ModalRoute.of(context)?.settings.arguments as String? ?? 'admin';
      return ProfileManagementScreen(role: role);
    },
    globalSearch: (context) => const GlobalSearchScreen(),
    idCardGeneration: (context) => const IdCardGenerationScreen(),
    reportCardGenerator: (context) => const ReportCardGeneratorScreen(),
    homeworkMessaging: (context) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ??
          {};
      return HomeworkMessagingScreen(
        role: args['role'] as String? ?? 'teacher',
        userId: args['userId'] as String? ?? '',
        userName: args['userName'] as String? ?? 'Teacher',
      );
    },
    feePaymentReceipt: (context) => FeePaymentReceiptScreen(),
    principalAnalytics: (context) => PrincipalAnalyticsScreen(),
  };

  static Widget buildRoutePage(
    BuildContext context, {
    required String routeName,
    Widget? child,
    WidgetBuilder? routeBuilder,
  }) {
    final metadata = SchoolDeskScreenRegistry.byRoute(routeName);
    final routeChild = _buildRouteChild(
      context,
      metadata: metadata,
      child: child,
      routeBuilder: routeBuilder,
    );
    if (metadata == null) return routeChild;
    return SchoolDeskRouteFrame(metadata: metadata, child: routeChild);
  }

  static Widget _buildRouteChild(
    BuildContext context, {
    required SchoolDeskScreenMetadata? metadata,
    required Widget? child,
    required WidgetBuilder? routeBuilder,
  }) {
    // Temporary UI-only switch: keep unfinished role route registrations hidden,
    // while allowing the implemented principal, parent, and shared workflows.
    if (blankRoleModuleScreens &&
        metadata != null &&
        !metadata.isPublic &&
        !metadata.isShared &&
        !_roleWorkflowVisibleRoutes.contains(metadata.route)) {
      return const BlankRoleModuleScreen();
    }

    if (child != null) return child;
    if (routeBuilder != null) return routeBuilder(context);
    return const SizedBox.shrink();
  }

  static const Set<String> _roleWorkflowVisibleRoutes = {
    principalDashboard,
    guidedAssistant,
    principalSchoolProfile,
    principalUserManagement,
    guardianDirectory,
    principalClasses,
    principalAttendance,
    principalSubjects,
    principalTimetable,
    principalExams,
    principalResults,
    principalAccountCreate,
    principalAccountEdit,
    principalParentChildAssignment,
    academicManagement,
    timetableManagement,
    syllabusMonitoring,
    examsResults,
    reportsAnalytics,
    staffManagement,
    staffForm,
    studentOversight,
    approvalCenter,
    principalInbox,
    feeMonitoring,
    communicationCenter,
    principalChatCommunications,
    complaintManagement,
    eventsCalendar,
    principalAcademicInfo,
    parentDashboard,
    parentAcademicProgress,
    parentAttendance,
    parentHomework,
    parentHomeworkSubmit,
    parentNotices,
    parentTeacherChat,
    parentFees,
    parentPaymentRequestForm,
    feePaymentReceipt,
    parentLeave,
    parentLeaveRequestForm,
    parentCalendar,
    parentDocuments,
    parentDiary,
    parentAcademicInfo,
    adminDashboard,
    adminStudents,
    adminTeachers,
    adminAttendance,
    adminFees,
    adminFeeStructureForm,
    adminInvoiceGenerationForm,
    adminPaymentRecordForm,
    adminPaymentRequests,
    adminPaymentRequestDecision,
    adminTimetable,
    adminTimetableGenerationForm,
    adminTimetablePeriodForm,
    adminTimetableSubstitutionForm,
    adminExams,
    adminExamForm,
    adminExamScheduleForm,
    adminCommunication,
    adminHelpdesk,
    adminDocuments,
    adminUserAccess,
    adminAccountCreate,
    adminAccountEdit,
    adminParentChildAssignment,
    adminReports,
    adminAcademicInfo,
    idCardGeneration,
    reportCardGenerator,
    teacherDashboard,
    teacherClasses,
    teacherAttendance,
    teacherMyAttendance,
    teacherHomework,
    teacherHomeworkForm,
    teacherHomeworkSubmissions,
    teacherPerformance,
    teacherStudentNotes,
    teacherCommunication,
    teacherParentInteraction,
    teacherLeave,
    teacherLeaveRequestForm,
    teacherDiscipline,
    teacherReports,
    teacherDiary,
    teacherAcademicInfo,
    principalAnalytics,
    notificationCenter,
    settingsScreen,
    profileScreen,
    globalSearch,
  };

  static AccountAccessFormArgs _accountFormArgs(
    BuildContext context,
    String fallbackOwnerRole,
  ) {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is AccountAccessFormArgs) return args;
    return AccountAccessFormArgs(ownerRole: fallbackOwnerRole);
  }

  static AccountChildAssignmentArgs _childAssignmentArgs(
    BuildContext context,
    String fallbackOwnerRole,
  ) {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is AccountChildAssignmentArgs) return args;
    return AccountChildAssignmentArgs(
      ownerRole: fallbackOwnerRole,
      parentUserId: '',
      parentName: 'Parent',
      parentEmail: '',
    );
  }

  static StaffFormArgs _staffFormArgs(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is StaffFormArgs) return args;
    return const StaffFormArgs(ownerRole: 'principal');
  }

  static AcademicYearFormArgs _academicYearFormArgs(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is AcademicYearFormArgs) return args;
    return const AcademicYearFormArgs(ownerRole: 'admin');
  }

  static AcademicSubjectFormArgs _academicSubjectFormArgs(
    BuildContext context,
  ) {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is AcademicSubjectFormArgs) return args;
    return const AcademicSubjectFormArgs(ownerRole: 'admin');
  }

  static AcademicClassFormArgs _academicClassFormArgs(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is AcademicClassFormArgs) return args;
    return const AcademicClassFormArgs(ownerRole: 'admin', staff: []);
  }

  static AcademicCurriculumFormArgs _academicCurriculumFormArgs(
    BuildContext context,
  ) {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is AcademicCurriculumFormArgs) return args;
    return const AcademicCurriculumFormArgs(
      ownerRole: 'admin',
      classes: [],
      subjects: [],
    );
  }

  static ParentLeaveRequestFormArgs _parentLeaveFormArgs(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is ParentLeaveRequestFormArgs) return args;
    return const ParentLeaveRequestFormArgs(children: [], initialStudentId: '');
  }

  static TeacherHomeworkFormArgs _teacherHomeworkFormArgs(
    BuildContext context,
  ) {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is TeacherHomeworkFormArgs) return args;
    return const TeacherHomeworkFormArgs(
      teacherStaffId: '',
      defaultClassName: 'Not assigned',
      defaultSubject: 'General',
      assignedClasses: [],
      students: [],
    );
  }

  static TeacherHomeworkSubmissionsArgs _teacherHomeworkSubmissionsArgs(
    BuildContext context,
  ) {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is TeacherHomeworkSubmissionsArgs) return args;
    return const TeacherHomeworkSubmissionsArgs(homework: {});
  }

  static ParentHomeworkSubmissionArgs _parentHomeworkSubmissionArgs(
    BuildContext context,
  ) {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is ParentHomeworkSubmissionArgs) return args;
    return const ParentHomeworkSubmissionArgs(
      homework: {},
      studentId: '',
      studentName: 'Student',
    );
  }

  static TeacherLeaveRequestFormArgs _teacherLeaveFormArgs(
    BuildContext context,
  ) {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is TeacherLeaveRequestFormArgs) return args;
    return const TeacherLeaveRequestFormArgs(
      staffId: '',
      staffName: '',
      leaveTypes: [],
      balances: [],
    );
  }

  static ParentPaymentRequestFormArgs _parentPaymentFormArgs(
    BuildContext context,
  ) {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is ParentPaymentRequestFormArgs) return args;
    return const ParentPaymentRequestFormArgs(fees: []);
  }

  static AdminFeeStructureFormArgs _adminFeeStructureFormArgs(
    BuildContext context,
  ) {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is AdminFeeStructureFormArgs) return args;
    return const AdminFeeStructureFormArgs(
      academicYears: [],
      grades: [],
      feeCategories: [],
    );
  }

  static AdminInvoiceGenerationFormArgs _adminInvoiceGenerationFormArgs(
    BuildContext context,
  ) {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is AdminInvoiceGenerationFormArgs) return args;
    return const AdminInvoiceGenerationFormArgs(
      academicYears: [],
      grades: [],
      sections: [],
      students: [],
      feeStructures: [],
    );
  }

  static AdminPaymentRecordFormArgs _adminPaymentRecordFormArgs(
    BuildContext context,
  ) {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is AdminPaymentRecordFormArgs) return args;
    return const AdminPaymentRecordFormArgs(pendingDues: []);
  }

  static AdminPaymentRequestDecisionArgs _adminPaymentRequestDecisionArgs(
    BuildContext context,
  ) {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is AdminPaymentRequestDecisionArgs) return args;
    return const AdminPaymentRequestDecisionArgs(request: {});
  }

  static AdminTimetableGenerationFormArgs _adminTimetableGenerationFormArgs(
    BuildContext context,
  ) {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is AdminTimetableGenerationFormArgs) return args;
    return const AdminTimetableGenerationFormArgs(
      classLabel: '',
      section: null,
      academicYear: null,
      termId: '',
      dayLabel: 'Monday',
      dayNumber: 1,
    );
  }

  static AdminTimetablePeriodFormArgs _adminTimetablePeriodFormArgs(
    BuildContext context,
  ) {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is AdminTimetablePeriodFormArgs) return args;
    return const AdminTimetablePeriodFormArgs(
      classLabel: '',
      section: null,
      academicYear: null,
      termId: '',
      dayLabel: 'Monday',
      dayNumber: 1,
      nextPeriodNumber: 1,
      subjects: [],
      staff: [],
      rooms: [],
    );
  }

  static AdminTimetableSubstitutionFormArgs _adminTimetableSubstitutionFormArgs(
    BuildContext context,
  ) {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is AdminTimetableSubstitutionFormArgs) return args;
    return const AdminTimetableSubstitutionFormArgs(
      classLabel: '',
      dayLabel: 'Monday',
      periods: [],
      staff: [],
    );
  }

  static AdminExamFormArgs _adminExamFormArgs(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is AdminExamFormArgs) return args;
    return const AdminExamFormArgs(academicYears: [], examTypes: []);
  }

  static AdminExamScheduleFormArgs _adminExamScheduleFormArgs(
    BuildContext context,
  ) {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is AdminExamScheduleFormArgs) return args;
    return const AdminExamScheduleFormArgs(
      exams: [],
      grades: [],
      sections: [],
      subjects: [],
    );
  }
}
