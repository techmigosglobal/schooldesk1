import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schooldesk1/app/providers/app_providers.dart';
import 'package:schooldesk1/app/router/app_router.dart';
import 'package:schooldesk1/routes/app_routes.dart';
import 'package:schooldesk1/routes/route_access_guard.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'session updates preserve the router and each role chat location',
    () async {
      final container = ProviderContainer();
      final subscription = container.listen(appRouterProvider, (_, _) {});
      addTearDown(() {
        subscription.close();
        container.dispose();
      });
      final api = container.read(backendApiClientProvider);
      api.setAuthToken('initial-session');
      final router = container.read(appRouterProvider);

      const chats = {
        'principal': AppRoutes.principalChatCommunications,
        'coordinator': AppRoutes.principalChatCommunications,
        'teacher': AppRoutes.teacherCommunication,
        'parent': AppRoutes.parentTeacherChat,
      };
      for (final entry in chats.entries) {
        api.setCurrentRole(entry.key);
        router.go(entry.value);
        api.setAuthToken('refreshed-${entry.key}');
        await Future<void>.delayed(Duration.zero);
        expect(container.read(appRouterProvider), same(router));
        expect(router.routeInformationProvider.value.uri.path, entry.value);
        expect(
          RouteAccessGuard.redirectFor(
            routeName: entry.value,
            isAuthenticated: api.isAuthenticated,
            currentRole: api.currentRoleName,
          ),
          isNull,
        );
      }
      // Preserving navigation must not weaken the authentication guard.
      expect(
        RouteAccessGuard.redirectFor(
          routeName: AppRoutes.parentTeacherChat,
          isAuthenticated: false,
          currentRole: 'parent',
        ),
        AppRoutes.landingPage,
      );
    },
  );
}
