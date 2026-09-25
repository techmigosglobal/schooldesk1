import 'dart:typed_data';

import 'package:schooldesk1/core/utils/result.dart';

abstract interface class ParentHomeworkRepository {
  Future<Result<List<Map<String, dynamic>>>> loadChildren();

  Future<Result<List<Map<String, dynamic>>>> loadHomework(String studentId);

  Future<Result<Map<String, dynamic>>> loadSubmissions(
    String homeworkId, {
    required String studentId,
  });

  Future<Result<String>> uploadFile(
    String path, {
    required String filename,
    Uint8List? fileBytes,
    String? mimeType,
  });

  Future<Result<Map<String, dynamic>>> submitHomework({
    required String homeworkId,
    required String studentId,
    required String answerText,
    required List<String> attachmentUrls,
  });
}
