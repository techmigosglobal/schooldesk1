import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schooldesk1/core/config/env_config.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/utils/media_cache.dart';
import 'package:schooldesk1/core/utils/media_url.dart';

void main() {
  test('normal object URLs remain unchanged', () {
    const url =
        'https://example.supabase.co/storage/v1/object/public/school-assets/logo.png';
    expect(resolveOriginalImageUrl(url), url);
  });

  test('R2 public and signed media URLs remain API-provided values', () {
    const publicUrl =
        'https://media.arishville.com/website/school/gallery/photo.jpg';
    const signedPrivateUrl =
        'https://account.r2.cloudflarestorage.com/schooldesk-private-files/private/event-posts/photo.jpg?X-Amz-Algorithm=AWS4-HMAC-SHA256';
    expect(resolveOriginalImageUrl(publicUrl), publicUrl);
    expect(resolveOriginalImageUrl(signedPrivateUrl), signedPrivateUrl);
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

  test('Docker storage aliases use the local gateway when running locally', () {
    const dockerUrl =
        'http://kong:8000/storage/v1/object/public/school-assets/logo.png';
    expect(
      resolveOriginalImageUrl(dockerUrl),
      'http://127.0.0.1:54321/storage/v1/object/public/school-assets/logo.png',
    );
  }, skip: !EnvConfig.isLocal);

  test('unavailable media resolves to an empty placeholder safely', () async {
    final api = BackendApiClient.instance;
    final previousAdapter = api.dio.httpClientAdapter;
    api.dio.httpClientAdapter = _OfflineAdapter();
    try {
      final bytes = await MediaCache.load(
        'http://offline.test/media/${DateTime.now().microsecondsSinceEpoch}.png',
      );
      expect(bytes, isEmpty);
    } finally {
      api.dio.httpClientAdapter = previousAdapter;
    }
  });
}

class _OfflineAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    throw DioException(
      requestOptions: options,
      type: DioExceptionType.connectionError,
    );
  }

  @override
  void close({bool force = false}) {}
}
