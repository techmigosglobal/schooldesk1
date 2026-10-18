import 'package:schooldesk1/core/errors/exceptions.dart';
import 'package:dio/dio.dart';
import 'package:schooldesk1/roles/teacher/domain/teacher_attendance_context.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/repositories/api_repository_utils.dart';
import 'package:schooldesk1/core/utils/result.dart';
import 'package:schooldesk1/roles/teacher/domain/teacher_attendance_repository.dart';
import 'package:schooldesk1/roles/teacher/domain/teacher_attendance_snapshot.dart';

class ApiTeacherAttendanceRepository implements TeacherAttendanceRepository {
  ApiTeacherAttendanceRepository(this._api);

  final BackendApiClient _api;

  // These calendar/roster reads must not reuse cached configuration or marks.
  Future<dynamic> _fresh(String path, Map<String, dynamic> query) async {
    try {
      final response = await _api.dio.get<dynamic>(
        path,
        queryParameters: query,
        options: Options(headers: {'Cache-Control': 'no-store'}),
      );
      final envelope = Map<String, dynamic>.from(response.data as Map);
      if (envelope['success'] != true) {
        throw ServerException(
          message: '${envelope['error'] ?? 'Unable to load attendance'}',
        );
      }
      return envelope['data'];
    } on DioException catch (error) {
      final payload = error.response?.data;
      throw ServerException(
        message: payload is Map && payload['error'] is String
            ? payload['error'] as String
            : 'Unable to reach school attendance. Check your connection and retry.',
        statusCode: error.response?.statusCode,
      );
    }
  }

  @override
  Future<Result<TeacherAttendanceContext>> loadContext({
    required String sectionId,
  }) => guardApi(
    () async => TeacherAttendanceContext.fromJson(
      Map<String, dynamic>.from(
        await _fresh('/attendance/context', {'section_id': sectionId}) as Map,
      ),
    ),
  );

  @override
  Future<Result<List<AcademicYearModel>>> loadAcademicYears() {
    return guardApi(_api.getAcademicYears);
  }

  @override
  Future<Result<List<StudentModel>>> loadRoster({
    required String sectionId,
    required String date,
  }) => guardApi(() async {
    final result = Map<String, dynamic>.from(
      await _fresh('/attendance/roster', {
            'section_id': sectionId,
            'date': date,
          })
          as Map,
    );
    return (result['items'] as List? ?? [])
        .whereType<Map>()
        .map((row) => StudentModel.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  });

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
      () => _api.getAttendanceSessions(
        sectionId: sectionId,
        date: date,
        forceRefresh: true,
      ),
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
      () => _api.markAttendance(sessionId, attendances, finalize: finalize),
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
