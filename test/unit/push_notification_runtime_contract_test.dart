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
    expect(service, contains('_requestAndroidNotificationPermission'));
    expect(service, contains('requestNotificationsPermission()'));
    expect(service, contains('areNotificationsEnabled()'));
    expect(center, contains('PushNotificationService.instance.runtimeStatus'));
    expect(center, contains('Enable Push'));
    expect(center, contains('registerDeviceTokenIfPossible()'));
  });

  test('android push notifications are bound to the Firebase Android app', () {
    final firebaseRc = File('.firebaserc').readAsStringSync();
    final firebaseJson = File('firebase.json').readAsStringSync();
    final googleServices = File(
      'android/app/google-services.json',
    ).readAsStringSync();
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();

    expect(firebaseRc, contains('"default": "schooldesk1-509e0"'));
    expect(firebaseJson.trim(), '{}');
    expect(googleServices, contains('"project_id": "schooldesk1-509e0"'));
    expect(
      googleServices,
      contains('"package_name": "com.techmigos.schooldesk1"'),
    );
    expect(manifest, contains('android.permission.POST_NOTIFICATIONS'));
    expect(
      manifest,
      contains('com.google.firebase.messaging.default_notification_channel_id'),
    );
    expect(gradle, contains('com.google.gms.google-services'));
  });
}
