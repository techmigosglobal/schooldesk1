import 'package:flutter_test/flutter_test.dart';
import 'package:schooldesk1/core/utils/event_post_media_parser.dart';

void main() {
  group('parseEventPostMediaUrls', () {
    test('parses JSON array string payload', () {
      final raw = '["https://cdn.test/a.jpg","https://cdn.test/b.jpg"]';

      final media = parseEventPostMediaUrls(raw);

      expect(media, const ['https://cdn.test/a.jpg', 'https://cdn.test/b.jpg']);
      expect(firstEventPostMediaUrl(raw), 'https://cdn.test/a.jpg');
    });

    test('keeps single signed URL with comma in query intact', () {
      final raw =
          'https://cdn.test/photo.jpg?X-Amz-SignedHeaders=host,content-type&X-Amz-Expires=900';

      final media = parseEventPostMediaUrls(raw);

      expect(media.length, 1);
      expect(media.first, raw);
    });

    test('splits comma-separated URL list when delimiter starts another URL', () {
      const raw = 'https://cdn.test/a.jpg, https://cdn.test/b.jpg';

      final media = parseEventPostMediaUrls(raw);

      expect(media, const ['https://cdn.test/a.jpg', 'https://cdn.test/b.jpg']);
    });
  });
}
