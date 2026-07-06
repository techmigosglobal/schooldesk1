part of '../backend_api_client.dart';

extension BackendCommunicationsApi on BackendApiClient {
  // ─── Unified Chat ─────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getUnifiedChatContacts({
    required String role,
    String studentId = '',
  }) {
    final params = <String, dynamic>{
      'role': role.trim().toLowerCase(),
      if (studentId.trim().isNotEmpty) 'student_id': studentId.trim(),
    };
    return getRawList('/chat/contacts', queryParameters: params);
  }

  Future<List<Map<String, dynamic>>> getUnifiedChatConversations({
    String? type,
    String? teacherId,
    String? parentId,
    String? studentId,
    bool monitor = false,
  }) {
    final params = <String, dynamic>{};
    if (type != null && type.trim().isNotEmpty) params['type'] = type.trim();
    if (teacherId != null && teacherId.trim().isNotEmpty) {
      params['teacher_id'] = teacherId.trim();
    }
    if (parentId != null && parentId.trim().isNotEmpty) {
      params['parent_id'] = parentId.trim();
    }
    if (studentId != null && studentId.trim().isNotEmpty) {
      params['student_id'] = studentId.trim();
    }
    if (monitor) params['monitor'] = 'true';
    return getRawList(
      monitor ? '/chat/monitor' : '/chat/conversations',
      queryParameters: params.isEmpty ? null : params,
    );
  }

  Future<Map<String, dynamic>> createUnifiedChatConversation({
    required String type,
    String teacherId = '',
    String parentId = '',
    String studentId = '',
    String title = '',
  }) {
    return createRaw('/chat/conversations', {
      'type': type.trim().isEmpty ? 'parent_teacher' : type.trim(),
      if (teacherId.trim().isNotEmpty) 'teacher_id': teacherId.trim(),
      if (parentId.trim().isNotEmpty) 'parent_id': parentId.trim(),
      if (studentId.trim().isNotEmpty) 'student_id': studentId.trim(),
      if (title.trim().isNotEmpty) 'title': title.trim(),
    });
  }

  Future<List<Map<String, dynamic>>> getUnifiedChatMessages({
    required String conversationId,
    int? pageSize,
    DateTime? sentAfter,
  }) {
    final params = <String, dynamic>{};
    if (pageSize != null) params['page_size'] = pageSize;
    if (sentAfter != null) {
      params['sent_after'] = sentAfter.toUtc().toIso8601String();
    }
    return getRawList(
      '/chat/conversations/${conversationId.trim()}/messages',
      queryParameters: params.isEmpty ? null : params,
    );
  }

  Future<Map<String, dynamic>> sendUnifiedChatMessage({
    required String conversationId,
    required String body,
    String messageType = 'text',
    String attachmentUrl = '',
  }) {
    return createRaw('/chat/conversations/${conversationId.trim()}/messages', {
      'body': body.trim(),
      'message_type': messageType.trim().isEmpty ? 'text' : messageType.trim(),
      if (attachmentUrl.trim().isNotEmpty)
        'attachment_url': attachmentUrl.trim(),
    });
  }

  Future<void> markUnifiedChatConversationRead(String conversationId) async {
    await createRaw('/chat/conversations/${conversationId.trim()}/read', {});
  }

  // ─── Announcements ──────────────────────────────────────────────────────────

  Future<List<AnnouncementModel>> getAnnouncements({String? schoolId}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (schoolId != null) queryParams['school_id'] = schoolId;

      final response = await _dio.get(
        '/announcements',
        queryParameters: queryParams,
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return (data['data'] as List)
            .map((e) => AnnouncementModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to get announcements',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> createAnnouncement({
    required String title,
    required String content,
    String targetAudience = 'all',
    bool isUrgent = false,
  }) async {
    try {
      final response = await _dio.post(
        '/announcements',
        data: {
          'title': title,
          'content': content,
          'target_audience': targetAudience,
          'is_urgent': isUrgent,
        },
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] != true) {
        throw ServerException(
          message: data['error'] ?? 'Failed to create announcement',
        );
      }
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<Map<String, dynamic>>> getNotifications() async {
    try {
      final response = await SchoolDeskApi.instance.client.notifications();
      if (response.success == true) {
        return _asListMap(response.data).map((notification) {
          final normalized = Map<String, dynamic>.from(notification);
          normalized['id'] ??= normalized['notification_id'];
          normalized['body'] ??= normalized['message'];
          normalized['type'] ??= normalized['notification_type'];
          normalized['user_id'] ??= normalized['target_user_id'];
          return normalized;
        }).toList();
      }
      throw ServerException(
        message: response.error ?? 'Failed to get notifications',
      );
    } on AuthException catch (_) {
      // Auth token may be expired or cleared by a concurrent request.
      // Return empty list instead of crashing — the user will see the
      // login screen shortly if the session is truly expired.
      return const [];
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<Map<String, dynamic>>> getCommunications({
    String? counterpartId,
    String? role,
  }) async {
    final queryParams = <String, dynamic>{};
    if (counterpartId != null && counterpartId.trim().isNotEmpty) {
      queryParams['counterpart_id'] = counterpartId.trim();
    }
    if (role != null && role.trim().isNotEmpty) {
      queryParams['receiver_role'] = role.trim().toLowerCase();
    }
    final rows = await getTablesMDRows(
      'communications',
      queryParameters: queryParams.isEmpty ? null : queryParams,
    );
    return rows.map(_normalizeCommunicationRow).toList();
  }

  Future<Map<String, dynamic>> sendCommunication({
    required String receiverId,
    required String messageContent,
    String receiverRole = '',
    String studentId = '',
    String priority = 'medium',
  }) async {
    final payload = <String, dynamic>{
      'receiver_id': receiverId.trim(),
      'message_content': messageContent.trim(),
      'message_type': 'direct',
      if (receiverRole.trim().isNotEmpty)
        'receiver_role': receiverRole.trim().toLowerCase(),
      if (studentId.trim().isNotEmpty) 'student_id': studentId.trim(),
      if (priority.trim().isNotEmpty) 'priority': priority.trim(),
    };
    final row = await createTablesMDRow('communications', payload);
    return _normalizeCommunicationRow(row);
  }

  Future<Map<String, dynamic>> markCommunicationRead(
    String communicationId,
  ) async {
    final row = await updateTablesMDRow('communications', communicationId, {
      'is_read': true,
    });
    return _normalizeCommunicationRow(row);
  }

  Map<String, dynamic> _normalizeCommunicationRow(Map<String, dynamic> row) {
    final normalized = Map<String, dynamic>.from(row);
    normalized['id'] ??= normalized['message_id'];
    normalized['message_id'] ??= normalized['id'];
    normalized['body'] ??= normalized['message_content'];
    normalized['message'] ??= normalized['message_content'];
    normalized['sent_at'] ??= normalized['created_at'];
    return normalized;
  }

  Future<List<Map<String, dynamic>>> getMessageConversations({
    int? pageSize,
    Map<String, dynamic>? queryParameters,
  }) {
    final params = <String, dynamic>{...?queryParameters};
    if (pageSize != null) params['page_size'] = pageSize;
    return getRawList(
      '/message-conversations',
      queryParameters: params.isEmpty ? null : params,
    );
  }

  Future<List<Map<String, dynamic>>> getChatMessages({
    String? conversationId,
    int? pageSize,
    DateTime? sentAfter,
    Map<String, dynamic>? queryParameters,
  }) {
    final params = <String, dynamic>{...?queryParameters};
    if (conversationId != null && conversationId.trim().isNotEmpty) {
      params['conversation_id'] = conversationId.trim();
    }
    if (pageSize != null) params['page_size'] = pageSize;
    if (sentAfter != null) {
      params['sent_after'] = sentAfter.toUtc().toIso8601String();
    }
    return getRawList(
      '/messages',
      queryParameters: params.isEmpty ? null : params,
    );
  }

  Future<Map<String, dynamic>> sendChatMessage({
    required String conversationId,
    required String senderId,
    required String senderRole,
    required String body,
    String senderName = '',
    DateTime? sentAt,
  }) {
    final text = body.trim();
    return createRaw('/messages', {
      'conversation_id': conversationId,
      'sender_id': senderId,
      'sender_role': senderRole,
      if (senderName.trim().isNotEmpty) 'sender_name': senderName.trim(),
      'message': text,
      'body': text,
      'is_read': false,
      'sent_at': (sentAt ?? DateTime.now()).toUtc().toIso8601String(),
    });
  }

  Future<Map<String, dynamic>> markChatMessageRead(String messageId) {
    return updateRaw('/messages/$messageId', {
      'is_read': true,
      'read_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> markNotificationRead(String notificationId) async {
    try {
      final response = await SchoolDeskApi.instance.client.markNotificationRead(
        notificationId,
      );
      if (response.success != true) {
        throw ServerException(
          message: response.error ?? 'Failed to mark notification as read',
        );
      }
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> registerNotificationDeviceToken({
    required String token,
    required String platform,
    String deviceId = '',
    String appVersion = '',
  }) async {
    try {
      final response = await _dio.post(
        '/notifications/register-token',
        data: {
          'fcm_token': token,
          'device_type': platform,
          if (deviceId.trim().isNotEmpty) 'device_id': deviceId.trim(),
          if (appVersion.trim().isNotEmpty) 'app_version': appVersion.trim(),
        },
      );
      final data = _asMap(response.data);
      if (data['success'] == true) {
        return _asMap(data['data']);
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to register notification device',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> revokeNotificationDeviceToken({required String token}) async {
    try {
      final response = await _dio.post(
        '/notifications/revoke-token',
        data: {'fcm_token': token},
      );
      final data = _asMap(response.data);
      if (data['success'] != true) {
        throw ServerException(
          message: data['error'] ?? 'Failed to revoke notification device',
        );
      }
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> runPushDiagnostics() async {
    try {
      final response = await _dio.post('/notifications/push-diagnostics');
      final data = _asMap(response.data);
      if (data['success'] == true) {
        return _asMap(data['data']);
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to run push diagnostics',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ─── Report Exports ───────────────────────────────────────────────────────

  Future<Map<String, dynamic>> createReportExport(
    String path, {
    required String reportTitle,
    required String format,
    String reportType = '',
    String scope = '',
    Map<String, dynamic> parameters = const {},
  }) {
    final payload = <String, dynamic>{
      'report_title': reportTitle,
      'report': reportTitle,
      'format': format.toLowerCase(),
      if (reportType.trim().isNotEmpty) 'report_type': reportType.trim(),
      if (scope.trim().isNotEmpty) 'scope': scope.trim(),
      if (parameters.isNotEmpty) 'parameters': parameters,
      ...parameters,
    };
    return createRaw(path, payload);
  }

  Future<Uint8List> downloadReportExport(String downloadUrl) async {
    final value = downloadUrl.trim();
    if (value.isEmpty) {
      throw const ServerException(message: 'Export download URL is missing');
    }
    final uri = Uri.parse(value);
    final resolved = uri.hasScheme
        ? uri
        : Uri.parse(
            '${EnvConfig.apiOrigin}${value.startsWith('/') ? '' : '/'}$value',
          );
    try {
      final response = await _dio.getUri<List<int>>(
        resolved,
        options: Options(responseType: ResponseType.bytes),
      );
      return Uint8List.fromList(response.data ?? const <int>[]);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<Map<String, dynamic>>> getReportExports(
    String path, {
    String? status,
  }) {
    final queryParams = <String, dynamic>{};
    if (status != null && status.trim().isNotEmpty) {
      queryParams['status'] = status.trim();
    }
    return getRawList(
      path,
      queryParameters: queryParams.isEmpty ? null : queryParams,
    );
  }

  Future<Map<String, dynamic>> bookParentTeacherMeeting(
    String id, {
    String notes = 'Booked by parent',
  }) async {
    try {
      final response = await _dio.put(
        '/parent-teacher-meetings/$id/book',
        data: {'notes': notes},
      );
      final data = _asMap(response.data);
      if (data['success'] == true) {
        return Map<String, dynamic>.from(data['data'] as Map? ?? {});
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to book PTM slot',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<Map<String, dynamic>>> getMyTeacherPtmSlots() async {
    try {
      final response = await _dio.get('/teacher/ptm-slots');
      final data = _asMap(response.data);
      if (data['success'] == true) return _asListMap(data['data']);
      throw ServerException(
        message: data['error'] ?? 'Failed to load teacher PTM slots',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ─── Birthday Alerts ──────────────────────────────────────────────────────

  /// Triggers the birthday alert job for today. Only principals/admins can
  /// call this. The backend creates notification_logs entries for every
  /// student whose date_of_birth matches today.
  Future<Map<String, dynamic>> triggerBirthdayAlerts() async {
    // Use a dedicated Dio instance without the auth-clearing error
    // interceptor so a 403/401 from this fire-and-forget endpoint never
    // wipes the shared TokenStorageService.
    final token = _authToken;
    if (token == null || token.isEmpty) {
      return <String, dynamic>{};
    }
    try {
      final safeDio = Dio(
        BaseOptions(
          baseUrl: _dio.options.baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ),
      );
      final response = await safeDio.post(
        '/jobs/birthday-alerts/run',
        data: <String, dynamic>{},
      );
      final data = _asMap(response.data);
      return Map<String, dynamic>.from(data['data'] as Map? ?? {});
    } catch (_) {
      // Fire-and-forget: never crash or clear shared auth state.
      return <String, dynamic>{};
    }
  }

  Future<Map<String, dynamic>> createMyTeacherPtmSlot({
    required String sectionId,
    required String slotDate,
    required String slotTime,
    int durationMin = 15,
    String eventId = '',
    String studentId = '',
    String guardianId = '',
  }) async {
    try {
      final response = await _dio.post(
        '/teacher/ptm-slots',
        data: {
          if (eventId.trim().isNotEmpty) 'event_id': eventId.trim(),
          'section_id': sectionId.trim(),
          'slot_date': slotDate.trim(),
          'slot_time': slotTime.trim(),
          'duration_min': durationMin,
          if (studentId.trim().isNotEmpty) 'student_id': studentId.trim(),
          if (guardianId.trim().isNotEmpty) 'guardian_id': guardianId.trim(),
        },
      );
      final data = _asMap(response.data);
      if (data['success'] == true) return _asMap(data['data']);
      throw ServerException(
        message: data['error'] ?? 'Failed to create teacher PTM slot',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }
}
