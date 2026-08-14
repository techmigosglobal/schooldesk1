import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'backend_api_sources.dart';

import 'backend_route_sources.dart';

void main() {
  test(
    'student write contracts expose principal direct and admin approval paths',
    () {
      final main = readBackendRouteSources();

      expect(
        main,
        contains('students.PUT("/:id", middleware.RBACMiddleware("Principal")'),
      );
      expect(main, contains('studentHandler.UpdateStudent'));
      expect(
        main,
        contains(
          'students.POST("/enrollments", middleware.RBACMiddleware("Principal")',
        ),
      );
      expect(main, contains('studentHandler.CreateEnrollment'));
      expect(
        main,
        contains(
          'studentApprovals.POST("", middleware.RBACMiddleware("Principal"), middleware.RateLimitMiddleware("student_write"',
        ),
      );
      expect(
        main,
        contains(
          'attendance.POST("/staff", middleware.RBACMiddleware("Principal")',
        ),
      );
      expect(main, contains('attendanceHandler.MarkStaffAttendance'));
      expect(
        main,
        contains(
          'fees.POST("/invoices", middleware.RBACMiddleware("Principal"), middleware.RateLimitMiddleware("fee_write"',
        ),
      );
    },
  );

  test('admin finance screen normalizes backend fee and invoice shapes', () {
    final source = File(
      'lib/features/finance/presentation/screens/admin_fees_screen/admin_fees_screen.dart',
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
      'lib/features/finance/presentation/screens/admin_fees_screen/admin_fees_screen.dart',
    ).readAsStringSync();
    final requestsScreen = File(
      'lib/features/finance/presentation/screens/admin_fees_screen/admin_payment_requests_screen.dart',
    ).readAsStringSync();
    final decisionScreen = File(
      'lib/features/finance/presentation/screens/admin_fees_screen/admin_payment_request_decision_screen.dart',
    ).readAsStringSync();
    final routes = File('lib/routes/app_routes.dart').readAsStringSync();
    final guard = File('lib/routes/route_access_guard.dart').readAsStringSync();
    final api = readBackendApiSources();

    expect(adminFees, contains('AppRoutes.principalPaymentRequests'));
    expect(routes, contains('principalPaymentRequests'));
    expect(routes, contains('PrincipalPaymentRequests'));
    expect(routes, contains('AdminPaymentRequestDecisionScreen'));
    expect(
      guard,
      contains('AppRoutes.principalPaymentRequests: {\'principal\'}'),
    );
    expect(requestsScreen, contains('getParentPaymentRequests('));
    expect(
      requestsScreen,
      contains('AppRoutes.principalPaymentRequestDecision'),
    );
    expect(
      requestsScreen,
      contains('pushReplacementNamed(AppRoutes.feeMonitoring)'),
    );
    expect(decisionScreen, contains('decideParentPaymentRequest('));
    expect(
      api,
      contains('Future<Map<String, dynamic>> decideParentPaymentRequest'),
    );
    expect(requestsScreen, isNot(contains('showDialog(')));
    expect(decisionScreen, isNot(contains('showDialog(')));
  });

  test(
    'admin fee structure and direct collection actions use routed input screens without popup forms',
    () {
      final adminFees = File(
        'lib/features/finance/presentation/screens/admin_fees_screen/admin_fees_screen.dart',
      ).readAsStringSync();
      final feeForms = File(
        'lib/features/finance/presentation/screens/admin_fees_screen/admin_fee_form_screens.dart',
      ).readAsStringSync();
      final routes = File('lib/routes/app_routes.dart').readAsStringSync();
      final guard = File(
        'lib/routes/route_access_guard.dart',
      ).readAsStringSync();
      final registry = File(
        'lib/routes/schooldesk_screen_registry.dart',
      ).readAsStringSync();

      expect(adminFees, contains('AppRoutes.principalFeeStructureForm'));
      expect(adminFees, contains('AppRoutes.principalPaymentRecordForm'));
      expect(adminFees, contains('AdminFeeStructureFormArgs'));
      expect(adminFees, contains('AdminPaymentRecordFormArgs'));
      expect(
        adminFees,
        isNot(contains('AppRoutes.principalInvoiceGenerationForm')),
      );
      expect(adminFees, isNot(contains('AdminInvoiceGenerationFormArgs')));
      expect(adminFees, isNot(contains('_showCreateFeeStructureDialog')));
      expect(adminFees, isNot(contains('_showGenerateInvoiceDialog')));
      expect(adminFees, isNot(contains('_showRecordPaymentDialog')));
      expect(adminFees, isNot(contains('_showEditFeeDialog')));
      expect(adminFees, isNot(contains('showDialog(')));
      expect(feeForms, contains('AdminFeeStructureFormScreen'));
      expect(feeForms, contains('AdminPaymentRecordFormScreen'));
      expect(feeForms, contains('createFeeStructure('));
      expect(feeForms, contains('recordPayment('));
      expect(feeForms, isNot(contains('showDialog(')));
      expect(routes, contains('principalFeeStructureForm'));
      expect(routes, contains('AdminFeeStructureFormScreen'));
      expect(routes, contains('principalPaymentRecordForm'));
      expect(routes, contains('AdminPaymentRecordFormScreen'));
      expect(
        guard,
        contains('AppRoutes.principalFeeStructureForm: {\'principal\'}'),
      );
      expect(registry, contains('/principal-fees-screen/fee-structure'));
      expect(registry, contains('/principal-fees-screen/payment-record'));
    },
  );

  test('parent payment requests use routed input screen without popup form', () {
    final parentFees = File(
      'lib/features/finance/presentation/screens/parent_hub/parent_fee_hub.dart',
    ).readAsStringSync();
    final paymentForm = File(
      'lib/features/finance/presentation/screens/parent_hub/parent_payment_flow.dart',
    ).readAsStringSync();
    final routes = File('lib/routes/app_routes.dart').readAsStringSync();
    final guard = File('lib/routes/route_access_guard.dart').readAsStringSync();
    final registry = File(
      'lib/routes/schooldesk_screen_registry.dart',
    ).readAsStringSync();

    expect(parentFees, contains("'/parent/payment-flow'"));
    expect(parentFees, contains('SingleChildScrollView('));
    expect(parentFees, contains('ParentChildSelector('));
    expect(parentFees, isNot(contains('_showPaymentDialog')));
    expect(parentFees, isNot(contains('showDialog(')));
    expect(paymentForm, contains('class ParentPaymentFlow'));
    expect(paymentForm, contains('submitParentPaymentRequestProof'));
    expect(paymentForm, contains('resubmitFeePaymentProof'));
    expect(paymentForm, contains('Confirm'));
    expect(paymentForm, contains('Submit Verification Request'));
    // Pay Now label replaced with Submit Payment for Verification in current UX
    expect(paymentForm, isNot(contains('showDialog(')));
    expect(routes, contains('parentPaymentRequestForm'));
    expect(routes, contains('parentPaymentSelection'));
    expect(routes, isNot(contains('parentPaymentProcessing')));
    expect(routes, contains('ParentPaymentFlow'));
    expect(guard, contains('AppRoutes.parentPaymentRequestForm: {\'parent\'}'));
    expect(registry, contains('/parent-fees-screen/payment'));
    expect(registry, contains('/parent-fees-screen/payment-selection'));
    expect(registry, contains('/parent-fees-screen/payment-processing'));
  });

  test(
    'principal and coordinator timetable routes stay on approved backend paths',
    () {
      final source = File(
        'lib/features/academics/presentation/screens/admin_timetable_screen/admin_timetable_screen.dart',
      ).readAsStringSync();
      final routes = File('lib/routes/app_routes.dart').readAsStringSync();
      final guard = File(
        'lib/routes/route_access_guard.dart',
      ).readAsStringSync();
      final registry = File(
        'lib/routes/schooldesk_screen_registry.dart',
      ).readAsStringSync();

      expect(source, contains('Create Timetable'));
      expect(source, contains('Timetable Management'));
      expect(source, contains('DropdownButtonFormField<String>'));
      expect(source, contains('_buildEditor'));
      expect(source, contains('Future<void> _save('));
      expect(source, contains('_validateRows'));
      expect(source, contains('replaceTimetableDays'));

      expect(routes, isNot(contains('adminTimetableGenerationForm')));
      expect(routes, isNot(contains('AdminTimetableGenerationFormScreen')));
      expect(routes, isNot(contains('adminTimetablePeriodForm')));
      expect(routes, isNot(contains('AdminTimetablePeriodFormScreen')));
      expect(routes, isNot(contains('adminTimetableSubstitutionForm')));
      expect(routes, isNot(contains('AdminTimetableSubstitutionFormScreen')));
      expect(guard, isNot(contains('AppRoutes.adminTimetableGenerationForm')));
      expect(guard, isNot(contains('AppRoutes.adminTimetablePeriodForm')));
      expect(
        guard,
        isNot(contains('AppRoutes.adminTimetableSubstitutionForm')),
      );
      expect(registry, isNot(contains('/admin-timetable-screen/generate')));
      expect(registry, isNot(contains('/admin-timetable-screen/period')));
      expect(registry, isNot(contains('/admin-timetable-screen/substitution')));
      expect(source, isNot(contains("'slot_id':")));
      expect(source, isNot(contains("'substitute_name':")));
    },
  );

  test('classes expose real class-teacher assignments from sections', () {
    final api = readBackendApiSources();
    final data = File(
      'lib/core/services/backend_data_service.dart',
    ).readAsStringSync();
    final academicScreen = File(
      'lib/features/academics/presentation/screens/academic_management_screen/academic_management_screen.dart',
    ).readAsStringSync();
    final academicForms = File(
      'lib/features/academics/presentation/screens/academic_management_screen/academic_management_form_screens.dart',
    ).readAsStringSync();
    final timetableScreen = File(
      'lib/features/academics/presentation/screens/admin_timetable_screen/admin_timetable_screen.dart',
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
    expect(timetableScreen, contains('_subjectOptionsForSelectedClass'));
    expect(timetableScreen, contains('_selectedClassLabel'));
    expect(timetableScreen, isNot(contains('gradeId.substring')));
  });

  test('admin attendance classes and exports are backend-derived', () {
    final source = File(
      'lib/features/attendance/presentation/screens/admin_attendance_screen/admin_attendance_screen.dart',
    ).readAsStringSync();

    expect(source, isNot(contains("String _selectedClass = 'Class 5A'")));
    expect(source, isNot(contains("'Class 10B'")));
    expect(source, contains('BackendApiClient.instance.getSections()'));
    expect(source, contains("createReportExport("));
    expect(source, contains("'/attendance/reports/exports'"));
  });

  test('retired admin exam screens and API routes remain unavailable', () {
    final api = readBackendApiSources();
    final routes = File('lib/routes/app_routes.dart').readAsStringSync();
    final guard = File('lib/routes/route_access_guard.dart').readAsStringSync();
    final registry = File(
      'lib/routes/schooldesk_screen_registry.dart',
    ).readAsStringSync();
    final main = readBackendRouteSources();

    expect(
      File(
        'lib/features/academics/presentation/screens/admin_exams_screen/admin_exams_screen.dart',
      ).existsSync(),
      isFalse,
    );
    expect(
      File(
        'lib/features/academics/presentation/screens/admin_exams_screen/admin_exam_form_screens.dart',
      ).existsSync(),
      isFalse,
    );
    expect(api, isNot(contains('Future<void> updateExam(')));
    expect(api, isNot(contains('Future<void> setExamPublished(')));
    expect(routes, isNot(contains('adminExamForm')));
    expect(routes, isNot(contains('AdminExamFormScreen')));
    expect(routes, isNot(contains('adminExamScheduleForm')));
    expect(routes, isNot(contains('AdminExamScheduleFormScreen')));
    expect(guard, isNot(contains('AppRoutes.adminExamForm')));
    expect(guard, isNot(contains('AppRoutes.adminExamScheduleForm')));
    expect(registry, isNot(contains('/admin-exams-screen/form')));
    expect(registry, isNot(contains('/admin-exams-screen/schedule')));
    expect(main, isNot(contains('examHandler.UpdateExam')));
    expect(main, isNot(contains('examHandler.PublishExam')));
    expect(main, isNot(contains('api.Group("/exams")')));
  });
}
