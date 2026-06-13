import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('push notification runtime readiness is visible and retryable', () {
    final service = File(
      'lib/core/services/push_notification_service.dart',
    ).readAsStringSync();
    final center = File(
      'lib/features/communication/presentation/screens/notification_center_screen/notification_center_screen.dart',
    ).readAsStringSync();

    expect(service, contains('PushNotificationRuntimeStatus'));
    expect(service, contains('runtimeStatus'));
    expect(service, contains('lastRegistrationError'));
    expect(service, contains('registerDeviceTokenIfPossible()'));
    expect(center, contains('PushNotificationService.instance.runtimeStatus'));
    expect(center, contains('Enable Push'));
    expect(center, contains('registerDeviceTokenIfPossible()'));
  });
}
