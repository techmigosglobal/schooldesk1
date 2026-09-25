import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:schooldesk1/app/router/typed_role_routes.dart';
import 'package:schooldesk1/core/auth/role_context.dart';
import 'package:schooldesk1/core/navigation/role_nav_indices.dart';
import 'package:schooldesk1/core/widgets/app_navigation.dart';
import 'package:schooldesk1/features/academics/academics.dart';
import 'package:schooldesk1/features/attendance/attendance.dart';
import 'package:schooldesk1/features/auth/auth.dart';
import 'package:schooldesk1/features/calendar/calendar.dart';
import 'package:schooldesk1/features/communication/communication.dart';
import 'package:schooldesk1/features/documents/documents.dart';
import 'package:schooldesk1/features/finance/finance.dart';
import 'package:schooldesk1/features/health/presentation/screens/parent_health_update_screen/parent_health_update_screen.dart';
import 'package:schooldesk1/features/homework/homework.dart';
import 'package:schooldesk1/features/leave/leave.dart';
import 'package:schooldesk1/features/people/people.dart';
import 'package:schooldesk1/features/profile/profile.dart';
import 'package:schooldesk1/features/reports/reports.dart';
import 'package:schooldesk1/features/shell/shell.dart';
import 'package:schooldesk1/features/communication/presentation/screens/event_post_screen.dart';
import 'package:schooldesk1/features/communication/presentation/screens/issue_screen.dart';
import 'package:schooldesk1/features/people/presentation/screens/admission_inquiries_screen.dart';
import 'package:schooldesk1/features/monitoring/presentation/screens/principal_audit_logs_screen.dart';
import 'package:schooldesk1/features/monitoring/presentation/screens/system_monitor_screen.dart';
import 'package:schooldesk1/shared/screens/help_screen/help_screen.dart';
import 'package:schooldesk1/shared/screens/school_gallery_screen.dart';
import 'package:schooldesk1/routes/app_routes.dart';

/// Marker for routes with no argument payload.
class NoRouteArgs {
  const NoRouteArgs();
}

typedef TypedRouteBuilder<T> =
    Widget Function(BuildContext context, GoRouterState state, T arguments);

typedef TypedRouteParser<T> = T Function(GoRouterState state);

/// One typed route contract. Each route owns its argument parser and screen
/// builder. No screen reads route arguments from Navigator settings.
abstract class TypedAppRouteBase {
  const TypedAppRouteBase({required this.path, required this.name});

  final String path;
  final String name;

  GoRoute toGoRoute();
}

class TypedAppRoute<T> extends TypedAppRouteBase {
  const TypedAppRoute({
    required super.path,
    required super.name,
    required this.parse,
    required this.build,
  });

  final TypedRouteParser<T> parse;
  final TypedRouteBuilder<T> build;

  @override
  GoRoute toGoRoute() {
    return GoRoute(
      path: path,
      name: name,
      builder: (context, state) => build(context, state, parse(state)),
    );
  }
}

/// Complete top-level route inventory. Compatibility aliases remain separate
/// paths, but all paths enter GoRouter through a typed route contract.
class TypedAppRouteRegistry {
  TypedAppRouteRegistry._();

