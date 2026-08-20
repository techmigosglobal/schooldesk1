import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io' show Platform;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:dio_cache_interceptor_hive_store/dio_cache_interceptor_hive_store.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:schooldesk1/core/config/env_config.dart';
import 'package:schooldesk1/core/errors/exceptions.dart';
import 'package:schooldesk1/features/shared/data/models/backend_models.dart';
import 'package:schooldesk1/features/communication/data/chat_models.dart';
import 'package:schooldesk1/core/network/generated/schooldesk_api_models.dart';
import 'package:schooldesk1/core/network/schooldesk_api.dart';
import 'package:schooldesk1/core/services/token_storage_service.dart';
import 'package:schooldesk1/core/services/demo_local_api_service.dart';
import 'package:schooldesk1/core/utils/event_post_media_parser.dart';
import 'package:schooldesk1/core/utils/image_upload_optimizer.dart';

export 'package:schooldesk1/features/shared/data/models/backend_models.dart';
part 'api_modules/auth_api.dart';
part 'api_modules/branches_api.dart';
part 'api_modules/client_interceptors.dart';
part 'api_modules/principal_api.dart';
part 'api_modules/school_api.dart';
part 'api_modules/staff_api.dart';
part 'api_modules/users_api.dart';
part 'api_modules/students_api.dart';
part 'api_modules/attendance_api.dart';
part 'api_modules/events_api.dart';
part 'api_modules/fees_api.dart';
part 'api_modules/fee_payments_api.dart';
part 'api_modules/leave_api.dart';
part 'api_modules/communications_api.dart';
part 'api_modules/timetable_api.dart';
part 'api_modules/homework_api.dart';
part 'api_modules/tables_raw_api.dart';
part 'api_modules/approval_requests_api.dart';
part 'api_modules/monitoring_api.dart';
part 'api_modules/notifications_api.dart';
part 'api_modules/help_api.dart';
part 'api_modules/issues_api.dart';
part 'api_modules/demo_api.dart';
part 'api_modules/request_coalescing.dart';

typedef ApiErrorReporter = void Function(DioException error);
const _forceRefreshCacheExtraKey = 'schooldesk_force_refresh_cache';

Future<MultipartFile> _multipartUpload({
  String? filePath,
  Uint8List? fileBytes,
  required String filename,
  DioMediaType? contentType,
}) async {
  if (fileBytes != null && fileBytes.isNotEmpty) {
    return MultipartFile.fromBytes(
      fileBytes,
      filename: filename,
      contentType: contentType,
    );
  }
  final path = (filePath ?? '').trim();
  if (path.isEmpty) {
    throw const ServerException(message: 'Upload file is required');
  }
  return MultipartFile.fromFile(
    path,
    filename: filename,
    contentType: contentType,
  );
}

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
        connectTimeout: const Duration(seconds: EnvConfig.apiTimeoutSeconds),
        receiveTimeout: const Duration(seconds: EnvConfig.apiTimeoutSeconds),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.addAll([
      _DemoLocalApiInterceptor(),
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
      client.setCurrentUserId(await TokenStorageService.getUserId());
      await client.setActiveBranchId(await TokenStorageService.getSchoolId());
    }
  }
  Dio get dio => _dio;
  String? _authToken;
  String? _currentRoleName;
  String? _currentUserId;
  String? _activeBranchId;
  UserResponse? _cachedProfile;
  Map<String, dynamic>? _cachedCurrentSchool;
  final Map<String, Map<String, dynamic>> _cachedDashboards = {};
  UserResponse? get cachedProfile => _cachedProfile;
  String? get currentRoleName => _currentRoleName;
  String? get currentUserId => _currentUserId;
  String? get activeBranchId => _activeBranchId;
  void setAuthToken(String token) => _authToken = token;

  void setCurrentRole(String? roleName) {
    final normalized = roleName?.trim();
    _currentRoleName = normalized?.isEmpty == true ? null : normalized;
  }

  void setCurrentUserId(String? userId) {
    final normalized = userId?.trim();
    final nextUserId = normalized?.isEmpty == true ? null : normalized;
    if (_currentUserId != nextUserId) {
      _cachedProfile = null;
      _cachedCurrentSchool = null;
      _cachedDashboards.clear();
      _clearCoalescedGets();
    }
    _currentUserId = nextUserId;
  }
  Future<void> setActiveBranchId(String? schoolId) async {
    final normalized = schoolId?.trim();
    _activeBranchId = normalized?.isEmpty == true ? null : normalized;
    if (_activeBranchId == null) {
      _dio.options.headers.remove('x-schooldesk-branch-id');
    } else {
      _dio.options.headers['x-schooldesk-branch-id'] = _activeBranchId;
      await TokenStorageService.saveSchoolId(_activeBranchId!);
    }
    _cachedCurrentSchool = null;
    _cachedDashboards.clear();
    _clearCoalescedGets();
    await invalidateCachedReads();
  }
  void clearAuthToken() {
    _authToken = null;
    _currentRoleName = null;
    _currentUserId = null;
    _cachedProfile = null;
    _cachedCurrentSchool = null;
    _cachedDashboards.clear();
    _clearCoalescedGets();
    _activeBranchId = null;
    _dio.options.headers.remove('x-schooldesk-branch-id');
  }
  void beginLocalDemoSession({
    required String role,
    required String userId,
    required String schoolId,
  }) {
    _authToken = 'local-demo-session';
    _currentRoleName = role.trim().toLowerCase();
    _currentUserId = userId;
    _activeBranchId = schoolId;
    _dio.options.headers['x-schooldesk-branch-id'] = schoolId;
  }
  bool get isAuthenticated => _authToken != null;

  Future<void> installPersistentCache() async {
    if (_cacheInstalled) return;
    try {
      final dir = await getApplicationSupportDirectory();
      final store = HiveCacheStore(p.join(dir.path, 'schooldesk_http_cache'));
      _cacheOptions = CacheOptions(
        store: store,
        keyBuilder: _authenticatedCacheKey,
        policy: CachePolicy.request,
        hitCacheOnErrorExcept: const [401, 403],
        maxStale: const Duration(days: 7),
        allowPostMethod: false,
      );
      _dio.interceptors.add(DioCacheInterceptor(options: _cacheOptions!));
      _cacheInstalled = true;
    } on Object catch (error) {
      if (EnvConfig.enableLogging) {
        developer.log(
          '[API CACHE] Persistent cache disabled: $error',
          name: 'BackendApiClient',
        );
      }
    }
  }

  Future<void> invalidateAcademicSetupCache() =>
      _invalidateReadMemoryAndDisk(const [r'/academic-years', r'/dashboard/']);
  Future<void> invalidateStudentCache() =>
      _invalidateReadMemoryAndDisk(const [r'/students', r'/dashboard/']);
  Future<void> invalidateCachedReads() async {
    _cachedCurrentSchool = null;
    _cachedDashboards.clear();
    _clearCoalescedGets();
    await _cacheOptions?.store?.clean();
  }
  Future<void> _invalidateReadMemoryAndDisk(List<String> pathPatterns) async {
    _cachedDashboards.clear();
    _clearCoalescedGets();
    await _deleteCachedPaths(pathPatterns);
  }

  Future<void> _deleteCachedPaths(List<String> pathPatterns) async {
    final store = _cacheOptions?.store;
    if (store == null) return;
    for (final pattern in pathPatterns) {
      await store.deleteFromPath(RegExp(pattern));
    }
  }
}
