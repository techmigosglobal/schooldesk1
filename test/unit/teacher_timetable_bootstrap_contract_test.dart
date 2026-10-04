import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('teacher scope reads timetable through assigned sections', () {
    final source = File(
      'lib/core/services/role_access_service.dart',
    ).readAsStringSync();
    final teacherBranch = source.substring(
      source.indexOf('final timetableFuture = isParent'),
      source.indexOf('// Coordinators have school-wide operations access'),
    );

    expect(teacherBranch, contains('staffId: isTeacher'));
    expect(
      teacherBranch,
      contains('isTeacher\n                  ? null'),
      reason: 'Teacher timetable reads must not send a rejected staff filter.',
    );
  });
}
