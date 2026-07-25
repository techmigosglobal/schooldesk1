part of '../backend_api_client.dart';

extension MonitoringApi on BackendApiClient {
  Future<void> submitErrorEvent(Map<String, dynamic> payload) async {
    await _dio.post('/monitoring/error-events', data: payload);
  }

  Future<Map<String, dynamic>> getErrorEvents({
    String? status,
    String? severity,
    String? source,
    String? requestId,
    DateTime? from,
    DateTime? to,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final response = await _dio.get(
        '/monitoring/error-events',
        queryParameters: {
          'page': page,
          'page_size': pageSize,
          if (status != null && status.isNotEmpty) 'status': status,
          if (severity != null && severity.isNotEmpty) 'severity': severity,
          if (source != null && source.isNotEmpty) 'source': source,
          if (requestId != null && requestId.isNotEmpty)
            'request_id': requestId,
          if (from != null) 'from': from.toUtc().toIso8601String(),
          if (to != null) 'to': to.toUtc().toIso8601String(),
        },
      );
      final data = _asMap(response.data);
      if (data['success'] == true) return data;
      throw ServerException(
        message:
            data['message'] ?? data['error'] ?? 'Failed to load error events',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getErrorEvent(String id) async {
    try {
      final response = await _dio.get('/monitoring/error-events/$id');
      final data = _asMap(response.data);
      if (data['success'] == true) return _asMap(data['data']);
      throw ServerException(
        message: data['message'] ?? 'Error event not found',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> resolveErrorEvent(
    String id, {
    String resolutionNote = '',
  }) async {
    try {
      final response = await _dio.patch(
        '/monitoring/error-events/$id/resolve',
        data: {'resolution_note': resolutionNote},
      );
      final data = _asMap(response.data);
      if (data['success'] == true) return _asMap(data['data']);
      throw ServerException(
        message: data['message'] ?? 'Failed to resolve error event',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getErrorRetentionMetrics() async {
    try {
      final response = await _dio.get('/monitoring/error-events/retention');
      final data = _asMap(response.data);
      if (data['success'] == true) return _asMap(data['data']);
      throw ServerException(
        message: data['message'] ?? 'Failed to load error retention metrics',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> updateErrorRetentionSettings({
    required int warningKeepDays,
    required int resolvedKeepDays,
    required int resolvedFatalKeepDays,
    required int maxRawEvents,
  }) async {
    try {
      final response = await _dio.patch(
        '/monitoring/error-events/retention',
        data: {
          'warning_keep_days': warningKeepDays,
          'resolved_keep_days': resolvedKeepDays,
          'resolved_fatal_keep_days': resolvedFatalKeepDays,
          'max_raw_events': maxRawEvents,
        },
      );
      final data = _asMap(response.data);
      if (data['success'] == true) return _asMap(data['data']);
      throw ServerException(
        message: data['message'] ?? 'Failed to update error retention settings',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> previewResolvedErrorCleanup({
    DateTime? before,
    String? severity,
  }) => _cleanupResolvedErrorEvents(
    preview: true,
    before: before,
    severity: severity,
  );

  Future<Map<String, dynamic>> clearResolvedErrorEvents({
    DateTime? before,
    String? severity,
  }) => _cleanupResolvedErrorEvents(
    preview: false,
    before: before,
    severity: severity,
    confirmation: 'CLEAR RESOLVED ERROR EVENTS',
  );

  Future<Map<String, dynamic>> _cleanupResolvedErrorEvents({
    required bool preview,
    DateTime? before,
    String? severity,
    String? confirmation,
  }) async {
    try {
      final response = await _dio.post(
        '/monitoring/error-events/cleanup',
        data: {
          'preview': preview,
          if (before != null) 'before': before.toUtc().toIso8601String(),
          if (severity != null && severity.isNotEmpty) 'severity': severity,
          if (confirmation != null) 'confirmation': confirmation,
        },
      );
      final data = _asMap(response.data);
      if (data['success'] == true) return _asMap(data['data']);
      throw ServerException(
        message: data['message'] ?? 'Failed to clean resolved error events',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> deleteResolvedErrorEvent(String id) async {
    try {
      final response = await _dio.delete(
        '/monitoring/error-events/$id',
        data: {'confirmation': 'DELETE RESOLVED ERROR EVENT'},
      );
      final data = _asMap(response.data);
      if (data['success'] != true) {
        throw ServerException(
          message: data['message'] ?? 'Failed to delete resolved error event',
        );
      }
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> backupDatabase() async {
    try {
      final response = await _dio.get('/monitoring/database/backup');
      final data = _asMap(response.data);
      if (data['success'] == true) return _asMap(data['data']);
      throw ServerException(
        message: data['message'] ?? 'Failed to backup database',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> restoreDatabase(Map<String, dynamic> dump) async {
    try {
      final response = await _dio.post(
        '/monitoring/database/restore',
        data: dump,
      );
      final data = _asMap(response.data);
      if (data['success'] != true) {
        throw ServerException(
          message: data['message'] ?? 'Failed to restore database',
        );
      }
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> wipeDatabase() async {
    try {
      final response = await _dio.post('/monitoring/database/wipe');
      final data = _asMap(response.data);
      if (data['success'] != true) {
        throw ServerException(
          message: data['message'] ?? 'Failed to wipe database storage',
        );
      }
      return _asMap(data['data']);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }
}
