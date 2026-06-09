part of '../backend_api_client.dart';

extension BackendSchoolApi on BackendApiClient {
  // ─── Schools ───────────────────────────────────────────────────────────────

  Future<List<SchoolModel>> getSchools() async {
    try {
      final response = await _dio.get('/schools');
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return (data['data'] as List)
            .map((e) => SchoolModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      throw ServerException(message: data['error'] ?? 'Failed to get schools');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getCurrentSchool() async {
    try {
      final response = await _dio.get('/schools/current');
      final data = _asMap(response.data);
      if (data['success'] == true) {
        return Map<String, dynamic>.from(data['data'] as Map? ?? {});
      }
      throw ServerException(message: data['error'] ?? 'Failed to get school');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> updateCurrentSchool(
    Map<String, dynamic> payload,
  ) async {
    try {
      final response = await _dio.patch('/schools/current', data: payload);
      final data = _asMap(response.data);
      if (data['success'] == true) {
        return Map<String, dynamic>.from(data['data'] as Map? ?? {});
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to update school',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<String> uploadCurrentSchoolLogo(String filePath) async {
    try {
      final formData = FormData.fromMap({
        'logo': await MultipartFile.fromFile(filePath),
      });
      final response = await _dio.post('/schools/current/logo', data: formData);
      final data = _asMap(response.data);
      if (data['success'] == true) {
        final payload = Map<String, dynamic>.from(data['data'] as Map? ?? {});
        return '${payload['logo_url'] ?? ''}';
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to upload school logo',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ─── Academic Years ─────────────────────────────────────────────────────────

  Future<List<AcademicYearModel>> getAcademicYears({String? schoolId}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (schoolId != null) queryParams['school_id'] = schoolId;

      final response = await _dio.get(
        '/academic-years',
        queryParameters: queryParams,
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return (data['data'] as List)
            .map((e) => AcademicYearModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to get academic years',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<AcademicYearModel> createAcademicYear({
    required String yearLabel,
    required String startDate,
    required String endDate,
    bool isCurrent = true,
  }) async {
    try {
      final response = await _dio.post(
        '/academic-years',
        data: {
          'year_label': yearLabel,
          'start_date': startDate,
          'end_date': endDate,
          'is_current': isCurrent,
        },
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return AcademicYearModel.fromJson(data['data'] as Map<String, dynamic>);
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to create academic year',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<AcademicYearModel> updateAcademicYear(
    String id, {
    required String yearLabel,
    required String startDate,
    required String endDate,
    bool isCurrent = false,
  }) async {
    try {
      final response = await _dio.put(
        '/academic-years/$id',
        data: {
          'year_label': yearLabel,
          'start_date': startDate,
          'end_date': endDate,
          'is_current': isCurrent,
        },
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return AcademicYearModel.fromJson(data['data'] as Map<String, dynamic>);
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to update academic year',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ─── Grades ─────────────────────────────────────────────────────────────────

  Future<List<GradeModel>> getGrades({String? schoolId}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (schoolId != null) queryParams['school_id'] = schoolId;

      final response = await _dio.get('/grades', queryParameters: queryParams);
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return (data['data'] as List)
            .map((e) => GradeModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      throw ServerException(message: data['error'] ?? 'Failed to get grades');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ─── Subjects ───────────────────────────────────────────────────────────────

  Future<List<SubjectModel>> getSubjects({String? departmentId}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (departmentId != null && departmentId.trim().isNotEmpty) {
        queryParams['department_id'] = departmentId.trim();
      }

      final response = await _dio.get(
        '/subjects',
        queryParameters: queryParams.isEmpty ? null : queryParams,
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return (data['data'] as List)
            .map((e) => SubjectModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      throw ServerException(message: data['error'] ?? 'Failed to get subjects');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ─── Sections ───────────────────────────────────────────────────────────────

  Future<List<SectionModel>> getSections({
    String? gradeId,
    String? yearId,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (gradeId != null) queryParams['grade_id'] = gradeId;
      if (yearId != null) queryParams['academic_year_id'] = yearId;

      final response = await _dio.get(
        '/sections',
        queryParameters: queryParams,
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return (data['data'] as List)
            .map((e) => SectionModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      throw ServerException(message: data['error'] ?? 'Failed to get sections');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<Map<String, dynamic>>> getRooms() async {
    try {
      final response = await _dio.get('/rooms');
      final data = _asMap(response.data);
      if (data['success'] == true) {
        return _asListMap(data['data']);
      }
      throw ServerException(message: data['error'] ?? 'Failed to get rooms');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> createRoom({
    required String roomNumber,
    String roomType = 'classroom',
    int capacity = 0,
    String block = '',
    int floor = 0,
  }) async {
    try {
      final response = await _dio.post(
        '/rooms',
        data: {
          'room_number': roomNumber.trim(),
          'room_type': roomType.trim().isEmpty ? 'classroom' : roomType.trim(),
          'capacity': capacity,
          'block': block.trim(),
          'floor': floor,
        },
      );
      final data = _asMap(response.data);
      if (data['success'] == true) {
        return _asMap(data['data']);
      }
      throw ServerException(message: data['error'] ?? 'Failed to create room');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }
}
