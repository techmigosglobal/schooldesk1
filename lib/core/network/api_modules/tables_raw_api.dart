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
  'homework',
  'leaves',
  'notifications',
  'holidays',
  'events',
  'approval-requests',
  'communications',
  'principal-reports',
  'student-documents',
  'staff-documents',
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
      final response = await _get(path, queryParameters: queryParameters);
      final data = _asMap(response.data);
      if (data['success'] == true) {
        final payload = data['data'];
        if (payload is Map) {
          return _asListMap(payload['items'] ?? payload['data']);
        }
        return _asListMap(payload);
      }
      throw ServerException(message: data['error'] ?? 'Failed to load $path');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Shared page-envelope reader for legacy table resources that have not yet
  /// earned a dedicated DTO. Interactive callers still receive typed
  /// `PaginatedList` metadata instead of guessing from a raw list length.
  Future<PaginatedList<Map<String, dynamic>>> getRawPage(
    String path, {
    Map<String, dynamic>? queryParameters,
    int page = 1,
    int pageSize = 20,
  }) async {
    final params = <String, dynamic>{
      ...?queryParameters,
      'page': page,
      'page_size': pageSize,
    };
    try {
      final response = await _get(path, queryParameters: params);
      final envelope = _asMap(response.data);
      if (envelope['success'] != true) {
        throw ServerException(
          message: envelope['error'] ?? 'Failed to load $path',
        );
      }
      final rawPayload = envelope['data'];
      final payload = rawPayload is Map ? _asMap(rawPayload) : null;
      final rows = _asListMap(
        payload?['data'] ?? payload?['items'] ?? rawPayload,
      );
      final total = _asInt(
        payload?['total'] ?? envelope['total'],
        fallback: rows.length,
      );
      return PaginatedList<Map<String, dynamic>>(
        data: rows,
        total: total,
        page: _asInt(payload?['page'] ?? envelope['page'], fallback: page),
        pageSize: _asInt(
          payload?['page_size'] ?? envelope['page_size'],
          fallback: pageSize,
        ),
        isStale: response.extra['schooldeskOfflineCache'] == true,
        cacheStoredAt: DateTime.tryParse(
          response.headers.value('x-schooldesk-cache-stored-at') ?? '',
        ),
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<PaginatedList<Map<String, dynamic>>> getAdmissionInquiriesPage({
    String? search,
    int page = 1,
    int pageSize = 20,
  }) {
    return getRawPage(
      '/admission-inquiries',
      queryParameters: {
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      },
      page: page,
      pageSize: pageSize,
    );
  }

  Future<PaginatedList<Map<String, dynamic>>> getDocumentRequestsPage({
    int page = 1,
    int pageSize = 20,
  }) => getRawPage('/documents/requests', page: page, pageSize: pageSize);

  Future<PaginatedList<Map<String, dynamic>>> getDocumentTemplatesPage({
    int page = 1,
    int pageSize = 20,
  }) => getRawPage('/documents/templates', page: page, pageSize: pageSize);

  Future<Map<String, dynamic>> getRawMap(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await _get(path, queryParameters: queryParameters);
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
    Map<String, dynamic> payload, {
    Map<String, dynamic>? extra,
  }) async {
    try {
      final root = _tablesMDRootListPath(path);
      if (root != null && extra == null) {
        final response = await SchoolDeskApi.instance.client.createTablesMdRoot(
          root,
          payload,
        );
        if (response.success == true) return _asMap(response.data);
        throw ServerException(
          message: response.error ?? 'Failed to create $path',
        );
      }
      final response = await _dio.post(
        path,
        data: payload,
        options: extra == null ? null : Options(extra: extra),
      );
      final data = _asMap(response.data);
      if (data['success'] == true) {
        final result = Map<String, dynamic>.from(data['data'] as Map? ?? {});
        if (data['queued'] == true) result['queued'] = true;
        return result;
      }
      throw ServerException(message: data['error'] ?? 'Failed to create $path');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> updateRaw(
    String path,
    Map<String, dynamic> payload, {
    Map<String, dynamic>? extra,
  }) async {
    try {
      final item = _tablesMDRootItemPath(path);
      if (item != null && extra == null) {
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
      final response = await _dio.put(
        path,
        data: payload,
        options: extra == null ? null : Options(extra: extra),
      );
      final data = _asMap(response.data);
      if (data['success'] == true) {
        final result = Map<String, dynamic>.from(data['data'] as Map? ?? {});
        if (data['queued'] == true) result['queued'] = true;
        return result;
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
