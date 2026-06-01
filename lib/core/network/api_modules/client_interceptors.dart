part of '../backend_api_client.dart';

// ─── Auth Interceptor ─────────────────────────────────────────────────────────

class _AuthInterceptor extends Interceptor {
  final BackendApiClient _client;

  _AuthInterceptor(this._client);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (_client._authToken != null) {
      options.headers['Authorization'] = 'Bearer ${_client._authToken}';
    }
    handler.next(options);
  }
}

// ─── Logging Interceptor ──────────────────────────────────────────────────────

class _LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (EnvConfig.enableLogging) {
      developer.log(
        '[API] ${options.method} ${options.path}',
        name: 'BackendApiClient',
      );
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (EnvConfig.enableLogging) {
      developer.log(
        '[API] ${response.statusCode} ${response.requestOptions.path}',
        name: 'BackendApiClient',
      );
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (EnvConfig.enableLogging) {
      developer.log(
        '[API ERROR] ${err.response?.statusCode} ${err.message}',
        name: 'BackendApiClient',
      );
    }
    handler.next(err);
  }
}

// ─── Error Interceptor ────────────────────────────────────────────────────────

class _ErrorInterceptor extends Interceptor {
  final BackendApiClient _client;

  _ErrorInterceptor(this._client);

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final statusCode = err.response?.statusCode ?? 0;
    final requestPath = err.requestOptions.path;
    final alreadyRetriedAfterRefresh =
        err.requestOptions.extra['retriedAfterRefresh'] == true;
    final isAuthRoute =
        requestPath.contains('/auth/login') ||
        requestPath.contains('/auth/refresh') ||
        requestPath.contains('/auth/logout') ||
        requestPath.contains('/auth/password');

    if (statusCode == 401 && !isAuthRoute) {
      if (alreadyRetriedAfterRefresh) {
        TokenStorageService.clear().then((_) {
          _client.clearAuthToken();
          handler.next(err);
        });
        return;
      }

      _client
          .refreshSession()
          .then((ok) async {
            if (!ok) {
              await TokenStorageService.clear();
              _client.clearAuthToken();
              handler.next(err);
              return;
            }
            try {
              final cloned = await _retry(
                err.requestOptions,
                _client._authToken!,
              );
              handler.resolve(cloned);
            } on DioException catch (retryErr) {
              if (retryErr.response?.statusCode == 401) {
                await TokenStorageService.clear();
                _client.clearAuthToken();
              }
              handler.next(retryErr);
            }
          })
          .catchError((_) {
            handler.next(err);
          });
      return;
    }
    handler.next(err);
  }

  Future<Response<dynamic>> _retry(
    RequestOptions requestOptions,
    String token,
  ) {
    final options = Options(
      method: requestOptions.method,
      headers: Map<String, dynamic>.from(requestOptions.headers)
        ..['Authorization'] = 'Bearer $token',
      responseType: requestOptions.responseType,
      contentType: requestOptions.contentType,
      validateStatus: requestOptions.validateStatus,
      receiveDataWhenStatusError: requestOptions.receiveDataWhenStatusError,
      followRedirects: requestOptions.followRedirects,
      extra: {...requestOptions.extra, 'retriedAfterRefresh': true},
    );
    return _client.dio.request<dynamic>(
      requestOptions.path,
      data: requestOptions.data,
      queryParameters: requestOptions.queryParameters,
      options: options,
    );
  }
}
