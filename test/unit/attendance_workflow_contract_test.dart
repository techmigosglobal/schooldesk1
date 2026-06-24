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
      expect(teacherAttendance, contains("'Daily attendance'"));
      expect(teacherAttendance, contains("'Whole day'"));
      expect(teacherAttendance, isNot(contains('ChoiceChip')));
      expect(teacherAttendance, contains("'reason': ''"));
      expect(teacherAttendance, isNot(contains("'remarks':")));
      expect(teacherAttendance, isNot(contains("this.status = 'present'")));
      expect(teacherAttendance, contains("this.status = 'unmarked'"));
      expect(teacherAttendance, contains('_hydrateSavedAttendanceRows'));
      expect(teacherAttendance, contains('_unmarkedStudents'));
      expect(
        teacherAttendance,
        contains('Mark every student before final submit'),
      );
      expect(teacherAttendance, contains('s.activeEnrollmentId'));
      expect(teacherAttendance, contains('_resolveEnrollmentId'));
      expect(teacherAttendance, contains('_attendanceEnrollmentId'));
      expect(
        teacherAttendance,
        isNot(
          contains(
            'if (s.activeEnrollmentId.trim().isNotEmpty) return s.activeEnrollmentId;',
          ),
        ),
      );
      expect(teacherAttendance, contains("'status': 'present'"));
      expect(teacherAttendance, contains("'status': 'absent'"));
      expect(teacherAttendance, isNot(contains("'status': 'late'")));
      expect(teacherAttendance, isNot(contains("'status': 'leave'")));
      expect(teacherAttendance, isNot(contains("'status': 'half_day'")));
      expect(teacherAttendance, isNot(contains('Add reason')));
      expect(teacherAttendance, isNot(contains('Edit reason')));
      expect(api, contains('bool finalize = true'));
      expect(api, contains("'finalize': finalize"));
      expect(api, contains('requestAttendanceCorrection'));
      expect(
        routes,
        contains('attendance.POST("/sessions/:session_id/correction-request"'),
      );
    },
  );

  test('teacher attendance history presents class-day register, not periods', () {
    final teacherHistory = File(
      'lib/features/attendance/presentation/screens/teacher_attendance_history_screen/teacher_attendance_history_screen.dart',
    ).readAsStringSync();

    expect(teacherHistory, contains("title: 'Daily attendance'"));
    expect(teacherHistory, contains('Class day register'));
    expect(teacherHistory, contains('Absent \$absent'));
    expect(
      teacherHistory,
      isNot(contains("'Period \${session.periodNumber}'")),
    );
    expect(teacherHistory, isNot(contains('Absent/Late')));
  });

  test('principal attendance screen separates staff and class-wise students', () {
    final principalAttendance = File(
      'lib/features/attendance/presentation/screens/principal_attendance_screen/principal_attendance_screen.dart',
    ).readAsStringSync();

    expect(
      principalAttendance,
      contains("enum _AttendanceView { staff, students"),
    );
    expect(principalAttendance, contains('Staff Attendance'));
    expect(principalAttendance, contains('Student Attendance'));
    expect(principalAttendance, contains('Staff Attendance Record'));
    expect(principalAttendance, contains('Select Class'));
    expect(
      principalAttendance,
      contains('Choose a class to see student attendance.'),
    );
    expect(principalAttendance, contains('Marked today:'));
    expect(principalAttendance, contains('Search by name or admission no.'));
    expect(principalAttendance, contains('_StaffAttendanceRow'));
    expect(principalAttendance, contains('getStaffAttendanceForDate'));
    expect(principalAttendance, contains('getStudents('));
    expect(principalAttendance, contains('_StudentDetailPage'));
    expect(principalAttendance, contains('PopScope'));
    expect(principalAttendance, contains('_recordsByStudent'));
    expect(principalAttendance, contains('_latestStudentRecord'));
    expect(principalAttendance, contains('_StudentAttendanceMeta'));
    expect(principalAttendance, contains('_AttendanceHistoryLine'));
    expect(principalAttendance, contains("record['marked_at']"));
    expect(principalAttendance, contains('_readableAttendanceTeacherLabel'));
    expect(principalAttendance, contains('_looksLikeIdentifier'));
    expect(principalAttendance, contains('staff.id == candidateId'));
    expect(principalAttendance, contains('Reopen Attendance'));
    expect(principalAttendance, contains('Send Reminder'));
    expect(principalAttendance, contains('Incomplete'));
    expect(principalAttendance, contains('_sessionStaffLabel'));
    expect(principalAttendance, isNot(contains("'Subject ID'")));
    expect(principalAttendance, isNot(contains("'Staff ID'")));
    expect(principalAttendance, isNot(contains('Open class in Classes Hub')));
    expect(principalAttendance, contains('reopenAttendanceSession'));
    expect(principalAttendance, contains('Not Started'));
    expect(principalAttendance, contains('Needs Review'));
  });

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

  test(
    'student list includes active enrollment id for attendance performance',
    () {
      final studentModel = File(
        'lib/features/shared/data/models/backend_models.dart',
      ).readAsStringSync();
      final backend = File(
        'school-backend/internal/handlers/student.go',
      ).readAsStringSync();

      expect(studentModel, contains('activeEnrollmentId'));
      expect(studentModel, contains("json['active_enrollment_id']"));
      expect(backend, contains('"active_enrollment_id"'));
      expect(backend, contains('activeEnrollmentIDsForStudents'));
    },
  );
}
