import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'package:schooldesk1/core/config/env_config.dart';
import 'package:schooldesk1/core/network/generated/schooldesk_api_client.dart';
import 'package:schooldesk1/core/services/token_storage_service.dart';

class SchoolDeskApi {
  SchoolDeskApi._() {
    dio = Dio(
      BaseOptions(
        baseUrl: EnvConfig.apiBaseUrl,
        connectTimeout: Duration(seconds: EnvConfig.apiTimeoutSeconds),
        receiveTimeout: Duration(seconds: EnvConfig.apiTimeoutSeconds),
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );
    dio.interceptors.addAll([
      _SchoolDeskAuthInterceptor(),
      _SchoolDeskRefreshInterceptor(this),
      if (kDebugMode) _SchoolDeskLogInterceptor(),
      _SchoolDeskErrorInterceptor(),
    ]);
    client = SchoolDeskApiClient(dio);
  }

  static final SchoolDeskApi instance = SchoolDeskApi._();

  late final Dio dio;
  late final SchoolDeskApiClient client;
  Completer<bool>? _refreshCompleter;

  Future<bool> refreshToken() async {
    if (_refreshCompleter != null) return _refreshCompleter!.future;
    _refreshCompleter = Completer<bool>();
    try {
      final refreshToken = await TokenStorageService.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        _refreshCompleter!.complete(false);
        return false;
      }
      final response = await Dio(
        BaseOptions(baseUrl: EnvConfig.apiBaseUrl),
      ).post('/auth/refresh', data: {'refresh_token': refreshToken});
      final data = response.data;
      if (data is! Map || data['data'] is! Map) {
        _refreshCompleter!.complete(false);
        return false;
      }
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

class _SchoolDeskAuthInterceptor extends Interceptor {
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

class _SchoolDeskRefreshInterceptor extends Interceptor {
  _SchoolDeskRefreshInterceptor(this.api);

  final SchoolDeskApi api;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final status = err.response?.statusCode;
    final alreadyRetried = err.requestOptions.extra['retried'] == true;
    if (status != 401 || alreadyRetried) {
      handler.next(err);
      return;
    }
    final refreshed = await api.refreshToken();
    if (!refreshed) {
      handler.next(err);
      return;
    }
    final token = await TokenStorageService.getAccessToken();
    final request = err.requestOptions;
    request.extra['retried'] = true;
    request.headers['Authorization'] = 'Bearer $token';
    try {
      handler.resolve(await api.dio.fetch<dynamic>(request));
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }
}

class _SchoolDeskLogInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    debugPrint('[SchoolDeskApi] ${options.method} ${options.uri}');
    handler.next(options);
  }
}

class _SchoolDeskErrorInterceptor extends Interceptor {
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
