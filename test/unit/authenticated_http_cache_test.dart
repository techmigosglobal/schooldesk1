import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';

void main() {
  final api = BackendApiClient.instance;

  tearDown(() {
    api.clearAuthToken();
  });

  test('coalesces concurrent and immediately repeated profile reads', () async {
    final adapter = _CountingAdapter({
      'GET /auth/profile': {
        'success': true,
        'data': {
          'id': 'teacher-user-1',
          'email': 'teacher@example.test',
          'role_name': 'teacher',
        },
      },
    });
    api.dio.httpClientAdapter = adapter;
    api.setAuthToken('test-token');
    api.setCurrentRole('teacher');
    api.setCurrentUserId('teacher-user-1');

    final concurrent = await Future.wait([api.getProfile(), api.getProfile()]);
    final immediate = await api.getProfile();

    expect(concurrent[0].id, 'teacher-user-1');
    expect(immediate.id, 'teacher-user-1');
    expect(adapter.requests, ['GET /auth/profile']);
  });

  test('persistent HTTP cache keys are isolated by authenticated user', () {
    api.setAuthToken('test-token');
    api.setCurrentRole('teacher');
    final request = RequestOptions(
      baseUrl: 'https://schooldesk.test/api/v1',
      path: '/dashboard/teacher',
      queryParameters: const {'page': 1},
    );

    api.setCurrentUserId('teacher-user-1');
    final firstTeacherKey = api.cacheKeyForRequest(request);
    api.setCurrentUserId('teacher-user-2');
    final secondTeacherKey = api.cacheKeyForRequest(request);

    expect(secondTeacherKey, isNot(firstTeacherKey));
  });

  test('refresh nonce updates the same user-scoped cache entry', () {
    api.setAuthToken('test-token');
    api.setCurrentRole('parent');
    api.setCurrentUserId('parent-user-1');
    final normalRequest = RequestOptions(
      baseUrl: 'https://schooldesk.test/api/v1',
      path: '/dashboard/parent',
    );
    final refreshRequest = RequestOptions(
      baseUrl: 'https://schooldesk.test/api/v1',
      path: '/dashboard/parent',
      queryParameters: const {'refresh_nonce': 123456},
    );

    expect(
      api.cacheKeyForRequest(refreshRequest),
      api.cacheKeyForRequest(normalRequest),
    );
  });
}

class _CountingAdapter implements HttpClientAdapter {
  _CountingAdapter(this.routes);

  final Map<String, Map<String, dynamic>> routes;
  final List<String> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final key = '${options.method.toUpperCase()} ${options.path}';
    requests.add(key);
    return ResponseBody.fromString(
      jsonEncode(routes[key]),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
