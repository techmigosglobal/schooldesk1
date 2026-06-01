import 'package:schooldesk1/core/utils/result.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/features/shared/domain/entities/attendance_record.dart';
import 'package:schooldesk1/features/shared/domain/repositories/attendance_repository.dart';
import 'package:schooldesk1/features/shared/data/repositories/api_repository_utils.dart';

class ApiAttendanceRepository implements AttendanceRepository {
  ApiAttendanceRepository(this._api);

  final BackendApiClient _api;

  @override
  Future<Result<List<AttendanceRecord>>> getAttendanceByDate({
    required DateTime date,
    String? className,
    String? section,
  }) {
    return guardApi(() async {
      final rows = await _api.getRawList(
        '/attendance',
        queryParameters: {'date': _dateString(date)},
      );
      return rows.map(_toAttendanceRecord).toList();
    });
  }

  @override
  Future<Result<List<AttendanceRecord>>> getAttendanceByStudent({
    required String studentId,
    DateTime? fromDate,
    DateTime? toDate,
  }) {
    return guardApi(() async {
      final rows = await _api.getStudentAttendanceRecords(studentId);
      return rows.map(_toAttendanceRecord).toList();
    });
  }

  @override
  Future<Result<void>> markAttendance(List<AttendanceRecord> records) {
    return guardApi(() async {
      for (final record in records) {
        await _api.createRaw('/attendance', _attendancePayload(record));
      }
    });
  }

  @override
  Future<Result<void>> updateAttendanceRecord(AttendanceRecord record) {
    return guardApi(() async {
      await _api.updateRaw(
        '/attendance/${record.id}',
        _attendancePayload(record),
      );
    });
  }

  @override
  Future<Result<Map<String, double>>> getAttendanceSummary({
    required String className,
    required String section,
    required DateTime month,
  }) {
    return guardApi(() async {
      final students = await _api.getStudents(
        sectionId: section,
        pageSize: 500,
      );
      var total = 0.0;
      var count = 0;
      for (final student in students.data) {
        final summary = await _api.getStudentAttendanceSummary(
          studentId: student.id,
        );
        total += doubleValue(
          summary['percentage'] ??
              summary['percent'] ??
              summary['attendance_percent'],
        );
        count += 1;
      }
      return {'percentage': count == 0 ? 0 : total / count};
    });
  }

  @override
  Future<Result<double>> getStudentAttendancePercentage({
    required String studentId,
    required DateTime fromDate,
    required DateTime toDate,
  }) {
    return guardApi(() async {
      final summary = await _api.getStudentAttendanceSummary(
        studentId: studentId,
      );
      return doubleValue(
        summary['percentage'] ??
            summary['percent'] ??
            summary['attendance_percent'],
      );
    });
  }

  AttendanceRecord _toAttendanceRecord(Map<String, dynamic> row) {
    final student = _map(row['student']);
    return AttendanceRecord(
      id: textValue(row['id']),
      studentId: textValue(row['student_id'] ?? student['id']),
      studentName: textValue(
        row['student_name'] ??
            student['full_name'] ??
            [
              textValue(student['first_name']),
              textValue(student['last_name']),
            ].where((part) => part.isNotEmpty).join(' '),
      ),
      className: textValue(row['class'] ?? row['grade_name']),
      section: textValue(row['section'] ?? row['section_name']),
      date: parseDate(
        row['date'] ?? row['marked_at'],
        fallback: DateTime.now(),
      ),
      status: textValue(row['status']).isEmpty
          ? 'present'
          : textValue(row['status']),
      remarks: textValue(row['remarks'] ?? row['reason']),
      markedBy: textValue(row['marked_by']),
      markedAt: DateTime.tryParse(textValue(row['marked_at'])),
    );
  }

  Map<String, dynamic> _attendancePayload(AttendanceRecord record) => {
    'student_id': record.studentId,
    'date': _dateString(record.date),
    'status': record.status,
    if (textValue(record.remarks).isNotEmpty) 'reason': record.remarks,
  };

  Map<String, dynamic> _map(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }

  String _dateString(DateTime value) =>
      value.toIso8601String().split('T').first;
}
