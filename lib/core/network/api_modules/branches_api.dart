part of '../backend_api_client.dart';

extension BackendBranchesApi on BackendApiClient {
  Future<List<Map<String, dynamic>>> getBranches() async {
    try {
      final response = await _dio.get('/branches');
      final data = _asMap(response.data);
      if (data['success'] != true) {
        throw ServerException(
          message: data['error'] ?? 'Failed to load branches',
        );
      }
      return (data['data'] as List? ?? [])
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> createBranch(
    Map<String, dynamic> payload,
  ) async {
    try {
      final response = await _dio.post('/branches', data: payload);
      final data = _asMap(response.data);
      if (data['success'] != true) {
        throw ServerException(
          message: data['error'] ?? 'Failed to create branch',
        );
      }
      return _asMap(data['data']);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> updateBranch(
    String branchId,
    Map<String, dynamic> payload,
  ) async {
    try {
      final response = await _dio.patch('/branches/$branchId', data: payload);
      final data = _asMap(response.data);
      if (data['success'] != true) {
        throw ServerException(
          message: data['error'] ?? 'Failed to update branch',
        );
      }
      return _asMap(data['data']);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> deleteBranch(
    String branchId, {
    required String confirmation,
  }) async {
    try {
      final response = await _dio.delete(
        '/branches/$branchId',
        data: {'confirmation': confirmation},
      );
      final data = _asMap(response.data);
      if (data['success'] != true) {
        throw ServerException(
          message: data['error'] ?? 'Failed to delete branch',
        );
      }
      return _asMap(data['data']);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<Map<String, dynamic>>> getBranchOverview() async {
    try {
      final response = await _dio.get('/branches/overview');
      final data = _asMap(response.data);
      if (data['success'] != true) {
        throw ServerException(
          message: data['error'] ?? 'Failed to load branch overview',
        );
      }
      return (data['data'] as List? ?? [])
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }
}
