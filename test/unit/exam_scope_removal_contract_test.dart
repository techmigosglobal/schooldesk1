import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('communication and settings screens do not expose exam specific UI', () {
    final notificationCenter = File(
      'lib/features/communication/presentation/screens/notification_center_screen/notification_center_screen.dart',
    ).readAsStringSync();
    final parentChat = File(
      'lib/features/communication/presentation/screens/parent_teacher_chat_screen/parent_teacher_chat_screen.dart',
    ).readAsStringSync();
    final settings = File(
      'lib/features/profile/presentation/screens/settings_screen/settings_screen.dart',
    ).readAsStringSync();

    expect(notificationCenter, isNot(contains("Tab(text: 'Exams')")));
    expect(notificationCenter, isNot(contains("return 'Exams'")));
    expect(parentChat, isNot(contains("'Exams'")));
    expect(settings, isNot(contains('Exam Reminders')));
    expect(settings, isNot(contains("exam_reminders")));
  });
}
