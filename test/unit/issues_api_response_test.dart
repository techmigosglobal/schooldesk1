import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';

class _ResponseAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    jsonEncode({
      'success': true,
      'data': {
        'data': [
          {'id': 'issue-42', 'title': 'Parent issue', 'status': 'pending'},
        ],
        'total': 41,
        'page': 2,
        'page_size': 20,
      },
    }),
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'issues preserve rows and pagination from the actual nested API envelope',
    () async {
      final api = BackendApiClient.instance;
      api.dio.options.baseUrl = 'http://127.0.0.1:54321/functions/v1/api';
      api.dio.interceptors.clear();
      api.dio.httpClientAdapter = _ResponseAdapter();
      final page = await api.getIssuesPage(page: 2);
      expect(page.data.single['id'], 'issue-42');
      expect(page.total, 41);
      expect(page.page, 2);
      expect(page.pageSize, 20);
      expect(page.hasMore, isTrue);
    },
  );
}
