import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:schooldesk1/core/auth/role_context.dart';
import 'package:schooldesk1/core/auth/api_auth_repository.dart';
import 'package:schooldesk1/core/auth/auth_repository.dart';
import 'package:schooldesk1/core/authorization/role_access_policy.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/offline/offline_database.dart';
import 'package:schooldesk1/core/offline/offline_sync_engine.dart';
import 'package:schooldesk1/core/services/backend_data_service.dart';
import 'package:schooldesk1/features/auth/presentation/controllers/auth_controller.dart';
import 'package:schooldesk1/modules/attendance/data/repositories/api_attendance_repository.dart';
import 'package:schooldesk1/modules/attendance/data/repositories/api_kiosk_attendance_repository.dart';
import 'package:schooldesk1/modules/attendance/domain/repositories/attendance_repository.dart';
import 'package:schooldesk1/modules/attendance/domain/repositories/kiosk_attendance_repository.dart';
import 'package:schooldesk1/modules/communication/data/repositories/api_notice_repository.dart';
import 'package:schooldesk1/modules/communication/domain/repositories/notice_repository.dart';
import 'package:schooldesk1/modules/finance/data/repositories/api_fee_repository.dart';
import 'package:schooldesk1/modules/finance/domain/repositories/fee_repository.dart';
import 'package:schooldesk1/modules/finance/data/api_payment_config_repository.dart';
import 'package:schooldesk1/modules/finance/domain/payment_config_repository.dart';
import 'package:schooldesk1/modules/finance/data/api_admin_fees_repository.dart';
import 'package:schooldesk1/modules/finance/domain/admin_fees_repository.dart';
import 'package:schooldesk1/modules/leave/data/repositories/api_leave_repository.dart';
import 'package:schooldesk1/modules/leave/domain/repositories/leave_repository.dart';
import 'package:schooldesk1/modules/people/data/repositories/api_student_repository.dart';
import 'package:schooldesk1/modules/people/data/repositories/api_teacher_repository.dart';
import 'package:schooldesk1/modules/people/data/repositories/api_approval_repository.dart';
import 'package:schooldesk1/modules/people/domain/repositories/approval_repository.dart';
import 'package:schooldesk1/modules/people/domain/repositories/student_repository.dart';
import 'package:schooldesk1/modules/people/data/api_student_directory_repository.dart';
import 'package:schooldesk1/modules/people/domain/student_directory_repository.dart';
import 'package:schooldesk1/modules/people/data/api_staff_directory_repository.dart';
import 'package:schooldesk1/modules/people/domain/staff_directory_repository.dart';
import 'package:schooldesk1/modules/people/data/api_guardian_directory_repository.dart';
import 'package:schooldesk1/modules/people/domain/guardian_directory_repository.dart';
import 'package:schooldesk1/modules/people/data/api_admission_inquiry_repository.dart';
import 'package:schooldesk1/modules/people/domain/admission_inquiry_repository.dart';
import 'package:schooldesk1/modules/people/data/api_user_access_repository.dart';
import 'package:schooldesk1/modules/people/domain/user_access_repository.dart';
import 'package:schooldesk1/modules/people/domain/repositories/teacher_repository.dart';
import 'package:schooldesk1/modules/communication/data/repositories/api_complaint_repository.dart';
import 'package:schooldesk1/modules/communication/domain/repositories/complaint_repository.dart';
import 'package:schooldesk1/modules/communication/data/api_event_post_repository.dart';
import 'package:schooldesk1/modules/communication/domain/event_post_repository.dart';
import 'package:schooldesk1/modules/communication/data/api_issue_repository.dart';
import 'package:schooldesk1/modules/communication/domain/issue_repository.dart';
import 'package:schooldesk1/roles/teacher/data/api_teacher_dashboard_repository.dart';
import 'package:schooldesk1/roles/teacher/domain/teacher_dashboard_repository.dart';
import 'package:schooldesk1/roles/teacher/data/api_teacher_leave_repository.dart';
import 'package:schooldesk1/roles/teacher/domain/teacher_leave_repository.dart';
import 'package:schooldesk1/roles/teacher/data/api_teacher_attendance_repository.dart';
import 'package:schooldesk1/roles/teacher/domain/teacher_attendance_repository.dart';
import 'package:schooldesk1/roles/teacher/data/api_teacher_homework_repository.dart';
import 'package:schooldesk1/roles/teacher/domain/teacher_homework_repository.dart';
import 'package:schooldesk1/roles/teacher/data/api_teacher_communication_repository.dart';
import 'package:schooldesk1/roles/teacher/domain/teacher_communication_repository.dart';
import 'package:schooldesk1/roles/teacher/data/api_teacher_documents_repository.dart';
import 'package:schooldesk1/roles/teacher/domain/teacher_documents_repository.dart';
import 'package:schooldesk1/roles/teacher/data/api_teacher_timetable_repository.dart';
import 'package:schooldesk1/roles/teacher/domain/teacher_timetable_repository.dart';
import 'package:schooldesk1/roles/teacher/data/api_teacher_lesson_planner_repository.dart';
import 'package:schooldesk1/roles/teacher/domain/teacher_lesson_planner_repository.dart';
import 'package:schooldesk1/roles/parent/data/api_parent_dashboard_repository.dart';
import 'package:schooldesk1/roles/parent/domain/parent_dashboard_repository.dart';
import 'package:schooldesk1/roles/parent/data/api_parent_leave_repository.dart';
import 'package:schooldesk1/roles/parent/domain/parent_leave_repository.dart';
import 'package:schooldesk1/roles/parent/data/api_parent_attendance_repository.dart';
import 'package:schooldesk1/roles/parent/domain/parent_attendance_repository.dart';
import 'package:schooldesk1/roles/parent/data/api_parent_homework_repository.dart';
import 'package:schooldesk1/roles/parent/domain/parent_homework_repository.dart';
import 'package:schooldesk1/roles/parent/data/api_parent_documents_repository.dart';
import 'package:schooldesk1/roles/parent/domain/parent_documents_repository.dart';
import 'package:schooldesk1/roles/parent/data/api_parent_communication_repository.dart';
import 'package:schooldesk1/roles/parent/domain/parent_communication_repository.dart';
import 'package:schooldesk1/roles/parent/data/api_parent_timetable_repository.dart';
import 'package:schooldesk1/roles/parent/domain/parent_timetable_repository.dart';
import 'package:schooldesk1/roles/parent/data/api_parent_health_repository.dart';
import 'package:schooldesk1/roles/parent/domain/parent_health_repository.dart';
import 'package:schooldesk1/roles/parent/data/api_parent_fee_payment_repository.dart';
import 'package:schooldesk1/roles/parent/domain/parent_fee_payment_repository.dart';
import 'package:schooldesk1/roles/parent/data/api_parent_lesson_planner_repository.dart';
import 'package:schooldesk1/roles/parent/domain/parent_lesson_planner_repository.dart';
import 'package:schooldesk1/roles/parent/data/api_parent_calendar_repository.dart';
import 'package:schooldesk1/roles/parent/domain/parent_calendar_repository.dart';
import 'package:schooldesk1/roles/super_admin/data/api_super_admin_dashboard_repository.dart';
import 'package:schooldesk1/roles/super_admin/domain/super_admin_dashboard_repository.dart';
import 'package:schooldesk1/roles/principal/data/api_leadership_dashboard_repository.dart';
import 'package:schooldesk1/roles/principal/domain/leadership_dashboard_repository.dart';
import 'package:schooldesk1/roles/principal/data/api_principal_reports_repository.dart';
import 'package:schooldesk1/roles/principal/domain/principal_reports_repository.dart';
import 'package:schooldesk1/roles/principal/data/api_principal_attendance_repository.dart';
import 'package:schooldesk1/roles/principal/domain/principal_attendance_repository.dart';
import 'package:schooldesk1/roles/principal/data/api_principal_event_approval_repository.dart';
import 'package:schooldesk1/roles/principal/domain/principal_event_approval_repository.dart';
import 'package:schooldesk1/roles/principal/data/api_principal_chat_repository.dart';
import 'package:schooldesk1/roles/principal/domain/principal_chat_repository.dart';
import 'package:schooldesk1/roles/principal/data/api_principal_classes_repository.dart';
import 'package:schooldesk1/roles/principal/domain/principal_classes_repository.dart';
import 'package:schooldesk1/roles/principal/data/api_principal_lesson_planner_repository.dart';
import 'package:schooldesk1/roles/principal/domain/principal_lesson_planner_repository.dart';
import 'package:schooldesk1/roles/principal/data/api_principal_academic_year_repository.dart';
import 'package:schooldesk1/roles/principal/domain/principal_academic_year_repository.dart';
import 'package:schooldesk1/roles/principal/data/api_student_oversight_repository.dart';
import 'package:schooldesk1/roles/principal/domain/student_oversight_repository.dart';
import 'package:schooldesk1/roles/principal/data/api_admin_reports_repository.dart';
import 'package:schooldesk1/roles/principal/domain/admin_reports_repository.dart';
import 'package:schooldesk1/roles/principal/data/api_principal_analytics_repository.dart';
import 'package:schooldesk1/roles/principal/domain/principal_analytics_repository.dart';
import 'package:schooldesk1/modules/calendar/data/api_calendar_repository.dart';
import 'package:schooldesk1/modules/calendar/domain/calendar_repository.dart';
import 'package:schooldesk1/modules/profile/data/api_profile_repository.dart';
import 'package:schooldesk1/modules/profile/domain/profile_repository.dart';
import 'package:schooldesk1/modules/documents/data/api_admin_documents_repository.dart';
import 'package:schooldesk1/modules/documents/domain/admin_documents_repository.dart';
import 'package:schooldesk1/modules/academics/data/api_admin_timetable_repository.dart';
import 'package:schooldesk1/modules/academics/domain/admin_timetable_repository.dart';
import 'package:schooldesk1/modules/academics/data/api_academic_management_repository.dart';
import 'package:schooldesk1/modules/academics/domain/academic_management_repository.dart';
import 'package:schooldesk1/modules/dashboard/data/api_admin_dashboard_repository.dart';
import 'package:schooldesk1/modules/dashboard/domain/admin_dashboard_repository.dart';
import 'package:schooldesk1/modules/documents/data/api_id_card_repository.dart';
import 'package:schooldesk1/modules/documents/domain/id_card_repository.dart';
import 'package:schooldesk1/modules/monitoring/data/api_system_monitor_repository.dart';
import 'package:schooldesk1/modules/monitoring/domain/system_monitor_repository.dart';
import 'package:schooldesk1/modules/communication/data/api_notification_diagnostics_repository.dart';
import 'package:schooldesk1/modules/communication/domain/notification_diagnostics_repository.dart';
import 'package:schooldesk1/modules/communication/data/api_help_content_repository.dart';
import 'package:schooldesk1/modules/communication/domain/help_content_repository.dart';

