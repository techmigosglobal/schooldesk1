import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/offline/offline_sync_engine.dart';
import 'package:schooldesk1/core/offline/offline_database.dart';
import 'package:schooldesk1/core/services/chat_draft_store.dart';
import 'package:schooldesk1/core/services/chat_workspace_connection.dart';
import 'package:schooldesk1/modules/communication/domain/chat_workspace_repository.dart';

/// Account-bound adapter for the redesigned chat. A stale screen cannot issue
/// requests under a newly signed-in account or a newly selected school.
class ApiChatWorkspaceRepository implements ChatWorkspaceRepository {
  ApiChatWorkspaceRepository(this.api, {ChatWorkspaceConnection? connection})
    : _boundScope = api.offlineAccountKey,
      currentUserId = api.currentUserId ?? '',
      currentRole = api.currentRoleName ?? '',
      _connection = connection ?? ChatWorkspaceConnection() {
    api.addListener(_accountChanged);
    _connectionEvents = _connection.invalidations.listen((_) {
      if (!_disposed) _signals.add(null);
    });
  }

  final BackendApiClient api;
  final ChatWorkspaceConnection _connection;
  @override
  String get accountScope => api.offlineAccountKey;
  final String _boundScope;
  final _signals = StreamController<void>.broadcast(sync: true);
  StreamSubscription<void>? _connectionEvents;
  bool _disposed = false;
  void _accountChanged() {
    if (!_disposed && accountScope != _boundScope) _signals.add(null);
  }

  @override
  final String currentUserId;
  @override
  final String currentRole;
  String _schoolName = '';
  Future<void>? _schoolLoad;

  static ApiChatWorkspaceRepository get legacyDefault =>
      ApiChatWorkspaceRepository(BackendApiClient.instance);

  void _checkScope() {
    if (_boundScope == 'anonymous' || api.offlineAccountKey != _boundScope) {
      throw StateError('Your account changed. Please reopen Messages.');
    }
  }

  Future<void> _loadSchool() => _schoolLoad ??= () async {
    try {
      final school = await api.getCurrentSchool();
      _checkScope();
      _schoolName = '${school['display_name'] ?? school['name'] ?? ''}'.trim();
    } on Object {
      // School branding cannot hide an otherwise valid conversation list.
    }
  }();

