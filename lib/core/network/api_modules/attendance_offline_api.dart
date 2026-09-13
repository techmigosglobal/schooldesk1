part of '../backend_api_client.dart';

extension BackendAttendanceOfflineApi on BackendApiClient {
  Future<List<AttendanceSessionModel>> _mergeLocalAttendanceSessions(
    List<AttendanceSessionModel> remote, {
    String? sectionId,
    String? date,
  }) async {
    final local = await _readLocalAttendanceSessions(
      sectionId: sectionId,
      date: date,
    );
    if (local.isEmpty) return remote;
    final remoteIds = remote.map((session) => session.id).toSet();
    return [
      ...remote,
      ...local.where((session) => !remoteIds.contains(session.id)),
    ];
  }

  Future<List<AttendanceSessionModel>> _readLocalAttendanceSessions({
    String? sectionId,
    String? date,
  }) async {
    final sync = offlineSync;
    if (sync == null || offlineAccountKey == 'anonymous') return const [];
    final rows = await sync.database.localAttendanceSessionsFor(
      offlineAccountKey,
      sectionId: sectionId,
      date: date,
    );
    return rows.map((row) {
      final decoded = jsonDecode(row.studentAttendancesJson);
      final attendances = decoded is List
          ? decoded.whereType<Map>().map(Map<String, dynamic>.from).toList()
          : const <Map<String, dynamic>>[];
      return _localAttendanceSession(
        localId: row.serverId ?? row.localId,
        sectionId: row.sectionId,
        academicYearId: row.academicYearId,
        subjectId: row.subjectId,
        staffId: row.staffId,
        date: row.date,
        periodNumber: row.periodNumber,
        timetableSlotId: row.timetableSlotId,
        status: row.status,
        isFinalized: row.isFinalized,
        attendances: attendances,
      );
    }).toList();
  }

  Future<void> _saveLocalAttendanceSession({
    required String localId,
    required String sectionId,
    required String academicYearId,
    required String subjectId,
    required String staffId,
    required String date,
    required int periodNumber,
    required String timetableSlotId,
  }) async {
    final sync = offlineSync;
    if (sync == null || offlineAccountKey == 'anonymous') return;
    await sync.database.saveAttendanceSession(
      accountKey: offlineAccountKey,
      localId: localId,
      sectionId: sectionId,
      academicYearId: academicYearId,
      subjectId: subjectId,
      staffId: staffId,
      date: date,
      periodNumber: periodNumber,
      timetableSlotId: timetableSlotId,
      syncStatus: 'pending',
    );
  }

  Future<void> _updateLocalAttendanceSession({
    required String localId,
    required List<Map<String, dynamic>> attendances,
    required bool finalize,
    required String syncStatus,
  }) async {
    final sync = offlineSync;
    if (sync == null || offlineAccountKey == 'anonymous') return;
    await sync.database.updateAttendanceSession(
      accountKey: offlineAccountKey,
      localId: localId,
      studentAttendances: attendances,
      status: finalize ? 'submitted' : 'draft',
      isFinalized: finalize,
      syncStatus: syncStatus,
    );
  }

  AttendanceSessionModel _localAttendanceSession({
    required String localId,
    required String sectionId,
    required String academicYearId,
    required String subjectId,
    required String staffId,
    required String date,
    required int periodNumber,
    required String timetableSlotId,
    String status = 'draft',
    bool isFinalized = false,
    List<Map<String, dynamic>> attendances = const [],
  }) {
    final presentCount = attendances.where((row) {
      return '${row['status'] ?? ''}'.toLowerCase() == 'present';
    }).length;
    return AttendanceSessionModel(
      id: localId,
      sectionId: sectionId,
      timetableSlotId: timetableSlotId,
      subjectId: subjectId,
      staffId: staffId,
      date: date,
      periodNumber: periodNumber,
      totalStudents: attendances.length,
      presentCount: presentCount,
      isFinalized: isFinalized,
      status: status,
      studentAttendances: attendances,
    );
  }
}
