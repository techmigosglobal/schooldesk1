import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('principal classes load depends on backend-backed setup resources', () {
    final screen = File(
      'lib/features/academics/presentation/screens/principal_classes_screen/principal_classes_screen.dart',
    ).readAsStringSync();
    final repository = File(
      'lib/roles/principal/data/api_principal_classes_repository.dart',
    ).readAsStringSync();
    final index = File('supabase/functions/api/index.ts').readAsStringSync();

    expect(screen, contains('_repository.loadOverview(forceRefresh: true)'));
    expect(
      screen,
      contains('_repository.loadAcademicYears(forceRefresh: true)'),
    );
    expect(screen, contains('_repository.loadStaff(page: 1, pageSize: 100'));
    expect(screen, contains('_repository.loadSubjects()'));
    expect(screen, contains('_repository.loadGradeSubjects()'));
    expect(screen, contains('_repository.loadStaffSubjects()'));
    expect(repository, contains('_api.getPrincipalClassesOverview('));
    expect(repository, contains('_api.getAcademicYears('));
    expect(repository, contains('_api.getStaff('));
    expect(repository, contains("_api.getRawList('/subjects'"));
    expect(repository, contains("_api.getRawList(\n    '/grade-subjects'"));
    expect(repository, contains("_api.getRawList(\n    '/staff-subjects'"));
    expect(index, contains('path.startsWith("/staff-subjects")'));
  });

  test('principal classes handler guards UUID-like foreign keys', () {
    final principal = File(
      'supabase/functions/api/handlers/principal.ts',
    ).readAsStringSync();

    expect(principal, contains('function uuidText'));
    expect(principal, contains('function uuidList'));
    expect(principal, contains('const classTeacherId = await resolveStaffId('));
    expect(principal, contains('body.class_teacher_id,'));
    expect(principal, contains('body.co_teacher_id'));
    expect(
      principal,
      contains('const explicitId = uuidText(row.academic_year_id)'),
    );
    expect(principal, contains('const gradeId = uuidText(body.grade_id)'));
    expect(principal, contains('const roomId = uuidText(body.room_id)'));
    expect(
      principal,
      contains('const explicitId = uuidText(mapping.subject_id)'),
    );
    expect(principal, contains('uuidList(body.deleted_grade_subject_ids)'));
    expect(principal, contains('uuidList(body.deleted_staff_subject_ids)'));
    expect(principal, contains('uuidList(body.deleted_fee_structure_ids)'));
  });

  test(
    'principal classes details include class teacher and co-teacher names',
    () {
      final principal = File(
        'supabase/functions/api/handlers/principal.ts',
      ).readAsStringSync();
      final screen = File(
        'lib/features/academics/presentation/screens/principal_classes_screen/principal_classes_screen.dart',
      ).readAsStringSync();

      expect(
        principal,
        contains('class_teacher:staff!sections_class_teacher_id_fkey(*)'),
      );
      expect(
        principal,
        contains('co_teacher:staff!sections_co_teacher_id_fkey(*)'),
      );
      expect(principal, contains('class_teacher: staffDisplayName'));
      expect(principal, contains('co_teacher: staffDisplayName'));
      expect(screen, contains("'co_teacher_id': _classText("));
      expect(screen, contains("'class_teacher': _staffDisplayName("));
      expect(screen, contains("'co_teacher': _staffDisplayName("));
    },
  );

  test('staff management mirrors class and co-teacher section assignments', () {
    final staffManagement = File(
      'lib/features/people/presentation/screens/staff_management_screen/staff_management_screen.dart',
    ).readAsStringSync();
    final sectionModel = File(
      'lib/core/network/models/backend_models.dart',
    ).readAsStringSync();

    expect(
      staffManagement,
      matches(
        RegExp(
          r'section\.classTeacherId != staffId\s*&&\s*section\.coTeacherId != staffId',
        ),
      ),
      reason:
          'Assigned Classes must include sections where the staff member is '
          'the co-teacher, not only the class teacher.',
    );
    expect(
      sectionModel,
      contains("coTeacherId: _stringValue(json['co_teacher_id'])"),
    );
  });

  test('principal classes overview includes live class-hub fee dues', () {
    final principal = File(
      'supabase/functions/api/handlers/principal.ts',
    ).readAsStringSync();
    final screen = File(
      'lib/features/academics/presentation/screens/principal_classes_screen/principal_classes_screen.dart',
    ).readAsStringSync();

    expect(principal, contains('feeDuesBySection'));
    expect(principal, contains('svc.from("fee_invoices").select('));
    expect(principal, contains('student:students(current_section_id)'));
    expect(principal, contains('.gt("balance", 0)'));
    expect(principal, contains('fees_due_amount: feeDues.amount'));
    expect(principal, contains('fees_due_students: feeDues.students'));
    expect(screen, contains("row['fees_due_amount']"));
    expect(screen, contains("row['fees_due_students']"));
  });

  test('deleting a class also removes its orphaned grade and fee setup', () {
    final principal = File(
      'supabase/functions/api/handlers/principal.ts',
    ).readAsStringSync();
    final feeStructures = File(
      'lib/features/finance/presentation/screens/principal_dashboard/principal_fee_structures.dart',
    ).readAsStringSync();
    final migration = File(
      'supabase/migrations/20260714112246_enforce_notification_retention_and_remove_orphan_classes.sql',
    ).readAsStringSync();

    expect(principal, contains('const { data: section, error: sectionError }'));
    expect(principal, contains('sectionFeesError'));
    expect(principal, contains('remainingSectionsError'));
    expect(principal, contains('deleted_grade_id'));
    expect(feeStructures, contains('List<GradeModel> get _gradeOptions'));
    expect(
      feeStructures,
      contains('section.academicYearId == _selectedAcademicYearId'),
    );
    expect(migration, contains('delete from public.fee_structures fs'));
    expect(migration, contains('delete from public.grades g'));
  });

  test('staff subject assignments have a direct class name relationship', () {
    final migrations = Directory('supabase/migrations')
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.sql'))
        .map((file) => file.readAsStringSync())
        .join('\n');
    final academics = File(
      'supabase/functions/api/handlers/academics.ts',
    ).readAsStringSync();

    expect(
      migrations,
      contains('grade_id uuid references public.grades(id) on delete cascade'),
    );
    expect(migrations, contains('idx_staff_subjects_grade'));
    expect(
      academics,
      contains('staff:staff(*), subject:subjects(*), grade:grades(*)'),
    );
    expect(academics, contains('q = q.eq("grade_id"'));
  });

  test('classes hub subject setup only sends supported subject columns', () {
    final screen = File(
      'lib/features/academics/presentation/screens/principal_classes_screen/principal_classes_screen.dart',
    ).readAsStringSync();
    final academics = File(
      'supabase/functions/api/handlers/academics.ts',
    ).readAsStringSync();
    final subjectsHandler = academics.substring(
      academics.indexOf('if (path.startsWith("/subjects"))'),
      academics.indexOf('if (path.startsWith("/grade-subjects"))'),
    );

    final createSubject = screen.substring(
      screen.indexOf('class _CreateSubjectSetupPage'),
      screen.indexOf('class _EditSubjectSetupSheet'),
    );
    final editSubject = screen.substring(
      screen.indexOf('class _EditSubjectSetupSheet'),
      screen.indexOf('class _SubjectNameCode'),
    );

    for (final subjectForm in [createSubject, editSubject]) {
      expect(subjectForm, isNot(contains('credit_hours')));
      expect(subjectForm, isNot(contains('department_name')));
      expect(subjectForm, isNot(contains("label: 'Type'")));
      expect(subjectForm, isNot(contains("label: 'Department'")));
      expect(subjectForm, isNot(contains("label: 'Credits'")));
      expect(
        subjectForm,
        contains("'subject_name': _nameController.text.trim()"),
      );
      expect(
        subjectForm,
        contains("'subject_code': _codeController.text.trim()"),
      );
      expect(subjectForm, contains("'subject_color': _subjectColor"));
    }

    expect(subjectsHandler, contains('subjectPayload(body)'));
    expect(subjectsHandler, contains('subjectPayload(body, false)'));
    expect(subjectsHandler, isNot(contains('department:departments(*)')));
    expect(subjectsHandler, isNot(contains('...safe, school_id: sid')));
    expect(academics, contains('function subjectPayload'));
    expect(academics, contains('subject_name: text(payload["subject_name"])'));
    expect(
      academics,
      contains('subject_code: text(payload["subject_code"]) || null'),
    );
    expect(
      academics,
      contains('subject_color: text(payload["subject_color"]) || null'),
    );
  });

  test(
    'classes hub subjects are class-level without teacher or timetable prompts',
    () {
      final screen = File(
        'lib/features/academics/presentation/screens/principal_classes_screen/principal_classes_screen.dart',
      ).readAsStringSync();
      final academics = File(
        'supabase/functions/api/handlers/academics.ts',
      ).readAsStringSync();
      final subjectSetup = screen.substring(
        screen.indexOf('class _AssignSubjectsSetupPage'),
        screen.indexOf('class _FeesSetupPage'),
      );
      final assignedTile = screen.substring(
        screen.indexOf('class _AssignedSubjectTile'),
        screen.indexOf('class _EditSubjectSetupSheet'),
      );
      final subjectsHandler = academics.substring(
        academics.indexOf('if (path.startsWith("/subjects"))'),
        academics.indexOf('if (path.startsWith("/grade-subjects"))'),
      );

      expect(subjectSetup, isNot(contains('_setTeacher')));
      expect(subjectSetup, isNot(contains('_promptRegenerateTimetable')));
      expect(subjectSetup, isNot(contains('_regenerateTimetable')));
      expect(subjectSetup, isNot(contains('onTeacherChanged')));
      expect(subjectSetup, isNot(contains('teacherId')));
      expect(assignedTile, isNot(contains('_TeacherAssignmentDropdown')));
      expect(screen, isNot(contains('Regenerate timetable?')));
      expect(screen, isNot(contains('class _TeacherAssignmentDropdown')));
      expect(screen, isNot(contains('class _TeacherMiniLabel')));
      expect(
        subjectsHandler,
        contains('method === "PATCH" || method === "PUT"'),
      );
    },
  );

  test('class hub subject assignment persists only class-subject mappings', () {
    final screen = File(
      'lib/features/academics/presentation/screens/principal_classes_screen/principal_classes_screen.dart',
    ).readAsStringSync();
    final addSelectSubject = screen.substring(
      screen.indexOf('class _AddSelectSubjectSetupPage'),
      screen.indexOf('class _CreateSubjectSetupPage'),
    );
    final createSubject = screen.substring(
      screen.indexOf('class _CreateSubjectSetupPage'),
      screen.indexOf('class _EditSubjectSetupSheet'),
    );

    for (final subjectFlow in [addSelectSubject, createSubject]) {
      expect(subjectFlow, contains('saveSubjectMapping('));
      expect(subjectFlow, contains('periodsPerWeek: 0'));
      expect(subjectFlow, isNot(contains('teacherId:')));
      expect(subjectFlow, isNot(contains('assignmentId:')));
    }
  });

  test('classes hub subject assignments are scoped to the exact section', () {
    final screen = File(
      'lib/features/academics/presentation/screens/principal_classes_screen/principal_classes_screen.dart',
    ).readAsStringSync();
    final academics = File(
      'supabase/functions/api/handlers/academics.ts',
    ).readAsStringSync();
    final subjectSetup = screen.substring(
      screen.indexOf('class _AssignSubjectsSetupPage'),
      screen.indexOf('class _FeesSetupPage'),
    );
    final gradeSubjectsHandler = academics.substring(
      academics.indexOf('if (path.startsWith("/grade-subjects"))'),
      academics.indexOf('if (path.startsWith("/staff-subjects"))'),
    );
    final staffSubjectsHandler = academics.substring(
      academics.indexOf('if (path.startsWith("/staff-subjects"))'),
      academics.indexOf('if (path.startsWith("/rooms"))'),
    );

    expect(subjectSetup, contains('sectionId: _sectionId'));
    expect(subjectSetup, contains('_isClassGradeSubject(row)'));
    expect(
      subjectSetup,
      contains('_classText(row[\'section_id\']) == _sectionId'),
    );
    expect(
      gradeSubjectsHandler,
      contains('if (qp(url, "section_id")) q = q.eq("section_id"'),
    );
    expect(
      staffSubjectsHandler,
      contains('q = q.eq("section_id", qp(url, "section_id")!)'),
    );
  });

  test('classes hub overview subject counts use exact section mappings', () {
    final screen = File(
      'lib/features/academics/presentation/screens/principal_classes_screen/principal_classes_screen.dart',
    ).readAsStringSync();
    final overviewSubjects = screen.substring(
      screen.indexOf(
        'List<Map<String, dynamic>> _subjectsForClass(Map<String, dynamic> row)',
      ),
      screen.indexOf('String _teacherForSubject('),
    );

    expect(
      overviewSubjects,
      contains("final sectionId = _text(row['section_id'])"),
    );
    expect(
      overviewSubjects,
      contains("_text(item['section_id']) == sectionId"),
    );
    expect(
      overviewSubjects,
      isNot(
        contains(
          "..._gradeSubjects\n          .where((item) => _text(item['grade_id']) == gradeId)",
        ),
      ),
    );
  });

  test('principal subjects stays overview-only and separates class sections', () {
    final subjects = File(
      'lib/features/academics/presentation/screens/principal_subjects_screen/principal_subjects_screen.dart',
    ).readAsStringSync();

    expect(subjects, contains("'Subjects'"));
    expect(subjects, contains('subjectsByClassKey'));
    expect(subjects, contains("'section:\$sectionId'"));
    expect(subjects, contains("'grade:\$gradeId'"));
    expect(subjects, contains('_loadData();'));
    expect(subjects, contains('onRefresh: _loadData'));
    expect(subjects, isNot(contains('savePrincipalSubjectMapping(')));
    expect(subjects, isNot(contains('createPrincipalSubjectAction(')));
    expect(subjects, isNot(contains('Teacher Load')));
  });
}
