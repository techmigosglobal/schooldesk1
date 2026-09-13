import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'guardian directory resolves linked children from flattened or nested rows',
    () {
      final directory = File(
        'lib/features/people/presentation/screens/guardian_directory_screen/guardian_directory_screen.dart',
      ).readAsStringSync();
      final parentHandler = File(
        'supabase/functions/api/handlers/uploads.ts',
      ).readAsStringSync();

      expect(directory, contains("row['linked_students']"));
      expect(directory, contains("student['student_id']"));
      expect(directory, contains("student['admission_number']"));
      expect(directory, contains('linkedStudents'));
      expect(parentHandler, contains('student_id, student:students('));
      expect(parentHandler, contains('student_admission_number'));
      expect(parentHandler, contains('canManageParentLinks'));
    },
  );

  test('principal can manage every school post from the gallery and manager', () {
    final api = File(
      'lib/core/network/api_modules/events_api.dart',
    ).readAsStringSync();
    final gallery = File(
      'lib/features/shared/presentation/screens/school_gallery_screen.dart',
    ).readAsStringSync();
    final manager = File(
      'lib/features/communication/presentation/screens/principal_event_approval_screen.dart',
    ).readAsStringSync();
    final handler = File(
      'supabase/functions/api/handlers/uploads.ts',
    ).readAsStringSync();

    expect(api, contains('getPrincipalEventPosts'));
    expect(gallery, contains('Manage posts'));
    expect(gallery, contains('Edit post'));
    expect(gallery, contains('Delete post'));
    expect(manager, contains('getPrincipalEventPosts()'));
    expect(manager, contains('All school posts'));
    expect(manager, contains('Future<void> _deletePost'));
    expect(handler, contains('roleValue(user)'));
    expect(handler, contains('canManageParentLinks'));
    expect(handler, contains('if (!seg && method === "GET")'));
  });
}
