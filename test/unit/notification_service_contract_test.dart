import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('notification service deduplicates concurrent initial loads', () {
    final service = File(
      'lib/core/services/notification_service.dart',
    ).readAsStringSync();

    expect(service, contains('Future<void>? _loadFuture'));
    expect(
      service,
      contains('await (_instance!._loadFuture ??= _instance!._load())'),
    );
    expect(service, contains('_loadFuture = null'));
  });
}
