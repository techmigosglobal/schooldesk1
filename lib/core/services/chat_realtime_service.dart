import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:schooldesk1/core/services/token_storage_service.dart';

/// Manages Supabase Realtime subscriptions for the chat screens.
///
/// Each call to [subscribe] creates one channel that listens to `messages`
/// (optionally filtered to a single conversation) and `message_conversations`.
/// Rapid back-to-back Realtime events are debounced so the UI does not
/// trigger a full reload for every individual row change in a burst.
class ChatRealtimeService {
  ChatRealtimeService._();

  static final ChatRealtimeService instance = ChatRealtimeService._();

  /// Subscribe to chat changes.
  ///
  /// [channelName] must be unique per screen instance (e.g. `teacher-chat`).
  /// [onUpdate] is called at most once per [debounce] window.
  /// [conversationId] when non-empty restricts the `messages` listener to that
  /// conversation only — reduces noise for screens that have one active thread.
  RealtimeChannel subscribe({
    required String channelName,
    required void Function() onUpdate,
    String conversationId = '',
    Duration debounce = const Duration(milliseconds: 400),
  }) {
    final client = Supabase.instance.client;

    // Ensure the realtime socket has a valid auth token.
    TokenStorageService.getAccessToken().then((token) {
      if (token != null && token.isNotEmpty) {
        client.realtime.setAuth(token);
      }
    });

    DateTime? lastFired;

    void fireDebounced() {
      final now = DateTime.now();
      final last = lastFired;
      if (last != null && now.difference(last) < debounce) return;
      lastFired = now;
      onUpdate();
    }

    final channel = client.channel(channelName);

    // Always subscribe to conversation-level changes (title, unread counts,
    // last_message preview) — no conversation filter here because the list
    // panel shows ALL conversations for the user.
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'message_conversations',
      callback: (_) => fireDebounced(),
    );

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
    } else {
      // No active conversation yet — listen to all messages (needed for the
      // conversation list to update unread counts when the user has not
      // opened a thread yet).
      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'messages',
        callback: (_) => fireDebounced(),
      );
    }

    channel.subscribe();
    return channel;
  }
}
