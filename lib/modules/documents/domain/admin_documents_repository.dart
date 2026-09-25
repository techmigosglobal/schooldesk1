import 'package:schooldesk1/core/network/models/backend_models.dart';

abstract interface class AdminDocumentsRepository {
  Future<PaginatedList<Map<String, dynamic>>> loadRequests({
    int page = 1,
    int pageSize = 20,
  });

  Future<PaginatedList<Map<String, dynamic>>> loadTemplates({
    int page = 1,
    int pageSize = 20,
  });

  Future<List<Map<String, dynamic>>> loadStudentDocuments(String studentId);

  Future<List<Map<String, dynamic>>> loadTeacherDocuments(String staffId);

  Future<void> deleteStudentDocument(String documentId);

  Future<String> uploadStudentDocument(
    String path, {
    required String filename,
    required String studentId,
  });

  Future<void> createStudentDocument({
    required String studentId,
    required String type,
    required String title,
    required String fileUrl,
  });

  Future<void> updateRequest({
    required String requestId,
    required String status,
  });

  Future<void> createTemplate({
    required String name,
    required String documentType,
    required String body,
  });

  Future<void> requestReprint(String requestId);

  Future<void> createRequest({
    required String studentName,
    required String documentType,
    required String status,
  });
}
