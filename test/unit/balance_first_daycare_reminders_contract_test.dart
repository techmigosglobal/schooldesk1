import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final feesHandler = File(
    'supabase/functions/api/handlers/fees.ts',
  ).readAsStringSync();
  final migration = File(
    'supabase/migrations/20260728043610_balance_first_daycare_reminders.sql',
  ).readAsStringSync();

  test('new fee payments use live balance amounts instead of month allocation', () {
    final parentFlow = File(
      'lib/features/finance/presentation/screens/parent_hub/parent_payment_flow.dart',
    ).readAsStringSync();
    final principalFlow = File(
      'lib/features/finance/presentation/screens/principal_dashboard/principal_collect_fee.dart',
    ).readAsStringSync();

    expect(feesHandler, contains('function validateInvoicePaymentAmount'));
    expect(
      feesHandler,
      contains('payment amount cannot exceed the remaining balance'),
    );
    expect(feesHandler, contains('p_idempotency_key'));
    expect(feesHandler, isNot(contains('selected_month_names')));
    expect(parentFlow, contains('amount: amount'));
    expect(parentFlow, contains(r'Maximum ${_money(_remainingBalance)}'));
    expect(parentFlow, isNot(contains('Select Months to Pay')));
    expect(
      principalFlow,
      contains('Record any amount up to the current balance'),
    );
    expect(principalFlow, isNot(contains('Select Months to Pay')));
    expect(principalFlow, isNot(contains('_selectedMonths')));
  });

  test('daycare plans create immutable hourly monthly invoice snapshots', () {
    expect(
      migration,
      contains('create table if not exists public.daycare_fee_plans'),
    );
    expect(migration, contains('hourly_rate numeric(12,2) not null'));
    expect(
      migration,
      contains('contracted_hours_per_month numeric(10,2) not null'),
    );
    expect(migration, contains('billing_period date'));
    expect(migration, contains('billing_details jsonb'));
    expect(migration, contains('ensure_daycare_invoice_for_plan'));
    expect(migration, contains('generate_current_daycare_invoices'));
    expect(migration, contains("'hourly_rate', v_plan.hourly_rate"));
    expect(
      migration,
      contains(
        "'contracted_hours_per_month', v_plan.contracted_hours_per_month",
      ),
    );
    expect(feesHandler, contains('feesPath.startsWith("/daycare-plans")'));
    expect(
      feesHandler,
      contains('Daycare plan changes take effect from next month'),
    );
  });

  test('fee reminders are deduplicated, auditable, and push-routable', () {
    final processor = File(
      'supabase/functions/notification-processor/index.ts',
    ).readAsStringSync();
    final home = File(
      'lib/features/finance/presentation/screens/fee_home_screen/fee_home_screen.dart',
    ).readAsStringSync();

    expect(
      migration,
      contains('create table if not exists public.fee_reminder_deliveries'),
    );
    expect(
      migration,
      contains(
        "'before_due_7', 'due_date', 'overdue_7', 'overdue_14', 'manual'",
      ),
    );
    expect(migration, contains('queue_fee_reminders'));
    expect(migration, contains("'30 3 * * *'"));
    expect(feesHandler, contains('queueManualFeeReminders'));
    expect(feesHandler, contains('skipped_cooldown'));
    expect(feesHandler, contains('unavailable_recipients'));
    expect(feesHandler, contains('fee_reminder_deliveries'));
    expect(processor, contains('case "fee_due"'));
    expect(
      processor,
      contains('route: String(eventData.route || "/parent-fees-screen")'),
    );
    expect(
      processor,
      contains('balance: String(eventData.balance || eventData.amount || "")'),
    );
    expect(home, contains('Review fee reminders'));
    expect(home, contains('Reminder delivery'));
  });
}
