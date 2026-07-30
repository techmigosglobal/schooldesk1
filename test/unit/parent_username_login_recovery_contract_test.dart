import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('legacy parent usernames are safely backfilled as login aliases', () {
    final migration = File(
      'supabase/migrations/20260729184144_repair_missing_username_aliases.sql',
    ).readAsStringSync();

    expect(migration, contains('join auth.users au on au.id = u.id'));
    expect(migration, contains('own_alias.auth_user_id is null'));
    expect(migration, contains("nullif(trim(u.username), '') is not null"));
    expect(migration, contains('on conflict (username) do nothing'));
  });

  test(
    'username login uses the authoritative Auth email and self-heals aliases',
    () {
      final handler = File(
        'supabase/functions/api/handlers/auth.ts',
      ).readAsStringSync();

      expect(handler, contains('.select("id, email, school_id, username")'));
      expect(
        handler,
        contains('.auth.admin\n            .getUserById(userRow.id)'),
      );
      expect(handler, contains('await updateOwnUsernameAlias('));
      expect(
        handler,
        contains('await anonClient.auth\n      .signInWithPassword'),
      );
      expect(handler, contains('role_name: normalizedRole'));
    },
  );

  test(
    'unlinked imported parents receive a child only from one guardian match',
    () {
      final migration = File(
        'supabase/migrations/20260729185317_repair_unlinked_parent_guardian_accounts.sql',
      ).readAsStringSync();
      final handler = File(
        'supabase/functions/api/handlers/auth.ts',
      ).readAsStringSync();

      expect(
        migration,
        contains("lower(coalesce(u.role_name, '')) = 'parent'"),
      );
      expect(migration, contains('count(distinct student_id) = 1'));
      expect(migration, contains('not exists ('));
      expect(handler, contains('repairUnambiguousParentStudentLink'));
      expect(handler, contains('.eq("phone", phone)'));
      expect(handler, contains('if (studentIds.length !== 1) return'));
    },
  );

  test('legacy parent Auth claims are normalized for route-safe sessions', () {
    final migration = File(
      'supabase/migrations/20260729185943_normalize_legacy_parent_auth_roles.sql',
    ).readAsStringSync();

    expect(migration, contains("'{role_name}'"));
    expect(migration, contains("'\"parent\"'::jsonb"));
    expect(migration, contains("lower(coalesce(u.role_name, '')) = 'parent'"));
  });

  test('imported parents receive and retain their home branch membership', () {
    final migration = File(
      'supabase/migrations/20260730004500_repair_imported_user_home_branch_memberships.sql',
    ).readAsStringSync();

    expect(migration, contains('insert into public.branch_memberships'));
    expect(migration, contains('on conflict (user_id, school_id) do update'));
    expect(migration, contains('ensure_user_home_branch_membership'));
    expect(migration, contains('trg_user_home_branch_membership'));
  });
}
