import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/repositories/api_repository_utils.dart';
import 'package:schooldesk1/core/utils/result.dart';
import 'package:schooldesk1/roles/parent/domain/parent_leave_repository.dart';

class ApiParentLeaveRepository implements ParentLeaveRepository {
  ApiParentLeaveRepository(this._api);

  final BackendApiClient _api;

  @override
  Future<Result<List<Map<String, dynamic>>>> getChildren({
    bool forceRefresh = false,
  }) {
    return guardApi(
      () => _api.getMyStudents(
        refreshNonce: forceRefresh
            ? DateTime.now().millisecondsSinceEpoch
            : null,
      ),
    );
  }

  @override
  Future<Result<List<Map<String, dynamic>>>> getRequests({
    required String studentId,
    bool forceRefresh = false,
  }) {
    return guardApi(
      () => _api.getStudentLeaveApplications(
        studentId: studentId,
        forceRefresh: forceRefresh,
      ),
    );
  }

  @override
  Future<Result<List<Map<String, dynamic>>>> getLeaveTypes({
    bool forceRefresh = false,
  }) {
    return guardApi(() => _api.getLeaveTypes(forceRefresh: forceRefresh));
  }

  @override
  Future<Result<void>> submitRequest({
    required String studentId,
    required String leaveType,
    required String fromDate,
    required String toDate,
    required String reason,
    bool halfDay = false,
  }) {
    return guardApi(
      () => _api
          .submitStudentLeaveApplication(
            studentId: studentId,
            leaveType: leaveType,
            fromDate: fromDate,
            toDate: toDate,
            halfDay: halfDay,
            reason: reason,
          )
          .then((_) {}),
    );
  }

  static ApiParentLeaveRepository get legacyDefault =>
      ApiParentLeaveRepository(BackendApiClient.instance);
}
