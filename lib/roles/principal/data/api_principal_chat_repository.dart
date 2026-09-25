import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/roles/principal/domain/principal_chat_repository.dart';

class ApiPrincipalChatRepository implements PrincipalChatRepository {
  ApiPrincipalChatRepository(this._api);

  final BackendApiClient _api;

  @override
  String? get currentRoleName => _api.currentRoleName;

  @override
  Future<UserResponse> loadProfile() => _api.getProfile();

  @override
  Future<List<Map<String, dynamic>>> loadConversations({
    required bool monitor,
  }) => _api.getUnifiedChatConversations(monitor: monitor);

  @override
  Future<List<Map<String, dynamic>>> loadContacts({required String role}) =>
      _api.getUnifiedChatContacts(role: role);

  @override
  Future<List<Map<String, dynamic>>> loadMessages({
    required String conversationId,
    DateTime? sentAfter,
  }) => _api.getUnifiedChatMessages(
    conversationId: conversationId,
    sentAfter: sentAfter,
  );

  @override
  Future<void> markConversationRead(String conversationId) =>
      _api.markUnifiedChatConversationRead(conversationId);

  @override
  Future<Map<String, dynamic>> createConversation({
    required String type,
    String teacherId = '',
    String parentId = '',
    String studentId = '',
    String title = '',
  }) => _api.createUnifiedChatConversation(
    type: type,
    teacherId: teacherId,
    parentId: parentId,
    studentId: studentId,
    title: title,
  );

  @override
  Future<Map<String, dynamic>> sendMessage({
    required String conversationId,
    required String body,
  }) => _api.sendUnifiedChatMessage(conversationId: conversationId, body: body);

  static ApiPrincipalChatRepository get legacyDefault =>
      ApiPrincipalChatRepository(BackendApiClient.instance);
}
