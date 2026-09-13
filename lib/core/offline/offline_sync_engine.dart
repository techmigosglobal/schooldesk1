import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cross_file/cross_file.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/offline/offline_database.dart';

enum OfflineConnectionState { unknown, online, offline, syncing }

class OfflineQueuedUpload {
  const OfflineQueuedUpload({required this.localId, required this.placeholder});

  final String localId;
  final String placeholder;
}

/// Applies the same Drift cache and safe-write outbox contract to every Dio
/// transport in the app, including the Retrofit client used by legacy modules.
/// The engine is resolved lazily so tests and startup code can construct a Dio
/// client before authentication has been restored.
class OfflineDioInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.extra['schooldeskOfflineReplay'] != true &&
        (OfflineSyncEngine.isOfflineCapableWrite(options) ||
            _isIdempotentUpload(options)) &&
        !options.headers.containsKey('Idempotency-Key')) {
      options.headers['Idempotency-Key'] = _idempotencyKey(options);
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final sync = _engine;
    final request = response.requestOptions;
    if (sync != null && _isCacheableRead(request)) {
      unawaited(sync.cacheResponse(request: request, response: response));
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final sync = _engine;
    final request = err.requestOptions;

    if (sync != null &&
        request.method.toUpperCase() == 'GET' &&
        _isCacheableRead(request)) {
      final cached = await sync.readCachedResponse(request);
      if (cached != null) {
        handler.resolve(cached);
        return;
      }
    }

    if (sync != null &&
        request.extra['schooldeskOfflineReplay'] != true &&
        OfflineSyncEngine.isOfflineCapableWrite(request) &&
        OfflineSyncEngine.isTransportFailure(err)) {
      final key = request.headers['Idempotency-Key']?.toString().trim();
      final idempotencyKey = key == null || key.isEmpty
          ? _idempotencyKey(request)
          : key;
      final queued = await sync.enqueueRequest(
        request,
        idempotencyKey: idempotencyKey,
      );
      if (queued) {
        handler.resolve(
          Response<dynamic>(
            requestOptions: request,
            statusCode: 202,
            data: const {
              'success': true,
              'queued': true,
              'message': 'Saved offline and queued for sync',
              'data': <String, dynamic>{},
            },
            extra: const {'schooldeskOfflineQueued': true},
          ),
        );
        return;
      }
    }

    handler.next(err);
  }

  OfflineSyncEngine? get _engine {
    try {
      return OfflineSyncEngine.instance;
    } on StateError {
      return null;
    }
  }

  bool _isCacheableRead(RequestOptions request) {
    final clean = request.path.toLowerCase();
    if (clean.contains('/health') ||
        clean.contains('/uploads') ||
        // Payment-request reads can contain short-lived signed proof URLs;
        // keep those out of the generic cache. Historical payment/receipt
        // reads remain cacheable and are explicitly offline-capable.
        clean.contains('/payment-requests') ||
        clean.contains('/attendance/staff/qr-token') ||
        (clean.contains('/auth/') && !clean.contains('/auth/profile'))) {
      return false;
    }
    return request.method.toUpperCase() == 'GET';
  }

  String _idempotencyKey(RequestOptions request) {
    return 'schooldesk-${DateTime.now().microsecondsSinceEpoch}-${request.hashCode}';
  }

  bool _isIdempotentUpload(RequestOptions request) {
    return request.method.toUpperCase() == 'POST' &&
        request.data is FormData;
  }
}

/// Owns the durable read cache and ordered mutation replay.
///
/// Connectivity events only trigger a sync attempt. A successful API request
/// remains the source of truth because Wi-Fi/mobile connectivity does not
/// guarantee that the Edge API is reachable.
class OfflineSyncEngine extends ChangeNotifier {
  OfflineSyncEngine({
    required this.database,
    required this.api,
    Connectivity? connectivity,
  }) : _connectivity = connectivity ?? Connectivity();

  static OfflineSyncEngine? _instance;

  static Future<OfflineSyncEngine> initialize() async {
    final existing = _instance;
    if (existing != null) return existing;
    final engine = OfflineSyncEngine(
      database: OfflineDatabase.defaults(),
      api: BackendApiClient.instance,
    );
    _instance = engine;
    return engine;
  }

