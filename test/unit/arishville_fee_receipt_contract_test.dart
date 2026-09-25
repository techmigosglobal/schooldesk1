import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('new receipts use the immutable Arishville identity format', () {
    final migration = File(
      'supabase/migrations/20260814055208_fee_receipt_integrity_alignment.sql',
    ).readAsStringSync();

    expect(migration, contains("where lower(name) like '%arish%ville%'"));
    expect(migration, contains("select id, 'AVP'"));
    expect(migration, contains("v_receipt_number := v_receipt_prefix || '/'"));
    expect(migration, contains("v_year_label || '/'"));
    expect(migration, contains("v_branch_token || '/'"));
    expect(migration, contains("v_month_token || '/'"));
    expect(migration, contains("lpad(v_sequence::text, 3, '0')"));
    expect(migration, contains("p_school_id, v_year_label, 'receipt', 1"));
    expect(migration, contains('idempotency_key = p_idempotency_key'));
    expect(migration, contains("'payment_receipt'"));
  });

  test(
    'historical receipts get display aliases without renumbering identity',
    () {
      final migration = File(
        'supabase/migrations/20260814055208_fee_receipt_integrity_alignment.sql',
      ).readAsStringSync();

      expect(migration, contains('display_receipt_number'));
      expect(migration, contains('fee_receipt_display_number_backfilled'));
      expect(migration, contains('legacy_receipt_number'));
      expect(
        migration,
        isNot(contains('set receipt_number = v_display_number')),
      );
    },
  );

  test('receipt payload is role-scoped and drives parent PDF rendering', () {
    final handler = File(
      'supabase/functions/api/handlers/fees.ts',
    ).readAsStringSync();
    final api = File(
      'lib/core/network/api_modules/fees_api.dart',
    ).readAsStringSync();
    final parentReceipt = File(
      'lib/features/finance/presentation/screens/parent_hub/parent_receipt_view_v2.dart',
    ).readAsStringSync();
    final ledger = File(
      'lib/features/finance/presentation/screens/fee_ledger_screen/fee_ledger_screen.dart',
    ).readAsStringSync();

    expect(handler, contains('async function paymentReceiptPayload'));
    expect(handler, contains('legacy_receipt_number'));
    expect(handler, contains('display_receipt_number'));
    expect(handler, contains('feePeriodLabel(invoice.billing_period)'));
    expect(handler, contains('yearRow.year_label'));
    expect(handler, contains('parentCanAccessStudent'));
    expect(handler, contains('if (!isParent && !isAdminOrPrincipal(user))'));
    expect(handler, contains(r'feesPath.match(/^\/receipts\/([^/]+)$/)'));
    expect(api, contains('getFeeReceiptPayload'));
    expect(parentReceipt, contains('loadReceiptPayload'));
    expect(parentReceipt, contains('generatePaymentReceiptFromPayload'));
    expect(ledger, contains("receipt['display_receipt_number']"));
    expect(ledger, contains("return 'Not issued';"));
  });

  test('payment receipt PDF follows the supplied formal layout', () {
    final pdf = File('lib/core/services/pdf_service.dart').readAsStringSync();

    expect(pdf, contains("'FEE RECEIPT'"));
    expect(pdf, contains('border: pw.Border.all(color: PdfColors.black'));
    expect(pdf, contains("['Receipt No.', receiptNo]"));
    expect(pdf, contains("['Student Name', studentName]"));
    expect(pdf, contains("'Academic Year'"));
    expect(pdf, contains("academicYear.isEmpty ? '—' : academicYear"));
    expect(pdf, contains("'S.No.'"));
    expect(pdf, contains("'Transaction Reference'"));
    expect(pdf, contains("'Amount in Words'"));
    expect(pdf, contains("'Authorised Signatory'"));
    expect(pdf, contains('documentKind == FeeDocumentKind.feeInvoice'));
  });
}
