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

  Future<List<Map<String, dynamic>>> getEvents({String? academicYearId}) async {
    try {
      final filters = <String, dynamic>{'page_size': 200};
      if (academicYearId != null && academicYearId.trim().isNotEmpty) {
        filters['academic_year_id'] = academicYearId.trim();
      }
      // The generated client remains the real-user transport contract. Demo
      // sessions use BackendApiClient's intercepted Dio because the generated
      // client owns a separate Dio instance.
      final events = DemoLocalApiService.instance.isActive
          ? _asListMap(
              (await _get('/events', queryParameters: filters)).data['data'],
            )
          : (await SchoolDeskApi.instance.client.events(filters)).data
                .whereType<Map>()
                .map((event) => Map<String, dynamic>.from(event))
                .toList();
      return events.map((event) {
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
      }).toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<String> uploadFile(
    String filePath, {
    required String filename,
    Uint8List? fileBytes,
    String? mimeType,
    String folder = 'uploads',
    String entityType = '',
    String entityId = '',
    bool private = false,
  }) async {
    try {
      var uploadFilename = filename;
      var uploadMimeType = mimeType;
      var uploadBytes = fileBytes;
      if (ImageUploadOptimizer.isImage(filename, mimeType)) {
        final optimized = uploadBytes != null
            ? ImageUploadOptimizer.fromBytes(
                uploadBytes,
                filename: filename,
                mimeType: mimeType,
                preset: ImageUploadPreset.content,
              )
            : await ImageUploadOptimizer.fromPath(
                filePath,
                filename: filename,
                mimeType: mimeType,
                preset: ImageUploadPreset.content,
              );
        uploadFilename = optimized.filename;
        uploadMimeType = optimized.mimeType;
        uploadBytes = optimized.bytes;
      }
      final contentType = _resolveMediaType(uploadMimeType, uploadFilename);
      final formData = FormData.fromMap({
        'folder': folder,
        'entity_type': entityType,
        'entity_id': entityId,
        'private': private,
        'file': await _multipartUpload(
          filePath: filePath,
          fileBytes: uploadBytes,
          filename: uploadFilename,
          contentType: contentType,
        ),
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
      final response = await _get('/event-posts/teacher');
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
      final response = await _get('/event-posts/pending');
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

  /// Principal-only management list. Includes drafts, pending, approved and
  /// published posts so a principal can correct or remove a post after it has
  /// appeared in a school surface.
  Future<List<Map<String, dynamic>>> getPrincipalEventPosts() async {
    try {
      final response = await _get('/event-posts');
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

  Future<Map<String, dynamic>> getEventPost(String id) async {
    final safeId = id.trim();
    if (safeId.isEmpty) {
      throw const ServerException(message: 'Event post id is required');
    }
    return getRawMap('/event-posts/$safeId');
  }

  Future<List<Map<String, dynamic>>> getGalleryEventPosts() async {
    try {
      final response = await _get('/event-posts/gallery');
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
      final response = await _get('/event-posts/home-feed');
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

// Resolves a Dio MediaType from an explicit MIME string or falls back to the
// file extension. This ensures MP4 and other video files are never uploaded
// with application/octet-stream, which breaks Supabase video playback.
DioMediaType? _resolveMediaType(String? mimeType, String filename) {
  final mime = mimeType?.trim() ?? '';
  if (mime.isNotEmpty) {
    final parts = mime.split('/');
    if (parts.length == 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return DioMediaType(parts[0], parts[1]);
    }
  }
  switch (filename.split('.').last.toLowerCase()) {
    case 'mp4':
      return DioMediaType('video', 'mp4');
    case 'mov':
      return DioMediaType('video', 'quicktime');
    case 'm4v':
      return DioMediaType('video', 'x-m4v');
    case 'webm':
      return DioMediaType('video', 'webm');
    case 'jpg':
    case 'jpeg':
      return DioMediaType('image', 'jpeg');
    case 'png':
      return DioMediaType('image', 'png');
    case 'webp':
      return DioMediaType('image', 'webp');
    case 'gif':
      return DioMediaType('image', 'gif');
    case 'heic':
      return DioMediaType('image', 'heic');
    case 'pdf':
      return DioMediaType('application', 'pdf');
    default:
      return null;
  }
}
