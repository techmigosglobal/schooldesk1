import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'backend_api_sources.dart';

import 'backend_route_sources.dart';
import 'package:schooldesk1/core/constants/schooldesk_glossary.dart';

void main() {
  test('principal timetable route delegates to read-only command screen', () {
    final wrapper = File(
      'lib/features/academics/presentation/screens/timetable_management_screen/timetable_management_screen.dart',
    ).readAsStringSync();
    final source = File(
      'lib/features/academics/presentation/screens/principal_command_center_screens/principal_academic_command_screens.dart',
    ).readAsStringSync();

    expect(wrapper, contains('PrincipalTimetableScreen'));
    expect(wrapper, isNot(contains('createRaw')));
    expect(source, contains('getPrincipalTimetableOverview'));
    expect(source, contains('didChangeDependencies'));
    expect(source, contains('_requestedSectionId'));
    expect(source, contains('_TimetableDetailMode.classDay'));
    expect(source, contains('_TimetableHomeMode.classes'));
    expect(source, contains('_TimetableHomeMode.teachers'));
    expect(source, contains('_TimetableHomeMode.rooms'));
    expect(source, contains('_buildOwnershipNotice'));
    expect(
      source,
      contains('Only live backend timetable rows are shown here.'),
    );
  });

  test('principal timetable routes setup changes to Classes Hub', () {
    final source = File(
      'lib/features/academics/presentation/screens/principal_command_center_screens/principal_academic_command_screens.dart',
    ).readAsStringSync();
    final wrapper = File(
      'lib/features/academics/presentation/screens/timetable_management_screen/timetable_management_screen.dart',
    ).readAsStringSync();

    expect(source, contains('Go to Classes Hub'));
    expect(source, contains("class_hub_action': 'timetable'"));
    expect(source, contains("source': 'principal_timetable'"));
    expect(source, isNot(contains('createPrincipalTimetableAction')));
    expect(source, isNot(contains('Timetable review saved')));
    expect(wrapper, isNot(contains('Add Period')));
    expect(wrapper, isNot(contains('_openAddPeriodForm')));
    expect(wrapper, isNot(contains('_openEditPeriodForm')));
    expect(wrapper, isNot(contains('_deletePeriod')));
  });

  test('fee monitoring concession cards use backend field names safely', () {
    final source = File(
      'lib/features/finance/presentation/screens/fee_monitoring_screen/fee_monitoring_screen.dart',
    ).readAsStringSync();

    expect(source, isNot(contains("c['student']")));
    expect(source, isNot(contains("c['class']")));
    expect(source, isNot(contains("c['date']")));
  });

  test(
    'fee monitoring matches the mobile fee workflow and backend contracts',
    () {
      final source = File(
        'lib/features/finance/presentation/screens/fee_monitoring_screen/fee_monitoring_screen.dart',
      ).readAsStringSync();
      final api = File(
        'lib/core/network/api_modules/fees_api.dart',
      ).readAsStringSync();

      expect(source, contains("title: 'Fees'"));
      expect(source, contains('View and manage fee information'));
      expect(source, contains('enum _FeeView'));
      expect(source, contains('_FeeView.home'));
      expect(source, contains('_FeeView.structures'));
      expect(source, contains('_FeeView.structureDetails'));
      expect(source, contains('_FeeView.students'));
      expect(source, contains('_FeeView.ledger'));
      expect(source, contains('_FeeView.collectMode'));
      expect(source, contains('_FeeView.collectDetails'));
      expect(source, contains('_FeeView.paymentSuccess'));
      expect(source, contains('_FeeView.dues'));
      expect(source, contains('_FeeView.reports'));
      expect(source, contains('Total Fee Structures'));
      expect(source, contains('Total Collections'));
      expect(source, contains('Total Due'));
      expect(source, contains('Fee Structures'));
      expect(source, contains('Fee Collection'));
      expect(source, contains('Outstanding Dues'));
      expect(source, contains('Fee Reports'));
      expect(source, contains('Fee Structure Details'));
      expect(source, contains('Fee Components'));
      expect(source, contains('Go to Classes Hub'));
      expect(source, contains('Students'));
      expect(source, contains('Fee Ledger'));
      expect(source, contains('Payment Summary'));
      expect(source, contains('Select Payment Mode'));
      expect(source, contains('Payment Details'));
      expect(source, contains('Payment Successful!'));
      expect(source, contains('Send Reminders'));
      expect(source, contains('Select Report Type'));
      expect(source, contains('Generate Report'));
      expect(source, contains('_structureBundles'));
      expect(source, contains('_studentAccounts'));
      expect(source, contains('_filteredStudentAccounts'));
      expect(source, contains('_filteredDueAccounts'));
      expect(source, contains('_primaryDueInvoice'));
      expect(source, contains('_FeeStructureBundle'));
      expect(source, contains('_FeeStudentAccount'));
      expect(source, contains('_FeePaymentResult'));
      expect(source, contains('BackendApiClient.instance.recordPayment'));
      expect(source, contains("createRaw('/fees/reminders'"));
      expect(source, contains("'/fees/reports/exports'"));
      expect(source, contains('createReportExport('));
      expect(source, contains('PaymentRequest('));
      expect(source, contains('PrincipalShellBottomBar'));
      expect(source, contains('PrincipalDrawer(selectedIndex: 7'));
      expect(source, contains('_openClassesHubForFees'));
      expect(source, contains("class_hub_action': 'fees'"));
      expect(source, contains("source': 'principal_fees'"));
      expect(api, contains('String? academicYearId'));
      expect(api, contains("queryParams['academic_year_id']"));
      expect(api, contains("queryParams['grade_id']"));
      expect(api, contains("queryParams['section_id']"));
      expect(api, contains("queryParams['term_id']"));
      expect(source, isNot(contains('AdminFeeStructureFormScreen')));
      expect(source, isNot(contains('AdminInvoiceGenerationFormScreen')));
      expect(source, isNot(contains("deleteRaw('/fees/structures")));
      expect(source, isNot(contains("deleteRaw('/fees/categories")));
      expect(source, isNot(contains('class _ManualFeeEntrySheet')));
      expect(source, isNot(contains('class _CashPaymentPage')));
      expect(source, isNot(contains('class _PaymentEntryForm')));
      expect(source, isNot(contains('Collect Payment')));
      expect(source, isNot(contains('PrincipalInputPage')));
    },
  );

  test('fee monitoring status filters keep mobile student lists readable', () {
    final source = File(
      'lib/features/finance/presentation/screens/fee_monitoring_screen/fee_monitoring_screen.dart',
    ).readAsStringSync();

    expect(source, contains('enum _FeeStatusFilter'));
    expect(source, contains('_FeeStatusFilter.all'));
    expect(source, contains('_FeeStatusFilter.paid'));
    expect(source, contains('_FeeStatusFilter.partial'));
    expect(source, contains('_FeeStatusFilter.unpaid'));
    expect(source, contains('_FeeStatusFilter.due'));
    expect(source, contains('RadioListTile<_FeeStatusFilter>'));
    expect(source, contains('_matchesStatus(account)'));
    expect(source, contains('_statusFilterLabel(filter)'));
    expect(source, contains('_FeeSearchBox'));
    expect(source, contains('TextOverflow.ellipsis'));
    expect(source, contains('maxLines: 1'));
  });

  test('principal classes UI is HTML-backed and class APIs stay reusable', () {
    final screenFile = File(
      'lib/features/academics/presentation/screens/principal_classes_screen/principal_classes_screen.dart',
    );
    final screen = screenFile.readAsStringSync();
    final client = readBackendApiSources();
    final backendRoutes = readBackendRouteSources();

    expect(screenFile.existsSync(), isTrue);
    expect(screen, contains('Existing Classes'));
    expect(screen, contains('Create New Class'));
    expect(screen, contains('Classes Directory'));
    expect(screen, contains('Search class, teacher, section'));
    expect(screen, contains('View calendar'));
    expect(screen, contains('Your Classes'));
    expect(screen, contains('No pending actions'));
    expect(screen, contains('Quick Actions'));
    expect(screen, contains('Edit Class'));
    expect(screen, contains('Save changes'));
    expect(screen, contains('Remove class'));
    expect(screen, contains('updatePrincipalClassSetup('));
    expect(screen, contains('deletePrincipalClass'));
    expect(screen, contains('_ClassesDirectoryBottomBar'));
    expect(screen, contains('Create Class'));
    expect(screen, contains('Classes Setup'));
    expect(screen, contains('Subjects creation and assigning teachers'));
    expect(screen, contains('Timetable setup'));
    expect(screen, contains('Fee setup'));
    expect(screen, contains('Review'));
    expect(
      screen.indexOf('Timetable setup'),
      lessThan(screen.indexOf('Fee setup')),
    );
    expect(screen, contains('Save & Continue'));
    expect(screen, contains('Assign Subjects'));
    expect(screen, contains('Class Details'));
    expect(screen, contains('Subjects in this Class'));
    expect(screen, contains('Add / Select Subject'));
    expect(screen, contains('Available Subjects'));
    expect(screen, contains("Can't find the subject?"));
    expect(screen, contains('Subject Color'));
    expect(screen, contains('Continue Setup'));
    expect(screen, contains('Timetable Setup'));
    expect(screen, contains('Generate class timetable'));
    expect(screen, contains('Preview Timetable'));
    expect(screen, contains('Generate Timetable'));
    expect(screen, contains('View timetables'));
    expect(screen, contains('Setup timetable'));
    expect(screen, contains('_openTimetableSetup'));
    expect(screen, contains('Open timetable'));
    expect(screen, contains('Continue to fees'));
    expect(screen, isNot(contains('Save & Publish')));
    expect(screen, isNot(contains('Edit Timetable Manually')));
    expect(screen, contains('previewSmartTimetable'));
    expect(screen, contains('generateSmartTimetable'));
    expect(screen, isNot(contains('saveTimetableTemplate')));
    expect(screen, contains('Fees Setup'));
    expect(screen, contains('Step 4 of 5'));
    expect(screen, contains('Use Existing Fee Structure'));
    expect(screen, contains('Create New Fee Structure'));
    expect(screen, contains('Create Fee Structure'));
    expect(screen, contains('Structure Details'));
    expect(screen, contains('Fee Components'));
    expect(screen, contains('Review Fee Structure'));
    expect(screen, contains('Confirm & Assign'));
    expect(screen, contains('Fees Assigned'));
    expect(screen, contains('Setup Next (Review)'));
    expect(screen, contains('Approvals & Notes'));
    expect(screen, contains('PrincipalPreviewBottomNav'));
    expect(screen, contains('principalDirectoryBackground'));
    expect(screen, contains('fontSize: compact ? 15 : 16'));
    expect(screen, contains('fontSize: phone ? 14.5 : 15.5'));
    expect(screen, isNot(contains('fontSize: 30')));
    expect(screen, isNot(contains('fontSize: 26')));
    expect(screen, isNot(contains('fontSize: 24')));
    expect(screen, isNot(contains('fontSize: compact ? 22 : 26')));
    expect(screen, isNot(contains('fontSize: phone ? 18 : 22')));
    expect(screen, contains('getPrincipalClassesOverview()'));
    expect(client, contains('createPrincipalClass'));
    expect(client, contains('updatePrincipalClassSetup'));
    expect(client, contains('deletePrincipalClass'));
    expect(client, contains("'grade_name': gradeName.trim()"));
    expect(client, contains('savePrincipalSubjectMapping'));
    expect(client, contains('getFeeStructures'));
    expect(backendRoutes, contains('principal.POST("/classes"'));
    expect(backendRoutes, contains('principal.DELETE('));
    expect(backendRoutes, contains('"/classes/:section_id"'));
    expect(backendRoutes, contains('fees.GET("/structures"'));
    expect(
      backendRoutes,
      contains(
        'timetable.POST("/smart/preview", middleware.RBACMiddleware("Admin", "Principal")',
      ),
    );
    expect(
      backendRoutes,
      contains(
        'timetable.POST("/smart/generate", middleware.RBACMiddleware("Admin", "Principal")',
      ),
    );
    expect(backendRoutes, contains('timetable.PUT("/templates"'));
    expect(
      backendRoutes,
      contains('principal.POST("/subjects/:subject_id/mappings"'),
    );
    expect(
      backendRoutes,
      contains('principal.GET("/classes", principalClassesHandler.Overview)'),
    );
  });

  test('principal student module exposes backend summaries and web uploads', () {
    final screen = File(
      'lib/features/people/presentation/screens/student_oversight_screen/student_oversight_screen.dart',
    ).readAsStringSync();
    final client = readBackendApiSources();
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
      'lib/features/people/presentation/screens/admin_user_access_screen/admin_user_access_screen.dart',
    ).readAsStringSync();
    final accountForm = File(
      'lib/features/people/presentation/screens/admin_user_access_screen/account_access_form_screen.dart',
    ).readAsStringSync();
    final childAssignment = File(
      'lib/features/people/presentation/screens/admin_user_access_screen/account_child_assignment_screen.dart',
    ).readAsStringSync();
    final client = readBackendApiSources();
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
      'lib/features/people/presentation/screens/admin_user_access_screen/admin_user_access_screen.dart',
    ).readAsStringSync();
    final routes = File('lib/routes/app_routes.dart').readAsStringSync();
    final accountForm = File(
      'lib/features/people/presentation/screens/admin_user_access_screen/account_access_form_screen.dart',
    ).readAsStringSync();
    final childAssignment = File(
      'lib/features/people/presentation/screens/admin_user_access_screen/account_child_assignment_screen.dart',
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
      'lib/features/academics/presentation/screens/academic_management_screen/academic_management_screen.dart',
    ).readAsStringSync();
    final forms = File(
      'lib/features/academics/presentation/screens/academic_management_screen/academic_management_form_screens.dart',
    ).readAsStringSync();
    final client = readBackendApiSources();
    final service = File(
      'lib/core/services/backend_data_service.dart',
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
    final source = File(
      'lib/core/widgets/app_navigation.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('badgeCount: 5')));
    expect(source, isNot(contains('badgeCount: 3')));
  });

  test('principal drawer exposes academic management from records section', () {
    final source = File(
      'lib/core/widgets/app_navigation.dart',
    ).readAsStringSync();
    final registry = File(
      'lib/routes/schooldesk_screen_registry.dart',
    ).readAsStringSync();
    final availability = File(
      'lib/core/services/feature_availability_service.dart',
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
      'lib/features/dashboard/presentation/screens/principal_dashboard_screen/principal_dashboard_screen.dart',
    ).readAsStringSync();

    expect(source, contains('api.getNotifications()'));
    expect(source, contains('unreadNotifications'));
    expect(source, contains('class _HeaderNotificationButton'));
    expect(source, contains('Icons.notifications_none_rounded'));
    expect(source, contains('AppRoutes.notificationCenter'));
  });

  test('principal dashboard top banner and module grid are responsive', () {
    final dashboard = File(
      'lib/features/dashboard/presentation/screens/principal_dashboard_screen/principal_dashboard_screen.dart',
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
    expect(dashboard, contains("label: 'Academic Years'"));
    expect(dashboard, contains('route: AppRoutes.academicManagement'));
    expect(dashboard, contains('SchoolDeskUiIllustrations.calendar'));
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
    expect(dashboard, contains("label: 'Chat Communications'"));
    expect(dashboard, contains('route: AppRoutes.principalChatCommunications'));
    expect(dashboard, contains('SchoolDeskUiIllustrations.chat'));
    expect(dashboard, contains('constraints.maxWidth < 340'));
    expect(dashboard, contains('SafeArea('));
    expect(dashboard, contains('height: 66'));

    for (final asset in <String>[
      'assets/images/ui/principal-students.svg',
      'assets/images/ui/principal-guided-assistant.svg',
      'assets/images/ui/illustration-calendar.svg',
      'assets/images/ui/illustration-chat.svg',
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
        'lib/features/dashboard/presentation/screens/principal_dashboard_screen/principal_dashboard_screen.dart',
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
        contains('static const String principalChatCommunications'),
      );
      expect(routes, contains('PrincipalChatCommunicationsScreen'));
      expect(
        guard,
        contains("AppRoutes.principalChatCommunications: {'principal'}"),
      );

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
      expect(
        dashboard,
        contains('route: AppRoutes.principalChatCommunications'),
      );
      expect(dashboard, contains('pendingApprovals'));
    },
  );

  test(
    'principal chat communications uses backend chat and direct message APIs',
    () {
      final source = File(
        'lib/features/communication/presentation/screens/principal_chat_communications_screen/principal_chat_communications_screen.dart',
      ).readAsStringSync();
      final routes = File('lib/routes/app_routes.dart').readAsStringSync();
      final guard = File(
        'lib/routes/route_access_guard.dart',
      ).readAsStringSync();
      final appNavigation = File(
        'lib/core/widgets/app_navigation.dart',
      ).readAsStringSync();

      expect(source, contains('Communication'));
      expect(source, contains('All Chats'));
      expect(source, contains('Teacher Chats'));
      expect(source, contains('Group Chat'));
      expect(source, contains('Announcements'));
      expect(source, contains('New Announcement'));
      expect(source, contains('Message Reports'));
      expect(source, contains('Communication Settings'));
      expect(source, contains("getRawList('/message-conversations')"));
      expect(source, contains("getRawList('/messages')"));
      expect(source, contains('getCommunications()'));
      expect(source, contains('getAnnouncements()'));
      expect(source, contains('sendCommunication('));
      expect(source, contains('createAnnouncement('));
      expect(source, contains("createRaw('/messages'"));
      expect(source, contains("updateRaw('/messages/\${message.id}'"));
      expect(source, contains("createReportExport("));
      expect(source, contains("'/reports/exports'"));
      expect(source, contains('PrincipalShellBottomBar'));
      expect(source, contains('_PrincipalCommunicationView.home'));
      expect(source, contains('_PrincipalCommunicationView.allChats'));
      expect(source, contains('_PrincipalCommunicationView.teacherChats'));
      expect(source, contains('_PrincipalCommunicationView.parentThread'));
      expect(source, contains('_PrincipalCommunicationView.announcements'));
      expect(source, contains('_PrincipalCommunicationView.reports'));
      expect(source, contains('_PrincipalCommunicationView.settings'));
      expect(source, contains('Send Announcement'));
      expect(source, contains('Export Chat Reports'));
      expect(source, isNot(contains('mock')));
      expect(source, isNot(contains('demo')));
      expect(
        routes,
        contains('static const String principalChatCommunications'),
      );
      expect(routes, contains('PrincipalChatCommunicationsScreen'));
      expect(
        guard,
        contains("AppRoutes.principalChatCommunications: {'principal'}"),
      );
      expect(
        appNavigation,
        contains('route: AppRoutes.principalChatCommunications'),
      );
    },
  );

  test('guided assistant mobile layout keeps key actions visible', () {
    final source = File(
      'lib/features/communication/presentation/screens/guided_assistant_screen/guided_assistant_screen.dart',
    ).readAsStringSync();

    expect(source, contains('EdgeInsets _screenPadding'));
    expect(source, contains('class _AssistantTopBar'));
    expect(source, contains('class _AssistantMenuCard'));
    expect(source, contains('class _StepProgressBar'));
    expect(source, contains('class _AssistantFooterActions'));
    expect(source, contains('class _CommandInputBar'));
    expect(source, contains('class _AssistantComposerFooter'));
    expect(source, contains("hint: 'Type here...'"));
    expect(source, contains('actionIcon: Icons.send_rounded'));
    expect(source, contains('_submitClassNameFromComposer'));
    expect(source, contains('_selectClassAcademicYear'));
    expect(source, contains('_api.getNotifications()'));
    expect(source, contains('unreadNotifications: _unreadNotifications'));
    expect(source, contains("'Confirm & Create'"));
    expect(source, contains('Future<void> _confirmAndCreate()'));
    expect(source, isNot(contains('drawer:')));
    expect(source, isNot(contains('Icons.menu')));
    expect(source, isNot(contains('mock')));
    expect(source, isNot(contains('demo')));
    expect(source, isNot(contains('sample')));
    expect(source, isNot(contains('badge: 3')));
    expect(source, isNot(contains('AlertDialog(')));
    expect(source, contains('mainAxisExtent: 96'));
    expect(source, contains('SliverGridDelegateWithFixedCrossAxisCount'));
    expect(source, contains('BouncingScrollPhysics'));
    expect(source, contains('SafeArea('));
  });

  test('principal events and inbox use directory workflows', () {
    final events = File(
      'lib/features/calendar/presentation/screens/events_calendar_screen/events_calendar_screen.dart',
    ).readAsStringSync();
    final inbox = File(
      'lib/features/communication/presentation/screens/principal_inbox_screen/principal_operational_inbox_screen.dart',
    ).readAsStringSync();
    final routes = File('lib/routes/app_routes.dart').readAsStringSync();
    final guard = File('lib/routes/route_access_guard.dart').readAsStringSync();
    final dashboard = File(
      'lib/features/dashboard/presentation/screens/principal_dashboard_screen/principal_dashboard_screen.dart',
    ).readAsStringSync();
    final appNavigation = File(
      'lib/core/widgets/app_navigation.dart',
    ).readAsStringSync();

    expect(events, contains('Events Directory'));
    expect(events, contains('PrincipalDirectoryScaffold'));
    expect(events, contains('Event Details'));
    expect(events, contains('Create Event'));
    expect(events, contains('Live school calendar'));
    expect(events, contains('_EventFilter.month'));
    expect(events, contains('_selectedMonthCount'));
    expect(events, contains('overlapsMonth'));
    expect(events, contains('overlapsDate'));
    expect(events, contains('Approve event'));
    expect(events, contains('Cancel event'));
    expect(events, contains('_setEventStatus'));
    expect(events, contains('End time must be after start time.'));
    expect(events, contains('Holiday rows are saved as all-day events'));
    expect(events, contains("'event_name': _titleController.text.trim()"));
    expect(events, contains("'audience_type': _audience"));
    expect(events, contains("'is_holiday': _isHoliday"));
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

  test('principal attendance UI uses directory workflow without QR display', () {
    final screenFile = File(
      'lib/features/attendance/presentation/screens/principal_attendance_screen/principal_attendance_screen.dart',
    );
    final routes = File('lib/routes/app_routes.dart').readAsStringSync();
    final client = readBackendApiSources();
    final backendRoutes = readBackendRouteSources();

    expect(screenFile.existsSync(), isTrue);
    final screen = screenFile.readAsStringSync();
    expect(screen, contains('Attendance Directory'));
    expect(
      screen,
      contains('Class-wise sessions, student rolls, and attendance history'),
    );
    expect(screen, contains('PrincipalDirectoryScaffold'));
    expect(screen, contains('PrincipalDetailPage'));
    expect(screen, isNot(contains('Daily Staff QR')));
    expect(screen, isNot(contains('QrImageView')));
    expect(screen, contains('_AttendanceView.classes'));
    expect(screen, contains('_classAttendanceCards'));
    expect(screen, contains('_openClassesHub'));
    expect(screen, contains("class_hub_action': action"));
    expect(screen, contains("source': 'principal_attendance'"));
    expect(screen, contains("_AttendanceView.students"));
    expect(screen, contains('Class attendance register'));
    expect(screen, contains('Open class in Classes Hub'));
    expect(screen, isNot(contains('PrincipalInputPage')));
    expect(screen, isNot(contains('Create Attendance Report')));
    expect(screen, isNot(contains('createReportExport')));
    expect(routes, contains('PrincipalAttendanceScreen'));
    expect(routes, contains('principalAttendance'));
    expect(client, contains('Future<List<AttendanceSessionModel>>'));
    expect(client, contains('getStaffAttendanceForDate'));
    expect(client, contains('getStudentAttendanceRecords'));
    expect(backendRoutes, contains('attendance.GET("/sessions"'));
    expect(backendRoutes, contains('attendance.GET("/reports/exports"'));
  });

  test('principal staff and guardian v1 routes match app calls', () {
    final backendRoutes = readBackendRouteSources();
    final staffScreen = File(
      'lib/features/people/presentation/screens/staff_management_screen/staff_management_screen.dart',
    ).readAsStringSync();
    final guardianScreen = File(
      'lib/features/people/presentation/screens/guardian_directory_screen/guardian_directory_screen.dart',
    ).readAsStringSync();

    expect(staffScreen, contains("getRawList(\n        '/staff-subjects'"));
    expect(guardianScreen, contains("getRawList(\n        '/guardians'"));
    expect(
      backendRoutes,
      contains('staffSubjects := api.Group("/staff-subjects")'),
    );
    expect(
      backendRoutes,
      contains('staffDocuments := api.Group("/staff-documents")'),
    );
    expect(backendRoutes, contains('guardians := api.Group("/guardians")'));
  });

  test('principal classes UI is routed and backend remains wired', () {
    final screenFile = File(
      'lib/features/academics/presentation/screens/principal_classes_screen/principal_classes_screen.dart',
    );
    final routes = File('lib/routes/app_routes.dart').readAsStringSync();
    final client = readBackendApiSources();
    final backendRoutes = readBackendRouteSources();
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
        'lib/features/people/presentation/screens/student_oversight_screen/student_oversight_screen.dart',
      ).readAsStringSync();
      final moduleScaffold = File(
        'lib/core/widgets/erp_module_scaffold.dart',
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
      'lib/features/academics/presentation/screens/principal_subjects_screen/principal_subjects_screen.dart',
    ).readAsStringSync();
    final routes = File('lib/routes/app_routes.dart').readAsStringSync();
    final client = readBackendApiSources();
    final backendRoutes = readBackendRouteSources();
    final backend = File(
      'school-backend/internal/handlers/principal_subjects.go',
    ).readAsStringSync();
    final crud = File(
      'school-backend/internal/handlers/crud.go',
    ).readAsStringSync();

    expect(routes, contains('PrincipalSubjectsScreen'));
    expect(screen, contains('Subjects Directory'));
    expect(screen, contains("String _workspaceView = 'Subjects'"));
    expect(screen, contains('Setup Subjects in Class Hub'));
    expect(screen, contains('_openClassesHubForSubjects'));
    expect(screen, contains("class_hub_action': 'subjects'"));
    expect(screen, contains("source': 'principal_subjects'"));
    expect(screen, contains('PrincipalShellBottomBar'));
    expect(screen, contains('PrincipalDirectoryCard'));
    expect(screen, contains('PrincipalDetailPage'));
    expect(screen, contains('Mapped'));
    expect(screen, contains('Class Coverage'));
    expect(screen, contains('Syllabus Pending'));
    expect(screen, contains('Total Subjects'));
    expect(screen, contains('Core Subjects'));
    expect(screen, contains('Teacher Load'));
    expect(screen, contains('Class / Grade'));
    expect(screen, contains('teacher_class_coverage'));
    expect(screen, contains('Open Classes Hub'));
    expect(screen, contains('Subject-wise Topper List'));
    expect(screen, contains('Weak Subject Detection'));
    expect(screen, contains('Syllabus Completion Tracker'));
    expect(screen, contains('Teacher Performance'));
    expect(screen, contains('Homework Consistency'));
    expect(screen, isNot(contains('Create Subject')));
    expect(screen, isNot(contains('Map / assign')));
    expect(screen, isNot(contains('Add Subject / Teacher')));
    expect(screen, isNot(contains('savePrincipalSubjectMapping')));
    expect(screen, isNot(contains('PrincipalInputPage')));
    expect(screen, isNot(contains('Map Subject to Class')));
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
      'lib/features/academics/presentation/screens/principal_command_center_screens/principal_academic_command_screens.dart',
    ).readAsStringSync();
    final examReview = File(
      'lib/features/academics/presentation/screens/principal_command_center_screens/principal_exam_review_screen.dart',
    ).readAsStringSync();
    final routes = File('lib/routes/app_routes.dart').readAsStringSync();
    final drawer = File(
      'lib/core/widgets/app_navigation.dart',
    ).readAsStringSync();
    final client = readBackendApiSources();
    final backendRoutes = readBackendRouteSources();
    final backend = File(
      'school-backend/internal/handlers/principal_academic_command.go',
    ).readAsStringSync();
    final examHandler = File(
      'school-backend/internal/handlers/exam.go',
    ).readAsStringSync();
    final examModels = File(
      'school-backend/internal/models/exam.go',
    ).readAsStringSync();

    expect(routes, contains('PrincipalTimetableScreen'));
    expect(routes, contains('PrincipalExamsScreen'));
    expect(routes, contains('PrincipalResultsScreen'));
    expect(drawer, contains('route: AppRoutes.principalTimetable'));
    expect(drawer, contains('route: AppRoutes.principalExams'));
    expect(drawer, contains('route: AppRoutes.principalResults'));

    expect(screen, contains('View and explore live timetables'));
    expect(screen, contains('_TimetableHomeMode.classes'));
    expect(screen, contains('_TimetableHomeMode.teachers'));
    expect(screen, contains('_TimetableHomeMode.rooms'));
    expect(screen, contains("label: 'Classes'"));
    expect(screen, contains("label: 'Teachers'"));
    expect(screen, contains("label: 'Conflicts'"));
    expect(screen, contains('Class Timetable'));
    expect(screen, contains('Teacher Timetable'));
    expect(screen, contains('Room Timetable'));
    expect(screen, contains('Filter Timetable'));
    expect(
      screen,
      contains('Edit generated class periods from the Action column'),
    );
    expect(screen, contains("class_hub_action': 'timetable'"));
    expect(screen, contains("source': 'principal_timetable'"));
    expect(screen, contains('final tableWidth = constraints.maxWidth < 650'));
    expect(screen, contains('width: tableWidth'));
    expect(
      screen,
      isNot(contains('constraints: const BoxConstraints(minWidth: 650)')),
    );
    expect(screen, isNot(contains('createPrincipalTimetableAction')));

    expect(screen, contains("import 'principal_exam_review_screen.dart';"));
    expect(screen, contains('PrincipalExamReviewScreen.examsHome'));
    expect(screen, contains('PrincipalExamReviewScreen.results'));
    expect(examReview, contains('enum _PrincipalExamView'));
    expect(examReview, contains('_PrincipalExamView.home'));
    expect(examReview, contains('_PrincipalExamView.examinations'));
    expect(examReview, contains('_PrincipalExamView.examDetails'));
    expect(examReview, contains('_PrincipalExamView.schedule'));
    expect(examReview, contains('_PrincipalExamView.results'));
    expect(examReview, contains('_PrincipalExamView.resultDetails'));
    expect(examReview, contains('_PrincipalExamView.subjectResults'));
    expect(examReview, contains('_PrincipalExamView.studentResult'));
    expect(examReview, contains('_PrincipalExamView.gradeSetup'));
    expect(examReview, contains('_PrincipalExamView.reports'));
    expect(examReview, contains("_buildHeader('Exams'"));
    expect(examReview, contains('View and manage exam information'));
    expect(examReview, contains('Total Exams'));
    expect(examReview, contains('Upcoming'));
    expect(examReview, contains('Completed'));
    expect(examReview, contains('Total Subjects'));
    expect(examReview, contains('Total Students'));
    expect(examReview, contains('Results Published'));
    expect(examReview, contains('Examination List'));
    expect(examReview, contains('Exam Schedule'));
    expect(examReview, contains('Results'));
    expect(examReview, contains('Grade Setup'));
    expect(examReview, contains('Exam Reports'));
    expect(
      examReview,
      contains(
        'Teachers prepare syllabus, schedules, marks, and report cards.',
      ),
    );
    expect(examReview, contains('Principal reviews and publishes'));
    expect(examReview, contains('Publish Exam Timetable'));
    expect(examReview, contains("actionType: 'publish_exam_timetable'"));
    expect(examReview, contains("actionType: 'publish_results'"));
    expect(examReview, contains("actionType: 'hold_results'"));
    expect(examReview, contains("getRawList('/exams/grading-scale')"));
    expect(examReview, contains("getRawList('/exams/report-cards')"));
    expect(examReview, contains("'/exams/report-cards/exports'"));
    expect(examReview, contains('createReportExport('));
    expect(examReview, contains('Subject Wise Results'));
    expect(examReview, contains('Student Result'));
    expect(examReview, contains('Download Marksheet'));
    expect(examReview, contains('Go to Classes Hub'));
    expect(examReview, contains("class_hub_action': 'exams'"));
    expect(examReview, contains("selectedStep': 'exam_setup'"));
    expect(examReview, contains("source': 'principal_exams'"));
    expect(examReview, contains('Step 5 (Exams)'));
    expect(examReview, isNot(contains("createRaw('/exams'")));
    expect(examReview, isNot(contains("createRaw('/exams/schedules'")));
    expect(examReview, isNot(contains('PrincipalInputPage')));

    expect(client, contains('getPrincipalTimetableOverview'));
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
    expect(backend, contains('schedule_details'));
    expect(backend, contains('examScheduleDetailRows'));
    expect(backend, contains('class_names'));
    expect(backend, contains('subject_names'));
    expect(backend, contains('"syllabus"'));
    expect(backend, contains('weakStudentRows'));
    expect(examHandler, contains('Syllabus  string `json:"syllabus"`'));
    expect(examHandler, contains('Syllabus:  strings.TrimSpace(req.Syllabus)'));
    expect(examModels, contains('Syllabus     string'));
  });

  test('app uses controlled text scale instead of system display text scale', () {
    final main = File('lib/main.dart').readAsStringSync();
    final settings = File(
      'lib/core/services/theme_provider.dart',
    ).readAsStringSync();
    final settingsScreen = File(
      'lib/features/profile/presentation/screens/settings_screen/settings_screen.dart',
    ).readAsStringSync();
    final students = File(
      'lib/features/people/presentation/screens/student_oversight_screen/student_oversight_screen.dart',
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
        'lib/features/profile/presentation/screens/school_profile_screen/school_profile_screen.dart',
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
        'lib/features/people/presentation/screens/student_oversight_screen/student_oversight_screen.dart',
      ).readAsStringSync();
      final backendRoutes = readBackendRouteSources();
      final teachers = File(
        'lib/features/people/presentation/screens/staff_management_screen/staff_management_screen.dart',
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
      'lib/features/people/presentation/screens/student_oversight_screen/student_oversight_screen.dart',
    ).readAsStringSync();
    final client = readBackendApiSources();
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
      'lib/features/people/presentation/screens/student_oversight_screen/student_oversight_screen.dart',
    ).readAsStringSync();
    final teachers = File(
      'lib/features/people/presentation/screens/staff_management_screen/staff_management_screen.dart',
    ).readAsStringSync();
    final guardians = File(
      'lib/features/people/presentation/screens/guardian_directory_screen/guardian_directory_screen.dart',
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
    final source = File(
      'lib/core/widgets/admin_navigation.dart',
    ).readAsStringSync();

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
      'lib/features/people/presentation/screens/admin_user_access_screen/admin_user_access_screen.dart',
    ).readAsStringSync();

    expect(source, contains("['Teacher', 'Parent']"));
    expect(source, contains('permanent: true'));
    expect(source, contains('Delete Inactive Account Permanently'));
  });

  test('principal communications use live direct messages backend flow', () {
    final client = File(
      'lib/core/network/api_modules/communications_api.dart',
    ).readAsStringSync();
    final principal = File(
      'lib/features/communication/presentation/screens/communication_center_screen/communication_center_screen.dart',
    ).readAsStringSync();
    final teacher = File(
      'lib/features/communication/presentation/screens/teacher_communication_screen/teacher_communication_screen.dart',
    ).readAsStringSync();
    final parent = File(
      'lib/features/communication/presentation/screens/parent_teacher_chat_screen/parent_teacher_chat_screen.dart',
    ).readAsStringSync();
    final backend = File(
      'school-backend/internal/handlers/tables_md_crud.go',
    ).readAsStringSync();

    expect(
      client,
      contains('Future<List<Map<String, dynamic>>> getCommunications'),
    );
    expect(client, contains('sendCommunication'));
    expect(client, contains('markCommunicationRead'));
    expect(client, contains("createTablesMDRow('communications'"));
    expect(principal, contains('TabController(length: 4'));
    expect(principal, contains("Tab(text: 'Messages')"));
    expect(principal, contains('getCommunications()'));
    expect(principal, contains('getUsers('));
    expect(principal, contains('sendCommunication('));
    expect(principal, contains('markCommunicationRead('));
    expect(teacher, contains('_buildPrincipalMessages'));
    expect(teacher, contains('getCommunications()'));
    expect(parent, contains('Principal Messages'));
    expect(parent, contains('getCommunications()'));
    expect(backend, contains('prepareCommunicationCreate'));
    expect(backend, contains('sender_id is derived from authentication'));
    expect(backend, contains('receiver_role does not match receiver user'));
  });

  test('principal timetable supports dropdown-only manual slot edits', () {
    final wrapper = File(
      'lib/features/academics/presentation/screens/timetable_management_screen/timetable_management_screen.dart',
    ).readAsStringSync();
    final source = File(
      'lib/features/academics/presentation/screens/principal_command_center_screens/principal_academic_command_screens.dart',
    ).readAsStringSync();
    final backendRoutes = readBackendRouteSources();

    expect(wrapper, contains('PrincipalTimetableScreen'));
    expect(wrapper, isNot(contains('AdminTimetablePeriodFormScreen')));
    expect(wrapper, isNot(contains('AdminTimetableGenerationFormScreen')));
    expect(wrapper, isNot(contains("deleteRaw('/timetable/slots/")));
    expect(source, contains('_openEditPeriodForm'));
    expect(source, contains("'/timetable/slots/\$id'"));
    expect(source, contains('Edit timetable slot'));
    expect(source, contains("labelText: 'Day'"));
    expect(source, contains("labelText: 'Period / time'"));
    expect(source, contains("labelText: 'Subject'"));
    expect(source, contains("labelText: 'Teacher'"));
    expect(source, contains("labelText: 'Room'"));
    expect(source, isNot(contains('Delete timetable slot')));
    expect(source, contains('getPrincipalTimetableOverview'));
    expect(source, contains("class_hub_action': 'timetable'"));
    expect(source, contains("source': 'principal_timetable'"));
    expect(source, isNot(contains('createPrincipalTimetableAction')));
    expect(source, isNot(contains('Timetable review saved')));
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
    expect(
      backendRoutes,
      contains(
        'timetable.POST("/slots/generate", middleware.RBACMiddleware("Admin")',
      ),
    );
    expect(
      backendRoutes,
      contains(
        'timetable.POST("/smart/preview", middleware.RBACMiddleware("Admin", "Principal")',
      ),
    );
    expect(
      backendRoutes,
      contains(
        'timetable.POST("/smart/generate", middleware.RBACMiddleware("Admin", "Principal")',
      ),
    );
    expect(backendRoutes, contains('principal.GET("/timetable"'));
  });

  test('principal timetable wrapper removes stale substitution writer UI', () {
    final source = File(
      'lib/features/academics/presentation/screens/timetable_management_screen/timetable_management_screen.dart',
    ).readAsStringSync();

    expect(source, contains('PrincipalTimetableScreen'));
    expect(source, isNot(contains('String _staffLabel(dynamic value')));
    expect(source, isNot(contains("s['original_staff']")));
    expect(source, isNot(contains("s['substitute_staff']")));
    expect(source, isNot(contains("Text(\n                  s['teacher']")));
    expect(source, isNot(contains("\${s['date']} · \${s['periods']}")));
  });

  test(
    'principal academics expose academic year setup without broad create workflows',
    () {
      final exams = File(
        'lib/features/academics/presentation/screens/exams_results_screen/exams_results_screen.dart',
      ).readAsStringSync();
      final academics = File(
        'lib/features/academics/presentation/screens/academic_management_screen/academic_management_screen.dart',
      ).readAsStringSync();
      final routes = File('lib/routes/app_routes.dart').readAsStringSync();

      expect(exams, isNot(contains('Add New Exam')));
      expect(exams, isNot(contains('Save Changes')));
      expect(routes, contains("role == 'principal' ? 'principal' : 'admin'"));
      expect(academics, contains('Configure academic years'));
      expect(academics, contains('canManageAcademicYears'));
      expect(academics, contains("ownerRole.toLowerCase() == 'principal'"));
      expect(academics, contains('onTogglePublish: isAdminOwner'));
    },
  );

  test(
    'principal profile uses backend file upload for avatar instead of URL entry',
    () {
      final screen = File(
        'lib/features/profile/presentation/screens/profile_management_screen/profile_management_screen.dart',
      ).readAsStringSync();
      final client = readBackendApiSources();
      final backend = readBackendRouteSources();

      expect(screen, contains('pickImage'));
      expect(screen, isNot(contains('Profile Picture URL')));
      expect(client, contains('uploadProfileAvatar'));
      expect(backend, contains('/profile/avatar'));
    },
  );
}
