import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/repositories/api_repository_utils.dart';
import 'package:schooldesk1/core/utils/result.dart';
import 'package:schooldesk1/roles/parent/domain/parent_documents_repository.dart';

class ApiParentDocumentsRepository implements ParentDocumentsRepository {
  ApiParentDocumentsRepository(this._api);

  final BackendApiClient _api;

  @override
  Future<Result<List<Map<String, dynamic>>>> loadChildren({
    required int refreshNonce,
  }) {
    return guardApi(
      () => _api.getMyStudents(refreshNonce: refreshNonce),
    );
  }

  @override
  Future<Result<Map<String, dynamic>>> loadSchool() {
    return guardApi(_api.getCurrentSchool);
  }

  @override
  Future<Result<UserResponse>> loadProfile() => guardApi(_api.getProfile);

  @override
  Future<Result<List<Map<String, dynamic>>>> loadStudentDocuments(
    String studentId,
  ) {
    return guardApi(
      () => _api.getRawList(
        '/student-documents',
        queryParameters: {'student_id': studentId},
      ),
    );
  }

  @override
  Future<Result<void>> deleteStudentDocument(String documentId) {
    return guardApi(() async {
      await _api.deleteRaw('/student-documents/$documentId');
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
        folder: 'student-documents',
        entityType: 'student_document',
        private: true,
      ),
    );
  }

  @override
  Future<Result<void>> createStudentDocument({
    required String type,
    required String title,
    required String fileUrl,
    required String studentId,
  }) {
    return guardApi(() async {
      await _api.createRaw('/student-documents', {
        'student_id': studentId,
        'doc_type': type,
        'title': title,
        'file_url': fileUrl,
      });
    });
  }

  static ApiParentDocumentsRepository get legacyDefault =>
      ApiParentDocumentsRepository(BackendApiClient.instance);
}