  static OfflineSyncEngine get instance {
    final value = _instance;
    if (value == null) {
      throw StateError('OfflineSyncEngine.initialize() must be called first.');
    }
    return value;
  }

  final OfflineDatabase database;
  final BackendApiClient api;
  final Connectivity _connectivity;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Future<void>? _syncFuture;
  bool _started = false;
  OfflineConnectionState _state = OfflineConnectionState.unknown;
  int _pendingMutationCount = 0;
  DateTime? _lastSyncedAt;
  String? _lastError;

  OfflineConnectionState get state => _state;
  bool get isOffline => _state == OfflineConnectionState.offline;
  bool get isSyncing => _state == OfflineConnectionState.syncing;
  int get pendingMutationCount => _pendingMutationCount;
  DateTime? get lastSyncedAt => _lastSyncedAt;
  String? get lastError => _lastError;

  String get accountKey => api.offlineAccountKey;

  /// Performs an uncached health request. Connectivity state and cached reads
  /// are only hints; callers that are about to replace role/branch scope must
  /// use this backend probe first.
  Future<bool> probeBackend() => _probeBackend();

  Future<void> start() async {
    if (_started) return;
    _started = true;
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((
      results,
    ) {
      if (results.every((result) => result == ConnectivityResult.none)) {
        _setState(OfflineConnectionState.offline);
        return;
      }
      unawaited(syncNow());
    });
    await _refreshPendingCount();
    await syncNow();
  }

  @override
  void dispose() {
    if (identical(_instance, this)) _instance = null;
    unawaited(_connectivitySubscription?.cancel() ?? Future<void>.value());
    unawaited(database.close());
    super.dispose();
  }

  Future<void> cacheResponse({
    required RequestOptions request,
    required Response<dynamic> response,
  }) async {
    if (!api.isAuthenticated || accountKey == 'anonymous') return;
    if (request.method.toUpperCase() != 'GET') return;
    if (!_isJsonValue(response.data)) return;

    final expiresAt = DateTime.now().toUtc().add(_ttlForPath(request.path));
    await database.saveCachedResponse(
      cacheKey: api.cacheKeyForRequest(request),
      accountKey: accountKey,
      method: request.method.toUpperCase(),
      path: request.path,
      queryParameters: request.queryParameters,
      body: response.data,
      statusCode: response.statusCode ?? 200,
      storedAt: DateTime.now().toUtc(),
      expiresAt: expiresAt,
    );
    if (_isStudentRead(request.path)) {
      await _cacheStudentRows(response.data);
    }
  }

  Future<Response<dynamic>?> readCachedResponse(RequestOptions request) async {
    if (!api.isAuthenticated || accountKey == 'anonymous') return null;
    final cached = await database.findCachedResponse(
      api.cacheKeyForRequest(request),
    );
    if (cached == null) return null;

    // A cache hit is useful data, but it is also evidence that the current
    // request did not reach the backend. Keep the status surface honest even
    // when there is no mutation waiting in the outbox.
    _setState(OfflineConnectionState.offline);
    Object? body;
    try {
      body = jsonDecode(cached.bodyJson);
    } on Object {
      return null;
    }

    return Response<dynamic>(
      requestOptions: request,
      data: body,
      statusCode: cached.statusCode,
      headers: Headers.fromMap({
        'x-schooldesk-offline-cache': ['true'],
        'x-schooldesk-cache-stored-at': [cached.storedAt.toIso8601String()],
      }),
      extra: {
        'schooldeskOfflineCache': true,
        'schooldeskCacheExpired':
            cached.expiresAt?.isBefore(DateTime.now()) ?? false,
      },
    );
  }

