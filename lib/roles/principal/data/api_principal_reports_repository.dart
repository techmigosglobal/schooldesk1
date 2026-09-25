import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/repositories/api_repository_utils.dart';
import 'package:schooldesk1/core/services/backend_data_service.dart';
import 'package:schooldesk1/core/utils/result.dart';
import 'package:schooldesk1/roles/principal/domain/principal_reports_repository.dart';

class ApiPrincipalReportsRepository implements PrincipalReportsRepository {
  ApiPrincipalReportsRepository(this._api);

  final BackendApiClient _api;

  @override
  Future<Result<PrincipalReportsSnapshot>> loadSnapshot({
    bool forceRefresh = false,
  }) => guardApi(() async {
    final service = BackendDataService.instance;
    final values = await Future.wait<Object>([
      service.getList(BackendDataService.kStudentFees),
      service.getList(BackendDataService.kStudents),
      service.getList(BackendDataService.kAdminTeachers),
      service.getList(BackendDataService.kAdminAttendanceRecords),
      service.getList(BackendDataService.kComplaints),
      service.getList(BackendDataService.kAcademicYears),
    ]);
    return PrincipalReportsSnapshot(
      invoices: List<Map<String, dynamic>>.from(
        values[0] as List<Map<String, dynamic>>,
      ),
      students: List<Map<String, dynamic>>.from(
        values[1] as List<Map<String, dynamic>>,
      ),
      staff: List<Map<String, dynamic>>.from(
        values[2] as List<Map<String, dynamic>>,
      ),
      attendance: List<Map<String, dynamic>>.from(
        values[3] as List<Map<String, dynamic>>,
      ),
      complaints: List<Map<String, dynamic>>.from(
        values[4] as List<Map<String, dynamic>>,
      ),
      academicYears: List<Map<String, dynamic>>.from(
        values[5] as List<Map<String, dynamic>>,
      ),
    );
  });

  @override
  Future<Result<Map<String, dynamic>>> loadSchool() {
    return guardApi(_api.getCurrentSchool);
  }

  @override
  Future<Result<List<StaffAttendanceModel>>> loadStaffAttendance({
    required String date,
  }) {
    return guardApi(() => _api.getStaffAttendanceForDate(date: date));
  }

  @override
  Future<Result<Map<String, dynamic>>> loadStaffDailySummary({
    required String date,
  }) {
    return guardApi(() => _api.getStaffDailyAttendanceSummary(date: date));
  }

  @override
  Future<Result<List<LeaveApplicationModel>>> loadApprovedLeaveApplications() {
    return guardApi(() => _api.getLeaveApplications(status: 'approved'));
  }

  @override
  Future<Result<void>> createReportExport({
    required String path,
    required String reportTitle,
    required String reportType,
    required String format,
    required String scope,
    required Map<String, dynamic> parameters,
  }) {
    return guardApi(
      () => _api.createReportExport(
        path,
        reportTitle: reportTitle,
        reportType: reportType,
        format: format,
        scope: scope,
        parameters: parameters,
      ),
    );
  }

  static ApiPrincipalReportsRepository get legacyDefault =>
      ApiPrincipalReportsRepository(BackendApiClient.instance);
}
