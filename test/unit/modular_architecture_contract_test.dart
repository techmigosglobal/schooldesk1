import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:schooldesk1/app/providers/app_providers.dart';
import 'package:schooldesk1/core/auth/auth_repository.dart';
import 'package:schooldesk1/core/auth/role_context.dart';
import 'package:schooldesk1/core/authorization/role_access_policy.dart';
import 'package:schooldesk1/core/authorization/feature_manifest.dart';
import 'package:schooldesk1/core/errors/failures.dart';
import 'package:schooldesk1/core/utils/result.dart';
import 'package:schooldesk1/core/repositories/repository_state.dart';
import 'package:schooldesk1/modules/attendance/domain/repositories/attendance_repository.dart';
import 'package:schooldesk1/modules/communication/domain/repositories/notice_repository.dart';
import 'package:schooldesk1/modules/communication/domain/repositories/complaint_repository.dart';
import 'package:schooldesk1/modules/finance/domain/repositories/fee_repository.dart';
import 'package:schooldesk1/modules/finance/domain/payment_config_repository.dart';
import 'package:schooldesk1/modules/finance/domain/admin_fees_repository.dart';
import 'package:schooldesk1/modules/leave/domain/repositories/leave_repository.dart';
import 'package:schooldesk1/modules/people/domain/repositories/student_repository.dart';
import 'package:schooldesk1/modules/people/domain/repositories/teacher_repository.dart';
import 'package:schooldesk1/modules/people/domain/student_directory_repository.dart';
import 'package:schooldesk1/modules/people/domain/staff_directory_repository.dart';
import 'package:schooldesk1/modules/people/domain/guardian_directory_repository.dart';
import 'package:schooldesk1/modules/people/domain/admission_inquiry_repository.dart';
import 'package:schooldesk1/modules/people/domain/user_access_repository.dart';
import 'package:schooldesk1/roles/parent/domain/parent_dashboard_repository.dart';
import 'package:schooldesk1/roles/parent/domain/parent_leave_repository.dart';
import 'package:schooldesk1/roles/parent/domain/parent_attendance_repository.dart';
import 'package:schooldesk1/roles/parent/domain/parent_homework_repository.dart';
import 'package:schooldesk1/roles/parent/domain/parent_documents_repository.dart';
import 'package:schooldesk1/roles/parent/domain/parent_communication_repository.dart';
import 'package:schooldesk1/roles/super_admin/domain/super_admin_dashboard_repository.dart';
import 'package:schooldesk1/roles/principal/domain/principal_reports_repository.dart';
import 'package:schooldesk1/roles/principal/domain/principal_attendance_repository.dart';
import 'package:schooldesk1/roles/principal/domain/principal_event_approval_repository.dart';
import 'package:schooldesk1/roles/principal/domain/principal_chat_repository.dart';
import 'package:schooldesk1/roles/principal/domain/principal_classes_repository.dart';
import 'package:schooldesk1/roles/principal/domain/principal_lesson_planner_repository.dart';
import 'package:schooldesk1/roles/principal/domain/principal_academic_year_repository.dart';
import 'package:schooldesk1/roles/principal/domain/student_oversight_repository.dart';
import 'package:schooldesk1/modules/communication/domain/event_post_repository.dart';
import 'package:schooldesk1/modules/communication/domain/issue_repository.dart';
import 'package:schooldesk1/modules/communication/domain/notification_diagnostics_repository.dart';
import 'package:schooldesk1/modules/monitoring/domain/system_monitor_repository.dart';
import 'package:schooldesk1/modules/profile/domain/profile_repository.dart';
import 'package:schooldesk1/modules/academics/domain/admin_timetable_repository.dart';
import 'package:schooldesk1/roles/teacher/domain/teacher_dashboard_repository.dart';
import 'package:schooldesk1/roles/teacher/domain/teacher_leave_repository.dart';
import 'package:schooldesk1/roles/teacher/domain/teacher_attendance_repository.dart';
import 'package:schooldesk1/roles/teacher/domain/teacher_homework_repository.dart';
import 'package:schooldesk1/roles/teacher/domain/teacher_communication_repository.dart';
import 'package:schooldesk1/roles/teacher/domain/teacher_documents_repository.dart';
import 'package:schooldesk1/roles/teacher/domain/teacher_timetable_repository.dart';
import 'package:schooldesk1/roles/teacher/domain/teacher_lesson_planner_repository.dart';
import 'package:schooldesk1/roles/parent/domain/parent_timetable_repository.dart';
import 'package:schooldesk1/roles/parent/domain/parent_calendar_repository.dart';
import 'package:schooldesk1/roles/parent/domain/parent_lesson_planner_repository.dart';
import 'package:schooldesk1/roles/parent/domain/parent_health_repository.dart';
import 'package:schooldesk1/roles/parent/domain/parent_fee_payment_repository.dart';
import 'package:schooldesk1/roles/principal/domain/admin_reports_repository.dart';
import 'package:schooldesk1/modules/calendar/domain/calendar_repository.dart';
import 'package:schooldesk1/modules/documents/domain/admin_documents_repository.dart';
import 'package:schooldesk1/routes/app_routes.dart';
import 'package:schooldesk1/routes/route_access_guard.dart';

