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
}
