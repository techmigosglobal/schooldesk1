import 'dart:async';
import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:dio_cache_interceptor_hive_store/dio_cache_interceptor_hive_store.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

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
part 'api_modules/school_api.dart';
part 'api_modules/staff_api.dart';
part 'api_modules/users_api.dart';
part 'api_modules/students_api.dart';
part 'api_modules/attendance_api.dart';
part 'api_modules/events_api.dart';
part 'api_modules/fees_api.dart';
part 'api_modules/leave_api.dart';
part 'api_modules/communications_api.dart';
part 'api_modules/timetable_api.dart';
part 'api_modules/homework_api.dart';
part 'api_modules/tables_raw_api.dart';
part 'api_modules/approval_requests_api.dart';
part 'api_modules/monitoring_api.dart';

typedef ApiErrorReporter = void Function(DioException error);

/// Backend API client for school-desk backend
/// Handles all HTTP communication with the FastAPI backend.
class BackendApiClient {
  static BackendApiClient? _instance;
  static ApiErrorReporter? apiErrorReporter;
  late final Dio _dio;
  CacheOptions? _cacheOptions;
  bool _cacheInstalled = false;
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
      _ReadCacheOptionsInterceptor(this),
      _WriteCacheInvalidationInterceptor(this),
      _LoggingInterceptor(),
      _ErrorInterceptor(this),
    ]);
  }

  static BackendApiClient get instance {
    _instance ??= BackendApiClient._();
    return _instance!;
  }

  String get baseUrl => _dio.options.baseUrl;

  static Future<void> initialize() async {
    final client = instance;
    await client.installPersistentCache();
    final access = await TokenStorageService.getAccessToken();
    if (access != null && access.isNotEmpty) {
      client.setAuthToken(access);
      client.setCurrentRole(await TokenStorageService.getRoleName());
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

  Future<void> installPersistentCache() async {
    if (_cacheInstalled) return;
    try {
      final dir = await getApplicationSupportDirectory();
      final store = HiveCacheStore(p.join(dir.path, 'schooldesk_http_cache'));
      _cacheOptions = CacheOptions(
        store: store,
        policy: CachePolicy.forceCache,
        hitCacheOnErrorExcept: const [401, 403],
        maxStale: const Duration(minutes: 5),
        allowPostMethod: false,
      );
      _dio.interceptors.add(DioCacheInterceptor(options: _cacheOptions!));
      _cacheInstalled = true;
    } catch (error) {
      if (EnvConfig.enableLogging) {
        developer.log(
          '[API CACHE] Persistent cache disabled: $error',
          name: 'BackendApiClient',
        );
      }
    }
  }

  Future<void> invalidateAcademicSetupCache() =>
      _deleteCachedPaths(const [r'/academic-years', r'/dashboard/']);

  Future<void> invalidateStudentCache() =>
      _deleteCachedPaths(const [r'/students', r'/dashboard/']);

  Future<void> invalidateCachedReads() async {
    await _cacheOptions?.store?.clean();
  }

  Future<void> _deleteCachedPaths(List<String> pathPatterns) async {
    final store = _cacheOptions?.store;
    if (store == null) return;
    for (final pattern in pathPatterns) {
      await store.deleteFromPath(RegExp(pattern));
    }
  }

  List<Map<String, dynamic>> _asListMap(dynamic value) {
    if (value is! List) return [];
    return value
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  // ─── Error Handling ─────────────────────────────────────────────────────────

  Exception _handleError(DioException e) {
    final path = e.requestOptions.path.toLowerCase();
    if (!path.contains('/monitoring/error-events')) {
      apiErrorReporter?.call(e);
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

  Future<Map<String, dynamic>> bulkImport({
    required String importType,
    required String filePath,
    bool dryRun = true,
  }) async {
    try {
      final formData = FormData.fromMap({
        'import_type': importType,
        'dry_run': dryRun.toString(),
        'file': await MultipartFile.fromFile(filePath, filename: 'import.csv'),
      });
      final response = await _dio.post(
        '/principal/bulk-import',
        data: formData,
      );
      final data = _asMap(response.data);
      if (data['success'] == true) return _asMap(data['data']);
      throw ServerException(message: data['error'] ?? 'Bulk import failed');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getBulkImportHistory({
    String? importType,
    int limit = 20,
  }) async {
    try {
      final response = await _dio.get(
        '/principal/bulk-import/history',
        queryParameters: {
          if (importType != null) 'import_type': importType,
          'limit': limit,
        },
      );
      final data = _asMap(response.data);
      if (data['success'] == true) return _asMap(data['data']);
      throw ServerException(
        message: data['error'] ?? 'Failed to fetch import history',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }
}
