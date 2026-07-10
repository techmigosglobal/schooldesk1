import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:schooldesk1/core/services/token_storage_service.dart';

class ChatRealtimeService {
  ChatRealtimeService._();

  static final ChatRealtimeService instance = ChatRealtimeService._();

  RealtimeChannel subscribe({
    required String channelName,
    required void Function() onUpdate,
  }) {
    final client = Supabase.instance.client;

    // Set token dynamically on subscribe
    TokenStorageService.getAccessToken().then((token) {
      if (token != null && token.isNotEmpty) {
        Supabase.instance.client.realtime.setAuth(token);
      }
    });

    final channel = client.channel(channelName);

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            onUpdate();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'message_conversations',
          callback: (payload) {
            onUpdate();
          },
        );

    channel.subscribe();
    return channel;
  }
}
