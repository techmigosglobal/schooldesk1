import 'package:schooldesk1/core/network/models/backend_models.dart';

abstract interface class PrincipalChatRepository {
  String? get currentRoleName;

  Future<UserResponse> loadProfile();

  Future<List<Map<String, dynamic>>> loadConversations({required bool monitor});

  Future<List<Map<String, dynamic>>> loadContacts({required String role});

  Future<List<Map<String, dynamic>>> loadMessages({
    required String conversationId,
    DateTime? sentAfter,
  });

  Future<void> markConversationRead(String conversationId);

  Future<Map<String, dynamic>> createConversation({
    required String type,
    String teacherId,
    String parentId,
    String studentId,
    String title,
  });

  Future<Map<String, dynamic>> sendMessage({
    required String conversationId,
    required String body,
  });
}