  static List<TypedAppRouteBase> get all {
    final overrides = <String, TypedAppRouteBase>{
      AppRoutes.principalDashboard: _noArgs(
        AppRoutes.principalDashboard,
        'principal_dashboard',
        (context, state) =>
            const PrincipalDashboardRoute().build(context, state),
      ),
      AppRoutes.coordinatorDashboard: _noArgs(
        AppRoutes.coordinatorDashboard,
        'coordinator_dashboard',
        (context, state) =>
            const CoordinatorDashboardRoute().build(context, state),
      ),
      AppRoutes.teacherDashboard: _noArgs(
        AppRoutes.teacherDashboard,
        'teacher_dashboard',
        (context, state) => const TeacherDashboardRoute().build(context, state),
      ),
      AppRoutes.parentDashboard: _noArgs(
        AppRoutes.parentDashboard,
        'parent_dashboard',
        (context, state) => const ParentDashboardRoute().build(context, state),
      ),
      AppRoutes.kioskQrAttendance: _noArgs(
        AppRoutes.kioskQrAttendance,
        'kiosk_qr_attendance',
        (context, state) => const KioskAttendanceRoute().build(context, state),
      ),
      AppRoutes.superAdminDashboard: _noArgs(
        AppRoutes.superAdminDashboard,
        'super_admin_dashboard',
        (context, state) =>
            const SuperAdminDashboardRoute().build(context, state),
      ),
      AppRoutes.notificationCenter: _sharedRole(
        AppRoutes.notificationCenter,
        'notification_center',
        (role) => NotificationCenterScreen(role: role),
      ),
      AppRoutes.settingsScreen: _sharedRole(
        AppRoutes.settingsScreen,
        'settings',
        (role) => AppSettingsScreen(role: role),
      ),
      AppRoutes.profileScreen: _sharedRole(
        AppRoutes.profileScreen,
        'profile',
        (role) => ProfileManagementScreen(role: role),
      ),
      AppRoutes.homeworkMessaging: TypedAppRoute<SharedRoleRouteArgs>(
        path: AppRoutes.homeworkMessaging,
        name: 'homework_messaging',
        parse: _sharedRoleArgs,
        build: (context, state, args) =>
            _frame(context, AppRoutes.homeworkMessaging, switch (args.role) {
              SchoolDeskRole.parent => const ParentTeacherChatScreen(),
              SchoolDeskRole.principal ||
              SchoolDeskRole.coordinator ||
              SchoolDeskRole.superAdmin =>
                const PrincipalChatCommunicationsScreen(),
              _ => const TeacherCommunicationScreen(),
            }),
      ),
      AppRoutes.staffForm: _typed<StaffFormArgs>(
        AppRoutes.staffForm,
        _extraOr(const StaffFormArgs(ownerRole: 'principal')),
      ),
      AppRoutes.approvalCenter: _typed<ApprovalCenterRouteArgs>(
        AppRoutes.approvalCenter,
        _extraOr(const ApprovalCenterRouteArgs()),
      ),
      AppRoutes.principalPaymentRequestDecision:
          _typed<AdminPaymentRequestDecisionArgs>(
            AppRoutes.principalPaymentRequestDecision,
            _extraOr(
              const AdminPaymentRequestDecisionArgs(
                request: <String, dynamic>{},
              ),
            ),
          ),
      AppRoutes.principalFeeStructureForm: _typed<AdminFeeStructureFormArgs>(
        AppRoutes.principalFeeStructureForm,
        _extraOr(
          const AdminFeeStructureFormArgs(
            academicYears: [],
            grades: [],
            sections: [],
            feeCategories: [],
            ownerRole: 'principal',
          ),
        ),
      ),
      AppRoutes.principalPaymentRecordForm: _typed<AdminPaymentRecordFormArgs>(
        AppRoutes.principalPaymentRecordForm,
        _extraOr(
          const AdminPaymentRecordFormArgs(
            pendingDues: [],
            ownerRole: 'principal',
          ),
        ),
      ),
      AppRoutes.academicYearDetail: _typed<AcademicYearRouteArgs>(
        AppRoutes.academicYearDetail,
        _extraOr(const AcademicYearRouteArgs(year: <String, dynamic>{})),
      ),
      AppRoutes.academicYearForm: _typed<AcademicYearFormArgs>(
        AppRoutes.academicYearForm,
        _extraOr(const AcademicYearFormArgs(ownerRole: 'principal')),
      ),
      AppRoutes.academicSubjectForm: _typed<AcademicSubjectFormArgs>(
        AppRoutes.academicSubjectForm,
        _extraOr(const AcademicSubjectFormArgs(ownerRole: 'principal')),
      ),
      AppRoutes.academicClassForm: _typed<AcademicClassFormArgs>(
        AppRoutes.academicClassForm,
        _extraOr(
          const AcademicClassFormArgs(ownerRole: 'principal', staff: []),
        ),
      ),
      AppRoutes.academicCurriculumForm: _typed<AcademicCurriculumFormArgs>(
        AppRoutes.academicCurriculumForm,
        _extraOr(
          const AcademicCurriculumFormArgs(
            ownerRole: 'principal',
            classes: [],
            subjects: [],
          ),
        ),
      ),
      AppRoutes.principalAccountCreate: _typed<AccountAccessFormArgs>(
        AppRoutes.principalAccountCreate,
        _extraOr(const AccountAccessFormArgs(ownerRole: 'principal')),
      ),
      AppRoutes.principalAccountEdit: _typed<AccountAccessFormArgs>(
        AppRoutes.principalAccountEdit,
        _extraOr(const AccountAccessFormArgs(ownerRole: 'principal')),
      ),
      AppRoutes.principalParentChildAssignment:
          _typed<AccountChildAssignmentArgs>(
            AppRoutes.principalParentChildAssignment,
            _extraOr(
              const AccountChildAssignmentArgs(
                ownerRole: 'principal',
                parentUserId: '',
                parentName: 'Parent',
                parentEmail: '',
              ),
            ),
          ),
      AppRoutes.principalEventApprovals: _typed<SchoolPostsRouteArgs>(
        AppRoutes.principalEventApprovals,
        _extraOr(const SchoolPostsRouteArgs(initialTab: 'review')),
      ),
      AppRoutes.principalEventPosts: _typed<SchoolPostsRouteArgs>(
        AppRoutes.principalEventPosts,
        _extraOr(const SchoolPostsRouteArgs()),
      ),
      AppRoutes.teacherLeaveRequestForm: _typed<TeacherLeaveRequestFormArgs>(
        AppRoutes.teacherLeaveRequestForm,
        _extraOr(
          const TeacherLeaveRequestFormArgs(
            staffId: '',
            staffName: '',
            leaveTypes: [],
            balances: [],
          ),
        ),
      ),
      AppRoutes.teacherHomeworkForm: _typed<TeacherHomeworkFormArgs>(
        AppRoutes.teacherHomeworkForm,
        _extraOr(
          const TeacherHomeworkFormArgs(
            teacherStaffId: '',
            defaultClassName: '',
            defaultSubject: '',
            assignedClasses: [],
            students: [],
          ),
        ),
      ),
      AppRoutes.teacherHomeworkSubmissions:
          _typed<TeacherHomeworkSubmissionsArgs>(
            AppRoutes.teacherHomeworkSubmissions,
            _extraOr(const TeacherHomeworkSubmissionsArgs(homework: {})),
          ),
      AppRoutes.parentHomeworkSubmit: _typed<ParentHomeworkSubmissionArgs>(
        AppRoutes.parentHomeworkSubmit,
        _extraOr(
          const ParentHomeworkSubmissionArgs(
            homework: {},
            studentId: '',
            studentName: 'Student',
          ),
        ),
      ),
      AppRoutes.parentLeaveRequestForm: _typed<ParentLeaveRequestFormArgs>(
        AppRoutes.parentLeaveRequestForm,
        _extraOr(
          const ParentLeaveRequestFormArgs(children: [], initialStudentId: ''),
        ),
      ),
      AppRoutes.parentPaymentRequestForm: _typed<ParentPaymentSelectionArgs>(
        AppRoutes.parentPaymentRequestForm,
        _extraOr(const ParentPaymentSelectionArgs(fees: [])),
      ),
      AppRoutes.parentPaymentSelection: _typed<ParentPaymentSelectionArgs>(
        AppRoutes.parentPaymentSelection,
        _extraOr(const ParentPaymentSelectionArgs(fees: [])),
      ),
      AppRoutes.parentPaymentFlow: _typed<ParentPaymentSelectionArgs>(
        AppRoutes.parentPaymentFlow,
        _extraOr(const ParentPaymentSelectionArgs(fees: [])),
      ),
      AppRoutes.parentReceipt: _typed<ParentPaymentSelectionArgs>(
        AppRoutes.parentReceipt,
        _extraOr(const ParentPaymentSelectionArgs(fees: [])),
      ),
      // Legacy deep-link aliases retain the exact same typed screen contracts
      // as their canonical routes until external notification links migrate.
      AppRoutes.legacyParentFees: _noArgs(
        AppRoutes.legacyParentFees,
        'parent_fees_legacy',
        (context, state) => const ParentFeeHub(),
      ),
      AppRoutes.legacyPrincipalPaymentRequests: _noArgs(
        AppRoutes.legacyPrincipalPaymentRequests,
        'principal_payment_requests_legacy',
        (context, state) => const PrincipalPaymentRequests(),
      ),
      AppRoutes.legacyPrincipalFeeStructures: _noArgs(
        AppRoutes.legacyPrincipalFeeStructures,
        'principal_fee_structures_legacy',
        (context, state) => const PrincipalFeeStructures(),
      ),
      AppRoutes.legacyPrincipalCollectFee: _noArgs(
        AppRoutes.legacyPrincipalCollectFee,
        'principal_collect_fee_legacy',
        (context, state) => const PrincipalCollectFee(),
      ),
      AppRoutes.legacyPrincipalPaymentConfig: _noArgs(
        AppRoutes.legacyPrincipalPaymentConfig,
        'principal_payment_config_legacy',
        (context, state) => const PrincipalPaymentConfig(),
      ),
    };

    return [
      for (final path in AppRoutes.routes.keys)
        overrides[path] ??
            _noArgs(path, _routeName(path), _requireNoArgScreen(path)),
    ];
  }

