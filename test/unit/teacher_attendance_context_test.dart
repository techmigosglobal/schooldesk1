import 'package:flutter_test/flutter_test.dart';
import 'package:schooldesk1/roles/teacher/domain/teacher_attendance_context.dart';

void main() {
  TeacherAttendanceContext context(Map<String, dynamic> overrides) =>
      TeacherAttendanceContext.fromJson({
        'section_id': 'section',
        'academic_year_id': 'year',
        'school_date': '2026-10-18',
        'academic_year_start': '2026-06-01',
        'academic_year_end': '2027-04-30',
        'min_date': '2026-06-01',
        'max_date': '2026-10-18',
        'configuration_status': 'ready',
        ...overrides,
      });
  test(
    'school calendar permits inclusive boundaries and refuses future dates',
    () {
      final calendar = context({});
      expect(calendar.contains(DateTime(2026, 6, 1)), isTrue);
      expect(calendar.contains(DateTime(2026, 10, 18)), isTrue);
      expect(calendar.contains(DateTime(2026, 10, 19)), isFalse);
      expect(calendar.contains(DateTime(2026, 5, 31)), isFalse);
    },
  );
  test('ended year initializes to final historical date', () {
    final calendar = context({
      'school_date': '2027-05-01',
      'max_date': '2027-04-30',
      'configuration_status': 'ended',
    });
    expect(calendar.initialDate, DateTime(2027, 4, 30));
  });
  test(
    'inverted, missing and unstarted calendars never expose picker bounds',
    () {
      for (final overrides in [
        {'max_date': '2026-05-31'},
        {'min_date': null},
        {'max_date': null},
        {'configuration_status': 'not_started'},
        {'configuration_status': 'invalid_year'},
        {'configuration_status': 'missing_year'},
        {'academic_year_id': null},
      ]) {
        expect(context(overrides).hasSelectableDates, isFalse);
      }
    },
  );
  test(
    'invalid ISO school date fails without DateTime overflow normalization',
    () {
      expect(
        () => context({'school_date': '2026-02-31'}),
        throwsFormatException,
      );
    },
  );
}
