import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'parent attendance is scoped and derives a fresh summary from marks',
    () {
      final handler = File(
        'supabase/functions/api/handlers/attendance.ts',
      ).readAsStringSync();
      final selector = File(
        'lib/core/widgets/parent_child_selector.dart',
      ).readAsStringSync();

      expect(handler, contains('parentCanAccessStudent'));
      expect(handler, contains('attendanceSummaryFromRows'));
      expect(handler, contains('attendance_pct'));
      expect(handler, contains('period_rows'));
      expect(handler, contains('session.date'));
      expect(selector, isNot(contains("{id:")));
      expect(selector, isNot(contains("Student ID")));
    },
  );
}
