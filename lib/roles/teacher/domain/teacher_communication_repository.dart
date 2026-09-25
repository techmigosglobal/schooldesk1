import 'package:schooldesk1/core/network/models/backend_models.dart';
import 'package:schooldesk1/core/utils/result.dart';

abstract interface class TeacherCommunicationRepository {
  Future<Result<UserResponse>> loadProfile();

  Future<Result<List<Map<String, dynamic>>>> loadConversations({
    required String teacherId,
  });

  Future<Result<List<Map<String, dynamic>>>> loadContacts();

  Future<Result<List<Map<String, dynamic>>>> loadMessages({
    required String conversationId,
    DateTime? sentAfter,
  });

  Future<Result<void>> markConversationRead(String conversationId);

  Future<Result<Map<String, dynamic>>> createConversation({
    required String type,
    required String teacherId,
    required String parentId,
    required String studentId,
    required String leaderId,
    required String title,
  });

  Future<Result<Map<String, dynamic>>> sendMessage({
    required String conversationId,
    required String body,
  });
}
