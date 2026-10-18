import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:schooldesk1/app/router/typed_role_routes.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';

void main() {
  for (final role in [
    'parent',
    'teacher',
    'coordinator',
    'principal',
    'super_admin',
  ]) {
    testWidgets(
      'shared screen respects authenticated $role despite stale navigation role',
      (tester) async {
        BackendApiClient.instance.setCurrentRole(role);
        final router = GoRouter(
          initialLocation: '/shared?role=principal',
          routes: [
            GoRoute(
              path: '/shared',
              builder: (_, state) =>
                  Text(SharedRoleRouteArgs.fromState(state).roleName),
            ),
          ],
        );
        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pumpAndSettle();
        expect(find.text(role), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
        router.dispose();
        BackendApiClient.instance.setCurrentRole(null);
      },
    );
  }
  testWidgets(
    'legacy extra role remains supported without an authenticated scope',
    (tester) async {
      BackendApiClient.instance.setCurrentRole(null);
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(path: '/', builder: (_, __) => const SizedBox()),
          GoRoute(
            path: '/shared',
            builder: (_, state) =>
                Text(SharedRoleRouteArgs.fromState(state).roleName),
          ),
        ],
      );
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      router.go('/shared', extra: 'parent');
      await tester.pumpAndSettle();
      expect(find.text('parent'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      router.dispose();
    },
  );
}
