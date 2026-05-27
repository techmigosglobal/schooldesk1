import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('teacher staff QR attendance V1 is routed and backend-backed', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final routes = File('lib/routes/app_routes.dart').readAsStringSync();
    final guard = File('lib/routes/route_access_guard.dart').readAsStringSync();
    final registry = File(
      'lib/routes/schooldesk_screen_registry.dart',
    ).readAsStringSync();
    final nav = File('lib/widgets/teacher_navigation.dart').readAsStringSync();
    final dashboard = File(
      'lib/presentation/teacher_dashboard_screen/teacher_dashboard_screen.dart',
    ).readAsStringSync();
    final myAttendance = File(
      'lib/presentation/teacher_my_attendance_screen/teacher_my_attendance_screen.dart',
    ).readAsStringSync();
    final adminAttendance = File(
      'lib/presentation/admin_attendance_screen/admin_attendance_screen.dart',
    ).readAsStringSync();
    final qrPanel = File(
      'lib/widgets/staff_qr_attendance_panel.dart',
    ).readAsStringSync();
    final api = File('lib/services/backend_api_client.dart').readAsStringSync();
    final main = File('school-backend/main.go').readAsStringSync();
    final handler = File(
      'school-backend/internal/handlers/attendance.go',
    ).readAsStringSync();

    expect(pubspec, contains('qr_flutter: ^4.1.0'));
    expect(pubspec, contains('mobile_scanner: ^7.2.0'));

    expect(routes, contains('teacherMyAttendance'));
    expect(routes, contains('TeacherMyAttendanceScreen'));
    expect(guard, contains('AppRoutes.teacherMyAttendance: {\'teacher\'}'));
    expect(registry, contains('/teacher-my-attendance-screen'));
    expect(registry, contains('My Attendance'));
    expect(registry, contains('Student Attendance'));

    expect(nav, contains('label: \'Today\''));
    expect(nav, contains('AppRoutes.teacherMyAttendance'));
    expect(nav, contains('Student Attendance'));
    expect(dashboard, contains('AppRoutes.teacherMyAttendance'));
    expect(dashboard, contains('Scan QR'));
    expect(dashboard, contains('Student Attendance'));

    expect(myAttendance, contains('MobileScanner('));
    expect(myAttendance, contains('MobileScannerController'));
    expect(myAttendance, contains('scanStaffQr(token)'));
    expect(myAttendance, contains('getMyStaffAttendanceToday()'));
    expect(myAttendance, contains('Semantics('));

    expect(adminAttendance, contains('StaffQrAttendancePanel'));
    expect(qrPanel, contains('QrImageView'));
    expect(qrPanel, contains('secondsRemaining'));
    expect(qrPanel, contains('Recent scans'));
    expect(qrPanel, contains('Semantics('));

    expect(api, contains('Future<StaffQrTokenModel> getStaffQrToken()'));
    expect(api, contains('Future<StaffAttendanceModel> scanStaffQr'));
    expect(api, contains('getMyStaffAttendanceToday'));
    expect(api, contains('getStaffAttendanceForDate'));
    expect(api, contains('refresh_after_seconds'));
    expect(api, contains('StaffAttendanceModel'));

    expect(main, contains('attendance.GET("/staff/qr-token"'));
    expect(main, contains('attendance.POST("/staff/qr-scan"'));
    expect(main, contains('attendance.GET("/staff/me/today"'));
    expect(main, contains('attendance.GET("/staff"'));
    expect(handler, contains('verifyStaffQRToken'));
    expect(handler, contains('currentStaffID(c)'));
    expect(handler, contains('payload.SchoolID != schoolID'));
    expect(handler, contains('staffQRRefreshSeconds = 60'));
  });
}
