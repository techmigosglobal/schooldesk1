import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'app keeps only the Flutter animated logo as visible startup splash',
    () {
      final main = File('lib/main.dart').readAsStringSync();
      final launch = File(
        'android/app/src/main/res/drawable/launch_background.xml',
      ).readAsStringSync();
      final launchV21 = File(
        'android/app/src/main/res/drawable-v21/launch_background.xml',
      ).readAsStringSync();
      final launchV31 = File(
        'android/app/src/main/res/values-v31/styles.xml',
      ).readAsStringSync();
      final transparentIcon = File(
        'android/app/src/main/res/drawable/transparent_splash_icon.xml',
      );

      expect(
        RegExp('AnimatedStartupSplash\\(').allMatches(main).length,
        1,
        reason: 'Only the Flutter overlay should show the animated logo.',
      );
      expect(main, contains('child: AnimatedStartupSplash(child: child!)'));
      expect(launch, isNot(contains('@mipmap/launch_image')));
      expect(launchV21, isNot(contains('@mipmap/launch_image')));
      expect(launchV31, isNot(contains('@mipmap/launch_image')));
      expect(launchV31, contains('@drawable/transparent_splash_icon'));
      expect(transparentIcon.existsSync(), isTrue);
    },
  );

  test(
    'startup defers slow role and push services until after first frame',
    () {
      final main = File('lib/main.dart').readAsStringSync();
      final apiClient = File(
        'lib/core/network/backend_api_client.dart',
      ).readAsStringSync();

      final runAppIndex = main.indexOf('runApp(');
      final deferIndex = main.indexOf('_deferStartupServices();');
      final roleInitIndex = main.indexOf(
        'await RoleAccessService.initialize()',
      );
      final pushInitIndex = main.indexOf(
        'await PushNotificationService.instance.initialize()',
      );
      expect(runAppIndex, lessThan(deferIndex));
      expect(deferIndex, lessThan(roleInitIndex));
      expect(deferIndex, lessThan(pushInitIndex));
      expect(main, contains('WidgetsBinding.instance.addPostFrameCallback'));
      expect(main, contains('restoreStoredSession()'));
      expect(
        apiClient,
        isNot(contains('await client.restoreStoredSession();')),
        reason: 'Token validation should not block first paint.',
      );
    },
  );

  test('principal dashboard double back exits instead of logging out', () {
    final dashboard = File(
      'lib/features/dashboard/presentation/screens/principal_dashboard_screen/principal_dashboard_screen.dart',
    ).readAsStringSync();
    final routeFrame = File(
      'lib/core/widgets/schooldesk_route_frame.dart',
    ).readAsStringSync();

    expect(dashboard, contains('PopScope('));
    expect(dashboard, contains('canPop: false'));
    expect(dashboard, contains('SystemNavigator.pop()'));
    expect(dashboard, contains('Press back again to exit Arish Ville'));
    expect(routeFrame, contains('Press back again to exit Arish Ville'));
    expect(routeFrame, contains('_isPortalHomeRoute'));
    expect(routeFrame, contains('_returnToPortalHome'));
    expect(routeFrame, contains("case '/teacher-dashboard-screen':"));
    expect(routeFrame, contains("case 'teacher':"));
    expect(dashboard, isNot(contains('LogoutService')));
    expect(dashboard, isNot(contains('BackendApiClient.instance.logout')));
  });
}
