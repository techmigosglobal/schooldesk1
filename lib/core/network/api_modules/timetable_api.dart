part of '../backend_api_client.dart';

extension BackendTimetableApi on BackendApiClient {
  Future<List<Map<String, dynamic>>> getTimetableSlots({
    String? sectionId,
    String? academicYearId,
    int? dayOfWeek,
    String? staffId,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (sectionId != null) {
        queryParams['section_id'] = sectionId;
      }
      if (academicYearId != null) {
        queryParams['academic_year_id'] = academicYearId;
      }
      if (dayOfWeek != null) {
        queryParams['day_of_week'] = dayOfWeek;
      }
      if (staffId != null) {
        queryParams['staff_id'] = staffId;
      }
      final response = await _dio.get(
        '/timetable/slots',
        queryParameters: queryParams,
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return _asListMap(data['data']);
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to get timetable slots',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<TimetableSuggestionResult> suggestTimetableSlots({
    required String sectionId,
    required String academicYearId,
    required String termId,
    required int dayOfWeek,
    int periodCount = 7,
    String startTime = '09:00',
    int periodDurationMinutes = 40,
    int gapMinutes = 5,
  }) async {
    try {
      final response = await _dio.post(
        '/timetable/suggestions',
        data: {
          'section_id': sectionId,
          'academic_year_id': academicYearId,
          'term_id': termId,
          'day_of_week': dayOfWeek,
          'period_count': periodCount,
          'start_time': startTime,
          'period_duration_minutes': periodDurationMinutes,
          'gap_minutes': gapMinutes,
        },
      );
      final data = _asMap(response.data);
      if (data['success'] == true) {
        return TimetableSuggestionResult.fromJson(_asMap(data['data']));
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to generate timetable suggestions',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<TimetableGenerationResult> generateTimetableSlots({
    required String sectionId,
    required String academicYearId,
    required String termId,
    required int dayOfWeek,
    int periodCount = 7,
    String startTime = '09:00',
    int periodDurationMinutes = 40,
    int gapMinutes = 5,
  }) async {
    try {
      final response = await _dio.post(
        '/timetable/slots/generate',
        data: {
          'section_id': sectionId,
          'academic_year_id': academicYearId,
          'term_id': termId,
          'day_of_week': dayOfWeek,
          'period_count': periodCount,
          'start_time': startTime,
          'period_duration_minutes': periodDurationMinutes,
          'gap_minutes': gapMinutes,
        },
      );
      final data = _asMap(response.data);
      if (data['success'] == true) {
        return TimetableGenerationResult.fromJson(_asMap(data['data']));
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to apply timetable suggestions',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<Map<String, dynamic>>> getTimetableTemplates({
    String? academicYearId,
  }) async {
    try {
      final response = await _dio.get(
        '/timetable/templates',
        queryParameters: {
          if (academicYearId != null && academicYearId.trim().isNotEmpty)
            'academic_year_id': academicYearId.trim(),
        },
      );
      final data = _asMap(response.data);
      if (data['success'] == true) return _asListMap(data['data']);
      throw ServerException(
        message: data['error'] ?? 'Failed to load timetable templates',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> saveTimetableTemplate({
    required String academicYearId,
    String id = '',
    String name = 'Class setup smart timetable',
    List<int> workingDays = const [1, 2, 3, 4, 5, 6],
    int periodsPerDay = 8,
    int periodDurationMinutes = 40,
    int gapMinutes = 5,
    String startTime = '08:30',
    String endTime = '',
    List<Map<String, dynamic>> breaks = const [],
    bool isDefault = true,
  }) async {
    try {
      final response = await _dio.put(
        '/timetable/templates',
        data: {
          'id': id.trim(),
          'academic_year_id': academicYearId.trim(),
          'name': name.trim().isEmpty ? 'Class setup smart timetable' : name,
          'working_days': workingDays,
          'periods_per_day': periodsPerDay,
          'period_duration_minutes': periodDurationMinutes,
          'gap_minutes': gapMinutes,
          'start_time': startTime.trim(),
          'end_time': endTime.trim(),
          'breaks': breaks,
          'is_default': isDefault,
        },
      );
      final data = _asMap(response.data);
      if (data['success'] == true) return _asMap(data['data']);
      throw ServerException(
        message: data['error'] ?? 'Failed to save timetable template',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> previewSmartTimetable({
    required String sectionId,
    required String academicYearId,
    required String termId,
    List<int> days = const [1, 2, 3, 4, 5, 6],
    int periodsPerDay = 8,
    String startTime = '08:30',
    int periodDurationMinutes = 40,
    int gapMinutes = 5,
    List<Map<String, dynamic>> breaks = const [],
  }) async {
    return _smartTimetable(
      path: '/timetable/smart/preview',
      sectionId: sectionId,
      academicYearId: academicYearId,
      termId: termId,
      days: days,
      periodsPerDay: periodsPerDay,
      startTime: startTime,
      periodDurationMinutes: periodDurationMinutes,
      gapMinutes: gapMinutes,
      breaks: breaks,
    );
  }

  Future<Map<String, dynamic>> generateSmartTimetable({
    required String sectionId,
    required String academicYearId,
    required String termId,
    List<int> days = const [1, 2, 3, 4, 5, 6],
    int periodsPerDay = 8,
    String startTime = '08:30',
    int periodDurationMinutes = 40,
    int gapMinutes = 5,
    List<Map<String, dynamic>> breaks = const [],
    bool regenerateScope = true,
  }) async {
    return _smartTimetable(
      path: '/timetable/smart/generate',
      sectionId: sectionId,
      academicYearId: academicYearId,
      termId: termId,
      days: days,
      periodsPerDay: periodsPerDay,
      startTime: startTime,
      periodDurationMinutes: periodDurationMinutes,
      gapMinutes: gapMinutes,
      breaks: breaks,
      regenerateScope: regenerateScope,
    );
  }

  Future<Map<String, dynamic>> _smartTimetable({
    required String path,
    required String sectionId,
    required String academicYearId,
    required String termId,
    required List<int> days,
    required int periodsPerDay,
    required String startTime,
    required int periodDurationMinutes,
    required int gapMinutes,
    required List<Map<String, dynamic>> breaks,
    bool regenerateScope = false,
  }) async {
    try {
      final response = await _dio.post(
        path,
        data: {
          'section_id': sectionId.trim(),
          'academic_year_id': academicYearId.trim(),
          'term_id': termId.trim(),
          'mode': regenerateScope ? 'regenerate_scope' : 'preview',
          'days': days,
          'periods_per_day': periodsPerDay,
          'start_time': startTime.trim(),
          'period_duration_minutes': periodDurationMinutes,
          'gap_minutes': gapMinutes,
          'breaks': breaks,
          'regenerate_scope': regenerateScope,
        },
      );
      final data = _asMap(response.data);
      if (data['success'] == true) return _asMap(data['data']);
      throw ServerException(
        message: data['error'] ?? 'Failed to run smart timetable',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<Map<String, dynamic>>> getSubstitutions({
    String? date,
    String? originalStaffId,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (date != null) {
        queryParams['date'] = date;
      }
      if (originalStaffId != null) {
        queryParams['original_staff_id'] = originalStaffId;
      }
      final response = await _dio.get(
        '/timetable/substitutions',
        queryParameters: queryParams,
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return _asListMap(data['data']);
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to get substitutions',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }
}
