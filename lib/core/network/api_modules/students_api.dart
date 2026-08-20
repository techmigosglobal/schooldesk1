part of '../backend_api_client.dart';

extension BackendStudentsApi on BackendApiClient {
  // ─── Students ───────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getStudentDirectorySummary() async {
    try {
      final response = await _get('/students/summary');
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) return _asMap(data['data']);
      throw ServerException(
        message: data['error'] ?? 'Failed to get student directory summary',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getStudentParentIntegrityReport() async {
    try {
      final response = await _get('/students/integrity');
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) return _asMap(data['data']);
      throw ServerException(
        message: data['error'] ?? 'Failed to get student parent integrity',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

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

      final response = await _get('/students', queryParameters: queryParams);
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

  Future<List<Map<String, dynamic>>> getMyStudents({
    int? refreshNonce,
  }) async {
    try {
      final response = await _get(
        '/me/students',
        queryParameters: {
          if (refreshNonce != null) 'refresh_nonce': refreshNonce,
        },
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        final payload = data['data'];
        List<dynamic> studentsList = [];
        if (payload is List) {
          studentsList = payload;
        } else if (payload is Map && payload['students'] is List) {
          studentsList = payload['students'];
        }

        if (studentsList.isNotEmpty) {
          return studentsList
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
    // The parent endpoint returns the student's current class as `section`.
    // Older payloads used `current_section`, so accept both without ever
    // exposing the section UUID as a display value.
    final currentSection = _asMap(row['current_section'] ?? row['section']);
    final grade = _asMap(row['grade'] ?? currentSection['grade']);
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
    row['id'] = _firstNonEmpty([row['id'], row['student_id']]);
    row['class'] = _firstScalarText([
      row['class'],
      row['class_name'],
      row['grade_name'],
      grade['grade_name'],
      grade['name'],
    ]);
    row['section'] = _firstScalarText([
      row['section_name'],
      row['current_section_name'],
      currentSection['section_name'],
      currentSection['name'],
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

  String _firstScalarText(Iterable<dynamic> values) {
    for (final value in values) {
      if (value is Map) continue;
      final text = _trimmed(value);
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  Future<StudentModel> getStudent(String id) async {
    try {
      final response = await _get('/students/$id');
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
      final response = await _get('/students/$studentId/enrollments');
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
    String? parentUserId,
    bool requireParentLink = false,
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
          'student_id_number': studentCode ?? '',
          'current_section_id': currentSectionId ?? '',
          if ((parentUserId ?? '').trim().isNotEmpty)
            'parent_user_id': parentUserId!.trim(),
          'require_parent_link': requireParentLink,
          'admission_date': admissionDate,
          'status': status,
        },
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        await _deleteCachedPaths([
          r'/students',
          r'/fees/structures',
          r'/fees/invoices',
          r'/principal/classes',
          r'/dashboard/',
        ]);
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
    String? mimeType,
  }) async {
    try {
      final formData = FormData.fromMap({
        'photo': await _multipartStudentFile(
          filePath: filePath,
          fileBytes: fileBytes,
          fileName: fileName,
          mimeType: mimeType,
          imagePreset: ImageUploadPreset.portrait,
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
    String? mimeType,
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
          mimeType: mimeType,
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
    String? parentUserId,
    bool requireParentLink = false,
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
        'student_id_number': studentCode ?? '',
        'current_section_id': currentSectionId ?? '',
        if (parentUserId != null) 'parent_user_id': parentUserId.trim(),
        'require_parent_link': requireParentLink,
        'status': status,
      };
      if ((admissionDate ?? '').trim().isNotEmpty) {
        payload['admission_date'] = admissionDate!.trim();
      }
      final response = await _dio.put('/students/$id', data: payload);
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        await _deleteCachedPaths([
          r'/students',
          r'/fees/structures',
          r'/fees/invoices',
          r'/principal/classes',
          r'/dashboard/',
        ]);
        return;
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to update student',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<MultipartFile> _multipartStudentFile({
    String? filePath,
    Uint8List? fileBytes,
    String? fileName,
    String? mimeType,
    ImageUploadPreset imagePreset = ImageUploadPreset.content,
  }) async {
    final sourceName = (fileName ?? filePath ?? '').trim();
    if (ImageUploadOptimizer.isImage(sourceName, mimeType)) {
      final optimized = fileBytes != null && fileBytes.isNotEmpty
          ? ImageUploadOptimizer.fromBytes(
              fileBytes,
              filename: sourceName,
              mimeType: mimeType,
              preset: imagePreset,
            )
          : await ImageUploadOptimizer.fromPath(
              filePath ?? '',
              filename: sourceName,
              mimeType: mimeType,
              preset: imagePreset,
            );
      return MultipartFile.fromBytes(
        optimized.bytes,
        filename: optimized.filename,
        contentType: _resolveMediaType(optimized.mimeType, optimized.filename),
      );
    }
    if (fileBytes != null && fileBytes.isNotEmpty) {
      return MultipartFile.fromBytes(
        fileBytes,
        filename: (fileName ?? '').trim().isEmpty
            ? 'schooldesk-upload'
            : fileName!.trim(),
        contentType: _resolveMediaType(
          mimeType,
          fileName ?? 'schooldesk-upload',
        ),
      );
    }
    final cleanPath = (filePath ?? '').trim();
    if (cleanPath.isEmpty) {
      throw const ServerException(message: 'Upload file is required');
    }
    return MultipartFile.fromFile(
      cleanPath,
      filename: (fileName ?? '').trim().isEmpty ? null : fileName!.trim(),
      contentType: _resolveMediaType(mimeType, fileName ?? cleanPath),
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
