import 'dart:typed_data';

import 'package:schooldesk1/core/utils/result.dart';

abstract interface class HelpContentRepository {
  Future<Result<List<Map<String, dynamic>>>> load(
    String role, {
    bool forceRefresh = false,
  });

  Future<Result<Map<String, dynamic>>> create(Map<String, dynamic> payload);

  Future<Result<Map<String, dynamic>>> update(Map<String, dynamic> payload);

  Future<Result<void>> delete(String id);

  Future<Result<String>> loadPlaybackUrl(String id);

  Future<Result<Map<String, dynamic>>> uploadTutorial(
    String path, {
    required String filename,
    required String roleName,
    Uint8List? fileBytes,
    String? mimeType,
  });
}
