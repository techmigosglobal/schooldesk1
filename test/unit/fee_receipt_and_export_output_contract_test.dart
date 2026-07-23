import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final root = Directory.current.path;

  test(
    'parent receipts generate a shareable PDF instead of a simulated toast',
    () {
      final source = File(
        '$root/lib/features/finance/presentation/screens/parent_hub/parent_receipt_view_v2.dart',
      ).readAsStringSync();

      expect(source, contains('PdfService.getInstance().generateFeeReceipt'));
      expect(source, contains('ShareExportService().shareBytes'));
      expect(source, isNot(contains('Simulating Share')));
    },
  );

  test('paid fee receipt accepts principal-approved proof payments', () {
    final source = File(
      '$root/lib/features/finance/presentation/screens/parent_hub/parent_fee_hub.dart',
    ).readAsStringSync();

    expect(source, contains("'completed', 'approved', 'paid'"));
    expect(source, contains('_openReceiptForFee(fee)'));
  });

  test('principal fee reports preview branded PDFs before any export action', () {
    final source = File(
      '$root/lib/features/finance/presentation/screens/principal_dashboard/principal_reports_v2.dart',
    ).readAsStringSync();

    expect(source, contains('_generatePdf'));
    expect(source, contains('pdfService.previewDocument'));
    expect(
      source,
      contains('Future<void> _requestExport(_ReportDef _) => _generatePdf()'),
    );
    expect(source, isNot(contains("format: 'csv'")));
  });
}
