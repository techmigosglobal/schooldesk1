import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'backend_api_sources.dart';

import 'backend_route_sources.dart';

void main() {
  test('teacher staff QR attendance V1 is backend-backed and isolated', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final routes = File('lib/routes/app_routes.dart').readAsStringSync();
    final guard = File('lib/routes/route_access_guard.dart').readAsStringSync();
    final registry = File(
      'lib/routes/schooldesk_screen_registry.dart',
    ).readAsStringSync();
    final nav = File(
      'lib/core/widgets/teacher_navigation.dart',
    ).readAsStringSync();
    final dashboard = File(
      'lib/features/dashboard/presentation/screens/teacher_dashboard_screen/teacher_dashboard_screen.dart',
    ).readAsStringSync();
    final myAttendance = File(
      'lib/features/attendance/presentation/screens/teacher_my_attendance_screen/teacher_my_attendance_screen.dart',
    ).readAsStringSync();
    final adminAttendance = File(
      'lib/features/attendance/presentation/screens/admin_attendance_screen/admin_attendance_screen.dart',
    ).readAsStringSync();
    final qrPanel = File(
      'lib/core/widgets/staff_qr_attendance_panel.dart',
    ).readAsStringSync();
    final api = readBackendApiSources();
    final main = readBackendRouteSources();
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
    expect(nav, contains('My Staff Attendance'));
    expect(dashboard, contains('AppRoutes.teacherMyAttendance'));
    expect(dashboard, contains('Scan QR'));
    expect(dashboard, contains('Attendance'));

    expect(myAttendance, contains('MobileScanner('));
    expect(myAttendance, contains('MobileScannerController'));
    expect(myAttendance, contains('scanStaffQr(token)'));
    expect(myAttendance, contains('getMyStaffAttendanceToday()'));
    expect(myAttendance, contains('Semantics('));

    expect(adminAttendance, isNot(contains('StaffQrAttendancePanel')));
    expect(qrPanel, contains('StaffQrAttendancePanel'));
    expect(qrPanel, contains('QrImageView'));
    expect(qrPanel, contains('secondsRemaining'));
    expect(qrPanel, contains('Recent scans'));
    expect(qrPanel, contains('Semantics('));
    expect(qrPanel, isNot(contains('Future.wait<Object>([')));
    expect(qrPanel, contains('_loadRecentScans'));
    expect(qrPanel, contains('_exportDailyQrLog'));
    expect(qrPanel, contains('SharePlus.instance.share'));

    expect(api, contains('Future<StaffQrTokenModel> getStaffQrToken()'));
    expect(api, contains('Future<StaffAttendanceModel> scanStaffQr'));
    expect(api, contains('exportStaffQrLogsCsv'));
    expect(api, contains('getMyStaffAttendanceToday'));
    expect(api, contains('getStaffAttendanceForDate'));
    expect(api, contains('refresh_after_seconds'));
    expect(api, contains('StaffAttendanceModel'));

    expect(main, contains('attendance.GET("/staff/qr-token"'));
    expect(main, contains('attendance.GET("/staff/qr-logs/export"'));
    expect(main, contains('attendance.POST("/staff/qr-scan"'));
    expect(main, contains('attendance.GET("/staff/me/today"'));
    expect(main, contains('attendance.GET("/staff"'));
    expect(handler, contains('verifyStaffQRToken'));
    expect(handler, contains('currentStaffID(c)'));
    expect(handler, contains('payload.SchoolID != schoolID'));
    expect(handler, contains('staffQRRefreshSeconds = 5'));
    expect(handler, contains('ExportStaffQRDailyLogs'));
  });

  test('staff QR display uses separate kiosk login and teacher scan identity', () {
    final routes = File('lib/routes/app_routes.dart').readAsStringSync();
    final guard = File('lib/routes/route_access_guard.dart').readAsStringSync();
    final landing = File(
      'lib/features/shell/presentation/screens/landing_page_screen/landing_page_screen.dart',
    ).readAsStringSync();
    final authLogin = File(
      'lib/features/auth/presentation/screens/auth_login_screen/auth_login_screen.dart',
    ).readAsStringSync();
    final attendanceExport = File(
      'lib/features/attendance/attendance.dart',
    ).readAsStringSync();
    final main = readBackendRouteSources();
    final handler = File(
      'school-backend/internal/handlers/attendance.go',
    ).readAsStringSync();

    expect(routes, contains('kioskLogin'));
    expect(routes, contains('kioskQrAttendance'));
    expect(routes, contains('KioskQrAttendanceScreen'));
    expect(authLogin, contains('case \'kiosk\':'));
    expect(routes, contains('kioskQrAttendance: (context)'));
    expect(guard, contains('\'kiosk\''));
    expect(guard, contains('AppRoutes.kioskQrAttendance: {\'kiosk\'}'));
    final topBar = landing
        .split('class _TopBar')
        .last
        .split('class _SlideView')
        .first;
    expect(topBar, isNot(contains('QR Display')));
    expect(topBar, isNot(contains('AppRoutes.onboarding')));
    expect(topBar, isNot(contains('AppRoutes.kioskLogin')));
    expect(topBar, isNot(contains('_showPublicEvents')));
    expect(attendanceExport, contains('kiosk_qr_attendance_screen'));

    expect(
      main,
      contains(
        'attendance.GET("/staff/qr-token", middleware.RBACMiddleware("Principal", "Kiosk")',
      ),
    );
    expect(
      main,
      contains(
        'attendance.GET("/staff", middleware.RBACMiddleware("Principal", "Kiosk")',
      ),
    );
    expect(
      main,
      contains(
        'attendance.POST("/staff/qr-scan", middleware.RBACMiddleware("Teacher", "Kiosk")',
      ),
    );
    expect(handler, contains('case "kiosk":'));
    expect(handler, contains('staffID = strings.TrimSpace(req.StaffID)'));
    expect(handler, contains('staffID = currentStaffID(c)'));
    expect(handler, contains('attendanceStringPtr(currentUserID(c))'));
  });
}
