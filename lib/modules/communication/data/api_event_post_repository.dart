import 'dart:typed_data';

import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/utils/event_post_media_parser.dart';
import 'package:schooldesk1/modules/communication/domain/event_post_repository.dart';

class ApiEventPostRepository implements EventPostRepository {
  ApiEventPostRepository(this._api);

  final BackendApiClient _api;

  @override
  Future<List<Map<String, dynamic>>> loadLandingPosts({
    required String schoolId,
  }) => _api.getLandingEventPosts(schoolId: schoolId);

  @override
  Future<Map<String, dynamic>> uploadMedia(
    String path, {
    required String filename,
    Uint8List? fileBytes,
    String? mimeType,
  }) {
    return _api.uploadFileResult(
      path,
      filename: filename,
      fileBytes: fileBytes,
      mimeType: mimeType,
      folder: 'event-posts',
      entityType: 'event_post',
      private: true,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> loadPosts({required bool principalMode}) {
    return principalMode
        ? _api.getPrincipalEventPosts()
        : _api.getTeacherEventPosts();
  }

  @override
  Future<List<Map<String, dynamic>>> loadPendingPosts() =>
      _api.getPendingEventPosts();

  @override
  Future<List<Map<String, dynamic>>> loadGalleryPosts({
    bool forceRefresh = false,
  }) => _api.getGalleryEventPosts(forceRefresh: forceRefresh);

  @override
  Future<Map<String, dynamic>> loadPost(String id) => _api.getEventPost(id);

  @override
  Future<void> createPost({
    required String title,
    required String description,
    required String eventDate,
    required List<String> mediaUrls,
    required List<EventPostMediaItem> media,
    required List<String> destinations,
    required bool isSubmit,
  }) {
    return _api.createEventPost(
      title: title,
      description: description,
      eventDate: eventDate,
      mediaUrls: mediaUrls,
      media: media,
      destinations: destinations,
      isSubmit: isSubmit,
    );
  }

  @override
  Future<Map<String, dynamic>> updatePost({
    required String id,
    required String title,
    required String description,
    required String eventDate,
    required List<String> mediaUrls,
    required List<EventPostMediaItem> media,
    required List<String> destinations,
    required bool isSubmit,
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
    );
  }

  @override
  Future<void> deletePost(String id) => _api.deleteEventPost(id);

  @override
  Future<void> approvePost(String id) => _api.approveEventPost(id);

  @override
  Future<void> rejectPost(String id, {required String reason}) =>
      _api.rejectEventPost(id, reason: reason);

  @override
  Future<void> invalidateCachedReads() => _api.invalidateCachedReads();

  static ApiEventPostRepository get legacyDefault =>
      ApiEventPostRepository(BackendApiClient.instance);
}
