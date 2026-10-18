import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schooldesk1/core/offline/offline_database.dart';
import 'package:schooldesk1/core/services/chat_draft_store.dart';

void main() {
  test(
    'drafts survive reopen and remain isolated by account, branch, role, and thread',
    () async {
      final directory = await Directory.systemTemp.createTemp('chat-drafts');
      final file = File('${directory.path}/drafts.sqlite');
      var database = OfflineDatabase(NativeDatabase(file));
      var store = ChatDraftStore(database);
      await store.write('user|school-a|teacher', 'thread-1', 'First draft');
      await store.write('user|school-a|teacher', 'thread-2', 'Other thread');
      await store.write('user|school-b|teacher', 'thread-1', 'Other school');
      await store.write('user|school-a|parent', 'thread-1', 'Other role');
      await store.write(
        'other-user|school-a|teacher',
        'thread-1',
        'Other account',
      );
      await database.close();
      database = OfflineDatabase(NativeDatabase(file));
      store = ChatDraftStore(database);
      expect(
        await store.read('user|school-a|teacher', 'thread-1'),
        'First draft',
      );
      expect(
        await store.read('user|school-a|teacher', 'thread-2'),
        'Other thread',
      );
      expect(
        await store.read('user|school-b|teacher', 'thread-1'),
        'Other school',
      );
      expect(
        await store.read('user|school-a|parent', 'thread-1'),
        'Other role',
      );
      expect(
        await store.read('other-user|school-a|teacher', 'thread-1'),
        'Other account',
      );
      await store.write('user|school-a|teacher', 'thread-1', 'Changed');
      expect(await store.read('user|school-a|teacher', 'thread-1'), 'Changed');
      await store.write('user|school-a|teacher', 'thread-1', '');
      expect(await store.read('user|school-a|teacher', 'thread-1'), '');
      await database.clearAccountData('user|school-a|teacher');
      expect(await store.read('user|school-a|teacher', 'thread-2'), '');
      expect(
        await store.read('user|school-b|teacher', 'thread-1'),
        'Other school',
      );
      await database.close();
      await directory.delete(recursive: true);
    },
  );

  test(
    'version five upgrades add drafts and preserve existing offline rows',
    () async {
      final directory = await Directory.systemTemp.createTemp('chat-migration');
      final file = File('${directory.path}/offline.sqlite');
      var database = OfflineDatabase(NativeDatabase(file));
      await database.saveCachedResponse(
        cacheKey: 'cached',
        accountKey: 'account',
        method: 'GET',
        path: '/students',
        queryParameters: {},
        body: {'value': 1},
        statusCode: 200,
        storedAt: DateTime.now(),
      );
      // Recreate the exact v5 shape (v6 only adds local_chat_drafts).
      await database.customStatement('DROP TABLE local_chat_drafts');
      await database.customStatement('PRAGMA user_version = 5');
      await database.close();
      database = OfflineDatabase(NativeDatabase(file));
      final store = ChatDraftStore(database);
      await store.write('account', 'thread', 'After upgrade');
      expect(await store.read('account', 'thread'), 'After upgrade');
      expect(
        (await database.findCachedResponse('cached'))?.bodyJson,
        '{"value":1}',
      );
      await database.close();
      await directory.delete(recursive: true);
    },
  );

  test('anonymous or blank scopes never persist drafts', () async {
    final database = OfflineDatabase(NativeDatabase.memory());
    final store = ChatDraftStore(database);
    await store.write('anonymous', 'thread', 'Private');
    await store.write('', 'thread', 'Private');
    await store.write('account', '', 'Private');
    expect(await database.select(database.localChatDrafts).get(), isEmpty);
    await database.close();
  });
}