  Future<bool> enqueueRequest(
    RequestOptions request, {
    required String idempotencyKey,
  }) async {
    if (!api.isAuthenticated || accountKey == 'anonymous') return false;
    if (!_isJsonValue(request.data)) return false;

    final metadata = <String, dynamic>{
      'request': request.data,
      if (request.extra['offlineLocalId'] is String)
        'local_id': request.extra['offlineLocalId'],
      if (request.extra['offlineSessionLocalId'] is String)
        'session_local_id': request.extra['offlineSessionLocalId'],
      if (request.extra['offlineReferencePlaceholder'] is String)
        'reference_placeholder': request.extra['offlineReferencePlaceholder'],
      if (request.extra['offlineReferenceType'] is String)
        'reference_type': request.extra['offlineReferenceType'],
      if (request.extra['offlineResourceType'] is String)
        'resource_type': request.extra['offlineResourceType'],
    };
    await database.enqueueMutation(
      accountKey: accountKey,
      operationType: _operationType(request),
      method: request.method.toUpperCase(),
      path: request.path,
      queryParameters: request.queryParameters,
      payload: metadata,
      idempotencyKey: idempotencyKey,
    );
    _lastError = null;
    _setState(OfflineConnectionState.offline);
    await _refreshPendingCount();
    unawaited(syncNow());
    return true;
  }

  Future<void> syncNow() {
    final running = _syncFuture;
    if (running != null) return running;

    final future = _syncPendingMutations();
    _syncFuture = future;
    return future.whenComplete(() {
      if (identical(_syncFuture, future)) _syncFuture = null;
    });
  }

