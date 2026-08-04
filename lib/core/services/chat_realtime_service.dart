import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/services/token_storage_service.dart';

/// Manages Supabase Realtime subscriptions for the chat screens.
///
/// Each call to [subscribe] creates one channel that listens to scoped
/// `message_conversations` changes and, when a thread is open, that thread's
/// `messages` changes.
/// Rapid back-to-back Realtime events are debounced so the UI does not
/// trigger a full reload for every individual row change in a burst.
class ChatRealtimeService {
  ChatRealtimeService._();

  static final ChatRealtimeService instance = ChatRealtimeService._();

  /// Refresh the Realtime bearer token without rebuilding an existing channel.
  /// The API interceptor may rotate the backend JWT while a chat stays open.
  Future<bool> refreshAuth() async {
    final token = await TokenStorageService.getAccessToken();
    if (token == null || token.trim().isEmpty) return false;
    await Supabase.instance.client.realtime.setAuth(token.trim());
    return true;
  }

  /// Subscribe to chat changes.
  ///
  /// [channelName] must be unique per screen instance (e.g. `teacher-chat`).
  /// [onUpdate] is called at most once per [debounce] window.
  /// [conversationId] when non-empty restricts the `messages` listener to that
  /// conversation only — reduces noise for screens that have one active thread.
  Future<RealtimeChannel?> subscribe({
    required String channelName,
    required void Function() onUpdate,
    String conversationId = '',
    Duration debounce = const Duration(milliseconds: 400),
  }) async {
    final client = Supabase.instance.client;

    // The API uses its own JWT, so Realtime must receive that same token
    // before the channel joins. Creating the channel first produces an
    // apparently connected but unauthorised subscription on cold startup.
    if (!await refreshAuth()) return null;

    DateTime? lastFired;

    void fireDebounced() {
      final now = DateTime.now();
      final last = lastFired;
      if (last != null && now.difference(last) < debounce) return;
      lastFired = now;
      onUpdate();
    }

    final channel = client.channel(channelName);
    final activeBranchId =
        BackendApiClient.instance.activeBranchId?.trim() ?? '';

    // Conversation-level changes refresh list previews and unread counts. RLS
    // limits the rows visible to this role and branch. The explicit branch
    // filter matters for principals who switch between permitted branches.
    if (activeBranchId.isEmpty) {
      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'message_conversations',
        callback: (_) => fireDebounced(),
      );
    } else {
      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'message_conversations',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'school_id',
          value: activeBranchId,
        ),
        callback: (_) => fireDebounced(),
      );
    }

    // For the messages table, filter to the active conversation when known so
    // we don't receive every school-wide message row change.
    if (conversationId.trim().isNotEmpty) {
      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'messages',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'conversation_id',
          value: conversationId.trim(),
        ),
        callback: (_) => fireDebounced(),
      );
    }

    channel.subscribe();
    return channel;
  }
}
