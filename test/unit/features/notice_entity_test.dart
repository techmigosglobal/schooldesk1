import 'package:flutter_test/flutter_test.dart';
import 'package:schooldesk1/features/shared/domain/entities/notice.dart';

void main() {
  group('Notice Entity', () {
    final testNotice = Notice(
      id: 'notice_001',
      title: 'School Holiday Announcement',
      content: 'School will remain closed on April 25th for Diwali.',
      type: 'Holiday',
      targetAudience: 'All',
      publishedBy: 'Principal',
      publishedByRole: 'principal',
      publishedAt: DateTime(2025, 4, 20),
      isUrgent: false,
      isPublished: true,
    );

    test('creates notice with required fields', () {
      expect(testNotice.id, 'notice_001');
      expect(testNotice.title, 'School Holiday Announcement');
      expect(testNotice.type, 'Holiday');
    });

    test('default readBy is empty list', () {
      expect(testNotice.readBy, isEmpty);
    });

    group('isReadBy()', () {
      test('returns false when user has not read', () {
        expect(testNotice.isReadBy('user_001'), isFalse);
      });

      test('returns true when user has read', () {
        final readNotice = testNotice.copyWith(
          readBy: ['user_001', 'user_002'],
        );
        expect(readNotice.isReadBy('user_001'), isTrue);
        expect(readNotice.isReadBy('user_003'), isFalse);
      });
    });

    group('copyWith()', () {
      test('marks notice as urgent', () {
        final urgent = testNotice.copyWith(isUrgent: true);
        expect(urgent.isUrgent, isTrue);
        expect(urgent.id, testNotice.id);
      });

      test('unpublishes notice', () {
        final unpublished = testNotice.copyWith(isPublished: false);
        expect(unpublished.isPublished, isFalse);
      });

      test('adds readers', () {
        final withReaders = testNotice.copyWith(readBy: ['user_001']);
        expect(withReaders.readBy.length, 1);
      });
    });

    group('equality', () {
      test('same id means equal', () {
        final copy = testNotice.copyWith(title: 'Different Title');
        expect(testNotice, equals(copy));
      });
    });
  });
}
