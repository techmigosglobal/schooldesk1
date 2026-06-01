part of '../backend_api_client.dart';

extension BackendHomeworkApi on BackendApiClient {
  // ─── Homework ─────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getHomework({
    String? studentId,
    String? sectionId,
    String? teacherId,
    String? status,
  }) async {
    final queryParams = <String, dynamic>{};
    if (studentId != null && studentId.trim().isNotEmpty) {
      queryParams['student_id'] = studentId.trim();
    }
    if (sectionId != null && sectionId.trim().isNotEmpty) {
      queryParams['section_id'] = sectionId.trim();
    }
    if (teacherId != null && teacherId.trim().isNotEmpty) {
      queryParams['staff_id'] = teacherId.trim();
    }
    if (status != null && status.trim().isNotEmpty) {
      queryParams['status'] = status.trim();
    }
    try {
      final response = await SchoolDeskApi.instance.client.homework(
        queryParams.isEmpty ? null : queryParams,
      );
      if (response.success == true) {
        return _asListMap(response.data);
      }
      throw ServerException(message: 'Failed to load homework');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> createHomework({
    required String title,
    required String subject,
    required String className,
    required String sectionId,
    required String teacherId,
    required String description,
    required String dueDate,
    String studentId = '',
    String status = 'pending',
  }) async {
    try {
      final response = await SchoolDeskApi.instance.client.createHomework(
        HomeworkDto(
          title: title,
          subjectId: subject,
          classId: className,
          sectionId: sectionId,
          staffId: teacherId,
          studentId: studentId,
          description: description,
          submissionDate: dueDate,
          status: status,
        ),
      );
      if (response.success == true) return _asMap(response.data);
      throw ServerException(
        message: response.error ?? 'Failed to create homework',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> updateHomework(
    String id, {
    required String title,
    required String subject,
    required String className,
    required String sectionId,
    required String teacherId,
    required String description,
    required String dueDate,
    String studentId = '',
    String status = 'pending',
  }) async {
    try {
      final response = await SchoolDeskApi.instance.client.updateHomework(
        id,
        HomeworkDto(
          title: title,
          subjectId: subject,
          classId: className,
          sectionId: sectionId,
          staffId: teacherId,
          studentId: studentId,
          description: description,
          submissionDate: dueDate,
          status: status,
        ),
      );
      if (response.success == true) return _asMap(response.data);
      throw ServerException(
        message: response.error ?? 'Failed to update homework',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> deleteHomework(String id) async {
    try {
      final response = await SchoolDeskApi.instance.client.deleteHomework(id);
      if (response.success == true) return;
      throw ServerException(
        message: response.error ?? 'Failed to delete homework',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getHomeworkSubmissions(
    String homeworkId, {
    String? studentId,
  }) async {
    final queryParams = <String, dynamic>{};
    if (studentId != null && studentId.trim().isNotEmpty) {
      queryParams['student_id'] = studentId.trim();
    }
    try {
      final response = await SchoolDeskApi.instance.client.homeworkSubmissions(
        homeworkId,
        queryParams.isEmpty ? null : queryParams,
      );
      if (response.success == true) return _asMap(response.data);
      throw ServerException(
        message: response.error ?? 'Failed to load homework submissions',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> submitHomework(
    String homeworkId, {
    required String studentId,
    required String answerText,
    String attachmentUrl = '',
  }) async {
    try {
      final response = await SchoolDeskApi.instance.client
          .submitHomework(homeworkId, {
            'student_id': studentId,
            'answer_text': answerText,
            'attachment_url': attachmentUrl,
          });
      if (response.success == true) return _asMap(response.data);
      throw ServerException(
        message: response.error ?? 'Failed to submit homework',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> reviewHomeworkSubmission(
    String homeworkId,
    String submissionId, {
    required String status,
    String grade = '',
    String remarks = '',
  }) async {
    try {
      final response = await SchoolDeskApi.instance.client
          .reviewHomeworkSubmission(homeworkId, submissionId, {
            'status': status,
            'grade': grade,
            'remarks': remarks,
          });
      if (response.success == true) return _asMap(response.data);
      throw ServerException(
        message: response.error ?? 'Failed to review homework',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }
}