final backendApiClientProvider = Provider<BackendApiClient>(
  (ref) => BackendApiClient.instance,
);

final currentRoleNameProvider = Provider<String?>((ref) {
  return ref
      .watch(backendApiClientProvider)
      .currentRoleName
      ?.trim()
      .toLowerCase();
});

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => ApiAuthRepository(ref.watch(backendApiClientProvider)),
);

final systemMonitorRepositoryProvider = Provider<SystemMonitorRepository>(
  (ref) => ApiSystemMonitorRepository(ref.watch(backendApiClientProvider)),
);

final notificationDiagnosticsRepositoryProvider =
    Provider<NotificationDiagnosticsRepository>(
      (ref) => ApiNotificationDiagnosticsRepository(
        ref.watch(backendApiClientProvider),
      ),
    );

final helpContentRepositoryProvider = Provider<HelpContentRepository>(
  (ref) => ApiHelpContentRepository(ref.watch(backendApiClientProvider)),
);

final authControllerProvider = Provider<AuthController>(
  (ref) => AuthController(ref.watch(authRepositoryProvider)),
);

final offlineSyncEngineProvider = Provider<OfflineSyncEngine?>((ref) {
  try {
    return OfflineSyncEngine.instance;
  } on StateError {
    return null;
  }
});

