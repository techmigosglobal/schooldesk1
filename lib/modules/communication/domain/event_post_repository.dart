import 'dart:typed_data';

import 'package:schooldesk1/core/utils/event_post_media_parser.dart';

abstract interface class EventPostRepository {
  Future<List<Map<String, dynamic>>> loadLandingPosts({
    required String schoolId,
  });

  Future<Map<String, dynamic>> uploadMedia(
    String path, {
    required String filename,
    Uint8List? fileBytes,
    String? mimeType,
  });

  Future<List<Map<String, dynamic>>> loadPosts({required bool principalMode});

  Future<List<Map<String, dynamic>>> loadPendingPosts();

  Future<List<Map<String, dynamic>>> loadGalleryPosts({
    bool forceRefresh = false,
  });

  Future<Map<String, dynamic>> loadPost(String id);

  Future<void> createPost({
    required String title,
    required String description,
    required String eventDate,
    required List<String> mediaUrls,
    required List<EventPostMediaItem> media,
    required List<String> destinations,
    required bool isSubmit,
  });

  Future<Map<String, dynamic>> updatePost({
    required String id,
    required String title,
    required String description,
    required String eventDate,
    required List<String> mediaUrls,
    required List<EventPostMediaItem> media,
    required List<String> destinations,
    required bool isSubmit,
  });

  Future<void> deletePost(String id);

  Future<void> approvePost(String id);

  Future<void> rejectPost(String id, {required String reason});

  Future<void> invalidateCachedReads();
}
