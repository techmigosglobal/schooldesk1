import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/roles/principal/domain/principal_attendance_repository.dart';

class ApiPrincipalAttendanceRepository
    implements PrincipalAttendanceRepository {
  ApiPrincipalAttendanceRepository(this._api);

  final BackendApiClient _api;

  @override
  Future<PaginatedList<AttendanceSessionModel>> loadSessions({
    String? startDate,
    String? endDate,
    String? date,
    int page = 1,
    int pageSize = 20,
  }) {
    return _api.getAttendanceSessionsPage(
      startDate: startDate,
      endDate: endDate,
      date: date,
      page: page,
      pageSize: pageSize,
    );
  }

  @override
  Future<List<StaffAttendanceModel>> loadStaffAttendance({
    String? startDate,
    String? endDate,
    String? date,
  }) {
    return _api.getStaffAttendanceForDate(
      startDate: startDate,
      endDate: endDate,
      date: date,
    );
  }

  @override
  Future<PaginatedList<StaffModel>> loadStaff({
    required int page,
    required int pageSize,
    String? status,
  }) {
    return _api.getStaff(page: page, pageSize: pageSize, status: status);
  }

  @override
  Future<List<SectionModel>> loadSections() => _api.getSections();

  @override
  Future<PaginatedList<StudentModel>> loadStudents({
    required String sectionId,
    required int page,
    required int pageSize,
  }) {
    return _api.getStudents(
      sectionId: sectionId,
      page: page,
      pageSize: pageSize,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> loadStudentAttendanceRecords(
    String studentId, {
    int? month,
    int? year,
  }) {
    return _api.getStudentAttendanceRecords(
      studentId,
      month: month,
      year: year,
    );
  }

  @override
  Future<AttendanceSessionModel> reopenSession(
    String sessionId, {
    required String reason,
  }) {
    return _api.reopenAttendanceSession(sessionId, reason: reason);
  }

  @override
  Future<Map<String, dynamic>> loadStaffDailySummary({required String date}) {
    return _api.getStaffDailyAttendanceSummary(date: date);
  }

  @override
  Future<Map<String, dynamic>> createReportExport({
    required String path,
    required String reportTitle,
    required String format,
    String reportType = '',
    String scope = '',
    Map<String, dynamic> parameters = const {},
  }) {
    return _api.createReportExport(
      path,
      reportTitle: reportTitle,
      format: format,
      reportType: reportType,
      scope: scope,
      parameters: parameters,
    );
  }

  static ApiPrincipalAttendanceRepository get legacyDefault =>
      ApiPrincipalAttendanceRepository(BackendApiClient.instance);
}
