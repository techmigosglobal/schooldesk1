import 'dart:io';

String readBackendRouteSources() {
  final routeFiles =
      Directory('school-backend/internal/routes')
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.go'))
          .map((file) => file.path)
          .toList()
        ..sort();
  return [
    'school-backend/main.go',
    ...routeFiles,
  ].map((path) => File(path).readAsStringSync()).join('\n');
}