final offlineDatabaseProvider = Provider<OfflineDatabase?>((ref) {
  return ref.watch(offlineSyncEngineProvider)?.database;
});

final studentRepositoryProvider = Provider<StudentRepository>((ref) {
  return ApiStudentRepository(ref.watch(backendApiClientProvider));
});

final studentDirectoryRepositoryProvider = Provider<StudentDirectoryRepository>(
  (ref) {
    return ApiStudentDirectoryRepository(ref.watch(backendApiClientProvider));
  },
);

final staffDirectoryRepositoryProvider = Provider<StaffDirectoryRepository>(
  (ref) => ApiStaffDirectoryRepository(ref.watch(backendApiClientProvider)),
);

final guardianDirectoryRepositoryProvider =
    Provider<GuardianDirectoryRepository>(
      (ref) =>
          ApiGuardianDirectoryRepository(ref.watch(backendApiClientProvider)),
    );

final admissionInquiryRepositoryProvider = Provider<AdmissionInquiryRepository>(
  (ref) => ApiAdmissionInquiryRepository(ref.watch(backendApiClientProvider)),
);

final userAccessRepositoryProvider = Provider<UserAccessRepository>(
  (ref) => ApiUserAccessRepository(ref.watch(backendApiClientProvider)),
);

final teacherRepositoryProvider = Provider<TeacherRepository>((ref) {
  return ApiTeacherRepository(ref.watch(backendApiClientProvider));
});

