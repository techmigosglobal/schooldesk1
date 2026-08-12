import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';

void main() {
  final api = BackendApiClient.instance;

  tearDown(() {
    api.clearAuthToken();
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
