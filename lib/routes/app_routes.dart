import 'package:flutter/material.dart';

import 'package:schooldesk1/features/academics/academics.dart';
import 'package:schooldesk1/features/attendance/attendance.dart';
import 'package:schooldesk1/features/communication/communication.dart';
import 'package:schooldesk1/features/dashboard/dashboard.dart';
import 'package:schooldesk1/features/documents/documents.dart';
import 'package:schooldesk1/features/finance/finance.dart';
import 'package:schooldesk1/features/health/presentation/screens/parent_health_update_screen/parent_health_update_screen.dart';
import 'package:schooldesk1/features/auth/auth.dart';
import 'package:schooldesk1/features/auth/presentation/screens/demo_role_selector_screen.dart';
import 'package:schooldesk1/features/reports/reports.dart';
import 'package:schooldesk1/features/people/people.dart';
import 'package:schooldesk1/features/calendar/calendar.dart';
import 'package:schooldesk1/features/shell/shell.dart';
import 'package:schooldesk1/features/homework/homework.dart';
import 'package:schooldesk1/features/leave/leave.dart';
import 'package:schooldesk1/features/profile/profile.dart';
import 'package:schooldesk1/core/navigation/role_nav_indices.dart';
import 'package:schooldesk1/core/widgets/app_navigation.dart';
import 'package:schooldesk1/core/widgets/schooldesk_route_frame.dart';
import 'package:schooldesk1/routes/schooldesk_screen_registry.dart';
import 'package:schooldesk1/features/communication/presentation/screens/event_post_screen.dart';
import 'package:schooldesk1/features/shared/presentation/screens/school_gallery_screen.dart';
import 'package:schooldesk1/features/communication/presentation/screens/principal_event_approval_screen.dart';
import 'package:schooldesk1/features/monitoring/presentation/screens/principal_audit_logs_screen.dart';
import 'package:schooldesk1/features/monitoring/presentation/screens/system_monitor_screen.dart';
import 'package:schooldesk1/features/dashboard/presentation/screens/super_admin_dashboard_screen/super_admin_dashboard_screen.dart';
import 'package:schooldesk1/features/shared/presentation/screens/help_screen/help_screen.dart';
import 'package:schooldesk1/features/communication/presentation/screens/issue_screen.dart';

class AppRoutes {
  static const String initial = '/';
  static const String landingPage = '/landing-page-screen';
  static const String onboarding = '/onboarding-screen';

  // Loading
  static const String loginLoading = '/login-loading-screen';
  static const String demoRoleSelector = '/demo-role-selector-screen';

