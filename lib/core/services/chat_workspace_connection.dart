import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/offline/offline_sync_engine.dart';
import 'package:schooldesk1/core/services/token_storage_service.dart';
import 'package:schooldesk1/modules/communication/domain/chat_workspace_repository.dart';

class ChatWorkspaceSyncState {
  const ChatWorkspaceSyncState({
    required this.accountKey,
    required this.reachable,
    required this.pendingCount,
    this.lastSyncedAt,
  });
  final String accountKey;
  final bool reachable;
  final int pendingCount;
  final DateTime? lastSyncedAt;
}

abstract interface class ChatWorkspaceSyncSource implements Listenable {
  ChatWorkspaceSyncState get snapshot;
}

class _OfflineSyncSource implements ChatWorkspaceSyncSource {
  _OfflineSyncSource(this.engine);
  final OfflineSyncEngine engine;
  @override
  ChatWorkspaceSyncState get snapshot => ChatWorkspaceSyncState(
    accountKey: engine.accountKey,
    reachable:
        engine.state == OfflineConnectionState.online || engine.isSyncing,
    pendingCount: engine.pendingMutationCount,
    lastSyncedAt: engine.lastSyncedAt,
  );
  @override
  void addListener(VoidCallback listener) => engine.addListener(listener);
  @override
  void removeListener(VoidCallback listener) => engine.removeListener(listener);
}

ChatWorkspaceSyncSource? _defaultSyncSource() {
  final engine = BackendApiClient.instance.offlineSync;
  return engine == null ? null : _OfflineSyncSource(engine);
}

abstract interface class ChatWorkspaceSubscription {
  Future<void> close();
}

abstract interface class ChatWorkspaceRealtimeTransport {
  Future<void> refreshAuth();
  Future<ChatWorkspaceSubscription?> connect({
    required String conversationId,
    required VoidCallback onInvalidation,
    required void Function(ChatConnectionStatus) onStatus,
  });
}

abstract interface class ChatWorkspaceTimer {
  void cancel();
}

abstract interface class ChatWorkspaceScheduler {
  ChatWorkspaceTimer oneShot(Duration delay, VoidCallback callback);
  ChatWorkspaceTimer periodic(Duration delay, VoidCallback callback);
}

class _SystemTimer implements ChatWorkspaceTimer {
  _SystemTimer(this.timer);
  final Timer timer;
  @override
  void cancel() => timer.cancel();
}

class _SystemScheduler implements ChatWorkspaceScheduler {
  @override
  ChatWorkspaceTimer oneShot(Duration delay, VoidCallback callback) =>
      _SystemTimer(Timer(delay, callback));
  @override
  ChatWorkspaceTimer periodic(Duration delay, VoidCallback callback) =>
      _SystemTimer(Timer.periodic(delay, (_) => callback()));
}

/// Owns one foreground chat subscription. Every async completion and callback
/// is checked against the scope/attempt that created it before reaching the UI.
class ChatWorkspaceConnection with WidgetsBindingObserver {
  ChatWorkspaceConnection({
    ChatWorkspaceRealtimeTransport? transport,
    ChatWorkspaceScheduler? scheduler,
    String Function()? scopeKey,
    bool Function()? authenticated,
    Listenable? authChanges,
    ChatWorkspaceSyncSource? syncSource,
    bool observeLifecycle = true,
  }) : _transport = transport ?? _SupabaseChatTransport(),
       _scheduler = scheduler ?? _SystemScheduler(),
       _scopeKey =
           scopeKey ?? (() => BackendApiClient.instance.offlineAccountKey),
       _authenticated =
           authenticated ?? (() => BackendApiClient.instance.isAuthenticated),
       _authChanges =
           authChanges ??
           (transport == null ? BackendApiClient.instance : null),
       _syncSource =
           syncSource ?? (transport == null ? _defaultSyncSource() : null),
       _observeLifecycle = observeLifecycle {
    _scope = _scopeKey();
    _authChanges?.addListener(_authChanged);
    _syncSnapshot = _syncSource?.snapshot;
    _syncSource?.addListener(_syncChanged);
    if (_observeLifecycle) WidgetsBinding.instance.addObserver(this);
  }

