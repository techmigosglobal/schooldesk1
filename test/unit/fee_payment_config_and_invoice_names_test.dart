import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('principal fee surfaces always expose payment setup', () {
    final dashboard = File(
      'lib/features/finance/presentation/screens/principal_dashboard/principal_fee_dashboard.dart',
    ).readAsStringSync();
    final feeHome = File(
      'lib/features/finance/presentation/screens/fee_home_screen/fee_home_screen.dart',
    ).readAsStringSync();
    final guard = File('lib/routes/route_access_guard.dart').readAsStringSync();

    expect(dashboard, contains("label: 'Payment Setup'"));
    expect(dashboard, contains('route: AppRoutes.feePaymentConfig'));
    expect(feeHome, contains("title: 'Parent Payment Setup'"));
    expect(feeHome, contains("'Set UPI ID and upload QR code'"));
    expect(guard, contains("AppRoutes.feePaymentConfig: {'principal'}"));
  });

  test('student ledger owns individual invoice printing', () {
    final dashboard = File(
      'lib/features/finance/presentation/screens/principal_dashboard/principal_fee_dashboard.dart',
    ).readAsStringSync();
    final ledger = File(
      'lib/features/finance/presentation/screens/fee_ledger_screen/fee_ledger_screen.dart',
    ).readAsStringSync();

    expect(dashboard, contains('.map(normalizeFeeStructure)'));
    expect(dashboard, isNot(contains('principalInvoiceGenerationForm')));
    expect(ledger, contains('Future<void> _previewInvoice('));
    expect(ledger, contains('FeeDocumentKind.feeInvoice'));
    expect(ledger, contains('Invoice PDF'));
    expect(ledger, contains('Record payment'));
    expect(ledger, contains("tooltip: 'Receipt PDF'"));
  });
}