  static Widget Function(BuildContext, GoRouterState) _requireNoArgScreen(
    String path,
  ) {
    final builder = _noArgScreens[path];
    if (builder == null) {
      throw StateError('No typed screen registered for $path');
    }
    return builder;
  }

  /// Explicit screen inventory for routes without argument payloads. This
  /// keeps a legacy [WidgetBuilder] from silently becoming a GoRouter route.
  static final Map<String, Widget Function(BuildContext, GoRouterState)>
  _noArgScreens = {
    AppRoutes.initial: (_, __) => const LandingPageScreen(),
    AppRoutes.landingPage: (_, __) => const LandingPageScreen(),
    AppRoutes.loginLoading: (_, __) => const LoginLoadingScreen(),
    AppRoutes.principalLogin: (_, __) => const AuthLoginScreen(),
    AppRoutes.principalSchoolProfile: (_, __) => const SchoolProfileScreen(),
    AppRoutes.admissionInquiries: (_, __) => const AdmissionInquiriesScreen(),
    AppRoutes.staffManagement: (_, __) => const StaffManagementScreen(),
    AppRoutes.studentOversight: (_, __) => const StudentOversightScreen(),
    AppRoutes.feeMonitoring: (_, __) => const FeeHomeScreen(),
    AppRoutes.feeHome: (_, __) => const FeeHomeScreen(),
    AppRoutes.principalFees: (_, __) => const FeeHomeScreen(),
    AppRoutes.principalFeeConcessions: (_, __) => const AdminFeesScreen(
      initialSection: 'concessions',
      concessionOnly: true,
    ),
    AppRoutes.feeStructures: (_, __) => const PrincipalFeeStructures(),
    AppRoutes.feeCollect: (_, __) => const PrincipalCollectFee(),
    AppRoutes.feeLedger: (_, __) => const FeeLedgerScreen(),
    AppRoutes.feePaymentConfig: (_, __) => const PrincipalPaymentConfig(),
    AppRoutes.principalPaymentRequests: (_, __) =>
        const PrincipalPaymentRequests(),
    AppRoutes.communicationCenter: (_, __) =>
        const PrincipalChatCommunicationsScreen(),
    AppRoutes.principalChatCommunications: (_, __) =>
        const PrincipalChatCommunicationsScreen(),
    AppRoutes.complaintManagement: (_, __) =>
        const IssueScreen(role: IssueScreenRole.principal),
    AppRoutes.eventsCalendar: (_, __) => const EventsCalendarScreen(),
    AppRoutes.reportsAnalytics: (_, __) => const ReportsAnalyticsScreen(),
    AppRoutes.academicManagement: (_, __) =>
        const PrincipalAcademicYearsScreen(),
    AppRoutes.principalAcademicInfo: (_, __) => AcademicInfoScreen(
      role: 'principal',
      drawer: PrincipalDrawer(
        selectedIndex: PrincipalNav.academics,
        onDestinationSelected: (_) {},
      ),
      drawerIndex: PrincipalNav.academics,
    ),
    AppRoutes.principalUserManagement: (_, __) =>
        const AdminUserAccessScreen(ownerRole: 'principal'),
    AppRoutes.guardianDirectory: (_, __) =>
        const GuardianDirectoryScreen(ownerRole: 'principal'),
    AppRoutes.principalClasses: (_, __) => const PrincipalClassesScreen(),
    AppRoutes.principalAttendance: (_, __) => const PrincipalAttendanceScreen(),
    AppRoutes.principalSubjects: (_, __) => const PrincipalSubjectsScreen(),
    AppRoutes.principalLessonPlanner: (_, __) =>
        const PrincipalLessonPlannerScreen(),
    AppRoutes.principalTimetable: (_, __) => const AdminTimetableScreen(),
    AppRoutes.principalDocuments: (_, __) => const AdminDocumentsScreen(),
    AppRoutes.principalAuditLogs: (_, __) =>
        const PrincipalAuditLogsScreen(role: 'principal'),
    AppRoutes.principalAnalytics: (_, __) => const PrincipalAnalyticsScreen(),
    AppRoutes.systemMonitor: (_, __) =>
        const SystemMonitorScreen(role: 'principal'),
    AppRoutes.idCardGeneration: (_, __) => const IdCardGenerationScreen(),
    AppRoutes.superAdminAuditLogs: (_, __) =>
        const PrincipalAuditLogsScreen(role: 'super_admin'),
    AppRoutes.superAdminSystemMonitor: (_, __) =>
        const SystemMonitorScreen(role: 'super_admin'),
    AppRoutes.superAdminAccess: (_, __) =>
        const AdminUserAccessScreen(ownerRole: 'super_admin'),
    AppRoutes.superAdminIssues: (_, __) =>
        const IssueScreen(role: IssueScreenRole.superAdmin),
    AppRoutes.teacherLogin: (_, __) => const AuthLoginScreen(),
    AppRoutes.teacherClasses: (_, __) => const TeacherClassesScreen(),
    AppRoutes.teacherTimetable: (_, __) => const TeacherTimetableScreen(),
    AppRoutes.teacherAttendance: (_, __) => const TeacherAttendanceScreen(),
    AppRoutes.teacherAttendanceHistory: (_, __) =>
        const TeacherAttendanceHistoryScreen(),
    AppRoutes.teacherMyAttendance: (_, __) => const TeacherMyAttendanceScreen(),
    AppRoutes.teacherCommunication: (_, __) =>
        const TeacherCommunicationScreen(),
    AppRoutes.teacherComplaints: (_, __) =>
        const IssueScreen(role: IssueScreenRole.teacher),
    AppRoutes.teacherLeave: (_, __) => const TeacherLeaveScreen(),
    AppRoutes.teacherHomework: (_, __) => const TeacherHomeworkScreen(),
    AppRoutes.teacherEventPosts: (_, __) => const TeacherEventPostScreen(),
    AppRoutes.teacherLessonPlanner: (_, __) =>
        const TeacherLessonPlannerScreen(),
    AppRoutes.teacherDocuments: (_, __) => const TeacherDocumentsScreen(),
    AppRoutes.teacherCalendar: (_, __) =>
        const EventsCalendarScreen(portal: SchoolCalendarPortal.teacher),
    AppRoutes.parentLogin: (_, __) => const AuthLoginScreen(),
    AppRoutes.kioskLogin: (_, __) => const AuthLoginScreen(),
    AppRoutes.parentAttendance: (_, __) => const ParentAttendanceScreen(),
    AppRoutes.parentHomework: (_, __) => const ParentHomeworkScreen(),
    AppRoutes.parentTeacherChat: (_, __) => const ParentTeacherChatScreen(),
    AppRoutes.parentComplaints: (_, __) =>
        const IssueScreen(role: IssueScreenRole.parent),
    AppRoutes.parentFees: (_, __) => const ParentFeeHub(),
    AppRoutes.parentPaymentHistory: (_, __) => const ParentPaymentHistoryV2(),
    AppRoutes.parentLeave: (_, __) => const ParentLeaveScreen(),
    AppRoutes.parentCalendar: (_, __) =>
        const EventsCalendarScreen(portal: SchoolCalendarPortal.parent),
    AppRoutes.parentDocuments: (_, __) => const ParentDocumentsScreen(),
    AppRoutes.parentTimetable: (_, __) => const ParentTimetableScreen(),
    AppRoutes.parentHealth: (_, __) => const ParentHealthUpdateScreen(),
    AppRoutes.parentLessonPlanner: (_, __) => const ParentLessonPlannerScreen(),
    AppRoutes.schoolGallery: (_, __) => const SchoolGalleryScreen(),
    AppRoutes.globalSearch: (_, __) => const GlobalSearchScreen(),
    AppRoutes.help: (_, __) => const HelpScreen(),
  };

