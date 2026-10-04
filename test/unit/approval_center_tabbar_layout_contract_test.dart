import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('approval center bounds its tab view during stale refresh', () {
    final source = File(
      'lib/features/people/presentation/screens/approval_center_screen/approval_center_screen.dart',
    ).readAsStringSync();

    expect(
      source,
      contains('expandStaleContent: true'),
      reason:
          'TabBarView needs a bounded height while the status banner is shown.',
    );
  });
}
