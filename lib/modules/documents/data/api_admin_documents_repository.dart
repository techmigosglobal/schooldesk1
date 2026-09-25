import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/modules/documents/domain/admin_documents_repository.dart';

class ApiAdminDocumentsRepository implements AdminDocumentsRepository {
  ApiAdminDocumentsRepository(this._api);

  final BackendApiClient _api;

  @override
  Future<PaginatedList<Map<String, dynamic>>> loadRequests({
    int page = 1,
    int pageSize = 20,
  }) => _api.getDocumentRequestsPage(page: page, pageSize: pageSize);

  @override
  Future<PaginatedList<Map<String, dynamic>>> loadTemplates({
    int page = 1,
    int pageSize = 20,
  }) => _api.getDocumentTemplatesPage(page: page, pageSize: pageSize);

  @override
  Future<List<Map<String, dynamic>>> loadStudentDocuments(String studentId) =>
      _api.getRawList(
        '/student-documents',
        queryParameters: {'student_id': studentId},
      );

  @override
  Future<List<Map<String, dynamic>>> loadTeacherDocuments(String staffId) =>
      _api.getRawList(
        '/staff-documents',
        queryParameters: {'staff_id': staffId},
      );

  @override
  Future<void> deleteStudentDocument(String documentId) =>
      _api.deleteRaw('/student-documents/$documentId');

  @override
  Future<String> uploadStudentDocument(
    String path, {
    required String filename,
    required String studentId,
  }) => _api.uploadFile(
    path,
    filename: filename,
    folder: 'student-documents',
    entityType: 'student_document',
    entityId: studentId,
    private: true,
  );

  @override
  Future<void> createStudentDocument({
    required String studentId,
    required String type,
    required String title,
    required String fileUrl,
  }) async {
    await _api.createRaw('/student-documents', {
      'student_id': studentId,
      'doc_type': type,
      'title': title,
      'file_url': fileUrl,
    });
  }

  @override
  Future<void> updateRequest({
    required String requestId,
    required String status,
  }) async {
    await _api.updateRaw('/documents/requests/$requestId', {
      'status': status.toLowerCase(),
    });
  }

  @override
  Future<void> createTemplate({
    required String name,
    required String documentType,
    required String body,
  }) async {
    await _api.createRaw('/documents/templates', {
      'name': name,
      'document_type': documentType,
      'body': body,
      'status': 'active',
    });
  }

  @override
  Future<void> requestReprint(String requestId) async {
    await _api.createRaw('/documents/requests/$requestId/prints', {
      'action': 'reprint',
    });
  }

  @override
  Future<void> createRequest({
    required String studentName,
    required String documentType,
    required String status,
  }) async {
    await _api.createRaw('/documents/requests', {
      'student_name': studentName,
      'type': documentType,
      'status': status,
    });
  }

  static ApiAdminDocumentsRepository get legacyDefault =>
      ApiAdminDocumentsRepository(BackendApiClient.instance);
}
