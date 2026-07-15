part of '../backend_api_client.dart';

extension BackendAttendanceApi on BackendApiClient {
  // ─── Attendance ─────────────────────────────────────────────────────────────

  Future<List<AttendanceSessionModel>> getAttendanceSessions({
    String? sectionId,
    String? date,
    String? startDate,
    String? endDate,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (sectionId != null) queryParams['section_id'] = sectionId;
      if (date != null) queryParams['date'] = date;
      if (startDate != null) queryParams['start_date'] = startDate;
      if (endDate != null) queryParams['end_date'] = endDate;

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
    required String academicYearId,
    required String subjectId,
    required String staffId,
    required String date,
    int? periodNumber,
    String? timetableSlotId,
  }) async {
    try {
      final data = {
        'section_id': sectionId,
        'academic_year_id': academicYearId,
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
    List<Map<String, dynamic>> attendances, {
    bool finalize = true,
  }) async {
    try {
      final response = await _dio.post(
        '/attendance/sessions/$sessionId/mark',
        data: {'attendances': attendances, 'finalize': finalize},
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

  Future<AttendanceSessionModel> requestAttendanceCorrection(
    String sessionId, {
    required String reason,
  }) async {
    try {
      final response = await _dio.post(
        '/attendance/sessions/$sessionId/correction-request',
        data: {'reason': reason},
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return AttendanceSessionModel.fromJson(
          data['data'] as Map<String, dynamic>,
        );
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to request attendance correction',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<AttendanceSessionModel> reopenAttendanceSession(
    String sessionId, {
    required String reason,
  }) async {
    try {
      final response = await _dio.post(
        '/attendance/sessions/$sessionId/reopen',
        data: {'reason': reason},
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return AttendanceSessionModel.fromJson(
          data['data'] as Map<String, dynamic>,
        );
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to reopen attendance session',
      );
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
  }) async {
    final queryParams = <String, dynamic>{};
    if (month != null) queryParams['month'] = month.toString().padLeft(2, '0');
    if (year != null) queryParams['year'] = '$year';
    final params = queryParams.isEmpty ? null : queryParams;
    try {
      return await getRawList(
        '/students/$studentId/attendance',
        queryParameters: params,
      );
    } on NotFoundException {
      return getRawList(
        '/attendance/students/$studentId',
        queryParameters: params,
      );
    }
  }

  Future<StaffQrTokenModel> getStaffQrToken({String? nonce}) async {
    try {
      final response = await _dio.get(
        '/attendance/staff/qr-token',
        queryParameters: {'refresh_nonce': nonce},
        options: Options(
          headers: const {'Cache-Control': 'no-store', 'Pragma': 'no-cache'},
        ),
      );
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

  Future<List<StaffAttendanceModel>> getMyStaffAttendanceLog({
    int days = 30,
  }) async {
    final rows = await getStaffAttendanceForDate();
    final today = DateTime.now();
    final startDate = DateTime(
      today.year,
      today.month,
      today.day,
    ).subtract(Duration(days: days - 1));
    final filtered =
        rows.where((row) {
          final date = row.date;
          if (date == null || row.checkIn == null) return false;
          final local = date.toLocal();
          final day = DateTime(local.year, local.month, local.day);
          return !day.isBefore(startDate);
        }).toList()..sort((a, b) {
          final aTime = a.checkIn ?? a.date ?? DateTime(1900);
          final bTime = b.checkIn ?? b.date ?? DateTime(1900);
          return bTime.compareTo(aTime);
        });
    return filtered.take(days).toList();
  }

  Future<List<StaffAttendanceModel>> getStaffAttendanceForDate({
    String? date,
    String? startDate,
    String? endDate,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (date != null && date.isNotEmpty) queryParams['date'] = date;
      if (startDate != null && startDate.isNotEmpty) {
        queryParams['start_date'] = startDate;
      }
      if (endDate != null && endDate.isNotEmpty) {
        queryParams['end_date'] = endDate;
      }

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

  Future<Uint8List> exportStaffQrLogsCsv({String? date}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (date != null && date.isNotEmpty) queryParams['date'] = date;
      final response = await _dio.get<List<int>>(
        '/attendance/staff/qr-logs/export',
        queryParameters: queryParams,
        options: Options(responseType: ResponseType.bytes),
      );
      final data = response.data;
      return Uint8List.fromList(data ?? const <int>[]);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }
}
