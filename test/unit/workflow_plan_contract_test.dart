import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('teacher class student card no longer exposes notes or performance', () {
    final source = File(
      'lib/features/academics/presentation/screens/teacher_classes_screen/teacher_classes_screen.dart',
    ).readAsStringSync();

    expect(source, isNot(contains("label: 'Notes'")));
    expect(source, isNot(contains("label: 'Performance'")));
    expect(source, isNot(contains('teacherStudentNotes')));
    expect(source, isNot(contains('teacherPerformance')));
  });

  test('submitted attendance is locked until principal reopen', () {
    final backend = File(
      'school-backend/internal/handlers/attendance.go',
    ).readAsStringSync();
    final teacherScreen = File(
      'lib/features/attendance/presentation/screens/teacher_attendance_screen/teacher_attendance_screen.dart',
    ).readAsStringSync();

    expect(backend, contains('session.IsFinalized = true'));
    expect(backend, contains('ReopenAttendanceSession'));
    expect(teacherScreen, contains('Attendance locked'));
    expect(teacherScreen, contains('locked ? null'));
  });

  test('leave, homework, and reports use real readable workflow hooks', () {
    final leave = File(
      'lib/features/leave/presentation/screens/teacher_leave_screen/teacher_leave_screen.dart',
    ).readAsStringSync();
    final homework = File(
      'lib/features/homework/presentation/screens/teacher_homework_screen/teacher_homework_screen.dart',
    ).readAsStringSync();
    final reports = File(
      'school-backend/internal/handlers/report_export.go',
    ).readAsStringSync();

    expect(leave, contains('_leaveTypeLabel(app.leaveTypeId)'));
    expect(homework, contains("row['homework_id'] ?? row['id']"));
    expect(reports, contains('attendanceReportRows'));
    expect(reports, contains('homeworkReportRows'));
  });
}
