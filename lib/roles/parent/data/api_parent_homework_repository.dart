import 'dart:typed_data';

import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/repositories/api_repository_utils.dart';
import 'package:schooldesk1/core/utils/result.dart';
import 'package:schooldesk1/roles/parent/domain/parent_homework_repository.dart';

class ApiParentHomeworkRepository implements ParentHomeworkRepository {
  ApiParentHomeworkRepository(this._api);

  final BackendApiClient _api;

  @override
  Future<Result<List<Map<String, dynamic>>>> loadChildren() {
    return guardApi(_api.getMyStudents);
  }

  @override
  Future<Result<List<Map<String, dynamic>>>> loadHomework(String studentId) {
    return guardApi(() => _api.getHomework(studentId: studentId));
  }

  @override
  Future<Result<Map<String, dynamic>>> loadSubmissions(
    String homeworkId, {
    required String studentId,
  }) {
    return guardApi(
      () => _api.getHomeworkSubmissions(homeworkId, studentId: studentId),
    );
  }

  @override
  Future<Result<String>> uploadFile(
    String path, {
    required String filename,
    Uint8List? fileBytes,
    String? mimeType,
  }) {
    return guardApi(
      () => _api.uploadFile(
        path,
        filename: filename,
        fileBytes: fileBytes,
        mimeType: mimeType,
      ),
    );
  }

  @override
  Future<Result<Map<String, dynamic>>> submitHomework({
    required String homeworkId,
    required String studentId,
    required String answerText,
    required List<String> attachmentUrls,
  }) {
    return guardApi(
      () => _api.submitHomework(
        homeworkId,
        studentId: studentId,
        answerText: answerText,
        attachmentUrl: '',
        attachmentUrls: attachmentUrls,
      ),
    );
  }

  static ApiParentHomeworkRepository get legacyDefault =>
      ApiParentHomeworkRepository(BackendApiClient.instance);
}
