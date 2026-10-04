import 'package:flutter_test/flutter_test.dart';
import 'package:schooldesk1/features/communication/presentation/widgets/chat_shared_widgets.dart';

void main() {
  group('chat date labels', () {
    final now = DateTime(2026, 10, 3, 12);

    test('labels local today and yesterday distinctly', () {
      expect(chatDateDividerLabel(DateTime(2026, 10, 3, 8), now: now), 'Today');
      expect(
        chatDateDividerLabel(DateTime(2026, 10, 2, 23, 59), now: now),
        'Yesterday',
      );
    });

    test('uses a calendar date for older messages and previews', () {
      final older = DateTime(2026, 9, 30, 23, 59);
      expect(chatDateDividerLabel(older, now: now), 'Sep 30, 2026');
      expect(chatPreviewDateTime(older, now: now), 'Sep 30, 2026');
      expect(
        chatPreviewDateTime(DateTime(2026, 10, 3, 9), now: now),
        '9:00 AM',
      );
      expect(
        chatPreviewDateTime(DateTime(2026, 10, 2, 9), now: now),
        'Yesterday',
      );
    });

    test('converts timestamp offsets to device-local calendar boundaries', () {
      final timestamp = DateTime.parse('2026-10-03T00:15:00+02:00').toLocal();
      final localNow = DateTime(
        timestamp.year,
        timestamp.month,
        timestamp.day,
        12,
      );
      expect(chatDateDividerLabel(timestamp, now: localNow), 'Today');
      expect(
        chatDateDividerLabel(
          timestamp,
          now: localNow.add(const Duration(days: 1)),
        ),
        'Yesterday',
      );
    });

    test('invalid or absent timestamps do not produce a date label', () {
      expect(chatDateDividerLabel(null, now: now), isNull);
      expect(chatPreviewDateTime(null, now: now), isEmpty);
      expect(DateTime.tryParse('not-a-timestamp'), isNull);
    });
  });

  test(
    'Direct contact role filter defaults to All and supports role filters',
    () {
      expect(
        chatContactMatchesRoleFilter(selectedRole: 'all', roleLabel: 'Teacher'),
        isTrue,
      );
      expect(
        chatContactMatchesRoleFilter(
          selectedRole: 'teacher',
          roleLabel: 'Teacher',
        ),
        isTrue,
      );
      expect(
        chatContactMatchesRoleFilter(
          selectedRole: 'parent',
          roleLabel: 'Teacher',
        ),
        isFalse,
      );
    },
  );
}
