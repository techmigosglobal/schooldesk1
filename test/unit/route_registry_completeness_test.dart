import 'package:flutter_test/flutter_test.dart';
import 'package:schooldesk1/routes/app_routes.dart';
import 'package:schooldesk1/routes/route_access_guard.dart';
import 'package:schooldesk1/routes/schooldesk_screen_registry.dart';

void main() {
  test('every registered route has auth ownership and screen metadata', () {
    final missingOwnership = <String>[];
    final missingMetadata = <String>[];

    for (final route in AppRoutes.routes.keys) {
      if (!RouteAccessGuard.publicRoutes.contains(route) &&
          !RouteAccessGuard.sharedProtectedRoutes.contains(route) &&
          RouteAccessGuard.allowedRolesFor(route).isEmpty) {
        missingOwnership.add(route);
      }
      final metadata = SchoolDeskScreenRegistry.byRoute(route);
      if (metadata == null ||
          metadata.title.trim().isEmpty ||
          metadata.module.trim().isEmpty ||
          metadata.portal.trim().isEmpty) {
        missingMetadata.add(route);
      }
    }

    expect(missingOwnership, isEmpty);
    expect(missingMetadata, isEmpty);
  });

  test(
    'owned routes reject every authenticated role outside their boundary',
    () {
      final failures = <String>[];
      for (final route in AppRoutes.routes.keys) {
        if (RouteAccessGuard.publicRoutes.contains(route) ||
            RouteAccessGuard.sharedProtectedRoutes.contains(route)) {
          continue;
        }
        final allowed = RouteAccessGuard.allowedRolesFor(route);
        for (final role in RouteAccessGuard.authenticatedRoles) {
          final expected = allowed.contains(role);
          final actual = RouteAccessGuard.isRoleAllowedFor(
            routeName: route,
            role: role,
          );
          if (actual != expected) failures.add('$role:$route');
        }
      }
      expect(failures, isEmpty);
    },
  );
}
