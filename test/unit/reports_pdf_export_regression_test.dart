import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('principal reports use live structured exports', () {
    final source = File(
      'lib/features/reports/presentation/screens/reports_analytics_screen/reports_analytics_screen.dart',
    ).readAsStringSync();

    expect(source, isNot(contains("className: 'Class 5A'")));
    expect(source, isNot(contains("month: 'April 2025'")));
    expect(source, contains('generateStructuredReport'));
    expect(source, contains("'/attendance/reports/exports'"));
    expect(source, contains("reportType: 'attendance'"));
    expect(source, contains("'/fees/reports/exports'"));
    expect(source, contains("reportType: 'complete_fees_report'"));
    expect(source, contains('final isAttendanceReport = lower.contains'));
    expect(source, contains('_invoiceBalance(invoice)'));
    expect(source, contains('Semantics('));
    expect(source, contains('Retry loading reports'));
    expect(source, isNot(contains('/ 3')));
    expect(source, isNot(contains('Public School · Academic Year 2025–26')));
  });
}
