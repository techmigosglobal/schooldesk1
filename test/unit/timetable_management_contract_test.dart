import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'backend_api_sources.dart';

void main() {
  test('leadership timetable uses the two-column selected-day editor', () {
    final teacher = File(
      'lib/features/academics/presentation/screens/teacher_timetable_screen/teacher_timetable_screen.dart',
    ).readAsStringSync();
    final principal = File(
      'lib/features/academics/presentation/screens/admin_timetable_screen/admin_timetable_screen.dart',
    ).readAsStringSync();
    final api = readBackendApiSources();
    final handler = File(
      'supabase/functions/api/handlers/timetable.ts',
    ).readAsStringSync();
    final migration = File(
      'supabase/migrations/20260804100000_add_timetable_day_replace.sql',
    ).readAsStringSync();
    final navigation = File(
      'lib/core/widgets/app_navigation.dart',
    ).readAsStringSync();
    final gateway = File('supabase/functions/api/index.ts').readAsStringSync();

    expect(
      teacher,
      contains('Read-only schedule from Principal timetable setup'),
    );
    expect(teacher, contains('_loadTeacherTimetableSlots'));
    expect(teacher, contains('getTimetableSlots(sectionId: sectionId)'));
    expect(teacher, contains('_loadWorkingDays'));
    expect(teacher, contains('_selectedDaySlots'));
    expect(teacher, contains('scrollDirection: Axis.horizontal'));
    expect(teacher, contains(r'No classes scheduled for $dayName.'));
    expect(teacher, isNot(contains('List.generate(7')));
    expect(teacher, contains('Select class'));
    expect(
      teacher,
      isNot(contains('staffId: RoleAccessService.teacherStaffId')),
    );
    expect(teacher, isNot(contains('staffScopedSlots')));

    expect(principal, contains('Timetable Management'));
    expect(principal, contains('Select class to continue'));
    expect(principal, contains('Timetable rows'));
    expect(principal, contains('From'));
    expect(principal, contains('To'));
    expect(principal, contains('Free Period'));
    expect(principal, contains('List.generate(3'));
    expect(principal, contains('_selectedDays'));
    expect(principal, contains('_validateRows'));
    expect(principal, contains('_subjectOptionsForSelectedClass'));
    expect(principal, contains('replaceTimetableDays'));
    expect(principal, isNot(contains('generateSmartTimetable(')));
    expect(principal, isNot(contains('Week-wise Timetable')));
    expect(principal, isNot(contains('_TimetableBreakDraft')));

    expect(api, contains('replaceTimetableDays'));
    expect(api, contains("'/timetable/slots/replace-days'"));
    expect(handler, contains('path === "/timetable/slots/replace-days"'));
    expect(handler, contains('sectionSubjectIds'));
    expect(handler, contains('validateTemplateRows'));
    expect(handler, contains('replace_timetable_days'));
    expect(handler, contains('/timetable/working-days'));
    expect(handler, contains('scope.sectionIds.has'));
    expect(handler, contains('staff_id'));
    expect(
      migration,
      contains('create or replace function public.replace_timetable_days'),
    );
    expect(migration, contains('delete from public.timetable_slots'));
    expect(migration, contains('jsonb_array_elements(p_rows)'));
    expect(navigation, contains('route: AppRoutes.principalTimetable'));
    expect(gateway, contains('x-schooldesk-branch-id'));
    expect(gateway, contains('branch_memberships'));
    expect(gateway, contains('currentRole === "coordinator"'));
    expect(gateway, contains('requestedBranch === profile.school_id'));
  });

  test('class subjects are restricted to mapped grade-year subjects', () {
    final flutter = File(
      'lib/features/academics/presentation/screens/admin_timetable_screen/admin_timetable_screen.dart',
    ).readAsStringSync();
    final web = File(
      'schooldesk-web/components/portal/TimetableWorkspace.tsx',
    ).readAsStringSync();
    final handler = File(
      'supabase/functions/api/handlers/timetable.ts',
    ).readAsStringSync();

    expect(flutter, contains("'/grade-subjects'"));
    expect(flutter, contains('mappingYear.isEmpty || mappingYear == yearId'));
    expect(web, contains('refs.gradeSubjects'));
    expect(web, contains('academicYearId'));
    expect(web, contains('Choose a subject mapped to this class'));
    expect(handler, contains('academic_year_id'));
    expect(
      handler,
      contains('every selected subject must be mapped to this class'),
    );
  });

  test('parent timetable retains child-scoped read visibility', () {
    final parent = File(
      'lib/features/academics/presentation/screens/parent_timetable_screen/parent_timetable_screen.dart',
    ).readAsStringSync();
    final handler = File(
      'supabase/functions/api/handlers/timetable.ts',
    ).readAsStringSync();

    expect(parent, contains('selected: isActive'));
    expect(parent, contains(r"hint: 'Show $dayName timetable'"));
    expect(parent, contains('current_section_id'));
    expect(parent, contains("'Sunday'"));
    expect(parent, contains('getTimetableSlots'));
    expect(handler, contains('parent_student_links'));
    expect(handler, contains('current_section_id'));
    expect(handler, contains('timetable access denied'));
  });
}