  Map<String, dynamic> _map(Object? value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  Map<String, dynamic> _contactContext(Map<String, dynamic> contact) {
    final normalized = <String, dynamic>{...contact};
    final contactRole = '${contact['role'] ?? ''}';
    final contactId = '${contact['id'] ?? ''}';
    if (currentRole == 'parent') {
      normalized['parent_id'] = currentUserId;
      if (contactRole == 'teacher') {
        normalized['teacher_id'] = contact['teacher_id'] ?? contactId;
      }
      if (contactRole == 'principal' || contactRole == 'coordinator') {
        normalized['leader_id'] = contact['leader_id'] ?? contactId;
      }
    } else if (currentRole == 'teacher') {
      normalized['teacher_id'] =
          contact['teacher_id'] ?? api.cachedProfile?.linkedId ?? '';
      if (contactRole == 'parent') {
        normalized['parent_id'] = contact['parent_id'] ?? contactId;
      }
      if (contactRole == 'principal' || contactRole == 'coordinator') {
        normalized['leader_id'] = contact['leader_id'] ?? contactId;
      }
    } else {
      normalized['leader_id'] = currentUserId;
      if (contactRole == 'teacher') {
        normalized['teacher_id'] = contact['teacher_id'] ?? contactId;
      }
      if (contactRole == 'parent') {
        normalized['parent_id'] = contact['parent_id'] ?? contactId;
      }
    }
    return normalized;
  }

  Map<String, dynamic> _conversation(Map<String, dynamic> row) => {
    ...row,
    for (final type in ['teacher', 'parent', 'leader', 'student'])
      if (row[type] is Map)
        type: {
          ..._map(row[type]),
          'name':
              '${_map(row[type])['name'] ?? [_map(row[type])['first_name'], _map(row[type])['last_name']].whereType<String>().where((s) => s.isNotEmpty).join(' ')}',
        },
  };

  Future<Map<String, dynamic>> _read(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    final response = await api.dio.get<dynamic>(
      path,
      queryParameters: query,
      options: Options(
        headers: {'Cache-Control': 'no-store'},
        extra: {'schooldeskExpectedScope': _boundScope},
      ),
    );
    _checkScope();
    final envelope = _map(response.data);
    if (envelope['success'] != true) {
      throw StateError('${envelope['error'] ?? 'Unable to refresh messages'}');
    }
    return _map(envelope['data']);
  }

  @override
  Future<List<Map<String, dynamic>>> loadChildren() async {
    _checkScope();
    final result = await api.getMyStudents();
    _checkScope();
    return result;
  }

  @override
  Future<List<Map<String, dynamic>>> loadContacts({
    String studentId = '',
  }) async {
    _checkScope();
    final response = await api.dio.get<dynamic>(
      '/chat/contacts',
      queryParameters: {
        'role': currentRole,
        if (studentId.isNotEmpty) 'student_id': studentId,
      },
      options: Options(
        headers: {'Cache-Control': 'no-store'},
        extra: {'schooldeskExpectedScope': _boundScope},
      ),
    );
    final envelope = _map(response.data);
    if (envelope['success'] != true) {
      throw StateError('${envelope['error'] ?? 'Unable to load contacts'}');
    }
    final result = (envelope['data'] as List? ?? const []).map(_map).toList();
    await _loadSchool();
    _checkScope();
    return result
        .map((row) => {..._contactContext(row), 'school_name': _schoolName})
        .toList();
  }

  @override
  Future<Map<String, dynamic>> loadConversations({
    bool monitor = false,
    String studentId = '',
    String search = '',
    String type = '',
    int page = 1,
    int pageSize = 50,
  }) async {
    _checkScope();
    final result = await _read(
      monitor ? '/chat/monitor' : '/chat/conversations',
      query: {
        'page': page,
        'page_size': pageSize,
        if (studentId.isNotEmpty) 'student_id': studentId,
        if (search.isNotEmpty) 'search': search,
        if (type.isNotEmpty) 'type': type,
      },
    );
    await _loadSchool();
    _checkScope();
    return {
      ...result,
      'school_name': _schoolName,
      'data': (result['data'] as List? ?? const [])
          .map(
            (row) => {..._conversation(_map(row)), 'school_name': _schoolName},
          )
          .toList(),
    };
  }

  @override
  Future<Map<String, dynamic>> loadConversation(String conversationId) async {
    _checkScope();
    final result = await _read(
      '/chat/conversations/${Uri.encodeComponent(conversationId)}',
    );
    _checkScope();
    return _conversation(result);
  }

  @override
  Future<Map<String, dynamic>> loadMessages({
    required String conversationId,
    String mode = 'latest',
    String cursorSentAt = '',
    String cursorId = '',
    int pageSize = 50,
  }) async {
    _checkScope();
    final result = await _read(
      '/chat/conversations/${Uri.encodeComponent(conversationId)}/messages',
      query: {
        'cursor_mode': mode,
        'page_size': pageSize,
        if (cursorSentAt.isNotEmpty) 'cursor_sent_at': cursorSentAt,
        if (cursorId.isNotEmpty) 'cursor_id': cursorId,
      },
    );
    _checkScope();
    return result;
  }

  @override
  Future<Map<String, dynamic>> sendMessage({
    required String clientMessageId,
    required String body,
    String conversationId = '',
    Map<String, dynamic> contact = const {},
  }) async {
    _checkScope();
    final normalized = _contactContext(contact);
    final payload = <String, dynamic>{
      'client_message_id': clientMessageId,
      'body': body,
      if (conversationId.isNotEmpty) 'conversation_id': conversationId,
      if (conversationId.isEmpty) ...{
        for (final key in [
          'type',
          'teacher_id',
          'parent_id',
          'student_id',
          'leader_id',
          'title',
        ])
          if ('${normalized[key] ?? ''}'.isNotEmpty) key: normalized[key],
      },
    };
    final sync = api.offlineSync;
    final database = sync?.database;
    if (database != null) {
      final existing =
          await (database.select(database.syncOutboxEntries)..where(
                (r) =>
                    r.accountKey.equals(_boundScope) &
                    r.idempotencyKey.equals(clientMessageId),
              ))
              .getSingleOrNull();
      if (existing != null) {
        final saved = _map(_map(jsonDecode(existing.payloadJson))['request']);
        if ('${saved['body']}' != body ||
            saved['client_message_id'] != clientMessageId) {
          throw StateError('This retry does not match the saved message.');
        }
        payload
          ..clear()
          ..addAll(saved);
      }
    }
    final localId = database == null
        ? null
        : await database.enqueueMutation(
            accountKey: _boundScope,
            operationType: 'message.compose',
            method: 'POST',
            path: '/chat/messages',
            queryParameters: {},
            payload: {'request': payload},
            idempotencyKey: clientMessageId,
          );
    if (localId != null) {
      await (database!.update(
        database.syncOutboxEntries,
      )..where((r) => r.id.equals(localId))).write(
        const SyncOutboxEntriesCompanion(
          status: Value('pending'),
          lastError: Value(null),
          nextAttemptAt: Value(null),
        ),
      );
    }
    try {
      // SQLite persistence can span an account/branch switch. Never dispatch
      // the saved compose intent with a different session's credentials.
      _checkScope();
      final response = await api.dio.post<dynamic>(
        '/chat/messages',
        data: payload,
        options: Options(
          headers: {'Idempotency-Key': clientMessageId},
          extra: {
            'schooldeskOfflineReplay': true,
            'schooldeskExpectedScope': _boundScope,
          },
        ),
      );
      final envelope = _map(response.data);
      if (envelope['success'] != true) {
        throw StateError('${envelope['error'] ?? 'Unable to send message'}');
      }
      if (localId != null) await database!.deleteMutation(localId);
      _checkScope();
      final result = _map(envelope['data']);
      if (result['conversation'] is Map) {
        result['conversation'] = _conversation(_map(result['conversation']));
      }
      return result;
    } on DioException catch (error) {
      final retryable =
          OfflineSyncEngine.isTransportFailure(error) ||
          error.response?.headers.value('Idempotency-Retryable') == 'true' ||
          (error.response?.statusCode ?? 0) >= 500;
      if (localId != null && retryable) {
        _checkScope();
        unawaited(sync!.syncNow());
        return {'queued': true, 'client_message_id': clientMessageId};
      }
      if (localId != null) {
        await database!.markMutationFailed(
          localId,
          '${error.response?.data ?? error.message}',
        );
      }
      rethrow;
    } on Object catch (error) {
      if (localId != null) {
        await database!.markMutationFailed(localId, '$error');
      }
      rethrow;
    }
  }

  @override
  Future<void> markRead({
    required String conversationId,
    String throughSentAt = '',
    String throughId = '',
  }) async {
    _checkScope();
    await api.dio.post<dynamic>(
      '/chat/conversations/${Uri.encodeComponent(conversationId)}/read',
      data: {
        if (throughSentAt.isNotEmpty) 'through_sent_at': throughSentAt,
        if (throughId.isNotEmpty) 'through_id': throughId,
      },
      options: Options(extra: {'schooldeskExpectedScope': _boundScope}),
    );
    _checkScope();
  }

  @override
  Future<int> unreadCount({bool monitor = false}) async {
    _checkScope();
    final result = await _read(
      '/chat/unread-count',
      query: {if (monitor) 'monitor': 'true'},
    );
    _checkScope();
    return int.tryParse('${result['unread_count'] ?? 0}') ?? 0;
  }

  @override
  Future<List<Map<String, dynamic>>> pendingMessages() async {
    _checkScope();
    final db = (api.offlineSync ?? OfflineSyncEngine.instance).database;
    final rows =
        await (db.select(db.syncOutboxEntries)..where(
              (row) =>
                  row.accountKey.equals(accountScope) &
                  row.operationType.equals('message.compose'),
            ))
            .get();
    _checkScope();
    return rows
        .where(
          (row) => const {'pending', 'failed', 'conflict'}.contains(row.status),
        )
        .map((row) {
          final metadata = _map(jsonDecode(row.payloadJson));
          final request = _map(metadata['request']);
          return {
            ...request,
            'client_message_id':
                request['client_message_id'] ?? row.idempotencyKey,
            'queued': row.status == 'pending',
            'status': row.status,
            'created_at': row.createdAt.toIso8601String(),
            'last_error': row.lastError,
          };
        })
        .toList();
  }

  @override
  Future<String> readDraft(String key) {
    _checkScope();
    return ChatDraftStore(
      (api.offlineSync ?? OfflineSyncEngine.instance).database,
    ).read(accountScope, key);
  }

  @override
  Future<void> saveDraft(String key, String body) {
    _checkScope();
    return ChatDraftStore(
      (api.offlineSync ?? OfflineSyncEngine.instance).database,
    ).write(accountScope, key, body);
  }

  @override
  Stream<void> get invalidations => _signals.stream;
  @override
  Stream<ChatConnectionStatus> get connectionChanges =>
      _connection.connectionChanges;
  @override
  Future<void> watch({String conversationId = ''}) {
    _checkScope();
    return _connection.watch(conversationId: conversationId);
  }

  @override
  Future<void> refreshConnection() {
    _checkScope();
    return _connection.refreshConnection();
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    api.removeListener(_accountChanged);
    await _connectionEvents?.cancel();
    await _connection.dispose();
    await _signals.close();
  }
}
