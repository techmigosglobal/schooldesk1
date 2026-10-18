import 'package:flutter_test/flutter_test.dart';
import 'package:schooldesk1/core/utils/timetable_time.dart';

void main() {
  test('school clock normalizes valid database and compact values', () {
    for (final entry in {
      '900': '09:00',
      '1000': '10:00',
      '9:05': '09:05',
      '13:00:00': '13:00',
      '00:00': '00:00',
      '23:59:59.0': '23:59',
      '100': '01:00',
    }.entries) {
      expect(normalizeTimetableTime(entry.key), entry.value);
    }
  });
  test('invalid and ambiguous clock text requires correction', () {
    for (final value in [
      '24:00',
      '12:60',
      'abc',
      '1',
      '12',
      '9 PM',
      '12:00:99',
    ]) {
      expect(normalizeTimetableTime(value), isNull);
    }
  });
}
