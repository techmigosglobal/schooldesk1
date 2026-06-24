import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'backend_api_sources.dart';
import 'backend_route_sources.dart';

void main() {
  test(
    'teacher timetable remains view-only while principal manages via overflow',
    () {
      final teacher = File(
        'lib/features/academics/presentation/screens/teacher_timetable_screen/teacher_timetable_screen.dart',
      ).readAsStringSync();
      final principal = File(
        'lib/features/academics/presentation/screens/admin_timetable_screen/admin_timetable_screen.dart',
      ).readAsStringSync();
      final api = readBackendApiSources();
      final routes = readBackendRouteSources();

      expect(
        teacher,
        contains('Read-only schedule from Principal timetable setup'),
      );
      expect(teacher, isNot(contains('Edit Timetable')));
      expect(teacher, isNot(contains('Delete Timetable')));
      expect(teacher, isNot(contains('updateTimetableSlot')));
      expect(teacher, isNot(contains('deleteTimetableSlot')));

      expect(principal, contains("value: 'edit_timetable'"));
      expect(principal, contains("value: 'delete_timetable'"));
      expect(principal, contains('Edit Timetable'));
      expect(principal, contains('Delete Timetable'));
      expect(principal, contains('_editingTimetable'));
      expect(principal, contains('_editableSchedulePanel'));
      expect(principal, contains('_saveEditedTimetable'));
      expect(principal, contains('_deleteSelectedClassTimetable'));
      expect(principal, contains('updateTimetableSlot('));
      expect(principal, contains('deleteTimetableSlot('));

      expect(api, contains('Future<Map<String, dynamic>> updateTimetableSlot'));
      expect(api, contains('Future<void> deleteTimetableSlot'));
      expect(routes, contains('timetable.PUT("/slots/:id"'));
      expect(routes, contains('timetable.DELETE("/slots/:id"'));
    },
  );
}