  Future<void> _syncPendingMutations() async {
    if (!api.isAuthenticated || accountKey == 'anonymous') {
      await _refreshPendingCount();
      return;
    }

    _lastError = null;
    _setState(OfflineConnectionState.syncing);
    if (!await _syncPendingUploads()) {
      await _refreshPendingCount();
      _setState(OfflineConnectionState.offline);
      await database.saveSyncState(
        accountKey,
        status: 'error',
        lastAttemptAt: DateTime.now().toUtc(),
        lastError: _lastError,
      );
      return;
    }

    final pending = await database.pendingMutations(accountKey);
    _pendingMutationCount = await database.pendingWorkCount(accountKey);
    notifyListeners();
    if (pending.isEmpty) {
      final outstanding = await database.pendingWorkCount(accountKey);
      if (outstanding == 0 && !await _probeBackend()) {
        _setState(OfflineConnectionState.offline);
        await database.saveSyncState(
          accountKey,
          status: 'offline',
          lastAttemptAt: DateTime.now().toUtc(),
          lastError: _lastError,
        );
        return;
      }
      final savedState = await database.findSyncState(accountKey);
      _lastError = outstanding == 0 ? null : savedState?.lastError;
      _setState(
        _lastError == null
            ? OfflineConnectionState.online
            : OfflineConnectionState.offline,
      );
      if (outstanding == 0 && _lastError == null) {
        _lastSyncedAt = DateTime.now().toUtc();
        await database.saveSyncState(
          accountKey,
          status: 'idle',
          lastAttemptAt: DateTime.now().toUtc(),
          lastSyncedAt: _lastSyncedAt,
          lastError: null,
        );
      }
      return;
    }

    // A later successful attempt must not inherit an error from a previous
    // transport failure. The outbox row itself is the source of truth for
    // whether work remains.
    await database.saveSyncState(
      accountKey,
      status: 'syncing',
      lastAttemptAt: DateTime.now().toUtc(),
      lastError: null,
    );

    for (final mutation in pending) {
      try {
        final metadata = jsonDecode(mutation.payloadJson);
        final requestData = metadata is Map && metadata['request'] != null
            ? metadata['request']
            : metadata;
        final resolvedPath =
            await _resolveQueuedReferences(mutation.path) as String;
        final resolvedRequestData = await _resolveQueuedReferences(requestData);
        if (_containsQueuedPlaceholder(resolvedPath) ||
            _containsQueuedPlaceholder(resolvedRequestData)) {
          throw StateError(
            'A queued mutation is waiting for a dependent upload or record.',
          );
        }
        final query = _decodeMap(mutation.queryJson);
        final response = await api.dio.request<dynamic>(
          resolvedPath,
          data: resolvedRequestData,
          queryParameters: query.isEmpty ? null : query,
          options: Options(
            method: mutation.method,
            headers: {'Idempotency-Key': mutation.idempotencyKey},
            extra: const {'schooldeskOfflineReplay': true},
          ),
        );
        final localId = metadata is Map ? metadata['local_id'] : null;
        if (localId is String && localId.isNotEmpty) {
          await database.updateAttendanceSyncStatus(
            accountKey,
            localId,
            'synced',
          );
        }
        final resourceType = metadata is Map
            ? metadata['resource_type']?.toString()
            : null;
        if (resourceType == 'homework' &&
            localId is String &&
            localId.isNotEmpty) {
          await database.updateHomeworkDraftSyncStatus(
            accountKey: accountKey,
            localId: localId,
            syncStatus: 'synced',
            serverId: _extractReferenceId(response.data),
          );
        }
        final sessionLocalId = metadata is Map
            ? metadata['session_local_id']
            : null;
        if (sessionLocalId is String && sessionLocalId.isNotEmpty) {
          await database.updateAttendanceSession(
            accountKey: accountKey,
            localId: sessionLocalId,
            syncStatus: 'synced',
          );
        }
        final referencePlaceholder = metadata is Map
            ? metadata['reference_placeholder']
            : null;
        if (referencePlaceholder is String && referencePlaceholder.isNotEmpty) {
          final remoteId = _extractReferenceId(response.data);
          if (remoteId.isEmpty) {
            throw StateError(
              'A queued record completed without a server identifier.',
            );
          }
          await database.saveSyncReference(
            accountKey: accountKey,
            placeholder: referencePlaceholder,
            referenceType: metadata['reference_type']?.toString() ?? 'record',
            remoteId: remoteId,
          );
          if (metadata['reference_type'] == 'attendance_session') {
            final localSessionId = metadata['session_local_id']?.toString();
            if (localSessionId != null && localSessionId.isNotEmpty) {
              await database.updateAttendanceSessionRemoteId(
                accountKey: accountKey,
                localId: localSessionId,
                remoteId: remoteId,
              );
            }
          }
        }
        await database.deleteMutation(mutation.id);
      } on DioException catch (error) {
        if (_isPermanentFailure(error)) {
          await database.markMutationFailed(mutation.id, _errorMessage(error));
          _lastError = _errorMessage(error);
        } else {
          await _deferMutation(mutation.id, mutation.retryCount, error);
          _lastError = _errorMessage(error);
        }
        break;
      } on Object catch (error) {
        await _deferMutation(mutation.id, mutation.retryCount, error);
        _lastError = error.toString();
        break;
      }
    }

    await _refreshPendingCount();
    final remaining = _pendingMutationCount;
    final successful = remaining == 0 && _lastError == null;
    if (successful) {
      _lastSyncedAt = DateTime.now().toUtc();
      _setState(OfflineConnectionState.online);
      await database.saveSyncState(
        accountKey,
        status: 'idle',
        lastAttemptAt: DateTime.now().toUtc(),
        lastSyncedAt: _lastSyncedAt,
        lastError: null,
      );
    } else {
      _setState(OfflineConnectionState.offline);
      await database.saveSyncState(
        accountKey,
        status: 'error',
        lastAttemptAt: DateTime.now().toUtc(),
        lastError: _lastError,
      );
    }
  }

  Future<void> _deferMutation(int id, int retryCount, Object error) {
    final nextRetry = retryCount + 1;
    final seconds = min(300, 1 << min(nextRetry, 8));
    return database.markMutationRetry(
      id,
      retryCount: nextRetry,
      error: _errorMessage(error),
      nextAttemptAt: DateTime.now().toUtc().add(Duration(seconds: seconds)),
    );
  }

  Future<void> _refreshPendingCount() async {
    if (!api.isAuthenticated || accountKey == 'anonymous') {
      _pendingMutationCount = 0;
    } else {
      _pendingMutationCount = await database.pendingWorkCount(accountKey);
    }
    notifyListeners();
  }

