import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String migration;

  setUpAll(() {
    migration = File(
      'supabase/migrations/20260811161601_isolate_teacher_parent_leave_rows.sql',
    ).readAsStringSync();
  });

  test(
    'teacher leave policies replace school-wide access with staff ownership',
    () {
      expect(
        migration,
        contains('drop policy if exists "leave_balances_school_select"'),
      );
      expect(
        migration,
        contains('drop policy if exists "leave_applications_school_select"'),
      );
      expect(migration, contains('account.id = (select auth.uid())'));
      expect(
        migration,
        contains('account.linked_id = leave_balances.staff_id'),
      );
      expect(
        migration,
        contains('account.linked_id = leave_applications.staff_id'),
      );
      expect(
        migration,
        contains("lower(coalesce(status, 'pending')) = 'pending'"),
      );
    },
  );

  test('parent student leave policies require an authenticated child link', () {
    expect(
      migration,
      contains(
        'drop policy if exists "student_leave_applications_school_select"',
      ),
    );
    expect(migration, contains('link.parent_user_id = (select auth.uid())'));
    expect(
      migration,
      contains('link.student_id = student_leave_applications.student_id'),
    );
    expect(migration, contains('student_leave_parent_or_leadership_select'));
  });

  test('only leadership receives direct update and delete policies', () {
    expect(migration, contains('leave_applications_leadership_update'));
    expect(migration, contains('leave_applications_leadership_delete'));
    expect(migration, contains('student_leave_leadership_update'));
    expect(migration, contains('student_leave_leadership_delete'));
    expect(
      migration,
      contains("in ('principal', 'coordinator', 'admin', 'super_admin')"),
    );
  });
}
