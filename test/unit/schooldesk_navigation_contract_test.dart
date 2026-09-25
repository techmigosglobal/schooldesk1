import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('notification navigation uses GoRouter adapter with safe fallback', () {
    final navigation = File(
      'lib/core/navigation/schooldesk_navigation.dart',
    ).readAsStringSync();
    final pushService = File(
      'lib/core/services/push_notification_service.dart',
    ).readAsStringSync();
    final notificationCenter = File(
      'lib/features/communication/presentation/screens/notification_center_screen/notification_center_screen.dart',
    ).readAsStringSync();

    expect(navigation, contains('GoRouter.maybeOf(context)'));
    expect(navigation, contains('router.push<T>(route, extra: arguments)'));
    expect(navigation, contains('Navigator.of(context).pushNamed<T>'));
    expect(pushService, contains('SchoolDeskNavigation.pushFromRoot'));
    expect(pushService, contains('SchoolDeskNavigation.goFromRoot'));
    expect(notificationCenter, contains('SchoolDeskNavigation.push('));
  });

  test('route frame gives GoRouter ownership of top-level back navigation', () {
    final routeFrame = File(
      'lib/core/widgets/schooldesk_route_frame.dart',
    ).readAsStringSync();

    expect(routeFrame, contains('GoRouter.maybeOf(context)?.canPop()'));
    expect(routeFrame, contains('router.pop()'));
    expect(routeFrame, contains('router.go(target)'));
  });
}
