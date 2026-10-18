import 'package:drift/drift.dart';
import 'package:schooldesk1/core/offline/offline_database.dart';

/// Durable drafts are keyed by the complete account/branch/role scope and
/// conversation (or contact/student key before a conversation exists).
class ChatDraftStore {
  ChatDraftStore(this.database);

  final OfflineDatabase database;

  Future<String> read(String accountKey, String threadKey) async {
    if (!_valid(accountKey, threadKey)) return '';
    final row =
        await (database.select(database.localChatDrafts)..where(
              (row) =>
                  row.accountKey.equals(accountKey) &
                  row.threadKey.equals(threadKey),
            ))
            .getSingleOrNull();
    return row?.body ?? '';
  }

  Future<void> write(String accountKey, String threadKey, String body) async {
    if (!_valid(accountKey, threadKey)) return;
    if (body.isEmpty) {
      await (database.delete(database.localChatDrafts)..where(
            (row) =>
                row.accountKey.equals(accountKey) &
                row.threadKey.equals(threadKey),
          ))
          .go();
      return;
    }
    await database
        .into(database.localChatDrafts)
        .insertOnConflictUpdate(
          LocalChatDraftsCompanion.insert(
            accountKey: accountKey,
            threadKey: threadKey,
            body: body,
            updatedAt: DateTime.now().toUtc(),
          ),
        );
  }

  bool _valid(String accountKey, String threadKey) =>
      accountKey.trim().isNotEmpty &&
      accountKey != 'anonymous' &&
      threadKey.trim().isNotEmpty;
}
