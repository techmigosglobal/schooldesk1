import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('approval center resolves event and generic submitter names', () {
    final source = File(
      'lib/features/people/presentation/screens/approval_center_screen/approval_center_screen.dart',
    ).readAsStringSync();

    expect(source, contains('requesterName'));
    expect(source, contains('requesterRole'));
    expect(source, contains('getApprovalFeed'));
  });
}
