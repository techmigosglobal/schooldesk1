import 'dart:typed_data';

import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/repositories/api_repository_utils.dart';
import 'package:schooldesk1/core/utils/result.dart';
import 'package:schooldesk1/roles/teacher/domain/teacher_homework_repository.dart';

class ApiTeacherHomeworkRepository implements TeacherHomeworkRepository {
  ApiTeacherHomeworkRepository(this._api);

  final BackendApiClient _api;

  @override
  bool get isOffline => _api.offlineSync?.isOffline == true;

  @override
  Future<Result<List<Map<String, dynamic>>>> loadHomework({
    required String sectionId,
  }) {
    return guardApi(
      () => _api.getHomework(sectionId: sectionId, page: 1, pageSize: 20),
    );
  }

  @override
  Future<Result<Map<String, dynamic>>> loadSubmissions(String homeworkId) {
    return guardApi(() => _api.getHomeworkSubmissions(homeworkId));
  }

  @override
  Future<Result<Map<String, dynamic>>> loadReminderStatus({
    required String sectionId,
  }) {
    return guardApi(
      () => _api.getTodayHomeworkReminderStatus(sectionId: sectionId),
    );
  }

  @override
  Future<Result<Map<String, dynamic>>> skipReminder({
    required String sectionId,
    required String reason,
  }) {
    return guardApi(
      () => _api.skipTodayHomeworkReminder(
        sectionId: sectionId,
        reason: reason,
      ),
    );
  }

  @override
  Future<Result<void>> deleteHomework(String homeworkId) {
    return guardApi(() => _api.deleteHomework(homeworkId));
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
  Future<Result<Map<String, dynamic>>> createHomework({
    required String title,
    required String subject,
    required String className,
    required String sectionId,
    required String teacherId,
    required String description,
    required String dueDate,
    required String status,
    String studentId = '',
    String attachmentUrl = '',
  }) {
    return guardApi(
      () => _api.createHomework(
        title: title,
        subject: subject,
        className: className,
        sectionId: sectionId,
        teacherId: teacherId,
        description: description,
        dueDate: dueDate,
        studentId: studentId,
        status: status,
        attachmentUrl: attachmentUrl,
      ),
    );
  }

  @override
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
    String studentId = '',
    String attachmentUrl = '',
  }) {
    return guardApi(
      () => _api.updateHomework(
        homeworkId,
        title: title,
        subject: subject,
        className: className,
        sectionId: sectionId,
        teacherId: teacherId,
        description: description,
        dueDate: dueDate,
        studentId: studentId,
        status: status,
        attachmentUrl: attachmentUrl,
      ),
    );
  }

  @override
  Future<Result<void>> writeDiaryEntry(Map<String, dynamic> payload) {
    return guardApi(() async {
      await _api.createRaw('/diary-entries', payload);
    });
  }

  @override
  Future<Result<Map<String, dynamic>>> reviewSubmission(
    String homeworkId,
    String submissionId, {
    required String status,
    required String remarks,
  }) {
    return guardApi(
      () => _api.reviewHomeworkSubmission(
        homeworkId,
        submissionId,
        status: status,
        remarks: remarks,
      ),
    );
  }

  static ApiTeacherHomeworkRepository get legacyDefault =>
      ApiTeacherHomeworkRepository(BackendApiClient.instance);
}
