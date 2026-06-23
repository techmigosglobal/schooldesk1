import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ArishVille branding is wired across onboarding and app metadata', () {
    final landing = File(
      'lib/features/shell/presentation/screens/landing_page_screen/landing_page_screen.dart',
    ).readAsStringSync();
    final onboarding = File(
      'lib/features/auth/presentation/screens/onboarding_screen/onboarding_screen.dart',
    ).readAsStringSync();
    final main = File('lib/main.dart').readAsStringSync();
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final webIndex = File('web/index.html').readAsStringSync();
    final webManifest = File('web/manifest.json').readAsStringSync();
    final androidManifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final iosInfo = File('ios/Runner/Info.plist').readAsStringSync();

    for (final asset in [
      'assets/branding/ArishVilleLogo.png',
      'assets/branding/techmigos_logo.png',
    ]) {
      expect(File(asset).existsSync(), isTrue, reason: '$asset is missing');
    }

    expect(pubspec, contains('- assets/branding/'));

    for (final source in [landing, onboarding]) {
      expect(source, contains('ArishVille Preschool'));
      expect(source, contains('assets/branding/ArishVilleLogo.png'));
      expect(source, contains('assets/branding/techmigos_logo.png'));
      expect(
        source,
        isNot(contains('assets/branding/arishville_logo_light.png')),
      );
      expect(
        source,
        isNot(contains('assets/branding/arishville_logo_dark.png')),
      );
      expect(source, isNot(contains('assets/images/header.png')));
      expect(source, isNot(contains('assets/images/footer.png')));
    }
    expect(landing, contains('Learn Today, Lead Tomorrow'));
    expect(landing, isNot(contains('Powered by SchoolDesk')));
    expect(onboarding, contains('Powered by Techmigos'));

    expect(onboarding, contains('assets/branding/ArishVilleLogo.png'));
    expect(main, contains("title: 'ArishVille Preschool'"));
    expect(webIndex, contains('<title>ArishVille Preschool</title>'));
    expect(webManifest, contains('"name": "ArishVille Preschool"'));
    expect(webManifest, contains('"short_name": "ArishVille"'));
    expect(androidManifest, contains('android:label="ArishVille"'));
    expect(iosInfo, contains('<string>ArishVille</string>'));
  });

  test('Android splash logo assets are large enough for launch screens', () {
    final expectedSizes = <String, int>{
      'mipmap-mdpi': 240,
      'mipmap-hdpi': 360,
      'mipmap-xhdpi': 480,
      'mipmap-xxhdpi': 720,
      'mipmap-xxxhdpi': 960,
    };

    for (final entry in expectedSizes.entries) {
      final asset = File(
        'android/app/src/main/res/${entry.key}/launch_image.png',
      );
      expect(asset.existsSync(), isTrue, reason: '${asset.path} is missing');
      final size = _pngSize(asset);
      expect(size.width, entry.value, reason: '${asset.path} width');
      expect(size.height, entry.value, reason: '${asset.path} height');
    }

    final android12Style = File(
      'android/app/src/main/res/values-v31/styles.xml',
    ).readAsStringSync();
    expect(android12Style, contains('@mipmap/launch_image'));
  });
}

({int width, int height}) _pngSize(File file) {
  final bytes = file.readAsBytesSync();
  expect(bytes.length, greaterThanOrEqualTo(24), reason: file.path);
  expect(bytes.take(8).toList(), [137, 80, 78, 71, 13, 10, 26, 10]);
  final data = ByteData.sublistView(Uint8List.fromList(bytes));
  return (width: data.getUint32(16), height: data.getUint32(20));
}
