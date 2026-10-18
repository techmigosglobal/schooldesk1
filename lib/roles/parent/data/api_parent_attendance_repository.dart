import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/repositories/api_repository_utils.dart';
import 'package:schooldesk1/core/utils/result.dart';
import 'package:schooldesk1/roles/parent/domain/parent_attendance_repository.dart';
import 'package:schooldesk1/roles/parent/domain/parent_attendance_snapshot.dart';

class ApiParentAttendanceRepository implements ParentAttendanceRepository {
  ApiParentAttendanceRepository(this._api);

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
  Future<Result<ParentAttendanceSnapshot>> loadChild({
    required String studentId,
    bool forceRefresh = false,
  }) {
    return guardApi(() async {
      Object? partialError;
      var fromCache = false;
      final failedSections = <String>{};
      void cache(CacheMetadata value) {
        fromCache = fromCache || value.isStale;
      }

      Future<Map<String, dynamic>> loadSummary() async {
        try {
          return await _api.getStudentAttendanceSummary(
            studentId: studentId,
            forceRefresh: forceRefresh,
            onCacheMetadata: cache,
          );
        } on Object catch (error) {
          partialError ??= error;
          failedSections.add('summary');
          return <String, dynamic>{'student_id': studentId};
        }
      }

      Future<List<Map<String, dynamic>>> loadRecords() async {
        try {
          return await _api.getStudentAttendanceRecords(
            studentId,
            month: DateTime.now().month,
            year: DateTime.now().year,
            forceRefresh: forceRefresh,
            onCacheMetadata: cache,
          );
        } on Object catch (error) {
          partialError ??= error;
          failedSections.add('records');
          return const <Map<String, dynamic>>[];
        }
      }

      Future<List<Map<String, dynamic>>> loadLeaveRequests() async {
        try {
          return await _api.getStudentLeaveApplications(
            studentId: studentId,
            forceRefresh: forceRefresh,
          );
        } on Object catch (error) {
          partialError ??= error;
          failedSections.add('leave');
          return const <Map<String, dynamic>>[];
        }
      }

      final results = await Future.wait<Object>([
        loadSummary(),
        loadRecords(),
        loadLeaveRequests(),
      ]);
      return ParentAttendanceSnapshot(
        summary: Map<String, dynamic>.from(results[0] as Map),
        records: List<Map<String, dynamic>>.from(results[1] as List),
        leaveRequests: List<Map<String, dynamic>>.from(results[2] as List),
        partialError: partialError?.toString(),
        fromCache: fromCache,
        failedSections: failedSections,
      );
    });
  }

  static ApiParentAttendanceRepository get legacyDefault =>
      ApiParentAttendanceRepository(BackendApiClient.instance);
}
