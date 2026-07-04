import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'backend_api_sources.dart';

void main() {
  test(
    'principal timetable is manual-only while teacher and parent remain read-only',
    () {
      final teacher = File(
        'lib/features/academics/presentation/screens/teacher_timetable_screen/teacher_timetable_screen.dart',
      ).readAsStringSync();
      final principal = File(
        'lib/features/academics/presentation/screens/admin_timetable_screen/admin_timetable_screen.dart',
      ).readAsStringSync();
      final api = readBackendApiSources();
      final supabaseTimetable = File(
        'supabase/functions/api/handlers/timetable.ts',
      ).readAsStringSync();

      expect(
        teacher,
        contains('Read-only schedule from Principal timetable setup'),
      );
      expect(teacher, isNot(contains('Edit Timetable')));
      expect(teacher, isNot(contains('Delete Timetable')));
      expect(teacher, isNot(contains('updateTimetableSlot')));
      expect(teacher, isNot(contains('deleteTimetableSlot')));

      expect(principal, contains('Timetable Management'));
      expect(principal, contains('Select class to continue'));
      expect(principal, contains('Create Timetable'));
      expect(principal, contains('Create Editable Timetable'));
      expect(principal, contains('Timetable Preview'));
      expect(principal, contains('Save Timetable'));
      expect(principal, contains('_buildManualEditor'));
      expect(principal, contains('_buildDayWiseEditor'));
      expect(principal, contains('_buildPeriodManagement'));
      expect(principal, contains('_saveManualTimetable'));
      expect(principal, contains('deleteTimetableSlot('));
      expect(principal, contains('createTimetableSlot('));
      expect(principal, contains('Delete Extra Period Rows'));
      expect(principal, contains('Reflow Day'));

      expect(principal, isNot(contains('Manual Edit Today')));
      expect(principal, isNot(contains('Generate Time Table')));
      expect(principal, isNot(contains('generateSmartTimetable(')));
      expect(principal, isNot(contains('applyPrePrimaryClassSchedule(')));
      expect(principal, isNot(contains('Import CSV')));
      expect(principal, isNot(contains('Export PDF')));
      expect(principal, isNot(contains('Teacher Timetable')));
      expect(principal, isNot(contains('Room Timetable')));

      expect(api, contains('Future<Map<String, dynamic>> updateTimetableSlot'));
      expect(api, contains('Future<void> deleteTimetableSlot'));
      expect(
        supabaseTimetable,
        contains('method === "PATCH" || method === "PUT"'),
      );
      expect(supabaseTimetable, contains('method === "DELETE"'));
    },
  );

  test('principal manual editor loads class subjects from mappings', () {
    final principal = File(
      'lib/features/academics/presentation/screens/admin_timetable_screen/admin_timetable_screen.dart',
    ).readAsStringSync();

    expect(principal, contains("api.getRawList('/subjects'"));
    expect(principal, contains("'/grade-subjects'"));
    expect(principal, contains("'/staff-subjects'"));
    expect(principal, contains('_subjectOptionsForSelectedClass'));
    expect(principal, contains('_teacherIdForSubject'));
    expect(principal, contains('Free Period'));
    expect(principal, isNot(contains('for (final slot in _slots)')));
  });

  test(
    'principal save replaces class timetable with regular free and break cells',
    () {
      final principal = File(
        'lib/features/academics/presentation/screens/admin_timetable_screen/admin_timetable_screen.dart',
      ).readAsStringSync();

      expect(principal, contains('_buildDraftFromSettings'));
      expect(principal, contains('_breakCellsForDay'));
      expect(principal, contains('_deleteDayCell'));
      expect(principal, contains('_deletePeriodColumn'));
      expect(principal, contains('_reflowSelectedDay'));
      expect(
        principal,
        contains("cell.slotType = cell.subjectId.isEmpty ? 'free' : 'regular'"),
      );
      expect(principal, contains("slotType: 'free'"));
      expect(principal, contains("slotType: 'break'"));
      expect(principal, contains('existingSlots'));
      expect(principal, contains("deleteTimetableSlot(_text(slot['id']))"));
      expect(principal, contains('staffId: cell.staffId'));
    },
  );
}
