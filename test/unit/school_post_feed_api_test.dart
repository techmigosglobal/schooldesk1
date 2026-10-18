import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/modules/communication/data/api_event_post_repository.dart';

class _FeedAdapter implements HttpClientAdapter {
  RequestOptions? request;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    if (options.method == 'GET' &&
        options.queryParameters['published_only'] != 'true') {
      final page = options.queryParameters['page'] as int;
      final size = options.queryParameters['page_size'] as int;
      final rows = List.generate(
        125,
        (i) => {'id': 'post-$i'},
      ).skip((page - 1) * size).take(size).toList();
      return ResponseBody.fromString(
        jsonEncode({
          'success': true,
          'data': {'data': rows, 'page': page, 'page_size': size, 'total': 125},
        }),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    return ResponseBody.fromString(
      jsonEncode({
        'success': true,
        'data': options.method == 'GET'
            ? {
                'data': [
                  {'id': 'post-121', 'destinations': []},
                ],
                'total': 125,
                'page': 7,
                'page_size': 20,
              }
            : {'id': 'post-121', 'destinations': [], 'status': 'approved'},
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'published feed page and placement-only writes preserve wire semantics',
    () async {
      final api = BackendApiClient.instance;
      final adapter = _FeedAdapter();
      api.dio.options.baseUrl = 'http://127.0.0.1:54321/functions/v1/api';
      api.dio.interceptors.clear();
      api.dio.httpClientAdapter = adapter;
      final repository = ApiEventPostRepository(api);
      final result = await repository.loadPublishedPostsPage(
        page: 7,
        destination: 'SCHOOL_GALLERY',
      );
      expect(result.data.single['id'], 'post-121');
      expect(result.total, 125);
      expect(result.hasMore, isFalse);
      expect(adapter.request!.queryParameters['published_only'], 'true');
      expect(adapter.request!.queryParameters['page'], 7);
      expect(adapter.request!.queryParameters['page_size'], 20);
      expect(adapter.request!.queryParameters['destination'], 'SCHOOL_GALLERY');
      final manageable = await repository.loadPosts(principalMode: true);
      expect(manageable.length, 125);
      expect(manageable.last['id'], 'post-124');
      await repository.updateVisibility('post-121', []);
      expect(adapter.request!.method, 'PUT');
      expect(adapter.request!.data, {'destinations': []});
      await repository.updateVisibility(
        'post-121',
        [],
        publicGalleryVisible: false,
      );
      expect(adapter.request!.data, {
        'destinations': [],
        'public_gallery_visible': false,
      });
    },
  );
}
