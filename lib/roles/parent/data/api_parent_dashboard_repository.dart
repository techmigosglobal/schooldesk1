import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/repositories/api_repository_utils.dart';
import 'package:schooldesk1/core/utils/result.dart';
import 'package:schooldesk1/roles/parent/domain/parent_dashboard_repository.dart';
import 'package:schooldesk1/roles/parent/domain/parent_dashboard_snapshot.dart';

class ApiParentDashboardRepository implements ParentDashboardRepository {
  ApiParentDashboardRepository(this._api);

  final BackendApiClient _api;

  @override
  Future<Result<ParentDashboardSnapshot>> load({
    bool forceRefresh = false,
    bool includeFeedPosts = true,
  }) {
    return guardApi(() async {
      final dashboard = await _api.getDashboard(
        'parent',
        forceRefresh: forceRefresh,
      );

      PaginatedList<Map<String, dynamic>>? feed;
      Object? feedError;
      if (includeFeedPosts) {
        try {
          feed = await _api.getHomeFeedEventPostsPage(page: 1, pageSize: 20);
        } on Object catch (error) {
          feedError = error;
        }
      }

      return ParentDashboardSnapshot(
        dashboard: Map<String, dynamic>.from(dashboard),
        feed: feed,
        feedError: feedError,
      );
    });
  }

  /// Legacy route fallback until all route entry points receive overrides.
  static ApiParentDashboardRepository get legacyDefault =>
      ApiParentDashboardRepository(BackendApiClient.instance);
}
