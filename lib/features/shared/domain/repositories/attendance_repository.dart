import '../entities/attendance_record.dart';
import '../../../../core/utils/result.dart';

/// Abstract repository interface for attendance operations.
abstract class AttendanceRepository {
  Future<Result<List<AttendanceRecord>>> getAttendanceByDate({
    required DateTime date,
    String? className,
    String? section,
  });

  Future<Result<List<AttendanceRecord>>> getAttendanceByStudent({
    required String studentId,
    DateTime? fromDate,
    DateTime? toDate,
  });

  Future<Result<void>> markAttendance(List<AttendanceRecord> records);

  Future<Result<void>> updateAttendanceRecord(AttendanceRecord record);

  Future<Result<Map<String, double>>> getAttendanceSummary({
    required String className,
    required String section,
    required DateTime month,
  });

  Future<Result<double>> getStudentAttendancePercentage({
    required String studentId,
    required DateTime fromDate,
    required DateTime toDate,
  });
}
