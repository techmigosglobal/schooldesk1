import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/repositories/api_repository_utils.dart';
import 'package:schooldesk1/core/utils/result.dart';
import 'package:schooldesk1/roles/teacher/domain/teacher_attendance_repository.dart';
import 'package:schooldesk1/roles/teacher/domain/teacher_attendance_snapshot.dart';

class ApiTeacherAttendanceRepository implements TeacherAttendanceRepository {
  ApiTeacherAttendanceRepository(this._api);

  final BackendApiClient _api;

  @override
  Future<Result<List<AcademicYearModel>>> loadAcademicYears() {
    return guardApi(_api.getAcademicYears);
  }

  @override
  Future<Result<PaginatedList<StudentModel>>> loadStudents({
    required String sectionId,
    required int page,
    required int pageSize,
  }) {
    return guardApi(
      () => _api.getStudents(
        sectionId: sectionId,
        page: page,
        pageSize: pageSize,
      ),
    );
  }

  @override
  Future<Result<List<Map<String, dynamic>>>> loadStudentEnrollments(
    String studentId,
  ) {
    return guardApi(() => _api.getStudentEnrollments(studentId));
  }

  @override
  Future<Result<TeacherAttendanceSnapshot>> loadStaffAttendance() {
    return guardApi(() async {
      final today = await _api.getMyStaffAttendanceToday();
      final log = await _api.getMyStaffAttendanceLog(days: 30);
      return TeacherAttendanceSnapshot(today: today, log: log);
    });
  }

  @override
  Future<Result<TeacherAttendanceSnapshot>> scanStaffQr(String token) {
    return guardApi(() async {
      final today = await _api.scanStaffQr(token);
      final log = await _api.getMyStaffAttendanceLog(days: 30);
      return TeacherAttendanceSnapshot(today: today, log: log);
    });
  }

  @override
  Future<Result<StaffAttendanceModel>> punchOutStaffAttendance() {
    return guardApi(_api.punchOutMyStaffAttendance);
  }

  @override
  Future<Result<List<AttendanceSessionModel>>> loadHistory({
    required String sectionId,
    required String date,
  }) {
    return guardApi(
      () => _api.getAttendanceSessions(sectionId: sectionId, date: date),
    );
  }

  @override
  Future<Result<AttendanceSessionModel>> createSession({
    required String sectionId,
    required String academicYearId,
    required String subjectId,
    required String staffId,
    required String date,
    int? periodNumber,
    String? timetableSlotId,
  }) {
    return guardApi(
      () => _api.createAttendanceSession(
        sectionId: sectionId,
        academicYearId: academicYearId,
        subjectId: subjectId,
        staffId: staffId,
        date: date,
        periodNumber: periodNumber,
        timetableSlotId: timetableSlotId,
      ),
    );
  }

  @override
  Future<Result<void>> markAttendance(
    String sessionId,
    List<Map<String, dynamic>> attendances, {
    required bool finalize,
  }) {
    return guardApi(
      () => _api.markAttendance(
        sessionId,
        attendances,
        finalize: finalize,
      ),
    );
  }

  @override
  Future<Result<AttendanceSessionModel>> requestCorrection(
    String sessionId, {
    required String reason,
  }) {
    return guardApi(
      () => _api.requestAttendanceCorrection(sessionId, reason: reason),
    );
  }

  static ApiTeacherAttendanceRepository get legacyDefault =>
      ApiTeacherAttendanceRepository(BackendApiClient.instance);
}
