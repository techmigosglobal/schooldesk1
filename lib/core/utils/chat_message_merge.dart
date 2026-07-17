/// Merges chat message batches without rendering the same persisted message
/// more than once.
///
/// Supabase Realtime can emit both a message-row event and a conversation-row
/// event for one send. Those events may start overlapping incremental loads
/// from the same cursor, so message identity—not callback timing—must decide
/// whether a row is new.
List<Map<String, dynamic>> mergeChatMessagesByIdentity(
  Iterable<Map<String, dynamic>> current,
  Iterable<Map<String, dynamic>> incoming,
) {
  final merged = <Map<String, dynamic>>[];
  final indexById = <String, int>{};

  void add(Map<String, dynamic> message) {
    final id = '${message['id'] ?? ''}'.trim();
    if (id.isEmpty) {
      merged.add(message);
      return;
    }

    final existingIndex = indexById[id];
    if (existingIndex == null) {
      indexById[id] = merged.length;
      merged.add(message);
      return;
    }

    merged[existingIndex] = {...merged[existingIndex], ...message};
  }

  for (final message in current) {
    add(message);
  }
  for (final message in incoming) {
    add(message);
  }
  return merged;
}
