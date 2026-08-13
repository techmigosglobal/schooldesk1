part of '../backend_api_client.dart';

extension BackendStaffApi on BackendApiClient {
  // ─── Staff ──────────────────────────────────────────────────────────────────

  Future<PaginatedList<StaffModel>> getStaff({
    String? schoolId,
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
      if (status != null) queryParams['status'] = status;

      final response = await _get('/staff', queryParameters: queryParams);
      final data = _asMap(response.data);
      if (data['success'] == true) {
        final payload = _asMap(data['data']);
        final rows = data['data'] is List ? data['data'] : payload['data'];
        return PaginatedList<StaffModel>(
          data: (rows as List? ?? const [])
              .whereType<Map>()
              .map((e) => StaffModel.fromJson(Map<String, dynamic>.from(e)))
              .toList(),
          total: _intValue(data['total'] ?? payload['total']),
          page: _intValue(data['page'] ?? payload['page'], fallback: page),
          pageSize: _intValue(
            data['page_size'] ?? payload['page_size'],
            fallback: pageSize,
          ),
        );
      }
      throw ServerException(message: data['error'] ?? 'Failed to get staff');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  int _intValue(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  Future<StaffModel> getStaffMember(String id) async {
    try {
      final response = await _get('/staff/$id');
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return StaffModel.fromJson(data['data'] as Map<String, dynamic>);
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to get staff member',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<StaffModel> createStaff({
    required String firstName,
    required String lastName,
    String? staffCode,
    String? username,
    String? email,
    String? phone,
    String? designation,
    String? password,
    String accountRole = 'Teacher',
    String gender = 'unspecified',
    String? employmentType,
    String? joinDate,
    String? dateOfBirth,
    double basicSalary = 0,
    bool requestPrincipalApproval = false,
  }) async {
    try {
      final response = await _dio.post(
        '/staff',
        data: {
          if (staffCode != null && staffCode.trim().isNotEmpty)
            'staff_code': staffCode.trim(),
          if (username != null && username.trim().isNotEmpty)
            'username': username.trim(),
          'first_name': firstName,
          'last_name': lastName,
          'email': email ?? '',
          'phone': phone ?? '',
          'designation': designation ?? '',
          if (password != null && password.trim().isNotEmpty)
            'password': password.trim(),
          'account_role': accountRole,
          'request_principal_approval': requestPrincipalApproval,
          'gender': gender,
          if (employmentType != null && employmentType.trim().isNotEmpty)
            'employment_type': employmentType.trim(),
          if (joinDate != null && joinDate.trim().isNotEmpty)
            'join_date': joinDate.trim(),
          if (dateOfBirth != null && dateOfBirth.trim().isNotEmpty)
            'date_of_birth': dateOfBirth.trim(),
          'basic_salary': basicSalary,
        },
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return StaffModel.fromJson(data['data'] as Map<String, dynamic>);
      }
      throw ServerException(message: data['error'] ?? 'Failed to create staff');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<String> uploadStaffPhoto({
    required String staffId,
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
      final response = await _dio.post('/staff/$staffId/photo', data: formData);
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        final payload = data['data'] as Map<String, dynamic>? ?? {};
        return '${payload['photo'] ?? payload['photo_url'] ?? ''}';
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to upload staff photo',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<String> uploadStaffDocument({
    required String staffId,
    String? filePath,
    Uint8List? fileBytes,
    String? fileName,
    String? mimeType,
    required String documentType,
  }) async {
    try {
      final formData = FormData.fromMap({
        'doc_type': documentType.trim().isEmpty
            ? 'staff_document'
            : documentType.trim(),
        'document': await _multipartStudentFile(
          filePath: filePath,
          fileBytes: fileBytes,
          fileName: fileName,
          mimeType: mimeType,
        ),
      });
      final response = await _dio.post(
        '/staff/$staffId/documents',
        data: formData,
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        final payload = data['data'] as Map<String, dynamic>? ?? {};
        return '${payload['file_url'] ?? ''}';
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to upload staff document',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> updateStaff(
    String id, {
    required String firstName,
    required String lastName,
    String? staffCode,
    String? username,
    String? email,
    String? phone,
    String? designation,
    String? password,
    String accountRole = 'Teacher',
    String gender = 'unspecified',
    String? employmentType,
    String? joinDate,
    String? dateOfBirth,
    double basicSalary = 0,
  }) async {
    try {
      final response = await _dio.put(
        '/staff/$id',
        data: {
          if (staffCode != null && staffCode.trim().isNotEmpty)
            'staff_code': staffCode.trim(),
          if (username != null && username.trim().isNotEmpty)
            'username': username.trim(),
          'first_name': firstName,
          'last_name': lastName,
          'email': email ?? '',
          'phone': phone ?? '',
          'designation': designation ?? '',
          if (password != null && password.trim().isNotEmpty)
            'password': password.trim(),
          'account_role': accountRole,
          'gender': gender,
          if (employmentType != null && employmentType.trim().isNotEmpty)
            'employment_type': employmentType.trim(),
          if (joinDate != null && joinDate.trim().isNotEmpty)
            'join_date': joinDate.trim(),
          if (dateOfBirth != null && dateOfBirth.trim().isNotEmpty)
            'date_of_birth': dateOfBirth.trim(),
          'basic_salary': basicSalary,
        },
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] != true) {
        throw ServerException(
          message: data['error'] ?? 'Failed to update staff',
        );
      }
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> deleteStaff(String id) async {
    try {
      final response = await _dio.delete('/staff/$id');
      final data = response.data as Map<String, dynamic>;
      if (data['success'] != true) {
        throw ServerException(
          message: data['error'] ?? 'Failed to delete staff',
        );
      }
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }
}
