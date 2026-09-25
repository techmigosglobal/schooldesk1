import 'package:schooldesk1/core/network/models/backend_models.dart';
import 'package:schooldesk1/core/utils/result.dart';

class PrincipalReportsSnapshot {
  const PrincipalReportsSnapshot({
    required this.invoices,
    required this.students,
    required this.staff,
    required this.attendance,
    required this.complaints,
    required this.academicYears,
  });

  final List<Map<String, dynamic>> invoices;
  final List<Map<String, dynamic>> students;
  final List<Map<String, dynamic>> staff;
  final List<Map<String, dynamic>> attendance;
  final List<Map<String, dynamic>> complaints;
  final List<Map<String, dynamic>> academicYears;
}

abstract interface class PrincipalReportsRepository {
  Future<Result<PrincipalReportsSnapshot>> loadSnapshot({
    bool forceRefresh = false,
  });

  Future<Result<Map<String, dynamic>>> loadSchool();

  Future<Result<List<StaffAttendanceModel>>> loadStaffAttendance({
    required String date,
  });

  Future<Result<Map<String, dynamic>>> loadStaffDailySummary({
    required String date,
  });

  Future<Result<List<LeaveApplicationModel>>> loadApprovedLeaveApplications();

  Future<Result<void>> createReportExport({
    required String path,
    required String reportTitle,
    required String reportType,
    required String format,
    required String scope,
    required Map<String, dynamic> parameters,
  });
}
