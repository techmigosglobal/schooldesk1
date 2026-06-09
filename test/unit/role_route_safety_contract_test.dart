import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:schooldesk1/routes/app_routes.dart';
import 'package:schooldesk1/routes/route_access_guard.dart';
import 'package:schooldesk1/routes/schooldesk_screen_registry.dart';

void main() {
  final appRoutesSource = File('lib/routes/app_routes.dart').readAsStringSync();
  final routeConstants = _routeConstants(appRoutesSource);
  final visibleRouteNames = _visibleRouteNames(appRoutesSource);

  final roleSources = {
    'admin': [
      'lib/core/widgets/admin_navigation.dart',
      'lib/features/dashboard/presentation/screens/admin_dashboard_screen/admin_dashboard_screen.dart',
    ],
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
          RouteAccessGuard.isRoleAllowedFor(
            routeName: route,
            role: entry.key,
          ),
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
        if (metadata == null || metadata.isPublic || metadata.isShared) {
          continue;
        }

        expect(
          visibleRouteNames,
          contains(routeName),
          reason:
              '$routeName ($route) is visible for ${entry.key} and must not resolve to BlankRoleModuleScreen',
        );

        final wrongRole = _wrongRoleFor(route);
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

Set<String> _visibleRouteNames(String source) {
  final match = RegExp(
    r'static\s+const\s+Set<String>\s+_roleWorkflowVisibleRoutes\s*=\s*\{([\s\S]*?)\};',
  ).firstMatch(source);
  final body = match?.group(1) ?? '';
  return RegExp(r'\b([a-zA-Z]\w*)\b')
      .allMatches(body)
      .map((match) => match.group(1)!)
      .where((name) => name != 'const')
      .toSet();
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
