import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('parent payment form keeps school request ids out of upi launch uri', () {
    final source = File(
      'lib/features/finance/presentation/screens/parent_fees_screen/parent_payment_request_form_screen.dart',
    ).readAsStringSync();

    expect(source, contains("updated.remove('tr');"));
    expect(source, contains("updated.remove('tid');"));
    expect(source, isNot(contains("params['tr']")));
  });
}