  final ChatWorkspaceRealtimeTransport _transport;
  final ChatWorkspaceScheduler _scheduler;
  final String Function() _scopeKey;
  final bool Function() _authenticated;
  final Listenable? _authChanges;
  final bool _observeLifecycle;
  final ChatWorkspaceSyncSource? _syncSource;
  ChatWorkspaceSyncState? _syncSnapshot;
  final _invalidations = StreamController<void>.broadcast();
  final _connections = StreamController<ChatConnectionStatus>.broadcast();
  ChatWorkspaceSubscription? _subscription;
  ChatWorkspaceTimer? _debounce, _retry, _poll, _joinTimeout;
  String _scope = '', _conversationId = '';
  int _generation = 0, _failures = 0;
  bool _disposed = false, _foreground = true, _watching = false;
  ChatConnectionStatus? _status;

  Stream<void> get invalidations => _invalidations.stream;
  Stream<ChatConnectionStatus> get connectionChanges => _connections.stream;

  bool _valid(int generation, String scope) =>
      !_disposed &&
      _foreground &&
      _watching &&
      generation == _generation &&
      scope == _scopeKey();

  void _setStatus(ChatConnectionStatus status) {
    if (_disposed || status == _status) return;
    _status = status;
    _connections.add(status);
  }

  void _invalidate() {
    if (!_disposed && _foreground && _watching) _invalidations.add(null);
  }

  void _coalesce(int generation, String scope) {
    if (!_valid(generation, scope)) return;
    _debounce?.cancel();
    _debounce = _scheduler.oneShot(const Duration(milliseconds: 200), () {
      if (_valid(generation, scope)) _invalidate();
    });
  }

  Future<void> watch({String conversationId = ''}) async {
    if (_disposed) return;
    final nextId = conversationId.trim();
    if (_watching && nextId == _conversationId && _scope == _scopeKey()) return;
    _watching = true;
    _conversationId = nextId;
    _scope = _scopeKey();
    _failures = 0;
    await _connect();
  }

  Future<void> refreshConnection() async {
    if (_disposed) return;
    _invalidate();
    if (!_watching || !_foreground) return;
    _scope = _scopeKey();
    _failures = 0;
    await _connect();
  }

  void _authChanged() {
    if (_disposed || !_watching) return;
    if (_scope != _scopeKey() || !_authenticated()) {
      unawaited(refreshConnection());
    } else if (_foreground) {
      // Token rotation can happen during a request. Updating the channel bearer
      // in place avoids a reconnect loop when refreshSession notifies listeners.
      final generation = _generation;
      final scope = _scope;
      unawaited(
        _transport.refreshAuth().catchError((Object _) {
          if (_valid(generation, scope)) _failed(generation, scope);
        }),
      );
    }
  }

  void _syncChanged() {
    final previous = _syncSnapshot;
    final next = _syncSource?.snapshot;
    _syncSnapshot = next;
    if (next == null ||
        _disposed ||
        !_foreground ||
        !_watching ||
        next.accountKey != _scope ||
        _scope != _scopeKey()) {
      return;
    }
    final sameScope = previous?.accountKey == next.accountKey;
    final regained =
        sameScope && previous?.reachable == false && next.reachable;
    final completed =
        sameScope &&
        (next.pendingCount < previous!.pendingCount ||
            (next.lastSyncedAt != null &&
                next.lastSyncedAt != previous.lastSyncedAt));
    if (regained) {
      unawaited(refreshConnection());
    } else if (completed) {
      _coalesce(_generation, _scope);
    }
  }

  Future<void> _connect() async {
    final generation = ++_generation;
    final scope = _scope;
    _debounce?.cancel();
    _retry?.cancel();
    _joinTimeout?.cancel();
    _debounce = _retry = _joinTimeout = null;
    final old = _subscription;
    _subscription = null;
    if (old != null) await old.close();
    if (!_valid(generation, scope)) return;
    if (!_authenticated()) {
      _poll?.cancel();
      _poll = null;
      _setStatus(ChatConnectionStatus.offline);
      return;
    }
    _setStatus(
      _failures == 0
          ? ChatConnectionStatus.connecting
          : ChatConnectionStatus.reconnecting,
    );
    _startPolling(generation, scope);
    _joinTimeout = _scheduler.oneShot(
      const Duration(seconds: 12),
      () => _failed(generation, scope),
    );
    try {
      final subscription = await _transport.connect(
        conversationId: _conversationId,
        onInvalidation: () => _coalesce(generation, scope),
        onStatus: (status) {
          if (!_valid(generation, scope)) return;
          if (status == ChatConnectionStatus.connected) {
            _joinTimeout?.cancel();
            _retry?.cancel();
            _retry = null;
            _poll?.cancel();
            _poll = null;
            _failures = 0;
            _setStatus(status);
            _invalidate(); // Catch up rows missed while reconnecting.
          } else if (status == ChatConnectionStatus.offline) {
            _failed(generation, scope);
          }
        },
      );
      if (!_valid(generation, scope)) {
        await subscription?.close();
        return;
      }
      _subscription = subscription;
      if (subscription == null) _failed(generation, scope);
    } on Object {
      if (_valid(generation, scope)) _failed(generation, scope);
    }
  }

