import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schooldesk1/core/services/chat_workspace_connection.dart';
import 'package:schooldesk1/core/services/chat_unread_service.dart';
import 'package:schooldesk1/modules/communication/domain/chat_workspace_repository.dart';

class _Timer implements ChatWorkspaceTimer {
  _Timer(this.at, this.callback, this.period);
  int at;
  final VoidCallback callback;
  final int? period;
  bool cancelled = false;
  @override
  void cancel() => cancelled = true;
}

class _Scheduler implements ChatWorkspaceScheduler {
  int now = 0;
  final timers = <_Timer>[];
  @override
  ChatWorkspaceTimer oneShot(Duration delay, VoidCallback callback) {
    final timer = _Timer(now + delay.inMilliseconds, callback, null);
    timers.add(timer);
    return timer;
  }

  @override
  ChatWorkspaceTimer periodic(Duration delay, VoidCallback callback) {
    final timer = _Timer(
      now + delay.inMilliseconds,
      callback,
      delay.inMilliseconds,
    );
    timers.add(timer);
    return timer;
  }

  void advance(int milliseconds) {
    final target = now + milliseconds;
    while (true) {
      final pending =
          timers
              .where((timer) => !timer.cancelled && timer.at <= target)
              .toList()
            ..sort((a, b) => a.at.compareTo(b.at));
      if (pending.isEmpty) break;
      final timer = pending.first;
      now = timer.at;
      if (timer.period == null) {
        timer.cancelled = true;
      } else {
        timer.at += timer.period!;
      }
      timer.callback();
    }
    now = target;
  }
}

class _Subscription implements ChatWorkspaceSubscription {
  bool closed = false;
  @override
  Future<void> close() async {
    closed = true;
  }
}

class _Attempt {
  _Attempt(this.id, this.invalidate, this.status);
  final String id;
  final VoidCallback invalidate;
  final void Function(ChatConnectionStatus) status;
  final subscription = _Subscription();
}

class _Transport implements ChatWorkspaceRealtimeTransport {
  final attempts = <_Attempt>[];
  int authRefreshes = 0;
  bool fail = false;
  Completer<ChatWorkspaceSubscription?>? pending;
  @override
  Future<void> refreshAuth() async {
    authRefreshes++;
  }

  @override
  Future<ChatWorkspaceSubscription?> connect({
    required String conversationId,
    required VoidCallback onInvalidation,
    required void Function(ChatConnectionStatus) onStatus,
  }) async {
    final attempt = _Attempt(conversationId, onInvalidation, onStatus);
    attempts.add(attempt);
    if (fail) onStatus(ChatConnectionStatus.offline);
    if (pending != null) return pending!.future;
    return attempt.subscription;
  }
}

class _SyncSource extends ChangeNotifier implements ChatWorkspaceSyncSource {
  @override
  ChatWorkspaceSyncState snapshot = const ChatWorkspaceSyncState(
    accountKey: 'account',
    reachable: false,
    pendingCount: 2,
  );
  void emit(ChatWorkspaceSyncState next) {
    snapshot = next;
    notifyListeners();
  }
}

Future<void> _flush() => Future<void>.delayed(Duration.zero);

