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
      expect(
        source,
        contains('parent_user: parentsById.get(text(row.parent_user_id))'),
      );
      expect(source, contains('pending_verification'));
      expect(source, contains('transaction_ref: text('));
      expect(
        source,
        contains('form.get("transaction_ref") ?? form.get("transaction_id")'),
      );
      expect(source, contains('proof_file_name: screenshot?.name'));
      expect(source, contains('fee_receipts'));
      expect(source, contains('payment_id'));
      expect(source, contains('receipt_id'));
      expect(source, contains('payment amount must be'));
    },
  );

  test('fee structure delete clears generated dues and collection rows', () {
    final source = File(
      'supabase/functions/api/handlers/fees.ts',
    ).readAsStringSync();

    expect(source, contains('deleteFeeStructureWorkflowRows'));
    expect(source, contains('invoiceIdsForFeeStructure'));
    expect(source, contains('deleteInvoiceWorkflowRows'));
    expect(source, contains('url.searchParams.get("remove_pending")'));
    expect(source, contains('svc.from("fee_receipts").delete()'));
    expect(source, contains('svc.from("parent_payment_requests").delete()'));
    expect(source, contains('svc.from("payments").delete()'));
    expect(source, contains('svc.from("fee_invoices").delete()'));
    expect(source, contains('svc.from("fee_concessions").delete()'));
    expect(source, contains('deleted_invoices'));
  });

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

  test(
    'payment config resolution should inspect invoice-aware scope before returning a QR config',
    () {
      final source = File(
        'supabase/functions/api/handlers/fees.ts',
      ).readAsStringSync();
      final start = source.indexOf(
        'if (feesPath === "/payment-config" && method === "GET") {',
      );
      final end = source.indexOf(
        'if (feesPath === "/payment-config" && method === "PUT") {',
      );
      final section = start >= 0 && end > start
          ? source.substring(start, end)
          : source;

      expect(section, contains('invoice_id'));
      expect(section, contains('resolveScopedPaymentConfig'));
      expect(source, contains('grade_id'));
      expect(source, contains('section_id'));
      expect(source, contains('configRecordId("section", gradeId, sectionId)'));
      expect(source, contains('configRecordId("grade", gradeId)'));
    },
  );

  test(
    'payment config save updates or inserts without requiring an unsupported upsert conflict target',
    () {
      final source = File(
        'supabase/functions/api/handlers/fees.ts',
      ).readAsStringSync();
      final start = source.indexOf('async function savePaymentConfigRecord');
      final end = source.indexOf('async function resolveScopedPaymentConfig');
      final section = start >= 0 && end > start
          ? source.substring(start, end)
          : source;

      expect(section, contains('if (existing != null)'));
      expect(section, contains('.update({'));
      expect(section, contains('.insert({'));
      expect(section, isNot(contains('.upsert({')));
      expect(section, isNot(contains('onConflict')));
    },
  );

  test(
    'principal fees screen previews QR safely and keeps Book Kit before tuition collection',
    () {
      final source = File(
        'lib/features/finance/presentation/screens/fee_monitoring_screen/fee_monitoring_screen.dart',
      ).readAsStringSync();

      expect(source, contains("const Text('Current QR image')"));
      expect(source, contains('Image.network('));
      expect(source, contains('_absoluteMediaUrl(qrImageUrl)'));
      expect(source, contains('sheetContext.mounted'));
      expect(source, contains('Navigator.of(sheetContext).pop()'));
      expect(source, contains('_disposeFeeComponentAfterFrame('));
      expect(source, contains('_feeInvoicePriority('));
      expect(source, contains('final priorityCompare = _feeInvoicePriority('));
      expect(source, contains(').compareTo(_feeInvoicePriority(b));'));
      expect(source, contains('_syncManualMonthsFromAmount('));
      expect(
        source,
        contains('onChanged: (_) => _syncManualMonthsFromAmount()'),
      );
      expect(source, contains('.round().clamp('));
      expect(source, contains('unpaid.length'));
    },
  );

  test(
    'payment approval decision keeps admin remarks separate and updates invoice balances',
    () {
      final source = File(
        'supabase/functions/api/handlers/fees.ts',
      ).readAsStringSync();
      final start = source.indexOf(
        'if (seg && path.endsWith("/decision") && method === "PUT") {',
      );
      final end = source.indexOf(
        'if (feesPath === "/payment-config" && method === "GET") {',
      );
      final section = start >= 0 && end > start
          ? source.substring(start, end)
          : source;

      expect(section, contains('await svc.from('));
      expect(section, contains('"payments"'));
      expect(section, contains(').insert({'));
      expect(section, contains('"fee_receipts"'));
      expect(source, contains('applyInvoiceAllocationUpdate('));
      expect(section, contains('admin_remarks: body.admin_remarks'));
      expect(section, isNot(contains('remarks: body.remarks')));
    },
  );

  test(
    'parent proof submission remains pending only until principal approval',
    () {
      final source = File(
        'supabase/functions/api/handlers/fees.ts',
      ).readAsStringSync();
      final start = source.indexOf(
        'if (seg === "submit" && method === "POST")',
      );
      final end = source.indexOf(
        'if (seg && normalized.endsWith("/resubmit") && method === "PATCH")',
      );
      final section = start >= 0 && end > start
          ? source.substring(start, end)
          : source;

      expect(section, contains('status: "pending_verification"'));
      expect(section, contains('"parent_payment_requests"'));
      expect(section, contains('proof_url'));
      expect(section, contains('proof_file_name'));
      expect(section, isNot(contains('"payments"')));
      expect(section, isNot(contains('"fee_receipts"')));
      expect(section, isNot(contains('applyInvoiceAllocationUpdate(')));
    },
  );

  test(
    'tuition selection validation enforces continuous unpaid months and one-time book kit',
    () {
      final source = File(
        'supabase/functions/api/handlers/fees.ts',
      ).readAsStringSync();
      final start = source.indexOf('function validateInvoiceSelection');
      final end = source.indexOf('async function applyInvoiceAllocationUpdate');
      final section = start >= 0 && end > start
          ? source.substring(start, end)
          : source;

      expect(section, contains('Book & Kit Fee is one-time only'));
      expect(section, contains('Select at least one continuous tuition month'));
      expect(
        section,
        contains(
          'Tuition months must be paid in continuous order without skipping',
        ),
      );
      expect(section, contains('selected_months cannot exceed 12'));
      expect(
        section,
        contains('selected_terms cannot exceed configured academic terms'),
      );
    },
  );

  test('parent payment history keeps receipt and invoice context', () {
    final datasource = File(
      'lib/features/finance/data/datasources/parent_fees_remote_datasource.dart',
    ).readAsStringSync();
    final history = File(
      'lib/features/finance/presentation/screens/parent_payment_screens/parent_payment_history_screen.dart',
    ).readAsStringSync();

    expect(datasource, contains("'receipt_id'"));
    expect(datasource, contains("'receipt_no'"));
    expect(datasource, contains("'invoice_number'"));
    expect(datasource, contains("'fee_type'"));
    expect(history, contains("payment['selected_month_names']"));
    expect(history, contains("payment['reference_number']"));
    expect(history, contains("normalizedStatus == 'completed'"));
    expect(history, isNot(contains('value.toDouble() / 100')));
  });
}
