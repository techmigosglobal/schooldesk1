part of '../backend_api_client.dart';

String _tablesMDPath(String resource) {
  switch (resource.trim()) {
    case 'approval_requests':
      return 'approval-requests';
    case 'principal_reports':
      return 'principal-reports';
    default:
      return resource.trim().replaceAll('_', '-');
  }
}

String? _tablesMDRootListPath(String path) {
  final segments = _pathSegments(path);
  if (segments.length != 1) return null;
  return _tablesMDRoots.contains(segments.first) ? segments.first : null;
}

({String root, String id})? _tablesMDRootItemPath(String path) {
  final segments = _pathSegments(path);
  if (segments.length != 2 || !_tablesMDRoots.contains(segments.first)) {
    return null;
  }
  return (root: segments.first, id: segments.last);
}

List<String> _pathSegments(String path) {
  return path
      .split('?')
      .first
      .split('/')
      .where((segment) => segment.trim().isNotEmpty)
      .toList(growable: false);
}

const Set<String> _tablesMDRoots = {
  'classes',
  'attendance',
  'fees',
  'exams',
  'homework',
  'leaves',
  'notifications',
  'holidays',
  'events',
  'approval-requests',
  'communications',
  'principal-reports',
};

extension BackendTablesRawApi on BackendApiClient {
  // ─── Tables.md ERP Resource Helpers ───────────────────────────────────────

  Future<List<Map<String, dynamic>>> getTablesMDRows(
    String resource, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await SchoolDeskApi.instance.client.listTablesMdRoot(
        _tablesMDPath(resource),
        queryParameters,
      );
      if (response.success == true) return _asListMap(response.data);
      throw ServerException(
        message: 'Failed to load ${_tablesMDPath(resource)}',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getTablesMDRow(
    String resource,
    String id,
  ) async {
    try {
      final response = await SchoolDeskApi.instance.client.getTablesMdRoot(
        _tablesMDPath(resource),
        id,
      );
      if (response.success == true) return _asMap(response.data);
      throw ServerException(
        message: response.error ?? 'Failed to load $resource',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> createTablesMDRow(
    String resource,
    Map<String, dynamic> payload,
  ) async {
    try {
      final response = await SchoolDeskApi.instance.client.createTablesMdRoot(
        _tablesMDPath(resource),
        payload,
      );
      if (response.success == true) return _asMap(response.data);
      throw ServerException(
        message: response.error ?? 'Failed to create $resource',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> updateTablesMDRow(
    String resource,
    String id,
    Map<String, dynamic> payload,
  ) async {
    try {
      final response = await SchoolDeskApi.instance.client.updateTablesMdRoot(
        _tablesMDPath(resource),
        id,
        payload,
      );
      if (response.success == true) return _asMap(response.data);
      throw ServerException(
        message: response.error ?? 'Failed to update $resource',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> deleteTablesMDRow(String resource, String id) async {
    try {
      final response = await SchoolDeskApi.instance.client.deleteTablesMdRoot(
        _tablesMDPath(resource),
        id,
      );
      if (response.success == true) return;
      throw ServerException(
        message: response.error ?? 'Failed to delete $resource',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ─── Raw CRUD Helpers ─────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getRawList(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final root = _tablesMDRootListPath(path);
      if (root != null) {
        final response = await SchoolDeskApi.instance.client.listTablesMdRoot(
          root,
          queryParameters,
        );
        if (response.success == true) return _asListMap(response.data);
        throw ServerException(message: 'Failed to load $path');
      }
      final response = await _dio.get(path, queryParameters: queryParameters);
      final data = _asMap(response.data);
      if (data['success'] == true) {
        return _asListMap(data['data']);
      }
      throw ServerException(message: data['error'] ?? 'Failed to load $path');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getRawMap(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await _dio.get(path, queryParameters: queryParameters);
      final data = _asMap(response.data);
      if (data['success'] == true) {
        return _asMap(data['data']);
      }
      throw ServerException(message: data['error'] ?? 'Failed to load $path');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> createRaw(
    String path,
    Map<String, dynamic> payload,
  ) async {
    try {
      final root = _tablesMDRootListPath(path);
      if (root != null) {
        final response = await SchoolDeskApi.instance.client.createTablesMdRoot(
          root,
          payload,
        );
        if (response.success == true) return _asMap(response.data);
        throw ServerException(
          message: response.error ?? 'Failed to create $path',
        );
      }
      final response = await _dio.post(path, data: payload);
      final data = _asMap(response.data);
      if (data['success'] == true) {
        return Map<String, dynamic>.from(data['data'] as Map? ?? {});
      }
      throw ServerException(message: data['error'] ?? 'Failed to create $path');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> updateRaw(
    String path,
    Map<String, dynamic> payload,
  ) async {
    try {
      final item = _tablesMDRootItemPath(path);
      if (item != null) {
        final response = await SchoolDeskApi.instance.client.updateTablesMdRoot(
          item.root,
          item.id,
          payload,
        );
        if (response.success == true) return _asMap(response.data);
        throw ServerException(
          message: response.error ?? 'Failed to update $path',
        );
      }
      final response = await _dio.put(path, data: payload);
      final data = _asMap(response.data);
      if (data['success'] == true) {
        return Map<String, dynamic>.from(data['data'] as Map? ?? {});
      }
      throw ServerException(message: data['error'] ?? 'Failed to update $path');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> deleteRaw(String path) async {
    try {
      final item = _tablesMDRootItemPath(path);
      if (item != null) {
        final response = await SchoolDeskApi.instance.client.deleteTablesMdRoot(
          item.root,
          item.id,
        );
        if (response.success == true) return;
        throw ServerException(
          message: response.error ?? 'Failed to delete $path',
        );
      }
      final response = await _dio.delete(path);
      final data = _asMap(response.data);
      if (data['success'] == true) return;
      throw ServerException(message: data['error'] ?? 'Failed to delete $path');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }
}
