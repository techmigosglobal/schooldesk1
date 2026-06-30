import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:schooldesk1/core/utils/event_post_media_parser.dart';
import 'package:schooldesk1/core/widgets/event_post_media_preview.dart';

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

    test(
      'splits comma-separated URL list when delimiter starts another URL',
      () {
        const raw = 'https://cdn.test/a.jpg, https://cdn.test/b.jpg';

        final media = parseEventPostMediaUrls(raw);

        expect(media, const [
          'https://cdn.test/a.jpg',
          'https://cdn.test/b.jpg',
        ]);
      },
    );

    test('parses structured media object arrays with video metadata', () {
      const raw =
          '[{"url":"/uploads/shared/school/clip.mp4","name":"Annual Day.mp4","mime_type":"video/mp4","kind":"video","size":12345}]';

      final media = EventPostMediaItem.parseList(raw);

      expect(media, hasLength(1));
      expect(media.single.url, '/uploads/shared/school/clip.mp4');
      expect(media.single.name, 'Annual Day.mp4');
      expect(media.single.mimeType, 'video/mp4');
      expect(media.single.kind, EventPostMediaKind.video);
      expect(media.single.size, 12345);
      expect(media.single.isVideo, isTrue);
    });

    test('infers media metadata for legacy URL strings', () {
      const raw =
          'https://cdn.test/photo.jpg, https://cdn.test/document.pdf, https://cdn.test/movie.webm';

      final media = EventPostMediaItem.parseList(raw);

      expect(media.map((item) => item.kind), [
        EventPostMediaKind.image,
        EventPostMediaKind.pdf,
        EventPostMediaKind.video,
      ]);
      expect(media.last.isVideo, isTrue);
    });

    test('resolves backend uploads through the api uploads route', () {
      final resolved = resolveEventPostMediaUrl(
        '/uploads/shared/school/photo.jpg',
      );

      expect(resolved, endsWith('/api/v1/uploads/shared/school/photo.jpg'));
      expect(resolved, isNot(contains('/api/v1/api/v1/')));
    });

    test('event post attachments open in app instead of external browser', () {
      final source = File(
        'lib/core/widgets/event_post_media_preview.dart',
      ).readAsStringSync();

      expect(source, contains('openEventPostMediaPreview'));
      expect(source, contains('Navigator.of(context).push'));
      expect(source, contains('PdfPreview('));
      expect(source, contains('BackendApiClient.instance.dio.get<List<int>>'));
      expect(source, contains('Image.memory'));
      expect(source, isNot(contains('LaunchMode.externalApplication')));
      expect(source, isNot(contains('Image.network')));
    });
  });
}
