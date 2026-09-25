import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'school wipe removes every account except principal and Super Admin',
    () {
      final handler = File(
        'supabase/functions/api/handlers/monitoring.ts',
      ).readAsStringSync();
      final migration = File(
        'supabase/migrations/20260713015324_secure_school_operational_wipe.sql',
      ).readAsStringSync();
      final screen = File(
        'lib/features/monitoring/presentation/screens/system_monitor_screen.dart',
      ).readAsStringSync();
      final gateway = File(
        'supabase/functions/api/index.ts',
      ).readAsStringSync();

      expect(handler, contains('wipe_school_data'));
      expect(handler, contains('wipeSchoolStorage'));
      expect(handler, contains('collectSchoolWipeAccounts'));
      expect(handler, contains('deleteSchoolAuthAccounts'));
      expect(handler, contains('Wipe blocked: this school has no principal'));
      expect(handler, isNot(contains('.delete().neq(')));
      expect(migration, contains('pg_advisory_xact_lock'));
      expect(migration, contains(r'where school_id = $1'));
      expect(migration, contains("'users'"));
      expect(migration, contains("'username_aliases'"));
      expect(screen, contains('Wipe All School Data'));
      expect(
        screen,
        contains('Delete Everything Except Principal & Super Admin'),
      );
      expect(screen, contains('Principal and Super Admin accounts remain'));
      expect(gateway, contains('Require the active application profile'));
      expect(gateway, contains('profile.is_active !== true'));
    },
  );
}
