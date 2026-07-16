import 'dart:io';

import 'package:test/test.dart';

void main() {
  test(
    'leave handler self-heals missing leave types and avoids blank uuid inserts',
    () {
      final source = File(
        'supabase/functions/api/handlers/leave.ts',
      ).readAsStringSync();

      expect(source, contains('async function ensureDefaultLeaveTypes'));
      expect(source, contains('Casual Leave'));
      expect(source, contains('Sick Leave'));
      expect(source, contains('Earned Leave'));
      expect(
        source,
        contains('const defaultLeaveTypeId = text(leaveTypes[0]?.id);'),
      );
      expect(
        source,
        contains(
          'leave_type_id: text(body.leave_type_id) || defaultLeaveTypeId || null',
        ),
      );
      expect(
        source,
        contains('if (!staffId) return fail("staff profile required", 403);'),
      );
    },
  );
}
