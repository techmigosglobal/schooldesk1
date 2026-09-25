import 'package:schooldesk1/core/network/models/backend_models.dart';
import 'package:schooldesk1/core/utils/result.dart';
import 'package:schooldesk1/roles/teacher/domain/teacher_attendance_snapshot.dart';

abstract interface class TeacherAttendanceRepository {
  Future<Result<List<AcademicYearModel>>> loadAcademicYears();

  Future<Result<PaginatedList<StudentModel>>> loadStudents({
    required String sectionId,
    required int page,
    required int pageSize,
  });

  Future<Result<List<Map<String, dynamic>>>> loadStudentEnrollments(
    String studentId,
  );

  Future<Result<TeacherAttendanceSnapshot>> loadStaffAttendance();

  Future<Result<TeacherAttendanceSnapshot>> scanStaffQr(String token);

  Future<Result<StaffAttendanceModel>> punchOutStaffAttendance();

  Future<Result<List<AttendanceSessionModel>>> loadHistory({
    required String sectionId,
    required String date,
  });

  Future<Result<AttendanceSessionModel>> createSession({
    required String sectionId,
    required String academicYearId,
    required String subjectId,
    required String staffId,
    required String date,
    int? periodNumber,
    String? timetableSlotId,
  });

  Future<Result<void>> markAttendance(
    String sessionId,
    List<Map<String, dynamic>> attendances, {
    required bool finalize,
  });

  Future<Result<AttendanceSessionModel>> requestCorrection(
    String sessionId, {
    required String reason,
  });
}