  // Principal Module Routes
  static const String principalLogin = '/principal-login-screen';
  static const String principalDashboard = '/principal-dashboard-screen';
  static const String coordinatorDashboard = '/coordinator-dashboard-screen';
  static const String staffManagement = '/staff-management-screen';
  static const String staffForm = '/staff-management-screen/form';
  static const String studentOversight = '/student-oversight-screen';
  static const String approvalCenter = '/approval-center-screen';
  static const String feeMonitoring = '/fee-monitoring-screen';
  static const String feeHome = '/fee-home-screen';
  static const String feeStructures = '/fee-structures-screen';
  static const String feeCollect = '/fee-collect-screen';
  static const String feeLedger = '/fee-ledger-screen';
  static const String feeReports = '/fee-reports-screen';
  static const String feePaymentConfig = '/fee-payment-config-screen';
  static const String principalPaymentRequests =
      '/principal-fees-screen/payment-requests';
  static const String principalPaymentRequestDecision =
      '/principal-fees-screen/payment-request-decision';
  static const String principalFeeStructureForm =
      '/principal-fees-screen/fee-structure';
  static const String principalInvoiceGenerationForm =
      '/principal-fees-screen/invoice-generation';
  static const String principalPaymentRecordForm =
      '/principal-fees-screen/payment-record';
  static const String communicationCenter = '/communication-center-screen';
  static const String principalChatCommunications =
      '/principal-chat-communications-screen';
  static const String complaintManagement = '/complaint-management-screen';
  static const String eventsCalendar = '/events-calendar-screen';
  static const String reportsAnalytics = '/reports-analytics-screen';
  static const String academicManagement = '/academic-management-screen';
  static const String academicYearDetail =
      '/academic-management-screen/year/detail';
  static const String academicYearClasswiseExport =
      '/academic-management-screen/year/classwise-export';
  static const String academicYearUsersExport =
      '/academic-management-screen/year/users-export';
  static const String academicYearFeesExport =
      '/academic-management-screen/year/fees-export';
  static const String academicYearForm = '/academic-management-screen/year';
  static const String academicSubjectForm =
      '/academic-management-screen/subject';
  static const String academicClassForm = '/academic-management-screen/class';
  static const String academicCurriculumForm =
      '/academic-management-screen/curriculum';
  static const String principalAcademicInfo = '/principal-academic-info-screen';
  static const String principalAnalytics = '/principal-analytics-screen';
  static const String principalUserManagement =
      '/principal-user-management-screen';
  static const String guardianDirectory = '/guardian-directory-screen';
  static const String principalClasses = '/principal-classes-screen';
  static const String principalAttendance = '/principal-attendance-screen';
  static const String principalSubjects = '/principal-subjects-screen';
  static const String principalLessonPlanner =
      '/principal-lesson-planner-screen';
  static const String principalAccountCreate =
      '/principal-user-management-screen/create';
  static const String principalAccountEdit =
      '/principal-user-management-screen/edit';
  static const String principalParentChildAssignment =
      '/principal-user-management-screen/assign-children';
  static const String principalSchoolProfile =
      '/principal-school-profile-screen';
  static const String principalEventApprovals =
      '/principal-event-approvals-screen';
  static const String principalEventPosts = '/principal-event-posts-screen';
  static const String principalTimetable = '/principal-timetable-screen';
  static const String principalDocuments = '/principal-documents-screen';
  static const String principalAuditLogs = '/principal-audit-logs-screen';
  static const String systemMonitor = '/system-monitor-screen';

  static const String idCardGeneration = '/id-card-generation-screen';

  // Super Admin Module Routes
  static const String superAdminDashboard = '/super-admin-dashboard-screen';
  static const String superAdminAuditLogs = '/super-admin-audit-logs-screen';
  static const String superAdminSystemMonitor =
      '/super-admin-system-monitor-screen';
  static const String superAdminAccess = '/super-admin-access-screen';
  static const String superAdminIssues = '/super-admin-issues-screen';

  // Teacher Module Routes
  static const String teacherLogin = '/teacher-login-screen';
  static const String teacherDashboard = '/teacher-dashboard-screen';
  static const String teacherClasses = '/teacher-classes-screen';
  static const String teacherTimetable = '/teacher-timetable-screen';
  static const String teacherAttendance = '/teacher-attendance-screen';
  static const String teacherAttendanceHistory =
      '/teacher-attendance-history-screen';
  static const String teacherMyAttendance = '/teacher-my-attendance-screen';
  static const String teacherCommunication = '/teacher-communication-screen';
  static const String teacherComplaints = '/teacher-complaints-screen';
  static const String teacherParentInteraction =
      '/teacher-parent-interaction-screen';
  static const String teacherLeave = '/teacher-leave-screen';
  static const String teacherLeaveRequestForm = '/teacher-leave-screen/request';
  static const String teacherHomework = '/teacher-homework-screen';
  static const String teacherHomeworkForm = '/teacher-homework-screen/form';
  static const String teacherHomeworkSubmissions =
      '/teacher-homework-screen/submissions';
  static const String teacherEventPosts = '/teacher-event-posts-screen';
  static const String teacherLessonPlanner = '/teacher-lesson-planner-screen';
  static const String teacherStudentNotes = '/teacher-student-notes-screen';
  static const String teacherDocuments = '/teacher-documents-screen';

