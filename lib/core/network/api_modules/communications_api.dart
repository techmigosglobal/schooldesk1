part of '../backend_api_client.dart';

extension BackendCommunicationsApi on BackendApiClient {
  // ─── Unified Chat ─────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getUnifiedChatContacts({
    required String role,
    String studentId = '',
  }) async {
    final params = <String, dynamic>{
      'role': role.trim().toLowerCase(),
      if (studentId.trim().isNotEmpty) 'student_id': studentId.trim(),
    };
    final rows = await getRawList('/chat/contacts', queryParameters: params);
    return rows.map(normalizeChatContextMap).toList();
  }

  Future<List<Map<String, dynamic>>> getUnifiedChatConversations({
    String? type,
    String? teacherId,
    String? parentId,
    String? studentId,
    bool monitor = false,
    String? search,
    int page = 1,
    int pageSize = 20,
  }) async {
    return (await getUnifiedChatConversationsPage(
      type: type,
      teacherId: teacherId,
      parentId: parentId,
      studentId: studentId,
      monitor: monitor,
      search: search,
      page: page,
      pageSize: pageSize,
    )).data;
  }

  Future<PaginatedList<Map<String, dynamic>>> getUnifiedChatConversationsPage({
    String? type,
    String? teacherId,
    String? parentId,
    String? studentId,
    bool monitor = false,
    String? search,
    int page = 1,
    int pageSize = 20,
  }) async {
    final params = <String, dynamic>{};
    params['page'] = page;
    params['page_size'] = pageSize;
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
    if (search != null && search.trim().isNotEmpty) {
      params['search'] = search.trim();
    }
    if (monitor) params['monitor'] = 'true';
    try {
      final response = await _get(
        monitor ? '/chat/monitor' : '/chat/conversations',
        queryParameters: params,
      );
      final envelope = _asMap(response.data);
      if (envelope['success'] != true) {
        throw ServerException(
          message: envelope['error'] ?? 'Failed to load conversations',
        );
      }
      final rows = _asListMap(
        envelope['data'],
      ).map(normalizeChatContextMap).toList();
      return PaginatedList<Map<String, dynamic>>(
        data: rows,
        total: _asInt(envelope['total'], fallback: rows.length),
        page: _asInt(envelope['page'], fallback: page),
        pageSize: _asInt(envelope['page_size'], fallback: pageSize),
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> createUnifiedChatConversation({
    required String type,
    String teacherId = '',
    String parentId = '',
    String studentId = '',
    String leaderId = '',
    String title = '',
  }) {
    return createRaw('/chat/conversations', {
      'type': type.trim().isEmpty ? 'parent_teacher' : type.trim(),
      if (teacherId.trim().isNotEmpty) 'teacher_id': teacherId.trim(),
      if (parentId.trim().isNotEmpty) 'parent_id': parentId.trim(),
      if (studentId.trim().isNotEmpty) 'student_id': studentId.trim(),
      if (leaderId.trim().isNotEmpty) 'leader_id': leaderId.trim(),
      if (title.trim().isNotEmpty) 'title': title.trim(),
    });
  }

  Future<List<Map<String, dynamic>>> getUnifiedChatMessages({
    required String conversationId,
    int? pageSize,
    int page = 1,
    DateTime? sentAfter,
  }) {
    return getUnifiedChatMessagesPage(
      conversationId: conversationId,
      page: page,
      pageSize: pageSize ?? 20,
      sentAfter: sentAfter,
    ).then((result) => result.data);
  }

  Future<PaginatedList<Map<String, dynamic>>> getUnifiedChatMessagesPage({
    required String conversationId,
    int page = 1,
    int pageSize = 20,
    DateTime? sentAfter,
  }) async {
    final params = <String, dynamic>{};
    params['page'] = page;
    params['page_size'] = pageSize;
    if (sentAfter != null) {
      params['sent_after'] = sentAfter.toUtc().toIso8601String();
    }
    try {
      final response = await _get(
        '/chat/conversations/${conversationId.trim()}/messages',
        queryParameters: params,
      );
      final envelope = _asMap(response.data);
      if (envelope['success'] != true) {
        throw ServerException(
          message: envelope['error'] ?? 'Failed to load messages',
        );
      }
      final rows = _asListMap(envelope['data']);
      return PaginatedList<Map<String, dynamic>>(
        data: rows,
        total: _asInt(envelope['total'], fallback: rows.length),
        page: _asInt(envelope['page'], fallback: page),
        pageSize: _asInt(envelope['page_size'], fallback: pageSize),
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
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
  Future<List<AnnouncementModel>> getAnnouncements({
    String? schoolId,
    bool forceRefresh = false,
    String? search,
    int page = 1,
    int pageSize = 20,
  }) async {
    return (await getAnnouncementsPage(
      schoolId: schoolId,
      forceRefresh: forceRefresh,
      search: search,
      page: page,
      pageSize: pageSize,
    )).data;
  }

  Future<PaginatedList<AnnouncementModel>> getAnnouncementsPage({
    String? schoolId,
    bool forceRefresh = false,
    String? search,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'page_size': pageSize,
      };
      if (schoolId != null) queryParams['school_id'] = schoolId;
      if (search != null && search.trim().isNotEmpty) {
        queryParams['search'] = search.trim();
      }
      if (forceRefresh) {
        queryParams['refresh_nonce'] = DateTime.now().millisecondsSinceEpoch;
      }
      final response = await _get(
        '/announcements',
        queryParameters: queryParams,
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        final payload = data['data'];
        final rows = payload is Map ? payload['data'] : payload;
        final announcements = (rows as List? ?? const [])
            .map((e) => AnnouncementModel.fromJson(e as Map<String, dynamic>))
            .toList();
        final payloadMap = payload is Map
            ? _asMap(payload)
            : const <String, dynamic>{};
        return PaginatedList<AnnouncementModel>(
          data: announcements,
          total: _asInt(
            payloadMap['total'] ?? data['total'],
            fallback: announcements.length,
          ),
          page: _asInt(payloadMap['page'] ?? data['page'], fallback: page),
          pageSize: _asInt(
            payloadMap['page_size'] ?? data['page_size'],
            fallback: pageSize,
          ),
        );
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

  Future<NotificationPage> getNotificationsPage({
    int page = 1,
    int pageSize = 50,
  }) async {
    try {
      final response = await _get(
        '/notifications',
        queryParameters: {'page': page, 'page_size': pageSize},
      );
      final envelope = _asMap(response.data);
      if (envelope['success'] == true) {
        final rawData = envelope['data'];
        final data = rawData is Map
            ? _asMap(rawData)
            : const <String, dynamic>{};
        final rows = rawData is Map ? data['items'] : rawData;
        final items = _asListMap(rows).map((notification) {
          final normalized = Map<String, dynamic>.from(notification);
          normalized['id'] ??= normalized['notification_id'];
          normalized['body'] ??= normalized['message'];
          normalized['type'] ??= normalized['notification_type'];
          normalized['user_id'] ??= normalized['target_user_id'];
          return normalized;
        }).toList();
        return NotificationPage(
          items: items,
          page: page,
          pageSize: pageSize,
          hasMore: rawData is Map
              ? data['has_more'] == true
              : items.length == pageSize,
        );
      }
      throw ServerException(
        message: envelope['error'] ?? 'Failed to get notifications',
      );
    } on AuthException catch (_) {
      // Auth token may be expired or cleared by a concurrent request.
      // Return empty list instead of crashing — the user will see the
      // login screen shortly if the session is truly expired.
      return NotificationPage.empty(page: page, pageSize: pageSize);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<Map<String, dynamic>>> getNotifications() async {
    return (await getNotificationsPage()).items;
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

  Future<void> markAllNotificationsRead({String role = ''}) async {
    try {
      final response = await _dio.post(
        '/notifications/mark-read',
        data: {
          if (role.trim().isNotEmpty) 'target_role': role.trim().toLowerCase(),
        },
      );
      final data = _asMap(response.data);
      if (data['success'] != true) {
        throw ServerException(
          message: data['error'] ?? 'Failed to mark notifications as read',
        );
      }
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    try {
      final response = await _dio.delete('/notifications/$notificationId');
      final data = _asMap(response.data);
      if (data['success'] != true) {
        throw ServerException(
          message: data['error'] ?? 'Failed to delete notification',
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

  // ─── Birthday Alerts ──────────────────────────────────────────────────────

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
    } on Object catch (_) {
      // Fire-and-forget: never crash or clear shared auth state.
      return <String, dynamic>{};
    }
  }
}

class NotificationPage {
  const NotificationPage({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.hasMore,
  });
  const NotificationPage.empty({required this.page, required this.pageSize})
    : items = const [],
      hasMore = false;
  final List<Map<String, dynamic>> items;
  final int page;
  final int pageSize;
  final bool hasMore;
}