  static TypedAppRoute<NoRouteArgs> _noArgs(
    String path,
    String name,
    Widget Function(BuildContext, GoRouterState) build,
  ) {
    return TypedAppRoute<NoRouteArgs>(
      path: path,
      name: name,
      parse: (_) => const NoRouteArgs(),
      build: (context, state, _) =>
          _frame(context, path, build(context, state)),
    );
  }

  static TypedAppRoute<T> _typed<T>(String path, TypedRouteParser<T> parse) {
    return TypedAppRoute<T>(
      path: path,
      name: _routeName(path),
      parse: parse,
      build: (context, state, args) => _frame(
        context,
        path,
        AppRoutes.buildTypedRouteWidget(
          context,
          routeName: path,
          arguments: args,
        ),
      ),
    );
  }

  static TypedAppRoute<SharedRoleRouteArgs> _sharedRole(
    String path,
    String name,
    Widget Function(String role) build,
  ) {
    return TypedAppRoute<SharedRoleRouteArgs>(
      path: path,
      name: name,
      parse: _sharedRoleArgs,
      build: (context, state, args) =>
          _frame(context, path, build(args.roleName)),
    );
  }

  static SharedRoleRouteArgs _sharedRoleArgs(GoRouterState state) {
    return SharedRoleRouteArgs.fromState(state);
  }