  // Parent Module Routes
  static const String parentLogin = '/parent-login-screen';
  static const String kioskLogin = '/kiosk-login-screen';
  static const String kioskQrAttendance = '/kiosk-qr-attendance-screen';
  static const String parentDashboard = '/parent-dashboard-screen';
  static const String parentAttendance = '/parent-attendance-screen';
  static const String parentHomework = '/parent-homework-screen';
  static const String parentHomeworkSubmit = '/parent-homework-screen/submit';
  static const String parentTeacherChat = '/parent-teacher-chat-screen';
  static const String parentComplaints = '/parent-complaints-screen';
  static const String parentFees = '/parent-fees-screen';
  static const String parentPaymentRequestForm = '/parent-fees-screen/payment';

  // Legacy short-form fee route aliases — registered alongside the primary routes
  // above. These constants exist solely to give the route guard type-safe keys;
  // never navigate to them directly. Use the primary constants instead.
  static const String legacyParentFees = '/parent/fees';
  static const String legacyPrincipalPaymentRequests =
      '/principal/payment-requests';
  static const String legacyPrincipalFeeStructures =
      '/principal/fee-structures';
  static const String legacyPrincipalInvoiceGenerate =
      '/principal/invoice-generate';
  static const String legacyPrincipalCollectFee = '/principal/collect-fee';
  static const String legacyPrincipalFeeReports = '/principal/fee-reports';
  static const String legacyPrincipalPaymentConfig =
      '/principal/payment-config';
  static const String parentPaymentSelection =
      '/parent-fees-screen/payment-selection';
  static const String parentPaymentFlow = '/parent/payment-flow';
  static const String parentPaymentHistory = '/parent/payment-history';
  static const String parentReceipt = '/parent/receipt';
  static const String principalFees = '/principal/fees';
  static const String principalFeeConcessions = '/principal/fee-concessions';
  static const String parentLeave = '/parent-leave-screen';
  static const String parentLeaveRequestForm = '/parent-leave-screen/request';
  static const String parentCalendar = '/parent-calendar-screen';
  static const String teacherCalendar = '/teacher-calendar-screen';
  static const String parentDocuments = '/parent-documents-screen';
  static const String parentTimetable = '/parent-timetable-screen';
  static const String parentPTMBooking = '/parent-ptm-booking-screen';
  static const String parentHealth = '/parent-health-screen';
  static const String parentLessonPlanner = '/parent-lesson-planner-screen';

  // Shared Routes
  static const String schoolGallery = '/school-gallery-screen';
  static const String notificationCenter = '/notification-center-screen';
  static const String settingsScreen = '/settings-screen';
  static const String profileScreen = '/profile-screen';
  static const String globalSearch = '/global-search-screen';
  static const String homeworkMessaging = '/homework-messaging-screen';
  static const String help = '/help-screen';

