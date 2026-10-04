import 'package:flutter_test/flutter_test.dart';

import 'package:schooldesk1/core/config/env_config.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/network/schooldesk_api.dart';

void main() {
  test(
    'Supabase gateway headers are present when an anon key is configured',
    () {
      final expected = EnvConfig.supabaseAnonKey.isEmpty
          ? <String, String>{}
          : <String, String>{
              'apikey': EnvConfig.supabaseAnonKey,
              'Authorization': 'Bearer ${EnvConfig.supabaseAnonKey}',
            };

      expect(EnvConfig.supabaseGatewayHeaders, expected);
      final transports = [
        BackendApiClient.instance.dio.options.headers,
        SchoolDeskApi.instance.dio.options.headers,
      ];
      for (final headers in transports) {
        if (expected.isEmpty) {
          expect(headers, isNot(contains('apikey')));
          expect(headers, isNot(contains('Authorization')));
        } else {
          expect(headers, containsPair('apikey', expected['apikey']));
          expect(
            headers,
            containsPair('Authorization', expected['Authorization']),
          );
        }
      }
    },
  );
}
