import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'package:schooldesk1/core/config/env_config.dart';
import 'package:schooldesk1/core/network/generated/schooldesk_api_client.dart';
import 'package:schooldesk1/core/services/token_storage_service.dart';
import 'package:schooldesk1/core/offline/offline_sync_engine.dart';
import 'package:schooldesk1/core/auth/session_refresh_coordinator.dart';

class SchoolDeskApi {
  SchoolDeskApi._() {
    dio = Dio(
      BaseOptions(
        baseUrl: EnvConfig.apiBaseUrl,
        connectTimeout: const Duration(seconds: EnvConfig.apiTimeoutSeconds),
        receiveTimeout: const Duration(seconds: EnvConfig.apiTimeoutSeconds),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          ...EnvConfig.supabaseGatewayHeaders,
        },
      ),
    );
    dio.interceptors.addAll([
      _SchoolDeskAuthInterceptor(),
      OfflineDioInterceptor(),
      _SchoolDeskRefreshInterceptor(this),
      if (kDebugMode) _SchoolDeskLogInterceptor(),
      _SchoolDeskErrorInterceptor(),
    ]);
    client = SchoolDeskApiClient(dio);
  }

  static final SchoolDeskApi instance = SchoolDeskApi._();

  late final Dio dio;
  late final SchoolDeskApiClient client;
  Future<bool> refreshToken() async {
    final refreshed = await SessionRefreshCoordinator.instance.refresh(
      EnvConfig.apiBaseUrl,
    );
    if (!refreshed) await TokenStorageService.clear();
    return refreshed;
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
    // Legacy Retrofit calls must carry the same explicit branch scope as the
    // primary BackendApiClient. Without this, a branch switch leaves events,
    // homework, and generic resource calls on the server's default branch.
    final branch = await TokenStorageService.getSchoolId();
    if (branch != null && branch.trim().isNotEmpty) {
      options.headers['x-schooldesk-branch-id'] = branch.trim();
    } else {
      options.headers.remove('x-schooldesk-branch-id');
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
