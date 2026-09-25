import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:schooldesk1/core/config/env_config.dart';

void main() {
  test('non-Supabase backend URLs fall back to Supabase runtime', () {
    expect(
      EnvConfig.v1BaseUrlFrom('http://127.0.0.1:8080/api'),
      'http://127.0.0.1:8080/api',
    );
    expect(
      EnvConfig.v1BaseUrlFrom('https://api.schooldesk.example/api'),
      'https://api.schooldesk.example/api',
    );
  });

  test('local Supabase URLs are allowed for offline QA runs', () {
    expect(
      EnvConfig.v1BaseUrlFrom('http://127.0.0.1:54321'),
      'http://127.0.0.1:54321/functions/v1/api',
    );
    expect(
      EnvConfig.v1BaseUrlFrom('http://localhost:54321/functions/v1/api'),
      'http://localhost:54321/functions/v1/api',
    );
  });

  test('asset origin strips Supabase Edge function suffix', () {
    expect(
      EnvConfig.apiOriginFromBaseUrl(
        'https://qzdhymlabzqjeocetqqv.supabase.co/functions/v1/api',
      ),
      'https://qzdhymlabzqjeocetqqv.supabase.co',
    );
  });

  test('release builds default to the Supabase backend without build args', () {
    final source = File('lib/core/config/env_config.dart').readAsStringSync();

    expect(
      source,
      isNot(
        contains('https://qzdhymlabzqjeocetqqv.supabase.co/functions/v1/api'),
      ),
    );
    expect(
      source,
      isNot(
        contains('https://ouvwogguttybmpgfgctc.supabase.co/functions/v1/api'),
      ),
    );
    expect(
      () => EnvConfig.validate(isRelease: true),
      throwsA(isA<Exception>()),
    );
  });

  test(
    'plain flutter run defaults to Supabase with operation logs enabled',
    () {
      final mainSource = File('lib/main.dart').readAsStringSync();

      expect(EnvConfig.apiBaseUrl, '');
      expect(EnvConfig.enableLogging, isTrue);
      expect(mainSource, contains('Backend attached'));
    },
  );

  test('Codemagic debug APK is explicitly attached to Supabase backend', () {
    final codemagic = File('codemagic.yaml').readAsStringSync();

    expect(codemagic, contains('flutter build apk --debug'));
    expect(codemagic, contains(r'--dart-define=API_BASE_URL=$API_BASE_URL'));
    expect(codemagic, contains('- schooldesk_prod'));
    expect(codemagic, contains('--dart-define=APP_ENV=production'));
    expect(codemagic, contains('--dart-define=ENABLE_LOGGING=false'));
    expect(codemagic, isNot(contains('env.railway.json')));
    expect(codemagic, isNot(contains('docker')));
  });

  test('release Android helper always builds artifacts against Supabase', () {
    final script = File('scripts/build-android-supabase.sh');
    final readme = File('README.md').readAsStringSync();
    final example = File('env.supabase.example.json');

    expect(script.existsSync(), isTrue);
    expect(example.existsSync(), isTrue);

    final source = script.readAsStringSync();
    expect(source, contains('env.supabase.json'));
    expect(source, contains(r'--dart-define-from-file="$env_file"'));
    expect(source, contains('flutter build apk --release'));
    expect(source, contains('flutter build appbundle --release'));
    expect(source, contains('aab|abb'));
    expect(source, contains('jq -e'));
    expect(source, contains('API_BASE_URL'));
    expect(
      source,
      contains(r'test("^https://.+\\.supabase\\.co/functions/v1/api$")'),
    );
    expect(source, contains('SUPABASE_URL'));
    expect(source, contains('SUPABASE_ANON_KEY'));

    expect(readme, contains('Supabase Edge backend'));
    expect(readme, contains('API_BASE_URL'));
    expect(readme, isNot(contains('flutter build apk --release\n')));
  });

  test('Xcode builds receive the generated production Dart defines', () {
    final project = File(
      'ios/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();
    final debugConfig = File('ios/Flutter/Debug.xcconfig').readAsStringSync();
    final releaseConfig = File(
      'ios/Flutter/Release.xcconfig',
    ).readAsStringSync();
    final generator = File('tool/generate_dart_defines.py').readAsStringSync();

    // A target-level DART_DEFINES value overrides the base xcconfig. Keeping
    // it out of Runner lets both Debug and Release use the generated values.
    expect(project, isNot(contains('DART_DEFINES =')));
    expect(debugConfig, contains('DartDefines.xcconfig'));
    expect(releaseConfig, contains('DartDefines.xcconfig'));
    expect(generator, contains('env.supabase.json'));
  });
}
