import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/offline/offline_database.dart';
import 'package:schooldesk1/core/offline/offline_sync_engine.dart';

class _RetryTimer implements Timer {
  _RetryTimer(this.delay, this.callback);
  final Duration delay;
  final void Function() callback;
  bool active = true;
  @override
  bool get isActive => active;
  @override
  int get tick => active ? 0 : 1;
  @override
  void cancel() => active = false;
  void fire() {
    if (!active) return;
    active = false;
    callback();
  }
}

class _Database extends OfflineDatabase {
  _Database() : super(NativeDatabase.memory());
  void Function()? duringReferences;
  @override
  Future<List<LocalFileUpload>> syncedFileUploads(String accountKey) async {
    final result = await super.syncedFileUploads(accountKey);
    final action = duringReferences;
    duringReferences = null;
    action?.call();
    return result;
  }
}

class _Adapter implements HttpClientAdapter {
  final List<RequestOptions> sends = [];
  int failures = 1;
  int failureStatus = 503;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? body,
    Future<void>? cancel,
  ) async {
    if (options.path == '/chat/messages') {
      sends.add(options);
      if (failures-- > 0) {
        return ResponseBody.fromString(
          '{"error":"try later"}',
          failureStatus,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      }
    }
    return ResponseBody.fromString(
      jsonEncode({'success': true, 'data': {}}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Future<void> _until(bool Function() condition) async {
  for (var attempt = 0; attempt < 200 && !condition(); attempt++) {
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
  expect(
    condition(),
    isTrue,
    reason: 'Replay did not reach its expected state',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Database db;
  late BackendApiClient api;
  late OfflineSyncEngine engine;
  late _Adapter adapter;
  late List<_RetryTimer> timers;
  late String scope;
  late int rowId;
  var disposed = false;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async => null,
        );
    db = _Database();
    api = BackendApiClient.instance;
    adapter = _Adapter();
    api.dio.interceptors.clear();
    api.dio.httpClientAdapter = adapter;
    timers = [];
    engine = OfflineSyncEngine(
      database: db,
      api: api,
      retryTimer: (delay, callback) {
        final timer = _RetryTimer(delay, callback);
        timers.add(timer);
        return timer;
      },
    );
    api.attachOfflineSync(engine);
    api.setAuthToken('synthetic-token');
    api.setCurrentUserId('teacher-a');
    api.setCurrentRole('teacher');
    await api.setActiveBranchId('school-a');
    await engine.syncNow();
    engine.didChangeAppLifecycleState(AppLifecycleState.resumed);
    scope = api.offlineAccountKey;
    rowId = await db.enqueueMutation(
      accountKey: scope,
      operationType: 'message.compose',
      method: 'POST',
      path: '/chat/messages',
      queryParameters: {},
      payload: {
        'request': {
          'conversation_id': 'thread-a',
          'body': 'Hello',
          'client_message_id': 'stable-message-id',
        },
      },
      idempotencyKey: 'stable-message-id',
    );
    disposed = false;
  });
  tearDown(() async {
    if (!disposed) engine.dispose();
    await Future<void>.delayed(Duration.zero);
  });

  Future<void> makeDue() =>
      (db.update(
        db.syncOutboxEntries,
      )..where((row) => row.id.equals(rowId))).write(
        SyncOutboxEntriesCompanion(
          nextAttemptAt: Value(
            DateTime.now().subtract(const Duration(seconds: 1)),
          ),
        ),
      );

  test(
    'deferred chat retries after due time with the same identity and scope',
    () async {
      await engine.syncNow();
      expect(adapter.sends, hasLength(1));
      expect(timers, hasLength(1));
      expect(
        timers.single.delay,
        greaterThanOrEqualTo(const Duration(seconds: 1)),
      );
      expect(
        timers.single.delay,
        lessThanOrEqualTo(const Duration(seconds: 2)),
      );
      expect(
        (await db.select(db.syncOutboxEntries).get()).single.status,
        'pending',
      );
      await makeDue();
      timers.single.fire();
      await _until(() => adapter.sends.length == 2 && !engine.isSyncing);
      expect(await db.select(db.syncOutboxEntries).get(), isEmpty);
      expect(adapter.sends[1].data, adapter.sends[0].data);
      expect(adapter.sends[1].headers['Idempotency-Key'], 'stable-message-id');
      expect(adapter.sends[1].extra['schooldeskExpectedScope'], scope);
      expect(timers.where((timer) => timer.isActive), isEmpty);
    },
  );

  test(
    'future retry waits instead of spinning when invoked before its due time',
    () async {
      await engine.syncNow();
      await (db.update(
        db.syncOutboxEntries,
      )..where((row) => row.id.equals(rowId))).write(
        SyncOutboxEntriesCompanion(
          nextAttemptAt: Value(DateTime.now().add(const Duration(minutes: 2))),
        ),
      );
      timers.single.fire();
      await _until(() => timers.length == 2);
      expect(adapter.sends, hasLength(1));
      expect(timers.last.delay, greaterThan(const Duration(minutes: 1)));
      expect(timers.where((timer) => timer.isActive), hasLength(1));
    },
  );

  test(
    'permanent rejection becomes failed without an automatic retry',
    () async {
      adapter.failureStatus = 403;
      await engine.syncNow();
      expect(
        (await db.select(db.syncOutboxEntries).get()).single.status,
        'failed',
      );
      expect(timers, isEmpty);
    },
  );

  for (final stop in ['account', 'background', 'dispose']) {
    test(
      '$stop cancels scheduled retry and blocks stale timer dispatch',
      () async {
        await engine.syncNow();
        final timer = timers.single;
        if (stop == 'account') {
          api.setCurrentUserId('teacher-b');
        } else if (stop == 'background') {
          engine.didChangeAppLifecycleState(AppLifecycleState.paused);
        } else {
          engine.dispose();
          disposed = true;
        }
        expect(timer.isActive, isFalse);
        // Even an already queued callback must obey its original generation.
        timer.callback();
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(adapter.sends, hasLength(1));
      },
    );
  }

  test('resume restores scheduling for a deferred pending message', () async {
    await engine.syncNow();
    engine.didChangeAppLifecycleState(AppLifecycleState.hidden);
    expect(timers.single.isActive, isFalse);
    engine.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await _until(() => timers.length == 2);
    expect(timers.last.isActive, isTrue);
  });

  test(
    'scope switch during reference resolution prevents network dispatch',
    () async {
      db.duringReferences = () => api.setCurrentUserId('teacher-b');
      await engine.syncNow();
      expect(adapter.sends, isEmpty);
      final saved = await db.select(db.syncOutboxEntries).get();
      expect(saved.single.accountKey, scope);
      expect(saved.single.status, 'pending');
      expect(timers, isEmpty);
    },
  );
}
