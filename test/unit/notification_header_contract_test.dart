import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('notification center owns its header actions across roles', () {
    final source = File(
      'lib/features/communication/presentation/screens/notification_center_screen/notification_center_screen.dart',
    ).readAsStringSync();

    expect(source, contains('showGlobalToolbarActions: false'));
    expect(source, contains('_notificationHeaderActions('));
    expect(source, contains("_notificationHeaderActions(context, 'parent')"));
    expect(source, contains('Mark all as read'));
    expect(source, contains('_markingAllRead'));
    expect(source, contains('_init(forceRefresh: true)'));
  });
}
