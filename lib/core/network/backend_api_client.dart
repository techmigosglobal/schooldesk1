import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io' show Platform;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show ChangeNotifier, kIsWeb;
import 'package:dio/dio.dart';
import 'package:schooldesk1/core/config/env_config.dart';
import 'package:schooldesk1/core/errors/exceptions.dart';
import 'package:schooldesk1/core/network/models/backend_models.dart';
import 'package:schooldesk1/features/communication/data/chat_models.dart';
import 'package:schooldesk1/core/network/generated/schooldesk_api_models.dart';
import 'package:schooldesk1/core/network/schooldesk_api.dart';
import 'package:schooldesk1/core/services/token_storage_service.dart';
import 'package:schooldesk1/core/utils/event_post_media_parser.dart';
import 'package:schooldesk1/core/utils/image_upload_optimizer.dart';
import 'package:schooldesk1/core/utils/secure_media_cache.dart';
import 'package:schooldesk1/core/offline/offline_sync_engine.dart';

export 'package:schooldesk1/core/network/models/backend_models.dart';
part 'api_modules/auth_api.dart';
part 'api_modules/branches_api.dart';
part 'api_modules/client_interceptors.dart';
part 'api_modules/principal_api.dart';
part 'api_modules/school_api.dart';
part 'api_modules/staff_api.dart';
part 'api_modules/users_api.dart';
part 'api_modules/students_api.dart';
part 'api_modules/attendance_api.dart';
part 'api_modules/attendance_offline_api.dart';
part 'api_modules/events_api.dart';
part 'api_modules/uploads_api.dart';
part 'api_modules/homework_offline_api.dart';
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
part 'api_modules/request_coalescing.dart';

typedef ApiErrorReporter = void Function(DioException error);
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

/// Session-aware transport notifier used by the typed router and Riverpod
/// composition root. Auth/role changes are navigation state changes, so the
/// router must be refreshed without relying on a periodic polling cycle.
class BackendApiClient extends ChangeNotifier {
  static BackendApiClient? _instance;
  static ApiErrorReporter? apiErrorReporter;
  late final Dio _dio;
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
      _AuthInterceptor(this),
      _WriteCacheInvalidationInterceptor(this),
      OfflineDioInterceptor(),
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
  void setAuthToken(String token) {
    if (_authToken == token) return;
    _authToken = token;
    notifyListeners();
  }

  void setCurrentRole(String? roleName) {
    final normalized = roleName?.trim();
    final nextRole = normalized?.isEmpty == true ? null : normalized;
    if (_currentRoleName == nextRole) return;
    _currentRoleName = nextRole;
    notifyListeners();
  }

  void setCurrentUserId(String? userId) {
    final previousScope = offlineAccountKey;
    final normalized = userId?.trim();
    final nextUserId = normalized?.isEmpty == true ? null : normalized;
    if (_currentUserId != nextUserId) {
      _cachedProfile = null;
      _cachedCurrentSchool = null;
      _cachedDashboards.clear();
      _clearCoalescedGets();
    }
    _currentUserId = nextUserId;
    final nextScope = offlineAccountKey;
    if (previousScope != nextScope && previousScope != 'anonymous') {
      unawaited(SecureSelectiveMediaCache.clearAccount(previousScope));
    }
    if (_currentUserId != null || nextUserId == null) notifyListeners();
  }

  Future<void> setActiveBranchId(String? schoolId) async {
    final previousScope = offlineAccountKey;
    final normalized = schoolId?.trim();
    final previousBranchId = _activeBranchId;
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
    final nextScope = offlineAccountKey;
    if (previousScope != nextScope && previousScope != 'anonymous') {
      unawaited(SecureSelectiveMediaCache.clearAccount(previousScope));
    }
    await invalidateCachedReads();
    unawaited(offlineSync?.syncNow() ?? Future<void>.value());
    if (previousBranchId != _activeBranchId) notifyListeners();
  }

  void clearAuthToken() {
    final hadSession =
        _authToken != null ||
        _currentRoleName != null ||
        _currentUserId != null ||
        _activeBranchId != null;
    final previousScope = offlineAccountKey;
    _authToken = null;
    _currentRoleName = null;
    _currentUserId = null;
    _cachedProfile = null;
    _cachedCurrentSchool = null;
    _cachedDashboards.clear();
    _clearCoalescedGets();
    _activeBranchId = null;
    _dio.options.headers.remove('x-schooldesk-branch-id');
    if (previousScope != 'anonymous') {
      unawaited(SecureSelectiveMediaCache.clearAccount(previousScope));
    }
    if (hadSession) notifyListeners();
  }

  bool get isAuthenticated => _authToken != null;

  Future<void> invalidateAcademicSetupCache() =>
      _invalidateReadMemoryAndDisk(const [r'/academic-years', r'/dashboard/']);
  Future<void> invalidateStudentCache() =>
      _invalidateReadMemoryAndDisk(const [r'/students', r'/dashboard/']);
  Future<void> invalidateCachedReads() async {
    _cachedCurrentSchool = null;
    _cachedDashboards.clear();
    _clearCoalescedGets();
  }

  Future<void> _invalidateReadMemoryAndDisk(List<String> pathPatterns) async {
    _cachedDashboards.clear();
    _clearCoalescedGets();
    await _deleteCachedPaths(pathPatterns);
  }

  Future<void> _deleteCachedPaths(List<String> pathPatterns) async {
    // Drift is the only durable cache. Its scoped invalidation is handled by
    // OfflineSyncEngine; this compatibility method remains until all legacy
    // API modules call repository invalidation directly.
  }
}
