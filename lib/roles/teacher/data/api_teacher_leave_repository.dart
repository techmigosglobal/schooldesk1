import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/repositories/api_repository_utils.dart';
import 'package:schooldesk1/core/utils/result.dart';
import 'package:schooldesk1/roles/teacher/domain/teacher_leave_context.dart';
import 'package:schooldesk1/roles/teacher/domain/teacher_leave_repository.dart';

class ApiTeacherLeaveRepository implements TeacherLeaveRepository {
  ApiTeacherLeaveRepository(this._api);

  final BackendApiClient _api;

  @override
  Future<Result<TeacherLeaveContext>> load({
    String? staffId,
    bool forceRefresh = false,
  }) {
    return guardApi(() async {
      final dashboard = await _api.getDashboard(
        'teacher',
        forceRefresh: forceRefresh,
      );
      final resolvedStaffId = (staffId ?? dashboard['staff_id'] ?? '')
          .toString()
          .trim();
      final results = await Future.wait([
        _api.getLeaveTypes(forceRefresh: forceRefresh),
        _api.getLeaveBalances(
          staffId: resolvedStaffId,
          forceRefresh: forceRefresh,
        ),
        _api.getLeaveApplications(
          staffId: resolvedStaffId,
          forceRefresh: forceRefresh,
        ),
      ]);
      return TeacherLeaveContext(
        staffId: resolvedStaffId,
        leaveTypes: results[0] as List<Map<String, dynamic>>,
        balances: results[1] as List<Map<String, dynamic>>,
        applications: results[2] as List<LeaveApplicationModel>,
      );
    });
  }

  @override
  Future<Result<void>> submit(LeaveApplicationRequest request) {
    return guardApi(() => _api.submitLeaveApplication(request));
  }

  @override
  Future<Result<void>> recall(String applicationId) {
    return guardApi(() => _api.recallLeaveApplication(applicationId));
  }

  static ApiTeacherLeaveRepository get legacyDefault =>
      ApiTeacherLeaveRepository(BackendApiClient.instance);
}
