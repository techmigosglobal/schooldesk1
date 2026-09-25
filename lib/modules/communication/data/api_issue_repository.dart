import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/modules/communication/domain/issue_repository.dart';

class ApiIssueRepository implements IssueRepository {
  ApiIssueRepository(this._api);

  final BackendApiClient _api;

  @override
  Future<PaginatedList<Map<String, dynamic>>> loadPage({
    String? status,
    String? search,
    int page = 1,
    int pageSize = 20,
  }) {
    return _api.getIssuesPage(
      status: status,
      search: search,
      page: page,
      pageSize: pageSize,
    );
  }

  @override
  Future<Map<String, dynamic>> createWithAttachments(
    Map<String, dynamic> payload,
    List<Map<String, dynamic>> files,
  ) {
    return _api.createIssueWithAttachments(payload, files);
  }

  @override
  Future<Map<String, dynamic>> updateIssue(
    String issueId, {
    required String status,
    String resolutionNote = '',
  }) {
    return _api.updateIssue(
      issueId,
      status: status,
      resolutionNote: resolutionNote,
    );
  }

  @override
  Future<String> loadAttachmentUrl(String issueId, String attachmentId) {
    return _api.issueAttachmentUrl(issueId, attachmentId);
  }

  static ApiIssueRepository get legacyDefault =>
      ApiIssueRepository(BackendApiClient.instance);
}
