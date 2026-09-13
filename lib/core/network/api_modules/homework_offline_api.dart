part of '../backend_api_client.dart';

bool _homeworkNeedsOfflineDraft(String attachmentUrl) {
  return attachmentUrl
      .split(',')
      .map((value) => value.trim())
      .any((value) => value.startsWith('schooldesk-upload://'));
}

extension BackendHomeworkOfflineApi on BackendApiClient {
  Future<void> _saveLocalHomeworkDraft({
    required String localId,
    String? serverId,
    required String title,
    required String subject,
    required String className,
    required String sectionId,
    required String teacherId,
    required String description,
    required String dueDate,
    required String studentId,
    required String attachmentUrl,
    required String status,
    required String syncStatus,
  }) async {
    final sync = offlineSync;
    if (sync == null || offlineAccountKey == 'anonymous') return;
    await sync.database.saveHomeworkDraft(
      accountKey: offlineAccountKey,
      localId: localId,
      serverId: serverId,
      title: title,
      subject: subject,
      className: className,
      sectionId: sectionId,
      teacherId: teacherId,
      description: description,
      dueDate: dueDate,
      studentId: studentId,
      attachmentUrl: attachmentUrl,
      status: status,
      syncStatus: syncStatus,
      rawJson: {
        'id': serverId ?? localId,
        'homework_id': serverId ?? localId,
        'title': title,
        'subject': subject,
        'subject_id': subject,
        'class': className,
        'class_id': className,
        'section_id': sectionId,
        'staff_id': teacherId,
        'student_id': studentId,
        'description': description,
        'submission_date': dueDate,
        'attachment_url': attachmentUrl,
        'status': status,
        '_offline_pending': syncStatus != 'synced',
      },
    );
  }

  Future<void> _markLocalHomeworkDraftSynced(
    String localId,
    String? serverId,
  ) async {
    final sync = offlineSync;
    if (sync == null || offlineAccountKey == 'anonymous') return;
    await sync.database.updateHomeworkDraftSyncStatus(
      accountKey: offlineAccountKey,
      localId: localId,
      syncStatus: 'synced',
      serverId: serverId,
    );
  }

  Future<void> _markLocalHomeworkDraftFailed(String localId) async {
    final sync = offlineSync;
    if (sync == null || offlineAccountKey == 'anonymous') return;
    await sync.database.updateHomeworkDraftSyncStatus(
      accountKey: offlineAccountKey,
      localId: localId,
      syncStatus: 'failed',
    );
  }

  Future<List<Map<String, dynamic>>> _mergeLocalHomeworkDrafts(
    List<Map<String, dynamic>> remote, {
    String? sectionId,
    String? studentId,
    String? status,
  }) async {
    final sync = offlineSync;
    if (sync == null || offlineAccountKey == 'anonymous') return remote;
    final local = await sync.database.localHomeworkDraftsForAccount(
      offlineAccountKey,
      sectionId: sectionId,
      studentId: studentId,
      status: status,
    );
    if (local.isEmpty) return remote;
    final remoteIds = remote
        .map((row) => '${row['id'] ?? row['homework_id'] ?? ''}')
        .where((id) => id.trim().isNotEmpty)
        .toSet();
    final drafts = local
        .map((row) {
          Map<String, dynamic> decoded;
          try {
            final raw = jsonDecode(row.rawJson);
            decoded = raw is Map
                ? Map<String, dynamic>.from(raw)
                : <String, dynamic>{};
          } on Object {
            decoded = <String, dynamic>{};
          }
          decoded.addAll({
            'id': row.serverId ?? row.localId,
            'homework_id': row.serverId ?? row.localId,
            'title': row.title,
            'subject': row.subject,
            'class': row.className,
            'section_id': row.sectionId,
            'staff_id': row.teacherId,
            'student_id': row.studentId,
            'description': row.description,
            'submission_date': row.dueDate,
            'attachment_url': row.attachmentUrl,
            'status': row.status,
            '_offline_pending': row.syncStatus != 'synced',
            '_offline_sync_status': row.syncStatus,
          });
          return decoded;
        })
        .where((row) {
          final id = '${row['id'] ?? row['homework_id'] ?? ''}';
          return !remoteIds.contains(id);
        });
    return [...remote, ...drafts];
  }

  Future<List<Map<String, dynamic>>> _readLocalHomeworkDrafts({
    String? sectionId,
    String? studentId,
    String? status,
  }) async {
    return _mergeLocalHomeworkDrafts(
      const [],
      sectionId: sectionId,
      studentId: studentId,
      status: status,
    );
  }
}
