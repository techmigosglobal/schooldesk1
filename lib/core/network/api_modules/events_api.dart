part of '../backend_api_client.dart';

extension BackendEventsApi on BackendApiClient {
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

  Future<String> uploadFile(String filePath, {required String filename}) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath, filename: filename),
      });
      final response = await _dio.post('/uploads', data: formData);
      final data = _asMap(response.data);
      final nested = _asMap(data['data']);
      final url = _firstNonEmpty([data['url'], nested['url']]);
      if (url.isNotEmpty) return url;
      throw ServerException(message: data['error'] ?? 'Upload failed');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<Map<String, dynamic>>> getTeacherEventPosts() async {
    try {
      final response = await _dio.get('/event-posts/teacher');
      final data = response.data;
      if (data is List) return _asListMap(data);
      final mapped = _asMap(data);
      if (mapped['success'] == false) {
        throw ServerException(
          message: mapped['error'] ?? 'Failed to load event posts',
        );
      }
      return _asListMap(mapped['data']);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<Map<String, dynamic>>> getPendingEventPosts() async {
    try {
      final response = await _dio.get('/event-posts/pending');
      final data = response.data;
      final rows = data is List
          ? data
          : (data is Map ? data['data'] as List? ?? const [] : const []);
      return rows
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<Map<String, dynamic>>> getGalleryEventPosts() async {
    try {
      final response = await _dio.get('/event-posts/gallery');
      final data = response.data;
      final rows = data is List
          ? data
          : (data is Map ? data['data'] as List? ?? const [] : const []);
      return rows
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<Map<String, dynamic>>> getHomeFeedEventPosts() async {
    try {
      final response = await _dio.get('/event-posts/home-feed');
      final data = response.data;
      final rows = data is List
          ? data
          : (data is Map ? data['data'] as List? ?? const [] : const []);
      return rows
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> approveEventPost(String id) async {
    try {
      await _dio.post('/event-posts/$id/approve');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> rejectEventPost(String id, {required String reason}) async {
    try {
      await _dio.post('/event-posts/$id/reject', data: {'reason': reason});
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> createEventPost({
    required String title,
    required String description,
    required String eventDate,
    required List<String> mediaUrls,
    required List<String> destinations,
    required bool isSubmit,
  }) async {
    try {
      final response = await _dio.post(
        '/event-posts',
        data: {
          'title': title,
          'description': description,
          'event_date': eventDate,
          'media_urls': mediaUrls.join(','),
          'destinations': destinations,
          'is_submit': isSubmit,
        },
      );
      final data = _asMap(response.data);
      if (data['success'] == false) {
        throw ServerException(
          message: data['error'] ?? 'Failed to submit event post',
        );
      }
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<Map<String, dynamic>>> getTeacherLessonPlanners() async {
    try {
      final response = await _dio.get('/lesson-planners/teacher');
      final data = _asMap(response.data);
      if (data['success'] == false) {
        throw ServerException(
          message: data['error'] ?? 'Failed to load lesson planners',
        );
      }
      return _asListMap(data['data']);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<Map<String, dynamic>>> getPrincipalLessonPlanners() async {
    try {
      final response = await _dio.get('/lesson-planners/principal');
      final data = _asMap(response.data);
      if (data['success'] == false) {
        throw ServerException(
          message: data['error'] ?? 'Failed to load lesson planners',
        );
      }
      return _asListMap(data['data']);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<Map<String, dynamic>>> getParentLessonPlanners() async {
    try {
      final response = await _dio.get('/lesson-planners/parent');
      final data = response.data;
      final rows = data is List
          ? data
          : (data is Map ? data['data'] as List? ?? const [] : const []);
      return rows
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> createLessonPlanner({
    required String gradeId,
    required String sectionId,
    required String weekStartDate,
    required String weekEndDate,
    required String attachmentUrl,
    required String note,
  }) async {
    try {
      final response = await _dio.post(
        '/lesson-planners',
        data: {
          'grade_id': gradeId,
          'section_id': sectionId,
          'week_start_date': weekStartDate,
          'week_end_date': weekEndDate,
          'attachment_url': attachmentUrl,
          'note': note,
        },
      );
      final data = _asMap(response.data);
      if (data['success'] == false) {
        throw ServerException(
          message: data['error'] ?? 'Failed to create lesson planner',
        );
      }
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> completeLessonPlanner(String id) async {
    try {
      final response = await _dio.post('/lesson-planners/$id/complete');
      final data = _asMap(response.data);
      if (data['success'] == false) {
        throw ServerException(
          message: data['error'] ?? 'Failed to complete lesson planner',
        );
      }
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }
}
