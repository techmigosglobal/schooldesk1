import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/repositories/api_repository_utils.dart';
import 'package:schooldesk1/core/utils/result.dart';
import 'package:schooldesk1/roles/teacher/domain/teacher_communication_repository.dart';

class ApiTeacherCommunicationRepository
    implements TeacherCommunicationRepository {
  ApiTeacherCommunicationRepository(this._api);

  final BackendApiClient _api;

  @override
  Future<Result<UserResponse>> loadProfile() => guardApi(_api.getProfile);

  @override
  Future<Result<List<Map<String, dynamic>>>> loadConversations({
    required String teacherId,
  }) {
    return guardApi(
      () => _api.getUnifiedChatConversations(teacherId: teacherId),
    );
  }

  @override
  Future<Result<List<Map<String, dynamic>>>> loadContacts() {
    return guardApi(() => _api.getUnifiedChatContacts(role: 'teacher'));
  }

  @override
  Future<Result<List<Map<String, dynamic>>>> loadMessages({
    required String conversationId,
    DateTime? sentAfter,
  }) {
    return guardApi(
      () => _api.getUnifiedChatMessages(
        conversationId: conversationId,
        sentAfter: sentAfter,
      ),
    );
  }

  @override
  Future<Result<void>> markConversationRead(String conversationId) {
    return guardApi(
      () => _api.markUnifiedChatConversationRead(conversationId),
    );
  }

  @override
  Future<Result<Map<String, dynamic>>> createConversation({
    required String type,
    required String teacherId,
    required String parentId,
    required String studentId,
    required String leaderId,
    required String title,
  }) {
    return guardApi(
      () => _api.createUnifiedChatConversation(
        type: type,
        teacherId: teacherId,
        parentId: parentId,
        studentId: studentId,
        leaderId: leaderId,
        title: title,
      ),
    );
  }

  @override
  Future<Result<Map<String, dynamic>>> sendMessage({
    required String conversationId,
    required String body,
  }) {
    return guardApi(
      () => _api.sendUnifiedChatMessage(
        conversationId: conversationId,
        body: body,
      ),
    );
  }

  static ApiTeacherCommunicationRepository get legacyDefault =>
      ApiTeacherCommunicationRepository(BackendApiClient.instance);
}
