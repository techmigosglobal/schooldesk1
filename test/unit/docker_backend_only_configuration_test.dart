import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Flutter runtime is configured only for the Go Docker API backend', () {
    final removedBackendTerms = [
      String.fromCharCodes([80, 111, 99, 107, 101, 116, 66, 97, 115, 101]),
      String.fromCharCodes([80, 79, 67, 75, 69, 84, 66, 65, 83, 69]),
      String.fromCharCodes([65, 112, 112, 119, 114, 105, 116, 101]),
      String.fromCharCodes([65, 80, 80, 87, 82, 73, 84, 69]),
      String.fromCharCodes([97, 112, 112, 119, 114, 105, 116, 101]),
    ];
    final files = [
      'env.json',
      'pubspec.yaml',
      'lib/core/config/env_config.dart',
      'lib/core/app_export.dart',
      'lib/services/backend_api_client.dart',
    ];

    for (final path in files) {
      final contents = File(path).readAsStringSync();
      for (final term in removedBackendTerms) {
        expect(
          contents,
          isNot(contains(term)),
          reason:
              '$path should not contain removed backend runtime/config traces',
        );
      }
    }
  });
}
