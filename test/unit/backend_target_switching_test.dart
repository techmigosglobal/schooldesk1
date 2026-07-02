import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:schooldesk1/core/config/env_config.dart';

void main() {
  test(
    'local and Hostinger env files make backend target switching explicit',
    () {
      final localExample = File('env.local.example.json');
      final hostingerExample = File('env.hostinger.example.json');
      final hostingerCompose = File('docker-compose.hostinger-traefik.yml');

      expect(localExample.existsSync(), isTrue);
      expect(hostingerExample.existsSync(), isTrue);
      expect(hostingerCompose.existsSync(), isTrue);

      final local = jsonDecode(localExample.readAsStringSync()) as Map;
      final hostinger = jsonDecode(hostingerExample.readAsStringSync()) as Map;

      expect(local['API_BASE_URL'], 'http://127.0.0.1:8080/api');
      expect(local['APP_ENV'], 'development');

      expect(hostinger['API_BASE_URL'], startsWith('https://'));
      expect(hostinger['API_BASE_URL'], endsWith('/api'));
      expect(hostinger['API_BASE_URL'], isNot(contains('localhost')));
      expect(hostinger['API_BASE_URL'], isNot(contains('127.0.0.1')));
      expect(hostinger['APP_ENV'], 'production');
      expect(hostinger['ENABLE_LOGGING'], 'false');

      final compose = hostingerCompose.readAsStringSync();
      expect(compose, contains('traefik.enable=true'));
      expect(compose, contains('traefik.http.routers.schooldesk-api.rule'));
      expect(compose, contains('traefik.http.services.schooldesk-api'));
    },
  );

  test('asset origin strips either compat api or v1 api suffix', () {
    expect(
      EnvConfig.apiOriginFromBaseUrl('http://127.0.0.1:8080/api'),
      'http://127.0.0.1:8080',
    );
    expect(
      EnvConfig.apiOriginFromBaseUrl('https://api.schooldesk.example/api/v1'),
      'https://api.schooldesk.example',
    );
  });

  test('release builds default to the Supabase backend without build args', () {
    final source = File('lib/core/config/env_config.dart').readAsStringSync();

    expect(
      source,
      contains('https://ouvwogguttybmpgfgctc.supabase.co/functions/v1/api'),
    );
    expect(() => EnvConfig.validate(isRelease: true), returnsNormally);
  });

  test('plain flutter run defaults to Supabase with operation logs enabled', () {
    final mainSource = File('lib/main.dart').readAsStringSync();

    expect(
      EnvConfig.apiBaseUrl,
      'https://ouvwogguttybmpgfgctc.supabase.co/functions/v1/api',
    );
    expect(EnvConfig.enableLogging, isTrue);
    expect(mainSource, contains('Backend attached'));
  });

  test('Codemagic debug APK is explicitly attached to Supabase backend', () {
    final codemagic = File('codemagic.yaml').readAsStringSync();

    expect(codemagic, contains('flutter build apk --debug'));
    expect(
      codemagic,
      contains(
        r'--dart-define=API_BASE_URL=$API_BASE_URL',
      ),
    );
    expect(
      codemagic,
      contains(
        'API_BASE_URL: https://ouvwogguttybmpgfgctc.supabase.co/functions/v1/api',
      ),
    );
    expect(codemagic, contains('--dart-define=APP_ENV=production'));
    expect(codemagic, contains('--dart-define=ENABLE_LOGGING=false'));
    expect(codemagic, isNot(contains('env.railway.json')));
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
    expect(source, contains(r'test("^https://.+\\.supabase\\.co/functions/v1/api$")'));
    expect(source, contains('SUPABASE_URL'));
    expect(source, contains('SUPABASE_ANON_KEY'));

    expect(readme, contains('scripts/build-android-supabase.sh apk'));
    expect(readme, contains('scripts/build-android-supabase.sh aab'));
    expect(readme, isNot(contains('flutter build apk --release\n')));
  });
}
