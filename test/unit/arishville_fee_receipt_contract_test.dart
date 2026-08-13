import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('new receipts use the immutable Arishville identity format', () {
    final migration = File(
      'supabase/migrations/20260813110000_arishville_fee_receipt_alignment.sql',
    ).readAsStringSync();

    expect(migration, contains("where lower(name) like '%arish%ville%'"));
    expect(migration, contains("'-C' || lpad(v_class_order::text, 2, '0')"));
    expect(migration, contains('v_student_token'));
    expect(migration, contains("lpad(v_sequence::text, 3, '0')"));
    expect(migration, contains('idempotency_key = p_idempotency_key'));
    expect(migration, contains("'payment_receipt'"));
  });

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

    expect(handler, contains('async function paymentReceiptPayload'));
    expect(handler, contains('parentCanAccessStudent'));
    expect(handler, contains('if (!isParent && !isAdminOrPrincipal(user))'));
    expect(handler, contains(r'feesPath.match(/^\/receipts\/([^/]+)$/)'));
    expect(api, contains('getFeeReceiptPayload'));
    expect(parentReceipt, contains('getFeeReceiptPayload'));
    expect(parentReceipt, contains('generatePaymentReceiptFromPayload'));
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
  });
}
