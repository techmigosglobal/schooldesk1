import 'dart:async';
import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'package:schooldesk1/core/config/env_config.dart';
import 'package:schooldesk1/core/errors/exceptions.dart';
import 'package:schooldesk1/features/shared/data/models/backend_models.dart';
import 'package:schooldesk1/core/network/generated/schooldesk_api_models.dart';
import 'package:schooldesk1/core/network/schooldesk_api.dart';
import 'package:schooldesk1/core/services/token_storage_service.dart';

export 'package:schooldesk1/features/shared/data/models/backend_models.dart';

part 'api_modules/auth_api.dart';
part 'api_modules/client_interceptors.dart';
part 'api_modules/principal_api.dart';
part 'api_modules/assistant_api.dart';
part 'api_modules/school_api.dart';
part 'api_modules/staff_api.dart';
part 'api_modules/users_api.dart';
part 'api_modules/students_api.dart';
part 'api_modules/attendance_api.dart';
part 'api_modules/exams_events_api.dart';
part 'api_modules/fees_api.dart';
part 'api_modules/leave_api.dart';
part 'api_modules/communications_api.dart';
part 'api_modules/timetable_api.dart';
part 'api_modules/homework_api.dart';
part 'api_modules/tables_raw_api.dart';
part 'api_modules/approval_requests_api.dart';

/// Backend API client for school-desk backend
/// Handles all HTTP communication with the Go backend
class BackendApiClient {
  static BackendApiClient? _instance;
  late final Dio _dio;
  Completer<bool>? _refreshCompleter;

  BackendApiClient._() {
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
      _AuthInterceptor(this),
      _LoggingInterceptor(),
      _ErrorInterceptor(this),
    ]);
  }

  static BackendApiClient get instance {
    _instance ??= BackendApiClient._();
    return _instance!;
  }

  static Future<void> initialize() async {
    final client = instance;
    final access = await TokenStorageService.getAccessToken();
    if (access != null && access.isNotEmpty) {
      client.setAuthToken(access);
      client.setCurrentRole(await TokenStorageService.getRoleName());
      await client.restoreStoredSession();
    }
  }

  Dio get dio => _dio;

  String? _authToken;
  String? _currentRoleName;

  String? get currentRoleName => _currentRoleName;

  void setAuthToken(String token) {
    _authToken = token;
  }

  void setCurrentRole(String? roleName) {
    final normalized = roleName?.trim();
    _currentRoleName = normalized == null || normalized.isEmpty
        ? null
        : normalized;
  }

  void clearAuthToken() {
    _authToken = null;
    _currentRoleName = null;
  }

  bool get isAuthenticated => _authToken != null;

  List<Map<String, dynamic>> _asListMap(dynamic value) {
    if (value is! List) return [];
    return value
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  // ─── Error Handling ─────────────────────────────────────────────────────────

  Exception _handleError(DioException e) {
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
