part of '../backend_api_client.dart';

extension BackendExamsEventsApi on BackendApiClient {
  // ─── Exams ──────────────────────────────────────────────────────────────────

  Future<List<ExamModel>> getExams({
    String? schoolId,
    String? yearId,
    String? termId,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (schoolId != null) queryParams['school_id'] = schoolId;
      if (yearId != null) queryParams['academic_year_id'] = yearId;
      if (termId != null) queryParams['term_id'] = termId;

      final response = await SchoolDeskApi.instance.client.exams(
        queryParams.isEmpty ? null : queryParams,
      );
      if (response.success == true) {
        return _asListMap(
          response.data,
        ).map((e) => ExamModel.fromJson(e)).toList();
      }
      throw ServerException(message: response.error ?? 'Failed to get exams');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<Map<String, dynamic>>> getExamTypes() async {
    try {
      final response = await _dio.get('/exams/types');
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return _asListMap(data['data']);
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to get exam types',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<Map<String, dynamic>>> getTerms(String academicYearId) async {
    try {
      final response = await _dio.get('/academic-years/$academicYearId/terms');
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return _asListMap(data['data']);
      }
      throw ServerException(message: data['error'] ?? 'Failed to get terms');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> createEvent({
    required String academicYearId,
    required String title,
    required String eventType,
    required DateTime start,
    required DateTime end,
    String location = '',
    String description = '',
    bool isHoliday = false,
  }) async {
    try {
      final response = await SchoolDeskApi.instance.client.createEvent(
        EventDto(
          academicYearId: academicYearId,
          eventName: title,
          eventType: eventType,
          description: description,
          startDate: start.toUtc().toIso8601String().split('T').first,
          endDate: end.toUtc().toIso8601String().split('T').first,
          startTime: start.toUtc().toIso8601String().split('T').last,
          endTime: end.toUtc().toIso8601String().split('T').last,
          venue: location,
          isHoliday: isHoliday,
          status: 'scheduled',
        ),
      );
      if (response.success != true) {
        throw ServerException(
          message: response.error ?? 'Failed to create event',
        );
      }
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> createExam({
    required String academicYearId,
    required String termId,
    required String examTypeId,
    required String examName,
    required String startDate,
    required String endDate,
  }) async {
    try {
      final response = await SchoolDeskApi.instance.client.createExam(
        ExamDto(
          academicYearId: academicYearId,
          termId: termId,
          examTypeId: examTypeId,
          examName: examName,
          startDate: startDate,
          endDate: endDate,
        ),
      );
      if (response.success != true) {
        throw ServerException(
          message: response.error ?? 'Failed to create exam',
        );
      }
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> updateExam(
    String id, {
    required String academicYearId,
    required String termId,
    required String examTypeId,
    required String examName,
    required String startDate,
    required String endDate,
  }) async {
    try {
      final response = await SchoolDeskApi.instance.client.updateExam(
        id,
        ExamDto(
          academicYearId: academicYearId,
          termId: termId,
          examTypeId: examTypeId,
          examName: examName,
          startDate: startDate,
          endDate: endDate,
        ),
      );
      if (response.success != true) {
        throw ServerException(
          message: response.error ?? 'Failed to update exam',
        );
      }
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> setExamPublished(String id, bool isPublished) async {
    try {
      final response = await SchoolDeskApi.instance.client.publishExam(id, {
        'is_published': isPublished,
      });
      if (response.success != true) {
        throw ServerException(
          message: response.error ?? 'Failed to update exam publish status',
        );
      }
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<Map<String, dynamic>>> getEvents({String? academicYearId}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (academicYearId != null) {
        queryParams['academic_year_id'] = academicYearId;
      }
      final response = await SchoolDeskApi.instance.client.events(
        queryParams.isEmpty ? null : queryParams,
      );
      if (response.success == true) {
        return _asListMap(response.data).map((event) {
          final normalized = Map<String, dynamic>.from(event);
          normalized['id'] ??= normalized['event_id'];
          normalized['event_title'] ??= normalized['event_name'];
          normalized['location'] ??= normalized['venue'];
          normalized['start_datetime'] ??=
              '${normalized['start_date'] ?? ''}T${normalized['start_time'] ?? '00:00:00'}';
          normalized['end_datetime'] ??=
              '${normalized['end_date'] ?? normalized['start_date'] ?? ''}T${normalized['end_time'] ?? '23:59:59'}';
          return normalized;
        }).toList();
      }
      throw ServerException(message: 'Failed to get events');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }
}
