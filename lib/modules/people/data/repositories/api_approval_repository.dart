import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/repositories/api_repository_utils.dart';
import 'package:schooldesk1/core/utils/result.dart';
import 'package:schooldesk1/modules/people/domain/repositories/approval_repository.dart';

class ApiApprovalRepository implements ApprovalRepository {
  ApiApprovalRepository(this._api);

  final BackendApiClient _api;

  @override
  Future<Result<List<Map<String, dynamic>>>> getApprovalRequests() {
    return guardApi(_api.getApprovalRequests);
  }

  @override
  Future<ApprovalFeed> loadFeed({
    String status = 'pending',
    String search = '',
    int page = 1,
    int pageSize = 20,
  }) async {
    final feed = await _api.getApprovalFeed(
      status: status,
      search: search,
      page: page,
      pageSize: pageSize,
    );
    return ApprovalFeed(
      page: feed.page,
      pendingCount: feed.pendingCount,
      countsByType: feed.countsByType,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> loadAuditLog({
    int pageSize = 10,
    String module = 'approvals',
    String actor = '',
    String actorRole = '',
    String eventType = '',
    String search = '',
    bool currentUserOnly = true,
  }) => _api.getApprovalAuditLog(
    pageSize: pageSize,
    module: module,
    actor: actor,
    actorRole: actorRole,
    eventType: eventType,
    search: search,
    currentUserOnly: currentUserOnly,
  );

  @override
  Future<PaginatedList<Map<String, dynamic>>> loadPaymentRequests({
    String? status,
    int page = 1,
    int pageSize = 20,
  }) => _api.getParentPaymentRequestsPage(
    status: status,
    page: page,
    pageSize: pageSize,
  );

  @override
  Future<Map<String, dynamic>> decideStudentLeave(
    String id, {
    required String status,
    String rejectionReason = '',
  }) => _api.decideStudentLeaveApplication(
    id,
    status: status,
    rejectionReason: rejectionReason,
  );

  @override
  Future<void> decideLeave(
    String id, {
    required String status,
    String reason = '',
  }) => _api.decideLeaveApplication(id, status: status, reason: reason);

  @override
  Future<Map<String, dynamic>> decidePayment(
    String id, {
    required String status,
    String adminRemarks = '',
  }) => _api.decideParentPaymentRequest(
    id,
    status: status,
    adminRemarks: adminRemarks,
  );

  @override
  Future<Map<String, dynamic>> approve(String id) =>
      _api.approveApprovalRequest(id);

  @override
  Future<Map<String, dynamic>> apply(String id) =>
      _api.applyApprovalRequest(id);

  @override
  Future<Map<String, dynamic>> reject(
    String id, {
    required String reason,
  }) => _api.rejectApprovalRequest(id, reason: reason);

  @override
  Future<Map<String, dynamic>> requestChanges(
    String id, {
    required String note,
  }) => _api.requestApprovalChanges(id, note: note);

  @override
  Future<Map<String, dynamic>> createRaw(
    String path,
    Map<String, dynamic> payload,
  ) => _api.createRaw(path, payload);

  @override
  Future<Map<String, dynamic>> updateRaw(
    String path,
    Map<String, dynamic> payload,
  ) => _api.updateRaw(path, payload);

  static ApiApprovalRepository get legacyDefault =>
      ApiApprovalRepository(BackendApiClient.instance);
}
