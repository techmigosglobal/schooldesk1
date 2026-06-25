import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:schooldesk1/routes/app_routes.dart';
import 'package:schooldesk1/routes/route_access_guard.dart';
import 'package:schooldesk1/routes/schooldesk_screen_registry.dart';

void main() {
  final appRoutesSource = File('lib/routes/app_routes.dart').readAsStringSync();
  final teacherNavigationSource = File(
    'lib/core/widgets/teacher_navigation.dart',
  ).readAsStringSync();
  final routeConstants = _routeConstants(appRoutesSource);

  final roleSources = {
    'principal': [
      'lib/core/widgets/app_navigation.dart',
      'lib/features/dashboard/presentation/screens/principal_dashboard_screen/principal_dashboard_screen.dart',
    ],
    'teacher': [
      'lib/core/widgets/teacher_navigation.dart',
      'lib/features/dashboard/presentation/screens/teacher_dashboard_screen/teacher_dashboard_screen.dart',
    ],
    'parent': [
      'lib/core/widgets/parent_navigation.dart',
      'lib/features/dashboard/presentation/screens/parent_dashboard_screen/parent_dashboard_screen.dart',
    ],
  };

  for (final entry in roleSources.entries) {
    test('${entry.key} visible routes are registered, allowed, and nonblank', () {
      final routeNames = <String>{};
      for (final path in entry.value) {
        routeNames.addAll(_referencedRouteNames(File(path).readAsStringSync()));
      }

      for (final routeName in routeNames) {
        final route = routeConstants[routeName];
        expect(
          route,
          isNotNull,
          reason: '$routeName must be an AppRoutes const',
        );
        if (route == null) continue;

        expect(
          AppRoutes.routes,
          contains(route),
          reason: '$routeName ($route) must be registered in AppRoutes.routes',
        );

        expect(
          RouteAccessGuard.isRoleAllowedFor(routeName: route, role: entry.key),
          isTrue,
          reason:
              '$routeName ($route) must be explicitly allowed for ${entry.key}',
        );

        final redirect = RouteAccessGuard.redirectFor(
          routeName: route,
          isAuthenticated: true,
          currentRole: entry.key,
        );
        expect(
          redirect,
          isNull,
          reason: '$routeName ($route) must be role-allowed for ${entry.key}',
        );

        final metadata = SchoolDeskScreenRegistry.byRoute(route);
        expect(
          metadata,
          isNotNull,
          reason: '$routeName ($route) must have screen registry metadata',
        );
        final wrongRole = _wrongRoleFor(route);
        if (wrongRole == null) continue;
        expect(
          wrongRole,
          isNotNull,
          reason:
              '$routeName ($route) should have at least one wrong-role redirect target',
        );
        if (wrongRole == null) continue;

        expect(
          RouteAccessGuard.redirectFor(
            routeName: route,
            isAuthenticated: true,
            currentRole: wrongRole,
          ),
          RouteAccessGuard.dashboardForRole(wrongRole),
          reason:
              '$routeName ($route) must redirect $wrongRole to their dashboard',
        );
      }
    });
  }

  test(
    'teacher drawer exposes active screens and hides retired duplicate routes',
    () {
      for (final routeName in [
        'teacherDashboard',
        'teacherClasses',
        'teacherTimetable',
        'teacherAttendance',
        'teacherAttendanceHistory',
        'teacherMyAttendance',
        'teacherDiary',
        'teacherEventPosts',
        'teacherLessonPlanner',
        'teacherStudentNotes',
        'teacherDocuments',
        'schoolGallery',
        'teacherCommunication',
        'teacherParentInteraction',
        'teacherLeave',
        'notificationCenter',
        'profileScreen',
        'settingsScreen',
      ]) {
        expect(
          teacherNavigationSource,
          contains('AppRoutes.$routeName'),
          reason: '$routeName should be reachable from TeacherDrawer',
        );
      }

      expect(
        teacherNavigationSource,
        isNot(contains('AppRoutes.teacherPerformance')),
      );
      expect(
        teacherNavigationSource,
        isNot(contains('AppRoutes.teacherReports')),
      );

      expect(
        teacherNavigationSource,
        isNot(contains('AppRoutes.teacherPTM')),
        reason: 'TeacherPTM is no longer part of Teacher navigation',
      );
      final routes = File('lib/routes/app_routes.dart').readAsStringSync();
      final guard = File(
        'lib/routes/route_access_guard.dart',
      ).readAsStringSync();
      final registry = File(
        'lib/routes/schooldesk_screen_registry.dart',
      ).readAsStringSync();
      final communicationBarrel = File(
        'lib/features/communication/communication.dart',
      ).readAsStringSync();
      expect(
        routes,
        isNot(contains('teacherPTM')),
        reason: 'TeacherParentInteraction is the canonical PTM route',
      );
      expect(
        guard,
        isNot(contains('teacherPTM')),
        reason: 'Duplicate TeacherPTM route should not stay guard-active',
      );
      expect(
        registry,
        isNot(contains('/teacher-ptm-screen')),
        reason: 'Duplicate PTM screen metadata should be retired',
      );
      expect(
        communicationBarrel,
        isNot(contains('teacher_ptm_screen.dart')),
        reason: 'Duplicate PTM screen should not be exported',
      );
      for (final removedRouteName in [
        'teacherStudyMaterials',
        'teacherStudyMaterialForm',
        'teacherHomework',
        'teacherHomeworkForm',
        'teacherHomeworkSubmissions',
        'teacherDiscipline',
      ]) {
        expect(
          teacherNavigationSource,
          isNot(contains('AppRoutes.$removedRouteName')),
          reason: '$removedRouteName is no longer part of Teacher navigation',
        );
      }

      expect(
        teacherNavigationSource,
        contains(
          "label: 'Diary',\n              route: AppRoutes.teacherDiary",
        ),
        reason: 'Diary drawer item must open Class Diary, not Homework',
      );
      expect(
        teacherNavigationSource,
        isNot(contains("label: 'Homework'")),
        reason: 'Teacher Homework is retired from active teacher navigation',
      );
    },
  );
}

Map<String, String> _routeConstants(String source) {
  final constants = <String, String>{};
  final regex = RegExp(
    r"static\s+const\s+String\s+(\w+)\s*=\s*'([^']+)';",
    multiLine: true,
  );
  for (final match in regex.allMatches(source)) {
    constants[match.group(1)!] = match.group(2)!;
  }
  return constants;
}

Set<String> _referencedRouteNames(String source) {
  return RegExp(r'AppRoutes\.(\w+)')
      .allMatches(source)
      .map((match) => match.group(1)!)
      .where((name) => name != 'routes')
      .toSet();
}

String? _wrongRoleFor(String route) {
  final allowedRoles = RouteAccessGuard.allowedRolesFor(route);
  for (final role in RouteAccessGuard.authenticatedRoles) {
    if (!allowedRoles.contains(role)) {
      return role;
    }
  }
  return null;
}
