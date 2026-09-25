import 'package:schooldesk1/core/network/models/backend_models.dart';

/// Data boundary for Principal attendance oversight.
abstract interface class PrincipalAttendanceRepository {
  Future<PaginatedList<AttendanceSessionModel>> loadSessions({
    String? startDate,
    String? endDate,
    String? date,
    int page = 1,
    int pageSize = 20,
  });

  Future<List<StaffAttendanceModel>> loadStaffAttendance({
    String? startDate,
    String? endDate,
    String? date,
  });

  Future<PaginatedList<StaffModel>> loadStaff({
    required int page,
    required int pageSize,
    String? status,
  });

  Future<List<SectionModel>> loadSections();

  Future<PaginatedList<StudentModel>> loadStudents({
    required String sectionId,
    required int page,
    required int pageSize,
  });

  Future<List<Map<String, dynamic>>> loadStudentAttendanceRecords(
    String studentId, {
    int? month,
    int? year,
  });

  Future<AttendanceSessionModel> reopenSession(
    String sessionId, {
    required String reason,
  });

  Future<Map<String, dynamic>> loadStaffDailySummary({required String date});

  Future<Map<String, dynamic>> createReportExport({
    required String path,
    required String reportTitle,
    required String format,
    String reportType = '',
    String scope = '',
    Map<String, dynamic> parameters = const {},
  });
}
