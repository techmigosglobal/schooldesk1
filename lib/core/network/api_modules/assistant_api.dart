part of '../backend_api_client.dart';

extension BackendAssistantApi on BackendApiClient {
  Future<Map<String, dynamic>> getAssistantCatalog() async {
    try {
      final response = await _dio.get('/assistant/workflows');
      final data = _asMap(response.data);
      if (data['success'] == true) {
        return _asMap(data['data']);
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to load assistant workflows',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> detectAssistantIntent(String command) async {
    try {
      final response = await _dio.post(
        '/assistant/intent',
        data: {'command': command},
      );
      final data = _asMap(response.data);
      if (data['success'] == true) {
        return _asMap(data['data']);
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to parse assistant command',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<Map<String, dynamic>>> getAssistantSessions({
    String? status,
    bool all = false,
  }) async {
    try {
      final query = <String, dynamic>{};
      if (status != null && status.trim().isNotEmpty) {
        query['status'] = status.trim();
      }
      if (all) query['all'] = true;
      final response = await _dio.get(
        '/assistant/sessions',
        queryParameters: query.isEmpty ? null : query,
      );
      final data = _asMap(response.data);
      if (data['success'] == true) {
        return _asListMap(data['data']);
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to load assistant sessions',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> createAssistantSession({
    required String workflowType,
    String title = '',
    String command = '',
    Map<String, dynamic> initialData = const {},
  }) async {
    try {
      final response = await _dio.post(
        '/assistant/sessions',
        data: {
          'workflow_type': workflowType,
          'title': title,
          'command': command,
          'initial_data': initialData,
        },
      );
      final data = _asMap(response.data);
      if (data['success'] == true) {
        return _asMap(data['data']);
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to create assistant session',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> saveAssistantStep({
    required String sessionId,
    required String stepId,
    Map<String, dynamic> draftData = const {},
    Map<String, dynamic> stepData = const {},
    bool completed = false,
    String currentStepId = '',
  }) async {
    try {
      final response = await _dio.put(
        '/assistant/sessions/$sessionId/steps/$stepId',
        data: {
          'draft_data': draftData,
          'step_data': stepData,
          'completed': completed,
          'current_step_id': currentStepId,
        },
      );
      final data = _asMap(response.data);
      if (data['success'] == true) {
        return _asMap(data['data']);
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to save assistant step',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> validateAssistantSession(
    String sessionId,
  ) async {
    try {
      final response = await _dio.post(
        '/assistant/sessions/$sessionId/validate',
      );
      final data = _asMap(response.data);
      if (data['success'] == true) {
        return _asMap(data['data']);
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to validate assistant workflow',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> executeAssistantSession(String sessionId) async {
    try {
      final response = await _dio.post(
        '/assistant/sessions/$sessionId/execute',
        data: {'confirm': true},
      );
      final data = _asMap(response.data);
      if (data['success'] == true) {
        return _asMap(data['data']);
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to execute assistant workflow',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> cancelAssistantSession(String sessionId) async {
    try {
      final response = await _dio.delete('/assistant/sessions/$sessionId');
      final data = _asMap(response.data);
      if (data['success'] == true) {
        return _asMap(data['data']);
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to cancel assistant workflow',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getAssistantTemplate(String workflowType) async {
    try {
      final response = await _dio.get('/assistant/templates/$workflowType');
      final data = _asMap(response.data);
      if (data['success'] == true) {
        return _asMap(data['data']);
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to load assistant template',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> importAssistantPreview({
    required String sessionId,
    required String format,
    required String content,
  }) async {
    try {
      final response = await _dio.post(
        '/assistant/sessions/$sessionId/import-preview',
        data: {'format': format, 'content': content},
      );
      final data = _asMap(response.data);
      if (data['success'] == true) {
        return _asMap(data['data']);
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to import assistant data',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }
}
