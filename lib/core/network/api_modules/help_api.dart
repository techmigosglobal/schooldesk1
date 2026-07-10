part of '../backend_api_client.dart';

extension HelpApi on BackendApiClient {
  Future<List<Map<String, dynamic>>> getHelpContent(String role) async {
    try {
      final response = await _dio.get('/help', queryParameters: {'role': role});
      final data = _asMap(response.data);
      if (data['success'] == true) {
        final list = data['data'] as List?;
        return list?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ??
            [];
      }
      throw ServerException(
        message:
            data['message'] ?? data['error'] ?? 'Failed to load help content',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> createHelpContent(
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await _dio.post('/help', data: body);
      final data = _asMap(response.data);
      if (data['success'] == true) {
        return Map<String, dynamic>.from(data['data'] as Map);
      }
      throw ServerException(
        message:
            data['message'] ?? data['error'] ?? 'Failed to create help content',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> updateHelpContent(
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await _dio.put('/help', data: body);
      final data = _asMap(response.data);
      if (data['success'] == true) {
        return Map<String, dynamic>.from(data['data'] as Map);
      }
      throw ServerException(
        message:
            data['message'] ?? data['error'] ?? 'Failed to update help content',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> deleteHelpContent(String id) async {
    try {
      final response = await _dio.delete('/help', queryParameters: {'id': id});
      final data = _asMap(response.data);
      if (data['success'] == true) return;
      throw ServerException(
        message:
            data['message'] ?? data['error'] ?? 'Failed to delete help content',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }
}
