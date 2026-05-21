import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/api_config.dart';
import 'token_storage_service.dart';

class ApiService {
  ApiService._() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );
    _dio.interceptors.addAll([
      _AuthInterceptor(),
      _RefreshInterceptor(this),
      if (kDebugMode) _DebugLogInterceptor(),
      _ErrorParserInterceptor(),
    ]);
  }

  static final ApiService instance = ApiService._();

  late final Dio _dio;
  Completer<bool>? _refreshCompleter;

  Dio get dio => _dio;

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) {
    return _dio.get<T>(path, queryParameters: queryParameters);
  }

  Future<Response<T>> post<T>(String path, {Object? data}) {
    return _dio.post<T>(path, data: data);
  }

  Future<Response<T>> patch<T>(String path, {Object? data}) {
    return _dio.patch<T>(path, data: data);
  }

  Future<Response<T>> delete<T>(String path) {
    return _dio.delete<T>(path);
  }

  Future<bool> refreshToken() async {
    if (_refreshCompleter != null) {
      return _refreshCompleter!.future;
    }
    _refreshCompleter = Completer<bool>();
    try {
      final refreshToken = await TokenStorageService.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        _refreshCompleter!.complete(false);
        return false;
      }
      final response = await Dio(
        BaseOptions(baseUrl: ApiConfig.baseUrl),
      ).post('/auth/refresh', data: {'refresh_token': refreshToken});
      final data = Map<String, dynamic>.from(response.data as Map);
      final payload = Map<String, dynamic>.from(data['data'] as Map);
      await TokenStorageService.saveTokens(
        accessToken: payload['token'].toString(),
        refreshToken: payload['refresh_token'].toString(),
      );
      _refreshCompleter!.complete(true);
      return true;
    } catch (_) {
      await TokenStorageService.clear();
      _refreshCompleter!.complete(false);
      return false;
    } finally {
      _refreshCompleter = null;
    }
  }
}

class _AuthInterceptor extends Interceptor {
  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await TokenStorageService.getAccessToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
}

class _RefreshInterceptor extends Interceptor {
  _RefreshInterceptor(this._service);

  final ApiService _service;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final status = err.response?.statusCode;
    final alreadyRetried = err.requestOptions.extra['retried'] == true;
    if (status != 401 || alreadyRetried) {
      handler.next(err);
      return;
    }
    final refreshed = await _service.refreshToken();
    if (!refreshed) {
      handler.next(err);
      return;
    }
    final token = await TokenStorageService.getAccessToken();
    final request = err.requestOptions;
    request.extra['retried'] = true;
    request.headers['Authorization'] = 'Bearer $token';
    try {
      final response = await _service.dio.fetch<dynamic>(request);
      handler.resolve(response);
    } on DioException catch (retryErr) {
      handler.next(retryErr);
    }
  }
}

class _DebugLogInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    debugPrint('[API] ${options.method} ${options.uri}');
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    debugPrint('[API] ${response.statusCode} ${response.requestOptions.uri}');
    handler.next(response);
  }
}

class _ErrorParserInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final data = err.response?.data;
    if (data is Map) {
      final message = data['message'] ?? data['error'];
      if (message != null) {
        handler.next(
          DioException(
            requestOptions: err.requestOptions,
            response: err.response,
            type: err.type,
            error: message.toString(),
          ),
        );
        return;
      }
    }
    handler.next(err);
  }
}
