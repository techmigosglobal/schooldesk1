import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ui issue polish keeps mobile FABs and filter chips usable', () {
    final complaints = File(
      'lib/presentation/complaint_management_screen/complaint_management_screen.dart',
    ).readAsStringSync();
    final students = File(
      'lib/presentation/admin_students_screen/admin_students_screen.dart',
    ).readAsStringSync();
    final fees = File(
      'lib/presentation/admin_fees_screen/admin_fees_screen.dart',
    ).readAsStringSync();
    final receipt = File(
      'lib/presentation/fee_payment_receipt_screen/fee_payment_receipt_screen.dart',
    ).readAsStringSync();
    final parentFees = File(
      'lib/presentation/parent_fees_screen/parent_fees_screen.dart',
    ).readAsStringSync();
    final oversightFilters = File(
      'lib/presentation/student_oversight_screen/widgets/student_filter_bar_widget.dart',
    ).readAsStringSync();
    final pdfService = File('lib/services/pdf_service.dart').readAsStringSync();

    expect(complaints, contains('FloatingActionButton.extended'));
    expect(complaints, contains('FloatingActionButtonLocation.endFloat'));
    expect(complaints, isNot(contains('DashboardFabWidget')));

    for (final source in [students, fees, receipt]) {
      expect(source, contains('FloatingActionButtonLocation.endFloat'));
    }

    for (final source in [students, oversightFilters]) {
      expect(source, contains('backgroundColor: AppTheme.surfaceVariant'));
      expect(source, contains('MaterialTapTargetSize.shrinkWrap'));
    }
    expect(students, contains('selectedColor: AppTheme.primaryContainer'));
    expect(oversightFilters, contains('selectedColor: AppTheme.primary'));

    for (final source in [fees, receipt, parentFees]) {
      expect(source, contains('previewDocument('));
      expect(source, isNot(contains('Printing.layoutPdf')));
    }
    expect(pdfService, contains('PdfPreview('));
    expect(pdfService, contains('Printing.sharePdf'));
  });

  test('local production-readiness artifacts exist', () {
    for (final path in [
      '.github/workflows/local-docker-ci.yml',
      'docs/api-contract-consolidation-2026-05-17.md',
      'docs/local-docker-ops-runbook-2026-05-17.md',
      'docs/wireless-mobile-testing-plan-2026-05-17.md',
    ]) {
      expect(File(path).existsSync(), isTrue, reason: '$path should exist');
    }
  });
}
