import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:schooldesk1/core/services/notification_service.dart';

void main() {
  test('birthday notification preserves the student profile photo URL', () {
    final notification = AppNotification.fromJson({
      'id': 'birthday-1',
      'title': 'Birthday Today',
      'body': 'Today we celebrate Tharun Kumar.',
      'type': 'birthday',
      'target_role': 'principal',
      'student_id': 'student-1',
      'student_photo_url': 'https://example.test/student.jpg',
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });

    expect(notification.studentId, 'student-1');
    expect(notification.studentPhotoUrl, 'https://example.test/student.jpg');
  });

  test('birthday highlight uses a medium photo and cake error fallback', () {
    final highlights = File(
      'lib/features/dashboard/presentation/widgets/todays_highlights_card.dart',
    ).readAsStringSync();
    final communications = File(
      'supabase/functions/api/handlers/communications.ts',
    ).readAsStringSync();
    final birthdayJob = File(
      'supabase/functions/api/handlers/birthday_alerts.ts',
    ).readAsStringSync();

    expect(highlights, contains("dimension: 62"));
    expect(highlights, contains("width: 56"));
    expect(highlights, contains("Image.network("));
    expect(highlights, contains("fit: BoxFit.cover"));
    expect(highlights, contains("errorBuilder:"));
    expect(highlights, contains("ValueKey('birthday-cake-\$identity')"));
    expect(highlights, contains("Icons.cake_rounded"));
    expect(highlights, contains("if (acknowledged)"));

    expect(
      communications,
      contains('.select("*, student:students(photo_url)")'),
    );
    expect(communications, contains('student_photo_url:'));
    expect(birthdayJob, contains('student_id: group.students.length === 1'));
  });
}