void main() {
  test('role context makes account and branch part of the cache scope', () {
    const teacher = RoleContext(
      accountId: 'account-a',
      schoolId: 'school-a',
      branchId: 'branch-a',
      role: SchoolDeskRole.teacher,
    );
    const parent = RoleContext(
      accountId: 'account-a',
      schoolId: 'school-a',
      branchId: 'branch-a',
      role: SchoolDeskRole.parent,
    );

    expect(teacher.cacheScope, isNot(parent.cacheScope));
    expect(
      RoleAccessPolicy.allows(teacher, SchoolDeskCapability.recordAttendance),
      isTrue,
    );
    expect(
      RoleAccessPolicy.allows(parent, SchoolDeskCapability.recordAttendance),
      isFalse,
    );
  });

  test(
    'repository state exposes cached stale data without hiding its source',
    () {
      final state = const RepositoryState<String>(
        data: 'cached dashboard',
        source: RepositorySource.cache,
        isStale: true,
      );

      expect(state.hasData, isTrue);
      expect(state.isOffline, isTrue);
      expect(state.source, RepositorySource.cache);
      expect(state.phase, RepositoryPhase.ready);
    },
  );

  test('repository state models loading, empty, error, and stale refresh', () {
    const loading = RepositoryState<List<String>>.loading();
    expect(loading.isLoading, isTrue);

    const empty = RepositoryState<List<String>>.empty();
    expect(empty.isEmpty, isTrue);
    expect(empty.phase, RepositoryPhase.empty);

    final error = RepositoryState.fromResult<List<String>>(
      const Result<List<String>>.err(
        UnknownFailure(message: 'backend unavailable'),
      ),
    );
    expect(error.isError, isTrue);

    final stale = RepositoryState.fromResult<List<String>>(
      const Result<List<String>>.err(
        UnknownFailure(message: 'refresh failed'),
      ),
      previous: const RepositoryState<List<String>>(
        data: ['cached'],
        source: RepositorySource.remote,
      ),
    );
    expect(stale.data, ['cached']);
    expect(stale.isStale, isTrue);
    expect(stale.isOffline, isTrue);
  });

  test('feature manifests declare capability and offline behavior', () {
    const finance = FeatureManifest(
      id: 'finance',
      route: '/principal/fees',
      capability: SchoolDeskCapability.manageFinance,
      offlineReadable: true,
      onlineOnlyMutation: true,
    );

    expect(finance.offlineReadable, isTrue);
    expect(finance.onlineOnlyMutation, isTrue);
    expect(RoleAccessPolicy.isOnlineOnly(finance.capability), isTrue);
  });

  test('role capability matrix keeps restricted roles narrow', () {
    const contexts = <SchoolDeskRole, RoleContext>{
      SchoolDeskRole.principal: RoleContext(
        accountId: 'principal',
        schoolId: 'school',
        branchId: null,
        role: SchoolDeskRole.principal,
      ),
      SchoolDeskRole.coordinator: RoleContext(
        accountId: 'coordinator',
        schoolId: 'school',
        branchId: null,
        role: SchoolDeskRole.coordinator,
      ),
      SchoolDeskRole.teacher: RoleContext(
        accountId: 'teacher',
        schoolId: 'school',
        branchId: 'branch',
        role: SchoolDeskRole.teacher,
      ),
      SchoolDeskRole.parent: RoleContext(
        accountId: 'parent',
        schoolId: 'school',
        branchId: 'branch',
        role: SchoolDeskRole.parent,
      ),
      SchoolDeskRole.kiosk: RoleContext(
        accountId: 'kiosk',
        schoolId: 'school',
        branchId: 'branch',
        role: SchoolDeskRole.kiosk,
      ),
      SchoolDeskRole.superAdmin: RoleContext(
        accountId: 'super-admin',
        schoolId: 'school',
        branchId: null,
        role: SchoolDeskRole.superAdmin,
      ),
    };

    expect(
      RoleAccessPolicy.allows(
        contexts[SchoolDeskRole.principal]!,
        SchoolDeskCapability.manageFinance,
      ),
      isTrue,
    );
    expect(
      RoleAccessPolicy.allows(
        contexts[SchoolDeskRole.coordinator]!,
        SchoolDeskCapability.manageFinance,
      ),
      isFalse,
    );
    expect(
      RoleAccessPolicy.allows(
        contexts[SchoolDeskRole.kiosk]!,
        SchoolDeskCapability.scanKioskAttendance,
      ),
      isTrue,
    );
    expect(
      RoleAccessPolicy.forRole(SchoolDeskRole.parent),
      containsAll(<SchoolDeskCapability>[
        SchoolDeskCapability.viewDashboard,
        SchoolDeskCapability.communicate,
      ]),
    );
    expect(
      RoleAccessPolicy.forRole(SchoolDeskRole.parent),
      isNot(contains(SchoolDeskCapability.managePeople)),
    );
    expect(
      RoleAccessPolicy.forRole(SchoolDeskRole.superAdmin),
      containsAll(<SchoolDeskCapability>[
        SchoolDeskCapability.viewDashboard,
        SchoolDeskCapability.viewReports,
        SchoolDeskCapability.manageBranches,
        SchoolDeskCapability.manageAccounts,
        SchoolDeskCapability.manageSupport,
      ]),
    );
    expect(
      RoleAccessPolicy.forRole(SchoolDeskRole.superAdmin),
      isNot(contains(SchoolDeskCapability.manageFinance)),
    );
  });

  test(
    'repository state copyWith preserves or clears nullable fields explicitly',
    () {
      final updatedAt = DateTime.utc(2026, 9, 23);
      final state = RepositoryState<String>(
        data: 'cached dashboard',
        source: RepositorySource.cache,
        isStale: true,
        error: StateError('refresh failed'),
        lastUpdated: updatedAt,
      );

      final preserved = state.copyWith(isRefreshing: true);
      expect(preserved.data, 'cached dashboard');
      expect(preserved.error, isA<StateError>());
      expect(preserved.lastUpdated, updatedAt);

      final cleared = state.copyWith(
        data: null,
        error: null,
        lastUpdated: null,
      );
      expect(cleared.hasData, isFalse);
      expect(cleared.error, isNull);
      expect(cleared.lastUpdated, isNull);
      expect(cleared.source, RepositorySource.cache);
    },
  );

  test(
    'Riverpod providers can override role scope without global mutation',
    () {
      const context = RoleContext(
        accountId: 'account-test',
        schoolId: 'school-test',
        branchId: 'branch-test',
        role: SchoolDeskRole.kiosk,
      );
      final container = ProviderContainer(
        overrides: [roleContextProvider.overrideWithValue(context)],
      );
      addTearDown(container.dispose);

      expect(container.read(roleContextProvider), same(context));
      expect(
        RoleAccessPolicy.allows(
          container.read(roleContextProvider)!,
          SchoolDeskCapability.scanKioskAttendance,
        ),
        isTrue,
      );
    },
  );

  test('Riverpod composition root exposes typed capability repositories', () {
    final container = ProviderContainer(
      overrides: [
        roleContextProvider.overrideWithValue(
          const RoleContext(
            accountId: 'account-test',
            schoolId: 'school-test',
            branchId: 'branch-test',
            role: SchoolDeskRole.teacher,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(authRepositoryProvider), isA<AuthRepository>());
    expect(
      container.read(notificationDiagnosticsRepositoryProvider),
      isA<NotificationDiagnosticsRepository>(),
    );
    expect(
      container.read(systemMonitorRepositoryProvider),
      isA<SystemMonitorRepository>(),
    );
    expect(container.read(studentRepositoryProvider), isA<StudentRepository>());
    expect(
      container.read(studentDirectoryRepositoryProvider),
      isA<StudentDirectoryRepository>(),
    );
    expect(
      container.read(staffDirectoryRepositoryProvider),
      isA<StaffDirectoryRepository>(),
    );
    expect(
      container.read(guardianDirectoryRepositoryProvider),
      isA<GuardianDirectoryRepository>(),
    );
    expect(
      container.read(admissionInquiryRepositoryProvider),
      isA<AdmissionInquiryRepository>(),
    );
    expect(
      container.read(userAccessRepositoryProvider),
      isA<UserAccessRepository>(),
    );
    expect(container.read(teacherRepositoryProvider), isA<TeacherRepository>());
    expect(
      container.read(teacherDashboardRepositoryProvider),
      isA<TeacherDashboardRepository>(),
    );
    expect(
      container.read(teacherLeaveRepositoryProvider),
      isA<TeacherLeaveRepository>(),
    );
    expect(
      container.read(teacherAttendanceRepositoryProvider),
      isA<TeacherAttendanceRepository>(),
    );
    expect(
      container.read(teacherHomeworkRepositoryProvider),
      isA<TeacherHomeworkRepository>(),
    );
    expect(
      container.read(teacherCommunicationRepositoryProvider),
      isA<TeacherCommunicationRepository>(),
    );
    expect(
      container.read(teacherDocumentsRepositoryProvider),
      isA<TeacherDocumentsRepository>(),
    );
    expect(
      container.read(teacherTimetableRepositoryProvider),
      isA<TeacherTimetableRepository>(),
    );
    expect(
      container.read(teacherLessonPlannerRepositoryProvider),
      isA<TeacherLessonPlannerRepository>(),
    );
    expect(
      container.read(parentDashboardRepositoryProvider),
      isA<ParentDashboardRepository>(),
    );
    expect(
      container.read(parentLeaveRepositoryProvider),
      isA<ParentLeaveRepository>(),
    );
    expect(
      container.read(parentAttendanceRepositoryProvider),
      isA<ParentAttendanceRepository>(),
    );
    expect(
      container.read(parentHomeworkRepositoryProvider),
      isA<ParentHomeworkRepository>(),
    );
    expect(
      container.read(parentDocumentsRepositoryProvider),
      isA<ParentDocumentsRepository>(),
    );
    expect(
      container.read(parentCommunicationRepositoryProvider),
      isA<ParentCommunicationRepository>(),
    );
    expect(
      container.read(parentTimetableRepositoryProvider),
      isA<ParentTimetableRepository>(),
    );
    expect(
      container.read(parentCalendarRepositoryProvider),
      isA<ParentCalendarRepository>(),
    );
    expect(
      container.read(parentLessonPlannerRepositoryProvider),
      isA<ParentLessonPlannerRepository>(),
    );
    expect(
      container.read(parentHealthRepositoryProvider),
      isA<ParentHealthRepository>(),
    );
    expect(
      container.read(parentFeePaymentRepositoryProvider),
      isA<ParentFeePaymentRepository>(),
    );
    expect(
      container.read(superAdminDashboardRepositoryProvider),
      isA<SuperAdminDashboardRepository>(),
    );
    expect(
      container.read(principalReportsRepositoryProvider),
      isA<PrincipalReportsRepository>(),
    );
    expect(
      container.read(principalAttendanceRepositoryProvider),
      isA<PrincipalAttendanceRepository>(),
    );
    expect(
      container.read(principalEventApprovalRepositoryProvider),
      isA<PrincipalEventApprovalRepository>(),
    );
    expect(
      container.read(principalChatRepositoryProvider),
      isA<PrincipalChatRepository>(),
    );
    expect(
      container.read(principalClassesRepositoryProvider),
      isA<PrincipalClassesRepository>(),
    );
    expect(
      container.read(principalLessonPlannerRepositoryProvider),
      isA<PrincipalLessonPlannerRepository>(),
    );
    expect(
      container.read(principalAcademicYearRepositoryProvider),
      isA<PrincipalAcademicYearRepository>(),
    );
    expect(
      container.read(studentOversightRepositoryProvider),
      isA<StudentOversightRepository>(),
    );
    expect(
      container.read(eventPostRepositoryProvider),
      isA<EventPostRepository>(),
    );
    expect(
      container.read(issueRepositoryProvider),
      isA<IssueRepository>(),
    );
    expect(
      container.read(profileRepositoryProvider),
      isA<ProfileRepository>(),
    );
    expect(
      container.read(adminTimetableRepositoryProvider),
      isA<AdminTimetableRepository>(),
    );
    expect(
      container.read(adminDocumentsRepositoryProvider),
      isA<AdminDocumentsRepository>(),
    );
    expect(
      container.read(adminReportsRepositoryProvider),
      isA<AdminReportsRepository>(),
    );
    expect(
      container.read(calendarRepositoryProvider),
      isA<CalendarRepository>(),
    );
    expect(container.read(feeRepositoryProvider), isA<FeeRepository>());
    expect(
      container.read(paymentConfigRepositoryProvider),
      isA<PaymentConfigRepository>(),
    );
    expect(
      container.read(adminFeesRepositoryProvider),
      isA<AdminFeesRepository>(),
    );
    expect(
      container.read(attendanceRepositoryProvider),
      isA<AttendanceRepository>(),
    );
    expect(container.read(leaveRepositoryProvider), isA<LeaveRepository>());
    expect(container.read(noticeRepositoryProvider), isA<NoticeRepository>());
    expect(
      container.read(complaintRepositoryProvider),
      isA<ComplaintRepository>(),
    );
    expect(
      container.read(roleCapabilitiesProvider),
      contains(SchoolDeskCapability.recordAttendance),
    );
    expect(
      container.read(roleCapabilitiesProvider),
      isNot(contains(SchoolDeskCapability.manageFinance)),
    );
  });

  test('legacy aliases remain role-guarded during typed-router migration', () {
    expect(
      RouteAccessGuard.isRoleAllowedFor(
        routeName: AppRoutes.legacyParentFees,
        role: 'parent',
      ),
      isTrue,
    );
    expect(
      RouteAccessGuard.isRoleAllowedFor(
        routeName: AppRoutes.legacyParentFees,
        role: 'teacher',
      ),
      isFalse,
    );
  });

  test('role dashboard widgets stay behind repository boundaries', () {
    const screens = [
      'lib/features/dashboard/presentation/screens/principal_dashboard_screen/principal_dashboard_screen.dart',
      'lib/features/dashboard/presentation/screens/teacher_dashboard_screen/teacher_dashboard_screen.dart',
      'lib/features/dashboard/presentation/screens/parent_dashboard_screen/parent_dashboard_screen.dart',
      'lib/features/dashboard/presentation/screens/super_admin_dashboard_screen/super_admin_dashboard_screen.dart',
      'lib/features/attendance/presentation/screens/kiosk_qr_attendance_screen/kiosk_qr_attendance_screen.dart',
      'lib/features/attendance/presentation/screens/teacher_attendance_screen/teacher_attendance_screen.dart',
      'lib/features/attendance/presentation/screens/principal_attendance_screen/principal_attendance_screen.dart',
      'lib/features/attendance/presentation/screens/admin_attendance_screen/admin_attendance_screen.dart',
      'lib/features/homework/presentation/screens/teacher_homework_screen/teacher_homework_screen.dart',
      'lib/features/homework/presentation/screens/teacher_homework_screen/teacher_homework_form_screens.dart',
      'lib/features/communication/presentation/screens/teacher_communication_screen/teacher_communication_screen.dart',
      'lib/features/homework/presentation/screens/parent_homework_screen/parent_homework_screen.dart',
      'lib/features/homework/presentation/screens/parent_homework_screen/parent_homework_submission_screen.dart',
      'lib/features/finance/presentation/screens/parent_hub/parent_payment_flow.dart',
      'lib/features/documents/presentation/screens/teacher_documents_screen/teacher_documents_screen.dart',
      'lib/features/documents/presentation/screens/parent_documents_screen/parent_documents_screen.dart',
      'lib/features/documents/presentation/screens/admin_documents_screen/admin_documents_screen.dart',
      'lib/features/communication/presentation/screens/parent_teacher_chat_screen/parent_teacher_chat_screen.dart',
      'lib/features/communication/presentation/screens/parent_complaint_screen/parent_complaint_screen.dart',
      'lib/features/communication/presentation/screens/teacher_complaint_screen/teacher_complaint_screen.dart',
      'lib/features/communication/presentation/screens/principal_event_approval_screen.dart',
      'lib/features/communication/presentation/screens/principal_chat_communications_screen/principal_chat_communications_screen.dart',
      'lib/features/communication/presentation/screens/event_post_screen.dart',
      'lib/features/communication/presentation/screens/issue_screen.dart',
      'lib/features/profile/presentation/screens/profile_management_screen/profile_management_screen.dart',
      'lib/features/academics/presentation/screens/teacher_timetable_screen/teacher_timetable_screen.dart',
      'lib/features/academics/presentation/screens/parent_timetable_screen/parent_timetable_screen.dart',
      'lib/features/academics/presentation/screens/parent_lesson_planner_screen/parent_lesson_planner_screen.dart',
      'lib/features/calendar/presentation/screens/parent_calendar_screen/parent_calendar_screen.dart',
      'lib/features/calendar/presentation/screens/events_calendar_screen/events_calendar_screen.dart',
      'lib/features/health/presentation/screens/parent_health_update_screen/parent_health_update_screen.dart',
      'lib/features/academics/presentation/screens/lesson_planner_screen.dart',
      'lib/features/academics/presentation/screens/principal_lesson_planner_screen.dart',
      'lib/features/academics/presentation/screens/academic_management_screen/principal_academic_years_screen.dart',
      'lib/features/reports/presentation/screens/reports_analytics_screen/reports_analytics_screen.dart',
      'lib/features/reports/presentation/screens/admin_reports_screen/admin_reports_screen.dart',
      'lib/features/people/presentation/screens/admin_students_screen/admin_students_screen.dart',
      'lib/features/people/presentation/screens/admin_teachers_screen/admin_teachers_screen.dart',
      'lib/features/people/presentation/screens/staff_management_screen/staff_management_screen.dart',
      'lib/features/people/presentation/screens/staff_management_screen/staff_form_screen.dart',
      'lib/features/people/presentation/screens/admin_user_access_screen/admin_user_access_screen.dart',
      'lib/features/people/presentation/screens/admin_user_access_screen/account_access_form_screen.dart',
      'lib/features/people/presentation/screens/admin_user_access_screen/account_child_assignment_screen.dart',
      'lib/features/people/presentation/screens/guardian_directory_screen/guardian_directory_screen.dart',
      'lib/features/people/presentation/screens/admission_inquiries_screen.dart',
      'lib/features/academics/presentation/screens/principal_classes_screen/principal_classes_screen.dart',
      'lib/features/people/presentation/screens/student_oversight_screen/student_oversight_screen.dart',
      'lib/features/people/presentation/screens/approval_center_screen/approval_center_screen.dart',
      'lib/features/finance/presentation/screens/fee_payment_config_screen/fee_payment_config_screen.dart',
      'lib/features/finance/presentation/screens/principal_dashboard/principal_payment_config.dart',
      'lib/features/finance/presentation/screens/admin_fees_screen/admin_payment_requests_screen.dart',
      'lib/features/finance/presentation/screens/admin_fees_screen/admin_payment_request_decision_screen.dart',
      'lib/features/finance/presentation/screens/admin_fees_screen/admin_fees_screen.dart',
      'lib/features/finance/presentation/screens/admin_fees_screen/admin_fee_form_screens.dart',
      'lib/features/finance/presentation/screens/fee_ledger_screen/fee_ledger_screen.dart',
      'lib/features/finance/presentation/screens/fee_home_screen/fee_home_screen.dart',
    ];

    for (final path in screens) {
      final source = File(path).readAsStringSync();
      expect(
        source,
        isNot(contains('BackendApiClient.instance')),
        reason: '$path must use its role repository boundary',
      );
    }
  });
}
