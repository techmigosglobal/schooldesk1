import 'package:flutter_test/flutter_test.dart';
import 'package:schooldesk1/core/utils/chat_message_merge.dart';

void main() {
  test(
    'overlapping realtime batches keep one row per persisted message id',
    () {
      final current = <Map<String, dynamic>>[
        {
          'id': 'message-1',
          'body': "Today's agenda",
          'sent_at': '2026-07-16T06:41:17.560Z',
        },
      ];
      final repeatedBatch = <Map<String, dynamic>>[
        {
          'id': 'message-1',
          'body': "Today's agenda",
          'sent_at': '2026-07-16T06:41:17.560Z',
          'is_read': true,
        },
      ];

      final merged = mergeChatMessagesByIdentity(current, repeatedBatch);

      expect(merged, hasLength(1));
      expect(merged.single['id'], 'message-1');
      expect(merged.single['is_read'], isTrue);
    },
  );

  test('new message ids remain in chronological batch order', () {
    final merged = mergeChatMessagesByIdentity(
      [
        {'id': 'message-1', 'body': 'First'},
      ],
      [
        {'id': 'message-2', 'body': 'Second'},
      ],
    );

    expect(merged.map((message) => message['id']), ['message-1', 'message-2']);
  });

  test('legacy rows without ids are not collapsed by matching text', () {
    final merged = mergeChatMessagesByIdentity(
      [
        {'body': 'Okay'},
      ],
      [
        {'body': 'Okay'},
      ],
    );

    expect(merged, hasLength(2));
  });
}
