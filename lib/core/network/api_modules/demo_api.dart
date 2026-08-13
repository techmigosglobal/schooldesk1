part of '../backend_api_client.dart';

extension BackendDemoApi on BackendApiClient {
  Future<Map<String, dynamic>> loginDemo({
    required String username,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        '/demo/login',
        data: {'username': username.trim(), 'password': password},
      );
      final data = _asMap(response.data);
      if (data['success'] == true) return _asMap(data['data']);
      throw ServerException(message: data['error'] ?? 'Demo sign-in failed');
    } on DioException catch (error) {
      throw _handleError(error);
    }
  }

  Future<Map<String, dynamic>?> getDemoAccount() async {
    try {
      final response = await _get('/demo/admin');
      final data = _asMap(response.data);
      if (data['success'] == true && data['data'] is Map) {
        return _asMap(data['data']);
      }
      if (data['success'] == true) return null;
      throw ServerException(
        message: data['error'] ?? 'Unable to load demo account',
      );
    } on DioException catch (error) {
      throw _demoError(error);
    }
  }

  Future<Map<String, dynamic>> createDemoAccount({
    required String demoSchoolId,
    String username = '',
  }) async {
    try {
      final response = await _dio.post(
        '/demo/admin',
        data: {
          'demo_school_id': demoSchoolId,
          'username': username,
          'snapshot': {
            'school_name': 'SchoolDesk Demo Preschool',
            'today': 'A joyful fictional school day',
            'principal': {'pending_approvals': 3, 'students': 42},
            'teacher': {
              'class_name': 'Sunshine Nursery',
              'attendance_ready': true,
            },
            'parent': {
              'child_name': 'Aarav Demo',
              'next_event': 'Storytelling Friday',
            },
          },
        },
      );
      final data = _asMap(response.data);
      if (data['success'] == true) return _asMap(data['data']);
      throw ServerException(
        message: data['error'] ?? 'Unable to create demo account',
      );
    } on DioException catch (error) {
      throw _demoError(error);
    }
  }

  Future<Map<String, dynamic>> resetDemoAccount(String id) async =>
      _demoSecret('/demo/admin/$id/reset');

  Future<Map<String, dynamic>> revealDemoAccount(String id) async =>
      _demoSecret('/demo/admin/$id/reveal');

  Future<Map<String, dynamic>> setDemoAccountEnabled(
    String id,
    bool isEnabled,
  ) async {
    try {
      final response = await _dio.patch(
        '/demo/admin/$id',
        data: {'is_enabled': isEnabled},
      );
      final data = _asMap(response.data);
      if (data['success'] == true) return _asMap(data['data']);
      throw ServerException(
        message: data['error'] ?? 'Unable to update demo access',
      );
    } on DioException catch (error) {
      throw _demoError(error);
    }
  }

  Future<Map<String, dynamic>> _demoSecret(String path) async {
    try {
      final response = await _dio.post(path);
      final data = _asMap(response.data);
      if (data['success'] == true) return _asMap(data['data']);
      throw ServerException(
        message: data['error'] ?? 'Demo credential is unavailable',
      );
    } on DioException catch (error) {
      throw _demoError(error);
    }
  }

  Exception _demoError(DioException error) {
    if (error.response?.statusCode == 404) {
      return const ServerException(
        message:
            'Demo administration is not deployed on this server yet. Deploy the latest SchoolDesk API and migration, then try again.',
      );
    }
    return _handleError(error);
  }
}
