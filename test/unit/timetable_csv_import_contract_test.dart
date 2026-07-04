import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('class CSV timetable generation stays on the Admin timetable path', () {
    final importer = File(
      'lib/core/services/bulk_csv_import_service.dart',
    ).readAsStringSync();
    final adminTimetable = File(
      'lib/features/academics/presentation/screens/admin_timetable_screen/admin_timetable_screen.dart',
    ).readAsStringSync();
    final adminTimetableForms = File(
      'lib/features/academics/presentation/screens/admin_timetable_screen/admin_timetable_form_screens.dart',
    ).readAsStringSync();
    final timetableHandler = File(
      'supabase/functions/api/handlers/timetable.ts',
    ).readAsStringSync();
    final principalClasses = File(
      'lib/features/academics/presentation/screens/principal_classes_screen/principal_classes_screen.dart',
    ).readAsStringSync();
    final timetableApi = File(
      'lib/core/network/api_modules/timetable_api.dart',
    ).readAsStringSync();

    expect(importer, contains('BulkCsvImportTarget.classTimetables'));
    expect(importer, contains('generateSmartTimetable('));
    expect(
      importer,
      contains('breaks: _breakRowsFor(row, days, periodsPerDay)'),
    );
    expect(importer, contains('short_break_period'));
    expect(importer, contains('short_break_start_time'));
    expect(importer, contains('short_break_end_time'));
    expect(importer, contains('long_break_period'));
    expect(importer, contains('long_break_start_time'));
    expect(importer, contains('long_break_end_time'));
    expect(importer, contains('Lunch Break'));
    expect(importer, contains("route: AppRoutes.principalClasses"));
    expect(importer, contains('getTerms(year.id)'));
    expect(importer, contains('section.academicYearId != academicYearId'));
    expect(importer, contains('working_days'));
    expect(importer, contains('periods_per_week'));
    expect(importer, contains('created_slots'));
    expect(importer, contains('conflicts'));
    expect(importer, contains('logs'));

    expect(adminTimetable, contains('BulkCsvImportService.importCsv'));
    expect(adminTimetable, contains('BulkCsvImportTarget.classTimetables'));
    expect(adminTimetable, contains('Import CSV'));
    expect(adminTimetable, contains('Generate Time Table'));
    expect(adminTimetable, contains('DropdownButtonFormField<String>'));
    expect(adminTimetable, contains("labelText: 'Class'"));
    expect(adminTimetable, contains('generateSmartTimetable('));
    expect(adminTimetable, isNot(contains('applyPrePrimaryClassSchedule(')));
    expect(adminTimetable, isNot(contains("value: 'preschool'")));
    expect(adminTimetable, isNot(contains("value: 'smart'")));
    expect(adminTimetable, contains("labelText: 'End time'"));
    expect(adminTimetable, contains("labelText: 'Break name'"));
    expect(adminTimetable, isNot(contains('Create a term for this academic year')));
    expect(adminTimetable, contains('_TimetableBreakDraft'));
    expect(adminTimetable, contains('_buildGeneratedWeekEditor'));
    expect(adminTimetable, contains('_publishGeneratedWeek'));
    expect(adminTimetable, isNot(contains('Add single period')));
    expect(adminTimetable, isNot(contains('Add substitution')));
    expect(adminTimetable, isNot(contains('Single Period Modification')));
    expect(adminTimetable, isNot(contains('Preschool Schedule')));
    expect(adminTimetable, isNot(contains('Apply preschool schedule')));
    expect(adminTimetable, contains('await _loadBackendTimetable();'));
    expect(adminTimetable, contains('api.getRooms()'));
    expect(adminTimetable, contains('_buildClassDropdown'));
    expect(
      adminTimetableForms,
      contains("decoration: const InputDecoration(labelText: 'Room')"),
    );
    expect(adminTimetableForms, contains("'room_id': _roomId"));
    expect(timetableHandler, contains('timetable_slots'));
    expect(timetableHandler, contains('room_id'));
    expect(timetableHandler, contains('buildClassSubjectAssignments'));
    expect(timetableHandler, contains('staff_id: null'));
    expect(timetableHandler, isNot(contains('staff_subjects')));
    expect(timetableHandler, contains('body.end_time'));
    expect(timetableApi, contains("'breaks': breaks"));
    expect(timetableApi, contains("'end_time': endTime.trim()"));
    expect(timetableApi, contains("if (termId.trim().isNotEmpty) 'term_id'"));

    expect(principalClasses, contains('BulkCsvImportTarget.classes'));
    expect(principalClasses, contains("label: 'Room Number'"));
    expect(principalClasses, isNot(contains("label: 'Short break period'")));
    expect(principalClasses, isNot(contains("label: 'Short break start'")));
    expect(principalClasses, isNot(contains("label: 'Short break end'")));
    expect(principalClasses, isNot(contains("label: 'Long break period'")));
    expect(principalClasses, isNot(contains("label: 'Long break start'")));
    expect(principalClasses, isNot(contains("label: 'Long break end'")));
    expect(principalClasses, isNot(contains('breaks: _breakRows')));
    expect(
      principalClasses,
      isNot(contains('BulkCsvImportTarget.classTimetables')),
    );
  });

  test('teacher timetable output remains the same backend slot source', () {
    final timetableApi = File(
      'lib/core/network/api_modules/timetable_api.dart',
    ).readAsStringSync();
    final teacherTimetable = File(
      'lib/features/academics/presentation/screens/teacher_timetable_screen/teacher_timetable_screen.dart',
    ).readAsStringSync();

    expect(timetableApi, contains('staff_id'));
    expect(timetableApi, contains('/timetable/slots'));
    expect(timetableApi, contains('/timetable/smart/generate'));
    expect(teacherTimetable, contains('Weekly Timetable'));
    expect(teacherTimetable, contains('_slotsByDay'));
    expect(teacherTimetable, contains('RoleAccessService.teacherSubjectIds'));
    expect(teacherTimetable, isNot(contains('Quick Actions')));
    expect(teacherTimetable, isNot(contains('_buildQuickActions')));
  });

  test('teacher timetable remains scoped to teacher and class slots', () {
    final principalClasses = File(
      'lib/features/academics/presentation/screens/principal_classes_screen/principal_classes_screen.dart',
    ).readAsStringSync();
    final teacherTimetable = File(
      'lib/features/academics/presentation/screens/teacher_timetable_screen/teacher_timetable_screen.dart',
    ).readAsStringSync();

    expect(principalClasses, contains('BulkCsvImportTarget.classes'));
    expect(
      teacherTimetable,
      contains('staffId: RoleAccessService.teacherStaffId'),
    );
    expect(teacherTimetable, contains('_weeklySubjects'));
  });

  test('principal timetable generation publishes class-owned weekly slots', () {
    final adminTimetable = File(
      'lib/features/academics/presentation/screens/admin_timetable_screen/admin_timetable_screen.dart',
    ).readAsStringSync();
    final timetableApi = File(
      'lib/core/network/api_modules/timetable_api.dart',
    ).readAsStringSync();
    final timetableHandler = File(
      'supabase/functions/api/handlers/timetable.ts',
    ).readAsStringSync();

    expect(adminTimetable, contains('var endTimeText'));
    expect(adminTimetable, contains('var generatedWeekDrafts'));
    expect(adminTimetable, contains('Balanced weekly'));
    expect(adminTimetable, contains('Save Week Timetable'));
    expect(adminTimetable, contains('staffId: draft.staffId'));
    expect(timetableApi, contains('String staffId = \'\''));
    expect(timetableApi, contains("'staff_id': null"));
    expect(timetableHandler, contains('breaksByDay'));
    expect(timetableHandler, contains('distributeSubjectsBalancedWeekly'));
  });

  test('teacher timetable falls back to assigned class slots', () {
    final teacherTimetable = File(
      'lib/features/academics/presentation/screens/teacher_timetable_screen/teacher_timetable_screen.dart',
    ).readAsStringSync();

    expect(teacherTimetable, contains('_loadTeacherTimetableSlots'));
    expect(teacherTimetable, contains('staffScopedSlots'));
    expect(teacherTimetable, contains('classScopedSlots'));
    expect(teacherTimetable, contains('RoleAccessService.teacherClassId'));
    expect(
      teacherTimetable,
      contains('sectionId: RoleAccessService.teacherClassId'),
    );
    expect(teacherTimetable, contains('Timetable source: assigned class'));
  });

  test('add period filters subjects to mapped grade-year subjects', () {
    final adminTimetableForms = File(
      'lib/features/academics/presentation/screens/admin_timetable_screen/admin_timetable_form_screens.dart',
    ).readAsStringSync();

    expect(adminTimetableForms, contains('_mappedSubjectOptions'));
    expect(adminTimetableForms, contains('_subjectIsMappedToSelectedClass'));
    expect(adminTimetableForms, contains('_selectedClassGradeId'));
    expect(
      adminTimetableForms,
      contains(r'Map ${_subjectNameById(_subjectId)} to'),
    );
    expect(
      adminTimetableForms,
      contains('Only subjects mapped to this class grade can be scheduled.'),
    );
    expect(adminTimetableForms, contains('subject must be mapped'));
  });
}