final approvalRepositoryProvider = Provider<ApprovalRepository>((ref) {
  return ApiApprovalRepository(ref.watch(backendApiClientProvider));
});

final teacherDashboardRepositoryProvider = Provider<TeacherDashboardRepository>(
  (ref) {
    return ApiTeacherDashboardRepository(ref.watch(backendApiClientProvider));
  },
);

final teacherLeaveRepositoryProvider = Provider<TeacherLeaveRepository>((ref) {
  return ApiTeacherLeaveRepository(ref.watch(backendApiClientProvider));
});

final teacherAttendanceRepositoryProvider =
    Provider<TeacherAttendanceRepository>((ref) {
      return ApiTeacherAttendanceRepository(
        ref.watch(backendApiClientProvider),
      );
    });

final teacherHomeworkRepositoryProvider = Provider<TeacherHomeworkRepository>((
  ref,
) {
  return ApiTeacherHomeworkRepository(ref.watch(backendApiClientProvider));
});

final teacherCommunicationRepositoryProvider =
    Provider<TeacherCommunicationRepository>((ref) {
      return ApiTeacherCommunicationRepository(
        ref.watch(backendApiClientProvider),
      );
    });

final teacherDocumentsRepositoryProvider = Provider<TeacherDocumentsRepository>(
  (ref) {
    return ApiTeacherDocumentsRepository(ref.watch(backendApiClientProvider));
  },
);

final teacherTimetableRepositoryProvider = Provider<TeacherTimetableRepository>(
  (ref) => ApiTeacherTimetableRepository(ref.watch(backendApiClientProvider)),
);

final teacherLessonPlannerRepositoryProvider =
    Provider<TeacherLessonPlannerRepository>(
      (ref) => ApiTeacherLessonPlannerRepository(
        ref.watch(backendApiClientProvider),
      ),
    );

final parentDashboardRepositoryProvider = Provider<ParentDashboardRepository>((
  ref,
) {
  return ApiParentDashboardRepository(ref.watch(backendApiClientProvider));
});

final parentLeaveRepositoryProvider = Provider<ParentLeaveRepository>((ref) {
  return ApiParentLeaveRepository(ref.watch(backendApiClientProvider));
});

