import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:schooldesk1/app/providers/app_providers.dart';
import 'package:schooldesk1/routes/route_access_guard.dart';
import 'package:schooldesk1/app/router/typed_app_route_registry.dart';
import 'package:schooldesk1/core/services/push_notification_service.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final api = ref.watch(backendApiClientProvider);
  return GoRouter(
    debugLogDiagnostics: false,
    navigatorKey: PushNotificationService.navigatorKey,
    refreshListenable: api,
    initialLocation: RouteAccessGuard.initialRouteFor(
      isAuthenticated: api.isAuthenticated,
      currentRole: api.currentRoleName,
    ),
    redirect: (context, state) {
      return RouteAccessGuard.redirectFor(
        routeName: state.uri.path,
        isAuthenticated: api.isAuthenticated,
        currentRole: api.currentRoleName,
      );
    },
    routes: [
      for (final route in TypedAppRouteRegistry.all) route.toGoRoute(),
    ],
  );
});

/// Transitional adapter used by migrated role modules while the legacy route
/// registry is retired. New modules should expose a [GoRouteData] route with
/// typed arguments instead of reading `ModalRoute.settings.arguments`.
class TypedRoutePage extends StatelessWidget {
  const TypedRoutePage({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}