  Future<OfflineQueuedUpload?> enqueueFileUpload({
    required String path,
    required Map<String, dynamic> fields,
    required String fieldName,
    required String fileName,
    String? mimeType,
    String? filePath,
    Uint8List? fileBytes,
    String? idempotencyKey,
  }) async {
    if (!api.isAuthenticated || accountKey == 'anonymous') return null;
    if ((filePath ?? '').trim().isEmpty && fileBytes == null) return null;

    final localId =
        'upload-${DateTime.now().microsecondsSinceEpoch}-${path.hashCode.abs()}';
    final placeholder = 'schooldesk-upload://$localId';
    await database.enqueueFileUpload(
      localId: localId,
      accountKey: accountKey,
      method: 'POST',
      path: path,
      fields: fields,
      fieldName: fieldName,
      fileName: fileName,
      mimeType: mimeType,
      filePath: filePath,
      fileBytes: fileBytes,
      placeholder: placeholder,
      idempotencyKey: idempotencyKey?.trim().isNotEmpty == true
          ? idempotencyKey!.trim()
          : 'schooldesk-$localId',
    );
    _lastError = null;
    _setState(OfflineConnectionState.offline);
    await _refreshPendingCount();
    unawaited(syncNow());
    return OfflineQueuedUpload(localId: localId, placeholder: placeholder);
  }

  Future<bool> _syncPendingUploads() async {
    final uploads = await database.pendingFileUploads(accountKey);
    for (final upload in uploads) {
      try {
        final bytes =
            upload.fileBytes ??
            await XFile(upload.filePath ?? '').readAsBytes();
        if (bytes.isEmpty) throw StateError('Queued upload is empty.');
        final fields = _decodeMap(upload.fieldsJson);
        fields[upload.fieldName] = MultipartFile.fromBytes(
          bytes,
          filename: upload.fileName,
          contentType: upload.mimeType == null
              ? null
              : DioMediaType.parse(upload.mimeType!),
        );
        final response = await api.dio.request<dynamic>(
          upload.path,
          data: FormData.fromMap(fields),
          options: Options(
            method: upload.method,
            headers: {'Idempotency-Key': upload.idempotencyKey},
            extra: const {'schooldeskOfflineReplay': true},
          ),
        );
        final privateUpload = _isPrivateUpload(fields);
        // Private responses expose both a short-lived signed `url` and the
        // durable storage `path` (Supabase bucket path or r2:// reference).
        // Dependent mutations must keep the durable reference, otherwise a
        // queued document would start failing as soon as its signed URL
        // expires. Public media continues to use its browser-ready URL.
        final remoteUrl = _extractUploadUrl(
          response.data,
          preferPath: privateUpload,
        );
        if (remoteUrl.isEmpty) {
          throw StateError('Upload completed without a remote URL.');
        }
        await database.markFileUploadSynced(
          upload.localId,
          accountKey,
          remoteUrl,
        );
      } on DioException catch (error) {
        await _recordUploadFailure(upload, error);
        return false;
      } on Object catch (error) {
        await _recordUploadFailure(upload, error);
        return false;
      }
    }
    return true;
  }

  Future<void> _recordUploadFailure(LocalFileUpload upload, Object error) {
    final message = _errorMessage(error);
    _lastError = message;
    if (error is DioException && _isPermanentFailure(error)) {
      return database.markFileUploadFailed(upload.localId, accountKey, message);
    }
    final nextRetry = upload.retryCount + 1;
    final seconds = min(300, 1 << min(nextRetry, 8));
    return database.markFileUploadRetry(
      upload.localId,
      accountKey: accountKey,
      retryCount: nextRetry,
      error: message,
      nextAttemptAt: DateTime.now().toUtc().add(Duration(seconds: seconds)),
    );
  }

  Future<Object?> _resolveQueuedReferences(Object? value) async {
    final uploads = await database.syncedFileUploads(accountKey);
    final replacements = {
      for (final upload in uploads)
        if (upload.remoteUrl != null && upload.remoteUrl!.isNotEmpty)
          upload.placeholder: upload.remoteUrl!,
    };
    final references = await database.syncReferencesForAccount(accountKey);
    for (final reference in references) {
      replacements[reference.placeholder] = reference.remoteId;
    }
    Object? resolve(Object? current) {
      if (current is String) {
        var resolved = current;
        for (final entry in replacements.entries) {
          resolved = resolved.replaceAll(entry.key, entry.value);
        }
        return resolved;
      }
      if (current is List) return current.map(resolve).toList();
      if (current is Map) {
        return current.map((key, item) => MapEntry(key, resolve(item)));
      }
      return current;
    }

    return resolve(value);
  }

