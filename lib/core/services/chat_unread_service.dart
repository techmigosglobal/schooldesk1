import 'package:flutter/foundation.dart';

import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/services/role_access_service.dart';

/// Keeps the shell-level Messages badge in sync with the authoritative chat
/// conversation rows. Individual chat screens still own their local message
/// state; this service only aggregates unread conversation counts.
class ChatUnreadService extends ChangeNotifier {
  ChatUnreadService._();

  static final ChatUnreadService instance = ChatUnreadService._();

  int _unreadCount = 0;
  bool _loading = false;

  int get unreadCount => _unreadCount;

  Future<void> refresh({String? role}) async {
    final api = BackendApiClient.instance;
    if (!api.isAuthenticated || _loading) return;
    _loading = true;
    try {
      final normalizedRole = (role ?? api.currentRoleName ?? '')
          .trim()
          .toLowerCase();
      final monitor = const {
        'principal',
        'coordinator',
        'admin',
        'super_admin',
      }.contains(normalizedRole);
      final rows = await api.getUnifiedChatConversations(
        monitor: monitor,
        pageSize: 100,
      );
      _unreadCount = rows.fold<int>(0, (total, row) {
        final value = row['unread_count'] ?? row['unread_for_current_user'];
        return total + (int.tryParse('$value') ?? 0).clamp(0, 100000);
      });
      notifyListeners();
    } on Object catch (_) {
      // A shell badge must never block the rest of the navigation shell.
    } finally {
      _loading = false;
    }
  }

  void reset() {
    if (_unreadCount == 0) return;
    _unreadCount = 0;
    notifyListeners();
  }

  String get currentRole => RoleAccessService.currentRoleName;
}