void main() {
  test(
    'burst invalidations deliver the final event after 200ms silence',
    () async {
      final scheduler = _Scheduler();
      final transport = _Transport();
      final connection = ChatWorkspaceConnection(
        transport: transport,
        scheduler: scheduler,
        scopeKey: () => 'teacher|school',
        authenticated: () => true,
        observeLifecycle: false,
      );
      var invalidations = 0;
      connection.invalidations.listen((_) => invalidations++);
      await connection.watch(conversationId: 'thread-1');
      transport.attempts.single.status(ChatConnectionStatus.connected);
      await _flush();
      invalidations = 0;
      transport.attempts.single.invalidate();
      scheduler.advance(100);
      transport.attempts.single.invalidate();
      scheduler.advance(199);
      await _flush();
      expect(invalidations, 0);
      scheduler.advance(1);
      await _flush();
      expect(invalidations, 1);
      scheduler.advance(10000);
      await _flush();
      expect(invalidations, 1, reason: 'healthy connections do not poll');
      await connection.dispose();
    },
  );

  test(
    'retries back off, polling catches failures, pause cancels all work',
    () async {
      final scheduler = _Scheduler();
      final transport = _Transport()..fail = true;
      final connection = ChatWorkspaceConnection(
        transport: transport,
        scheduler: scheduler,
        scopeKey: () => 'teacher|school',
        authenticated: () => true,
        observeLifecycle: false,
      );
      var invalidations = 0;
      connection.invalidations.listen((_) => invalidations++);
      await connection.watch();
      expect(transport.attempts.length, 1);
      for (final delay in [1000, 2000, 4000, 8000, 16000, 30000, 30000]) {
        final before = transport.attempts.length;
        scheduler.advance(delay - 1);
        await _flush();
        expect(transport.attempts.length, before);
        scheduler.advance(1);
        await _flush();
        expect(transport.attempts.length, before + 1);
      }
      expect(invalidations, greaterThan(0));
      connection.didChangeAppLifecycleState(AppLifecycleState.paused);
      await _flush();
      final before = transport.attempts.length;
      final invalidationsBefore = invalidations;
      scheduler.advance(100000);
      await _flush();
      expect(transport.attempts.length, before);
      expect(invalidations, invalidationsBefore);
      transport.fail = false;
      connection.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await _flush();
      expect(transport.attempts.length, before + 1);
      expect(invalidations, invalidationsBefore + 1);
      await connection.dispose();
    },
  );

  test(
    'old thread callbacks and late joins cannot invalidate a new scope',
    () async {
      var scope = 'account-a';
      final scheduler = _Scheduler();
      final transport = _Transport();
      final connection = ChatWorkspaceConnection(
        transport: transport,
        scheduler: scheduler,
        scopeKey: () => scope,
        authenticated: () => true,
        observeLifecycle: false,
      );
      var invalidations = 0;
      connection.invalidations.listen((_) => invalidations++);
      await connection.watch(conversationId: 'old-thread');
      final old = transport.attempts.single;
      old.invalidate();
      scope = 'account-b';
      await connection.watch(conversationId: 'new-thread');
      old.invalidate();
      old.status(ChatConnectionStatus.connected);
      scheduler.advance(200);
      await _flush();
      expect(invalidations, 0);
      expect(old.subscription.closed, isTrue);
      transport.attempts.last.invalidate();
      scheduler.advance(200);
      await _flush();
      expect(invalidations, 1);
      await connection.dispose();
      transport.attempts.last.invalidate();
      scheduler.advance(5000);
      await _flush();
      expect(invalidations, 1);
    },
  );

  test(
    'token notifications update auth in place while account changes reconnect',
    () async {
      var scope = 'account-a';
      final changes = ChangeNotifier();
      final transport = _Transport();
      final connection = ChatWorkspaceConnection(
        transport: transport,
        scheduler: _Scheduler(),
        scopeKey: () => scope,
        authenticated: () => true,
        authChanges: changes,
        observeLifecycle: false,
      );
      await connection.watch();
      changes.notifyListeners();
      await _flush();
      expect(transport.authRefreshes, 1);
      expect(transport.attempts.length, 1);
      scope = 'account-b';
      changes.notifyListeners();
      await _flush();
      expect(transport.attempts.length, 2);
      await connection.dispose();
      changes.notifyListeners();
      expect(transport.authRefreshes, 1);
      changes.dispose();
    },
  );

  test('late pending subscription is closed after disposal', () async {
    final transport = _Transport()
      ..pending = Completer<ChatWorkspaceSubscription?>();
    final connection = ChatWorkspaceConnection(
      transport: transport,
      scheduler: _Scheduler(),
      scopeKey: () => 'account',
      authenticated: () => true,
      observeLifecycle: false,
    );
    final watching = connection.watch();
    await _flush();
    await connection.dispose();
    final subscription = _Subscription();
    transport.pending!.complete(subscription);
    await watching;
    expect(subscription.closed, isTrue);
  });

  test(
    'outbox completion invalidates and regained connectivity reconnects only once',
    () async {
      final scheduler = _Scheduler();
      final transport = _Transport();
      final sync = _SyncSource();
      final connection = ChatWorkspaceConnection(
        transport: transport,
        scheduler: scheduler,
        scopeKey: () => 'account',
        authenticated: () => true,
        syncSource: sync,
        observeLifecycle: false,
      );
      var invalidations = 0;
      connection.invalidations.listen((_) => invalidations++);
      await connection.watch();
      sync.emit(
        const ChatWorkspaceSyncState(
          accountKey: 'account',
          reachable: true,
          pendingCount: 2,
        ),
      );
      await _flush();
      expect(transport.attempts.length, 2);
      for (var i = 0; i < 5; i++) {
        sync.emit(
          const ChatWorkspaceSyncState(
            accountKey: 'account',
            reachable: true,
            pendingCount: 2,
          ),
        );
      }
      await _flush();
      expect(
        transport.attempts.length,
        2,
        reason: 'successful GET notifications cannot loop reconnects',
      );
      invalidations = 0;
      sync.emit(
        ChatWorkspaceSyncState(
          accountKey: 'account',
          reachable: true,
          pendingCount: 0,
          lastSyncedAt: DateTime.utc(2026, 10, 17),
        ),
      );
      scheduler.advance(200);
      await _flush();
      expect(invalidations, 1);
      connection.didChangeAppLifecycleState(AppLifecycleState.paused);
      sync.emit(
        const ChatWorkspaceSyncState(
          accountKey: 'account',
          reachable: false,
          pendingCount: 0,
        ),
      );
      sync.emit(
        const ChatWorkspaceSyncState(
          accountKey: 'account',
          reachable: true,
          pendingCount: 0,
        ),
      );
      await _flush();
      expect(transport.attempts.length, 2);
      await connection.dispose();
      sync.dispose();
    },
  );

  test(
    'unread count is authoritative, coalesced, and ignores old account responses',
    () async {
      var scope = 'account-a';
      final changes = ChangeNotifier();
      final pending = <Completer<int>>[];
      final monitorValues = <bool>[];
      final service = ChatUnreadService(
        loadCount: (monitor) {
          monitorValues.add(monitor);
          final result = Completer<int>();
          pending.add(result);
          return result.future;
        },
        scopeKey: () => scope,
        roleName: () => 'teacher',
        authenticated: () => true,
        authChanges: changes,
      );
      final first = service.refresh();
      await service.refresh();
      await service.refresh();
      expect(pending.length, 1);
      pending.first.complete(450);
      await _flush();
      expect(service.unreadCount, 450);
      expect(pending.length, 2);
      scope = 'account-b';
      changes.notifyListeners();
      expect(service.unreadCount, 0);
      pending[1].complete(999);
      await _flush();
      expect(service.unreadCount, 0);
      expect(pending.length, 3);
      pending[2].complete(7);
      await first;
      expect(service.unreadCount, 7);
      expect(monitorValues, everyElement(isFalse));
      service.dispose();
      changes.dispose();
    },
  );
}