final parentAttendanceRepositoryProvider = Provider<ParentAttendanceRepository>(
  (ref) {
    return ApiParentAttendanceRepository(ref.watch(backendApiClientProvider));
  },
);

final parentHomeworkRepositoryProvider = Provider<ParentHomeworkRepository>((
  ref,
) {
  return ApiParentHomeworkRepository(ref.watch(backendApiClientProvider));
});

final parentDocumentsRepositoryProvider = Provider<ParentDocumentsRepository>((
  ref,
) {
  return ApiParentDocumentsRepository(ref.watch(backendApiClientProvider));
});

final parentCommunicationRepositoryProvider =
    Provider<ParentCommunicationRepository>((ref) {
      return ApiParentCommunicationRepository(
        ref.watch(backendApiClientProvider),
      );
    });

final parentTimetableRepositoryProvider = Provider<ParentTimetableRepository>(
  (ref) => ApiParentTimetableRepository(ref.watch(backendApiClientProvider)),
);

final parentHealthRepositoryProvider = Provider<ParentHealthRepository>(
  (ref) => ApiParentHealthRepository(ref.watch(backendApiClientProvider)),
);

final parentFeePaymentRepositoryProvider = Provider<ParentFeePaymentRepository>(
  (ref) => ApiParentFeePaymentRepository(ref.watch(backendApiClientProvider)),
);

final parentLessonPlannerRepositoryProvider =
    Provider<ParentLessonPlannerRepository>(
      (ref) =>
          ApiParentLessonPlannerRepository(ref.watch(backendApiClientProvider)),
    );

final parentCalendarRepositoryProvider = Provider<ParentCalendarRepository>(
  (ref) => ApiParentCalendarRepository(ref.watch(backendApiClientProvider)),
);

final superAdminDashboardRepositoryProvider =
    Provider<SuperAdminDashboardRepository>((ref) {
      return ApiSuperAdminDashboardRepository(
        ref.watch(backendApiClientProvider),
      );
    });

final leadershipDashboardRepositoryProvider =
    Provider<LeadershipDashboardRepository>((ref) {
      return ApiLeadershipDashboardRepository(
        ref.watch(backendApiClientProvider),
      );
    });

final principalReportsRepositoryProvider = Provider<PrincipalReportsRepository>(
  (ref) => ApiPrincipalReportsRepository(ref.watch(backendApiClientProvider)),
);

final principalAttendanceRepositoryProvider =
    Provider<PrincipalAttendanceRepository>(
      (ref) =>
          ApiPrincipalAttendanceRepository(ref.watch(backendApiClientProvider)),
    );

final principalEventApprovalRepositoryProvider =
    Provider<PrincipalEventApprovalRepository>(
      (ref) => ApiPrincipalEventApprovalRepository(
        ref.watch(backendApiClientProvider),
      ),
    );

final principalChatRepositoryProvider = Provider<PrincipalChatRepository>(
  (ref) => ApiPrincipalChatRepository(ref.watch(backendApiClientProvider)),
);

final principalClassesRepositoryProvider = Provider<PrincipalClassesRepository>(
  (ref) => ApiPrincipalClassesRepository(ref.watch(backendApiClientProvider)),
);

final principalLessonPlannerRepositoryProvider =
    Provider<PrincipalLessonPlannerRepository>(
      (ref) => ApiPrincipalLessonPlannerRepository(
        ref.watch(backendApiClientProvider),
      ),
    );

final principalAcademicYearRepositoryProvider =
    Provider<PrincipalAcademicYearRepository>(
      (ref) => ApiPrincipalAcademicYearRepository(
        ref.watch(backendApiClientProvider),
      ),
    );

final studentOversightRepositoryProvider = Provider<StudentOversightRepository>(
  (ref) => ApiStudentOversightRepository(ref.watch(backendApiClientProvider)),
);

final adminReportsRepositoryProvider = Provider<AdminReportsRepository>(
  (ref) => ApiAdminReportsRepository(ref.watch(backendApiClientProvider)),
);

