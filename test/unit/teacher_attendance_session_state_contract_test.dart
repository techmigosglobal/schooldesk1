import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('attendance session list includes saved student statuses', () {
    final source = File(
      'supabase/functions/api/handlers/attendance.ts',
    ).readAsStringSync();

    expect(
      source,
      contains(
        'student_attendances(student_id, enrollment_id, status, reason, remarks, marked_at)',
      ),
    );

    final model = File(
      'lib/core/network/models/backend_models.dart',
    ).readAsStringSync();
    expect(model, contains("isFinalized && rawStatus == 'draft'"));
  });

  test(
    'local attendance fixture leaves today available for teacher marking',
    () {
      final seed = File('supabase/seed.sql').readAsStringSync();

      expect(seed, contains('current_date - 1'));
    },
  );
}
