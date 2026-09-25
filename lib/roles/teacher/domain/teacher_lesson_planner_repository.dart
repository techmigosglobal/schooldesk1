import 'dart:typed_data';

import 'package:schooldesk1/core/utils/result.dart';

abstract interface class TeacherLessonPlannerRepository {
  Future<Result<List<Map<String, dynamic>>>> loadLessonPlanners();

  Future<Result<List<Map<String, dynamic>>>> loadSections();

  Future<Result<String>> uploadFile(
    String path, {
    required String filename,
    Uint8List? fileBytes,
    String? mimeType,
  });

  Future<Result<void>> createLessonPlanner({
    required String gradeId,
    required String sectionId,
    required String weekStartDate,
    required String weekEndDate,
    required String attachmentUrl,
    required List<Map<String, dynamic>> attachments,
    required String note,
  });
}
