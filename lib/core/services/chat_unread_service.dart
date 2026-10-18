import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/services/role_access_service.dart';

/// Shell badge uses the server aggregate, including conversations beyond the
/// currently loaded page. One pending refresh catches invalidations in flight.
class ChatUnreadService extends ChangeNotifier {
  ChatUnreadService({
    Future<int> Function(bool monitor)? loadCount,
    String Function()? scopeKey,
    String Function()? roleName,
    bool Function()? authenticated,
    Listenable? authChanges,
  }) : _loadCount = loadCount ?? _loadServerCount,
       _scopeKey = scopeKey ?? _backendScope,
       _roleName =
           roleName ?? (() => BackendApiClient.instance.currentRoleName ?? ''),
       _authenticated =
           authenticated ?? (() => BackendApiClient.instance.isAuthenticated),
       _authChanges =
           authChanges ??
           (loadCount == null ? BackendApiClient.instance : null) {
    _scope = _scopeKey();
    _authChanges?.addListener(_accountChanged);
  }

  static final ChatUnreadService instance = ChatUnreadService();
  final Future<int> Function(bool monitor) _loadCount;
  final String Function() _scopeKey;
  final String Function() _roleName;
  final bool Function() _authenticated;
  final Listenable? _authChanges;
  int _unreadCount = 0, _generation = 0;
  bool _loading = false, _pending = false, _disposed = false;
  String _scope = '';
  String? _pendingRole;

  int get unreadCount => _unreadCount;

  static String _backendScope() {
    final api = BackendApiClient.instance;
    return '${api.currentUserId}|${api.activeBranchId}|${api.currentRoleName}';
  }

  static Future<int> _loadServerCount(bool monitor) async {
    final response = await BackendApiClient.instance.dio.get<dynamic>(
      '/chat/unread-count',
      queryParameters: {if (monitor) 'monitor': 'true'},
    );
    final envelope = response.data;
    if (envelope is! Map || envelope['success'] == false) {
      throw StateError('Unread count unavailable');
    }
    final payload = envelope['data'] is Map
        ? envelope['data'] as Map
        : envelope;
    final value = int.tryParse('${payload['unread_count']}');
    if (value == null) throw StateError('Invalid unread count');
    return value;
  }

  void _accountChanged() {
    if (_disposed || _scope == _scopeKey()) return;
    _scope = _scopeKey();
    reset();
    unawaited(refresh());
  }

  Future<void> refresh({String? role}) async {
    if (_disposed || !_authenticated()) return;
    if (_scope != _scopeKey()) {
      _scope = _scopeKey();
      reset();
    }
    if (_loading) {
      _pending = true;
      _pendingRole = role;
      return;
    }
    _loading = true;
    final generation = _generation;
    final scope = _scope;
    try {
      final normalizedRole = (role ?? _roleName()).trim().toLowerCase();
      final monitor = const {
        'principal',
        'coordinator',
        'admin',
        'super_admin',
      }.contains(normalizedRole);
      final count = await _loadCount(monitor);
      if (!_disposed &&
          _authenticated() &&
          generation == _generation &&
          scope == _scopeKey()) {
        final next = count.clamp(0, 1 << 31);
        if (next != _unreadCount) {
          _unreadCount = next;
          notifyListeners();
        }
      }
    } on Object {
      // A failed badge request must not interrupt the navigation shell.
    } finally {
      _loading = false;
      if (_pending && !_disposed) {
        final pendingRole = _pendingRole;
        _pending = false;
        _pendingRole = null;
        await refresh(role: pendingRole);
      }
    }
  }

  void reset() {
    _generation++;
    _pending = false;
    _pendingRole = null;
    if (_unreadCount == 0 || _disposed) return;
    _unreadCount = 0;
    notifyListeners();
  }

  String get currentRole => RoleAccessService.currentRoleName;

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _authChanges?.removeListener(_accountChanged);
    super.dispose();
  }
}
