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

    expect(migration, contains('add column if not exists enrollment_id'));
    expect(migration, contains('add column if not exists reason text'));
    expect(migration, contains('add column if not exists status text'));
    expect(migration, contains('add column if not exists submitted_at'));
    expect(migration, contains('idx_student_attendances_enrollment'));
  });

  test('diary route scopes teacher rows and supports delete', () {
    final source = File(
      'supabase/functions/api/handlers/communications.ts',
    ).readAsStringSync();
    final diary = File(
      'lib/features/academics/presentation/screens/teacher_diary_screen/teacher_diary_screen.dart',
    ).readAsStringSync();

    expect(
      source,
      contains('const staffId = url.searchParams.get("staff_id")'),
    );
    expect(source, contains('staffId !== linkedStaffId(user)'));
    expect(source, contains('staff_id: canManageSchoolContent(user)'));
    expect(source, contains('if (diaryMatch && method === "DELETE")'));
    expect(diary, contains("'staff_id': RoleAccessService.teacherStaffId"));
    expect(diary, contains("'section_id': RoleAccessService.teacherClassId"));
  });

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
