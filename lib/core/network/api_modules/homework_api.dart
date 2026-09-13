part of '../backend_api_client.dart';

extension BackendHomeworkApi on BackendApiClient {
  // ─── Homework ─────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getHomework({
    String? studentId,
    String? sectionId,
    String? teacherId,
    String? status,
    int page = 1,
    int pageSize = 20,
  }) async {
    return (await getHomeworkPage(
      studentId: studentId,
      sectionId: sectionId,
      teacherId: teacherId,
      status: status,
      page: page,
      pageSize: pageSize,
    )).data;
  }

  Future<PaginatedList<Map<String, dynamic>>> getHomeworkPage({
    String? studentId,
    String? sectionId,
    String? teacherId,
    String? status,
    int page = 1,
    int pageSize = 20,
  }) async {
    final queryParams = <String, dynamic>{'page': page, 'page_size': pageSize};
    if (studentId != null && studentId.trim().isNotEmpty) {
      queryParams['student_id'] = studentId.trim();
    }
    if (sectionId != null && sectionId.trim().isNotEmpty) {
      queryParams['section_id'] = sectionId.trim();
    }
    if (teacherId != null && teacherId.trim().isNotEmpty) {
      queryParams['staff_id'] = teacherId.trim();
    }
    if (status != null && status.trim().isNotEmpty) {
      queryParams['status'] = status.trim();
    }
    try {
      final response = await _get('/homework', queryParameters: queryParams);
      final envelope = _asMap(response.data);
      if (envelope['success'] == true) {
        final rawPayload = envelope['data'];
        final payload = rawPayload is Map ? _asMap(rawPayload) : null;
        final merged = await _mergeLocalHomeworkDrafts(
          _asListMap(payload?['data'] ?? payload?['items'] ?? rawPayload),
          sectionId: sectionId,
          studentId: studentId,
          status: status,
        );
        return PaginatedList<Map<String, dynamic>>(
          data: merged,
          total: _asInt(
            payload?['total'] ?? envelope['total'],
            fallback: merged.length,
          ),
          page: _asInt(payload?['page'] ?? envelope['page'], fallback: page),
          pageSize: _asInt(
            payload?['page_size'] ?? envelope['page_size'],
            fallback: pageSize,
          ),
        );
      }
      throw ServerException(
        message: envelope['error'] ?? 'Failed to load homework',
      );
    } on DioException catch (e) {
      final local = await _readLocalHomeworkDrafts(
        sectionId: sectionId,
        studentId: studentId,
        status: status,
      );
      if (local.isNotEmpty) {
        return PaginatedList<Map<String, dynamic>>(
          data: local,
          total: local.length,
          page: page,
          pageSize: pageSize,
        );
      }
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getTodayHomeworkReminderStatus({
    String sectionId = '',
  }) async {
    try {
      final response = await _get(
        '/homework/reminders/today',
        queryParameters: {
          if (sectionId.trim().isNotEmpty) 'section_id': sectionId.trim(),
        },
      );
      final data = _asMap(response.data);
      if (data['success'] == true) return _asMap(data['data']);
      throw ServerException(
        message: data['error'] ?? 'Failed to load homework reminder status',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> skipTodayHomeworkReminder({
    String sectionId = '',
    String reason = '',
  }) async {
    try {
      final response = await _dio.post(
        '/homework/reminders/today/skip',
        data: {
          if (sectionId.trim().isNotEmpty) 'section_id': sectionId.trim(),
          if (reason.trim().isNotEmpty) 'reason': reason.trim(),
        },
      );
      final data = _asMap(response.data);
      if (data['success'] == true) return _asMap(data['data']);
      throw ServerException(
        message: data['error'] ?? 'Failed to skip homework reminder',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> createHomework({
    required String title,
    required String subject,
    required String className,
    required String sectionId,
    required String teacherId,
    required String description,
    required String dueDate,
    String studentId = '',
    String status = 'pending',
    String attachmentUrl = '',
  }) async {
    // A queued upload is a durable dependency. Persist the assignment as a
    // draft until that upload resolves; publishing a pending assignment still
    // requires an online request and an authoritative server state.
    final effectiveStatus =
        status.trim().toLowerCase() == 'draft' ||
            _homeworkNeedsOfflineDraft(attachmentUrl)
        ? 'draft'
        : status;
    final localId = effectiveStatus.trim().toLowerCase() == 'draft'
        ? 'local-homework-${DateTime.now().microsecondsSinceEpoch}'
        : null;
    if (localId != null) {
      await _saveLocalHomeworkDraft(
        localId: localId,
        title: title,
        subject: subject,
        className: className,
        sectionId: sectionId,
        teacherId: teacherId,
        description: description,
        dueDate: dueDate,
        studentId: studentId,
        attachmentUrl: attachmentUrl,
        status: effectiveStatus,
        syncStatus: 'pending',
      );
    }
    try {
      // Keep draft writes on the primary Dio pipeline so the offline
      // interceptor sees a JSON map and can persist the mutation in Drift.
      // Retrofit serializes the DTO internally, after interceptors have
      // already classified the request, which bypasses the draft allow-list.
      final response = await _dio.post(
        '/homework',
        data: _homeworkPayload(
          title: title,
          subject: subject,
          className: className,
          sectionId: sectionId,
          teacherId: teacherId,
          description: description,
          dueDate: dueDate,
          studentId: studentId,
          status: effectiveStatus,
          attachmentUrl: attachmentUrl,
        ),
        options: Options(
          extra: {
            if (localId != null) 'offlineLocalId': localId,
            if (localId != null) 'offlineResourceType': 'homework',
          },
        ),
      );
      final data = _asMap(response.data);
      if (data['success'] == true) {
        final result = _asMap(data['data']);
        if (data['queued'] == true) {
          result['queued'] = true;
          if (localId != null) result['id'] = localId;
        } else if (localId != null) {
          await _markLocalHomeworkDraftSynced(
            localId,
            '${result['id'] ?? result['homework_id'] ?? ''}'.trim(),
          );
        }
        return result;
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to create homework',
      );
    } on DioException catch (e) {
      if (localId != null) {
        await _markLocalHomeworkDraftFailed(localId);
      }
      throw _handleError(e);
    } on Object {
      if (localId != null) {
        await _markLocalHomeworkDraftFailed(localId);
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateHomework(
    String id, {
    required String title,
    required String subject,
    required String className,
    required String sectionId,
    required String teacherId,
    required String description,
    required String dueDate,
    String studentId = '',
    String status = 'pending',
    String attachmentUrl = '',
  }) async {
    final effectiveStatus =
        status.trim().toLowerCase() == 'draft' ||
            _homeworkNeedsOfflineDraft(attachmentUrl)
        ? 'draft'
        : status;
    final localId = effectiveStatus.trim().toLowerCase() == 'draft'
        ? 'local-homework-server-$id'
        : null;
    if (localId != null) {
      await _saveLocalHomeworkDraft(
        localId: localId,
        serverId: id,
        title: title,
        subject: subject,
        className: className,
        sectionId: sectionId,
        teacherId: teacherId,
        description: description,
        dueDate: dueDate,
        studentId: studentId,
        attachmentUrl: attachmentUrl,
        status: effectiveStatus,
        syncStatus: 'pending',
      );
    }
    try {
      final response = await _dio.put(
        '/homework/$id',
        data: _homeworkPayload(
          id: id,
          title: title,
          subject: subject,
          className: className,
          sectionId: sectionId,
          teacherId: teacherId,
          description: description,
          dueDate: dueDate,
          studentId: studentId,
          status: effectiveStatus,
          attachmentUrl: attachmentUrl,
        ),
        options: Options(
          extra: {
            if (localId != null) 'offlineLocalId': localId,
            if (localId != null) 'offlineResourceType': 'homework',
          },
        ),
      );
      final data = _asMap(response.data);
      if (data['success'] == true) {
        final result = _asMap(data['data']);
        if (data['queued'] == true) {
          result['queued'] = true;
        } else if (localId != null) {
          await _markLocalHomeworkDraftSynced(localId, id);
        }
        return result;
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to update homework',
      );
    } on DioException catch (e) {
      if (localId != null) {
        await _markLocalHomeworkDraftFailed(localId);
      }
      throw _handleError(e);
    } on Object {
      if (localId != null) {
        await _markLocalHomeworkDraftFailed(localId);
      }
      rethrow;
    }
  }

  Future<void> deleteHomework(String id) async {
    try {
      final response = await SchoolDeskApi.instance.client.deleteHomework(id);
      if (response.success == true) return;
      throw ServerException(
        message: response.error ?? 'Failed to delete homework',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getHomeworkSubmissions(
    String homeworkId, {
    String? studentId,
  }) async {
    final queryParams = <String, dynamic>{};
    if (studentId != null && studentId.trim().isNotEmpty) {
      queryParams['student_id'] = studentId.trim();
    }
    try {
      final response = await SchoolDeskApi.instance.client.homeworkSubmissions(
        homeworkId,
        queryParams.isEmpty ? null : queryParams,
      );
      if (response.success == true) return _asMap(response.data);
      throw ServerException(
        message: response.error ?? 'Failed to load homework submissions',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> submitHomework(
    String homeworkId, {
    required String studentId,
    required String answerText,
    String attachmentUrl = '',
    List<String> attachmentUrls = const [],
  }) async {
    try {
      final response = await SchoolDeskApi.instance.client
          .submitHomework(homeworkId, {
            'student_id': studentId,
            'answer_text': answerText,
            'attachment_url': attachmentUrl,
            'attachment_urls': attachmentUrls
                .map((url) => url.trim())
                .where((url) => url.isNotEmpty)
                .toList(),
          });
      if (response.success == true) return _asMap(response.data);
      throw ServerException(
        message: response.error ?? 'Failed to submit homework',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> reviewHomeworkSubmission(
    String homeworkId,
    String submissionId, {
    required String status,
    String grade = '',
    String remarks = '',
  }) async {
    try {
      final response = await SchoolDeskApi.instance.client
          .reviewHomeworkSubmission(homeworkId, submissionId, {
            'status': status,
            'grade': grade,
            'remarks': remarks,
          });
      if (response.success == true) return _asMap(response.data);
      throw ServerException(
        message: response.error ?? 'Failed to review homework',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Map<String, dynamic> _homeworkPayload({
    String? id,
    required String title,
    required String subject,
    required String className,
    required String sectionId,
    required String teacherId,
    required String description,
    required String dueDate,
    required String studentId,
    required String status,
    required String attachmentUrl,
  }) {
    return HomeworkDto(
      id: id,
      title: title,
      subjectId: subject,
      classId: className,
      sectionId: sectionId,
      staffId: teacherId,
      studentId: studentId,
      description: description,
      submissionDate: dueDate,
      attachmentUrl: attachmentUrl,
      status: status,
    ).toJson();
  }
}
