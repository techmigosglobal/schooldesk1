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
}
