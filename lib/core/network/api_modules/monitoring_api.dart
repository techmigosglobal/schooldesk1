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
        },
      );
      final data = _asMap(response.data);
      if (data['success'] == true) return data;
      throw ServerException(
        message: data['message'] ?? data['error'] ?? 'Failed to load error events',
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

  Future<void> wipeDatabase() async {
    try {
      final response = await _dio.post('/monitoring/database/wipe');
      final data = _asMap(response.data);
      if (data['success'] != true) {
        throw ServerException(
          message: data['message'] ?? 'Failed to wipe database storage',
        );
      }
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }
}
