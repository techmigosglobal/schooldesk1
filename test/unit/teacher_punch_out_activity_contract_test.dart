import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'staff QR attendance uses server-owned India-time check-out decisions',
    () {
      final source = File(
        'supabase/functions/api/handlers/attendance.ts',
      ).readAsStringSync();
      expect(source, contains('timeZone: "Asia/Kolkata"'));
      expect(source, contains('staffQRRefreshSeconds = 7'));
      expect(
        source,
        contains('const afterNoon = indiaDateParts(now).hour >= 12'),
      );
      expect(source, contains('check_out_source: "qr"'));
      expect(source, contains('check_in: timeValue'));
      expect(source, isNot(contains('check_in: body.check_in')));
    },
  );

  test(
    'manual teacher punch-out and principal staff summary are available',
    () {
      final source = File(
        'supabase/functions/api/handlers/attendance.ts',
      ).readAsStringSync();
      expect(source, contains('/attendance/staff/me/punch-out'));
      expect(source, contains('check-in is required before punch-out'));
      expect(source, contains('/attendance/staff/daily-summary'));
      expect(source, contains('currently_on_site'));
    },
  );

  test('teacher UI exposes completed attendance and manual punch-out', () {
    final source = File(
      'lib/features/attendance/presentation/screens/teacher_my_attendance_screen/teacher_my_attendance_screen.dart',
    ).readAsStringSync();
    final repository = File(
      'lib/roles/teacher/data/api_teacher_attendance_repository.dart',
    ).readAsStringSync();
    expect(source, contains('Punch Out'));
    expect(repository, contains('punchOutMyStaffAttendance'));
    expect(source, contains(r'Out ${_timeLabel(checkOut)}'));
  });

  test('staff punch-out and session tracking remain active', () {
    final migration = File(
      'supabase/migrations/20260719102101_staff_punch_out_and_activity_log.sql',
    ).readAsStringSync();
    final auth = File(
      'supabase/functions/api/handlers/auth.ts',
    ).readAsStringSync();
    expect(migration, contains('check_out_source'));
    expect(migration, contains('signed_out_at'));
    expect(auth, contains('from("user_sessions").insert'));
    expect(auth, contains('signed_out_at: now'));
    expect(auth, isNot(contains('refresh_token: refresh_token')));
  });
}
