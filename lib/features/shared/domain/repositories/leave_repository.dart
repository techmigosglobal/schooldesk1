import 'package:schooldesk1/features/shared/domain/entities/leave_request.dart';
import 'package:schooldesk1/core/utils/result.dart';

/// Abstract repository interface for leave request operations.
abstract class LeaveRepository {
  Future<Result<List<LeaveRequest>>> getLeaveRequests({
    String? requesterId,
    String? status,
    String? role,
  });

  Future<Result<LeaveRequest>> getLeaveRequestById(String id);

  Future<Result<LeaveRequest>> submitLeaveRequest(LeaveRequest request);

  Future<Result<LeaveRequest>> approveLeaveRequest({
    required String id,
    required String approvedBy,
  });

  Future<Result<LeaveRequest>> rejectLeaveRequest({
    required String id,
    required String rejectedBy,
    required String remark,
  });

  Future<Result<void>> cancelLeaveRequest(String id);
}
