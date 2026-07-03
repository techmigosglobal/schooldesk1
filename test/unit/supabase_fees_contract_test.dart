import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fees handler supports slash fees aliases used by Flutter', () {
    final source = File(
      'supabase/functions/api/handlers/fees.ts',
    ).readAsStringSync();

    expect(source, contains('feesPath.startsWith("/categories")'));
    expect(source, contains('feesPath.startsWith("/structures")'));
    expect(source, contains('feesPath.startsWith("/invoices")'));
    expect(source, contains('feesPath.startsWith("/payments")'));
    expect(source, contains('feesPath.startsWith("/payment-requests")'));
    expect(source, contains('feesPath === "/payment-config"'));
  });

  test(
    'fees handler includes payment intent submit resubmit and config flows',
    () {
      final source = File(
        'supabase/functions/api/handlers/fees.ts',
      ).readAsStringSync();

      expect(source, contains('seg === "intent"'));
      expect(source, contains('seg === "submit"'));
      expect(source, contains('/resubmit'));
      expect(source, contains('/payment-config/qr'));
      expect(source, contains('/payment-configs'));
      expect(source, contains('/payment-configs/'));
      expect(source, contains('invoice-sync'));
      expect(source, contains('late-fines'));
    },
  );

  test('fee workflow schema alignment migration covers Supabase drift', () {
    final migration = File(
      'supabase/migrations/0011_fee_workflow_alignment.sql',
    ).readAsStringSync();

    expect(migration, contains('fee_category_id'));
    expect(
      migration,
      contains('add constraint fee_invoices_invoice_number_key unique'),
    );
    expect(migration, contains('alter table public.fee_installments'));
    expect(migration, contains('school_id uuid'));
    expect(migration, contains('academic_year_id uuid'));
    expect(migration, contains('grade_id uuid'));
    expect(migration, contains('section_id uuid'));
    expect(migration, contains('method text'));
    expect(migration, contains('status text'));
    expect(migration, contains('percentage numeric'));
    expect(
      migration,
      contains('create table if not exists public.fee_receipts'),
    );
    expect(migration, contains('selected_month_names text[]'));
    expect(migration, contains('parent_payment_requests_linked_select'));
  });

  test(
    'Supabase fees handler implements invoice generation and payment lifecycle',
    () {
      final source = File(
        'supabase/functions/api/handlers/fees.ts',
      ).readAsStringSync();

      expect(source, contains('selectedMonthNamesFrom'));
      expect(source, contains('invoicePayableAmount'));
      expect(source, contains('parentCanAccessStudent'));
      expect(source, contains('fee_invoice_items'));
      expect(source, contains('monthly_amount'));
      expect(source, contains('parent_payment_requests'));
      expect(source, contains('attachPaymentRequestRelations'));
      expect(source, contains('parent_user: parentsById.get(text(row.parent_user_id))'));
      expect(source, contains('pending_verification'));
      expect(source, contains('transaction_ref: text(form.get("transaction_ref")'));
      expect(source, contains('proof_file_name: screenshot?.name'));
      expect(source, contains('fee_receipts'));
      expect(source, contains('payment_id'));
      expect(source, contains('receipt_id'));
      expect(source, contains('payment amount must be'));
    },
  );

  test(
    'students handler exposes student fees route and avoids Dart string helpers',
    () {
      final source = File(
        'supabase/functions/api/handlers/students.ts',
      ).readAsStringSync();

      expect(source, contains('sub === "fees"'));
      expect(source, contains('fee_invoices'));
      expect(source, isNot(contains('.isNotEmpty')));
      expect(source, isNot(contains('.isEmpty')));
    },
  );

  test(
    'student directory keeps class loading independent from fee structures',
    () {
      final source = File(
        'lib/features/people/presentation/screens/student_oversight_screen/student_oversight_screen.dart',
      ).readAsStringSync();

      expect(source, contains('_loadFeeStructuresSafely'));
      expect(source, contains('return const <Map<String, dynamic>>[];'));
      expect(source, contains('items.contains(value) ? value : null'));
    },
  );

  test('parent fee history datasource uses Supabase fee payment routes', () {
    final source = File(
      'lib/features/finance/data/datasources/parent_fees_remote_datasource.dart',
    ).readAsStringSync();

    expect(source, contains("'/fees/payments'"));
    expect(source, contains('getMyStudents()'));
    expect(source, contains("queryParameters: {'student_id': studentId}"));
    expect(source, isNot(contains('/parents/fees/payments')));
    expect(source, isNot(contains('/parents/fees/receipts')));
  });
}
