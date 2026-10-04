import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('forward migration removes audit storage and decision triggers', () {
    final migration = File(
      'supabase/migrations/20261003143942_remove_audit_logs.sql',
    ).readAsStringSync();
    expect(
      migration,
      contains('drop table if exists public.audit_logs cascade'),
    );
    expect(
      migration,
      contains(
        'drop function if exists public.record_approval_decision_audit()',
      ),
    );
    expect(migration, contains('error_events'));
  });

  test(
    'API no longer imports audit writers or registers the audit endpoint',
    () {
      final api = File('supabase/functions/api/index.ts').readAsStringSync();
      final handlers = Directory('supabase/functions/api/handlers')
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.ts'))
          .map((file) => file.readAsStringSync())
          .join('\n');
      expect(api, isNot(contains('handleActivity')));
      expect(handlers, isNot(contains('recordActivity')));
      expect(handlers, isNot(contains('from("audit_logs")')));
    },
  );

  test(
    'error-event diagnostics and business approval decisions stay present',
    () {
      final monitoring = File(
        'supabase/functions/api/handlers/monitoring.ts',
      ).readAsStringSync();
      final approvals = File(
        'supabase/functions/api/handlers/approvals.ts',
      ).readAsStringSync();
      expect(monitoring, contains('from("error_events")'));
      expect(approvals, contains('approval_requests'));
      final auth = File(
        'supabase/functions/api/handlers/auth.ts',
      ).readAsStringSync();
      expect(auth, contains('from("user_sessions").insert'));
      expect(auth, contains('signed_out_at: now'));
    },
  );
}
