import 'package:schooldesk1/core/utils/result.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/modules/attendance/domain/entities/attendance_record.dart';
import 'package:schooldesk1/modules/attendance/domain/repositories/attendance_repository.dart';
import 'package:schooldesk1/core/repositories/api_repository_utils.dart';
import 'package:schooldesk1/core/offline/offline_database.dart';

class ApiAttendanceRepository implements AttendanceRepository {
  ApiAttendanceRepository(this._api, [this._offlineDatabase]);

  final BackendApiClient _api;
  OfflineDatabase? _offlineDatabase;

  void attachOfflineDatabase(OfflineDatabase database) {
    _offlineDatabase = database;
  }

  @override
  Future<Result<List<AttendanceRecord>>> getAttendanceByDate({
    required DateTime date,
    String? className,
    String? section,
  }) async {
    final local = await _readLocalByDate(date);
    try {
      final rows = await _api.getRawList(
        '/attendance',
        queryParameters: {'date': _dateString(date)},
      );
      final records = rows.map(_toAttendanceRecord).toList();
      await _saveRecords(records, syncStatus: 'synced');
      return Result.ok(records);
    } on Object catch (error) {
      if (local.isNotEmpty) return Result.ok(local);
      return Result.err(failureFrom(error));
    }
  }

  @override
  Future<Result<List<AttendanceRecord>>> getAttendanceByStudent({
    required String studentId,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final local = await _readLocalByStudent(studentId);
    try {
      final rows = await _api.getStudentAttendanceRecords(studentId);
      final records = rows.map(_toAttendanceRecord).toList();
      await _saveRecords(records, syncStatus: 'synced');
      return Result.ok(records);
    } on Object catch (error) {
      if (local.isNotEmpty) return Result.ok(local);
      return Result.err(failureFrom(error));
    }
  }

  @override
  Future<Result<void>> markAttendance(List<AttendanceRecord> records) async {
    try {
      for (final record in records) {
        final localId = _localId(record);
        await _saveRecord(record, localId: localId, syncStatus: 'pending');
        final response = await _api.createRaw(
          '/attendance',
          _attendancePayload(record),
          extra: {'offlineLocalId': localId},
        );
        await _markLocalSync(
          localId,
          response['queued'] == true ? 'pending' : 'synced',
        );
      }
      return const Result.ok(null);
    } on Object catch (error) {
      return Result.err(failureFrom(error));
    }
  }

  @override
  Future<Result<void>> updateAttendanceRecord(AttendanceRecord record) async {
    final localId = _localId(record);
    try {
      await _saveRecord(record, localId: localId, syncStatus: 'pending');
      final response = await _api.updateRaw(
        '/attendance/${record.id}',
        _attendancePayload(record),
        extra: {'offlineLocalId': localId},
      );
      await _markLocalSync(
        localId,
        response['queued'] == true ? 'pending' : 'synced',
      );
      return const Result.ok(null);
    } on Object catch (error) {
      return Result.err(failureFrom(error));
    }
  }

  @override
  Future<Result<Map<String, double>>> getAttendanceSummary({
    required String className,
    required String section,
    required DateTime month,
  }) {
    return guardApi(() async {
      final students = await _api.getStudents(sectionId: section, pageSize: 20);
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

  Future<List<AttendanceRecord>> _readLocalByDate(DateTime date) async {
    final db = _offlineDatabase;
    if (db == null || _api.offlineAccountKey == 'anonymous') return const [];
    final rows = await db.localAttendanceForDate(
      _api.offlineAccountKey,
      _dateString(date),
    );
    return rows.map(_fromLocal).toList();
  }

  Future<List<AttendanceRecord>> _readLocalByStudent(String studentId) async {
    final db = _offlineDatabase;
    if (db == null || _api.offlineAccountKey == 'anonymous') return const [];
    final rows = await db.localAttendanceForStudent(
      _api.offlineAccountKey,
      studentId,
    );
    return rows.map(_fromLocal).toList();
  }

  Future<void> _saveRecords(
    List<AttendanceRecord> records, {
    required String syncStatus,
  }) async {
    for (final record in records) {
      await _saveRecord(
        record,
        localId: _localId(record),
        syncStatus: syncStatus,
      );
    }
  }

  Future<void> _saveRecord(
    AttendanceRecord record, {
    required String localId,
    required String syncStatus,
  }) async {
    final db = _offlineDatabase;
    if (db == null || _api.offlineAccountKey == 'anonymous') return;
    await db.saveAttendanceRecord(
      accountKey: _api.offlineAccountKey,
      localId: localId,
      serverId: record.id.isEmpty ? null : record.id,
      schoolId: _api.activeBranchId,
      studentId: record.studentId,
      studentName: record.studentName,
      className: record.className,
      section: record.section,
      date: _dateString(record.date),
      status: record.status,
      remarks: record.remarks ?? '',
      markedBy: record.markedBy,
      markedAt: record.markedAt,
      updatedAt: record.markedAt,
      syncStatus: syncStatus,
    );
  }

  Future<void> _markLocalSync(String localId, String status) async {
    final db = _offlineDatabase;
    if (db == null || _api.offlineAccountKey == 'anonymous') return;
    await db.updateAttendanceSyncStatus(
      _api.offlineAccountKey,
      localId,
      status,
    );
  }

  String _localId(AttendanceRecord record) {
    if (record.id.trim().isNotEmpty) return record.id;
    return 'local-attendance-${record.studentId}-${_dateString(record.date)}';
  }

  AttendanceRecord _fromLocal(LocalAttendanceRecord row) {
    return AttendanceRecord(
      id: row.serverId ?? row.localId,
      studentId: row.studentId,
      studentName: row.studentName,
      className: row.className,
      section: row.section,
      date: DateTime.tryParse(row.date) ?? DateTime.now(),
      status: row.attendanceStatus,
      remarks: row.remarks,
      markedBy: row.markedBy,
      markedAt: row.markedAt,
    );
  }
}
