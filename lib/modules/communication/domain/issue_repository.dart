import 'package:schooldesk1/core/network/models/backend_models.dart';

abstract interface class IssueRepository {
  Future<PaginatedList<Map<String, dynamic>>> loadPage({
    String? status,
    String? search,
    int page = 1,
    int pageSize = 20,
  });

  Future<Map<String, dynamic>> createWithAttachments(
    Map<String, dynamic> payload,
    List<Map<String, dynamic>> files,
  );

  Future<Map<String, dynamic>> updateIssue(
    String issueId, {
    required String status,
    String resolutionNote = '',
  });

  Future<String> loadAttachmentUrl(String issueId, String attachmentId);
}
