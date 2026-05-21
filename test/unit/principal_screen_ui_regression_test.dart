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

  test('fee monitoring mirrors admin read data without admin-only actions', () {
    final source = File(
      'lib/presentation/fee_monitoring_screen/fee_monitoring_screen.dart',
    ).readAsStringSync();

    expect(source, contains('TabController(length: 5'));
    expect(source, contains("Tab(text: 'Payments')"));
    expect(
      source,
      contains('List<Map<String, dynamic>> _recentPayments = [];'),
    );
    expect(
      source,
      contains('feeStructures.map(_normalizeFeeStructure).toList()'),
    );
    expect(source, contains('studentFees.map(_normalizeInvoice).toList()'));
    expect(source, contains('studentFees.expand(_normalizePayments).toList()'));
    expect(
      source,
      contains('Payment recording and receipt generation are admin-managed'),
    );
    expect(source, isNot(contains('_showRecordPaymentDialog')));
    expect(source, isNot(contains('_showGenerateInvoiceDialog')));
  });

  test(
    'fee monitoring class filters keep readable selected and unselected states',
    () {
      final source = File(
        'lib/presentation/fee_monitoring_screen/fee_monitoring_screen.dart',
      ).readAsStringSync();

      expect(source, contains('Widget _buildClassFilterChip('));
      expect(source, contains('selectedColor: AppTheme.primary'));
      expect(source, contains('backgroundColor: AppTheme.surface'));
      expect(source, contains('checkmarkColor: AppTheme.onPrimary'));
      expect(source, contains('labelStyle: GoogleFonts.dmSans'));
    },
  );

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
    expect(dashboard, contains('crossAxisCount: compact ? 2 : 3'));
    expect(dashboard, contains('mainAxisExtent: compact ? 112 : 116'));
    expect(dashboard, contains('constraints.maxWidth < 340'));
    expect(dashboard, contains('SafeArea('));
    expect(dashboard, contains('height: 66'));
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
      expect(students, contains('BackendApiClient.instance.createStudent'));
      expect(students, contains('setStudentParent'));
      expect(students, contains('uploadStudentPhoto'));
      expect(teachers, contains('Crop Teacher Photo'));
      expect(teachers, contains('_requiredFullName'));
      expect(teachers, contains('_requiredPhone'));
      expect(teachers, contains('BackendApiClient.instance.createStaff'));
      expect(teachers, contains('uploadStaffPhoto'));
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
    expect(students, contains('Remove Student'));
    expect(
      students,
      contains('api.BackendApiClient.instance.deleteStudent(student.id)'),
    );
    expect(students, contains('moved to inactive records'));
    expect(client, contains('Future<void> deleteStudent(String id)'));
    expect(backend, contains('Update("status", "inactive")'));
  });

  test('principal student and teacher directories harden compact layouts', () {
    final students = File(
      'lib/presentation/student_oversight_screen/student_oversight_screen.dart',
    ).readAsStringSync();
    final teachers = File(
      'lib/presentation/staff_management_screen/staff_management_screen.dart',
    ).readAsStringSync();

    for (final source in [students, teachers]) {
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

  test('principal timetable is oversight with advice requests only', () {
    final source = File(
      'lib/presentation/timetable_management_screen/timetable_management_screen.dart',
    ).readAsStringSync();

    expect(source, contains('Raise Advice'));
    expect(source, contains('/principal/timetable-advice'));
    expect(source, contains('suggestTimetableSlots('));
    expect(source, contains('Timetable suggestions sent to Admin'));
    expect(source, isNot(contains('rootNavigator: true')));
    expect(source, isNot(contains("label: const Text('Add Period')")));
    expect(source, isNot(contains('void _showEditPeriodDialog')));
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
