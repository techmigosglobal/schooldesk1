import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'backend_route_sources.dart';

void main() {
  test(
    'principal portal has no active admin routes or admin-only guard role',
    () {
      final routes = File('lib/routes/app_routes.dart').readAsStringSync();
      final guard = File(
        'lib/routes/route_access_guard.dart',
      ).readAsStringSync();
      final backendRoutes = readBackendRouteSources();
      final registry = File(
        'lib/routes/schooldesk_screen_registry.dart',
      ).readAsStringSync();

      expect(routes, isNot(contains("'/admin-")));
      expect(routes, isNot(contains('static const String admin')));
      expect(guard, isNot(contains("'admin'")));
      expect(registry, isNot(contains("portal: 'admin'")));
      expect(backendRoutes, isNot(contains('api.Group("/admin")')));
      expect(backendRoutes, isNot(contains('"/admin/bulk-import')));
      expect(backendRoutes, contains('api.Group("/principal/bulk-import")'));
    },
  );

  test('principal lesson planner monitoring is routed and backend-backed', () {
    final dashboard = File(
      'lib/features/dashboard/presentation/screens/principal_dashboard_screen/principal_dashboard_screen.dart',
    ).readAsStringSync();
    final drawer = File(
      'lib/core/widgets/app_navigation.dart',
    ).readAsStringSync();
    final routes = File('lib/routes/app_routes.dart').readAsStringSync();
    final guard = File('lib/routes/route_access_guard.dart').readAsStringSync();
    final registry = File(
      'lib/routes/schooldesk_screen_registry.dart',
    ).readAsStringSync();
    final academics = File(
      'lib/features/academics/academics.dart',
    ).readAsStringSync();
    final backendRoutes = readBackendRouteSources();

    expect(routes, contains('static const String principalLessonPlanner'));
    expect(routes, contains('PrincipalLessonPlannerScreen'));
    expect(guard, contains("AppRoutes.principalLessonPlanner: {'principal'}"));
    expect(registry, contains("route: '/principal-lesson-planner-screen'"));
    expect(dashboard, contains("label: 'Lesson Planners'"));
    expect(dashboard, contains('route: AppRoutes.principalLessonPlanner'));
    expect(drawer, contains('route: AppRoutes.principalLessonPlanner'));
    expect(academics, contains('principal_lesson_planner_screen.dart'));
    expect(backendRoutes, contains('path === "/lesson-planners/principal"'));
  });

  test('principal home orders academics and uses distinct event icons', () {
    final dashboard = File(
      'lib/features/dashboard/presentation/screens/principal_dashboard_screen/principal_dashboard_screen.dart',
    ).readAsStringSync();
    final registry = File(
      'lib/routes/schooldesk_screen_registry.dart',
    ).readAsStringSync();
    final illustrations = File(
      'lib/core/widgets/erp_components.dart',
    ).readAsStringSync();

    final subjectsIndex = dashboard.indexOf("label: 'Subjects'");
    final timetableIndex = dashboard.indexOf("label: 'Timetable'");
    final lessonPlannerIndex = dashboard.indexOf("label: 'Lesson Planners'");
    expect(subjectsIndex, isNonNegative);
    expect(timetableIndex, greaterThan(subjectsIndex));
    expect(lessonPlannerIndex, greaterThan(timetableIndex));

    final registrySubjectsIndex = registry.indexOf(
      "route: '/principal-subjects-screen'",
    );
    final registryTimetableIndex = registry.indexOf(
      "route: '/principal-timetable-screen'",
    );
    final registryLessonPlannerIndex = registry.indexOf(
      "route: '/principal-lesson-planner-screen'",
    );
    expect(registryTimetableIndex, greaterThan(registrySubjectsIndex));
    expect(registryLessonPlannerIndex, greaterThan(registryTimetableIndex));

    final calendarBlock = dashboard.substring(
      dashboard.indexOf("label: 'Calendar'"),
      dashboard.indexOf("label: 'Event Approvals'"),
    );
    final approvalsBlock = dashboard.substring(
      dashboard.indexOf("label: 'Event Approvals'"),
      dashboard.indexOf("label: 'Gallery'"),
    );
    final galleryBlock = dashboard.substring(
      dashboard.indexOf("label: 'Gallery'"),
      dashboard.indexOf("label: 'Communications'"),
    );
    expect(
      calendarBlock,
      contains('SchoolDeskUiIllustrations.principalEvents'),
    );
    expect(approvalsBlock, contains('SchoolDeskUiIllustrations.notices'));
    expect(galleryBlock, contains('SchoolDeskUiIllustrations.resources'));
    expect(illustrations, contains('principal-timetable.svg'));
    expect(dashboard, contains('SchoolDeskUiIllustrations.principalTimetable'));
  });

  test('principal lesson planner review filters match backend statuses', () {
    final screen = File(
      'lib/features/academics/presentation/screens/principal_lesson_planner_screen.dart',
    ).readAsStringSync();
    final backendRoutes = readBackendRouteSources();

    expect(screen, contains("_statusFilter = 'all'"));
    expect(screen, contains("value: 'uploaded'"));
    expect(screen, contains("label: Text('Needs review')"));
    expect(screen, contains("value: 'completed'"));
    expect(screen, contains("label: 'Needs review'"));
    expect(screen, contains("label: 'Completion'"));
    expect(screen, isNot(contains("value: 'planned'")));
    expect(screen, contains("teacherMap['first_name']"));
    expect(screen, contains("teacherMap['last_name']"));
    expect(screen, contains("return 'Class Name: \$displayName';"));
    expect(screen, contains('_classDisplayName(planner)'));
    expect(screen, contains('_isGenericTeacherName'));
    expect(backendRoutes, contains('function lessonPlannerDisplayText'));
    expect(backendRoutes, contains('async function enrichLessonPlannerRows'));
    expect(backendRoutes, contains('section:sections(*, grade:grades(*))'));
    expect(backendRoutes, contains('svc.from("staff")'));
    expect(backendRoutes, contains('class_name: className'));
    expect(backendRoutes, contains('grade_name: gradeName'));
    expect(backendRoutes, contains('section_name: sectionName'));
    expect(backendRoutes, contains('teacher_name: teacherName'));
  });
}
