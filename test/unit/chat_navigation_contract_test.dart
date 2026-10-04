import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const screens = {
    'Parent':
        'lib/features/communication/presentation/screens/parent_teacher_chat_screen/parent_teacher_chat_screen.dart',
    'Teacher':
        'lib/features/communication/presentation/screens/teacher_communication_screen/teacher_communication_screen.dart',
    'Principal':
        'lib/features/communication/presentation/screens/principal_chat_communications_screen/principal_chat_communications_screen.dart',
  };

  for (final entry in screens.entries) {
    test('${entry.key} chat routes Back from conversation to list first', () {
      final source = File(entry.value).readAsStringSync();
      expect(source, contains('PopScope('));
      expect(source, contains('onBackRequested:'));
      expect(source, contains('_backToConversationList'));
      expect(source, contains('Back to chats'));
    });
  }

  test(
    'Principal Direct retains Monitor and Direct tabs with All as default',
    () {
      final source = File(screens['Principal']!).readAsStringSync();
      expect(source, contains("String _directRoleFilter = 'all'"));
      expect(
        source,
        contains("label: 'All (\${_directConversations.length})'"),
      );
      expect(source, contains("text: 'Monitor'"));
      expect(source, contains("text: 'Direct'"));
    expect(source, contains("child: Text('All classes')"));
    },
  );
}
