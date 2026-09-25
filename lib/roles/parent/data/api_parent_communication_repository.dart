import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/repositories/api_repository_utils.dart';
import 'package:schooldesk1/core/utils/result.dart';
import 'package:schooldesk1/roles/parent/domain/parent_communication_repository.dart';

class ApiParentCommunicationRepository
    implements ParentCommunicationRepository {
  ApiParentCommunicationRepository(this._api);

  final BackendApiClient _api;

  @override
  Future<Result<UserResponse>> loadProfile() => guardApi(_api.getProfile);

  @override
  Future<Result<List<Map<String, dynamic>>>> loadChildren() {
    return guardApi(_api.getMyStudents);
  }

  @override
  Future<Result<List<Map<String, dynamic>>>> loadConversations({
    required String studentId,
  }) {
    return guardApi(
      () => _api.getUnifiedChatConversations(studentId: studentId),
    );
  }

  @override
  Future<Result<List<Map<String, dynamic>>>> loadContacts({
    required String studentId,
  }) {
    return guardApi(
      () => _api.getUnifiedChatContacts(
        role: 'parent',
        studentId: studentId,
      ),
    );
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
    required String parentId,
    required String teacherId,
    required String leaderId,
    required String studentId,
    required String title,
  }) {
    return guardApi(
      () => _api.createUnifiedChatConversation(
        type: type,
        parentId: parentId,
        teacherId: teacherId,
        leaderId: leaderId,
        studentId: studentId,
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

  static ApiParentCommunicationRepository get legacyDefault =>
      ApiParentCommunicationRepository(BackendApiClient.instance);
}
