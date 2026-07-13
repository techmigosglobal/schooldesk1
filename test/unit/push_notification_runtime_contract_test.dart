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
      expect(service, contains('requestPermission('));
      expect(service, contains('getAPNSToken()'));
      expect(service, contains('_apnsRegistrationTimeout'));
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

  test('iOS requests only the permissions used by contextual features', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final app = File('lib/main.dart').readAsStringSync();
    final filePickerPackage = File(
      'third_party/flutter_plugins/file_picker/ios/file_picker/Package.swift',
    ).readAsStringSync();
    final paymentFlow = File(
      'lib/features/finance/presentation/screens/parent_hub/parent_payment_flow.dart',
    ).readAsStringSync();
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    // Camera and photo access are requested by the feature SDKs only when a
    // user opens the scanner or picker. Push permission is owned by Firebase.
    // Keeping the broad permission plug-in out of the iOS binary avoids
    // shipping unused location APIs and their App Store privacy requirement.
    expect(pubspec, isNot(contains('permission_handler:')));
    expect(app, isNot(contains('AppPermissionLifecycleGate')));
    expect(filePickerPackage, isNot(contains('DKImagePickerController')));
    expect(filePickerPackage, isNot(contains('PICKER_MEDIA')));
    expect(paymentFlow, contains('ImagePicker().pickImage'));
    expect(paymentFlow, isNot(contains('FileType.image')));
    expect(plist, contains('NSPhotoLibraryUsageDescription'));
    expect(plist, isNot(contains('NSPhotoLibraryAddUsageDescription')));
    expect(plist, isNot(contains('NSLocationWhenInUseUsageDescription')));
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
