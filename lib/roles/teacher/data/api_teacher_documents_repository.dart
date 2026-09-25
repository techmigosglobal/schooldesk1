import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/repositories/api_repository_utils.dart';
import 'package:schooldesk1/core/utils/result.dart';
import 'package:schooldesk1/roles/teacher/domain/teacher_documents_repository.dart';

class ApiTeacherDocumentsRepository implements TeacherDocumentsRepository {
  ApiTeacherDocumentsRepository(this._api);

  final BackendApiClient _api;

  @override
  Future<Result<List<Map<String, dynamic>>>> loadStudentDocuments(
    String sectionId,
  ) {
    return guardApi(
      () => _api.getRawList(
        '/student-documents',
        queryParameters: {'section_id': sectionId, 'page_size': 100},
      ),
    );
  }

  @override
  Future<Result<List<Map<String, dynamic>>>> loadMyDocuments() {
    return guardApi(() => _api.getRawList('/staff-documents'));
  }

  @override
  Future<Result<void>> deleteMyDocument(String documentId) {
    return guardApi(() async {
      await _api.deleteRaw('/staff-documents/$documentId');
    });
  }

  @override
  Future<Result<String>> uploadDocument(
    String path, {
    required String filename,
  }) {
    return guardApi(
      () => _api.uploadFile(
        path,
        filename: filename,
        folder: 'staff-documents',
        entityType: 'staff_document',
        private: true,
      ),
    );
  }

  @override
  Future<Result<void>> createMyDocument({
    required String type,
    required String title,
    required String fileUrl,
  }) {
    return guardApi(() async {
      await _api.createRaw('/staff-documents', {
        'doc_type': type,
        'title': title,
        'file_url': fileUrl,
      });
    });
  }

  static ApiTeacherDocumentsRepository get legacyDefault =>
      ApiTeacherDocumentsRepository(BackendApiClient.instance);
}
