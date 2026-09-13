import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'offline_database.g.dart';

/// Durable HTTP read models. The account key is part of every cache row so a
/// parent, teacher, or branch can never read another scope's cached response.
class CachedResponses extends Table {
  TextColumn get cacheKey => text()();
  TextColumn get accountKey => text()();
  TextColumn get method => text().withDefault(const Constant('GET'))();
  TextColumn get path => text()();
  TextColumn get queryJson => text().withDefault(const Constant('{}'))();
  TextColumn get bodyJson => text()();
  IntColumn get statusCode => integer().withDefault(const Constant(200))();
  DateTimeColumn get storedAt => dateTime()();
  DateTimeColumn get expiresAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {cacheKey};
}

/// Mutations that are safe to replay after a transport failure.
class SyncOutboxEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get accountKey => text()();
  TextColumn get operationType => text()();
  TextColumn get method => text()();
  TextColumn get path => text()();
  TextColumn get queryJson => text().withDefault(const Constant('{}'))();
  TextColumn get payloadJson => text()();
  TextColumn get idempotencyKey => text()();
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  TextColumn get lastError => text().nullable()();
  DateTimeColumn get nextAttemptAt => dateTime().nullable()();
}

class SyncStates extends Table {
  TextColumn get accountKey => text()();
  TextColumn get status => text().withDefault(const Constant('idle'))();
  DateTimeColumn get lastAttemptAt => dateTime().nullable()();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  TextColumn get lastError => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {accountKey};
}

class SyncReferences extends Table {
  TextColumn get placeholder => text()();
  TextColumn get accountKey => text()();
  TextColumn get referenceType => text()();
  TextColumn get remoteId => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {accountKey, placeholder};
}

class LocalFileUploads extends Table {
  TextColumn get localId => text()();
  TextColumn get accountKey => text()();
  TextColumn get method => text().withDefault(const Constant('POST'))();
  TextColumn get path => text()();
  TextColumn get fieldsJson => text().withDefault(const Constant('{}'))();
  TextColumn get fieldName => text()();
  TextColumn get fileName => text()();
  TextColumn get mimeType => text().nullable()();
  TextColumn get filePath => text().nullable()();
  BlobColumn get fileBytes => blob().nullable()();
  TextColumn get placeholder => text()();
  TextColumn get idempotencyKey => text()();
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  TextColumn get lastError => text().nullable()();
  DateTimeColumn get nextAttemptAt => dateTime().nullable()();
  TextColumn get remoteUrl => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {localId, accountKey};
}

/// Typed attendance data used by the teacher workflow. Other read models can
/// be promoted from [CachedResponses] into typed tables without changing the
/// UI or repository contracts.
class LocalAttendanceRecords extends Table {
  TextColumn get localId => text()();
  TextColumn get accountKey => text()();
  TextColumn get serverId => text().nullable()();
  TextColumn get schoolId => text().nullable()();
  TextColumn get studentId => text()();
  TextColumn get studentName => text().withDefault(const Constant(''))();
  TextColumn get className => text().withDefault(const Constant(''))();
  TextColumn get section => text().withDefault(const Constant(''))();
  TextColumn get date => text()();
  TextColumn get attendanceStatus => text()();
  TextColumn get remarks => text().withDefault(const Constant(''))();
  TextColumn get markedBy => text().nullable()();
  DateTimeColumn get markedAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  DateTimeColumn get localUpdatedAt => dateTime()();
  TextColumn get syncStatus => text().withDefault(const Constant('synced'))();
  IntColumn get serverVersion => integer().nullable()();
  TextColumn get rawJson => text().withDefault(const Constant('{}'))();

  @override
  Set<Column<Object>> get primaryKey => {accountKey, localId};
}

class LocalAttendanceSessions extends Table {
  TextColumn get localId => text()();
  TextColumn get accountKey => text()();
  TextColumn get serverId => text().nullable()();
  TextColumn get sectionId => text()();
  TextColumn get academicYearId => text()();
  TextColumn get subjectId => text().withDefault(const Constant(''))();
  TextColumn get staffId => text().withDefault(const Constant(''))();
  TextColumn get date => text()();
  IntColumn get periodNumber => integer().withDefault(const Constant(1))();
  TextColumn get timetableSlotId => text().withDefault(const Constant(''))();
  TextColumn get status => text().withDefault(const Constant('draft'))();
  BoolColumn get isFinalized => boolean().withDefault(const Constant(false))();
  TextColumn get studentAttendancesJson =>
      text().withDefault(const Constant('[]'))();
  DateTimeColumn get localUpdatedAt => dateTime()();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();

