import 'package:dio/dio.dart';

import '../../core/config/env_config.dart';
import '../../core/errors/exceptions.dart';

/// Configured Dio HTTP client — ready for backend integration.
/// Add interceptors for auth tokens, logging, and retry logic here.
class ApiClient {
  static ApiClient? _instance;
  late final Dio _dio;

  ApiClient._() {
    _dio = Dio(
      BaseOptions(
        baseUrl: EnvConfig.apiBaseUrl,
        connectTimeout: Duration(seconds: EnvConfig.apiTimeoutSeconds),
        receiveTimeout: Duration(seconds: EnvConfig.apiTimeoutSeconds),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.addAll([
      _AuthInterceptor(),
      _LoggingInterceptor(),
      _ErrorInterceptor(),
    ]);
  }

  static ApiClient get instance {
    _instance ??= ApiClient._();
    return _instance!;
  }

  Dio get dio => _dio;

  /// Sets the auth token for all subsequent requests.
  void setAuthToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  /// Clears the auth token (on logout).
  void clearAuthToken() {
    _dio.options.headers.remove('Authorization');
  }
}

/// Adds Authorization header from stored token.
class _AuthInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // Token injection handled by ApiClient.setAuthToken()
    handler.next(options);
  }
}

/// Logs requests and responses in development mode.
class _LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (EnvConfig.enableLogging) {
      // ignore: avoid_print
      print('[API] ${options.method} ${options.path}');
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (EnvConfig.enableLogging) {
      // ignore: avoid_print
      print('[API ERROR] ${err.response?.statusCode} ${err.message}');
    }
    handler.next(err);
  }
}

/// Converts DioException to typed AppExceptions.
class _ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        throw NetworkException(message: 'Request timed out. Please try again.');
      case DioExceptionType.connectionError:
        throw const NetworkException();
      case DioExceptionType.badResponse:
        final statusCode = err.response?.statusCode ?? 0;
        final message =
            err.response?.data?['message'] as String? ??
            'Server error occurred.';
        if (statusCode == 401) throw AuthException(message: message);
        if (statusCode == 404) throw NotFoundException(message: message);
        throw ServerException(message: message, statusCode: statusCode);
      default:
        throw NetworkException(
          message: err.message ?? 'Network error occurred.',
        );
    }
  }
}
