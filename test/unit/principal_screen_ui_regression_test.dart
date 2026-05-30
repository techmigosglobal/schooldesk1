import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:schooldesk1/core/constants/schooldesk_glossary.dart';

void main() {
  test('principal timetable keeps tabs and weekday selector accessible', () {
    final source = File(
      'lib/presentation/timetable_management_screen/timetable_management_screen.dart',
    ).readAsStringSync();

    expect(source, contains('TabController(length: 3'));
    expect(source, contains('Widget _buildDaySelector()'));
    expect(source, contains('Semantics('));
    expect(source, contains('Tooltip('));
    expect(source, contains('BoxConstraints(minHeight: 44'));
  });

  test('principal timetable guards backend ids before dropdown selection', () {
    final source = File(
      'lib/presentation/timetable_management_screen/timetable_management_screen.dart',
    ).readAsStringSync();

    expect(source, contains('int _intValue(dynamic value'));
    expect(source, contains("if (!_subjects.contains(selectedSubject))"));
    expect(source, contains("if (!_teachers.contains(selectedTeacher))"));
  });

  test('fee monitoring concession cards use backend field names safely', () {
    final source = File(
      'lib/presentation/fee_monitoring_screen/fee_monitoring_screen.dart',
    ).readAsStringSync();

    expect(source, isNot(contains("c['student']")));
    expect(source, isNot(contains("c['class']")));
    expect(source, isNot(contains("c['date']")));
  });

  test(
    'fee monitoring exposes principal fee operations on backend contracts',
    () {
      final source = File(
        'lib/presentation/fee_monitoring_screen/fee_monitoring_screen.dart',
      ).readAsStringSync();

      expect(source, contains('Fee Dashboard'));
      expect(source, contains("String _selectedView = 'Overview'"));
      expect(
        source,
        contains('List<Map<String, dynamic>> _recentPayments = [];'),
      );
      expect(
        source,
        contains('feeStructures.map(_normalizeFeeStructure).toList()'),
      );
      expect(source, contains('studentFees.map(_normalizeInvoice).toList()'));
      expect(
        source,
        contains('studentFees.expand(_normalizePayments).toList()'),
      );
      expect(source, contains('PrincipalDirectoryScaffold'));
      expect(source, contains('PrincipalDirectoryChip'));
      expect(source, contains("createRaw('/fees/structures'"));
      expect(source, contains("createRaw('/fees/invoices/generate'"));
      expect(source, contains('class _ManualFeeEntrySheet'));
      expect(source, contains('class _CashPaymentPage'));
      expect(source, contains('class _FeeInvoiceDetailPage'));
      expect(source, contains('class _PaymentEntryForm'));
      expect(source, contains('Add Student Fee Entry'));
      expect(source, contains("'discount_amount': _discount"));
      expect(source, contains("'net_amount': _payable"));
      expect(source, contains('Collect Payment'));
      expect(source, contains('Total Collection'));
      expect(source, contains('Fees Pending'));
      expect(source, contains('Today Collection'));
      expect(source, contains('Quick Actions'));
      expect(source, contains("paymentMode: 'cash'"));
      expect(source, contains('BackendApiClient.instance.recordPayment'));
      expect(source, contains('_printReceiptFromInvoice'));
      expect(source, contains('Widget _buildDirectoryQuickActions()'));
      expect(source, contains('Widget _buildDirectoryMetrics()'));
      expect(source, contains('_FeeDashboardMetricCard'));
      expect(source, contains('for (final classValue in classes)'));
      expect(source, contains('for (final status in _statusFilters)'));
      expect(source, contains('PopupMenuButton<String>'));
      expect(source, contains("tooltip: 'Fee options'"));
      expect(source, contains('PrincipalInputPage'));
      expect(source, contains('PrincipalDirectoryCard'));
    },
  );

  test(
    'fee monitoring class filters keep readable selected and unselected states',
    () {
      final source = File(
        'lib/presentation/fee_monitoring_screen/fee_monitoring_screen.dart',
      ).readAsStringSync();

      expect(source, contains('PrincipalDirectoryChip'));
      expect(source, contains("classValue == 'All Classes'"));
      expect(source, contains("_selectedClass = classValue == 'All Classes'"));
      expect(
        source,
        contains("label: status == 'All' ? 'All Status' : status"),
      );
      expect(source, contains('selected: _selectedStatus == status'));
      expect(source, contains('setState(() => _selectedStatus = status)'));
    },
  );

  test('principal classes UI is HTML-backed and class APIs stay reusable', () {
    final screenFile = File(
      'lib/presentation/principal_classes_screen/principal_classes_screen.dart',
    );
    final screen = screenFile.readAsStringSync();
    final client = File(
      'lib/services/backend_api_client.dart',
    ).readAsStringSync();
    final backendRoutes = File('school-backend/main.go').readAsStringSync();

    expect(screenFile.existsSync(), isTrue);
    expect(screen, contains('Existing Classes'));
    expect(screen, contains('Create New Class'));
    expect(screen, contains('Classes Directory'));
    expect(screen, contains('Approvals & Notes'));
    expect(screen, contains('PrincipalPreviewBottomNav'));
    expect(screen, contains('getPrincipalClassesOverview()'));
    expect(client, contains('createPrincipalClass'));
    expect(backendRoutes, contains('principal.POST("/classes"'));
    expect(
      backendRoutes,
      contains('principal.GET("/classes", principalClassesHandler.Overview)'),
    );
  });

  test('principal student module exposes backend summaries and web uploads', () {
    final screen = File(
      'lib/presentation/student_oversight_screen/student_oversight_screen.dart',
    ).readAsStringSync();
    final client = File(
      'lib/services/backend_api_client.dart',
    ).readAsStringSync();
    final backend = File(
      'school-backend/internal/handlers/student.go',
    ).readAsStringSync();

    expect(backend, contains('"attendance_summary"'));
    expect(backend, contains('"fee_summary"'));
    expect(backend, contains('"performance_summary"'));
    expect(backend, contains('"parent_accounts"'));
    expect(backend, contains('school_id = ? AND "+column+" = ?'));
    expect(client, contains('Uint8List? fileBytes'));
    expect(client, contains('MultipartFile.fromBytes'));
    expect(client, contains('if ((admissionDate ?? \'\').trim().isNotEmpty)'));
    expect(screen, contains('title: \'Parent / Guardian\''));
    expect(screen, contains('title: \'Fee Position\''));
    expect(screen, contains('title: \'Academic Performance\''));
    expect(screen, contains('title: \'Documents\''));
    expect(screen, contains('title: \'Medical Notes\''));
    expect(screen, contains('share_plus.XFile.fromData'));
    expect(screen, isNot(contains('Enter first and last name')));
  });

  test('principal user management creates and manages linked staff accounts', () {
    final screen = File(
      'lib/presentation/admin_user_access_screen/admin_user_access_screen.dart',
    ).readAsStringSync();
    final accountForm = File(
      'lib/presentation/admin_user_access_screen/account_access_form_screen.dart',
    ).readAsStringSync();
    final childAssignment = File(
      'lib/presentation/admin_user_access_screen/account_child_assignment_screen.dart',
    ).readAsStringSync();
    final client = File(
      'lib/services/backend_api_client.dart',
    ).readAsStringSync();
    final backend = File(
      'school-backend/internal/handlers/user.go',
    ).readAsStringSync();

    expect(backend, contains('"linked_type":'));
    expect(backend, contains('"linked_id":'));
    expect(client, contains('final String linkedType;'));
    expect(client, contains('final String linkedId;'));
    expect(accountForm, contains('_isStaffManagedRole(_role)'));
    expect(accountForm, contains('BackendApiClient.instance.createStaff'));
    expect(accountForm, contains('BackendApiClient.instance.updateStaff'));
    expect(screen, contains('BackendApiClient.instance.deleteStaff'));
    expect(screen, contains('AccountAccessFormArgs'));
    expect(screen, contains('AccountChildAssignmentArgs'));
    expect(
      childAssignment,
      contains('BackendApiClient.instance.assignParentStudents'),
    );
    expect(screen, contains("'staffId': u.linkedId"));
  });

  test('account access input flows use routed screens instead of dialogs', () {
    final screen = File(
      'lib/presentation/admin_user_access_screen/admin_user_access_screen.dart',
    ).readAsStringSync();
    final routes = File('lib/routes/app_routes.dart').readAsStringSync();
    final accountForm = File(
      'lib/presentation/admin_user_access_screen/account_access_form_screen.dart',
    ).readAsStringSync();
    final childAssignment = File(
      'lib/presentation/admin_user_access_screen/account_child_assignment_screen.dart',
    ).readAsStringSync();

    expect(screen, isNot(contains('_showAddUserDialog')));
    expect(screen, isNot(contains('_showUserDialog')));
    expect(screen, isNot(contains('_showAssignChildrenDialog')));
    expect(screen, contains('Navigator.pushNamed'));
    expect(routes, contains('adminAccountCreate'));
    expect(routes, contains('principalAccountCreate'));
    expect(routes, contains('adminParentChildAssignment'));
    expect(routes, contains('principalParentChildAssignment'));
    expect(accountForm, contains('class AccountAccessFormScreen'));
    expect(accountForm, contains('SchoolDeskModuleScaffold'));
    expect(childAssignment, contains('class AccountChildAssignmentScreen'));
  });

  test('academic management uses explicit backend academic year workflow', () {
    final screen = File(
      'lib/presentation/academic_management_screen/academic_management_screen.dart',
    ).readAsStringSync();
    final forms = File(
      'lib/presentation/academic_management_screen/academic_management_form_screens.dart',
    ).readAsStringSync();
    final client = File(
      'lib/services/backend_api_client.dart',
    ).readAsStringSync();
    final service = File(
      'lib/services/backend_data_service.dart',
    ).readAsStringSync();
    final routes = File('lib/routes/app_routes.dart').readAsStringSync();

    expect(client, contains('Future<AcademicYearModel> createAcademicYear'));
    expect(client, contains('Future<AcademicYearModel> updateAcademicYear'));
    expect(service, contains('Future<void> saveAcademicYearRecord'));
    expect(service, contains("await _api.createRaw('/academic-years'"));
    expect(screen, contains('AppRoutes.academicYearForm'));
    expect(screen, contains('AppRoutes.academicSubjectForm'));
    expect(screen, contains('AppRoutes.academicClassForm'));
    expect(screen, contains('AppRoutes.academicCurriculumForm'));
    expect(screen, contains('BackendApiClient.instance.updateAcademicYear'));
    expect(screen, isNot(contains('_showAddYearDialog')));
    expect(screen, isNot(contains('_showEditYearDialog')));
    expect(screen, isNot(contains('_showAddSubjectDialog')));
    expect(screen, isNot(contains('_showEditSubjectDialog')));
    expect(screen, isNot(contains('_showAddClassDialog')));
    expect(screen, isNot(contains('_showEditClassDialog')));
    expect(screen, isNot(contains('_showAddCurriculumDialog')));
    expect(screen, isNot(contains('_showEditCurriculumDialog')));
    expect(forms, contains('AcademicYearFormScreen'));
    expect(forms, contains('AcademicSubjectFormScreen'));
    expect(forms, contains('AcademicClassFormScreen'));
    expect(forms, contains('AcademicCurriculumFormScreen'));
    expect(forms, contains('storage.saveAcademicYearRecord'));
    expect(forms, contains('storage.saveAcademicSubjectRecord'));
    expect(forms, contains('storage.saveAcademicClassRecord'));
    expect(forms, contains('storage.saveAcademicCurriculumRecord'));
    expect(forms, isNot(contains('showDialog(')));
    expect(routes, contains('academicYearForm'));
    expect(routes, contains('academicSubjectForm'));
    expect(routes, contains('academicClassForm'));
    expect(routes, contains('academicCurriculumForm'));
  });

  test('principal drawer does not show hardcoded workflow badges', () {
    final source = File('lib/widgets/app_navigation.dart').readAsStringSync();

    expect(source, isNot(contains('badgeCount: 5')));
    expect(source, isNot(contains('badgeCount: 3')));
  });

  test('principal drawer exposes academic management from records section', () {
    final source = File('lib/widgets/app_navigation.dart').readAsStringSync();
    final registry = File(
      'lib/routes/schooldesk_screen_registry.dart',
    ).readAsStringSync();
    final availability = File(
      'lib/services/feature_availability_service.dart',
    ).readAsStringSync();

    expect(source, isNot(contains("label: 'Staff Management'")));
    expect(source, isNot(contains("label: 'Student Management'")));
    expect(source, isNot(contains("label: 'User Management'")));
    expect(source, contains('label: SchoolDeskGlossary.timetableRecords'));
    expect(source, contains('label: SchoolDeskGlossary.academicManagement'));
    expect(source, contains('route: AppRoutes.academicManagement'));
    expect(registry, contains('feature: SchoolDeskFeature.syllabusRecords'));
    expect(availability, contains('SchoolDeskFeature.syllabusRecords'));
    expect(availability, contains("label: 'Syllabus records'"));
    expect(availability, contains('isAvailable: true'));
  });

  test('principal top bar notifications are backed by backend unread state', () {
    final source = File(
      'lib/presentation/principal_dashboard_screen/principal_dashboard_screen.dart',
    ).readAsStringSync();

    expect(source, contains('api.getNotifications()'));
    expect(source, contains('unreadNotifications'));
    expect(source, contains('class _HeaderNotificationButton'));
    expect(source, contains('Icons.notifications_none_rounded'));
    expect(source, contains('AppRoutes.notificationCenter'));
  });

  test('principal dashboard top banner and module grid are responsive', () {
    final dashboard = File(
      'lib/presentation/principal_dashboard_screen/principal_dashboard_screen.dart',
    ).readAsStringSync();

    expect(dashboard, contains('schoolBannerUrl'));
    expect(dashboard, contains('banner_url'));
    expect(dashboard, contains('class _SchoolIdentityBanner'));
    expect(dashboard, contains('constraints.maxWidth < 370'));
    expect(dashboard, contains('final columns = compact ? 2 : 3'));
    expect(dashboard, contains('crossAxisCount: columns'));
    expect(dashboard, contains('final textScale = MediaQuery.textScalerOf'));
    expect(dashboard, contains('final labelHeight ='));
    expect(dashboard, contains('.toDouble()'));
    expect(dashboard, contains('mainAxisExtent: tileExtent'));
    expect(dashboard, contains('maxLines: 2'));
    expect(dashboard, contains("label: 'Guided Assistant'"));
    expect(dashboard, contains('route: AppRoutes.guidedAssistant'));
    expect(
      dashboard,
      contains('SchoolDeskUiIllustrations.principalGuidedAssistant'),
    );
    expect(dashboard, contains('SchoolDeskUiIllustrations.principalStudents'));
    expect(dashboard, contains("label: 'Staff Management'"));
    expect(dashboard, contains("label: 'Guardians'"));
    expect(dashboard, contains("label: 'Class Hub'"));
    expect(dashboard, contains('route: AppRoutes.principalClasses'));
    expect(dashboard, contains("label: 'Attendance'"));
    expect(dashboard, contains('route: AppRoutes.principalAttendance'));
    expect(dashboard, contains("label: 'Subjects'"));
    expect(dashboard, contains("label: 'Timetable'"));
    expect(dashboard, contains("label: 'Exams'"));
    expect(dashboard, contains("label: 'Results'"));
    expect(dashboard, contains("label: 'Fees'"));
    expect(dashboard, contains('constraints.maxWidth < 340'));
    expect(dashboard, contains('SafeArea('));
    expect(dashboard, contains('height: 66'));

    for (final asset in <String>[
      'assets/images/ui/principal-students.svg',
      'assets/images/ui/principal-guided-assistant.svg',
      'assets/images/ui/principal-staff-management.svg',
      'assets/images/ui/principal-guardians.svg',
      'assets/images/ui/principal-classes.svg',
      'assets/images/ui/principal-subjects.svg',
      'assets/images/ui/principal-timetable.svg',
      'assets/images/ui/principal-exams.svg',
      'assets/images/ui/principal-results.svg',
      'assets/images/ui/principal-fees.svg',
      'assets/images/ui/principal-events.svg',
      'assets/images/ui/principal-inbox.svg',
    ]) {
      expect(File(asset).existsSync(), isTrue, reason: '$asset is missing');
    }
  });

  test(
    'principal academic cards include HTML-backed classes and attendance modules',
    () {
      final dashboard = File(
        'lib/presentation/principal_dashboard_screen/principal_dashboard_screen.dart',
      ).readAsStringSync();
      final routes = File('lib/routes/app_routes.dart').readAsStringSync();
      final guard = File(
        'lib/routes/route_access_guard.dart',
      ).readAsStringSync();

      expect(dashboard, contains('AppRoutes.principalClasses'));
      expect(routes, contains('static const String principalClasses'));
      expect(routes, contains('PrincipalClassesScreen'));
      expect(guard, contains("AppRoutes.principalClasses: {'principal'}"));

      expect(
        routes,
        contains(
          'principalTimetable: (context) => const PrincipalTimetableScreen()',
        ),
      );
      expect(
        routes,
        contains('principalExams: (context) => const PrincipalExamsScreen()'),
      );
      expect(
        routes,
        contains(
          'principalResults: (context) => const PrincipalResultsScreen()',
        ),
      );

      expect(dashboard, contains('AppRoutes.principalAttendance'));
      expect(routes, contains('static const String principalAttendance'));
      expect(routes, contains('PrincipalAttendanceScreen'));
      expect(guard, contains("AppRoutes.principalAttendance: {'principal'}"));
      expect(dashboard, contains('AppRoutes.guidedAssistant'));
      expect(routes, contains('static const String guidedAssistant'));
      expect(routes, contains('GuidedAssistantScreen'));
      expect(
        guard,
        contains("AppRoutes.guidedAssistant: {'principal', 'admin'}"),
      );

      for (final route in <String>[
        'principalTimetable',
        'principalExams',
        'principalResults',
      ]) {
        expect(dashboard, contains('AppRoutes.$route'));
        expect(routes, contains('static const String $route'));
        expect(guard, contains("AppRoutes.$route: {'principal'}"));
      }

      expect(dashboard, contains('route: AppRoutes.feeMonitoring'));
      expect(dashboard, contains('SchoolDeskUiIllustrations.principalFees'));
      expect(dashboard, contains('route: AppRoutes.principalInbox'));
      expect(dashboard, contains('pendingApprovals'));
    },
  );

  test('principal events and inbox use directory workflows', () {
    final events = File(
      'lib/presentation/events_calendar_screen/events_calendar_screen.dart',
    ).readAsStringSync();
    final inbox = File(
      'lib/presentation/principal_inbox_screen/principal_operational_inbox_screen.dart',
    ).readAsStringSync();
    final routes = File('lib/routes/app_routes.dart').readAsStringSync();
    final guard = File('lib/routes/route_access_guard.dart').readAsStringSync();
    final dashboard = File(
      'lib/presentation/principal_dashboard_screen/principal_dashboard_screen.dart',
    ).readAsStringSync();
    final appNavigation = File(
      'lib/widgets/app_navigation.dart',
    ).readAsStringSync();

    expect(events, contains('Events Directory'));
    expect(events, contains('PrincipalDirectoryScaffold'));
    expect(events, contains('Event Details'));
    expect(events, contains('Create Event'));
    expect(events, contains("createRaw('/events'"));
    expect(events, contains("updateRaw('/events/\$eventId'"));
    expect(events, contains("deleteRaw('/events/\${event.id}'"));
    expect(inbox, contains('Operational Inbox'));
    expect(inbox, contains('NotificationService.getInstance'));
    expect(inbox, contains("getRawList(source.path)"));
    expect(inbox, contains("'/events/approvals'"));
    expect(inbox, contains('decideLeaveApplication'));
    expect(inbox, contains('markAsRead'));
    expect(routes, contains('static const String principalInbox'));
    expect(routes, contains('PrincipalOperationalInboxScreen'));
    expect(guard, contains("AppRoutes.principalInbox: {'principal'}"));
    expect(dashboard, contains('route: AppRoutes.principalInbox'));
    expect(appNavigation, contains('route: AppRoutes.principalInbox'));
  });

  test(
    'principal attendance UI uses directory workflow while backend remains wired',
    () {
      final screenFile = File(
        'lib/presentation/principal_attendance_screen/principal_attendance_screen.dart',
      );
      final routes = File('lib/routes/app_routes.dart').readAsStringSync();
      final client = File(
        'lib/services/backend_api_client.dart',
      ).readAsStringSync();
      final backendRoutes = File('school-backend/main.go').readAsStringSync();

      expect(screenFile.existsSync(), isTrue);
      final screen = screenFile.readAsStringSync();
      expect(screen, contains('Attendance Directory'));
      expect(screen, contains('PrincipalDirectoryScaffold'));
      expect(screen, contains('PrincipalDetailPage'));
      expect(screen, contains('PrincipalInputPage'));
      expect(screen, contains('Daily Staff QR'));
      expect(screen, contains('Teacher / Staff Status'));
      expect(screen, contains('Class-wise Students'));
      expect(screen, contains('Attendance Reports'));
      expect(screen, contains('Create Attendance Report'));
      expect(screen, contains('QrImageView'));
      expect(routes, contains('PrincipalAttendanceScreen'));
      expect(routes, contains('principalAttendance'));
      expect(client, contains('Future<List<AttendanceSessionModel>>'));
      expect(client, contains('getStudentAttendanceRecords'));
      expect(backendRoutes, contains('attendance.GET("/sessions"'));
      expect(backendRoutes, contains('attendance.GET("/reports/exports"'));
    },
  );

  test('principal staff and guardian compatibility routes match app calls', () {
    final backendRoutes = File('school-backend/main.go').readAsStringSync();
    final staffScreen = File(
      'lib/presentation/staff_management_screen/staff_management_screen.dart',
    ).readAsStringSync();
    final guardianScreen = File(
      'lib/presentation/guardian_directory_screen/guardian_directory_screen.dart',
    ).readAsStringSync();

    expect(staffScreen, contains("getRawList(\n        '/staff-subjects'"));
    expect(guardianScreen, contains("getRawList(\n        '/guardians'"));
    expect(
      backendRoutes,
      contains('staffSubjectsCompat := protected.Group("/staff-subjects")'),
    );
    expect(
      backendRoutes,
      contains('staffDocumentsCompat := protected.Group("/staff-documents")'),
    );
    expect(
      backendRoutes,
      contains('guardiansCompat := protected.Group("/guardians")'),
    );
  });

  test('principal classes UI is routed and backend remains wired', () {
    final screenFile = File(
      'lib/presentation/principal_classes_screen/principal_classes_screen.dart',
    );
    final routes = File('lib/routes/app_routes.dart').readAsStringSync();
    final client = File(
      'lib/services/backend_api_client.dart',
    ).readAsStringSync();
    final backendRoutes = File('school-backend/main.go').readAsStringSync();
    final backend = File(
      'school-backend/internal/handlers/principal_classes.go',
    ).readAsStringSync();

    expect(screenFile.existsSync(), isTrue);
    final screen = screenFile.readAsStringSync();
    expect(screen, contains('PrincipalClassesScreen'));
    expect(screen, contains('PrincipalPreviewBottomNav'));
    expect(screen, contains('Create New Class'));
    expect(screen, contains('Class Detail'));
    expect(routes, contains('PrincipalClassesScreen'));
    expect(routes, contains('principalClasses'));
    expect(
      client,
      contains('Future<Map<String, dynamic>> getPrincipalClassesOverview'),
    );
    expect(
      client,
      contains('Future<Map<String, dynamic>> createPrincipalClass'),
    );
    expect(
      client,
      contains('Future<Map<String, dynamic>> createPrincipalClassInstruction'),
    );
    expect(
      backendRoutes,
      contains('principal.GET("/classes", principalClassesHandler.Overview)'),
    );
    expect(backendRoutes, contains('principal.POST("/classes",'));
    expect(
      backendRoutes,
      contains('principal.POST("/classes/:section_id/instructions"'),
    );
    expect(backend, contains('const principalClassInstructionsResource'));
    expect(backend, contains('type PrincipalClassesHandler struct{}'));
    expect(backend, contains('"principal_role": "supervision"'));
  });

  test(
    'principal class actions scope downstream screens by selected section',
    () {
      final students = File(
        'lib/presentation/student_oversight_screen/student_oversight_screen.dart',
      ).readAsStringSync();
      final moduleScaffold = File(
        'lib/widgets/erp_module_scaffold.dart',
      ).readAsStringSync();

      expect(students, contains('ModalRoute.of(context)?.settings.arguments'));
      expect(students, contains("args['section_id'] ?? args['sectionId']"));
      expect(
        students,
        contains(
          'sectionId: _scopedSectionId.isEmpty ? null : _scopedSectionId',
        ),
      );
      expect(moduleScaffold, contains("label: principal ? 'Inbox'"));
      expect(moduleScaffold, contains('AppRoutes.principalInbox'));
    },
  );

  test('principal subjects screen is command-center supervision', () {
    final screen = File(
      'lib/presentation/principal_subjects_screen/principal_subjects_screen.dart',
    ).readAsStringSync();
    final routes = File('lib/routes/app_routes.dart').readAsStringSync();
    final client = File(
      'lib/services/backend_api_client.dart',
    ).readAsStringSync();
    final backendRoutes = File('school-backend/main.go').readAsStringSync();
    final backend = File(
      'school-backend/internal/handlers/principal_subjects.go',
    ).readAsStringSync();
    final crud = File(
      'school-backend/internal/handlers/crud.go',
    ).readAsStringSync();

    expect(routes, contains('PrincipalSubjectsScreen'));
    expect(screen, contains('Subjects Directory'));
    expect(screen, contains('Catalog, class mappings'));
    expect(screen, contains('Create Subject'));
    expect(screen, contains('Map Class / Teacher'));
    expect(screen, contains('savePrincipalSubjectMapping'));
    expect(screen, contains('PrincipalDirectoryScaffold'));
    expect(screen, contains('PrincipalDirectoryCard'));
    expect(screen, contains('PrincipalDetailPage'));
    expect(screen, contains('PrincipalInputPage'));
    expect(screen, contains('Mapped'));
    expect(screen, contains('Classes Mapped'));
    expect(screen, contains('Syllabus Pending'));
    expect(screen, contains('Teacher Assignments'));
    expect(screen, contains('Teacher Load'));
    expect(screen, contains('Class / Grade'));
    expect(screen, contains('teacher_class_coverage'));
    expect(screen, contains('Map Subject to Class'));
    expect(screen, contains('Subject-wise Topper List'));
    expect(screen, contains('Weak Subject Detection'));
    expect(screen, contains('Syllabus Completion Tracker'));
    expect(screen, contains('Teacher Performance'));
    expect(screen, contains('Homework Consistency'));
    expect(
      client,
      contains('Future<Map<String, dynamic>> getPrincipalSubjectsOverview'),
    );
    expect(
      client,
      contains('Future<Map<String, dynamic>> savePrincipalSubjectMapping'),
    );
    expect(
      client,
      contains('Future<Map<String, dynamic>> createPrincipalSubjectAction'),
    );
    expect(
      backendRoutes,
      contains('principal.GET("/subjects", principalSubjectsHandler.Overview)'),
    );
    expect(
      backendRoutes,
      contains('principal.POST("/subjects/:subject_id/actions"'),
    );
    expect(
      backendRoutes,
      contains('principal.POST("/subjects/:subject_id/mappings"'),
    );
    expect(
      backendRoutes,
      contains('gradeSubjects := api.Group("/grade-subjects")'),
    );
    expect(backend, contains('type PrincipalSubjectsHandler struct{}'));
    expect(backend, contains('"principal_role": "subject_supervision"'));
    expect(backend, contains('upsertSubjectTeacherAssignment'));
    expect(backend, contains('principalSubjectTeacherCoverageRows'));
    expect(backend, contains('subjectTeacherCoverageAnalytics'));
    expect(backend, contains('"section_name": teacher.SectionName'));
    expect(crud, contains('validateGradeSubjectPolicy'));
  });

  test('principal timetable exams and results are command centers', () {
    final screen = File(
      'lib/presentation/principal_command_center_screens/principal_academic_command_screens.dart',
    ).readAsStringSync();
    final routes = File('lib/routes/app_routes.dart').readAsStringSync();
    final drawer = File('lib/widgets/app_navigation.dart').readAsStringSync();
    final client = File(
      'lib/services/backend_api_client.dart',
    ).readAsStringSync();
    final backendRoutes = File('school-backend/main.go').readAsStringSync();
    final backend = File(
      'school-backend/internal/handlers/principal_academic_command.go',
    ).readAsStringSync();

    expect(routes, contains('PrincipalTimetableScreen'));
    expect(routes, contains('PrincipalExamsScreen'));
    expect(routes, contains('PrincipalResultsScreen'));
    expect(drawer, contains('route: AppRoutes.principalTimetable'));
    expect(drawer, contains('route: AppRoutes.principalExams'));
    expect(drawer, contains('route: AppRoutes.principalResults'));

    expect(screen, contains('Timetable Builder'));
    expect(screen, contains('class _TimetableModePicker'));
    expect(screen, contains('_TimetableMode.periods'));
    expect(screen, contains('Created Periods'));
    expect(screen, contains('Class Coverage'));
    expect(screen, contains('Teacher Load'));
    expect(screen, contains('Subject Coverage'));
    expect(screen, contains('Room Usage'));
    expect(screen, contains('Conflict Alerts'));
    expect(screen, contains('Add Timetable Period'));
    expect(screen, contains('class _TimetableSlotInputForm'));

    expect(screen, contains('Exam Workflow'));
    expect(screen, contains('1. Readiness'));
    expect(screen, contains('2. Scheduled Exams'));
    expect(screen, contains('Assign invigilators'));
    expect(screen, contains('3. Live Monitoring'));
    expect(screen, contains('4. Evaluation'));
    expect(screen, contains('5. Publish'));
    expect(screen, contains('Create Exam'));

    expect(screen, contains('Results Command Center'));
    expect(screen, contains('Result Dashboard'));
    expect(screen, contains('Toppers Section'));
    expect(screen, contains('Weak Student Detection'));
    expect(screen, contains('Export Options'));
    expect(screen, contains('Generate improvement plans'));

    expect(client, contains('getPrincipalTimetableOverview'));
    expect(client, contains('createPrincipalTimetableAction'));
    expect(client, contains('getPrincipalExamsOverview'));
    expect(client, contains('createPrincipalExamAction'));
    expect(client, contains('getPrincipalResultsOverview'));
    expect(client, contains('createPrincipalResultAction'));

    expect(backendRoutes, contains('principal.GET("/timetable"'));
    expect(backendRoutes, contains('principal.GET("/exams"'));
    expect(backendRoutes, contains('principal.GET("/results"'));
    expect(backend, contains('principalTimetableActionsResource'));
    expect(backend, contains('principalExamActionsResource'));
    expect(backend, contains('principalResultActionsResource'));
    expect(backend, contains('timetableConflictAlerts'));
    expect(backend, contains('examEvaluationRows'));
    expect(backend, contains('weakStudentRows'));
  });

  test('app uses controlled text scale instead of system display text scale', () {
    final main = File('lib/main.dart').readAsStringSync();
    final settings = File(
      'lib/services/theme_provider.dart',
    ).readAsStringSync();
    final settingsScreen = File(
      'lib/presentation/settings_screen/settings_screen.dart',
    ).readAsStringSync();
    final students = File(
      'lib/presentation/student_oversight_screen/student_oversight_screen.dart',
    ).readAsStringSync();

    expect(main, contains('ChangeNotifierProvider<AppSettingsProvider>.value'));
    expect(main, contains('TextScaler.linear('));
    expect(main, isNot(contains('mediaQuery.textScaler.clamp')));
    expect(settings, contains('double get appTextScaleFactor'));
    expect(settings, contains("case 'large':"));
    expect(settings, contains('return 1.12;'));
    expect(settingsScreen, contains('App Text Size'));
    expect(
      settingsScreen,
      contains('Uses SchoolDesk sizing, not the phone display size'),
    );
    expect(students, contains("_formatStudentDate"));
    expect(students, contains("DateFormat('dd MMM yyyy')"));
    expect(students, contains('maxLines: 2'));
  });

  test(
    'school profile edit validates fields and crops logo before backend upload',
    () {
      final screen = File(
        'lib/presentation/school_profile_screen/school_profile_screen.dart',
      ).readAsStringSync();
      final backend = File(
        'school-backend/internal/handlers/school.go',
      ).readAsStringSync();

      expect(screen, contains('GlobalKey<FormState>'));
      expect(screen, contains('_formKey.currentState?.validate()'));
      expect(screen, contains('SchoolDeskImageCropper.cropSquareImage'));
      expect(screen, contains('Crop School Logo'));
      expect(screen, contains('uploadCurrentSchoolLogo'));
      expect(screen, contains('updateCurrentSchool'));
      expect(backend, contains('validateCurrentSchoolPayload'));
      expect(backend, contains('mail.ParseAddress'));
      expect(backend, contains('website must start with http:// or https://'));
    },
  );

  test(
    'principal student and teacher add forms validate and upload cropped photos',
    () {
      final routes = File('lib/routes/app_routes.dart').readAsStringSync();
      final students = File(
        'lib/presentation/student_oversight_screen/student_oversight_screen.dart',
      ).readAsStringSync();
      final backendRoutes = File('school-backend/main.go').readAsStringSync();
      final teachers = File(
        'lib/presentation/staff_management_screen/staff_management_screen.dart',
      ).readAsStringSync();

      expect(
        routes,
        contains(
          'studentOversight: (context) => const StudentOversightScreen()',
        ),
      );
      expect(students, contains('Crop Student Photo'));
      expect(students, contains('_requiredFullName'));
      expect(students, contains('client.createStudent('));
      expect(students, contains('client.updateStudent('));
      expect(students, contains('client.createUser('));
      expect(students, contains('setStudentParent'));
      expect(students, contains('uploadStudentPhoto'));
      expect(students, contains('uploadStudentDocument'));
      expect(students, contains("createRaw('/fees/invoices/generate'"));
      expect(students, contains("createRaw('/fees/concessions'"));
      expect(
        backendRoutes,
        contains(
          'fees.POST("/invoices/generate", middleware.RBACMiddleware("Admin", "Principal")',
        ),
      );
      expect(teachers, contains('Crop Staff Photo'));
      expect(teachers, contains('_requiredFullName'));
      expect(teachers, contains('_requiredPhone'));
      expect(teachers, contains('BackendApiClient.instance.createStaff'));
      expect(teachers, contains('uploadStaffPhoto'));
      expect(teachers, contains('uploadStaffDocument'));
    },
  );

  test('principal student details expose backend-backed removal action', () {
    final students = File(
      'lib/presentation/student_oversight_screen/student_oversight_screen.dart',
    ).readAsStringSync();
    final client = File(
      'lib/services/backend_api_client.dart',
    ).readAsStringSync();
    final backend = File(
      'school-backend/internal/handlers/student.go',
    ).readAsStringSync();

    expect(students, contains('Student actions'));
    expect(students, contains('Edit Student'));
    expect(students, contains('Remove Student'));
    expect(students, contains('Edit Student Admission'));
    expect(
      students,
      contains('api.BackendApiClient.instance.deleteStudent(student.id)'),
    );
    expect(client, contains('Future<void> updateStudent('));
    expect(client, contains('Future<String> uploadStudentDocument'));
    expect(backend, contains('UploadStudentDocument'));
    expect(students, contains('moved to inactive records'));
    expect(client, contains('Future<void> deleteStudent(String id)'));
    expect(backend, contains('cleanupStudentAssociations'));
    expect(backend, contains('"status":             "inactive"'));
  });

  test('principal student and teacher directories harden compact layouts', () {
    final students = File(
      'lib/presentation/student_oversight_screen/student_oversight_screen.dart',
    ).readAsStringSync();
    final teachers = File(
      'lib/presentation/staff_management_screen/staff_management_screen.dart',
    ).readAsStringSync();
    final guardians = File(
      'lib/presentation/guardian_directory_screen/guardian_directory_screen.dart',
    ).readAsStringSync();

    for (final source in [students, teachers, guardians]) {
      expect(source, contains('final chipRowHeight ='));
      expect(source, contains('height: chipRowHeight'));
      expect(source, contains('class _ResponsiveFieldRow'));
      expect(source, contains('constraints.maxWidth < 330'));
      expect(source, contains('class _DetailRow'));
      expect(source, contains('maxLines: 2'));
      expect(source, contains('FittedBox('));
      expect(source, contains('_buildActionButtons'));
      expect(source, contains('constraints.maxWidth < 300'));
    }
  });

  test('admin drawer uses simple action labels for owned operations', () {
    final source = File('lib/widgets/admin_navigation.dart').readAsStringSync();

    expect(source, contains('label: SchoolDeskGlossary.timetable'));
    expect(source, contains('label: SchoolDeskGlossary.academicManagement'));
    expect(source, contains('label: SchoolDeskGlossary.exams'));
    expect(source, contains('label: SchoolDeskGlossary.access'));
    expect(source, isNot(contains('Student Administration')));
    expect(source, isNot(contains('Exam Administration')));
    expect(source, isNot(contains('User & Access')));
  });

  test('glossary normalizes misspelled principal role labels', () {
    expect(SchoolDeskGlossary.roleLabel('principle'), 'Principal');
    expect(SchoolDeskGlossary.portalLabel('principal'), 'Principal Portal');
  });

  test('admin user access manages teacher and parent accounts', () {
    final source = File(
      'lib/presentation/admin_user_access_screen/admin_user_access_screen.dart',
    ).readAsStringSync();

    expect(source, contains("['Teacher', 'Parent']"));
    expect(source, contains('permanent: true'));
    expect(source, contains('Delete Inactive Account Permanently'));
  });

  test('principal timetable can write backend class slots', () {
    final source = File(
      'lib/presentation/timetable_management_screen/timetable_management_screen.dart',
    ).readAsStringSync();
    final backendRoutes = File('school-backend/main.go').readAsStringSync();

    expect(source, contains('Add Period'));
    expect(source, contains('_openAddPeriodForm'));
    expect(source, contains('_openEditPeriodForm'));
    expect(source, contains('_deletePeriod'));
    expect(source, contains("deleteRaw('/timetable/slots/"));
    expect(source, contains('AdminTimetablePeriodFormScreen'));
    expect(source, contains('AdminTimetableGenerationFormScreen'));
    expect(source, contains('Raise Advice'));
    expect(source, contains('/principal/timetable-advice'));
    expect(source, isNot(contains('rootNavigator: true')));
    expect(source, isNot(contains('void _showEditPeriodDialog')));
    expect(
      backendRoutes,
      contains(
        'timetable.POST("/slots", middleware.RBACMiddleware("Admin", "Principal")',
      ),
    );
    expect(
      backendRoutes,
      contains(
        'timetable.PUT("/slots/:id", middleware.RBACMiddleware("Admin", "Principal")',
      ),
    );
  });

  test(
    'principal substitute cards safely render backend substitution payloads',
    () {
      final source = File(
        'lib/presentation/timetable_management_screen/timetable_management_screen.dart',
      ).readAsStringSync();

      expect(source, contains('String _staffLabel(dynamic value'));
      expect(source, contains("s['original_staff']"));
      expect(source, contains("s['substitute_staff']"));
      expect(source, isNot(contains("Text(\n                  s['teacher']")));
      expect(source, isNot(contains("\${s['date']} · \${s['periods']}")));
    },
  );

  test('principal exams and academics expose records not create workflows', () {
    final exams = File(
      'lib/presentation/exams_results_screen/exams_results_screen.dart',
    ).readAsStringSync();
    final academics = File(
      'lib/presentation/academic_management_screen/academic_management_screen.dart',
    ).readAsStringSync();
    final routes = File('lib/routes/app_routes.dart').readAsStringSync();

    expect(exams, isNot(contains('Add New Exam')));
    expect(exams, isNot(contains('Save Changes')));
    expect(routes, contains("role == 'principal' ? 'principal' : 'admin'"));
    expect(academics, contains("Review academic structure"));
    expect(academics, contains('onAdd: isAdminOwner ?'));
    expect(academics, contains('onEdit: isAdminOwner'));
    expect(academics, contains('onDelete: isAdminOwner'));
    expect(academics, contains('onTogglePublish: isAdminOwner'));
  });

  test(
    'principal profile uses backend file upload for avatar instead of URL entry',
    () {
      final screen = File(
        'lib/presentation/profile_management_screen/profile_management_screen.dart',
      ).readAsStringSync();
      final client = File(
        'lib/services/backend_api_client.dart',
      ).readAsStringSync();
      final backend = File('school-backend/main.go').readAsStringSync();

      expect(screen, contains('pickImage'));
      expect(screen, isNot(contains('Profile Picture URL')));
      expect(client, contains('uploadProfileAvatar'));
      expect(backend, contains('/profile/avatar'));
    },
  );
}
