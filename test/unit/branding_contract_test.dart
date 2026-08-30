import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Arish Ville branding is wired across the public landing and app metadata',
    () {
      final landing = File(
        'lib/features/shell/presentation/screens/landing_page_screen/landing_page_screen.dart',
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

      for (final source in [landing]) {
        expect(
          source.contains('Arish Ville Preschool') ||
              source.contains('AppConstants.schoolName'),
          isTrue,
          reason:
              'Should contain Arish Ville Preschool brand name or reference',
        );
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
      expect(landing, isNot(contains('Powered by Arish Ville')));
      expect(
        main.contains("title: 'Arish Ville Preschool'") ||
            main.contains("title: AppConstants.schoolName"),
        isTrue,
        reason:
            'main.dart should set app title to Arish Ville brand name or constant',
      );
      expect(webIndex, contains('<title>Arish Ville Preschool</title>'));
      expect(webManifest, contains('"name": "Arish Ville Preschool"'));
      expect(webManifest, contains('"short_name": "Arish Ville"'));
      expect(androidManifest, contains('android:label="Arish Ville"'));
      expect(iosInfo, contains('<string>Arish Ville</string>'));
      expect(pubspec, contains('name: schooldesk1'));
    },
  );

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
    expect(android12Style, contains('@drawable/transparent_splash_icon'));
  });
}

({int width, int height}) _pngSize(File file) {
  final bytes = file.readAsBytesSync();
  expect(bytes.length, greaterThanOrEqualTo(24), reason: file.path);
  expect(bytes.take(8).toList(), [137, 80, 78, 71, 13, 10, 26, 10]);
  final data = ByteData.sublistView(Uint8List.fromList(bytes));
  return (width: data.getUint32(16), height: data.getUint32(20));
}
