import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ui issue polish keeps mobile FABs and filter chips usable', () {
    final complaints = File(
      'lib/features/communication/presentation/screens/complaint_management_screen/complaint_management_screen.dart',
    ).readAsStringSync();
    final students = File(
      'lib/features/people/presentation/screens/admin_students_screen/admin_students_screen.dart',
    ).readAsStringSync();
    final fees = File(
      'lib/features/finance/presentation/screens/admin_fees_screen/admin_fees_screen.dart',
    ).readAsStringSync();
    final receipt = File(
      'lib/features/finance/presentation/screens/fee_payment_receipt_screen/fee_payment_receipt_screen.dart',
    ).readAsStringSync();
    final parentFees = File(
      'lib/features/finance/presentation/screens/parent_fees_screen/parent_fees_screen.dart',
    ).readAsStringSync();
    final oversightFilters = File(
      'lib/features/people/presentation/screens/student_oversight_screen/widgets/student_filter_bar_widget.dart',
    ).readAsStringSync();
    final pdfService = File(
      'lib/core/services/pdf_service.dart',
    ).readAsStringSync();

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

  test('source-only documentation contract is enforced', () {
    for (final path in [
      '.github/workflows/local-docker-ci.yml',
      'README.md',
      'docs/PRD.md',
      'docs/SPEC.md',
    ]) {
      expect(File(path).existsSync(), isTrue, reason: '$path should exist');
    }

    final markdownFiles =
        (Process.runSync('find', [
                  '.',
                  '-name',
                  '*.md',
                  '-not',
                  '-path',
                  './.git/*',
                ]).stdout
                as String)
            .trim()
            .split('\n')
            .where((path) => path.isNotEmpty)
            .map((path) => path.replaceFirst('./', ''))
            .toSet();

    expect(markdownFiles, {'README.md', 'docs/PRD.md', 'docs/SPEC.md'});
  });
}
