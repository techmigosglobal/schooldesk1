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

  test('leave handler matches Flutter balances recall and decision routes', () {
    final source = File(
      'supabase/functions/api/handlers/leave.ts',
    ).readAsStringSync();

    expect(source, contains('/leave/balances'));
    expect(source, contains(r'^\/leave\/applications\/([^/]+)\/recall$'));
    expect(source, contains(r'/recall$/'));
    expect(source, contains(r'(approve|reject)'));
    expect(
      source,
      contains(r'^\/student-leave\/applications\/([^/]+)\/decision$'),
    );
  });

  test('students handler exposes student attendance history route', () {
    final source = File(
      'supabase/functions/api/handlers/students.ts',
    ).readAsStringSync();

    expect(source, contains('sub === "attendance"'));
    expect(source, contains('student_attendances'));
  });
}
