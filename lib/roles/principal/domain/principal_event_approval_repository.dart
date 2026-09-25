import 'package:schooldesk1/core/utils/event_post_media_parser.dart';

abstract interface class PrincipalEventApprovalRepository {
  Future<List<Map<String, dynamic>>> loadPosts();

  Future<Map<String, dynamic>> loadPost(String id);

  Future<void> invalidateCachedReads();

  Future<void> approve(String id);

  Future<void> reject(String id, {required String reason});

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
  });

  Future<void> delete(String id);
}
