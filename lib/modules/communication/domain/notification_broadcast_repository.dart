abstract interface class NotificationBroadcastRepository {
  Future<Map<String, dynamic>> recipients({
    required Set<String> roles,
    String search = '',
    int page = 1,
  });
  Future<Map<String, dynamic>> history({int page = 1});
  Future<Map<String, dynamic>> send({
    required String key,
    required String title,
    required String message,
    required Set<String> roles,
    required bool all,
    required Set<String> userIds,
  });
}
