import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String read(String path) => File(path).readAsStringSync();

  test(
    'parent attendance client falls back to legacy student attendance route',
    () {
      final api = read('lib/core/network/api_modules/attendance_api.dart');

      expect(api, contains("'/students/\$studentId/attendance'"));
      expect(api, contains("'/attendance/students/\$studentId'"));
      expect(api, contains('on NotFoundException'));
    },
  );

  test('parent attendance screen tolerates partial backend failures', () {
    final screen = read(
      'lib/features/attendance/presentation/screens/parent_attendance_screen/parent_attendance_screen.dart',
    );
    final repository = read(
      'lib/roles/parent/data/api_parent_attendance_repository.dart',
    );

    expect(repository, contains('getStudentAttendanceSummary'));
    expect(repository, contains('getStudentAttendanceRecords'));
    expect(repository, contains('getStudentLeaveApplications'));
    expect(screen, contains('widget.repository'));
    expect(screen, contains('Some attendance data is unavailable'));
    expect(screen, contains("child: const Text('Retry')"));
  });

  test('parent attendance and leave screens accept start and end date aliases', () {
    final attendanceScreen = read(
      'lib/features/attendance/presentation/screens/parent_attendance_screen/parent_attendance_screen.dart',
    );
    final leaveScreen = read(
      'lib/features/leave/presentation/screens/parent_leave_screen/parent_leave_screen.dart',
    );
    final leaveRepository = read(
      'lib/roles/parent/data/api_parent_leave_repository.dart',
    );

    expect(
      attendanceScreen,
      contains("request['from_date'] ?? request['start_date']"),
    );
    expect(
      attendanceScreen,
      contains("request['to_date'] ?? request['end_date']"),
    );
    expect(
      leaveScreen,
      contains("request['from_date'] ?? request['start_date']"),
    );
    expect(leaveScreen, contains("request['to_date'] ?? request['end_date']"));
    expect(leaveRepository, contains('getStudentLeaveApplications('));
    expect(leaveRepository, contains('studentId: studentId'));
  });

  test(
    'parent leave uses configured API types without fictional fallback data',
    () {
      final screen = read(
        'lib/features/leave/presentation/screens/parent_leave_screen/parent_leave_screen.dart',
      );
      final form = read(
        'lib/features/leave/presentation/screens/parent_leave_screen/parent_leave_request_form_screen.dart',
      );

      expect(screen, contains('widget.repository'));
      expect(screen, contains('_leaveTypes'));
      expect(form, contains('ApiParentLeaveRepository'));
      expect(form, isNot(contains('_defaultParentLeaveTypes')));
    },
  );
}
