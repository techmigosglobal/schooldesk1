part of '../backend_api_client.dart';

extension BackendAttendanceApi on BackendApiClient {
  // ─── Attendance ─────────────────────────────────────────────────────────────

  Future<List<AttendanceSessionModel>> getAttendanceSessions({
    String? sectionId,
    String? date,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (sectionId != null) queryParams['section_id'] = sectionId;
      if (date != null) queryParams['date'] = date;

      final response = await _dio.get(
        '/attendance/sessions',
        queryParameters: queryParams,
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return (data['data'] as List)
            .map(
              (e) => AttendanceSessionModel.fromJson(e as Map<String, dynamic>),
            )
            .toList();
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to get attendance sessions',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<AttendanceSessionModel> createAttendanceSession({
    required String sectionId,
    required String subjectId,
    required String staffId,
    required String date,
    int? periodNumber,
    String? timetableSlotId,
  }) async {
    try {
      final data = {
        'section_id': sectionId,
        'subject_id': subjectId,
        'staff_id': staffId,
        'date': date,
        if (periodNumber != null) 'period_number': periodNumber,
        if (timetableSlotId != null) 'timetable_slot_id': timetableSlotId,
      };

      final response = await _dio.post('/attendance/sessions', data: data);
      final responseData = response.data as Map<String, dynamic>;
      if (responseData['success'] == true) {
        return AttendanceSessionModel.fromJson(
          responseData['data'] as Map<String, dynamic>,
        );
      }
      throw ServerException(
        message: responseData['error'] ?? 'Failed to create attendance session',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> markAttendance(
    String sessionId,
    List<Map<String, dynamic>> attendances,
  ) async {
    try {
      final response = await _dio.post(
        '/attendance/sessions/$sessionId/mark',
        data: {'attendances': attendances},
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] != true) {
        throw ServerException(
          message: data['error'] ?? 'Failed to mark attendance',
        );
      }
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getStudentAttendanceSummary({
    required String studentId,
    String? academicYearId,
    String? termId,
  }) async {
    try {
      final queryParams = <String, dynamic>{'student_id': studentId};
      if (academicYearId != null && academicYearId.isNotEmpty) {
        queryParams['academic_year_id'] = academicYearId;
      }
      if (termId != null && termId.isNotEmpty) {
        queryParams['term_id'] = termId;
      }

      final response = await _dio.get(
        '/attendance/summary',
        queryParameters: queryParams,
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        final payload = data['data'];
        if (payload is Map) return Map<String, dynamic>.from(payload);
        return <String, dynamic>{};
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to get attendance summary',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<Map<String, dynamic>>> getStudentAttendanceRecords(
    String studentId, {
    int? month,
    int? year,
  }) {
    final queryParams = <String, dynamic>{};
    if (month != null) queryParams['month'] = month.toString().padLeft(2, '0');
    if (year != null) queryParams['year'] = '$year';
    return getRawList(
      '/students/$studentId/attendance',
      queryParameters: queryParams.isEmpty ? null : queryParams,
    );
  }

  Future<StaffQrTokenModel> getStaffQrToken() async {
    try {
      final response = await _dio.get('/attendance/staff/qr-token');
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return StaffQrTokenModel.fromJson(
          Map<String, dynamic>.from(data['data'] as Map),
        );
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to create staff QR code',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<StaffAttendanceModel> scanStaffQr(String token) async {
    try {
      final response = await _dio.post(
        '/attendance/staff/qr-scan',
        data: {'token': token},
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return StaffAttendanceModel.fromJson(
          Map<String, dynamic>.from(data['data'] as Map),
        );
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to record staff attendance',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<StaffAttendanceModel?> getMyStaffAttendanceToday() async {
    try {
      final response = await _dio.get('/attendance/staff/me/today');
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        final payload = data['data'];
        if (payload is Map) {
          final attendance = payload['attendance'];
          if (attendance is Map) {
            return StaffAttendanceModel.fromJson(
              Map<String, dynamic>.from(attendance),
            );
          }
        }
        return null;
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to load staff attendance',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<StaffAttendanceModel>> getStaffAttendanceForDate({
    String? date,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (date != null && date.isNotEmpty) queryParams['date'] = date;

      final response = await _dio.get(
        '/attendance/staff',
        queryParameters: queryParams,
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        final payload = data['data'];
        final rows = payload is Map ? payload['attendances'] : payload;
        if (rows is List) {
          return rows
              .whereType<Map>()
              .map(
                (item) => StaffAttendanceModel.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList();
        }
        return const [];
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to load staff attendance',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }
}
