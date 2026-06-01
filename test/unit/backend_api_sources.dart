import 'dart:io';

String readBackendApiSources() {
  final moduleFiles =
      Directory('lib/core/network/api_modules')
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  final files = [
    File('lib/core/network/backend_api_client.dart'),
    File('lib/features/shared/data/models/backend_models.dart'),
    ...moduleFiles,
  ];

  return files.map((file) => file.readAsStringSync()).join('\n');
}
