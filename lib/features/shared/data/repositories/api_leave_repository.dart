import 'package:schooldesk1/core/utils/result.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/features/shared/domain/entities/leave_request.dart';
import 'package:schooldesk1/features/shared/domain/repositories/leave_repository.dart';
import 'package:schooldesk1/features/shared/data/repositories/api_repository_utils.dart';

class ApiLeaveRepository implements LeaveRepository {
  ApiLeaveRepository(this._api);

  final BackendApiClient _api;

  @override
  Future<Result<List<LeaveRequest>>> getLeaveRequests({
    String? requesterId,
    String? status,
    String? role,
  }) {
    return guardApi(() async {
      final rows = await _api.getLeaveApplications(
        staffId: requesterId,
        status: status,
      );
      return rows.map(_toLeaveRequest).toList();
    });
  }

  @override
  Future<Result<LeaveRequest>> getLeaveRequestById(String id) {
    return guardApi(() async {
      final row = await _api.getRawMap('/leave/applications/$id');
      return _leaveFromMap(row);
    });
  }

  @override
  Future<Result<LeaveRequest>> submitLeaveRequest(LeaveRequest request) {
    return guardApi(() async {
      await _api.submitLeaveApplication(
        LeaveApplicationRequest(
          staffId: request.requesterId,
          leaveTypeId: request.leaveType,
          fromDate: _dateString(request.fromDate),
          toDate: _dateString(request.toDate),
          reason: request.reason,
        ),
      );
      return request.copyWith(status: 'pending', submittedAt: DateTime.now());
    });
  }

  @override
  Future<Result<LeaveRequest>> approveLeaveRequest({
    required String id,
    required String approvedBy,
  }) {
    return guardApi(() async {
      await _api.decideLeaveApplication(id, status: 'approved');
      return (await getLeaveRequestById(id)).dataOrNull ??
          _decisionFallback(id, 'approved', approvedBy);
    });
  }

  @override
  Future<Result<LeaveRequest>> rejectLeaveRequest({
    required String id,
    required String rejectedBy,
    required String remark,
  }) {
    return guardApi(() async {
      await _api.decideLeaveApplication(id, status: 'rejected', reason: remark);
      return (await getLeaveRequestById(id)).dataOrNull ??
          _decisionFallback(id, 'rejected', rejectedBy, remark: remark);
    });
  }

  @override
  Future<Result<void>> cancelLeaveRequest(String id) {
    return guardApi(() async {
      await _api.updateRaw('/leave/applications/$id', {'status': 'cancelled'});
    });
  }

  LeaveRequest _toLeaveRequest(LeaveApplicationModel model) {
    return LeaveRequest(
      id: model.id,
      requesterId: model.staffId,
      requesterName: '',
      requesterRole: 'teacher',
      leaveType: model.leaveTypeId,
      fromDate: parseDate(model.fromDate),
      toDate: parseDate(model.toDate),
      reason: model.reason ?? '',
      status: model.status,
      rejectionRemark: model.rejectionReason,
      submittedAt: DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  LeaveRequest _leaveFromMap(Map<String, dynamic> row) {
    return LeaveRequest(
      id: textValue(row['id']),
      requesterId: textValue(row['staff_id'] ?? row['requester_id']),
      requesterName: textValue(row['staff_name'] ?? row['requester_name']),
      requesterRole: textValue(row['requester_role']).isEmpty
          ? 'teacher'
          : textValue(row['requester_role']),
      leaveType: textValue(row['leave_type_id'] ?? row['leave_type']),
      fromDate: parseDate(row['from_date']),
      toDate: parseDate(row['to_date']),
      reason: textValue(row['reason']),
      status: textValue(row['status']).isEmpty
          ? 'pending'
          : textValue(row['status']),
      rejectionRemark: textValue(row['rejection_reason']),
      submittedAt: parseDate(row['created_at']),
      reviewedAt: DateTime.tryParse(textValue(row['reviewed_at'])),
    );
  }

  LeaveRequest _decisionFallback(
    String id,
    String status,
    String reviewer, {
    String? remark,
  }) {
    return LeaveRequest(
      id: id,
      requesterId: '',
      requesterName: '',
      requesterRole: 'teacher',
      leaveType: '',
      fromDate: DateTime.now(),
      toDate: DateTime.now(),
      reason: '',
      status: status,
      approvedBy: reviewer,
      rejectionRemark: remark,
      submittedAt: DateTime.now(),
      reviewedAt: DateTime.now(),
    );
  }

  String _dateString(DateTime value) =>
      value.toIso8601String().split('T').first;
}
