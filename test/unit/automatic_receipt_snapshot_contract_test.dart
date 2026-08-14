import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'each finalized payment receipt receives an immutable dated snapshot',
    () {
      final migration = File(
        'supabase/migrations/20260814055208_fee_receipt_integrity_alignment.sql',
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
      expect(
        migration,
        contains("raise exception 'Receipt snapshot was not generated"),
      );
      expect(feesHandler, contains('ensureReceiptSnapshot'));
      expect(feesHandler, contains('receipt_snapshot: snapshot'));
    },
  );

  test(
    'the official receipt includes collection fields and signature support',
    () {
      final pdfService = File(
        'lib/core/services/pdf_service.dart',
      ).readAsStringSync();

      expect(pdfService, contains("'FEE RECEIPT'"));
      expect(pdfService, contains("'Student ID'"));
      expect(pdfService, contains("'Transaction Reference'"));
      expect(pdfService, contains("'Amount in Words'"));
      expect(pdfService, contains('authorizedSignature'));
      expect(pdfService, contains("'Authorised Signatory'"));
    },
  );
}
