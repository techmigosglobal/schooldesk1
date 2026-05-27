import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'admin timetable configuration feeds teacher attendance through scoped slots',
    () {
      final adminTimetable = File(
        'lib/presentation/admin_timetable_screen/admin_timetable_screen.dart',
      ).readAsStringSync();
      final teacherAttendance = File(
        'lib/presentation/teacher_attendance_screen/teacher_attendance_screen.dart',
      ).readAsStringSync();
      final timetableHandler = File(
        'school-backend/internal/handlers/timetable.go',
      ).readAsStringSync();
      final schoolHandler = File(
        'school-backend/internal/handlers/school.go',
      ).readAsStringSync();

      expect(adminTimetable, contains('api.getTimetableSlots()'));
      expect(teacherAttendance, contains('RoleAccessService.teacherStaffId'));
      expect(teacherAttendance, contains('getTimetableSlots('));
      expect(teacherAttendance, contains('staffId: staffId'));
      expect(teacherAttendance, contains('getStudentEnrollments(s.id)'));
      expect(teacherAttendance, contains('createAttendanceSession('));
      expect(
        teacherAttendance,
        contains('markAttendance(sessionId, attendances)'),
      );
      expect(
        timetableHandler,
        contains('currentTeacherID := currentStaffID(c)'),
      );
      expect(timetableHandler, contains('teacher timetable access denied'));
      expect(
        schoolHandler,
        contains('teacherSectionSubquery(staffID, schoolID)'),
      );
    },
  );

  test(
    'homework lifecycle connects teacher posting, parent submission, and review',
    () {
      final teacherForms = File(
        'lib/presentation/teacher_homework_screen/teacher_homework_form_screens.dart',
      ).readAsStringSync();
      final parentHomework = File(
        'lib/presentation/parent_homework_screen/parent_homework_screen.dart',
      ).readAsStringSync();
      final parentSubmission = File(
        'lib/presentation/parent_homework_screen/parent_homework_submission_screen.dart',
      ).readAsStringSync();
      final main = File('school-backend/main.go').readAsStringSync();
      final submissionHandler = File(
        'school-backend/internal/handlers/homework_submission.go',
      ).readAsStringSync();

      expect(teacherForms, contains('createHomework('));
      expect(teacherForms, contains('updateHomework('));
      expect(teacherForms, contains('getHomeworkSubmissions('));
      expect(teacherForms, contains('reviewHomeworkSubmission('));
      expect(parentHomework, contains('AppRoutes.parentHomeworkSubmit'));
      expect(parentSubmission, contains('submitHomework('));
      expect(
        main,
        contains(
          'homework.POST("", middleware.RBACMiddleware("Admin", "Principal", "Teacher")',
        ),
      );
      expect(
        main,
        contains(
          'homework.POST("/:id/submissions", middleware.RBACMiddleware("Parent")',
        ),
      );
      expect(
        main,
        contains('homework.PUT("/:id/submissions/:submission_id/review"'),
      );
      expect(submissionHandler, contains('canAccessStudent(c, req.StudentID)'));
      expect(submissionHandler, contains('scopedSubmissionQuery(c, homework)'));
    },
  );

  test(
    'communication and notifications coordinate chat, read receipts, push, and navigation',
    () {
      final teacherChat = File(
        'lib/presentation/teacher_communication_screen/teacher_communication_screen.dart',
      ).readAsStringSync();
      final parentChat = File(
        'lib/presentation/parent_teacher_chat_screen/parent_teacher_chat_screen.dart',
      ).readAsStringSync();
      final crud = File(
        'school-backend/internal/handlers/crud.go',
      ).readAsStringSync();
      final notifications = File(
        'school-backend/internal/handlers/communication_notifications.go',
      ).readAsStringSync();
      final notificationCenter = File(
        'lib/presentation/notification_center_screen/notification_center_screen.dart',
      ).readAsStringSync();
      final pushService = File(
        'lib/services/push_notification_service.dart',
      ).readAsStringSync();
      final apiClient = File(
        'lib/services/backend_api_client.dart',
      ).readAsStringSync();
      final main = File('school-backend/main.go').readAsStringSync();

      expect(teacherChat, contains("createRaw('/messages'"));
      expect(parentChat, contains("createRaw('/messages'"));
      expect(teacherChat, contains("updateRaw('/messages/\$id'"));
      expect(parentChat, contains("updateRaw('/messages/\$id'"));
      expect(crud, contains('updateMessageReadReceipt'));
      expect(crud, contains('notifyMessageCreated(*message)'));
      expect(notifications, contains('createNotificationLogsForRolesTx('));
      expect(notifications, contains('notifyMessageCreated'));
      expect(notificationCenter, contains('NotificationRouteResolver.resolve'));
      expect(pushService, contains('registerDeviceTokenIfPossible'));
      expect(pushService, contains('_firebaseOperationTimeout'));
      expect(pushService, contains('_deviceRegistrationTimeout'));
      expect(pushService, contains('.timeout(_firebaseOperationTimeout'));
      expect(apiClient, contains('retriedAfterRefresh'));
      expect(apiClient, contains('catchError((_)'));
      expect(main, contains('notifications.POST("/device-tokens"'));
      expect(main, contains('notifications.DELETE("/device-tokens"'));
    },
  );

  test(
    'fee workflow coordinates parent payment request, admin decision, and balance updates',
    () {
      final parentForm = File(
        'lib/presentation/parent_fees_screen/parent_payment_request_form_screen.dart',
      ).readAsStringSync();
      final adminDecision = File(
        'lib/presentation/admin_fees_screen/admin_payment_request_decision_screen.dart',
      ).readAsStringSync();
      final adminFeeForms = File(
        'lib/presentation/admin_fees_screen/admin_fee_form_screens.dart',
      ).readAsStringSync();
      final api = File(
        'lib/services/backend_api_client.dart',
      ).readAsStringSync();
      final main = File('school-backend/main.go').readAsStringSync();
      final feeHandler = File(
        'school-backend/internal/handlers/fee.go',
      ).readAsStringSync();

      expect(parentForm, contains('submitParentPaymentRequest('));
      expect(adminDecision, contains('decideParentPaymentRequest('));
      expect(adminFeeForms, contains('recordPayment('));
      expect(api, contains("'/fees/payment-requests'"));
      expect(api, contains("'/fees/payment-requests/\$id/decision'"));
      expect(
        main,
        contains(
          'fees.POST("/payment-requests", middleware.RBACMiddleware("Parent")',
        ),
      );
      expect(
        main,
        contains(
          'fees.PUT("/payment-requests/:id/decision", middleware.RBACMiddleware("Admin", "Principal")',
        ),
      );
      expect(feeHandler, contains('CreateParentPaymentRequest'));
      expect(feeHandler, contains('DecideParentPaymentRequest'));
      expect(feeHandler, contains('currentUserID(c)'));
    },
  );

  test(
    'exam marks coordinate admin entry, parent progress, principal records, and report exports',
    () {
      final adminExamForms = File(
        'lib/presentation/admin_exams_screen/admin_exam_form_screens.dart',
      ).readAsStringSync();
      final parentProgress = File(
        'lib/presentation/parent_academic_progress_screen/parent_academic_progress_screen.dart',
      ).readAsStringSync();
      final backendData = File(
        'lib/services/backend_data_service.dart',
      ).readAsStringSync();
      final examHandler = File(
        'school-backend/internal/handlers/exam.go',
      ).readAsStringSync();
      final main = File('school-backend/main.go').readAsStringSync();

      expect(adminExamForms, contains('AdminExamMarksEntryScreen'));
      expect(
        adminExamForms,
        contains("'/exams/schedules/\$_scheduleId/marks'"),
      );
      expect(parentProgress, contains("'/students/\$studentId/marks'"));
      expect(parentProgress, contains("'/exams/report-cards'"));
      expect(parentProgress, contains("'/exams/report-cards/exports'"));
      expect(backendData, contains('static const String kExamResults'));
      expect(backendData, contains('_principalExamResult'));
      expect(examHandler, contains('func (h *ExamHandler) GetScheduleMarks'));
      expect(examHandler, contains('func (h *ExamHandler) EnterMarks'));
      expect(examHandler, contains('validateMarkValue'));
      expect(main, contains('exams.GET("/schedules/:schedule_id/marks"'));
      expect(main, contains('exams.POST("/schedules/:schedule_id/marks"'));
      expect(
        main,
        contains('reportExportResource("/exams/report-cards/exports"'),
      );
    },
  );

  test(
    'approval workflow coordinates admin requests with principal decision center',
    () {
      final accountForm = File(
        'lib/presentation/admin_user_access_screen/account_access_form_screen.dart',
      ).readAsStringSync();
      final staffForm = File(
        'lib/presentation/staff_management_screen/staff_form_screen.dart',
      ).readAsStringSync();
      final students = File(
        'lib/presentation/admin_students_screen/admin_students_screen.dart',
      ).readAsStringSync();
      final backendData = File(
        'lib/services/backend_data_service.dart',
      ).readAsStringSync();
      final approvalCenter = File(
        'lib/presentation/approval_center_screen/approval_center_screen.dart',
      ).readAsStringSync();
      final main = File('school-backend/main.go').readAsStringSync();

      expect(
        accountForm,
        contains('requestPrincipalApproval: !_isPrincipalOwner'),
      );
      expect(staffForm, contains('requestPrincipalApproval: _isAdminOwner'));
      expect(students, contains("createRaw('/student-approvals'"));
      expect(backendData, contains("createRaw('/class-approvals'"));
      expect(approvalCenter, contains("path: '/account-approvals'"));
      expect(approvalCenter, contains("path: '/student-approvals'"));
      expect(approvalCenter, contains("path: '/class-approvals'"));
      expect(approvalCenter, contains('_decideGenericApproval'));
      expect(
        main,
        contains(
          'accountApprovalsCompat := protected.Group("/account-approvals")',
        ),
      );
      expect(
        main,
        contains('classApprovalsCompat := protected.Group("/class-approvals")'),
      );
      expect(
        main,
        contains(
          'studentApprovalsCompat := protected.Group("/student-approvals")',
        ),
      );
    },
  );

  test(
    'profile/avatar configuration is shared by all roles and guarded server-side',
    () {
      final teacherDashboard = File(
        'lib/presentation/teacher_dashboard_screen/teacher_dashboard_screen.dart',
      ).readAsStringSync();
      final profile = File(
        'lib/presentation/profile_management_screen/profile_management_screen.dart',
      ).readAsStringSync();
      final api = File(
        'lib/services/backend_api_client.dart',
      ).readAsStringSync();
      final auth = File(
        'school-backend/internal/handlers/auth.go',
      ).readAsStringSync();
      final main = File('school-backend/main.go').readAsStringSync();

      expect(teacherDashboard, contains('AppRoutes.profileScreen'));
      expect(profile, contains('uploadProfileAvatar('));
      expect(profile, contains('updateProfile('));
      expect(api, contains('Future<String> uploadProfileAvatar'));
      expect(
        auth,
        contains('Use /auth/profile/avatar to update profile pictures'),
      );
      expect(auth, contains('Avatar file must be 3 MB or smaller'));
      expect(auth, contains('Avatar must be a JPG, PNG, or WebP image'));
      expect(main, contains('auth.POST("/profile/avatar"'));
    },
  );

  test(
    'advanced parent linking and child switching are wired across parent screens',
    () {
      final api = File(
        'lib/services/backend_api_client.dart',
      ).readAsStringSync();
      final assignment = File(
        'lib/presentation/admin_user_access_screen/account_child_assignment_screen.dart',
      ).readAsStringSync();
      final dashboard = File(
        'lib/presentation/parent_dashboard_screen/parent_dashboard_screen.dart',
      ).readAsStringSync();
      final roleAccess = File(
        'lib/services/role_access_service.dart',
      ).readAsStringSync();
      final parentLink = File(
        'school-backend/internal/handlers/parent_link.go',
      ).readAsStringSync();
      final policyTests = File(
        'school-backend/internal/handlers/relationship_policy_test.go',
      ).readAsStringSync();
      final verifier = File(
        'school-backend/cmd/local-api-verify/main.go',
      ).readAsStringSync();

      expect(api, contains('assignParentStudents'));
      expect(api, contains("'/parents/\$parentUserId/students'"));
      expect(api, contains('getMyStudents'));
      expect(
        assignment,
        contains('BackendApiClient.instance.assignParentStudents'),
      );
      expect(dashboard, contains('api.getMyStudents()'));
      expect(dashboard, contains("api.getDashboard('parent')"));
      expect(dashboard, contains('_activeChildIndex'));
      expect(dashboard, contains('class _ChildSelector'));
      expect(roleAccess, contains('loggedInParentChildren'));
      expect(roleAccess, contains('Map<String, dynamic> childAt(int index)'));
      expect(roleAccess, contains('parentChildNames'));
      expect(
        parentLink,
        contains('func (h *ParentLinkHandler) AssignParentStudents'),
      );
      expect(parentLink, contains('func (h *ParentLinkHandler) GetMyStudents'));
      expect(
        policyTests,
        contains('TestParentStudentLinkListIsScopedToAuthenticatedParent'),
      );
      expect(
        policyTests,
        contains('TestStudentDashboardCompatIsParentManagedAndLinkedScoped'),
      );
      expect(verifier, contains('Admin links Parent to fee student'));
      expect(verifier, contains('Parent can read linked students'));
      expect(
        verifier,
        contains('Parent cannot submit leave for an unlinked student'),
      );
    },
  );

  test(
    'advanced leave, exam, homework notification, and route-deep-link contracts are connected',
    () {
      final studentLeave = File(
        'school-backend/internal/handlers/student_leave.go',
      ).readAsStringSync();
      final exam = File(
        'school-backend/internal/handlers/exam.go',
      ).readAsStringSync();
      final notifications = File(
        'school-backend/internal/handlers/communication_notifications.go',
      ).readAsStringSync();
      final routeResolver = File(
        'lib/services/notification_route_resolver.dart',
      ).readAsStringSync();
      final parentLeave = File(
        'lib/presentation/parent_leave_screen/parent_leave_screen.dart',
      ).readAsStringSync();
      final parentLeaveForm = File(
        'lib/presentation/parent_leave_screen/parent_leave_request_form_screen.dart',
      ).readAsStringSync();
      final api = File(
        'lib/services/backend_api_client.dart',
      ).readAsStringSync();
      final localVerifier = File(
        'school-backend/cmd/local-api-verify/main.go',
      ).readAsStringSync();

      expect(parentLeave, contains('getStudentLeaveApplications'));
      expect(parentLeaveForm, contains('submitStudentLeaveApplication'));
      expect(api, contains("'/student-leave/applications'"));
      expect(
        studentLeave,
        contains('Only parents can submit student leave applications'),
      );
      expect(studentLeave, contains('createNotificationLogsForRolesTx'));
      expect(studentLeave, contains('createNotificationLogsForUserIDsTx'));
      expect(exam, contains('func (h *ExamHandler) CreateExamSchedule'));
      expect(exam, contains('createExamScheduleNotifications(schedule)'));
      expect(notifications, contains('func notifyHomeworkCreated'));
      expect(notifications, contains('func createExamScheduleNotifications'));
      expect(notifications, contains('referenceType string'));
      expect(notifications, contains('case "homework"'));
      expect(notifications, contains('case "exam", "exam_schedule"'));
      expect(routeResolver, contains("'homework' => _homeworkRouteFor(role)"));
      expect(
        routeResolver,
        contains("'exam' || 'exam_schedule' => _examRouteFor(role)"),
      );
      expect(localVerifier, contains('Parent sees homework notification'));
      expect(
        localVerifier,
        contains('Admin creates exam schedule and notifications'),
      );
      expect(localVerifier, contains('Parent sees exam schedule notification'));
      expect(
        localVerifier,
        contains('Teacher sees exam schedule notification'),
      );
    },
  );

  test(
    'advanced transport and library are retired from current route exposure',
    () {
      final main = File('school-backend/main.go').readAsStringSync();
      final studentHandler = File(
        'school-backend/internal/handlers/student.go',
      ).readAsStringSync();
      final models = File(
        'school-backend/internal/models/library_transport.go',
      ).readAsStringSync();
      final appRoutes = File('lib/routes/app_routes.dart').readAsStringSync();
      final docs = File(
        'docs/production-readiness-testcase-sheet-2026-05-16.md',
      ).readAsStringSync();

      expect(main, isNot(contains('transport := api.Group("/transport")')));
      expect(main, isNot(contains('library := api.Group("/library")')));
      expect(main, isNot(contains('GetStudentTransport')));
      expect(
        studentHandler,
        contains('func (h *StudentHandler) GetStudentTransport'),
      );
      expect(studentHandler, contains('Preload("Route").Preload("Stop")'));
      expect(models, contains('type BookIssue struct'));
      expect(models, contains('FinePerDay'));
      expect(models, contains('FineAmount'));
      expect(models, contains('type StudentTransport struct'));
      expect(appRoutes, isNot(contains('/transport-')));
      expect(appRoutes, isNot(contains('/library-')));
      expect(docs, contains('ADV-015'));
      expect(docs, contains('Transport is out of the current product scope'));
      expect(docs, contains('ADV-016'));
      expect(docs, contains('Library is out of the current product scope'));
    },
  );
}
