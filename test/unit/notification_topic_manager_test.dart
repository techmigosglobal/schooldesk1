import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('push delivery uses registered device tokens, not unused topics', () {
    final pushSource = File(
      'lib/core/services/push_notification_service.dart',
    ).readAsStringSync();
    final loginSource = File(
      'lib/features/auth/presentation/screens/auth_login_screen/auth_login_screen.dart',
    ).readAsStringSync();
    final logoutSource = File(
      'lib/core/services/logout_service.dart',
    ).readAsStringSync();

    expect(pushSource, isNot(contains('subscribeToTopic')));
    expect(pushSource, isNot(contains('unsubscribeFromTopic')));
    expect(loginSource, isNot(contains('NotificationTopicManager')));
    expect(logoutSource, isNot(contains('NotificationTopicManager')));
  });
}