  static Map<String, WidgetBuilder> routes = {
    initial: (context) => const LandingPageScreen(),
    landingPage: (context) => const LandingPageScreen(),
    onboarding: (context) => const OnboardingScreen(),

    // Principal
    loginLoading: (context) => const LoginLoadingScreen(),
    demoRoleSelector: (context) => const DemoRoleSelectorScreen(),
    principalLogin: (context) => const AuthLoginScreen(),
    principalDashboard: (context) => const PrincipalDashboardScreen(),
    coordinatorDashboard: (context) => const PrincipalDashboardScreen(),
    principalSchoolProfile: (context) => const SchoolProfileScreen(),
    staffManagement: (context) => const StaffManagementScreen(),
    staffForm: (context) => StaffFormScreen(args: _staffFormArgs(context)),
    studentOversight: (context) => const StudentOversightScreen(),
    approvalCenter: (context) => ApprovalCenterScreen(
      args: ApprovalCenterRouteArgs.fromRoute(
        ModalRoute.of(context)?.settings.arguments,
      ),
    ),
    // One operational entry point prevents the older metrics-heavy dashboard
    // and the daily collection flow from competing with each other.
    feeMonitoring: (context) => const FeeHomeScreen(),
    feeHome: (context) => const FeeHomeScreen(),
    principalFees: (context) => const FeeHomeScreen(),
    principalFeeConcessions: (context) => const AdminFeesScreen(
      initialSection: 'concessions',
      concessionOnly: true,
    ),
    feeStructures: (context) => const PrincipalFeeStructures(),
    '/principal/fee-structures': (context) => const PrincipalFeeStructures(),
    feeCollect: (context) => const PrincipalCollectFee(),
    '/principal/collect-fee': (context) => const PrincipalCollectFee(),
    feeLedger: (context) => const FeeLedgerScreen(),
    feeReports: (context) => const PrincipalReports(),
    '/principal/fee-reports': (context) => const PrincipalReports(),
    feePaymentConfig: (context) => const PrincipalPaymentConfig(),
    '/principal/payment-config': (context) => const PrincipalPaymentConfig(),
    principalPaymentRequests: (context) => const PrincipalPaymentRequests(),
    '/principal/payment-requests': (context) =>
        const PrincipalPaymentRequests(),
    principalPaymentRequestDecision: (context) =>
        AdminPaymentRequestDecisionScreen(
          args: _principalPaymentRequestDecisionArgs(context),
        ),
    principalFeeStructureForm: (context) => AdminFeeStructureFormScreen(
      args: _principalFeeStructureFormArgs(context),
    ),
    principalInvoiceGenerationForm: (context) => PrincipalInvoiceGenerate(
      args: _principalInvoiceGenerationFormArgs(context),
    ),
    '/principal/invoice-generate': (context) => PrincipalInvoiceGenerate(
      args: _principalInvoiceGenerationFormArgs(context),
    ),
    principalPaymentRecordForm: (context) => AdminPaymentRecordFormScreen(
      args: _principalPaymentRecordFormArgs(context),
    ),
    communicationCenter: (context) => const PrincipalChatCommunicationsScreen(),
    principalChatCommunications: (context) =>
        const PrincipalChatCommunicationsScreen(),
    complaintManagement: (context) =>
        const IssueScreen(role: IssueScreenRole.principal),
    eventsCalendar: (context) => const EventsCalendarScreen(),
    reportsAnalytics: (context) => const ReportsAnalyticsScreen(),
    academicManagement: (context) => const PrincipalAcademicYearsScreen(),
    academicYearDetail: (context) => PrincipalAcademicYearDetailScreen(
      args: _academicYearRouteArgs(context),
    ),
    academicYearClasswiseExport: (context) => AcademicYearClasswiseExportScreen(
      args: _academicYearRouteArgs(context),
    ),
    academicYearUsersExport: (context) =>
        AcademicYearUsersExportScreen(args: _academicYearRouteArgs(context)),
    academicYearFeesExport: (context) =>
        AcademicYearFeesExportScreen(args: _academicYearRouteArgs(context)),
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
      drawer: PrincipalDrawer(
        selectedIndex: PrincipalNav.academics,
        onDestinationSelected: (_) {},
      ),
      drawerIndex: PrincipalNav.academics,
    ),
    principalUserManagement: (context) =>
        const AdminUserAccessScreen(ownerRole: 'principal'),
    guardianDirectory: (context) =>
        const GuardianDirectoryScreen(ownerRole: 'principal'),
    principalClasses: (context) => const PrincipalClassesScreen(),
    principalAttendance: (context) => const PrincipalAttendanceScreen(),
    principalSubjects: (context) => const PrincipalSubjectsScreen(),
    principalLessonPlanner: (context) => const PrincipalLessonPlannerScreen(),
    principalAccountCreate: (context) =>
        AccountAccessFormScreen(args: _accountFormArgs(context, 'principal')),
    principalAccountEdit: (context) =>
        AccountAccessFormScreen(args: _accountFormArgs(context, 'principal')),
    principalParentChildAssignment: (context) => AccountChildAssignmentScreen(
      args: _childAssignmentArgs(context, 'principal'),
    ),
    principalEventApprovals: (context) => PrincipalEventApprovalScreen(
      args: EventApprovalRouteArgs.fromRoute(
        ModalRoute.of(context)?.settings.arguments,
      ),
    ),
    principalEventPosts: (context) =>
        const TeacherEventPostScreen(principalMode: true),
    principalTimetable: (context) => const AdminTimetableScreen(),
    principalDocuments: (context) => const AdminDocumentsScreen(),
    principalAuditLogs: (context) => const PrincipalAuditLogsScreen(),
    principalAnalytics: (context) => const PrincipalAnalyticsScreen(),
    systemMonitor: (context) => const SystemMonitorScreen(),

