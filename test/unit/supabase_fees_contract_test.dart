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
    'fee management remains principal-only while parents use proof flow',
    () {
      final source = File(
        'supabase/functions/api/handlers/fees.ts',
      ).readAsStringSync();

      expect(source, contains('isFinanceManagementPath'));
      expect(source, contains('principal access required'));
      expect(source, contains('isParentPaymentAction'));
      expect(
        source,
        contains('only parents can submit manual UPI payment proofs'),
      );
      expect(source, contains('only parents can resubmit payment proofs'));
      expect(source, contains('parent or principal access required'));
    },
  );

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
      expect(
        source,
        contains('payment amount cannot exceed the remaining balance'),
      );
    },
  );

  test(
    'invoice generation fills missing student components without duplicating paid or unpaid invoices',
    () {
      final source = File(
        'supabase/functions/api/handlers/fees.ts',
      ).readAsStringSync();

      expect(source, contains('const existingInvoiceKeys = new Set<string>()'));
      expect(source, contains('existingInvoiceKeys.has(invoiceKey)'));
      expect(source, contains('existing_paid_count: existingPaid'));
      expect(source, contains('existing_unpaid_count: existingUnpaid'));
    },
  );

  test('parent fee endpoint enriches completed payments with receipts', () {
    final source = File(
      'supabase/functions/api/handlers/fees.ts',
    ).readAsStringSync();

    expect(source, contains('receiptsByPaymentId'));
    expect(source, contains('receipt_number: text('));
    expect(source, contains('fee_invoice_items(*), payments(*)'));
  });

  test('fee structure delete clears generated dues and collection rows', () {
    final source = File(
      'supabase/functions/api/handlers/fees.ts',
    ).readAsStringSync();

    expect(source, contains('deleteFeeStructureWorkflowRows'));
    expect(source, contains('invoiceIdsForFeeStructure'));
    expect(source, contains('deleteInvoiceWorkflowRows'));
    expect(source, contains('url.searchParams.get("remove_pending")'));
    expect(source, contains('svc.from("fee_receipts").delete()'));
    expect(
      source,
      contains('svc.from("fee_receipts").delete().in("payment_id"'),
    );
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
      expect(source, contains('hasPaymentDestination'));
      expect(source, contains('config?.upi_enabled !== false'));
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
    'payment config partial updates preserve existing UPI and QR values',
    () {
      final source = File(
        'supabase/functions/api/handlers/fees.ts',
      ).readAsStringSync();
      final start = source.indexOf(
        'if (feesPath === "/payment-config" && method === "PUT") {',
      );
      final end = source.indexOf(
        'if (feesPath === "/payment-config/qr" && method === "POST") {',
      );
      final section = start >= 0 && end > start
          ? source.substring(start, end)
          : source;

      expect(section, contains('Object.hasOwn(body, key)'));
      expect(section, isNot(contains('body.upi_id ?? ""')));
      expect(section, isNot(contains('body.qr_image_url ?? ""')));
    },
  );

  test(
    'fee structures and generated invoice numbers expose category names',
    () {
      final source = File(
        'supabase/functions/api/handlers/fees.ts',
      ).readAsStringSync();

      expect(source, contains('category_name: categoryName'));
      expect(source, contains('fee_item_name: categoryName'));
      expect(source, contains('const structureTag = categoryName'));
      expect(source, contains(r'}-${structureTag}`'));
      expect(
        source,
        isNot(
          contains(
            r'${structureTag}-${text(structure.id).slice(0, 4).toUpperCase()}',
          ),
        ),
      );
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

      expect(section, contains('svc.rpc("record_fee_payment"'));
      expect(source, contains('record_fee_payment'));
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
    'tuition selection validation enforces the June–March cycle and one-time fees',
    () {
      final source = File(
        'supabase/functions/api/handlers/fees.ts',
      ).readAsStringSync();
      final start = source.indexOf('function validateInvoiceSelection');
      final end = source.indexOf('async function applyInvoiceAllocationUpdate');
      final section = start >= 0 && end > start
          ? source.substring(start, end)
          : source;

      expect(
        section,
        contains('This fee is one-time only and cannot be split'),
      );
      expect(section, contains('Select at least one monthly installment'));
      expect(
        section,
        contains('Monthly installments must be paid in order without skipping'),
      );
      expect(
        section,
        contains('selected_months cannot exceed the June–March cycle of 10'),
      );
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
    final hub = File(
      'lib/features/finance/presentation/screens/parent_hub/parent_fee_hub.dart',
    ).readAsStringSync();

    expect(datasource, contains("'receipt_id'"));
    expect(datasource, contains("'receipt_no'"));
    expect(datasource, contains("'invoice_number'"));
    expect(datasource, contains("'fee_type'"));
    expect(hub, contains("invoice['invoice_number']"));
    expect(hub, contains("payment['receipt_number']"));
    expect(hub, contains("payment['amount_paid']"));
    expect(hub, contains("payment['payment_date']"));
    expect(hub, contains("payment['payment_mode']"));
  });

  // ── Orphaned invoice cleanup contract tests ──────────────────────────────

  test(
    'invoiceIdsForFeeStructure has scope-based fallback for orphaned invoices',
    () {
      final source = File(
        'supabase/functions/api/handlers/fees.ts',
      ).readAsStringSync();

      // The function must exist and contain the three lookup strategies
      expect(source, contains('async function invoiceIdsForFeeStructure'));
      // 1. Direct link via fee_invoices.fee_structure_id
      expect(source, contains('.eq("fee_structure_id", structureId)'));
      // 2. Indirect link via fee_invoice_items
      expect(source, contains('fee_invoice_items'));
      // 3. Scope-based fallback for orphaned invoices
      expect(source, contains('Scope-based fallback'));
      expect(source, contains('.is("fee_structure_id", null)'));
      expect(source, contains('.neq("status", "paid")'));
      // Must query students through sections for grade/scope matching
      expect(source, contains('current_section_id'));
      expect(source, contains('sections'));
    },
  );

  test(
    'DELETE fee structure handler includes reconciliation sweep for orphaned invoices',
    () {
      final source = File(
        'supabase/functions/api/handlers/fees.ts',
      ).readAsStringSync();

      // Find the DELETE handler section
      final deleteStart = source.indexOf('if (seg && method === "DELETE") {');
      // Find the reconciliation sweep section (after the structure is deleted)
      final reconciliationStart = source.indexOf('Reconciliation sweep');
      expect(reconciliationStart, isPositive);

      final section = source.substring(reconciliationStart);
      // Must query for orphaned invoices after structure deletion
      expect(section, contains('fee_invoices'));
      expect(section, contains('.is("fee_structure_id", null)'));
      expect(section, contains('.neq("status", "paid")'));
      // Must clean up orphaned invoices via deleteInvoiceWorkflowRows
      expect(section, contains('deleteInvoiceWorkflowRows'));
      // Must report reconciled_orphans count in response
      expect(section, contains('reconciled_orphans'));
      // Must be best-effort (wrapped in try/catch)
      expect(section, contains('Best-effort reconciliation'));
    },
  );

  test(
    'dashboard handler queries paid_amount not amount_paid for totalPaid',
    () {
      final source = File(
        'supabase/functions/api/handlers/dashboard.ts',
      ).readAsStringSync();

      // Must use the correct column name paid_amount
      expect(source, contains('"paid_amount"'));
      expect(source, contains('i.paid_amount'));
      // Must NOT use the wrong column name amount_paid in select or reduce
      expect(source, isNot(contains('"amount_paid"')));
      expect(source, isNot(contains('i.amount_paid')));
    },
  );

  test(
    'deleteFeeStructureWorkflowRows cleans up installments and concessions',
    () {
      final source = File(
        'supabase/functions/api/handlers/fees.ts',
      ).readAsStringSync();

      final start = source.indexOf(
        'async function deleteFeeStructureWorkflowRows',
      );
      final end = source.indexOf('export async function handleFees');
      final section = source.substring(start, end);

      // Must call invoiceIdsForFeeStructure first
      expect(section, contains('invoiceIdsForFeeStructure'));
      // Must call deleteInvoiceWorkflowRows for invoice cleanup
      expect(section, contains('deleteInvoiceWorkflowRows'));
      // Must delete fee_installments
      expect(section, contains('fee_installments'));
      // Must delete fee_concessions
      expect(section, contains('fee_concessions'));
      // Must return deletion stats
      expect(section, contains('deleted_installments'));
      expect(section, contains('deleted_concessions'));
    },
  );

  test('orphaned fee cleanup migration covers all affected tables', () {
    final migration = File(
      'supabase/migrations/20260706180300_orphaned_fee_cleanup.sql',
    ).readAsStringSync();

    // Must target fee_invoices with fee_structure_id IS NULL
    expect(migration, contains('fee_structure_id IS NULL'));
    expect(migration, contains('status NOT IN'));
    // Must delete from all child tables in correct order
    expect(migration, contains('DELETE FROM public.fee_receipts'));
    expect(migration, contains('DELETE FROM public.parent_payment_requests'));
    expect(migration, contains('DELETE FROM public.payments'));
    expect(migration, contains('DELETE FROM public.fee_invoice_items'));
    expect(migration, contains('DELETE FROM public.fee_invoices'));
    // Must preserve paid and cancelled invoices
    expect(migration, contains("'paid', 'cancelled'"));
  });
}
