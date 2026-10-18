enum ChatConnectionStatus { connecting, connected, reconnecting, offline }

abstract interface class ChatWorkspaceRepository {
  String get accountScope;
  String get currentUserId;
  String get currentRole;
  Future<List<Map<String, dynamic>>> loadChildren();
  Future<List<Map<String, dynamic>>> loadContacts({String studentId = ''});
  Future<Map<String, dynamic>> loadConversations({
    bool monitor = false,
    String studentId = '',
    String search = '',
    String type = '',
    int page = 1,
    int pageSize = 50,
  });
  Future<Map<String, dynamic>> loadConversation(String conversationId);
  Future<Map<String, dynamic>> loadMessages({
    required String conversationId,
    String mode = 'latest',
    String cursorSentAt = '',
    String cursorId = '',
    int pageSize = 50,
  });
  Future<Map<String, dynamic>> sendMessage({
    required String clientMessageId,
    required String body,
    String conversationId = '',
    Map<String, dynamic> contact = const {},
  });
  Future<void> markRead({
    required String conversationId,
    String throughSentAt = '',
    String throughId = '',
  });
  Future<List<Map<String, dynamic>>> pendingMessages();
  Future<int> unreadCount({bool monitor = false});
  Future<String> readDraft(String key);
  Future<void> saveDraft(String key, String body);
  Stream<void> get invalidations;
  Stream<ChatConnectionStatus> get connectionChanges;
  Future<void> watch({String conversationId = ''});
  Future<void> refreshConnection();
  Future<void> dispose();
}
