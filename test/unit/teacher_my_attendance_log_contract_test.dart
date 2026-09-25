import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('teacher my attendance keeps QR actions and shows a 30 day log', () {
    final screen = File(
      'lib/features/attendance/presentation/screens/teacher_my_attendance_screen/teacher_my_attendance_screen.dart',
    ).readAsStringSync();
    final api = File(
      'lib/core/network/api_modules/attendance_api.dart',
    ).readAsStringSync();
    final repository = File(
      'lib/roles/teacher/data/api_teacher_attendance_repository.dart',
    ).readAsStringSync();

    expect(screen, contains("label: 'Scan QR'"));
    expect(screen, contains("label: 'Refresh Status'"));
    expect(screen, contains('_AttendanceLogCard(records: _attendanceLog)'));
    expect(screen, contains("title: 'Attendance Log'"));
    expect(screen, contains("subtitle: 'Last 30 days'"));
    expect(screen, contains("DateFormat('dd MMM yyyy')"));
    expect(screen, contains("DateFormat('HH:mm')"));
    expect(screen, isNot(contains("label: 'Status'")));
    expect(screen, isNot(contains("label: 'Source'")));

    expect(repository, contains('getMyStaffAttendanceLog'));
    expect(api, contains('Duration(days: days - 1)'));
    expect(api, contains('filtered.take(days).toList()'));
  });
}
