import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every document role infers preview type from the uploaded file URL', () {
    const screens = [
      'lib/features/documents/presentation/screens/parent_documents_screen/parent_documents_screen.dart',
      'lib/features/documents/presentation/screens/teacher_documents_screen/teacher_documents_screen.dart',
      'lib/features/documents/presentation/screens/admin_documents_screen/admin_documents_screen.dart',
    ];

    for (final path in screens) {
      final source = File(path).readAsStringSync();
      expect(source, contains('EventPostMediaItem.fromUrl('));
      expect(source, contains('name:'));
    }
  });
}
