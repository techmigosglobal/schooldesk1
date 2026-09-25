import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/utils/event_post_media_parser.dart';
import 'package:schooldesk1/roles/principal/domain/principal_event_approval_repository.dart';

class ApiPrincipalEventApprovalRepository
    implements PrincipalEventApprovalRepository {
  ApiPrincipalEventApprovalRepository(this._api);

  final BackendApiClient _api;

  @override
  Future<List<Map<String, dynamic>>> loadPosts() =>
      _api.getPrincipalEventPosts();

  @override
  Future<Map<String, dynamic>> loadPost(String id) => _api.getEventPost(id);

  @override
  Future<void> invalidateCachedReads() => _api.invalidateCachedReads();

  @override
  Future<void> approve(String id) => _api.approveEventPost(id);

  @override
  Future<void> reject(String id, {required String reason}) =>
      _api.rejectEventPost(id, reason: reason);

  @override
  Future<Map<String, dynamic>> update({
    required String id,
    required String title,
    required String description,
    required String eventDate,
    required List<String> mediaUrls,
    required List<EventPostMediaItem> media,
    required List<String> destinations,
    required bool isSubmit,
    String? sectionId,
  }) {
    return _api.updateEventPost(
      id: id,
      title: title,
      description: description,
      eventDate: eventDate,
      mediaUrls: mediaUrls,
      media: media,
      destinations: destinations,
      isSubmit: isSubmit,
      sectionId: sectionId,
    );
  }

  @override
  Future<void> delete(String id) => _api.deleteEventPost(id);

  static ApiPrincipalEventApprovalRepository get legacyDefault =>
      ApiPrincipalEventApprovalRepository(BackendApiClient.instance);
}
