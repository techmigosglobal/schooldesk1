part of '../backend_api_client.dart';

extension BackendLeaveApi on BackendApiClient {
  Future<List<Map<String, dynamic>>> getStudentLeaveApplications({
    String? studentId,
    String? status,
    bool forceRefresh = false,
    int page = 1,
    int pageSize = 100,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'page_size': pageSize,
      };
      if (studentId != null && studentId.trim().isNotEmpty) {
        queryParams['student_id'] = studentId.trim();
      }
      if (status != null && status.trim().isNotEmpty) {
        queryParams['status'] = status.trim();
      }
      if (forceRefresh) {
        queryParams['refresh_nonce'] = DateTime.now().millisecondsSinceEpoch;
      }
      final response = await _dio.get(
        '/student-leave/applications',
        queryParameters: queryParams,
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return _asListMap(data['data']);
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to load student leave applications',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> submitStudentLeaveApplication({
    required String studentId,
    required String leaveType,
    required String fromDate,
    required String toDate,
    required String reason,
    bool halfDay = false,
  }) async {
    try {
      final response = await _dio.post(
        '/student-leave/applications',
        data: {
          'student_id': studentId,
          'leave_type': leaveType,
          'from_date': fromDate,
          'to_date': toDate,
          'half_day': halfDay,
          'reason': reason,
        },
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return Map<String, dynamic>.from(data['data'] as Map);
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to submit student leave application',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> decideStudentLeaveApplication(
    String id, {
    required String status,
    String rejectionReason = '',
  }) async {
    try {
      final response = await _dio.put(
        '/student-leave/applications/$id/decision',
        data: {
          'status': status,
          if (rejectionReason.trim().isNotEmpty)
            'rejection_reason': rejectionReason.trim(),
        },
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return Map<String, dynamic>.from(data['data'] as Map);
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to update student leave application',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ─── Leave ──────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getLeaveTypes({
    bool forceRefresh = false,
  }) {
    return getRawList(
      '/leave/types',
      queryParameters: forceRefresh
          ? {'refresh_nonce': DateTime.now().millisecondsSinceEpoch}
          : null,
    );
  }

  Future<List<Map<String, dynamic>>> getLeaveBalances({
    String? staffId,
    String? academicYearId,
    bool forceRefresh = false,
  }) {
    final queryParams = <String, dynamic>{};
    if (staffId != null && staffId.trim().isNotEmpty) {
      queryParams['staff_id'] = staffId.trim();
    }
    if (academicYearId != null && academicYearId.trim().isNotEmpty) {
      queryParams['academic_year_id'] = academicYearId.trim();
    }
    if (forceRefresh) {
      queryParams['refresh_nonce'] = DateTime.now().millisecondsSinceEpoch;
    }
    return getRawList(
      '/leave/balances',
      queryParameters: queryParams.isEmpty ? null : queryParams,
    );
  }

  Future<List<LeaveApplicationModel>> getLeaveApplications({
    String? staffId,
    String? status,
    bool forceRefresh = false,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (staffId != null) queryParams['staff_id'] = staffId;
      if (status != null) queryParams['status'] = status;
      if (forceRefresh) {
        queryParams['refresh_nonce'] = DateTime.now().millisecondsSinceEpoch;
      }

      final response = await _dio.get(
        '/leave/applications',
        queryParameters: queryParams,
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return (data['data'] as List)
            .map(
              (e) => LeaveApplicationModel.fromJson(e as Map<String, dynamic>),
            )
            .toList();
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to get leave applications',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> submitLeaveApplication(LeaveApplicationRequest request) async {
    try {
      final response = await _dio.post(
        '/leave/applications',
        data: request.toJson(),
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] != true) {
        throw ServerException(
          message: data['error'] ?? 'Failed to submit leave application',
        );
      }
      return;
    } on DioException catch (e) {
      // If backend schema doesn't have `half_day`, retry without that key.
      try {
        final respData = e.response?.data;
        final msg = respData is Map<String, dynamic>
            ? (respData['error'] ?? respData['message'] ?? '')
            : respData?.toString() ?? '';
        if (msg.toString().toLowerCase().contains('half_day') ||
            msg.toString().toLowerCase().contains(
              "could not find the 'half_day'",
            )) {
          final payload = Map<String, dynamic>.from(request.toJson());
          payload.remove('half_day');
          final retryResp = await _dio.post(
            '/leave/applications',
            data: payload,
          );
          final retryData = retryResp.data as Map<String, dynamic>;
          if (retryData['success'] == true) return;
          throw ServerException(
            message: retryData['error'] ?? 'Failed to submit leave application',
          );
        }
      } on Object catch (_) {
        // fall-through to throw original handled error
      }
      throw _handleError(e);
    }
  }

  Future<void> recallLeaveApplication(String id) async {
    try {
      final response = await _dio.post('/leave/applications/$id/recall');
      final data = response.data as Map<String, dynamic>;
      if (data['success'] != true) {
        throw ServerException(
          message: data['error'] ?? 'Failed to recall leave application',
        );
      }
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> decideLeaveApplication(
    String id, {
    required String status,
    String reason = '',
  }) async {
    try {
      final response = await _dio.put(
        '/leave/applications/$id/approve',
        data: {'status': status, 'reason': reason},
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] != true) {
        throw ServerException(
          message: data['error'] ?? 'Failed to update leave application',
        );
      }
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }
}
