import 'package:schooldesk1/core/network/models/backend_models.dart';
import 'package:schooldesk1/core/utils/result.dart';

abstract interface class ParentCommunicationRepository {
  Future<Result<UserResponse>> loadProfile();

  Future<Result<List<Map<String, dynamic>>>> loadChildren();

  Future<Result<List<Map<String, dynamic>>>> loadConversations({
    required String studentId,
  });

  Future<Result<List<Map<String, dynamic>>>> loadContacts({
    required String studentId,
  });

  Future<Result<List<Map<String, dynamic>>>> loadMessages({
    required String conversationId,
    DateTime? sentAfter,
  });

  Future<Result<void>> markConversationRead(String conversationId);

  Future<Result<Map<String, dynamic>>> createConversation({
    required String type,
    required String parentId,
    required String teacherId,
    required String leaderId,
    required String studentId,
    required String title,
  });

  Future<Result<Map<String, dynamic>>> sendMessage({
    required String conversationId,
    required String body,
  });
}
