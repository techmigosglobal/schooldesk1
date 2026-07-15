import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('attendance handler matches Flutter session and qr routes', () {
    final source = File(
      'supabase/functions/api/handlers/attendance.ts',
    ).readAsStringSync();

    expect(source, contains(r'^\/attendance\/sessions\/([^/]+)$'));
    expect(source, contains(r'/mark$/'));
    expect(source, contains(r'/correction-request$/'));
    expect(source, contains(r'/reopen$/'));
    expect(source, contains('/attendance/staff/me/today'));
    expect(source, contains('/attendance/staff/qr-token'));
    expect(source, contains('/attendance/staff/qr-scan'));
    expect(source, contains('student_attendances(*)'));
    expect(source, contains('enrollment_id: r.enrollment_id || null'));
    expect(source, contains('reason: r.reason ?? r.remarks ?? ""'));
    expect(source, contains('status: "submitted"'));
    expect(source, contains('status: "needs_review"'));
    expect(source, contains('notification_logs'));
    expect(source, contains('entity_type: "attendance"'));
    expect(source, contains('route: "/parent-attendance-screen"'));
    expect(source, contains('dedupe_key: `attendance:'));
    expect(
      source,
      isNot(
        contains(
          'is_finalized: false,\n      updated_at: new Date().toISOString(),',
        ),
      ),
    );
  });

  test(
    'Supabase staff QR workflow uses kiosk token and teacher scan identity',
    () {
      final source = File(
        'supabase/functions/api/handlers/attendance.ts',
      ).readAsStringSync();
      final seed = File('supabase/seed_principal.ts').readAsStringSync();

      expect(seed, contains('seedKioskUser'));
      expect(seed, contains('KIOSK_USERNAME'));
      expect(seed, contains('KIOSK_PASSWORD'));
      expect(seed, contains('role_name: "kiosk"'));

      expect(source, contains('const roleName = role(user)'));
      expect(source, contains('canDisplayStaffQr(roleName)'));
      expect(
        source,
        contains('if (!linkedStaffId) return fail("staff profile not linked"'),
      );
      expect(source, contains('staff_id: linkedStaffId'));
      expect(source, isNot(contains('staff_id: staffId')));
      expect(source, contains('verifyStaffQrToken'));
      expect(source, contains('staffQRRefreshSeconds = 7'));
      expect(source, contains('staffQRScanGraceSeconds = 10'));
      expect(source, contains('/attendance/staff/qr-logs/export'));
    },
  );

  test('attendance schema migration stores Flutter attendance metadata', () {
    final migration = File(
      'supabase/migrations/0012_teacher_attendance_alignment.sql',
    ).readAsStringSync();
    final markedAtMigration = File(
      'supabase/migrations/20260705142256_add_student_attendance_marked_at.sql',
    ).readAsStringSync();

    expect(migration, contains('add column if not exists enrollment_id'));
    expect(migration, contains('add column if not exists reason text'));
    expect(migration, contains('add column if not exists status text'));
    expect(migration, contains('add column if not exists submitted_at'));
    expect(migration, contains('idx_student_attendances_enrollment'));
    expect(markedAtMigration, contains('add column if not exists marked_at'));
    expect(markedAtMigration, contains("notify pgrst, 'reload schema'"));
  });

  test('diary route scopes teacher rows and supports delete', () {
    final source = File(
      'supabase/functions/api/handlers/communications.ts',
    ).readAsStringSync();

    expect(
      source,
      contains('const staffId = url.searchParams.get("staff_id")'),
    );
    expect(source, contains('staffId !== linkedStaffId(user)'));
    expect(source, contains('staff_id: canManageSchoolContent(user)'));
    expect(source, contains('if (diaryMatch && method === "DELETE")'));
  });

  test('leave handler matches Flutter balances recall and decision routes', () {
    final source = File(
      'supabase/functions/api/handlers/leave.ts',
    ).readAsStringSync();
    final migration = File(
      'supabase/migrations/0003_attendance_fees_leave_timetable.sql',
    ).readAsStringSync();
    final model = File(
      'lib/features/shared/data/models/backend_models.dart',
    ).readAsStringSync();

    expect(source, contains('/leave/balances'));
    expect(source, contains(r'^\/leave\/applications\/([^/]+)\/recall$'));
    expect(source, contains(r'/recall$/'));
    expect(source, contains(r'(approve|reject)'));
    expect(migration, contains('start_date      date not null'));
    expect(migration, isNot(contains('half_day')));
    expect(model, contains("'start_date': fromDate"));
    expect(model, contains("json['start_date']"));
    expect(model, isNot(contains("'half_day': halfDay")));
    expect(
      source,
      contains(r'^\/student-leave\/applications\/([^/]+)\/decision$'),
    );
  });

  test('students handler exposes student attendance history route', () {
    final source = File(
      'supabase/functions/api/handlers/students.ts',
    ).readAsStringSync();
    final attendanceApi = File(
      'lib/core/network/api_modules/attendance_api.dart',
    ).readAsStringSync();

    expect(source, contains('sub === "attendance"'));
    expect(source, contains('student_attendances'));
    expect(attendanceApi, contains("'/students/\$studentId/attendance'"));
    expect(attendanceApi, contains("'/attendance/students/\$studentId'"));
    expect(attendanceApi, contains('on NotFoundException'));
  });

  test('parent attendance and leave screens accept backend leave date aliases', () {
    final attendanceScreen = File(
      'lib/features/attendance/presentation/screens/parent_attendance_screen/parent_attendance_screen.dart',
    ).readAsStringSync();
    final leaveScreen = File(
      'lib/features/leave/presentation/screens/parent_leave_screen/parent_leave_screen.dart',
    ).readAsStringSync();

    expect(
      attendanceScreen,
      contains("request['from_date'] ?? request['start_date']"),
    );
    expect(
      attendanceScreen,
      contains("request['to_date'] ?? request['end_date']"),
    );
    expect(
      attendanceScreen,
      contains('Future<Map<String, dynamic>> _safeAttendanceSummary'),
    );
    expect(
      attendanceScreen,
      contains('Future<List<Map<String, dynamic>>> _safeAttendanceRecords'),
    );
    expect(
      attendanceScreen,
      contains('Future<List<Map<String, dynamic>>> _safeLeaveRequests'),
    );
    expect(
      leaveScreen,
      contains("request['from_date'] ?? request['start_date']"),
    );
    expect(leaveScreen, contains("request['to_date'] ?? request['end_date']"));
  });

  test(
    'StaffAttendanceModel._parseDateTime handles PostgreSQL time-only strings',
    () {
      final source = File(
        'lib/features/shared/data/models/backend_models.dart',
      ).readAsStringSync();

      // Verify the parser exists in StaffAttendanceModel
      expect(source, contains('class StaffAttendanceModel'));
      expect(
        source,
        contains('static DateTime? _parseDateTime(Object? value)'),
      );

      // Verify it handles time-only strings
      expect(source, contains('PostgreSQL time-only'));
      expect(source, contains('RegExp('));
      expect(source, contains('\\d{2}'));

      // Verify it combines time with today's date
      expect(source, contains('now.year'));
      expect(source, contains('now.month'));
      expect(source, contains('now.day'));

      // Verify it handles microseconds from fractional seconds
      expect(source, contains('microseconds'));
      expect(source, contains('padRight(6'));

      // Verify it still handles full ISO datetimes
      expect(source, contains('DateTime.tryParse(raw)'));
      expect(source, contains('full.toLocal()'));
    },
  );

  test('backend stores full ISO datetime in staff QR scan check_in', () {
    final source = File(
      'supabase/functions/api/handlers/attendance.ts',
    ).readAsStringSync();

    // Verify qr-scan stores full ISO datetime, not time-only string
    expect(source, contains('/attendance/staff/qr-scan'));
    expect(source, contains('now.toISOString()'));
    expect(source, isNot(contains('now.toTimeString()')));

    // Verify legacy /attendance/qr endpoint also uses ISO datetime
    expect(source, contains('/attendance/qr'));
    expect(source, contains('new Date().toISOString()'));
  });

  test('migration 0025 alters staff_attendances check_in to timestamptz', () {
    final migration = File(
      'supabase/migrations/0025_staff_attendance_checkin_timestamptz.sql',
    ).readAsStringSync();

    expect(migration, contains('staff_attendances'));
    expect(migration, contains('check_in'));
    expect(migration, contains('check_out'));
    expect(migration, contains('timestamptz'));
    expect(migration, contains('USING (date + check_in)'));
    expect(migration, contains('AT TIME ZONE'));
  });
}
