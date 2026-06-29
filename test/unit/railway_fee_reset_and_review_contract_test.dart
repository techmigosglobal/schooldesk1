import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('railway fee reset script is dry-run first and fee scoped', () {
    final script = File('scripts/reset-railway-fees.sh').readAsStringSync();

    expect(script, contains('mode="dry-run"'));
    expect(script, contains('RAILWAY_FEE_RESET'));
    expect(script, contains('DATABASE_URL'));
    expect(script, contains('pg_dump'));
    expect(script, contains('TRUNCATE TABLE'));

    for (final table in [
      'fee_receipt_invoice_map',
      'payment_order_invoice_map',
      'fee_receipts',
      'payment_transactions',
      'payment_webhook_events',
      'payment_orders',
      'parent_payment_requests',
      'payments',
      'fee_invoice_items',
      'fee_invoices',
      'fee_concessions',
      'fee_installments',
      'fee_structures',
      'fee_categories',
      'school_payment_settings',
      'scoped_payment_settings',
    ]) {
      expect(script, contains(table));
    }

    expect(script, isNot(contains('TRUNCATE TABLE public.students')));
    expect(script, isNot(contains('TRUNCATE TABLE public.users')));
    expect(
      script,
      isNot(contains('TRUNCATE TABLE public.parent_student_links')),
    );
    expect(script, isNot(contains('TRUNCATE TABLE public.guardians')));
    expect(script, contains('Protected non-fee tables'));
  });

  test('local code reviewer script replaces stalled third party review gate', () {
    final script = File('scripts/local-code-review.sh').readAsStringSync();

    expect(
      script,
      contains('flutter test test/unit/attendance_workflow_contract_test.dart'),
    );
    expect(
      script,
      contains(
        'flutter test test/unit/railway_fee_reset_and_review_contract_test.dart',
      ),
    );
    expect(script, contains('dart analyze'));
    expect(
      script,
      contains('go test ./internal/handlers ./cmd/local-api-verify'),
    );
    expect(script, contains('git diff --check'));
    expect(script, contains('rg -n'));
    expect(script, contains('DATABASE_URL|PGPASSWORD|RAILWAY_TOKEN'));
    expect(script, contains('scripts/verify-local-docker-api.sh'));
  });
}