  @override
  Set<Column<Object>> get primaryKey => {accountKey, localId};
}

class LocalStudents extends Table {
  TextColumn get serverId => text()();
  TextColumn get accountKey => text()();
  TextColumn get schoolId => text().nullable()();
  TextColumn get fullName => text()();
  TextColumn get sectionId => text().nullable()();
  TextColumn get className => text().withDefault(const Constant(''))();
  TextColumn get sectionName => text().withDefault(const Constant(''))();
  TextColumn get status => text().withDefault(const Constant('active'))();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  DateTimeColumn get localUpdatedAt => dateTime()();
  IntColumn get serverVersion => integer().nullable()();
  TextColumn get rawJson => text().withDefault(const Constant('{}'))();

  @override
  Set<Column<Object>> get primaryKey => {accountKey, serverId};
}

class LocalHomeworkDrafts extends Table {
  TextColumn get localId => text()();
  TextColumn get accountKey => text()();
  TextColumn get serverId => text().nullable()();
  TextColumn get title => text()();
  TextColumn get subject => text().withDefault(const Constant(''))();
  TextColumn get className => text().withDefault(const Constant(''))();
  TextColumn get sectionId => text()();
  TextColumn get teacherId => text().withDefault(const Constant(''))();
  TextColumn get description => text().withDefault(const Constant(''))();
  TextColumn get dueDate => text().withDefault(const Constant(''))();
  TextColumn get studentId => text().withDefault(const Constant(''))();
  TextColumn get attachmentUrl => text().withDefault(const Constant(''))();
  TextColumn get status => text().withDefault(const Constant('draft'))();
  DateTimeColumn get localUpdatedAt => dateTime()();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();
  TextColumn get rawJson => text().withDefault(const Constant('{}'))();

  @override
  Set<Column<Object>> get primaryKey => {accountKey, localId};
}

@DriftDatabase(
  tables: [
    CachedResponses,
    SyncOutboxEntries,
    SyncStates,
    SyncReferences,
    LocalFileUploads,
    LocalAttendanceRecords,
    LocalAttendanceSessions,
    LocalStudents,
    LocalHomeworkDrafts,
  ],
)
class OfflineDatabase extends _$OfflineDatabase {
  OfflineDatabase(super.executor);

