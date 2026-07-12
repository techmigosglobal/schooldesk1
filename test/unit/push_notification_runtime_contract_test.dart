import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'push notification runtime readiness is visible without a manual button',
    () {
      final service = File(
        'lib/core/services/push_notification_service.dart',
      ).readAsStringSync();
      final communicationsApi = File(
        'lib/core/network/api_modules/communications_api.dart',
      ).readAsStringSync();
      final center = File(
        'lib/features/communication/presentation/screens/notification_center_screen/notification_center_screen.dart',
      ).readAsStringSync();

      expect(service, contains('PushNotificationRuntimeStatus'));
      expect(service, contains('runtimeStatus'));
      expect(service, contains('lastRegistrationError'));
      expect(service, contains('deviceTokenPreview'));
      expect(service, contains('registerDeviceTokenIfPossible()'));
      expect(service, contains('_requestAndroidNotificationPermission'));
      expect(service, contains('requestNotificationsPermission()'));
      expect(service, contains('areNotificationsEnabled()'));
      expect(
        center,
        contains('PushNotificationService.instance.runtimeStatus'),
      );
      expect(center, contains("label: 'Push'"));
      expect(center, isNot(contains('Push Ready')));
      expect(center, isNot(contains('Enable Push')));
      expect(center, contains('Test Push'));
      expect(center, contains('_PushDiagnosticsSheet'));
      expect(communicationsApi, contains("'/notifications/register-token'"));
      expect(communicationsApi, contains("'/notifications/push-diagnostics'"));
      expect(communicationsApi, contains("'fcm_token': token"));
      expect(communicationsApi, contains("'/notifications/revoke-token'"));
    },
  );

  test('permission recovery covers camera, media, and notifications', () {
    final coordinator = File(
      'lib/core/services/app_permission_coordinator.dart',
    ).readAsStringSync();
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(coordinator, contains('Permission.notification'));
    expect(coordinator, contains('Permission.camera'));
    expect(coordinator, contains('Permission.photos'));
    expect(coordinator, contains('Permission.videos'));
    expect(coordinator, contains('AppLifecycleState.resumed'));
    expect(coordinator, contains('openAppSettings()'));
    expect(plist, contains('NSPhotoLibraryUsageDescription'));
    expect(manifest, contains('android.permission.READ_MEDIA_IMAGES'));
    expect(manifest, contains('android.permission.READ_MEDIA_VIDEO'));
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
