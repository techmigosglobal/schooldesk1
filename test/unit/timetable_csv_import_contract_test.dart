import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('class timetable management stays on the manual Principal path', () {
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

    expect(adminTimetable, contains('Timetable Management'));
    expect(adminTimetable, contains('Create Editable Timetable'));
    expect(adminTimetable, contains('Day-wise Timetable'));
    expect(adminTimetable, contains('Week-wise Timetable'));
    expect(adminTimetable, contains('_deleteDayCell'));
    expect(adminTimetable, isNot(contains('Delete Extra Period Rows')));
    expect(adminTimetable, isNot(contains('_deletePeriodColumn')));
    expect(adminTimetable, contains('DropdownButtonFormField<String>'));
    expect(adminTimetable, contains("labelText: 'Select Class'"));
    expect(adminTimetable, contains('createTimetableSlot('));
    expect(adminTimetable, contains('deleteTimetableSlot('));
    expect(adminTimetable, isNot(contains('BulkCsvImportService.importCsv')));
    expect(
      adminTimetable,
      isNot(contains('BulkCsvImportTarget.classTimetables')),
    );
    expect(adminTimetable, isNot(contains('Import CSV')));
    expect(adminTimetable, isNot(contains('Generate Time Table')));
    expect(adminTimetable, isNot(contains('generateSmartTimetable(')));
    expect(adminTimetable, isNot(contains('applyPrePrimaryClassSchedule(')));
    expect(adminTimetable, isNot(contains("value: 'preschool'")));
    expect(adminTimetable, isNot(contains("value: 'smart'")));
    expect(adminTimetable, contains("label: 'End Time'"));
    expect(adminTimetable, contains("labelText: 'Break Name'"));
    expect(
      adminTimetable,
      isNot(contains('Create a term for this academic year')),
    );
    expect(adminTimetable, contains('_TimetableBreakDraft'));
    expect(adminTimetable, contains('_buildManualEditor'));
    expect(adminTimetable, contains('_saveManualTimetable'));
    expect(adminTimetable, isNot(contains('Add single period')));
    expect(adminTimetable, isNot(contains('Add substitution')));
    expect(adminTimetable, isNot(contains('Single Period Modification')));
    expect(adminTimetable, isNot(contains('Preschool Schedule')));
    expect(adminTimetable, isNot(contains('Apply preschool schedule')));
    expect(adminTimetable, contains('await _loadData();'));
    expect(adminTimetable, isNot(contains('api.getRooms()')));
    expect(
      adminTimetableForms,
      contains("decoration: const InputDecoration(labelText: 'Room')"),
    );
    expect(adminTimetableForms, contains("roomId: _roomId"));
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

  test('principal manual timetable publishes class-owned weekly slots', () {
    final adminTimetable = File(
      'lib/features/academics/presentation/screens/admin_timetable_screen/admin_timetable_screen.dart',
    ).readAsStringSync();
    final timetableApi = File(
      'lib/core/network/api_modules/timetable_api.dart',
    ).readAsStringSync();
    final timetableHandler = File(
      'supabase/functions/api/handlers/timetable.ts',
    ).readAsStringSync();

    expect(adminTimetable, contains('_buildDraftFromSettings'));
    expect(adminTimetable, contains('_buildDayWiseEditor'));
    expect(adminTimetable, contains('_deleteDayCell'));
    expect(adminTimetable, isNot(contains('_deletePeriodColumn')));
    expect(adminTimetable, contains('_reflowSelectedDay'));
    expect(adminTimetable, contains('staffId: cell.staffId'));
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
    expect(teacherTimetable, contains('RoleAccessService.teacherSectionIds'));
    expect(
      teacherTimetable,
      contains('getTimetableSlots(sectionId: sectionId)'),
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
