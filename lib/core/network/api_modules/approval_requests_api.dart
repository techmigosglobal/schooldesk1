part of '../backend_api_client.dart';

class ApprovalFeedPage {
  final PaginatedList<Map<String, dynamic>> page;
  final int pendingCount;
  final Map<String, int> countsByType;

  const ApprovalFeedPage({
    required this.page,
    required this.pendingCount,
    required this.countsByType,
  });
}

extension BackendApprovalRequestsApi on BackendApiClient {
  Future<List<Map<String, dynamic>>> getApprovalAuditLog({
    int pageSize = 10,
    String module = 'approvals',
    String actor = '',
    String actorRole = '',
    String eventType = '',
    String search = '',
    bool currentUserOnly = true,
  }) {
    return getRawList(
      '/audit-logs',
      queryParameters: {
        if (module.trim().isNotEmpty) 'module': module.trim(),
        if (currentUserOnly) 'user_id': 'current',
        'page_size': pageSize,
        if (actor.trim().isNotEmpty) 'actor': actor.trim(),
        if (actorRole.trim().isNotEmpty) 'actor_role': actorRole.trim(),
        if (eventType.trim().isNotEmpty) 'event_type': eventType.trim(),
        if (search.trim().isNotEmpty) 'search': search.trim(),
      },
    );
  }

  Future<ApprovalFeedPage> getApprovalFeed({
    String status = 'pending',
    String type = '',
    String search = '',
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final query = <String, dynamic>{
        'page': page,
        'page_size': pageSize,
        if (status.trim().isNotEmpty) 'status': status.trim(),
        if (type.trim().isNotEmpty) 'type': type.trim(),
        if (search.trim().isNotEmpty) 'search': search.trim(),
      };
      final response = await _get('/approvals/feed', queryParameters: query);
      final payload = _asMap(response.data);
      if (payload['success'] == true) {
        return ApprovalFeedPage(
          page: PaginatedList<Map<String, dynamic>>(
            data: _asListMap(payload['data']),
            total: _asInt(payload['total']),
            page: _asInt(payload['page'], fallback: page),
            pageSize: _asInt(payload['page_size'], fallback: pageSize),
          ),
          pendingCount: _asInt(payload['pending_count']),
          countsByType: _asMap(payload['counts_by_type']).map(
            (key, value) => MapEntry(key, _asInt(value)),
          ),
        );
      }
      throw ServerException(
        message: payload['error'] ?? 'Failed to load approval feed',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<Map<String, dynamic>>> getApprovalRequests({
    String status = '',
    String module = '',
  }) async {
    final query = <String, dynamic>{
      if (status.trim().isNotEmpty) 'status': status.trim(),
      if (module.trim().isNotEmpty) 'module': module.trim(),
    };
    return getRawList('/approvals', queryParameters: query);
  }

  Future<Map<String, dynamic>> createApprovalRequest({
    required String module,
    required String operationType,
    required String entityType,
    String entityId = '',
    String academicYearId = '',
    String status = 'draft',
    Map<String, dynamic> payload = const {},
    Map<String, dynamic> beforeSnapshot = const {},
    Map<String, dynamic> afterSnapshot = const {},
  }) {
    return createRaw('/approvals', {
      'module': module.trim(),
      'operation_type': operationType.trim(),
      'entity_type': entityType.trim(),
      if (entityId.trim().isNotEmpty) 'entity_id': entityId.trim(),
      if (academicYearId.trim().isNotEmpty)
        'academic_year_id': academicYearId.trim(),
      'status': status.trim().isEmpty ? 'draft' : status.trim(),
      'payload_json': payload,
      'before_snapshot_json': beforeSnapshot,
      'after_snapshot_json': afterSnapshot,
    });
  }

  Future<Map<String, dynamic>> updateApprovalRequest(
    String id, {
    String operationType = '',
    String entityType = '',
    String entityId = '',
    String academicYearId = '',
    Map<String, dynamic>? payload,
    Map<String, dynamic>? beforeSnapshot,
    Map<String, dynamic>? afterSnapshot,
  }) {
    return updateRaw('/approvals/${id.trim()}', {
      if (operationType.trim().isNotEmpty)
        'operation_type': operationType.trim(),
      if (entityType.trim().isNotEmpty) 'entity_type': entityType.trim(),
      if (entityId.trim().isNotEmpty) 'entity_id': entityId.trim(),
      if (academicYearId.trim().isNotEmpty)
        'academic_year_id': academicYearId.trim(),
      if (payload != null) 'payload_json': payload,
      if (beforeSnapshot != null) 'before_snapshot_json': beforeSnapshot,
      if (afterSnapshot != null) 'after_snapshot_json': afterSnapshot,
    });
  }

  Future<Map<String, dynamic>> submitApprovalRequest(String id) {
    return createRaw(
      '/approvals/${id.trim()}/submit',
      const <String, dynamic>{},
    );
  }

  Future<Map<String, dynamic>> approveApprovalRequest(
    String id, {
    String note = '',
  }) {
    return createRaw('/approvals/${id.trim()}/approve', {
      if (note.trim().isNotEmpty) 'note': note.trim(),
    });
  }

  Future<Map<String, dynamic>> rejectApprovalRequest(
    String id, {
    required String reason,
  }) {
    return createRaw('/approvals/${id.trim()}/reject', {
      'reason': reason.trim(),
    });
  }

  Future<Map<String, dynamic>> requestApprovalChanges(
    String id, {
    required String note,
  }) {
    return createRaw('/approvals/${id.trim()}/request-changes', {
      'note': note.trim(),
    });
  }

  Future<Map<String, dynamic>> cancelApprovalRequest(String id) {
    return createRaw(
      '/approvals/${id.trim()}/cancel',
      const <String, dynamic>{},
    );
  }

  Future<Map<String, dynamic>> applyApprovalRequest(String id) {
    return createRaw(
      '/approvals/${id.trim()}/apply',
      const <String, dynamic>{},
    );
  }
}