  OfflineDatabase.defaults()
    : super(
        driftDatabase(
          name: 'schooldesk_offline',
          web: DriftWebOptions(
            sqlite3Wasm: Uri.parse('sqlite3.wasm'),
            driftWorker: Uri.parse('drift_worker.js'),
          ),
          native: const DriftNativeOptions(shareAcrossIsolates: true),
        ),
      );

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) await m.createTable(localFileUploads);
      if (from < 3) {
        await m.createTable(syncReferences);
        await m.createTable(localAttendanceSessions);
      }
      if (from < 4) await m.createTable(localHomeworkDrafts);
    },
  );

  Future<void> saveCachedResponse({
    required String cacheKey,
    required String accountKey,
    required String method,
    required String path,
    required Map<String, dynamic> queryParameters,
    required Object? body,
    required int statusCode,
    required DateTime storedAt,
    DateTime? expiresAt,
  }) async {
    await into(cachedResponses).insertOnConflictUpdate(
      CachedResponsesCompanion.insert(
        cacheKey: cacheKey,
        accountKey: accountKey,
        method: Value(method),
        path: path,
        queryJson: Value(jsonEncode(queryParameters)),
        bodyJson: jsonEncode(body),
        statusCode: Value(statusCode),
        storedAt: storedAt,
        expiresAt: Value(expiresAt),
      ),
    );
  }

  Future<CachedResponse?> findCachedResponse(String cacheKey) {
    return (select(
      cachedResponses,
    )..where((row) => row.cacheKey.equals(cacheKey))).getSingleOrNull();
  }

  Future<int> enqueueMutation({
    required String accountKey,
    required String operationType,
    required String method,
    required String path,
    required Map<String, dynamic> queryParameters,
    required Object? payload,
    required String idempotencyKey,
  }) {
    return into(syncOutboxEntries).insert(
      SyncOutboxEntriesCompanion.insert(
        accountKey: accountKey,
        operationType: operationType,
        method: method,
        path: path,
        queryJson: Value(jsonEncode(queryParameters)),
        payloadJson: jsonEncode(payload),
        idempotencyKey: idempotencyKey,
        createdAt: DateTime.now().toUtc(),
      ),
    );
  }

  Stream<int> watchPendingMutationCount(String accountKey) {
    final query = select(syncOutboxEntries)
      ..where((row) {
        return row.accountKey.equals(accountKey) & row.status.equals('pending');
      });
    return query.watch().map((rows) => rows.length);
  }

  Future<List<SyncOutboxEntry>> pendingMutations(String accountKey) {
    final query = select(syncOutboxEntries)
      ..where((row) {
        return row.accountKey.equals(accountKey) &
            row.status.equals('pending') &
            (row.nextAttemptAt.isNull() |
                row.nextAttemptAt.isSmallerOrEqualValue(DateTime.now()));
      })
      ..orderBy([
        (row) => OrderingTerm(expression: row.createdAt),
        (row) => OrderingTerm(expression: row.id),
      ]);
    return query.get();
  }

  Future<void> markMutationRetry(
    int id, {
    required int retryCount,
    required String error,
    required DateTime nextAttemptAt,
  }) async {
    await (update(syncOutboxEntries)..where((row) => row.id.equals(id))).write(
      SyncOutboxEntriesCompanion(
        retryCount: Value(retryCount),
        lastError: Value(error),
        nextAttemptAt: Value(nextAttemptAt),
      ),
    );
  }

  Future<void> markMutationFailed(int id, String error) async {
    await (update(syncOutboxEntries)..where((row) => row.id.equals(id))).write(
      SyncOutboxEntriesCompanion(
        status: const Value('failed'),
        lastError: Value(error),
      ),
    );
  }

  Future<void> deleteMutation(int id) async {
    await (delete(syncOutboxEntries)..where((row) => row.id.equals(id))).go();
  }

  Future<void> saveSyncReference({
    required String accountKey,
    required String placeholder,
    required String referenceType,
    required String remoteId,
  }) async {
    await into(syncReferences).insertOnConflictUpdate(
      SyncReferencesCompanion.insert(
        placeholder: placeholder,
        accountKey: accountKey,
        referenceType: referenceType,
        remoteId: remoteId,
        createdAt: DateTime.now().toUtc(),
      ),
    );
  }

  Future<String?> findSyncReference(
    String accountKey,
    String placeholder,
  ) async {
    final row =
        await (select(syncReferences)..where((entry) {
              return entry.accountKey.equals(accountKey) &
                  entry.placeholder.equals(placeholder);
            }))
            .getSingleOrNull();
    return row?.remoteId;
  }

  Future<List<SyncReference>> syncReferencesForAccount(String accountKey) {
    return (select(
      syncReferences,
    )..where((entry) => entry.accountKey.equals(accountKey))).get();
  }

  Future<void> saveSyncState(
    String accountKey, {
    required String status,
    DateTime? lastAttemptAt,
    DateTime? lastSyncedAt,
    String? lastError,
  }) async {
    await into(syncStates).insertOnConflictUpdate(
      SyncStatesCompanion.insert(
        accountKey: accountKey,
        status: Value(status),
        lastAttemptAt: Value(lastAttemptAt),
        lastSyncedAt: Value(lastSyncedAt),
        lastError: Value(lastError),
      ),
    );
  }

  Future<SyncState?> findSyncState(String accountKey) {
    return (select(
      syncStates,
    )..where((row) => row.accountKey.equals(accountKey))).getSingleOrNull();
  }

  Future<void> enqueueFileUpload({
    required String localId,
    required String accountKey,
    required String method,
    required String path,
    required Map<String, dynamic> fields,
    required String fieldName,
    required String fileName,
    String? mimeType,
    String? filePath,
    Uint8List? fileBytes,
    required String placeholder,
    required String idempotencyKey,
  }) async {
    await into(localFileUploads).insertOnConflictUpdate(
      LocalFileUploadsCompanion.insert(
        localId: localId,
        accountKey: accountKey,
        method: Value(method),
        path: path,
        fieldsJson: Value(jsonEncode(fields)),
        fieldName: fieldName,
        fileName: fileName,
        mimeType: Value(mimeType),
        filePath: Value(filePath),
        fileBytes: Value(fileBytes),
        placeholder: placeholder,
        idempotencyKey: idempotencyKey,
        createdAt: DateTime.now().toUtc(),
      ),
    );
  }

  Future<List<LocalFileUpload>> pendingFileUploads(String accountKey) {
    final query = select(localFileUploads)
      ..where((row) {
        return row.accountKey.equals(accountKey) &
            row.status.equals('pending') &
            (row.nextAttemptAt.isNull() |
                row.nextAttemptAt.isSmallerOrEqualValue(DateTime.now()));
      })
      ..orderBy([
        (row) => OrderingTerm(expression: row.createdAt),
        (row) => OrderingTerm(expression: row.localId),
      ]);
    return query.get();
  }

  Future<List<LocalFileUpload>> syncedFileUploads(String accountKey) {
    return (select(localFileUploads)..where((row) {
          return row.accountKey.equals(accountKey) &
              row.status.equals('synced') &
              row.remoteUrl.isNotNull();
        }))
        .get();
  }

  Future<int> pendingWorkCount(String accountKey) async {
    final mutations =
        await (select(syncOutboxEntries)..where((row) {
              return row.accountKey.equals(accountKey) &
                  (row.status.equals('pending') | row.status.equals('failed'));
            }))
            .get();
    final uploads =
        await (select(localFileUploads)..where((row) {
              return row.accountKey.equals(accountKey) &
                  (row.status.equals('pending') | row.status.equals('failed'));
            }))
            .get();
    return mutations.length + uploads.length;
  }

  Future<void> markFileUploadRetry(
    String localId, {
    required String accountKey,
    required int retryCount,
    required String error,
    required DateTime nextAttemptAt,
  }) async {
    await (update(localFileUploads)..where((row) {
          return row.localId.equals(localId) &
              row.accountKey.equals(accountKey);
        }))
        .write(
          LocalFileUploadsCompanion(
            retryCount: Value(retryCount),
            lastError: Value(error),
            nextAttemptAt: Value(nextAttemptAt),
          ),
        );
  }

  Future<void> markFileUploadFailed(
    String localId,
    String accountKey,
    String error,
  ) async {
    await (update(localFileUploads)..where((row) {
          return row.localId.equals(localId) &
              row.accountKey.equals(accountKey);
        }))
        .write(
          LocalFileUploadsCompanion(
            status: const Value('failed'),
            lastError: Value(error),
          ),
        );
  }

  Future<void> markFileUploadSynced(
    String localId,
    String accountKey,
    String remoteUrl,
  ) async {
    await (update(localFileUploads)..where((row) {
          return row.localId.equals(localId) &
              row.accountKey.equals(accountKey);
        }))
        .write(
          LocalFileUploadsCompanion(
            status: const Value('synced'),
            remoteUrl: Value(remoteUrl),
            lastError: const Value(null),
            nextAttemptAt: const Value(null),
          ),
        );
  }

  Future<void> saveAttendanceRecord({
    required String accountKey,
    required String localId,
    String? serverId,
    String? schoolId,
    required String studentId,
    required String studentName,
    required String className,
    required String section,
    required String date,
    required String status,
    String remarks = '',
    String? markedBy,
    DateTime? markedAt,
    DateTime? updatedAt,
    required String syncStatus,
    int? serverVersion,
    Map<String, dynamic> rawJson = const {},
  }) async {
    await into(localAttendanceRecords).insertOnConflictUpdate(
      LocalAttendanceRecordsCompanion.insert(
        localId: localId,
        accountKey: accountKey,
        serverId: Value(serverId),
        schoolId: Value(schoolId),
        studentId: studentId,
        studentName: Value(studentName),
        className: Value(className),
        section: Value(section),
        date: date,
        attendanceStatus: status,
        remarks: Value(remarks),
        markedBy: Value(markedBy),
        markedAt: Value(markedAt),
        updatedAt: Value(updatedAt),
        localUpdatedAt: DateTime.now().toUtc(),
        syncStatus: Value(syncStatus),
        serverVersion: Value(serverVersion),
        rawJson: Value(jsonEncode(rawJson)),
      ),
    );
  }

  Future<void> updateAttendanceSyncStatus(
    String accountKey,
    String localId,
    String syncStatus,
  ) async {
    await (update(localAttendanceRecords)..where((row) {
          return row.accountKey.equals(accountKey) &
              row.localId.equals(localId);
        }))
        .write(
          LocalAttendanceRecordsCompanion(
            syncStatus: Value(syncStatus),
            localUpdatedAt: Value(DateTime.now().toUtc()),
          ),
        );
  }

  Future<void> saveAttendanceSession({
    required String accountKey,
    required String localId,
    String? serverId,
    required String sectionId,
    required String academicYearId,
    String subjectId = '',
    String staffId = '',
    required String date,
    int periodNumber = 1,
    String timetableSlotId = '',
    String status = 'draft',
    bool isFinalized = false,
    List<Map<String, dynamic>> studentAttendances = const [],
    required String syncStatus,
  }) async {
    await into(localAttendanceSessions).insertOnConflictUpdate(
      LocalAttendanceSessionsCompanion.insert(
        localId: localId,
        accountKey: accountKey,
        serverId: Value(serverId),
        sectionId: sectionId,
        academicYearId: academicYearId,
        subjectId: Value(subjectId),
        staffId: Value(staffId),
        date: date,
        periodNumber: Value(periodNumber),
        timetableSlotId: Value(timetableSlotId),
        status: Value(status),
        isFinalized: Value(isFinalized),
        studentAttendancesJson: Value(jsonEncode(studentAttendances)),
        localUpdatedAt: DateTime.now().toUtc(),
        syncStatus: Value(syncStatus),
      ),
    );
  }

  Future<List<LocalAttendanceSession>> localAttendanceSessionsFor(
    String accountKey, {
    String? sectionId,
    String? date,
  }) {
    final query = select(localAttendanceSessions)
      ..where((row) {
        var expression = row.accountKey.equals(accountKey);
        if (sectionId != null && sectionId.isNotEmpty) {
          expression = expression & row.sectionId.equals(sectionId);
        }
        if (date != null && date.isNotEmpty) {
          expression = expression & row.date.equals(date);
        }
        return expression;
      })
      ..orderBy([
        (row) => OrderingTerm(
          expression: row.localUpdatedAt,
          mode: OrderingMode.desc,
        ),
      ]);
    return query.get();
  }

  Future<void> updateAttendanceSession({
    required String accountKey,
    required String localId,
    String? serverId,
    List<Map<String, dynamic>>? studentAttendances,
    String? status,
    bool? isFinalized,
    required String syncStatus,
  }) async {
    await (update(localAttendanceSessions)..where((row) {
          return row.accountKey.equals(accountKey) &
              row.localId.equals(localId);
        }))
        .write(
          LocalAttendanceSessionsCompanion(
            serverId: serverId == null ? const Value.absent() : Value(serverId),
            studentAttendancesJson: studentAttendances == null
                ? const Value.absent()
                : Value(jsonEncode(studentAttendances)),
            status: status == null ? const Value.absent() : Value(status),
            isFinalized: isFinalized == null
                ? const Value.absent()
                : Value(isFinalized),
            syncStatus: Value(syncStatus),
            localUpdatedAt: Value(DateTime.now().toUtc()),
          ),
        );
  }

  Future<void> updateAttendanceSessionRemoteId({
    required String accountKey,
    required String localId,
    required String remoteId,
  }) async {
    await (update(localAttendanceSessions)..where((row) {
          return row.accountKey.equals(accountKey) &
              row.localId.equals(localId);
        }))
        .write(
          LocalAttendanceSessionsCompanion(
            serverId: Value(remoteId),
            localUpdatedAt: Value(DateTime.now().toUtc()),
          ),
        );
  }

  Future<List<LocalAttendanceRecord>> localAttendanceForDate(
    String accountKey,
    String date,
  ) {
    return (select(localAttendanceRecords)
          ..where((row) {
            return row.accountKey.equals(accountKey) & row.date.equals(date);
          })
          ..orderBy([(row) => OrderingTerm(expression: row.studentName)]))
        .get();
  }

  Future<List<LocalAttendanceRecord>> localAttendanceForStudent(
    String accountKey,
    String studentId,
  ) {
    return (select(localAttendanceRecords)
          ..where((row) {
            return row.accountKey.equals(accountKey) &
                row.studentId.equals(studentId);
          })
          ..orderBy([
            (row) =>
                OrderingTerm(expression: row.date, mode: OrderingMode.desc),
          ]))
        .get();
  }

  Future<void> saveStudentSnapshot({
    required String accountKey,
    required String serverId,
    String? schoolId,
    required String fullName,
    String? sectionId,
    String className = '',
    String sectionName = '',
    String status = 'active',
    DateTime? updatedAt,
    int? serverVersion,
    Map<String, dynamic> rawJson = const {},
  }) async {
    await into(localStudents).insertOnConflictUpdate(
      LocalStudentsCompanion.insert(
        serverId: serverId,
        accountKey: accountKey,
        schoolId: Value(schoolId),
        fullName: fullName,
        sectionId: Value(sectionId),
        className: Value(className),
        sectionName: Value(sectionName),
        status: Value(status),
        updatedAt: Value(updatedAt),
        localUpdatedAt: DateTime.now().toUtc(),
        serverVersion: Value(serverVersion),
        rawJson: Value(jsonEncode(rawJson)),
      ),
    );
  }

  Future<List<LocalStudent>> localStudentsForAccount(String accountKey) {
    return (select(localStudents)
          ..where((row) => row.accountKey.equals(accountKey))
          ..orderBy([(row) => OrderingTerm(expression: row.fullName)]))
        .get();
  }

  Future<void> saveHomeworkDraft({
    required String accountKey,
    required String localId,
    String? serverId,
    required String title,
    String subject = '',
    String className = '',
    required String sectionId,
    String teacherId = '',
    String description = '',
    String dueDate = '',
    String studentId = '',
    String attachmentUrl = '',
    String status = 'draft',
    required String syncStatus,
    Map<String, dynamic> rawJson = const {},
  }) async {
    await into(localHomeworkDrafts).insertOnConflictUpdate(
      LocalHomeworkDraftsCompanion.insert(
        localId: localId,
        accountKey: accountKey,
        serverId: Value(serverId),
        title: title,
        subject: Value(subject),
        className: Value(className),
        sectionId: sectionId,
        teacherId: Value(teacherId),
        description: Value(description),
        dueDate: Value(dueDate),
        studentId: Value(studentId),
        attachmentUrl: Value(attachmentUrl),
        status: Value(status),
        localUpdatedAt: DateTime.now().toUtc(),
        syncStatus: Value(syncStatus),
        rawJson: Value(jsonEncode(rawJson)),
      ),
    );
  }

  Future<List<LocalHomeworkDraft>> localHomeworkDraftsForAccount(
    String accountKey, {
    String? sectionId,
    String? studentId,
    String? status,
  }) {
    final query = select(localHomeworkDrafts)
      ..where((row) {
        var expression = row.accountKey.equals(accountKey);
        if (sectionId != null && sectionId.isNotEmpty) {
          expression = expression & row.sectionId.equals(sectionId);
        }
        if (studentId != null && studentId.isNotEmpty) {
          expression = expression & row.studentId.equals(studentId);
        }
        if (status != null && status.isNotEmpty) {
          expression = expression & row.status.equals(status);
        }
        return expression;
      })
      ..orderBy([
        (row) => OrderingTerm(
          expression: row.localUpdatedAt,
          mode: OrderingMode.desc,
        ),
      ]);
    return query.get();
  }

  Future<void> updateHomeworkDraftSyncStatus({
    required String accountKey,
    required String localId,
    required String syncStatus,
    String? serverId,
  }) async {
    await (update(localHomeworkDrafts)..where((row) {
          return row.accountKey.equals(accountKey) &
              row.localId.equals(localId);
        }))
        .write(
          LocalHomeworkDraftsCompanion(
            serverId: serverId == null ? const Value.absent() : Value(serverId),
            syncStatus: Value(syncStatus),
            localUpdatedAt: Value(DateTime.now().toUtc()),
          ),
        );
  }
}
