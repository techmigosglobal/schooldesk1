part of '../backend_api_client.dart';

extension BackendPrincipalApi on BackendApiClient {
  Future<Map<String, dynamic>> getDashboard(
    String role, {
    bool forceRefresh = false,
  }) async {
    final safeRole = role.trim().toLowerCase();
    try {
      final response = await _dio.get(
        '/dashboard/$safeRole',
        queryParameters: forceRefresh
            ? {'refresh_nonce': DateTime.now().millisecondsSinceEpoch}
            : null,
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return Map<String, dynamic>.from(data['data'] as Map? ?? {});
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to load dashboard',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getPrincipalClassesOverview({
    bool forceRefresh = false,
  }) async {
    try {
      final response = await _dio.get(
        '/principal/classes',
        queryParameters: forceRefresh
            ? {'refresh_nonce': DateTime.now().millisecondsSinceEpoch}
            : null,
      );
      final data = _asMap(response.data);
      if (data['success'] == true) {
        return _asMap(data['data']);
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to load class command center',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> createPrincipalClass({
    required String academicYearId,
    required String sectionName,
    required int capacity,
    String gradeId = '',
    String gradeName = '',
    int? gradeNumber,
    String classTeacherId = '',
    String coTeacherId = '',
    String roomNumber = '',
    String roomType = 'classroom',
    int roomCapacity = 0,
    List<Map<String, dynamic>> subjectMappings = const [],
    List<Map<String, dynamic>> feeItems = const [],
  }) async {
    try {
      final response = await _dio.post(
        '/principal/classes',
        data: {
          'grade_id': gradeId.trim(),
          'grade_name': gradeName.trim(),
          if (gradeNumber != null) 'grade_number': gradeNumber,
          'academic_year_id': academicYearId.trim(),
          'section_name': sectionName.trim(),
          'capacity': capacity,
          'class_teacher_id': classTeacherId.trim(),
          if (coTeacherId.trim().isNotEmpty)
            'co_teacher_id': coTeacherId.trim(),
          if (roomNumber.trim().isNotEmpty) 'room_number': roomNumber.trim(),
          if (roomNumber.trim().isNotEmpty)
            'room_type': roomType.trim().isEmpty
                ? 'classroom'
                : roomType.trim(),
          if (roomNumber.trim().isNotEmpty && roomCapacity > 0)
            'room_capacity': roomCapacity,
          'subject_mappings': subjectMappings,
          'fee_items': feeItems,
        },
      );
      final data = _asMap(response.data);
      if (data['success'] == true) {
        return _asMap(data['data']);
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to create principal class',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> dryRunPrincipalClassCsvImport({
    required String csvText,
  }) async {
    try {
      final response = await _dio.post(
        '/principal/classes/import/dry-run',
        data: {'csv_text': csvText},
      );
      final data = _asMap(response.data);
      if (data['success'] == true) {
        return _asMap(data['data']);
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to validate class CSV',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> importPrincipalClassCsv({
    required String csvText,
  }) async {
    try {
      final response = await _dio.post(
        '/principal/classes/import',
        data: {'csv_text': csvText},
      );
      final data = _asMap(response.data);
      if (data['success'] == true) {
        return _asMap(data['data']);
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to import class CSV',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> updatePrincipalClassSetup({
    required String sectionId,
    required String gradeId,
    required String academicYearId,
    required String sectionName,
    required int capacity,
    String gradeName = '',
    int? gradeNumber,
    String classTeacherId = '',
    String coTeacherId = '',
    String? roomNumber,
    String roomType = 'classroom',
    int roomCapacity = 0,
    List<Map<String, dynamic>> subjectMappings = const [],
    List<Map<String, dynamic>> feeItems = const [],
    List<String> deletedFeeStructureIds = const [],
    List<String> deletedGradeSubjectIds = const [],
    List<String> deletedStaffSubjectIds = const [],
  }) async {
    try {
      final response = await _dio.put(
        '/principal/classes/${sectionId.trim()}',
        data: {
          'grade_id': gradeId.trim(),
          'grade_name': gradeName.trim(),
          if (gradeNumber != null) 'grade_number': gradeNumber,
          'academic_year_id': academicYearId.trim(),
          'section_name': sectionName.trim(),
          'capacity': capacity,
          'class_teacher_id': classTeacherId.trim(),
          if (coTeacherId.trim().isNotEmpty)
            'co_teacher_id': coTeacherId.trim(),
          if (roomNumber != null) 'room_number': roomNumber.trim(),
          if (roomNumber != null && roomNumber.trim().isNotEmpty)
            'room_type': roomType.trim().isEmpty
                ? 'classroom'
                : roomType.trim(),
          if (roomNumber != null &&
              roomNumber.trim().isNotEmpty &&
              roomCapacity > 0)
            'room_capacity': roomCapacity,
          'subject_mappings': subjectMappings,
          'fee_items': feeItems,
          'deleted_fee_structure_ids': deletedFeeStructureIds,
          'deleted_grade_subject_ids': deletedGradeSubjectIds,
          'deleted_staff_subject_ids': deletedStaffSubjectIds,
        },
      );
      final data = _asMap(response.data);
      if (data['success'] == true) {
        return _asMap(data['data']);
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to update class setup',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> deletePrincipalClass({
    required String sectionId,
  }) async {
    try {
      final response = await _dio.delete(
        '/principal/classes/${sectionId.trim()}',
      );
      final data = _asMap(response.data);
      if (data['success'] == true) {
        return _asMap(data['data']);
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to remove principal class',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getPrincipalSubjectsOverview() async {
    try {
      final response = await _dio.get('/principal/subjects');
      final data = _asMap(response.data);
      if (data['success'] == true) {
        return _asMap(data['data']);
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to load subject command center',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> createPrincipalSubjectAction({
    required String subjectId,
    required String actionType,
    required String message,
    String title = '',
    String priority = 'normal',
    String teacherId = '',
    String gradeId = '',
    String dueDate = '',
  }) async {
    try {
      final response = await _dio.post(
        '/principal/subjects/$subjectId/actions',
        data: {
          'action_type': actionType.trim(),
          'title': title.trim(),
          'message': message.trim(),
          'priority': priority.trim().isEmpty ? 'normal' : priority.trim(),
          'teacher_id': teacherId.trim(),
          'grade_id': gradeId.trim(),
          'due_date': dueDate.trim(),
        },
      );
      final data = _asMap(response.data);
      if (data['success'] == true) {
        return _asMap(data['data']);
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to save subject action',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> savePrincipalSubjectMapping({
    required String subjectId,
    required String academicYearId,
    required String gradeId,
    required int periodsPerWeek,
    bool isMandatory = true,
    String sectionId = '',
    String teacherId = '',
    bool isPrimary = true,
    String assignmentId = '',
  }) async {
    try {
      final response = await _dio.post(
        '/principal/subjects/${subjectId.trim()}/mappings',
        data: {
          'academic_year_id': academicYearId.trim(),
          'grade_id': gradeId.trim(),
          'section_id': sectionId.trim(),
          'teacher_id': teacherId.trim(),
          'assignment_id': assignmentId.trim(),
          'periods_per_week': periodsPerWeek,
          'is_mandatory': isMandatory,
          'is_primary': isPrimary,
        },
      );
      final data = _asMap(response.data);
      if (data['success'] == true) {
        return _asMap(data['data']);
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to save subject mapping',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getPrincipalTimetableOverview() async {
    try {
      final response = await _dio.get('/principal/timetable');
      final data = _asMap(response.data);
      if (data['success'] == true) {
        return _asMap(data['data']);
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to load timetable command center',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> createPrincipalTimetableAction({
    required String actionType,
    required String message,
    String title = '',
    String priority = 'normal',
    String slotId = '',
    String dueDate = '',
  }) async {
    try {
      final response = await _dio.post(
        '/principal/timetable/actions',
        data: {
          'action_type': actionType.trim(),
          'title': title.trim(),
          'message': message.trim(),
          'priority': priority.trim().isEmpty ? 'normal' : priority.trim(),
          'slot_id': slotId.trim(),
          'due_date': dueDate.trim(),
        },
      );
      final data = _asMap(response.data);
      if (data['success'] == true) {
        return _asMap(data['data']);
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to save timetable action',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> bulkImport({
    required String importType,
    required String filePath,
    bool dryRun = true,
  }) async {
    try {
      final formData = FormData.fromMap({
        'import_type': importType,
        'dry_run': dryRun.toString(),
        'file': await MultipartFile.fromFile(filePath, filename: 'import.csv'),
      });
      final response = await _dio.post(
        '/principal/bulk-import',
        data: formData,
      );
      final data = _asMap(response.data);
      if (data['success'] == true) return _asMap(data['data']);
      throw ServerException(message: data['error'] ?? 'Bulk import failed');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getBulkImportHistory({
    String? importType,
    int limit = 20,
  }) async {
    try {
      final response = await _dio.get(
        '/principal/bulk-import/history',
        queryParameters: {
          if (importType != null) 'import_type': importType,
          'limit': limit,
        },
      );
      final data = _asMap(response.data);
      if (data['success'] == true) return _asMap(data['data']);
      throw ServerException(
        message: data['error'] ?? 'Failed to fetch import history',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }
}
