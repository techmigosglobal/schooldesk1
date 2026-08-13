import 'package:flutter_test/flutter_test.dart';
import 'package:schooldesk1/core/utils/media_url.dart';

void main() {
  test('normal object URLs remain unchanged', () {
    const url =
        'https://example.supabase.co/storage/v1/object/public/school-assets/logo.png';
    expect(resolveOriginalImageUrl(url), url);
  });

  test('legacy render URLs resolve to the original object URL', () {
    const legacy =
        'https://example.supabase.co/storage/v1/render/image/public/school-assets/logo.png?width=256&height=256&quality=72&resize=contain&download=1';
    expect(
      resolveOriginalImageUrl(legacy),
      'https://example.supabase.co/storage/v1/object/public/school-assets/logo.png?download=1',
    );
    expect(resolveOriginalImageUrl(legacy), isNot(contains('/render/image/')));
  });

  test(
    'relative and non-image API URLs are left for their existing resolver',
    () {
      expect(
        resolveOriginalImageUrl('/uploads/abc/photo.jpg'),
        '/uploads/abc/photo.jpg',
      );
      expect(
        resolveOriginalImageUrl(
          'https://example.supabase.co/storage/v1/object/public/docs/file.pdf',
        ),
        'https://example.supabase.co/storage/v1/object/public/docs/file.pdf',
      );
    },
  );
}
