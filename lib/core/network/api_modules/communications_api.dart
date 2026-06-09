part of '../backend_api_client.dart';

extension BackendCommunicationsApi on BackendApiClient {
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
        '/notifications/device-tokens',
        data: {
          'token': token,
          'platform': platform,
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
      final response = await _dio.delete(
        '/notifications/device-tokens',
        data: {'token': token},
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
}
