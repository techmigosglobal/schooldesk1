import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:schooldesk1/core/offline/offline_database.dart';
import 'package:schooldesk1/core/offline/offline_sync_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/services/chat_workspace_connection.dart';
import 'package:schooldesk1/modules/communication/data/api_chat_workspace_repository.dart';
import 'package:schooldesk1/modules/communication/domain/chat_workspace_repository.dart';
import 'package:schooldesk1/core/services/notification_route_resolver.dart';
import 'package:schooldesk1/routes/app_routes.dart';

class _Transport implements ChatWorkspaceRealtimeTransport {
  @override
  Future<void> refreshAuth() async {}
  @override
  Future<ChatWorkspaceSubscription?> connect({
    required String conversationId,
    required void Function() onInvalidation,
    required void Function(ChatConnectionStatus) onStatus,
  }) async => null;
}

class _Sync extends OfflineSyncEngine {
  _Sync(OfflineDatabase database, BackendApiClient api)
    : super(database: database, api: api);
  @override
  Future<void> syncNow() async {}
}

class _Database extends OfflineDatabase {
  _Database() : super(NativeDatabase.memory());
  Completer<void>? persisted, release;

  @override
  Future<int> enqueueMutation({
    required String accountKey,
    required String operationType,
    required String method,
    required String path,
    required Map<String, dynamic> queryParameters,
    required Object? payload,
    required String idempotencyKey,
  }) async {
    final id = await super.enqueueMutation(
      accountKey: accountKey,
      operationType: operationType,
      method: method,
      path: path,
      queryParameters: queryParameters,
      payload: payload,
      idempotencyKey: idempotencyKey,
    );
    persisted?.complete();
    await release?.future;
    return id;
  }
}

