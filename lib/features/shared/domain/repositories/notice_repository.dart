import 'package:schooldesk1/features/shared/domain/entities/notice.dart';
import 'package:schooldesk1/core/utils/result.dart';

/// Abstract repository interface for notice/circular operations.
abstract class NoticeRepository {
  Future<Result<List<Notice>>> getNotices({
    String? targetAudience,
    String? type,
    bool? isPublished,
  });

  Future<Result<Notice>> getNoticeById(String id);

  Future<Result<Notice>> createNotice(Notice notice);

  Future<Result<Notice>> updateNotice(Notice notice);

  Future<Result<void>> deleteNotice(String id);

  Future<Result<void>> markNoticeAsRead({
    required String noticeId,
    required String userId,
  });

  Future<Result<void>> publishNotice(String id);
}
