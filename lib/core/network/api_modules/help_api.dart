part of '../backend_api_client.dart';

extension HelpApi on BackendApiClient {
  Future<Map<String, dynamic>> uploadHelpTutorialVideo(
    String filePath, {
    required String filename,
    required String roleName,
  }) async {
    try {
      final response = await _dio.post(
        '/help/videos',
        data: FormData.fromMap({
          'role_name': roleName,
          'file': await MultipartFile.fromFile(filePath, filename: filename),
        }),
      );
      final data = _asMap(response.data);
      if (data['success'] == true) return _asMap(data['data']);
      throw ServerException(
        message: data['message'] ?? data['error'] ?? 'Tutorial upload failed',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<String> getHelpTutorialPlaybackUrl(String helpContentId) async {
    try {
      final response = await _get('/help/$helpContentId/video');
      final data = _asMap(response.data);
      final payload = _asMap(data['data']);
      final url = '${payload['url'] ?? ''}'.trim();
      if (data['success'] == true && url.isNotEmpty) return url;
      throw ServerException(
        message: data['message'] ?? data['error'] ?? 'Tutorial is unavailable',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<Map<String, dynamic>>> getHelpContent(String role) async {
    try {
      final response = await _get('/help', queryParameters: {'role': role});
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
