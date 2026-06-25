import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('main module setup actions redirect to Class Hub with contract args', () {
    const files = {
      'subjects':
          'lib/features/academics/presentation/screens/principal_subjects_screen/principal_subjects_screen.dart',
      'fees':
          'lib/features/finance/presentation/screens/fee_monitoring_screen/fee_monitoring_screen.dart',
      'attendance':
          'lib/features/attendance/presentation/screens/principal_attendance_screen/principal_attendance_screen.dart',
    };

    for (final entry in files.entries) {
      final source = File(entry.value).readAsStringSync();
      expect(
        source,
        contains('AppRoutes.principalClasses'),
        reason: '${entry.key} setup edits must route to Class Hub',
      );
      for (final key in ['source', 'action', 'sectionId', 'selectedStep']) {
        expect(
          source,
          contains("'$key'"),
          reason: '${entry.key} redirect must pass $key',
        );
      }
    }

    final subjects = File(files['subjects']!).readAsStringSync();
    expect(subjects, contains("'classId'"));

    final fees = File(files['fees']!).readAsStringSync();
    expect(fees, contains("'classId'"));
  });

  test('Class Hub accepts old and new setup argument names', () {
    final source = File(
      'lib/features/academics/presentation/screens/principal_classes_screen/principal_classes_screen.dart',
    ).readAsStringSync();

    for (final key in [
      'class_hub_action',
      'action',
      'selectedStep',
      'section_id',
      'sectionId',
      'classId',
      'grade_id',
      'gradeId',
    ]) {
      expect(source, contains("'$key'"));
    }
  });

  test('teacher class hub exposes leave alongside class workflows', () {
    final source = File(
      'lib/features/academics/presentation/screens/teacher_classes_screen/teacher_classes_screen.dart',
    ).readAsStringSync();

    expect(source, isNot(contains("label: 'Homework'")));
    expect(source, isNot(contains('AppRoutes.teacherHomework')));
    expect(source, contains("label: 'Diary'"));
    expect(source, contains("label: 'Track Leave'"));
    expect(source, contains('AppRoutes.teacherLeave'));
  });
}