  static T Function(GoRouterState) _extraOr<T>(T fallback) {
    return (state) {
      return _parseExtra<T>(state.extra, fallback);
    };
  }

  static T _parseExtra<T>(Object? value, T fallback) {
    if (value is T) return value;
    if (value is Map) {
      final map = Map<String, dynamic>.from(value);
      if (T == ApprovalCenterRouteArgs) {
        return ApprovalCenterRouteArgs.fromRoute(map) as T;
      }
      if (T == SchoolPostsRouteArgs) {
        return SchoolPostsRouteArgs.fromRoute(map) as T;
      }
      if (T == AdminPaymentRequestDecisionArgs) {
        return AdminPaymentRequestDecisionArgs(request: map) as T;
      }
      if (T == TeacherHomeworkSubmissionsArgs) {
        return TeacherHomeworkSubmissionsArgs(homework: map) as T;
      }
      if (T == ParentPaymentSelectionArgs) {
        return ParentPaymentSelectionArgs(
              fees:
                  (map['fees'] as List?)
                      ?.whereType<Map>()
                      .map((entry) => Map<String, dynamic>.from(entry))
                      .toList() ??
                  const [],
              student: map['student'] is Map
                  ? Map<String, dynamic>.from(map['student'] as Map)
                  : null,
              paymentRequest: map['payment_request'] is Map
                  ? Map<String, dynamic>.from(map['payment_request'] as Map)
                  : null,
            )
            as T;
      }
      if (T == ParentHomeworkSubmissionArgs) {
        final nested = map['homework'];
        final homework = nested is Map
            ? Map<String, dynamic>.from(nested)
            : <String, dynamic>{};
        final referenceId = map['reference_id'] ?? map['id'];
        if (homework['homework_id'] == null && referenceId != null) {
          homework['homework_id'] = referenceId;
          homework['id'] = referenceId;
        }
        return ParentHomeworkSubmissionArgs(
              homework: homework,
              studentId: map['student_id']?.toString() ?? '',
              studentName: map['student_name']?.toString() ?? 'Student',
            )
            as T;
      }
    }
    return fallback;
  }

  static Widget _frame(BuildContext context, String path, Widget child) {
    return AppRoutes.buildRoutePage(context, routeName: path, child: child);
  }

  static String _routeName(String path) {
    final normalized = path
        .replaceFirst(RegExp(r'^/+'), '')
        .replaceAll('/', '_');
    return normalized.isEmpty ? 'root' : normalized.replaceAll('-', '_');
  }
}
