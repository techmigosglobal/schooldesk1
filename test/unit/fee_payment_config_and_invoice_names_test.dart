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

  test('principal invoice generator normalizes and renders fee names', () {
    final dashboard = File(
      'lib/features/finance/presentation/screens/principal_dashboard/principal_fee_dashboard.dart',
    ).readAsStringSync();
    final generator = File(
      'lib/features/finance/presentation/screens/principal_dashboard/principal_invoice_generate.dart',
    ).readAsStringSync();

    expect(dashboard, contains('.map(normalizeFeeStructure)'));
    expect(generator, contains('String _feeComponentName('));
    expect(
      generator,
      contains("category['category_name'] ?? category['name']"),
    );
    expect(generator, contains('_feeComponentName(fee)'));
  });
}
