import 'package:schooldesk1/core/utils/result.dart';

abstract interface class TeacherDocumentsRepository {
  Future<Result<List<Map<String, dynamic>>>> loadStudentDocuments(
    String sectionId,
  );

  Future<Result<List<Map<String, dynamic>>>> loadMyDocuments();

  Future<Result<void>> deleteMyDocument(String documentId);

  Future<Result<String>> uploadDocument(
    String path, {
    required String filename,
  });

  Future<Result<void>> createMyDocument({
    required String type,
    required String title,
    required String fileUrl,
  });
}