final principalAnalyticsRepositoryProvider =
    Provider<PrincipalAnalyticsRepository>(
      (ref) =>
          ApiPrincipalAnalyticsRepository(ref.watch(backendApiClientProvider)),
    );

final calendarRepositoryProvider = Provider<CalendarRepository>(
  (ref) => ApiCalendarRepository(ref.watch(backendApiClientProvider)),
);

final feeRepositoryProvider = Provider<FeeRepository>((ref) {
  return ApiFeeRepository(ref.watch(backendApiClientProvider));
});

final paymentConfigRepositoryProvider = Provider<PaymentConfigRepository>(
  (ref) => ApiPaymentConfigRepository(ref.watch(backendApiClientProvider)),
);

final adminFeesRepositoryProvider = Provider<AdminFeesRepository>(
  (ref) => ApiAdminFeesRepository(ref.watch(backendApiClientProvider)),
);

final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  return ApiAttendanceRepository(
    ref.watch(backendApiClientProvider),
    ref.watch(offlineDatabaseProvider),
  );
});

final kioskAttendanceRepositoryProvider = Provider<KioskAttendanceRepository>((
  ref,
) {
  return ApiKioskAttendanceRepository(ref.watch(backendApiClientProvider));
});

final leaveRepositoryProvider = Provider<LeaveRepository>((ref) {
  return ApiLeaveRepository(ref.watch(backendApiClientProvider));
});

final noticeRepositoryProvider = Provider<NoticeRepository>((ref) {
  return ApiNoticeRepository(ref.watch(backendApiClientProvider));
});

final complaintRepositoryProvider = Provider<ComplaintRepository>((ref) {
  return ApiComplaintRepository(ref.watch(backendApiClientProvider));
});

final eventPostRepositoryProvider = Provider<EventPostRepository>(
  (ref) => ApiEventPostRepository(ref.watch(backendApiClientProvider)),
);

final issueRepositoryProvider = Provider<IssueRepository>(
  (ref) => ApiIssueRepository(ref.watch(backendApiClientProvider)),
);

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ApiProfileRepository(ref.watch(backendApiClientProvider)),
);

final adminDocumentsRepositoryProvider = Provider<AdminDocumentsRepository>(
  (ref) => ApiAdminDocumentsRepository(ref.watch(backendApiClientProvider)),
);

final adminTimetableRepositoryProvider = Provider<AdminTimetableRepository>(
  (ref) => ApiAdminTimetableRepository(ref.watch(backendApiClientProvider)),
);

final academicManagementRepositoryProvider =
    Provider<AcademicManagementRepository>(
      (ref) => ApiAcademicManagementRepository(
        // BackendDataService remains behind this capability boundary while
        // its transport mapping is retired incrementally.
        BackendDataService.instance,
      ),
    );

final adminDashboardRepositoryProvider = Provider<AdminDashboardRepository>(
  (ref) => ApiAdminDashboardRepository(BackendDataService.instance),
);

final idCardRepositoryProvider = Provider<IdCardRepository>(
  (ref) => ApiIdCardRepository(BackendDataService.instance),
);

final roleCapabilitiesProvider = Provider<Set<SchoolDeskCapability>>((ref) {
  final context = ref.watch(roleContextProvider);
  if (context == null) return const <SchoolDeskCapability>{};
  return RoleAccessPolicy.forRole(context.role);
});

/// A snapshot provider is intentionally small and synchronous. Auth/session
/// events will move behind a notifier as role screens migrate to Riverpod;
/// this adapter lets the new modules share the existing session safely now.
final roleContextProvider = Provider<RoleContext?>((ref) {
  final api = ref.watch(backendApiClientProvider);
  final role = SchoolDeskRoleParsing.fromWireName(api.currentRoleName);
  final accountId = api.currentUserId?.trim();
  final schoolId = api.activeBranchId?.trim();
  if (role == null || accountId == null || accountId.isEmpty) return null;
  if (schoolId == null || schoolId.isEmpty) return null;
  return RoleContext(
    accountId: accountId,
    schoolId: schoolId,
    branchId: schoolId,
    role: role,
  );
});
