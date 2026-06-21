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
      'school-backend/internal/handlers/timetable.go',
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
    expect(adminTimetable, contains('Generate from class CSV'));
    expect(adminTimetable, contains('Generate Time Table'));
    expect(adminTimetable, contains('DropdownButtonFormField<String>'));
    expect(adminTimetable, contains("labelText: 'Class'"));
    expect(adminTimetable, contains("value: 'smart'"));
    expect(adminTimetable, contains('generateSmartTimetable('));
    expect(adminTimetable, contains('applyPrePrimaryClassSchedule('));
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
    expect(timetableHandler, contains('room is already booked during period'));
    expect(timetableHandler, contains('chooseTimetableRoom'));
    expect(timetableApi, contains("'breaks': breaks"));

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

  test('class subject changes prompt smart timetable regeneration', () {
    final principalClasses = File(
      'lib/features/academics/presentation/screens/principal_classes_screen/principal_classes_screen.dart',
    ).readAsStringSync();
    final teacherTimetable = File(
      'lib/features/academics/presentation/screens/teacher_timetable_screen/teacher_timetable_screen.dart',
    ).readAsStringSync();

    expect(principalClasses, contains('_promptRegenerateTimetable'));
    expect(principalClasses, contains('Regenerate timetable?'));
    expect(principalClasses, contains('generateSmartTimetable('));
    expect(principalClasses, contains('getTerms(_academicYearId)'));
    expect(
      principalClasses,
      contains('teacher subjects and teacher timetable stay in sync'),
    );
    expect(
      teacherTimetable,
      contains('staffId: RoleAccessService.teacherStaffId'),
    );
    expect(teacherTimetable, contains('_weeklySubjects'));
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
