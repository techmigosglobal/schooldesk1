import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('each finalized payment receipt receives an immutable dated snapshot', () {
    final migration = File(
      'supabase/migrations/20260729173723_automatic_payment_receipt_snapshots.sql',
    ).readAsStringSync();
    final feesHandler = File(
      'supabase/functions/api/handlers/fees.ts',
    ).readAsStringSync();

    expect(migration, contains('capture_payment_receipt_snapshot'));
    expect(migration, contains('after insert on public.fee_receipts'));
    expect(migration, contains("'this_payment_amount'"));
    expect(migration, contains("'payment_date'"));
    expect(migration, contains('document_snapshot_id'));
    expect(migration, contains('do nothing'));
    expect(feesHandler, contains('receipt_snapshot: snapshot'));
  });

  test(
    'the official receipt includes collection fields and signature support',
    () {
      final pdfService = File(
        'lib/core/services/pdf_service.dart',
      ).readAsStringSync();

      expect(pdfService, contains("'PAYMENT INFORMATION'"));
      expect(pdfService, contains("'Reference / Cheque No.'"));
      expect(pdfService, contains('Amount in words:'));
      expect(pdfService, contains('authorizedSignature'));
      expect(pdfService, contains('Parent Copy'));
    },
  );
}