  bool _containsQueuedPlaceholder(Object? value) {
    if (value is String) {
      return value.contains('schooldesk-upload://') ||
          value.contains('schooldesk-reference-');
    }
    if (value is List) return value.any(_containsQueuedPlaceholder);
    if (value is Map) return value.values.any(_containsQueuedPlaceholder);
    return false;
  }

  String _extractReferenceId(Object? value) {
    if (value is Map) {
      final direct = value['id'];
      if (direct is String && direct.trim().isNotEmpty) return direct.trim();
      final nested = value['data'];
      final nestedId = _extractReferenceId(nested);
      if (nestedId.isNotEmpty) return nestedId;
      for (final child in value.values) {
        final childId = _extractReferenceId(child);
        if (childId.isNotEmpty) return childId;
      }
    } else if (value is List) {
      for (final child in value) {
        final childId = _extractReferenceId(child);
        if (childId.isNotEmpty) return childId;
      }
    }
    return '';
  }

  bool _isPrivateUpload(Map<String, dynamic> fields) {
    final value = '${fields['private'] ?? ''}'.trim().toLowerCase();
    return value == 'true' || value == '1' || value == 'yes';
  }

  String _extractUploadUrl(Object? value, {bool preferPath = false}) {
    if (value is Map) {
      final keys = preferPath
          ? const ['path', 'file_url', 'url', 'avatar', 'public_url']
          : const ['url', 'avatar', 'file_url', 'public_url', 'path'];
      for (final key in keys) {
        final candidate = value[key];
        if (candidate is String && candidate.trim().isNotEmpty) {
          return candidate.trim();
        }
      }
      for (final child in value.values) {
        final found = _extractUploadUrl(child, preferPath: preferPath);
        if (found.isNotEmpty) return found;
      }
    } else if (value is List) {
      for (final child in value) {
        final found = _extractUploadUrl(child, preferPath: preferPath);
        if (found.isNotEmpty) return found;
      }
    }
    return '';
  }

  Future<void> _cacheStudentRows(Object? value) async {
    final rows = _listFromEnvelope(value);
    for (final row in rows) {
      final id = '${row['id'] ?? row['student_id'] ?? ''}'.trim();
      if (id.isEmpty) continue;
      final section = row['section'] is Map
          ? Map<String, dynamic>.from(row['section'] as Map)
          : const <String, dynamic>{};
      final name = '${row['full_name'] ?? row['name'] ?? ''}'.trim().isNotEmpty
          ? '${row['full_name'] ?? row['name']}'.trim()
          : [row['first_name'], row['last_name']]
                .map((part) => '$part'.trim())
                .where((part) => part.isNotEmpty && part != 'null')
                .join(' ');
      if (name.isEmpty) continue;
      final updatedAt = DateTime.tryParse(
        '${row['updated_at'] ?? row['updatedAt'] ?? ''}',
      );
      final version = row['server_version'] is num
          ? (row['server_version'] as num).toInt()
          : int.tryParse('${row['server_version'] ?? ''}');
      await database.saveStudentSnapshot(
        accountKey: accountKey,
        serverId: id,
        schoolId: api.activeBranchId,
        fullName: name,
        sectionId: '${row['section_id'] ?? section['id'] ?? ''}'.trim(),
        className: '${row['class'] ?? row['grade_name'] ?? ''}'.trim(),
        sectionName: '${row['section_name'] ?? section['name'] ?? ''}'.trim(),
        status: '${row['status'] ?? 'active'}',
        updatedAt: updatedAt,
        serverVersion: version,
        rawJson: row,
      );
    }
  }

  List<Map<String, dynamic>> _listFromEnvelope(Object? value) {
    if (value is List) {
      return value.whereType<Map>().map(Map<String, dynamic>.from).toList();
    }
    if (value is Map) {
      final map = Map<String, dynamic>.from(value);
      for (final key in const ['data', 'students', 'items', 'results']) {
        final nested = map[key];
        if (nested is List) {
          return nested
              .whereType<Map>()
              .map(Map<String, dynamic>.from)
              .toList();
        }
      }
    }
    return const [];
  }

