import 'package:schooldesk1/core/utils/result.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/features/shared/domain/entities/notice.dart';
import 'package:schooldesk1/features/shared/domain/repositories/notice_repository.dart';
import 'package:schooldesk1/features/shared/data/repositories/api_repository_utils.dart';

class ApiNoticeRepository implements NoticeRepository {
  ApiNoticeRepository(this._api);

  final BackendApiClient _api;

  @override
  Future<Result<List<Notice>>> getNotices({
    String? targetAudience,
    String? type,
    bool? isPublished,
  }) {
    return guardApi(() async {
      final notices = await _api.getAnnouncements();
      return notices
          .where((notice) {
            final target = textValue(targetAudience).toLowerCase();
            return target.isEmpty ||
                notice.targetAudience.toLowerCase() == target ||
                notice.targetAudience.toLowerCase() == 'all';
          })
          .map(_toNotice)
          .toList();
    });
  }

  @override
  Future<Result<Notice>> getNoticeById(String id) {
    return guardApi(
      () async => _noticeFromMap(await _api.getRawMap('/announcements/$id')),
    );
  }

  @override
  Future<Result<Notice>> createNotice(Notice notice) {
    return guardApi(() async {
      await _api.createAnnouncement(
        title: notice.title,
        content: notice.content,
        targetAudience: notice.targetAudience.toLowerCase(),
        isUrgent: notice.isUrgent,
      );
      return notice;
    });
  }

  @override
  Future<Result<Notice>> updateNotice(Notice notice) {
    return guardApi(() async {
      final row = await _api.updateRaw('/announcements/${notice.id}', {
        'title': notice.title,
        'content': notice.content,
        'target_audience': notice.targetAudience.toLowerCase(),
        'is_urgent': notice.isUrgent,
        'is_published': notice.isPublished,
      });
      return _noticeFromMap(row);
    });
  }

  @override
  Future<Result<void>> deleteNotice(String id) {
    return guardApi(() => _api.deleteRaw('/announcements/$id'));
  }

  @override
  Future<Result<void>> markNoticeAsRead({
    required String noticeId,
    required String userId,
  }) {
    return guardApi(() async {
      await _api.createRaw('/notice-acknowledgements', {
        'notice_id': noticeId,
        'user_id': userId,
        'read_at': DateTime.now().toIso8601String(),
      });
    });
  }

  @override
  Future<Result<void>> publishNotice(String id) {
    return guardApi(() async {
      await _api.updateRaw('/announcements/$id', {'is_published': true});
    });
  }

  Notice _toNotice(AnnouncementModel model) {
    return Notice(
      id: model.id,
      title: model.title,
      content: model.content,
      type: 'General',
      targetAudience: model.targetAudience,
      publishedBy: model.createdBy,
      publishedByRole: '',
      publishedAt: parseDate(model.publishedAt, fallback: DateTime.now()),
      isUrgent: model.isUrgent,
      isPublished: true,
    );
  }

  Notice _noticeFromMap(Map<String, dynamic> row) {
    return Notice(
      id: textValue(row['id']),
      title: textValue(row['title']),
      content: textValue(row['content'] ?? row['body']),
      type: textValue(row['type']).isEmpty ? 'General' : textValue(row['type']),
      targetAudience: textValue(row['target_audience']).isEmpty
          ? 'all'
          : textValue(row['target_audience']),
      publishedBy: textValue(row['created_by'] ?? row['published_by']),
      publishedByRole: textValue(row['published_by_role']),
      publishedAt: parseDate(row['published_at'], fallback: DateTime.now()),
      expiresAt: DateTime.tryParse(textValue(row['expires_at'])),
      isUrgent: row['is_urgent'] as bool? ?? false,
      isPublished: row['is_published'] as bool? ?? true,
    );
  }
}