    idCardGeneration: (context) => const IdCardGenerationScreen(),

    // Super Admin
    superAdminDashboard: (context) => const SuperAdminDashboardScreen(),
    superAdminAuditLogs: (context) => const PrincipalAuditLogsScreen(),
    superAdminSystemMonitor: (context) => const SystemMonitorScreen(),
    superAdminAccess: (context) =>
        const AdminUserAccessScreen(ownerRole: 'super_admin'),
    superAdminIssues: (context) =>
        const IssueScreen(role: IssueScreenRole.superAdmin),

    // Teacher
    teacherLogin: (context) => const AuthLoginScreen(),
    teacherDashboard: (context) => const TeacherDashboardScreen(),
    teacherClasses: (context) => const TeacherClassesScreen(),
    teacherTimetable: (context) => const TeacherTimetableScreen(),
    teacherAttendance: (context) => const TeacherAttendanceScreen(),
    teacherAttendanceHistory: (context) =>
        const TeacherAttendanceHistoryScreen(),
    teacherMyAttendance: (context) => const TeacherMyAttendanceScreen(),
    teacherCommunication: (context) => const TeacherCommunicationScreen(),
    teacherComplaints: (context) =>
        const IssueScreen(role: IssueScreenRole.teacher),
    teacherParentInteraction: (context) =>
        const TeacherParentInteractionScreen(),
    teacherLeave: (context) => const TeacherLeaveScreen(),
    teacherLeaveRequestForm: (context) =>
        TeacherLeaveRequestFormScreen(args: _teacherLeaveFormArgs(context)),
    teacherHomework: (context) => const TeacherHomeworkScreen(),
    teacherHomeworkForm: (context) =>
        TeacherHomeworkFormScreen(args: _teacherHomeworkFormArgs(context)),
    teacherHomeworkSubmissions: (context) => TeacherHomeworkSubmissionsScreen(
      args: _teacherHomeworkSubmissionsArgs(context),
    ),
    teacherEventPosts: (context) => const TeacherEventPostScreen(),
    teacherLessonPlanner: (context) => const TeacherLessonPlannerScreen(),
    teacherStudentNotes: (context) => const TeacherStudentNotesScreen(),
    teacherDocuments: (context) => const TeacherDocumentsScreen(),
    teacherCalendar: (context) =>
        const EventsCalendarScreen(portal: SchoolCalendarPortal.teacher),

    // Parent
    parentLogin: (context) => const AuthLoginScreen(),
    kioskLogin: (context) => const AuthLoginScreen(),
    kioskQrAttendance: (context) => const KioskQrAttendanceScreen(),
    parentDashboard: (context) => const ParentDashboardScreen(),
    parentAttendance: (context) => const ParentAttendanceScreen(),
    parentHomework: (context) => const ParentHomeworkScreen(),
    parentHomeworkSubmit: (context) => ParentHomeworkSubmissionScreen(
      args: _parentHomeworkSubmissionArgs(context),
    ),
    parentTeacherChat: (context) => const ParentTeacherChatScreen(),
    parentComplaints: (context) =>
        const IssueScreen(role: IssueScreenRole.parent),
    parentFees: (context) => const ParentFeeHub(),
    '/parent/fees': (context) => const ParentFeeHub(),
    parentPaymentRequestForm: (context) =>
        ParentPaymentFlow(args: _parentPaymentSelectionArgs(context)),
    parentPaymentSelection: (context) =>
        ParentPaymentFlow(args: _parentPaymentSelectionArgs(context)),
    parentPaymentFlow: (context) =>
        ParentPaymentFlow(args: _parentPaymentSelectionArgs(context)),
    parentPaymentHistory: (context) => const ParentPaymentHistoryV2(),
    parentReceipt: (context) =>
        ParentReceiptViewV2(args: _parentPaymentSelectionArgs(context)),
    parentLeave: (context) => const ParentLeaveScreen(),
    parentLeaveRequestForm: (context) =>
        ParentLeaveRequestFormScreen(args: _parentLeaveFormArgs(context)),
    parentCalendar: (context) =>
        const EventsCalendarScreen(portal: SchoolCalendarPortal.parent),
    parentDocuments: (context) => const ParentDocumentsScreen(),
    parentTimetable: (context) => const ParentTimetableScreen(),
    parentPTMBooking: (context) => const ParentPTMBookingScreen(),
    parentHealth: (context) => const ParentHealthUpdateScreen(),
    parentLessonPlanner: (context) => const ParentLessonPlannerScreen(),

