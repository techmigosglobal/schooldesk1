import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Academic Year exports use the scoped landscape report renderer for every requested type',
    () {
      final handler = File(
        'supabase/functions/api/handlers/uploads.ts',
      ).readAsStringSync();

      expect(handler, contains('performStructuredReportExport'));
      expect(handler, contains('usesStructuredAcademicExport'));
      for (final reportType in [
        'class_summary',
        'students_list',
        'subjects_mapping',
        'teacher_mapping',
        'timetable_summary',
        'complete_classwise_data',
        'users_wise_export',
        'fee_structure',
        'student_fee_invoices',
        'paid_fees',
        'pending_fees',
        'due_fees',
        'complete_fees_report',
      ]) {
        expect(handler, contains('"$reportType"'));
      }

      expect(handler, contains('Academic year: '));
      expect(handler, contains('schoolProfile'));
      expect(handler, contains('pageWidth = 842'));
      expect(handler, contains('Confidential school record'));
      expect(handler, contains('Page '));
      expect(handler, contains('No records match the selected report scope.'));
      expect(handler, contains('query = query.in("role_name", roles)'));
      expect(handler, contains('query = query.eq("is_active"'));
      expect(handler, contains('value(parameters.academic_year_id)'));
      expect(handler, contains('value(parameters.grade_id)'));
      expect(handler, contains('value(parameters.section_id)'));
      expect(handler, contains('currency(totalBilled)'));
      expect(handler, contains('currency(totalPaid)'));
      expect(handler, contains('currency(totalBalance)'));
      expect(
        handler,
        contains(
          '[classSummary, studentList, subjectsMap, teacherMap, timetableSummary]',
        ),
      );
    },
  );

  test('observation workflows have no reachable client or server surface', () {
    final routes = File('lib/routes/app_routes.dart').readAsStringSync();
    final navigation = File(
      'lib/core/widgets/teacher_navigation.dart',
    ).readAsStringSync();
    final classHub = File(
      'lib/features/academics/presentation/screens/principal_classes_screen/principal_classes_screen.dart',
    ).readAsStringSync();
    final client = File(
      'lib/core/network/api_modules/principal_api.dart',
    ).readAsStringSync();
    final handler = File(
      'supabase/functions/api/handlers/principal.ts',
    ).readAsStringSync();

    expect(routes, isNot(contains('teacherStudentNotes')));
    expect(navigation, isNot(contains('Student Notes')));
    expect(classHub, isNot(contains('Send observation')));
    expect(classHub, isNot(contains('Latest Instruction')));
    expect(client, isNot(contains('createPrincipalClassInstruction')));
    expect(handler, isNot(contains('/instructions')));
    expect(
      File(
        'lib/features/academics/presentation/screens/teacher_student_notes_screen/teacher_student_notes_screen.dart',
      ).existsSync(),
      isFalse,
    );
  });

  test(
    'parent language and directory header visibility follow the product request',
    () {
      final parents = File(
        'lib/features/people/presentation/screens/guardian_directory_screen/guardian_directory_screen.dart',
      ).readAsStringSync();
      final students = File(
        'lib/features/people/presentation/screens/student_oversight_screen/student_oversight_screen.dart',
      ).readAsStringSync();
      final staff = File(
        'lib/features/people/presentation/screens/staff_management_screen/staff_management_screen.dart',
      ).readAsStringSync();

      expect(parents, contains('All Parents Directory'));
      expect(parents, contains('return \'Parent\';'));
      expect(parents, contains('Upload parents CSV'));
      expect(parents, contains('Temporarily hidden at product request'));
      expect(students, contains('Parent Phone'));
      expect(students, contains('student CSV/PDF'));
      expect(staff, contains('Temporarily hidden at product request'));
    },
  );
}
