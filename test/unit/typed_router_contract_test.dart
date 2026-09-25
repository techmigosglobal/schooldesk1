import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:schooldesk1/app/router/typed_app_route_registry.dart';
import 'package:schooldesk1/app/router/typed_role_routes.dart';
import 'package:schooldesk1/core/auth/role_context.dart';
import 'package:schooldesk1/routes/app_routes.dart';

void main() {
  test('role entry points use typed GoRouteData adapters', () {
    final routes = File(
      'lib/app/router/typed_role_routes.dart',
    ).readAsStringSync();
    final router = File('lib/app/router/app_router.dart').readAsStringSync();

    for (final type in [
      'PrincipalDashboardRoute',
      'CoordinatorDashboardRoute',
      'TeacherDashboardRoute',
      'ParentDashboardRoute',
      'KioskAttendanceRoute',
      'SuperAdminDashboardRoute',
    ]) {
      expect(routes, contains('class $type extends GoRouteData'));
      expect(routes, contains('const $type()'));
    }

    for (final type in [
      'NotificationCenterRoute',
      'SettingsRoute',
      'ProfileRoute',
      'GlobalSearchRoute',
      'HelpRoute',
      'HomeworkMessagingRoute',
    ]) {
      expect(routes, contains('class $type extends GoRouteData'));
      expect(routes, contains('fromState(GoRouterState state)'));
    }

    expect(router, contains('refreshListenable: api'));
    expect(router, contains('TypedAppRouteRegistry.all'));
    expect(router, isNot(contains('LegacyRouteHost')));
  });

  test('every registered location has a typed GoRouter contract', () {
    final typedRoutes = TypedAppRouteRegistry.all;
    expect(typedRoutes, hasLength(AppRoutes.routes.length));
    expect(
      typedRoutes.map((route) => route.path).toSet(),
      containsAll(AppRoutes.routes.keys),
    );
    expect(typedRoutes.every((route) => route.name.trim().isNotEmpty), isTrue);
  });

  test('feature code does not bypass the typed navigation adapter', () {
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .where(
          (file) =>
              !file.path.endsWith('core/navigation/schooldesk_navigation.dart'),
        );

    for (final file in files) {
      final source = file.readAsStringSync();
      expect(
        source,
        isNot(
          anyOf(
            contains('pushNamed('),
            contains('pushReplacementNamed('),
            contains('pushNamedAndRemoveUntil('),
          ),
        ),
        reason: '${file.path} still bypasses SchoolDeskNavigation',
      );
    }
  });

  test('shared typed routes keep portal role in their locations', () {
    const args = SharedRoleRouteArgs(role: SchoolDeskRole.teacher);

    expect(
      NotificationCenterRoute(args: args).location,
      contains('role=teacher'),
    );
    expect(SettingsRoute(args: args).location, contains('role=teacher'));
    expect(ProfileRoute(args: args).location, contains('role=teacher'));
    expect(
      HomeworkMessagingRoute(args: args).location,
      contains('role=teacher'),
    );
  });
}
