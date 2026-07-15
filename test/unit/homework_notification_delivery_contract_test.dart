import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('homework assignments and submissions persist routed in-app and push data', () {
    final homework = File(
      'supabase/functions/api/handlers/homework.ts',
    ).readAsStringSync();
    final processor = File(
      'supabase/functions/notification-processor/index.ts',
    ).readAsStringSync();
    final resolver = File(
      'lib/core/services/notification_route_resolver.dart',
    ).readAsStringSync();

    expect(homework, contains('teacherUserIdForStaff'));
    expect(homework, contains('homework_assigned'));
    expect(homework, contains('homework_submitted'));
    expect(homework, contains('route: "/parent-homework-screen/submit"'));
    expect(
      homework,
      contains('route: "/teacher-homework-screen/submissions"'),
    );
    expect(homework, contains('triggerPushProcessing'));
    expect(processor, contains('reference_id: String(eventData.reference_id'));
    expect(processor, contains('action: "submission"'));
    expect(resolver, contains("data['homework_id']"));
  });

  test('homework in-app rows use the real notification schema', () {
    final homework = File(
      'supabase/functions/api/handlers/homework.ts',
    ).readAsStringSync();

    final assignmentLog = homework.substring(
      homework.indexOf('const notifications ='),
      homework.indexOf('// Also queue FCM pushes'),
    );
    final submissionLog = homework.substring(
      homework.indexOf('const notifBase ='),
      homework.indexOf('// Create push notification event for the teacher'),
    );
    final feedbackLog = homework.substring(
      homework.indexOf('const parentNotifs ='),
      homework.indexOf('// Create push notification events for each parent'),
    );

    for (final log in [assignmentLog, submissionLog, feedbackLog]) {
      expect(log, isNot(contains('reference_type:')));
      expect(log, isNot(contains('reference_id:')));
      expect(log, isNot(contains('action:')));
    }
  });

  test('homework keeps parent comments and teacher feedback separate', () {
    final homework = File(
      'supabase/functions/api/handlers/homework.ts',
    ).readAsStringSync();
    final parent = File(
      'lib/features/homework/presentation/screens/parent_homework_screen/'
      'parent_homework_submission_screen.dart',
    ).readAsStringSync();
    final teacher = File(
      'lib/features/homework/presentation/screens/teacher_homework_screen/'
      'teacher_homework_form_screens.dart',
    ).readAsStringSync();
    final migration = File(
      'supabase/migrations/20260714182130_preserve_homework_comments.sql',
    ).readAsStringSync();

    expect(homework, contains('parent_comment: text(body.answer_text)'));
    expect(homework, contains('teacher_feedback: reviewRemarks'));
    expect(parent, contains('Your Submitted Comment'));
    expect(parent, contains('_teacherFeedback'));
    expect(teacher, contains('void addUnique(String url)'));
    expect(migration, contains('add column if not exists parent_comment text'));
    expect(migration, contains('add column if not exists teacher_feedback text'));
  });
}
