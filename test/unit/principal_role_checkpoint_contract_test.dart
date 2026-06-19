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
    expect(backendRoutes, contains('lessonPlanners.GET("/principal"'));
  });
}
