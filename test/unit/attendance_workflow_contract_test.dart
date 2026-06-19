import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'backend_api_sources.dart';
import 'backend_route_sources.dart';

void main() {
  test(
    'teacher student attendance saves drafts, submits final, and requests correction',
    () {
      final teacherAttendance = File(
        'lib/features/attendance/presentation/screens/teacher_attendance_screen/teacher_attendance_screen.dart',
      ).readAsStringSync();
      final api = readBackendApiSources();
      final routes = readBackendRouteSources();

      expect(teacherAttendance, contains("title: 'Student Attendance'"));
      expect(
        teacherAttendance,
        contains('Future<AttendanceSessionModel> _ensureSessionForSave'),
      );
      expect(teacherAttendance, contains('Save Draft'));
      expect(teacherAttendance, contains('Submit Final'));
      expect(teacherAttendance, contains('Request Correction'));
      expect(teacherAttendance, contains("'reason': student.reason"));
      expect(teacherAttendance, isNot(contains("'remarks':")));
      expect(teacherAttendance, contains("'status': 'leave'"));
      expect(teacherAttendance, contains("'status': 'half_day'"));
      expect(api, contains('bool finalize = true'));
      expect(api, contains("'finalize': finalize"));
      expect(api, contains('requestAttendanceCorrection'));
      expect(
        routes,
        contains('attendance.POST("/sessions/:session_id/correction-request"'),
      );
    },
  );

  test(
    'principal attendance screen is a student monitor with reopen and staff check-in separation',
    () {
      final principalAttendance = File(
        'lib/features/attendance/presentation/screens/principal_attendance_screen/principal_attendance_screen.dart',
      ).readAsStringSync();

      expect(
        principalAttendance,
        contains("title: 'Student Attendance Monitor'"),
      );
      expect(principalAttendance, contains('Staff Check-in Monitor'));
      expect(principalAttendance, contains('Reopen Attendance'));
      expect(principalAttendance, contains('Send Reminder'));
      expect(principalAttendance, contains('Export Class Register'));
      expect(principalAttendance, contains('Audit Trail'));
      expect(principalAttendance, contains('reopenAttendanceSession'));
      expect(principalAttendance, contains('Not Started'));
      expect(principalAttendance, contains('Needs Review'));
    },
  );

  test('parent attendance is child scoped and uses actual day-wise records', () {
    final parentAttendance = File(
      'lib/features/attendance/presentation/screens/parent_attendance_screen/parent_attendance_screen.dart',
    ).readAsStringSync();
    final backend = File(
      'school-backend/internal/handlers/attendance.go',
    ).readAsStringSync();

    expect(parentAttendance, contains("title: 'My Child Attendance'"));
    expect(parentAttendance, contains('getMyStudents()'));
    expect(parentAttendance, contains('getStudentAttendanceRecords'));
    expect(parentAttendance, contains('Period-wise attendance'));
    expect(parentAttendance, contains('Marked by teacher'));
    expect(parentAttendance, contains('Reason'));
    expect(parentAttendance, contains("'Leave'"));
    expect(parentAttendance, contains("'Half Day'"));
    expect(parentAttendance, contains('_showDayAttendanceDetail'));
    expect(backend, contains('"daily_statuses"'));
    expect(backend, contains('"period_rows"'));
    expect(backend, contains('StudentLeaveApplication'));
  });
}