    // Shared
    schoolGallery: (context) => const SchoolGalleryScreen(),
    notificationCenter: (context) {
      final role =
          ModalRoute.of(context)?.settings.arguments as String? ?? 'principal';
      return NotificationCenterScreen(role: role);
    },
    settingsScreen: (context) {
      final role =
          ModalRoute.of(context)?.settings.arguments as String? ?? 'principal';
      return AppSettingsScreen(role: role);
    },
    profileScreen: (context) {
      final role =
          ModalRoute.of(context)?.settings.arguments as String? ?? 'principal';
      return ProfileManagementScreen(role: role);
    },
    globalSearch: (context) => const GlobalSearchScreen(),
    help: (context) => const HelpScreen(),
    homeworkMessaging: (context) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ??
          {};
      final role = (args['role'] as String? ?? 'teacher').toLowerCase();
      switch (role) {
        case 'parent':
          return const ParentTeacherChatScreen();
        case 'principal':
        case 'coordinator':
        case 'admin':
          return const PrincipalChatCommunicationsScreen();
        case 'teacher':
        default:
          return const TeacherCommunicationScreen();
      }
    },
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
      routeName: routeName,
      metadata: metadata,
      child: child,
      routeBuilder: routeBuilder,
    );
    if (metadata == null) return routeChild;
    return SchoolDeskRouteFrame(metadata: metadata, child: routeChild);
  }

  static Widget _buildRouteChild(
    BuildContext context, {
    required String routeName,
    required SchoolDeskScreenMetadata? metadata,
    required Widget? child,
    required WidgetBuilder? routeBuilder,
  }) {
    if (child != null) return child;
    if (routeBuilder != null) return routeBuilder(context);
    throw StateError(
      'Route "$routeName" was requested without a screen or route builder.',
    );
  }

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
    return const AcademicYearFormArgs(ownerRole: 'principal');
  }

  static AcademicYearRouteArgs _academicYearRouteArgs(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is AcademicYearRouteArgs) return args;
    return const AcademicYearRouteArgs(year: <String, dynamic>{});
  }

  static AcademicSubjectFormArgs _academicSubjectFormArgs(
    BuildContext context,
  ) {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is AcademicSubjectFormArgs) return args;
    return const AcademicSubjectFormArgs(ownerRole: 'principal');
  }

  static AcademicClassFormArgs _academicClassFormArgs(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is AcademicClassFormArgs) return args;
    return const AcademicClassFormArgs(ownerRole: 'principal', staff: []);
  }

  static AcademicCurriculumFormArgs _academicCurriculumFormArgs(
    BuildContext context,
  ) {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is AcademicCurriculumFormArgs) return args;
    return const AcademicCurriculumFormArgs(
      ownerRole: 'principal',
      classes: [],
      subjects: [],
    );
  }

  static ParentLeaveRequestFormArgs _parentLeaveFormArgs(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is ParentLeaveRequestFormArgs) return args;
    return const ParentLeaveRequestFormArgs(children: [], initialStudentId: '');
  }

  static ParentHomeworkSubmissionArgs _parentHomeworkSubmissionArgs(
    BuildContext context,
  ) {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is ParentHomeworkSubmissionArgs) return args;
    // Handle Map args — e.g. when navigated from a notification
    if (args is Map) {
      final argMap = Map<String, dynamic>.from(args);
      // The notification resolver passes {'homework': {'homework_id': id}, ...}
      final hwRaw = argMap['homework'];
      final hw = hwRaw is Map
          ? Map<String, dynamic>.from(hwRaw)
          : <String, dynamic>{};
      // Merge top-level keys into hw if homework_id is missing
      if (hw['homework_id'] == null || hw['homework_id'].toString().isEmpty) {
        final rid = argMap['reference_id'] ?? argMap['id'];
        if (rid != null) {
          hw['homework_id'] = rid;
          hw['id'] = rid;
        }
      }
      return ParentHomeworkSubmissionArgs(
        homework: hw,
        studentId: argMap['student_id']?.toString() ?? '',
        studentName: argMap['student_name']?.toString() ?? 'Student',
      );
    }
    return const ParentHomeworkSubmissionArgs(
      homework: {},
      studentId: '',
      studentName: 'Student',
    );
  }

  static TeacherHomeworkFormArgs _teacherHomeworkFormArgs(
    BuildContext context,
  ) {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is TeacherHomeworkFormArgs) return args;
    return const TeacherHomeworkFormArgs(
      teacherStaffId: '',
      defaultClassName: '',
      defaultSubject: '',
      assignedClasses: [],
      students: [],
    );
  }

  static TeacherHomeworkSubmissionsArgs _teacherHomeworkSubmissionsArgs(
    BuildContext context,
  ) {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is TeacherHomeworkSubmissionsArgs) return args;
    if (args is Map<String, dynamic>) {
      return TeacherHomeworkSubmissionsArgs(homework: args);
    }
    return const TeacherHomeworkSubmissionsArgs(homework: {});
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

  static ParentPaymentSelectionArgs _parentPaymentSelectionArgs(
    BuildContext context,
  ) {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is ParentPaymentSelectionArgs) return args;
    if (args is Map<String, dynamic>) {
      return ParentPaymentSelectionArgs(
        fees:
            (args['fees'] as List?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            [],
        student: args['student'] as Map<String, dynamic>?,
        paymentRequest: args['payment_request'] is Map
            ? Map<String, dynamic>.from(args['payment_request'] as Map)
            : null,
      );
    }
    return const ParentPaymentSelectionArgs(fees: []);
  }

  static AdminPaymentRequestDecisionArgs _principalPaymentRequestDecisionArgs(
    BuildContext context,
  ) {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is AdminPaymentRequestDecisionArgs) return args;
    if (args is Map<String, dynamic>) {
      return AdminPaymentRequestDecisionArgs(request: args);
    }
    return const AdminPaymentRequestDecisionArgs(request: <String, dynamic>{});
  }

  static AdminFeeStructureFormArgs _principalFeeStructureFormArgs(
    BuildContext context,
  ) {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is AdminFeeStructureFormArgs) return args;
    return const AdminFeeStructureFormArgs(
      academicYears: [],
      grades: [],
      sections: [],
      feeCategories: [],
      ownerRole: 'principal',
    );
  }

  static AdminInvoiceGenerationFormArgs _principalInvoiceGenerationFormArgs(
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
      ownerRole: 'principal',
    );
  }

  static AdminPaymentRecordFormArgs _principalPaymentRecordFormArgs(
    BuildContext context,
  ) {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is AdminPaymentRecordFormArgs) return args;
    return const AdminPaymentRecordFormArgs(
      pendingDues: [],
      ownerRole: 'principal',
    );
  }
}

class ParentPaymentSelectionArgs {
  final List<Map<String, dynamic>> fees;
  final Map<String, dynamic>? student;
  final Map<String, dynamic>? paymentRequest;
  const ParentPaymentSelectionArgs({
    required this.fees,
    this.student,
    this.paymentRequest,
  });
}