  void _failed(int generation, String scope) {
    if (!_valid(generation, scope) || _retry != null) return;
    _joinTimeout?.cancel();
    _setStatus(ChatConnectionStatus.offline);
    _startPolling(generation, scope);
    const delays = [1, 2, 4, 8, 16, 30];
    final delay = delays[_failures.clamp(0, delays.length - 1)];
    _failures++;
    _retry = _scheduler.oneShot(Duration(seconds: delay), () {
      _retry = null;
      if (_valid(generation, scope)) unawaited(_connect());
    });
  }

  void _startPolling(int generation, String scope) {
    _poll ??= _scheduler.periodic(const Duration(seconds: 5), () {
      if (!_disposed &&
          _foreground &&
          _watching &&
          _authenticated() &&
          _scope == _scopeKey() &&
          _status != ChatConnectionStatus.connected) {
        _invalidate();
      }
    });
  }

  void _cancelTimers() {
    _debounce?.cancel();
    _retry?.cancel();
    _poll?.cancel();
    _joinTimeout?.cancel();
    _debounce = _retry = _poll = _joinTimeout = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_disposed) return;
    if (state == AppLifecycleState.resumed) {
      _foreground = true;
      unawaited(refreshConnection());
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _foreground = false;
      ++_generation;
      _cancelTimers();
      final old = _subscription;
      _subscription = null;
      if (old != null) unawaited(old.close());
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    ++_generation;
    _authChanges?.removeListener(_authChanged);
    _syncSource?.removeListener(_syncChanged);
    if (_observeLifecycle) WidgetsBinding.instance.removeObserver(this);
    _cancelTimers();
    await _subscription?.close();
    _subscription = null;
    await _invalidations.close();
    await _connections.close();
  }
}

class _SupabaseSubscription implements ChatWorkspaceSubscription {
  _SupabaseSubscription(this.client, this.channel);
  final SupabaseClient client;
  final RealtimeChannel channel;
  @override
  Future<void> close() async {
    await client.removeChannel(channel);
  }
}

class _SupabaseChatTransport implements ChatWorkspaceRealtimeTransport {
  static int _channelNumber = 0;
  @override
  Future<void> refreshAuth() async {
    var token = await TokenStorageService.getAccessToken();
    if (token == null || token.trim().isEmpty) {
      await BackendApiClient.instance.refreshSession();
      token = await TokenStorageService.getAccessToken();
    }
    if (token == null || token.trim().isEmpty) {
      throw StateError('Chat requires an authenticated session');
    }
    await Supabase.instance.client.realtime.setAuth(token.trim());
  }

  @override
  Future<ChatWorkspaceSubscription?> connect({
    required String conversationId,
    required VoidCallback onInvalidation,
    required void Function(ChatConnectionStatus) onStatus,
  }) async {
    // Capture the branch before awaiting auth: an old attempt must never join a
    // new branch's channel with the previous scope's callbacks.
    final branchId = BackendApiClient.instance.activeBranchId?.trim() ?? '';
    if (branchId.isEmpty) throw StateError('Chat requires a school scope');
    await refreshAuth();
    final client = Supabase.instance.client;
    final channel = client.channel('chat-workspace-${++_channelNumber}');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'message_conversations',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'school_id',
        value: branchId,
      ),
      callback: (_) => onInvalidation(),
    );
    if (conversationId.isNotEmpty) {
      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'messages',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'conversation_id',
          value: conversationId,
        ),
        callback: (_) => onInvalidation(),
      );
    }
    channel.subscribe((status, [error]) {
      if (status == RealtimeSubscribeStatus.subscribed) {
        onStatus(ChatConnectionStatus.connected);
      }
      if (status == RealtimeSubscribeStatus.channelError ||
          status == RealtimeSubscribeStatus.closed ||
          status == RealtimeSubscribeStatus.timedOut) {
        onStatus(ChatConnectionStatus.offline);
      }
    });
    return _SupabaseSubscription(client, channel);
  }
}
