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

      expect(source, contains('validateInvoicePaymentAmount'));
      expect(source, contains('parentCanAccessStudent'));
      expect(source, contains('fee_invoice_items'));
      expect(source, isNot(contains('selected_month_names')));
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

  test('normal invoice reads exclude cancelled rows unless auditing', () {
    final source = File(
      'supabase/functions/api/handlers/fees.ts',
    ).readAsStringSync();

    expect(source, contains('include_cancelled'));
    expect(source, contains('q.not("status", "in", "(cancelled,void,voided)")'));
    expect(source, contains('invoiceQuery.not("status", "in", "(cancelled,void,voided)")'));
  });

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

  test('fee structure delete archives history instead of deleting it', () {
    final source = File(
      'supabase/functions/api/handlers/fees.ts',
    ).readAsStringSync();

    expect(source, contains('deleteFeeStructureWorkflowRows'));
    expect(source, contains('archived_at'));
    expect(source, contains('Financial history is immutable'));
    final workflowStart = source.indexOf('async function deleteFeeStructureWorkflowRows');
    final workflowEnd = source.indexOf('export async function handleFees');
    expect(workflowStart, isNonNegative);
    expect(workflowEnd, greaterThan(workflowStart));
    final workflow = source.substring(workflowStart, workflowEnd);
    expect(workflow, isNot(contains('svc.from("fee_receipts").delete()')));
    expect(workflow, isNot(contains('svc.from("payments").delete()')));
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

      expect(section, contains('"pending_verification"'));
      expect(section, contains('"parent_payment_requests"'));
      expect(section, contains('proof_url'));
      expect(section, contains('proof_file_name'));
      expect(section, isNot(contains('"payments"')));
      expect(section, isNot(contains('"fee_receipts"')));
      expect(section, isNot(contains('applyInvoiceAllocationUpdate(')));
    },
  );

  test(
    'payment validation enforces a direct positive amount within the balance',
    () {
      final source = File(
        'supabase/functions/api/handlers/fees.ts',
      ).readAsStringSync();
      final start = source.indexOf('function validateInvoicePaymentAmount');
      final end = source.indexOf('function dueDateFrom');
      final section = start >= 0 && end > start
          ? source.substring(start, end)
          : source;

      expect(section, contains('payment amount cannot exceed the remaining balance'));
      expect(section, contains('payment amount must be greater than zero'));
      expect(section, isNot(contains('selected_months')));
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
    'DELETE fee structure handler archives the selected structure',
    () {
      final source = File(
        'supabase/functions/api/handlers/fees.ts',
      ).readAsStringSync();

      // Find the DELETE handler section
      final structuresStart = source.indexOf(
        'const base = path.startsWith("/fee-structures")',
      );
      final deleteStart = source.indexOf(
        'if (seg && method === "DELETE") {',
        structuresStart,
      );
      expect(deleteStart, isPositive);
      final section = source.substring(deleteStart, deleteStart + 500);
      expect(section, contains('deleteFeeStructureWorkflowRows'));
      expect(section, contains('archive fee structure'));
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
    'deleteFeeStructureWorkflowRows archives the structure and retains finance records',
    () {
      final source = File(
        'supabase/functions/api/handlers/fees.ts',
      ).readAsStringSync();

      final start = source.indexOf(
        'async function deleteFeeStructureWorkflowRows',
      );
      final end = source.indexOf('export async function handleFees');
      final section = source.substring(start, end);

      expect(section, contains('archived_at'));
      expect(section, contains('is_active: false'));
      expect(section, isNot(contains('.delete()')));
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
