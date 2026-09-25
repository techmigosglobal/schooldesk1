import 'package:schooldesk1/core/utils/result.dart';

abstract interface class ParentLeaveRepository {
  Future<Result<List<Map<String, dynamic>>>> getChildren({
    bool forceRefresh = false,
  });

  Future<Result<List<Map<String, dynamic>>>> getRequests({
    required String studentId,
    bool forceRefresh = false,
  });

  Future<Result<List<Map<String, dynamic>>>> getLeaveTypes({
    bool forceRefresh = false,
  });

  Future<Result<void>> submitRequest({
    required String studentId,
    required String leaveType,
    required String fromDate,
    required String toDate,
    required String reason,
    bool halfDay = false,
  });
}
