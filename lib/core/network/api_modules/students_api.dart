part of '../backend_api_client.dart';

extension BackendStudentsApi on BackendApiClient {
  // ─── Students ───────────────────────────────────────────────────────────────

  Future<PaginatedList<StudentModel>> getStudents({
    String? schoolId,
    String? sectionId,
    String? status,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'page_size': pageSize,
      };
      if (schoolId != null) queryParams['school_id'] = schoolId;
      if (sectionId != null) queryParams['section_id'] = sectionId;
      if (status != null) queryParams['status'] = status;

      final response = await _dio.get(
        '/students',
        queryParameters: queryParams,
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return PaginatedList<StudentModel>(
          data: (data['data'] as List)
              .map((e) => StudentModel.fromJson(e as Map<String, dynamic>))
              .toList(),
          total: data['total'] as int,
          page: data['page'] as int,
          pageSize: data['page_size'] as int,
        );
      }
      throw ServerException(message: data['error'] ?? 'Failed to get students');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<Map<String, dynamic>>> getMyStudents() async {
    try {
      final response = await _dio.get('/me/students');
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        final payload = data['data'];
        if (payload is List) {
          return payload
              .whereType<Map>()
              .map((e) => _parentStudentDashboardMap(e))
              .toList();
        }
        return <Map<String, dynamic>>[];
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to get linked students',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Map<String, dynamic> _parentStudentDashboardMap(
    Map<dynamic, dynamic> source,
  ) {
    final row = Map<String, dynamic>.from(source);
    final currentSection = _asMap(row['current_section']);
    final grade = _asMap(currentSection['grade']);
    final classTeacher = _asMap(currentSection['class_teacher']);
    final attendanceSummary = _asMap(row['attendance_summary']);
    final feeSummary = _asMap(row['fee_summary']);

    final firstName = _trimmed(row['first_name']);
    final lastName = _trimmed(row['last_name']);
    final fullName = [
      firstName,
      lastName,
    ].where((part) => part.isNotEmpty).join(' ');
    row['name'] = _firstNonEmpty([row['name'], row['full_name'], fullName]);
    row['class'] = _firstNonEmpty([
      row['class'],
      row['grade_name'],
      grade['grade_name'],
    ]);
    row['section'] = _firstNonEmpty([
      row['section'],
      row['section_name'],
      currentSection['section_name'],
    ]);
    row['rollNo'] = _firstNonEmpty([
      row['rollNo'],
      row['roll_number'],
      row['admission_number'],
      row['student_code'],
    ]);

    final photoUrl = _firstNonEmpty([
      row['photo'],
      row['photo_url'],
      row['avatar'],
    ]);
    if (photoUrl.isNotEmpty) {
      row['photo'] = photoUrl;
      row['photo_url'] = photoUrl;
    }

    final teacherName = _firstNonEmpty([
      row['classTeacher'],
      currentSection['class_teacher_name'],
      classTeacher['name'],
      [
        _trimmed(classTeacher['first_name']),
        _trimmed(classTeacher['last_name']),
      ].where((part) => part.isNotEmpty).join(' '),
    ]);
    if (teacherName.isNotEmpty) {
      row['classTeacher'] = teacherName;
    }

    if (attendanceSummary.isNotEmpty) {
      row['attendance'] = _asDouble(
        attendanceSummary['percent'] ?? attendanceSummary['attendance_percent'],
      );
      row['attendance_status'] = _trimmed(attendanceSummary['status_label']);
    }
    if (feeSummary.isNotEmpty) {
      row['feesDue'] = _asDouble(feeSummary['balance']);
      row['pending_invoices'] = _asInt(feeSummary['pending_invoices']);
      row['feeStatus'] = _firstNonEmpty([
        feeSummary['status'],
        row['feeStatus'],
      ]);
    }
    return row;
  }

  Future<StudentModel> getStudent(String id) async {
    try {
      final response = await _dio.get('/students/$id');
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return StudentModel.fromJson(data['data'] as Map<String, dynamic>);
      }
      throw ServerException(message: data['error'] ?? 'Failed to get student');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<Map<String, dynamic>>> getStudentEnrollments(
    String studentId,
  ) async {
    try {
      final response = await _dio.get('/students/$studentId/enrollments');
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return _asListMap(data['data']);
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to get student enrollments',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<StudentModel> createStudent({
    required String firstName,
    required String lastName,
    required String dateOfBirth,
    required String gender,
    String? admissionNumber,
    String? studentCode,
    String? currentSectionId,
    String admissionDate = '2026-01-01',
    String status = 'active',
  }) async {
    try {
      final response = await _dio.post(
        '/students',
        data: {
          'first_name': firstName,
          'last_name': lastName,
          'date_of_birth': dateOfBirth,
          'gender': gender,
          'admission_number': admissionNumber ?? '',
          'student_code': studentCode ?? '',
          'current_section_id': currentSectionId ?? '',
          'admission_date': admissionDate,
          'status': status,
        },
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return StudentModel.fromJson(data['data'] as Map<String, dynamic>);
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to create student',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<String> uploadStudentPhoto({
    required String studentId,
    String? filePath,
    Uint8List? fileBytes,
    String? fileName,
  }) async {
    try {
      final formData = FormData.fromMap({
        'photo': await _multipartStudentFile(
          filePath: filePath,
          fileBytes: fileBytes,
          fileName: fileName,
        ),
      });
      final response = await _dio.post(
        '/students/$studentId/photo',
        data: formData,
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        final payload = data['data'] as Map<String, dynamic>? ?? {};
        return '${payload['photo'] ?? payload['photo_url'] ?? ''}';
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to upload student photo',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<String> uploadStudentDocument({
    required String studentId,
    String? filePath,
    Uint8List? fileBytes,
    String? fileName,
    required String docType,
  }) async {
    try {
      final formData = FormData.fromMap({
        'doc_type': docType.trim().isEmpty
            ? 'admission_document'
            : docType.trim(),
        'document': await _multipartStudentFile(
          filePath: filePath,
          fileBytes: fileBytes,
          fileName: fileName,
        ),
      });
      final response = await _dio.post(
        '/students/$studentId/documents',
        data: formData,
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        final payload = data['data'] as Map<String, dynamic>? ?? {};
        return '${payload['file_url'] ?? ''}';
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to upload student document',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> updateStudent(
    String id, {
    required String firstName,
    required String lastName,
    required String dateOfBirth,
    required String gender,
    String? admissionNumber,
    String? studentCode,
    String? currentSectionId,
    String? admissionDate,
    String status = 'active',
  }) async {
    try {
      final payload = <String, dynamic>{
        'first_name': firstName,
        'last_name': lastName,
        'date_of_birth': dateOfBirth,
        'gender': gender,
        'admission_number': admissionNumber ?? '',
        'student_code': studentCode ?? '',
        'current_section_id': currentSectionId ?? '',
        'status': status,
      };
      if ((admissionDate ?? '').trim().isNotEmpty) {
        payload['admission_date'] = admissionDate!.trim();
      }
      final response = await _dio.put('/students/$id', data: payload);
      final data = response.data as Map<String, dynamic>;
      if (data['success'] != true) {
        throw ServerException(
          message: data['error'] ?? 'Failed to update student',
        );
      }
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<MultipartFile> _multipartStudentFile({
    String? filePath,
    Uint8List? fileBytes,
    String? fileName,
  }) async {
    if (fileBytes != null && fileBytes.isNotEmpty) {
      return MultipartFile.fromBytes(
        fileBytes,
        filename: (fileName ?? '').trim().isEmpty
            ? 'schooldesk-upload'
            : fileName!.trim(),
      );
    }
    final cleanPath = (filePath ?? '').trim();
    if (cleanPath.isEmpty) {
      throw const ServerException(message: 'Upload file is required');
    }
    return MultipartFile.fromFile(
      cleanPath,
      filename: (fileName ?? '').trim().isEmpty ? null : fileName!.trim(),
    );
  }

  Future<void> deleteStudent(String id) async {
    try {
      final response = await _dio.delete('/students/$id');
      final data = response.data as Map<String, dynamic>;
      if (data['success'] != true) {
        throw ServerException(
          message: data['error'] ?? 'Failed to delete student',
        );
      }
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }
}
