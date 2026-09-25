import 'dart:typed_data';

import 'package:schooldesk1/core/utils/result.dart';

abstract interface class TeacherHomeworkRepository {
  bool get isOffline;

  Future<Result<List<Map<String, dynamic>>>> loadHomework({
    required String sectionId,
  });

  Future<Result<Map<String, dynamic>>> loadSubmissions(String homeworkId);

  Future<Result<Map<String, dynamic>>> loadReminderStatus({
    required String sectionId,
  });

  Future<Result<Map<String, dynamic>>> skipReminder({
    required String sectionId,
    required String reason,
  });

  Future<Result<void>> deleteHomework(String homeworkId);

  Future<Result<String>> uploadFile(
    String path, {
    required String filename,
    Uint8List? fileBytes,
    String? mimeType,
  });

  Future<Result<Map<String, dynamic>>> createHomework({
    required String title,
    required String subject,
    required String className,
    required String sectionId,
    required String teacherId,
    required String description,
    required String dueDate,
    required String status,
    String studentId,
    String attachmentUrl,
  });

  Future<Result<Map<String, dynamic>>> updateHomework(
    String homeworkId, {
    required String title,
    required String subject,
    required String className,
    required String sectionId,
    required String teacherId,
    required String description,
    required String dueDate,
    required String status,
    String studentId,
    String attachmentUrl,
  });

  Future<Result<void>> writeDiaryEntry(Map<String, dynamic> payload);

  Future<Result<Map<String, dynamic>>> reviewSubmission(
    String homeworkId,
    String submissionId, {
    required String status,
    required String remarks,
  });
}
