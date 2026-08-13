part of '../backend_api_client.dart';

extension BackendUsersApi on BackendApiClient {
  Future<Map<String, dynamic>> getAccessPermissions() async {
    try {
      final response = await _get('/access/permissions');
      final data = _asMap(response.data);
      if (data['success'] == true) return _asMap(data['data']);
      throw ServerException(
        message:
            data['message'] ?? data['error'] ?? 'Failed to load permissions',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<PaginatedList<UserAccountModel>> getUsers({
    String? role,
    String? status,
    int page = 1,
    int pageSize = 50,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'page_size': pageSize,
      };
      if (role != null && role.trim().isNotEmpty) {
        queryParams['role'] = role.trim();
      }
      if (status != null && status.trim().isNotEmpty) {
        queryParams['status'] = status.trim();
      }

      final response = await _get('/users', queryParameters: queryParams);
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return PaginatedList<UserAccountModel>(
          data: (data['data'] as List)
              .map((e) => UserAccountModel.fromJson(e as Map<String, dynamic>))
              .toList(),
          total: data['total'] as int,
          page: data['page'] as int,
          pageSize: data['page_size'] as int,
        );
      }
      throw ServerException(message: data['error'] ?? 'Failed to get users');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<UserAccountModel> createUser({
    required String username,
    required String password,
    required String role,
    String fullName = '',
    String email = '',
    String phone = '',
    bool isActive = true,
    bool requestPrincipalApproval = false,
  }) async {
    try {
      final cleanUsername = username.trim();
      final cleanEmail = email.trim();
      final response = await _dio.post(
        '/users',
        data: {
          'name': fullName.trim(),
          'username': cleanUsername,
          'password': password,
          'role': role,
          if (cleanEmail.isNotEmpty) 'email': cleanEmail,
          'phone': phone,
          'is_active': isActive,
        },
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return UserAccountModel.fromJson(data['data'] as Map<String, dynamic>);
      }
      throw ServerException(message: data['error'] ?? 'Failed to create user');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<UserAccountModel> updateUser(
    String id, {
    String? username,
    String? password,
    String? role,
    String? fullName,
    String? email,
    String? phone,
    bool? isActive,
  }) async {
    try {
      final payload = <String, dynamic>{};
      if (username != null && username.trim().isNotEmpty) {
        payload['username'] = username.trim();
      }
      if (password != null && password.isNotEmpty) {
        payload['password'] = password;
      }
      if (role != null) payload['role'] = role;
      if (fullName != null) payload['name'] = fullName;
      if (email != null) payload['email'] = email;
      if (phone != null) payload['phone'] = phone;
      if (isActive != null) payload['is_active'] = isActive;
      final response = await _dio.patch('/users/$id', data: payload);
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return UserAccountModel.fromJson(data['data'] as Map<String, dynamic>);
      }
      throw ServerException(message: data['error'] ?? 'Failed to update user');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Returns a temporary password exactly once. It is never stored locally.
  Future<Map<String, dynamic>> resetUserCredentials(String id) async {
    try {
      final response = await _dio.post('/users/$id/reset-credentials');
      final data = _asMap(response.data);
      if (data['success'] != true) {
        throw ServerException(
          message: data['error'] ?? 'Failed to reset credentials',
        );
      }
      return _asMap(data['data']);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<String> uploadUserAvatar({
    required String userId,
    String filePath = '',
    Uint8List? fileBytes,
    String? fileName,
    String? mimeType,
  }) async {
    try {
      final formData = FormData.fromMap({
        'avatar': await _multipartUpload(
          filePath: filePath,
          fileBytes: fileBytes,
          filename: (fileName ?? '').trim().isEmpty
              ? 'parent-avatar.jpg'
              : fileName!.trim(),
          contentType: _resolveMediaType(mimeType, fileName ?? filePath),
        ),
      });
      final response = await _dio.post('/users/$userId/avatar', data: formData);
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        final payload = data['data'] as Map<String, dynamic>? ?? {};
        return '${payload['avatar'] ?? payload['avatar_url'] ?? ''}';
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to upload user avatar',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> deleteUser(String id, {bool permanent = false}) async {
    try {
      final response = await _dio.delete(
        '/users/$id',
        queryParameters: permanent ? {'permanent': true} : null,
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) return;
      throw ServerException(message: data['error'] ?? 'Failed to delete user');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> assignParentStudents({
    required String parentUserId,
    required List<String> admissionNumbers,
    List<String> studentIds = const [],
  }) async {
    try {
      final cleaned = admissionNumbers
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      final cleanedStudentIds = studentIds
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      final response = await _dio.post(
        '/parents/$parentUserId/students',
        data: {'admission_numbers': cleaned, 'student_ids': cleanedStudentIds},
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] != true) {
        throw ServerException(
          message: data['error'] ?? 'Failed to assign students',
        );
      }
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<Map<String, dynamic>>> getParentStudents({
    required String parentUserId,
  }) async {
    try {
      final response = await _get('/parents/$parentUserId/students');
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        final payload = data['data'];
        if (payload is Map) {
          return _asListMap(payload['students']);
        }
        return _asListMap(payload);
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to get parent students',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> setStudentParent({
    required String studentId,
    String? parentUserId,
  }) async {
    try {
      final response = await _dio.put(
        '/students/$studentId/parent',
        data: {'parent_user_id': parentUserId?.trim() ?? ''},
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] != true) {
        throw ServerException(
          message: data['error'] ?? 'Failed to update student parent',
        );
      }
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Links a guardian record to a student via the student_guardians join table.
  /// Calls POST /students/:studentId/guardians — the dedicated backend endpoint
  /// that correctly creates the StudentGuardian row (unlike POST /guardians CRUD
  /// which ignores student_id because Guardian.StudentID is gorm:"-").
  Future<void> linkGuardianToStudent({
    required String studentId,
    required String guardianId,
    bool isPrimary = false,
    bool canPickup = false,
  }) async {
    try {
      final response = await _dio.post(
        '/students/$studentId/guardians',
        data: {
          'guardian_id': guardianId,
          'is_primary': isPrimary,
          'can_pickup': canPickup,
        },
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] != true && data['message'] == null) {
        throw ServerException(
          message: data['error'] ?? 'Failed to link parent to student',
        );
      }
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }
}
