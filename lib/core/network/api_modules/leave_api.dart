part of '../backend_api_client.dart';

extension BackendLeaveApi on BackendApiClient {
  Future<List<Map<String, dynamic>>> getStudentLeaveApplications({
    String? studentId,
    String? status,
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

  Future<List<Map<String, dynamic>>> getLeaveTypes() {
    return getRawList('/leave/types');
  }

  Future<List<Map<String, dynamic>>> getLeaveBalances({
    String? staffId,
    String? academicYearId,
  }) {
    final queryParams = <String, dynamic>{};
    if (staffId != null && staffId.trim().isNotEmpty) {
      queryParams['staff_id'] = staffId.trim();
    }
    if (academicYearId != null && academicYearId.trim().isNotEmpty) {
      queryParams['academic_year_id'] = academicYearId.trim();
    }
    return getRawList(
      '/leave/balances',
      queryParameters: queryParams.isEmpty ? null : queryParams,
    );
  }

  Future<List<LeaveApplicationModel>> getLeaveApplications({
    String? staffId,
    String? status,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (staffId != null) queryParams['staff_id'] = staffId;
      if (status != null) queryParams['status'] = status;

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
