import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:typed_data';

import 'package:schooldesk1/core/offline/offline_database.dart';
import 'package:schooldesk1/core/offline/offline_sync_engine.dart';

void main() {
  late OfflineDatabase database;

  setUp(() {
    database = OfflineDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  test('stores account-scoped cached responses and outbox entries', () async {
    await database.saveCachedResponse(
      cacheKey: 'user-a|branch-a|teacher:/students',
      accountKey: 'user-a|branch-a|teacher',
      method: 'GET',
      path: '/students',
      queryParameters: const {},
      body: const {
        'success': true,
        'data': [
          {'id': 'student-1', 'name': 'Aarav'},
        ],
      },
      statusCode: 200,
      storedAt: DateTime.utc(2026, 9, 12),
    );

    final cached = await database.findCachedResponse(
      'user-a|branch-a|teacher:/students',
    );
    expect(cached, isNotNull);
    expect(cached!.accountKey, 'user-a|branch-a|teacher');
    expect(cached.bodyJson, contains('Aarav'));

    await database.enqueueMutation(
      accountKey: 'user-a|branch-a|teacher',
      operationType: 'attendance.submit',
      method: 'POST',
      path: '/attendance',
      queryParameters: const {},
      payload: const {
        'request': {'student_id': 'student-1', 'status': 'present'},
        'local_id': 'attendance-1',
      },
      idempotencyKey: 'idem-1',
    );

    final pending = await database.pendingMutations('user-a|branch-a|teacher');
    expect(pending, hasLength(1));
    expect(pending.single.idempotencyKey, 'idem-1');
    expect(pending.single.operationType, 'attendance.submit');
  });

  test('idempotency key is durable and scoped per account', () async {
    final first = await database.enqueueMutation(
      accountKey: 'account-a|branch-a|teacher',
      operationType: 'attendance.submit',
      method: 'POST',
      path: '/attendance',
      queryParameters: const {},
      payload: const {'local_id': 'attendance-1'},
      idempotencyKey: 'same-key',
    );
    final duplicate = await database.enqueueMutation(
      accountKey: 'account-a|branch-a|teacher',
      operationType: 'attendance.submit',
      method: 'POST',
      path: '/attendance',
      queryParameters: const {},
      payload: const {'local_id': 'attendance-1'},
      idempotencyKey: 'same-key',
    );
    final otherAccount = await database.enqueueMutation(
      accountKey: 'account-b|branch-b|teacher',
      operationType: 'attendance.submit',
      method: 'POST',
      path: '/attendance',
      queryParameters: const {},
      payload: const {'local_id': 'attendance-1'},
      idempotencyKey: 'same-key',
    );

    expect(duplicate, first);
    expect(otherAccount, isNot(first));
    expect(
      await database.pendingMutations('account-a|branch-a|teacher'),
      hasLength(1),
    );
    expect(
      await database.pendingMutations('account-b|branch-b|teacher'),
      hasLength(1),
    );
  });

  test(
    'outbox preserves order, retry backoff, permanent failure, and conflict',
    () async {
      final first = await database.enqueueMutation(
        accountKey: 'account-a|branch-a|teacher',
        operationType: 'attendance.submit',
        method: 'POST',
        path: '/attendance',
        queryParameters: const {},
        payload: const {'local_id': 'first'},
        idempotencyKey: 'first-key',
      );
      final second = await database.enqueueMutation(
        accountKey: 'account-a|branch-a|teacher',
        operationType: 'teacher-note.save',
        method: 'POST',
        path: '/diary-entries',
        queryParameters: const {},
        payload: const {'local_id': 'second'},
        idempotencyKey: 'second-key',
      );

      var pending = await database.pendingMutations(
        'account-a|branch-a|teacher',
      );
      expect(pending.map((entry) => entry.id), [first, second]);

      await database.markMutationRetry(
        first,
        retryCount: 1,
        error: 'temporary network failure',
        nextAttemptAt: DateTime.now().toUtc().add(const Duration(minutes: 1)),
      );
      pending = await database.pendingMutations('account-a|branch-a|teacher');
      expect(pending.single.id, second);

      await database.markMutationConflict(first, 'server version conflict');
      final conflicted = await (database.select(
        database.syncOutboxEntries,
      )..where((row) => row.id.equals(first))).getSingle();
      expect(conflicted.status, 'conflict');
      expect(conflicted.lastError, 'server version conflict');
      expect(await database.pendingWorkCount('account-a|branch-a|teacher'), 2);

      await database.markMutationFailed(second, 'permanent validation failure');
      expect(
        await database.pendingWorkCount('account-a|branch-a|teacher'),
        2,
      );
    },
  );

  test('outbox survives database restart', () async {
    final directory = await Directory.systemTemp.createTemp(
      'schooldesk-offline-restart-',
    );
    final file = File('${directory.path}/offline.sqlite');
    try {
      final firstDatabase = OfflineDatabase(NativeDatabase(file));
      final id = await firstDatabase.enqueueMutation(
        accountKey: 'account-a|branch-a|teacher',
        operationType: 'homework.draft',
        method: 'POST',
        path: '/homework',
        queryParameters: const {},
        payload: const {'status': 'draft', 'local_id': 'draft-1'},
        idempotencyKey: 'restart-key',
      );
      await firstDatabase.close();

      final reopened = OfflineDatabase(NativeDatabase(file));
      final pending = await reopened.pendingMutations(
        'account-a|branch-a|teacher',
      );
      expect(pending.single.id, id);
      expect(pending.single.idempotencyKey, 'restart-key');
      await reopened.close();
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('does not allow identical local ids to cross account scopes', () async {
    await database.saveAttendanceRecord(
      accountKey: 'user-a|branch-a|teacher',
      localId: 'same-server-id',
      serverId: 'same-server-id',
      studentId: 'student-a',
      studentName: 'Aarav',
      className: '5',
      section: 'A',
      date: '2026-09-12',
      status: 'present',
      syncStatus: 'synced',
    );
    await database.saveAttendanceRecord(
      accountKey: 'user-b|branch-b|teacher',
      localId: 'same-server-id',
      serverId: 'same-server-id',
      studentId: 'student-b',
      studentName: 'Riya',
      className: '5',
      section: 'B',
      date: '2026-09-12',
      status: 'absent',
      syncStatus: 'synced',
    );

    expect(
      (await database.localAttendanceForDate(
        'user-a|branch-a|teacher',
        '2026-09-12',
      )).single.studentName,
      'Aarav',
    );
    expect(
      (await database.localAttendanceForDate(
        'user-b|branch-b|teacher',
        '2026-09-12',
      )).single.studentName,
      'Riya',
    );
  });

  test(
    'stores binary uploads and resolves their durable placeholder',
    () async {
      await database.enqueueFileUpload(
        localId: 'upload-1',
        accountKey: 'user-a|branch-a|teacher',
        method: 'POST',
        path: '/uploads',
        fields: const {'folder': 'homework'},
        fieldName: 'file',
        fileName: 'homework.png',
        mimeType: 'image/png',
        fileBytes: Uint8List.fromList(const [1, 2, 3]),
        placeholder: 'schooldesk-upload://upload-1',
        idempotencyKey: 'idem-upload-1',
      );

      final pending = await database.pendingFileUploads(
        'user-a|branch-a|teacher',
      );
      expect(pending, hasLength(1));
      expect(pending.single.fileBytes, orderedEquals([1, 2, 3]));

      await database.markFileUploadSynced(
        'upload-1',
        'user-a|branch-a|teacher',
        'https://r2.example/homework.png',
      );
      final synced = await database.syncedFileUploads(
        'user-a|branch-a|teacher',
      );
      expect(synced.single.placeholder, 'schooldesk-upload://upload-1');
      expect(synced.single.remoteUrl, 'https://r2.example/homework.png');
    },
  );

  test(
    'stores local attendance sessions and server reference mappings',
    () async {
      const account = 'user-a|branch-a|teacher';
      const localId = 'schooldesk-reference-attendance-1';
      await database.saveAttendanceSession(
        accountKey: account,
        localId: localId,
        sectionId: 'section-1',
        academicYearId: 'year-1',
        subjectId: 'subject-1',
        staffId: 'staff-1',
        date: '2026-09-12',
        studentAttendances: const [
          {'student_id': 'student-1', 'status': 'present'},
        ],
        syncStatus: 'pending',
      );
      await database.saveSyncReference(
        accountKey: account,
        placeholder: localId,
        referenceType: 'attendance_session',
        remoteId: 'server-session-1',
      );

      final sessions = await database.localAttendanceSessionsFor(
        account,
        sectionId: 'section-1',
        date: '2026-09-12',
      );
      expect(sessions.single.localId, localId);
      expect(
        await database.findSyncReference(account, localId),
        'server-session-1',
      );
    },
  );

  test('stores account-scoped homework drafts for offline reads', () async {
    const account = 'user-a|branch-a|teacher';
    await database.saveHomeworkDraft(
      accountKey: account,
      localId: 'local-homework-1',
      title: 'Fractions',
      subject: 'Maths',
      className: '5',
      sectionId: 'section-1',
      teacherId: 'staff-1',
      description: 'Complete worksheet',
      dueDate: '2026-09-15',
      status: 'draft',
      syncStatus: 'pending',
      rawJson: const {'title': 'Fractions'},
    );

    final drafts = await database.localHomeworkDraftsForAccount(
      account,
      sectionId: 'section-1',
      status: 'draft',
    );
    expect(drafts.single.localId, 'local-homework-1');
    expect(drafts.single.syncStatus, 'pending');
    expect(drafts.single.rawJson, contains('Fractions'));
  });

  test('policy only queues explicitly offline-capable writes', () {
    expect(
      OfflineSyncEngine.isOfflineCapableWrite(
        RequestOptions(method: 'POST', path: '/attendance'),
      ),
      isTrue,
    );
    expect(
      OfflineSyncEngine.isOfflineCapableWrite(
        RequestOptions(method: 'POST', path: '/attendance/sessions'),
      ),
      isTrue,
    );
    expect(
      OfflineSyncEngine.isOfflineCapableWrite(
        RequestOptions(method: 'POST', path: '/approvals/123/approve'),
      ),
      isFalse,
    );
    expect(
      OfflineSyncEngine.isOfflineCapableWrite(
        RequestOptions(
          method: 'POST',
          path: '/homework',
          data: const {'status': 'draft'},
        ),
      ),
      isTrue,
    );
    expect(
      OfflineSyncEngine.isOfflineCapableWrite(
        RequestOptions(
          method: 'PUT',
          path: '/homework/homework-1',
          data: const {'status': 'draft'},
        ),
      ),
      isTrue,
    );
    expect(
      OfflineSyncEngine.isOfflineCapableWrite(
        RequestOptions(
          method: 'POST',
          path: '/homework',
          data: const {'status': 'published'},
        ),
      ),
      isFalse,
    );
    expect(
      OfflineSyncEngine.isOfflineCapableWrite(
        RequestOptions(method: 'POST', path: '/diary-entries'),
      ),
      isTrue,
    );
    expect(
      OfflineSyncEngine.isOfflineCapableWrite(
        RequestOptions(
          method: 'POST',
          path: '/chat/conversations/c-1/messages',
        ),
      ),
      isTrue,
    );
  });
}
