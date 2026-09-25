import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'academic-year detail exposes summary and no academic-year export routes',
    () {
      final screen = File(
        'lib/features/academics/presentation/screens/academic_management_screen/principal_academic_years_screen.dart',
      ).readAsStringSync();
      final routes = File('lib/routes/app_routes.dart').readAsStringSync();
      final api = File(
        'lib/core/network/api_modules/school_api.dart',
      ).readAsStringSync();

      expect(screen, contains('_repository.loadAcademicYearSummary'));
      expect(screen, contains('active_student_count'));
      expect(screen, contains('fee_structure_names'));
      expect(
        screen,
        isNot(contains("Create an academic year to enable exports.")),
      );
      expect(routes, isNot(contains('academicYearClasswiseExport')));
      expect(routes, isNot(contains('academicYearUsersExport')));
      expect(routes, isNot(contains('academicYearFeesExport')));
      expect(api, contains("'/academic-years/\$academicYearId/summary'"));
    },
  );

  test(
    'student directory counts are server-backed and parent links are validated',
    () {
      final screen = File(
        'lib/features/people/presentation/screens/student_oversight_screen/student_oversight_screen.dart',
      ).readAsStringSync();
      final api = File(
        'lib/core/network/api_modules/students_api.dart',
      ).readAsStringSync();
      final handler = File(
        'supabase/functions/api/handlers/students.ts',
      ).readAsStringSync();

      expect(screen, contains('All Students (\$_activeStudentTotal)'));
      expect(screen, contains('_activeStudentsBySection'));
      expect(screen, contains('_countForClass'));
      expect(api, contains("_get('/students/summary')"));
      expect(handler, contains('active_students_by_section'));
      expect(handler, contains('validateStudentSection'));
      expect(handler, contains('validateParentAccount'));
      expect(handler, contains('ensureStudentIdentifiersAvailable'));
      expect(handler, contains('student identifiers must be unique'));
      expect(handler, contains('ilike("role_name", "parent")'));
      expect(handler, contains('eq("is_active", true)'));
      expect(handler, contains('onConflict: "parent_user_id,student_id"'));
      expect(
        handler,
        contains('active students must have an active parent login'),
      );
    },
  );

  test('teacher assignment scope and daily claims are server-enforced', () {
    final academics = File(
      'supabase/functions/api/handlers/academics.ts',
    ).readAsStringSync();
    final claims = File(
      'supabase/functions/api/handlers/daily_claims.ts',
    ).readAsStringSync();
    final attendance = File(
      'supabase/functions/api/handlers/attendance.ts',
    ).readAsStringSync();
    final homework = File(
      'supabase/functions/api/handlers/homework.ts',
    ).readAsStringSync();
    final migration = File(
      'supabase/migrations/20260813100000_principal_workflow_hardening.sql',
    ).readAsStringSync();
    final staff = File(
      'lib/features/people/presentation/screens/staff_management_screen/staff_management_screen.dart',
    ).readAsStringSync();

    expect(academics, contains('class_teacher_id'));
    expect(academics, contains('co_teacher_id'));
    expect(
      academics,
      contains('class teacher and co-teacher must be different staff members'),
    );
    expect(
      File('supabase/functions/api/handlers/principal.ts').readAsStringSync(),
      contains('an operational class requires a class teacher'),
    );
    expect(claims, contains('class_daily_operation_claims'));
    expect(claims, contains('teacherCanUseSection'));
    expect(claims, contains('status: "reopened"'));
    expect(attendance, contains('claimDailyOperation'));
    expect(attendance, contains('daily_claim'));
    expect(homework, contains('claimDailyOperation'));
    expect(homework, contains('teacherCanUseSection'));
    expect(homework, contains('daily_claim'));
    expect(
      migration,
      contains(
        'unique (school_id, academic_year_id, section_id, operation, operation_date)',
      ),
    );
    expect(migration, contains('uq_academic_years_one_current_per_school'));
    expect(staff, contains("assignmentRole: 'co_teacher'"));
    expect(staff, contains("assignment_role"));
  });
}
