import 'package:schooldesk1/core/utils/result.dart';
import 'package:schooldesk1/roles/parent/domain/parent_attendance_snapshot.dart';

abstract interface class ParentAttendanceRepository {
  Future<Result<List<Map<String, dynamic>>>> getChildren({
    bool forceRefresh = false,
  });

  Future<Result<ParentAttendanceSnapshot>> loadChild({
    required String studentId,
    bool forceRefresh = false,
  });
}
