import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('student write contracts expose principal direct and admin approval paths', () {
    final main = File('school-backend/main.go').readAsStringSync();

    expect(
      main,
      contains(
        'students.PUT("/:id", middleware.RBACMiddleware("Admin", "Principal"), studentHandler.UpdateStudent)',
      ),
    );
    expect(
      main,
      contains(
        'students.POST("/enrollments", middleware.RBACMiddleware("Admin", "Principal"), studentHandler.CreateEnrollment)',
      ),
    );
    expect(
      main,
      contains(
        'studentApprovals.POST("", middleware.RBACMiddleware("Admin"), middleware.RateLimitMiddleware("student_write"',
      ),
    );
    expect(
      main,
      contains(
        'attendance.POST("/staff", middleware.RBACMiddleware("Admin", "Principal"), attendanceHandler.MarkStaffAttendance)',
      ),
    );
    expect(
      main,
      contains(
        'fees.POST("/invoices", middleware.RBACMiddleware("Admin", "Principal"), middleware.RateLimitMiddleware("fee_write"',
      ),
    );
  });

  test('admin finance screen normalizes backend fee and invoice shapes', () {
    final source = File(
      'lib/presentation/admin_fees_screen/admin_fees_screen.dart',
    ).readAsStringSync();

    expect(source, contains('Map<String, dynamic> _normalizeFeeStructure('));
    expect(source, contains('Map<String, dynamic> _normalizeInvoice('));
    expect(source, contains("fee['fee_category']"));
    expect(source, contains("invoice['student']"));
    expect(
      source,
      contains(".where((invoice) => _numValue(invoice['balance']) > 0)"),
    );
    expect(source, isNot(contains("f['class'] as String")));
    expect(source, isNot(contains("d['months'] as int")));
  });

  test('admin payment requests use routed review screens and decision API', () {
    final adminFees = File(
      'lib/presentation/admin_fees_screen/admin_fees_screen.dart',
    ).readAsStringSync();
    final requestsScreen = File(
      'lib/presentation/admin_fees_screen/admin_payment_requests_screen.dart',
    ).readAsStringSync();
    final decisionScreen = File(
      'lib/presentation/admin_fees_screen/admin_payment_request_decision_screen.dart',
    ).readAsStringSync();
    final routes = File('lib/routes/app_routes.dart').readAsStringSync();
    final guard = File('lib/routes/route_access_guard.dart').readAsStringSync();
    final api = File('lib/services/backend_api_client.dart').readAsStringSync();

    expect(adminFees, contains('AppRoutes.adminPaymentRequests'));
    expect(routes, contains('adminPaymentRequests'));
    expect(routes, contains('AdminPaymentRequestsScreen'));
    expect(routes, contains('AdminPaymentRequestDecisionScreen'));
    expect(guard, contains('AppRoutes.adminPaymentRequests: {\'admin\'}'));
    expect(requestsScreen, contains('getParentPaymentRequests('));
    expect(requestsScreen, contains('AppRoutes.adminPaymentRequestDecision'));
    expect(decisionScreen, contains('decideParentPaymentRequest('));
    expect(
      api,
      contains('Future<Map<String, dynamic>> decideParentPaymentRequest'),
    );
    expect(requestsScreen, isNot(contains('showDialog(')));
    expect(decisionScreen, isNot(contains('showDialog(')));
  });

  test(
    'admin fee write actions use routed input screens without popup forms',
    () {
      final adminFees = File(
        'lib/presentation/admin_fees_screen/admin_fees_screen.dart',
      ).readAsStringSync();
      final feeForms = File(
        'lib/presentation/admin_fees_screen/admin_fee_form_screens.dart',
      ).readAsStringSync();
      final routes = File('lib/routes/app_routes.dart').readAsStringSync();
      final guard = File(
        'lib/routes/route_access_guard.dart',
      ).readAsStringSync();
      final registry = File(
        'lib/routes/schooldesk_screen_registry.dart',
      ).readAsStringSync();

      expect(adminFees, contains('AppRoutes.adminFeeStructureForm'));
      expect(adminFees, contains('AppRoutes.adminInvoiceGenerationForm'));
      expect(adminFees, contains('AppRoutes.adminPaymentRecordForm'));
      expect(adminFees, isNot(contains('_showCreateFeeStructureDialog')));
      expect(adminFees, isNot(contains('_showGenerateInvoiceDialog')));
      expect(adminFees, isNot(contains('_showRecordPaymentDialog')));
      expect(adminFees, isNot(contains('_showEditFeeDialog')));
      expect(adminFees, isNot(contains('showDialog(')));
      expect(feeForms, contains('AdminFeeStructureFormScreen'));
      expect(feeForms, contains('AdminInvoiceGenerationFormScreen'));
      expect(feeForms, contains('AdminPaymentRecordFormScreen'));
      expect(feeForms, contains("createRaw('/fees/structures'"));
      expect(feeForms, contains("createRaw('/fees/invoices/generate'"));
      expect(feeForms, contains('recordPayment('));
      expect(feeForms, isNot(contains('showDialog(')));
      expect(routes, contains('adminFeeStructureForm'));
      expect(routes, contains('adminInvoiceGenerationForm'));
      expect(routes, contains('adminPaymentRecordForm'));
      expect(guard, contains('AppRoutes.adminFeeStructureForm: {\'admin\'}'));
      expect(
        guard,
        contains('AppRoutes.adminInvoiceGenerationForm: {\'admin\'}'),
      );
      expect(guard, contains('AppRoutes.adminPaymentRecordForm: {\'admin\'}'));
      expect(registry, contains('/admin-fees-screen/structures/form'));
      expect(registry, contains('/admin-fees-screen/invoices/generate'));
      expect(registry, contains('/admin-fees-screen/payments/record'));
    },
  );

  test('parent payment requests use routed input screen without popup form', () {
    final parentFees = File(
      'lib/presentation/parent_fees_screen/parent_fees_screen.dart',
    ).readAsStringSync();
    final paymentForm = File(
      'lib/presentation/parent_fees_screen/parent_payment_request_form_screen.dart',
    ).readAsStringSync();
    final routes = File('lib/routes/app_routes.dart').readAsStringSync();
    final guard = File('lib/routes/route_access_guard.dart').readAsStringSync();
    final registry = File(
      'lib/routes/schooldesk_screen_registry.dart',
    ).readAsStringSync();

    expect(parentFees, contains('AppRoutes.parentPaymentRequestForm'));
    expect(parentFees, isNot(contains('_showPaymentDialog')));
    expect(parentFees, isNot(contains('showDialog(')));
    expect(paymentForm, contains('class ParentPaymentRequestFormScreen'));
    expect(paymentForm, contains('submitParentPaymentRequest'));
    expect(paymentForm, contains('PaymentRequest('));
    expect(paymentForm, isNot(contains('showDialog(')));
    expect(routes, contains('parentPaymentRequestForm'));
    expect(routes, contains('ParentPaymentRequestFormScreen'));
    expect(guard, contains('AppRoutes.parentPaymentRequestForm: {\'parent\'}'));
    expect(registry, contains('/parent-fees-screen/payment'));
  });

  test('admin timetable mutations persist through backend slot APIs', () {
    final source = File(
      'lib/presentation/admin_timetable_screen/admin_timetable_screen.dart',
    ).readAsStringSync();
    final forms = File(
      'lib/presentation/admin_timetable_screen/admin_timetable_form_screens.dart',
    ).readAsStringSync();
    final routes = File('lib/routes/app_routes.dart').readAsStringSync();
    final guard = File('lib/routes/route_access_guard.dart').readAsStringSync();
    final registry = File(
      'lib/routes/schooldesk_screen_registry.dart',
    ).readAsStringSync();

    expect(source, contains('AppRoutes.adminTimetableGenerationForm'));
    expect(source, contains('AppRoutes.adminTimetablePeriodForm'));
    expect(source, contains('AppRoutes.adminTimetableSubstitutionForm'));
    expect(source, isNot(contains('_showGenerateTimetableDialog')));
    expect(source, isNot(contains('_showAddPeriodDialog')));
    expect(source, isNot(contains('_showEditPeriodDialog')));
    expect(source, isNot(contains('_showSubstituteDialog')));
    expect(source, isNot(contains('showDialog(')));
    expect(source, isNot(contains('rootNavigator: true')));
    expect(source, contains("deleteRaw('/timetable/slots/\$id'"));

    expect(forms, contains('AdminTimetableGenerationFormScreen'));
    expect(forms, contains('AdminTimetablePeriodFormScreen'));
    expect(forms, contains('AdminTimetableSubstitutionFormScreen'));
    expect(forms, contains('suggestTimetableSlots('));
    expect(forms, contains('generateTimetableSlots('));
    expect(forms, contains("createRaw('/timetable/slots'"));
    expect(forms, contains('updateRaw('));
    expect(forms, contains("'/timetable/slots/\$id'"));
    expect(forms, contains("createRaw('/timetable/substitutions'"));
    expect(forms, contains("'timetable_slot_id':"));
    expect(forms, contains("'substitute_staff_id':"));
    expect(forms, isNot(contains('showDialog(')));
    expect(forms, isNot(contains("'slot_id':")));
    expect(forms, isNot(contains("'substitute_name':")));

    expect(routes, contains('adminTimetableGenerationForm'));
    expect(routes, contains('AdminTimetableGenerationFormScreen'));
    expect(routes, contains('adminTimetablePeriodForm'));
    expect(routes, contains('AdminTimetablePeriodFormScreen'));
    expect(routes, contains('adminTimetableSubstitutionForm'));
    expect(routes, contains('AdminTimetableSubstitutionFormScreen'));
    expect(
      guard,
      contains('AppRoutes.adminTimetableGenerationForm: {\'admin\'}'),
    );
    expect(guard, contains('AppRoutes.adminTimetablePeriodForm: {\'admin\'}'));
    expect(
      guard,
      contains('AppRoutes.adminTimetableSubstitutionForm: {\'admin\'}'),
    );
    expect(registry, contains('/admin-timetable-screen/generate'));
    expect(registry, contains('/admin-timetable-screen/period'));
    expect(registry, contains('/admin-timetable-screen/substitution'));
    expect(source, isNot(contains("'slot_id':")));
    expect(source, isNot(contains("'substitute_name':")));
  });

  test('classes expose real class-teacher assignments from sections', () {
    final api = File('lib/services/backend_api_client.dart').readAsStringSync();
    final data = File(
      'lib/services/backend_data_service.dart',
    ).readAsStringSync();
    final academicScreen = File(
      'lib/presentation/academic_management_screen/academic_management_screen.dart',
    ).readAsStringSync();
    final academicForms = File(
      'lib/presentation/academic_management_screen/academic_management_form_screens.dart',
    ).readAsStringSync();
    final timetableScreen = File(
      'lib/presentation/admin_timetable_screen/admin_timetable_screen.dart',
    ).readAsStringSync();

    expect(api, contains('final String classTeacherId;'));
    expect(api, contains('final String classTeacherName;'));
    expect(api, contains("json['class_teacher_id']"));
    expect(api, contains("json['class_teacher']"));
    expect(data, contains("'class_teacher_id': classTeacherId"));
    expect(data, contains("'classTeacherId': classTeacherIds.length == 1"));
    expect(data, isNot(contains("'classTeacher': '',")));
    expect(academicScreen, contains('AppRoutes.academicClassForm'));
    expect(academicForms, contains('DropdownButtonFormField<String>'));
    expect(academicForms, contains("'classTeacherId': _teacherId"));
    expect(timetableScreen, contains('classTeacherName'));
    expect(timetableScreen, contains('Class teacher:'));
    expect(timetableScreen, isNot(contains('gradeId.substring')));
  });

  test('admin attendance classes and exports are backend-derived', () {
    final source = File(
      'lib/presentation/admin_attendance_screen/admin_attendance_screen.dart',
    ).readAsStringSync();

    expect(source, isNot(contains("String _selectedClass = 'Class 5A'")));
    expect(source, isNot(contains("'Class 10B'")));
    expect(source, contains('BackendApiClient.instance.getSections()'));
    expect(source, contains("createReportExport("));
    expect(source, contains("'/attendance/reports/exports'"));
  });

  test(
    'admin exams render backend schedules and avoid fake local-only actions',
    () {
      final source = File(
        'lib/presentation/admin_exams_screen/admin_exams_screen.dart',
      ).readAsStringSync();
      final forms = File(
        'lib/presentation/admin_exams_screen/admin_exam_form_screens.dart',
      ).readAsStringSync();
      final api = File(
        'lib/services/backend_api_client.dart',
      ).readAsStringSync();
      final routes = File('lib/routes/app_routes.dart').readAsStringSync();
      final guard = File(
        'lib/routes/route_access_guard.dart',
      ).readAsStringSync();
      final registry = File(
        'lib/routes/schooldesk_screen_registry.dart',
      ).readAsStringSync();
      final main = File('school-backend/main.go').readAsStringSync();

      expect(source, contains("getRawList("));
      expect(source, contains("'/exams/schedules'"));
      expect(source, contains('AppRoutes.adminExamForm'));
      expect(source, contains('AppRoutes.adminExamScheduleForm'));
      expect(source, contains('getAcademicYears()'));
      expect(source, contains('getExamTypes()'));
      expect(source, contains('getGrades()'));
      expect(source, contains('getSections()'));
      expect(source, contains("getRawList('/subjects'"));
      expect(source, contains('setExamPublished('));
      expect(source, contains('String _classLabelForSchedules('));
      expect(source, contains('String _formatDate('));
      expect(source, isNot(contains('_showAddExamDialog')));
      expect(source, isNot(contains('_showEditExamDialog')));
      expect(source, isNot(contains('showDialog(')));
      expect(source, isNot(contains("'Class 5A'")));
      expect(source, isNot(contains('schedule published')));
      expect(source, isNot(contains('terms.first')));
      expect(source, isNot(contains('examTypes.first')));
      expect(forms, contains('AdminExamFormScreen'));
      expect(forms, contains('AdminExamScheduleFormScreen'));
      expect(forms, contains('createExam('));
      expect(forms, contains('updateExam('));
      expect(forms, contains("createRaw('/exams/schedules'"));
      expect(forms, contains("'exam_id': _examId"));
      expect(forms, contains("'grade_id': _gradeId"));
      expect(forms, contains("'section_id': _sectionId"));
      expect(forms, contains("'subject_id': _subjectId"));
      expect(forms, isNot(contains('showDialog(')));
      expect(api, contains('Future<void> updateExam('));
      expect(api, contains('Future<void> setExamPublished('));
      expect(routes, contains('adminExamForm'));
      expect(routes, contains('AdminExamFormScreen'));
      expect(routes, contains('adminExamScheduleForm'));
      expect(routes, contains('AdminExamScheduleFormScreen'));
      expect(guard, contains('AppRoutes.adminExamForm: {\'admin\'}'));
      expect(guard, contains('AppRoutes.adminExamScheduleForm: {\'admin\'}'));
      expect(registry, contains('/admin-exams-screen/form'));
      expect(registry, contains('/admin-exams-screen/schedule'));
      expect(main, contains('examHandler.UpdateExam'));
      expect(main, contains('examHandler.PublishExam'));
      expect(source, contains('_AdminExamTypeFormPage'));
      expect(source, contains("createRaw('/exams/types'"));
      expect(source, contains("getRawList('/exams/report-cards'"));
      expect(source, isNot(contains('Seating plan API is not exposed yet')));
      expect(
        source,
        isNot(contains('Hall ticket generation API is not exposed yet')),
      );
    },
  );
}
