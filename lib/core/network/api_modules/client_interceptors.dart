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

// ─── Read Cache Interceptor ───────────────────────────────────────────────────

class _ReadCacheOptionsInterceptor extends Interceptor {
  final BackendApiClient _client;

  _ReadCacheOptionsInterceptor(this._client);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final cacheOptions = _client._cacheOptions;
    if (cacheOptions == null ||
        !_client.isAuthenticated ||
        options.method.toUpperCase() != 'GET' ||
        !_isCacheablePath(options.path)) {
      handler.next(options);
      return;
    }

    options.extra.addAll(
      cacheOptions
          .copyWith(maxStale: Nullable(_ttlForPath(options.path)))
          .toExtra(),
    );
    handler.next(options);
  }

  bool _isCacheablePath(String path) {
    final clean = path.toLowerCase();
    if (clean.contains('/auth/') ||
        clean.contains('/uploads') ||
        clean.contains('/payment-requests') ||
        clean.contains('/payments') ||
        clean.contains('/attendance/sessions') ||
        clean.contains('/attendance/staff/qr-token')) {
      return false;
    }
    return clean.contains('/dashboard/') ||
        clean.contains('/students') ||
        clean.contains('/staff') ||
        clean.contains('/schools') ||
        clean.contains('/academic-years') ||
        clean.contains('/grades') ||
        clean.contains('/sections') ||
        clean.contains('/subjects') ||
        clean.contains('/timetable') ||
        clean.contains('/homework') ||
        clean.contains('/lesson-planners') ||
        clean.contains('/fees/invoices') ||
        clean.contains('/fees/structures') ||
        clean.contains('/fees/categories') ||
        clean.contains('/fees/payment-config');
  }

  Duration _ttlForPath(String path) {
    final clean = path.toLowerCase();
    if (clean.contains('/academic-years') ||
        clean.contains('/grades') ||
        clean.contains('/sections') ||
        clean.contains('/subjects') ||
        clean.contains('/fees/payment-config')) {
      return const Duration(hours: 6);
    }
    if (clean.contains('/dashboard/')) return const Duration(minutes: 2);
    return const Duration(minutes: 5);
  }
}

// ─── Write Cache Invalidation Interceptor ────────────────────────────────────

class _WriteCacheInvalidationInterceptor extends Interceptor {
  final BackendApiClient _client;

  _WriteCacheInvalidationInterceptor(this._client);

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final method = response.requestOptions.method.toUpperCase();
    if (method == 'POST' ||
        method == 'PUT' ||
        method == 'PATCH' ||
        method == 'DELETE') {
      _client
          .invalidateCachedReads()
          .then((_) => handler.next(response))
          .catchError((_) => handler.next(response));
      return;
    }
    handler.next(response);
  }
}

// ─── Logging Interceptor ──────────────────────────────────────────────────────

class _LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra['requestStartedAt'] = DateTime.now().microsecondsSinceEpoch;
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
    final elapsed = _elapsedMs(response.requestOptions);
    if (EnvConfig.enableLogging) {
      developer.log(
        '[API] ${response.statusCode} ${response.requestOptions.path} ${elapsed}ms',
        name: 'BackendApiClient',
      );
      if (elapsed >= 1200) {
        developer.log(
          '[API SLOW] ${response.requestOptions.method} '
          '${response.requestOptions.path} took ${elapsed}ms',
          name: 'BackendApiClient',
        );
      }
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final elapsed = _elapsedMs(err.requestOptions);
    if (EnvConfig.enableLogging) {
      developer.log(
        '[API ERROR] ${err.response?.statusCode} ${err.requestOptions.path} ${elapsed}ms ${err.message}',
        name: 'BackendApiClient',
      );
    }
    handler.next(err);
  }

  int _elapsedMs(RequestOptions options) {
    final started = options.extra['requestStartedAt'];
    if (started is! int) return 0;
    return ((DateTime.now().microsecondsSinceEpoch - started) / 1000).round();
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

extension BackendClientHelpers on BackendApiClient {
  List<Map<String, dynamic>> _asListMap(dynamic value) {
    if (value is! List) return [];
    return value
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Exception _handleError(DioException e) {
    final path = e.requestOptions.path.toLowerCase();
    if (!path.contains('/monitoring/error-events')) {
      BackendApiClient.apiErrorReporter?.call(e);
    }
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout) {
      return const NetworkException(
        message: 'Unable to connect to server. Please check your connection.',
      );
    }
    if (e.response != null) {
      final statusCode = e.response!.statusCode ?? 0;
      final data = e.response!.data;
      final message = data is Map<String, dynamic>
          ? _serverErrorMessage(data)
          : 'Server error occurred.';
      final safeMessage = message.isEmpty ? 'Server error occurred.' : message;
      if (statusCode == 401) return AuthException(message: safeMessage);
      if (statusCode == 404) return NotFoundException(message: safeMessage);
      return ServerException(message: safeMessage, statusCode: statusCode);
    }
    return NetworkException(message: e.message ?? 'Network error occurred.');
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  int _asInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}') ?? fallback;
  }

  double _asDouble(dynamic value, {double fallback = 0}) {
    if (value is num) return value.toDouble();
    return double.tryParse('${value ?? ''}') ?? fallback;
  }

  String _trimmed(dynamic value) => value?.toString().trim() ?? '';

  String _firstNonEmpty(Iterable<dynamic> values) {
    for (final value in values) {
      final text = _trimmed(value);
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  String _serverErrorMessage(Map<String, dynamic> data) {
    final message = _firstNonEmpty([data['message']]);
    if (message.isNotEmpty) return message;
    final error = data['error'];
    if (error is String) return error.trim();
    if (error is Map) {
      return _firstNonEmpty([
        error['message'],
        error['details'],
        error['code'],
      ]);
    }
    return '';
  }
}
