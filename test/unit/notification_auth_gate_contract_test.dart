import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('notification service does not load before authentication', () {
    final source = File(
      'lib/core/services/notification_service.dart',
    ).readAsStringSync();

    expect(source, contains('if (!_instance!._api.isAuthenticated)'));
    expect(source, contains('unloaded so the first authenticated shell'));
  });
}
