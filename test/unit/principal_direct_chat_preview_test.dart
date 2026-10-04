import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:schooldesk1/features/communication/presentation/widgets/chat_shared_widgets.dart';

void main() {
  group('principal direct chat preview lines', () {
    test('shows a latest message only once when no class context exists', () {
      expect(
        principalDirectChatPreviewLines(
          classContext: '',
          contactContext: '',
          latestMessage: 'Hi, prepare Lesson planner for Aug...',
        ),
        ['Hi, prepare Lesson planner for Aug...'],
      );
    });

    test('shows class context followed by the latest message', () {
      expect(
        principalDirectChatPreviewLines(
          classContext: 'Class 1 - A',
          contactContext: '',
          latestMessage: 'Please check the lesson planner.',
        ),
        ['Class 1 - A', 'Please check the lesson planner.'],
      );
    });

    test(
      'shows contact context while an empty contact starts a conversation',
      () {
        expect(
          principalDirectChatPreviewLines(
            classContext: '',
            contactContext: 'Teacher contact',
            latestMessage: '',
          ),
          ['Teacher contact', 'Start a conversation'],
        );
      },
    );

    test('principal chat rows render the deduplicated preview lines', () {
      final source = File(
        'lib/features/communication/presentation/screens/principal_chat_communications_screen/principal_chat_communications_screen.dart',
      ).readAsStringSync();

      expect(
        source,
        contains('final directPreviewLines = principalDirectChatPreviewLines('),
      );
      expect(source, contains('for (final line in directPreviewLines)'));
    });
  });
}
