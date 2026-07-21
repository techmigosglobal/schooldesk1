import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Android release builds optimize code and can resolve clean dependencies',
    () {
      final releaseConfig = File(
        'android/app/build.gradle.kts',
      ).readAsStringSync();
      final gradleProperties = File(
        'android/gradle.properties',
      ).readAsStringSync();
      final releaseScript = File(
        'scripts/build-android-supabase.sh',
      ).readAsStringSync();
      final codemagic = File('codemagic.yaml').readAsStringSync();

      expect(releaseConfig, contains('isMinifyEnabled = true'));
      expect(releaseConfig, contains('isShrinkResources = true'));
      expect(gradleProperties, contains('org.gradle.offline=false'));
      expect(releaseScript, contains('--obfuscate'));
      expect(releaseScript, contains('--split-debug-info'));
      expect(codemagic, contains('--obfuscate'));
      expect(codemagic, contains('--split-debug-info'));
    },
  );

  test('native permissions match the supported mobile features', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final plist = File('ios/Runner/Info.plist').readAsStringSync();

    expect(manifest, contains('android.permission.INTERNET'));
    expect(manifest, contains('android.permission.CAMERA'));
    expect(manifest, contains('android.permission.POST_NOTIFICATIONS'));
    expect(manifest, contains('@style/Ucrop.CropTheme'));
    expect(plist, contains('NSCameraUsageDescription'));
    expect(plist, contains('NSPhotoLibraryUsageDescription'));
    expect(plist, contains('remote-notification'));
    expect(
      File('android/app/proguard-rules.pro').readAsStringSync(),
      contains('-dontwarn okhttp3.**'),
    );
  });

  test('iOS uses Flutter Swift Packages rather than an unused Podfile', () {
    final project = File(
      'ios/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();

    expect(project, contains('FlutterGeneratedPluginSwiftPackage'));
    expect(project, contains('XCLocalSwiftPackageReference'));
    expect(File('ios/Podfile').existsSync(), isFalse);
  });
}