class _Api implements HttpClientAdapter {
  final List<RequestOptions> calls = [];
  Completer<ResponseBody>? blocked;
  bool failure = false;
  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? body,
    Future<void>? cancel,
  ) async {
    calls.add(o);
    if (failure && o.path == '/chat/messages') {
      throw DioException(
        requestOptions: o,
        type: DioExceptionType.connectionError,
      );
    }
    if (blocked != null) {
      final pending = blocked!;
      blocked = null;
      return pending.future;
    }
    Object data = switch (o.path) {
      '/schools/current' => {'display_name': 'ArishVille PreSchool'},
      '/chat/contacts' => [
        {
          'id': 'teacher',
          'name': 'Ananya',
          'avatar_url': 'https://example.com/avatar.jpg',
        },
      ],
      '/chat/messages' => {
        'conversation': {'id': 'thread'},
        'message': {
          'id': 'message',
          'client_message_id': o.data['client_message_id'],
        },
        'duplicate': false,
      },
      '/chat/unread-count' => {'unread_count': 150},
      _ => {'data': [], 'has_more': false},
    };
    return response(data);
  }

  ResponseBody response(Object data) => ResponseBody.fromString(
    jsonEncode({'success': true, 'data': data}),
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late BackendApiClient api;
  late _Api transport;
  late ApiChatWorkspaceRepository repository;
  late _Database database;
  late _Sync sync;
  late List<Interceptor> productionInterceptors;
  setUpAll(() {
    productionInterceptors = BackendApiClient.instance.dio.interceptors
        .toList();
  });
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async => null,
        );
    api = BackendApiClient.instance;
    // Install this test's database before branch changes invalidate caches.
    // The singleton otherwise still points at the previous test's closed store.
    database = _Database();
    sync = _Sync(database, api);
    api.attachOfflineSync(sync);
    api.dio.interceptors.clear();
    transport = _Api();
    api.dio.httpClientAdapter = transport;
    api.setAuthToken('synthetic-chat-token');
    api.setCurrentUserId('parent-a');
    api.setCurrentRole('parent');
    await api.setActiveBranchId('school-a');
    repository = ApiChatWorkspaceRepository(
      api,
      connection: ChatWorkspaceConnection(
        transport: _Transport(),
        observeLifecycle: false,
      ),
    );
  });
  tearDown(() async {
    await repository.dispose();
    sync.dispose();
  });
  test(
    'atomic send keeps the same client identity and authorized context on retry',
    () async {
      const key = '00000000-0000-4000-8000-000000000011';
      const contact = {
        'type': 'parent_teacher',
        'parent_id': 'parent-a',
        'teacher_id': 'teacher-a',
        'student_id': 'child-a',
        'untrusted': 'not forwarded',
      };
      for (var i = 0; i < 2; i++) {
        final result = await repository.sendMessage(
          clientMessageId: key,
          body: 'Same message',
          contact: contact,
        );
        expect((result['message'] as Map)['client_message_id'], key);
      }
      final calls = transport.calls
          .where((o) => o.path == '/chat/messages')
          .toList();
      expect(calls.length, 2);
      expect(calls.every((o) => o.headers['Idempotency-Key'] == key), isTrue);
      expect(calls[0].data, calls[1].data);
      expect((calls[0].data as Map).containsKey('untrusted'), isFalse);
    },
  );
  test(
    'send intent is durable before the request and transport failure preserves the same UUID',
    () async {
      final blocked = Completer<ResponseBody>();
      transport.blocked = blocked;
      const key = '00000000-0000-4000-8000-000000000099';
      final sending = repository.sendMessage(
        clientMessageId: key,
        body: 'Durable message',
        conversationId: 'thread',
      );
      for (var i = 0; i < 100 && transport.calls.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
      final pending = await repository.pendingMessages();
      expect(pending.single['client_message_id'], key);
      blocked.complete(
        transport.response({
          'message': {'id': 'm', 'client_message_id': key},
          'conversation': {'id': 'thread'},
        }),
      );
      await sending;
      expect(await repository.pendingMessages(), isEmpty);
      transport.failure = true;
      const retryKey = '00000000-0000-4000-8000-000000000100';
      final result = await repository.sendMessage(
        clientMessageId: retryKey,
        body: 'Retryable',
        conversationId: 'thread',
      );
      expect(result['queued'], true);
      expect(
        (await repository.pendingMessages()).single['client_message_id'],
        retryKey,
      );
    },
  );
  test('account switch immediately invalidates old screen scope', () async {
    final event = Completer<void>();
    final subscription = repository.invalidations.listen((_) {
      if (!event.isCompleted) event.complete();
    });
    api.setCurrentUserId('new-parent');
    await event.future;
    expect(repository.accountScope, contains('new-parent'));
    await subscription.cancel();
  });
  test('account switch during outbox persistence prevents dispatch', () async {
    database.persisted = Completer<void>();
    database.release = Completer<void>();
    final sending = repository.sendMessage(
      clientMessageId: '00000000-0000-4000-8000-000000000101',
      body: 'Belongs to original account',
      conversationId: 'thread',
    );
    final assertion = expectLater(sending, throwsStateError);
    await database.persisted!.future;
    api.setCurrentUserId('new-parent');
    database.release!.complete();
    await assertion;
    expect(transport.calls.where((o) => o.path == '/chat/messages'), isEmpty);
  });
  test('auth interceptor rejects a stale dispatch scope', () async {
    api.dio.interceptors.add(
      productionInterceptors.firstWhere(
        (interceptor) =>
            interceptor.runtimeType.toString() == '_AuthInterceptor',
      ),
    );
    final scope = api.offlineAccountKey;
    api.setCurrentUserId('new-parent');
    await expectLater(
      api.dio.get<dynamic>(
        '/chat/conversations',
        options: Options(extra: {'schooldeskExpectedScope': scope}),
      ),
      throwsA(
        isA<DioException>().having(
          (e) => e.type,
          'cancelled before dispatch',
          DioExceptionType.cancel,
        ),
      ),
    );
    expect(transport.calls, isEmpty);
  });
  test(
    'cursor pages preserve tuple boundaries and intentionally bypass short read cache',
    () async {
      for (var i = 0; i < 2; i++) {
        await repository.loadMessages(
          conversationId: 'thread',
          mode: 'before',
          cursorSentAt: '2026-10-17T03:00:00Z',
          cursorId: 'message-50',
        );
      }
      final calls = transport.calls
          .where((o) => o.path.endsWith('/messages'))
          .toList();
      expect(calls.length, 2);
      expect(calls.first.queryParameters['cursor_mode'], 'before');
      expect(calls.first.queryParameters['cursor_id'], 'message-50');
      expect(calls.first.headers['Cache-Control'], 'no-store');
      await repository.markRead(
        conversationId: 'thread',
        throughSentAt: '2026-10-17T03:00:00Z',
        throughId: 'message-50',
      );
      expect(transport.calls.last.data, {
        'through_sent_at': '2026-10-17T03:00:00Z',
        'through_id': 'message-50',
      });
    },
  );
  test(
    'contacts retain real avatar and school branding; unread is not capped by first page',
    () async {
      final contacts = await repository.loadContacts(studentId: 'child-a');
      expect(contacts.single['avatar_url'], 'https://example.com/avatar.jpg');
      expect(contacts.single['school_name'], 'ArishVille PreSchool');
      expect(await repository.unreadCount(), 150);
    },
  );
  test('old account response cannot escape after account switch', () async {
    final blocked = Completer<ResponseBody>();
    transport.blocked = blocked;
    final pending = repository.loadMessages(conversationId: 'thread');
    await Future<void>.delayed(Duration.zero);
    api.setCurrentUserId('other-parent');
    blocked.complete(
      transport.response({
        'data': [
          {'body': 'private'},
        ],
      }),
    );
    await expectLater(pending, throwsStateError);
    await expectLater(repository.loadConversations(), throwsStateError);
  });
  for (final role in ['parent', 'teacher', 'principal', 'coordinator']) {
    test(
      '$role notification preserves exact conversation and authenticated role',
      () {
        final target = NotificationRouteResolver.resolve(
          data: {
            'reference_type': 'message',
            'reference_id': 'thread-200',
            'student_id': 'child',
            'role': 'super_admin',
          },
          currentRole: role,
        );
        expect(target.arguments, isA<Map>());
        expect((target.arguments as Map)['conversation_id'], 'thread-200');
        expect((target.arguments as Map)['role'], role);
        if (role == 'parent') {
          expect((target.arguments as Map)['student_id'], 'child');
        }
        expect(
          target.route,
          role == 'parent'
              ? AppRoutes.parentTeacherChat
              : role == 'teacher'
              ? AppRoutes.teacherCommunication
              : AppRoutes.communicationCenter,
        );
      },
    );
  }
}
