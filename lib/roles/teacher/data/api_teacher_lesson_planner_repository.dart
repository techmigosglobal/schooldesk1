import 'dart:typed_data';

import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/repositories/api_repository_utils.dart';
import 'package:schooldesk1/core/utils/result.dart';
import 'package:schooldesk1/roles/teacher/domain/teacher_lesson_planner_repository.dart';

class ApiTeacherLessonPlannerRepository
    implements TeacherLessonPlannerRepository {
  ApiTeacherLessonPlannerRepository(this._api);

  final BackendApiClient _api;

  @override
  Future<Result<List<Map<String, dynamic>>>> loadLessonPlanners() {
    return guardApi(_api.getTeacherLessonPlanners);
  }

  @override
  Future<Result<List<Map<String, dynamic>>>> loadSections() {
    return guardApi(() async {
      final sections = await _api.getSections();
      return sections
          .map(
            (section) => {
              'id': section.id,
              'grade_id': section.gradeId,
              'grade_name': section.gradeName,
              'section_name': section.sectionName,
            },
          )
          .toList();
    });
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
  Future<Result<void>> createLessonPlanner({
    required String gradeId,
    required String sectionId,
    required String weekStartDate,
    required String weekEndDate,
    required String attachmentUrl,
    required List<Map<String, dynamic>> attachments,
    required String note,
  }) {
    return guardApi(
      () => _api.createLessonPlanner(
        gradeId: gradeId,
        sectionId: sectionId,
        weekStartDate: weekStartDate,
        weekEndDate: weekEndDate,
        attachmentUrl: attachmentUrl,
        attachments: attachments,
        note: note,
      ),
    );
  }

  static ApiTeacherLessonPlannerRepository get legacyDefault =>
      ApiTeacherLessonPlannerRepository(BackendApiClient.instance);
}
