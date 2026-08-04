import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CSV timetable import remains separate from the leadership editor', () {
    final importer = File(
      'lib/core/services/bulk_csv_import_service.dart',
    ).readAsStringSync();
    final adminTimetable = File(
      'lib/features/academics/presentation/screens/admin_timetable_screen/admin_timetable_screen.dart',
    ).readAsStringSync();

    expect(importer, contains('BulkCsvImportTarget.classTimetables'));
    expect(importer, contains('generateSmartTimetable('));
    expect(adminTimetable, isNot(contains('BulkCsvImportService.importCsv')));
    expect(adminTimetable, isNot(contains('Import CSV')));
    expect(adminTimetable, isNot(contains('Generate Time Table')));
    expect(adminTimetable, isNot(contains('generateSmartTimetable(')));
  });

  test('teacher timetable reads only assigned class and co-teacher sections', () {
    final teacher = File(
      'lib/features/academics/presentation/screens/teacher_timetable_screen/teacher_timetable_screen.dart',
    ).readAsStringSync();
    final handler = File(
      'supabase/functions/api/handlers/timetable.ts',
    ).readAsStringSync();
    expect(teacher, contains('RoleAccessService.teacherSectionIds'));
    expect(teacher, contains('getTimetableSlots(sectionId: sectionId)'));
    expect(teacher, contains('_selectedSectionId'));
    expect(
      teacher,
      isNot(contains('staffId: RoleAccessService.teacherStaffId')),
    );
    expect(handler, contains('class_teacher_id.eq.'));
    expect(handler, contains('co_teacher_id.eq.'));
    expect(handler, contains('return { staffId: "", sectionIds }'));
    expect(handler, isNot(contains('const { data: assignments')));
  });

  test('free periods and multi-day replacement use the shared slot source', () {
    final admin = File(
      'lib/features/academics/presentation/screens/admin_timetable_screen/admin_timetable_screen.dart',
    ).readAsStringSync();
    final api = File(
      'lib/core/network/api_modules/timetable_api.dart',
    ).readAsStringSync();
    final handler = File(
      'supabase/functions/api/handlers/timetable.ts',
    ).readAsStringSync();
    final migration = File(
      'supabase/migrations/20260804100000_add_timetable_day_replace.sql',
    ).readAsStringSync();

    expect(
      admin,
      contains("'subject_id': row.subjectId.isEmpty ? null : row.subjectId"),
    );
    expect(admin, contains('selectedDays'));
    expect(api, contains("'/timetable/slots/replace-days'"));
    expect(api, contains("'days': days"));
    expect(migration, contains('    day_number,'));
    expect(migration, contains('row_data.ordinality::integer'));
    expect(
      migration,
      contains(
        "when nullif(row_data.value ->> 'subject_id', '') is null then 'free'",
      ),
    );
  });
}