  bool _isStudentRead(String path) {
    final clean = path.toLowerCase();
    return clean == '/students' ||
        clean.startsWith('/students/') ||
        clean.startsWith('/parent/students/');
  }

  void _setState(OfflineConnectionState next) {
    if (_state == next) {
      notifyListeners();
      return;
    }
    _state = next;
    notifyListeners();
  }

  Duration _ttlForPath(String path) {
    final clean = path.toLowerCase();
    if (clean.contains('/academic-years') ||
        clean.contains('/grades') ||
        clean.contains('/sections') ||
        clean.contains('/subjects')) {
      return const Duration(days: 30);
    }
    if (clean.contains('/attendance/')) return const Duration(hours: 6);
    if (clean.contains('/fees/')) return const Duration(hours: 12);
    return const Duration(days: 7);
  }

  String _operationType(RequestOptions request) {
    final path = request.path.toLowerCase();
    if (path == '/attendance/sessions') return 'attendance.session.create';
    if (path == '/attendance' || path.startsWith('/attendance/')) {
      return 'attendance.submit';
    }
    if (path.contains('/homework')) return 'homework.draft';
    if (path == '/diary-entries' || path.startsWith('/diary-entries/')) {
      return 'teacher-note.save';
    }
    if (path.contains('/chat/') && path.endsWith('/messages')) {
      return 'message.compose';
    }
    return '${request.method.toLowerCase()}.${request.path}';
  }

  static bool isOfflineCapableWrite(RequestOptions request) {
    final method = request.method.toUpperCase();
    if (method != 'POST' && method != 'PUT' && method != 'PATCH') return false;
    final path = request.path.toLowerCase();
    if (path == '/attendance' ||
        path == '/attendance/sessions' ||
        RegExp(r'^/attendance/[^/]+$').hasMatch(path) ||
        RegExp(r'^/attendance/sessions/[^/]+/mark$').hasMatch(path)) {
      return true;
    }
    if ((path == '/homework' || RegExp(r'^/homework/[^/]+$').hasMatch(path)) &&
        request.data is Map) {
      final data = Map<String, dynamic>.from(request.data as Map);
      return '${data['status'] ?? ''}'.toLowerCase() == 'draft';
    }
    if (path == '/diary-entries' || path.startsWith('/diary-entries/')) {
      return true;
    }
    if (path.contains('/chat/') && path.endsWith('/messages')) return true;
    return false;
  }

  static bool isTransportFailure(DioException error) {
    return switch (error.type) {
      DioExceptionType.connectionError ||
      DioExceptionType.connectionTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.badCertificate => true,
      _ => false,
    };
  }

  bool _isPermanentFailure(DioException error) {
    final status = error.response?.statusCode;
    return status == 401 || status == 403 || status == 409 || status == 422;
  }

  String _errorMessage(Object error) {
    if (error is DioException) {
      return error.response?.data is Map
          ? '${(error.response!.data as Map)['error'] ?? error.message}'
          : (error.message ?? error.toString());
    }
    return error.toString();
  }

  Future<bool> _probeBackend() async {
    try {
      final response = await api.dio.get<dynamic>(
        '/health',
        options: Options(extra: const {'schooldeskConnectivityProbe': true}),
      );
      final status = response.statusCode ?? 0;
      if (status >= 200 && status < 300) return true;
      _lastError = 'Backend health check returned HTTP $status';
      return false;
    } on Object catch (error) {
      _lastError = _errorMessage(error);
      return false;
    }
  }

  Map<String, dynamic> _decodeMap(String value) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } on Object {
      // The mutation remains queued and will be retried after the next app
      // update rather than being discarded because of malformed metadata.
    }
    return const {};
  }

  bool _isJsonValue(Object? value) {
    if (value == null || value is String || value is num || value is bool) {
      return true;
    }
    if (value is List) return value.every(_isJsonValue);
    if (value is Map) {
      return value.keys.every((key) => key is String) &&
          value.values.every(_isJsonValue);
    }
    return false;
  }
}
