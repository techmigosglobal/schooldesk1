// A named interface keeps capability access testable and overrideable.
// ignore_for_file: one_member_abstracts

import 'package:schooldesk1/core/utils/result.dart';
import 'package:schooldesk1/core/network/models/backend_models.dart';

class ApprovalFeed {
  const ApprovalFeed({
    required this.page,
    required this.pendingCount,
    required this.countsByType,
  });

  final PaginatedList<Map<String, dynamic>> page;
  final int pendingCount;
  final Map<String, int> countsByType;
}

abstract interface class ApprovalRepository {
  Future<Result<List<Map<String, dynamic>>>> getApprovalRequests();

  Future<ApprovalFeed> loadFeed({
    String status = 'pending',
    String search = '',
    int page = 1,
    int pageSize = 20,
  });

  Future<List<Map<String, dynamic>>> loadAuditLog({
    int pageSize = 10,
    String module = 'approvals',
    String actor = '',
    String actorRole = '',
    String eventType = '',
    String search = '',
    bool currentUserOnly = true,
  });

  Future<PaginatedList<Map<String, dynamic>>> loadPaymentRequests({
    String? status,
    int page = 1,
    int pageSize = 20,
  });

  Future<Map<String, dynamic>> decideStudentLeave(
    String id, {
    required String status,
    String rejectionReason = '',
  });

  Future<void> decideLeave(
    String id, {
    required String status,
    String reason = '',
  });

  Future<Map<String, dynamic>> decidePayment(
    String id, {
    required String status,
    String adminRemarks = '',
  });

  Future<Map<String, dynamic>> approve(String id);

  Future<Map<String, dynamic>> apply(String id);

  Future<Map<String, dynamic>> reject(String id, {required String reason});

  Future<Map<String, dynamic>> requestChanges(
    String id, {
    required String note,
  });

  Future<Map<String, dynamic>> createRaw(
    String path,
    Map<String, dynamic> payload,
  );

  Future<Map<String, dynamic>> updateRaw(
    String path,
    Map<String, dynamic> payload,
  );
}
