part of '../backend_api_client.dart';

extension BackendEventsApi on BackendApiClient {
  Future<Map<String, dynamic>> getCalendarPreferences() async {
    try {
      final response = await _get('/events/calendar-preferences');
      final data = _asMap(response.data);
      if (data['success'] == true) return _asMap(data['data']);
      throw ServerException(
        message: data['error'] ?? 'Failed to load calendar preferences',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> resetSchoolCalendar() async {
    try {
      final response = await _dio.post(
        '/events/calendar-reset',
        data: const {'confirmation': 'RESET'},
      );
      final data = _asMap(response.data);
      if (data['success'] == true) return _asMap(data['data']);
      throw ServerException(
        message: data['error'] ?? 'Failed to reset calendar',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<Map<String, dynamic>>> getTerms(String academicYearId) async {
    try {
      final response = await _get('/academic-years/$academicYearId/terms');
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
    await createEventPayload({
      'academic_year_id': academicYearId,
      'event_title': title,
      'event_name': title,
      'event_type': eventType,
      'description': description,
      'start_date': start.toIso8601String().split('T').first,
      'end_date': end.toIso8601String().split('T').first,
      'event_date': start.toUtc().toIso8601String(),
      'start_datetime': start.toIso8601String(),
      'end_datetime': end.toIso8601String(),
      'location': location,
      'venue': location,
      'is_holiday': isHoliday,
    });
  }

  Future<void> createEventPayload(Map<String, dynamic> payload) async {
    try {
      final response = await _dio.post('/events', data: payload);
      final data = _asMap(response.data);
      if (data['success'] == false) {
        throw ServerException(
          message: data['error'] ?? 'Failed to create event',
        );
      }
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<Map<String, dynamic>>> getHolidays({
    String? academicYearId,
  }) async {
    try {
      final queryParameters = <String, dynamic>{};
      if (academicYearId != null && academicYearId.trim().isNotEmpty) {
        queryParameters['academic_year_id'] = academicYearId.trim();
      }
      final response = await _get(
        '/holidays',
        queryParameters: queryParameters.isEmpty ? null : queryParameters,
      );
      final data = _asMap(response.data);
      if (data['success'] == true) return _asListMap(data['data']);
      throw ServerException(message: data['error'] ?? 'Failed to get holidays');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<PaginatedList<Map<String, dynamic>>> getEventsPage({
    String? academicYearId,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final filters = <String, dynamic>{'page': page, 'page_size': pageSize};
      if (academicYearId != null && academicYearId.trim().isNotEmpty) {
        filters['academic_year_id'] = academicYearId.trim();
      }
      final pageResult = await _generatedEventPage(
        filters,
        page: page,
        pageSize: pageSize,
      );
      return PaginatedList<Map<String, dynamic>>(
        data: pageResult.data.map((event) {
          final normalized = Map<String, dynamic>.from(event);
          normalized['id'] ??= normalized['event_id'];
          normalized['event_title'] ??=
              normalized['event_name'] ?? normalized['title'];
          normalized['location'] ??= normalized['venue'];
          normalized['start_date'] ??= normalized['event_date'];
          normalized['end_date'] ??= normalized['event_date'];
          normalized['start_datetime'] ??=
              '${normalized['start_date'] ?? ''}T${normalized['start_time'] ?? '00:00:00'}';
          normalized['end_datetime'] ??=
              '${normalized['end_date'] ?? normalized['start_date'] ?? ''}T${normalized['end_time'] ?? '23:59:59'}';
          return normalized;
        }).toList(),
        total: pageResult.total,
        page: pageResult.page,
        pageSize: pageResult.pageSize,
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<Map<String, dynamic>>> getEvents({String? academicYearId}) async {
    return (await getEventsPage(
      academicYearId: academicYearId,
      page: 1,
      pageSize: 100,
    )).data;
  }

  Future<PaginatedList<Map<String, dynamic>>> _generatedEventPage(
    Map<String, dynamic> filters, {
    required int page,
    required int pageSize,
  }) async {
    final response = await SchoolDeskApi.instance.client.events(filters);
    return PaginatedList<Map<String, dynamic>>(
      data: response.data
          .whereType<Map>()
          .map((event) => Map<String, dynamic>.from(event))
          .toList(),
      total: response.total,
      page: response.page,
      pageSize: response.pageSize,
    );
  }

  Future<List<Map<String, dynamic>>> getTeacherEventPosts() async {
    try {
      return (await _getEventPostsPage(
        '/event-posts/teacher',
        pageSize: 100,
      )).data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<Map<String, dynamic>>> getPendingEventPosts() async {
    try {
      return (await _getEventPostsPage(
        '/event-posts/pending',
        pageSize: 100,
      )).data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Principal-only management list. Includes drafts, pending, approved and
  /// published posts so a principal can correct or remove a post after it has
  /// appeared in a school surface.
  Future<List<Map<String, dynamic>>> getPrincipalEventPosts() async {
    try {
      return (await _getEventPostsPage('/event-posts', pageSize: 100)).data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getEventPost(String id) async {
    final safeId = id.trim();
    if (safeId.isEmpty) {
      throw const ServerException(message: 'Event post id is required');
    }
    return getRawMap('/event-posts/$safeId');
  }

  Future<List<Map<String, dynamic>>> getGalleryEventPosts({
    bool forceRefresh = false,
  }) async {
    try {
      return (await _getEventPostsPage(
        '/event-posts/gallery',
        pageSize: 100,
        forceRefresh: forceRefresh,
      )).data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<PaginatedList<Map<String, dynamic>>> getHomeFeedEventPostsPage({
    int page = 1,
    int pageSize = 20,
  }) {
    return _getEventPostsPage(
      '/event-posts/home-feed',
      page: page,
      pageSize: pageSize,
    );
  }

  /// Teacher feed is intentionally not the parent home feed. It includes
  /// approved teacher-targeted updates plus school-wide parent/gallery posts,
  /// while the backend remains responsible for role and school scope.
  Future<PaginatedList<Map<String, dynamic>>> getTeacherSchoolFeedPage({
    int page = 1,
    int pageSize = 20,
  }) {
    return _getEventPostsPage(
      '/event-posts/teacher-feed',
      page: page,
      pageSize: pageSize,
    );
  }

  Future<List<Map<String, dynamic>>> getHomeFeedEventPosts() async {
    return (await getHomeFeedEventPostsPage(page: 1, pageSize: 100)).data;
  }

  Future<PaginatedList<Map<String, dynamic>>> _getEventPostsPage(
    String path, {
    int page = 1,
    int pageSize = 20,
    bool forceRefresh = false,
  }) async {
    try {
      final response = await _get(
        path,
        queryParameters: {
          'page': page,
          'page_size': pageSize,
          if (forceRefresh)
            'refresh_nonce': DateTime.now().millisecondsSinceEpoch,
        },
      );
      final envelope = _asMap(response.data);
      if (envelope['success'] == false) {
        throw ServerException(
          message: envelope['error'] ?? 'Failed to load event posts',
        );
      }
      final rawPayload = envelope['data'];
      final payload = rawPayload is Map ? _asMap(rawPayload) : null;
      final rows = _asListMap(
        payload?['data'] ?? payload?['items'] ?? rawPayload,
      );
      return PaginatedList<Map<String, dynamic>>(
        data: rows,
        total: _asInt(
          payload?['total'] ?? envelope['total'],
          fallback: rows.length,
        ),
        page: _asInt(payload?['page'] ?? envelope['page'], fallback: page),
        pageSize: _asInt(
          payload?['page_size'] ?? envelope['page_size'],
          fallback: pageSize,
        ),
        isStale: response.extra['schooldeskOfflineCache'] == true,
        cacheStoredAt: DateTime.tryParse(
          response.headers.value('x-schooldesk-cache-stored-at') ?? '',
        ),
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Fetches approved SCHOOL_LANDING posts for the public pre-login carousel.
  /// No auth token required — the backend serves this without authentication.
  Future<List<Map<String, dynamic>>> getLandingEventPosts({
    required String schoolId,
  }) async {
    try {
      final response = await _get(
        '/event-posts/landing',
        queryParameters: {'school_id': schoolId},
      );
      final data = response.data;
      final rows = data is List
          ? data
          : (data is Map ? data['data'] as List? ?? const [] : const []);
      return rows
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
    } on Object catch (_) {
      return const [];
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
    List<EventPostMediaItem> media = const [],
    required List<String> destinations,
    required bool isSubmit,
    String? sectionId,
  }) async {
    try {
      final response = await _dio.post(
        '/event-posts',
        data: {
          'title': title,
          'description': description,
          'event_date': eventDate,
          if (media.isNotEmpty)
            'media': media.map((item) => item.toJson()).toList()
          else
            'media_urls': mediaUrls,
          'destinations': destinations,
          'is_submit': isSubmit,
          if (sectionId != null && sectionId.trim().isNotEmpty)
            'section_id': sectionId.trim(),
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

  Future<Map<String, dynamic>> updateEventPost({
    required String id,
    required String title,
    required String description,
    required String eventDate,
    required List<String> mediaUrls,
    List<EventPostMediaItem> media = const [],
    required List<String> destinations,
    required bool isSubmit,
    String? sectionId,
  }) async {
    try {
      final response = await _dio.put(
        '/event-posts/${id.trim()}',
        data: {
          'title': title,
          'description': description,
          'event_date': eventDate,
          if (media.isNotEmpty)
            'media': media.map((item) => item.toJson()).toList()
          else
            'media_urls': mediaUrls,
          'destinations': destinations,
          'is_submit': isSubmit,
          if (sectionId != null && sectionId.trim().isNotEmpty)
            'section_id': sectionId.trim(),
        },
      );
      final data = _asMap(response.data);
      if (data['success'] == false) {
        throw ServerException(
          message: data['error'] ?? 'Failed to update event post',
        );
      }
      final updated = _asMap(data['data']);
      return updated.isNotEmpty ? updated : data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> submitEventPost(String id) async {
    final post = await getEventPost(id);
    final media = EventPostMediaItem.parseList(post['media_urls']);
    await updateEventPost(
      id: id,
      title: (post['title'] ?? '').toString(),
      description: (post['description'] ?? '').toString(),
      eventDate: (post['event_date'] ?? DateTime.now().toIso8601String())
          .toString(),
      mediaUrls: media.map((item) => item.url).toList(),
      media: media,
      destinations: (post['destinations'] ?? '')
          .toString()
          .split(',')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList(),
      isSubmit: true,
      sectionId: post['section_id']?.toString(),
    );
  }

  Future<void> deleteEventPost(String id) async {
    try {
      final response = await _dio.delete('/event-posts/${id.trim()}');
      final data = _asMap(response.data);
      if (data['success'] == false) {
        throw ServerException(
          message: data['error'] ?? 'Failed to delete event post',
        );
      }
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<Map<String, dynamic>>> getTeacherLessonPlanners() async {
    try {
      final response = await _get('/lesson-planners/teacher');
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
      final response = await _get('/lesson-planners/principal');
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
      final response = await _get('/lesson-planners/parent');
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
    List<Map<String, dynamic>> attachments = const [],
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
          'attachments': attachments,
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
