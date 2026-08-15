import 'package:flutter_test/flutter_test.dart';
import 'package:schooldesk1/features/academics/presentation/screens/teacher_timetable_screen/teacher_timetable_day_selection.dart';

void main() {
  test('selects today when today is a configured working day', () {
    expect(
      selectInitialTeacherTimetableDay(
        workingDays: const [1, 2, 3, 4, 5],
        now: DateTime(2026, 8, 10), // Monday
      ),
      DateTime.monday,
    );
  });

  test('selects the first configured day when today is not working', () {
    expect(
      selectInitialTeacherTimetableDay(
        workingDays: const [2, 4, 6],
        now: DateTime(2026, 8, 10), // Monday
      ),
      DateTime.tuesday,
    );
  });

  test('falls back to Monday through Saturday when working days are empty', () {
    expect(normalizeTeacherWorkingDays(const []), defaultTeacherWorkingDays);
    expect(
      selectInitialTeacherTimetableDay(
        workingDays: const [],
        now: DateTime(2026, 8, 9), // Sunday
      ),
      DateTime.monday,
    );
  });

  test('normalizes invalid, duplicate, and unsorted working days', () {
    expect(normalizeTeacherWorkingDays(const [8, 5, 2, 5, 0]), const [2, 5]);
  });
}
