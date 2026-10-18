import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'homework assignments and submissions persist routed in-app and push data',
    () {
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
      expect(
        processor,
        contains('reference_id: String(eventData.reference_id'),
      );
      expect(processor, contains('action: "submission"'));
      expect(resolver, contains("data['homework_id']"));
    },
  );

  test('homework in-app rows use the real notification schema', () {
    final homework = File(
      'supabase/functions/api/handlers/homework.ts',
    ).readAsStringSync();

    final migration = File(
      'supabase/migrations/20261016171021_role_workflow_delivery_repairs.sql',
    ).readAsStringSync();
    expect(homework, contains('wakeWorkflowDelivery'));
    expect(migration, contains('insert into public.notification_logs'));
    expect(migration, contains("'high',false"));
    expect(migration, contains('on conflict(user_id,entity_type,entity_id)'));
    expect(migration, contains('insert into public.notification_events'));
    expect(migration, contains('schooldesk_workflow_notice'));
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
    expect(
      migration,
      contains('add column if not exists teacher_feedback text'),
    );
  });

  test(
    'teacher completes review with required feedback and parent push metadata',
    () {
      final homework = File(
        'supabase/functions/api/handlers/homework.ts',
      ).readAsStringSync();
      final teacher = File(
        'lib/features/homework/presentation/screens/teacher_homework_screen/'
        'teacher_homework_form_screens.dart',
      ).readAsStringSync();
      final feedbackSection = teacher.substring(
        teacher.indexOf('class TeacherHomeworkSubmissionsScreen'),
      );

      expect(feedbackSection, contains("label: 'Done'"));
      expect(feedbackSection, isNot(contains("label: 'Approve'")));
      expect(feedbackSection, isNot(contains("label: 'Needs Revision'")));
      expect(feedbackSection, isNot(contains("label: 'Re-review'")));
      expect(feedbackSection, contains('Feedback for the parent is required'));
      expect(feedbackSection, contains("status: 'reviewed'"));
      expect(feedbackSection, contains('Feedback is required.'));
      expect(
        homework,
        contains('feedback is required before marking the dairy done'),
      );
      expect(
        File(
          'supabase/migrations/20261016171021_role_workflow_delivery_repairs.sql',
        ).readAsStringSync(),
        contains("'homework_feedback'"),
      );
      expect(homework, contains('priority: "high"'));
    },
  );
}
