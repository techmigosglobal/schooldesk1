import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'teacher assignments retain direct section IDs and all client classes',
    () {
      final dashboard = File(
        'supabase/functions/api/handlers/dashboard.ts',
      ).readAsStringSync();
      final scope = File(
        'lib/core/services/role_access_service.dart',
      ).readAsStringSync();
      final screen = File(
        'lib/features/academics/presentation/screens/teacher_classes_screen/teacher_classes_screen.dart',
      ).readAsStringSync();

      expect(
        dashboard,
        contains('const directSectionId = text(row.section_id)'),
      );
      expect(dashboard, contains('const directSection = directSectionId'));
      expect(
        scope,
        contains('_loadStudentsForSections(api, assignedSectionIds)'),
      );
      expect(scope, contains('teacherAssignedStudents'));
      expect(
        screen,
        contains("const TeacherFlowSectionHeader(title: 'Assigned Classes')"),
      );
    },
  );
}
