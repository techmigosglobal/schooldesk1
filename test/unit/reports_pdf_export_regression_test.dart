import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('principal reports PDF export does not use stale demo arguments', () {
    final source = File(
      'lib/presentation/reports_analytics_screen/reports_analytics_screen.dart',
    ).readAsStringSync();

    expect(source, isNot(contains("className: 'Class 5A'")));
    expect(source, isNot(contains("month: 'April 2025'")));
    expect(source, contains('generatePrincipalSummaryReport'));
  });
}
