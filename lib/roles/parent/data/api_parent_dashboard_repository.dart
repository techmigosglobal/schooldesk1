import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/repositories/api_repository_utils.dart';
import 'package:schooldesk1/core/utils/result.dart';
import 'package:schooldesk1/roles/parent/domain/parent_dashboard_repository.dart';
import 'package:schooldesk1/roles/parent/domain/parent_dashboard_snapshot.dart';

class ApiParentDashboardRepository implements ParentDashboardRepository {
  ApiParentDashboardRepository(this._api);

  final BackendApiClient _api;

  @override
  Future<ParentDashboardSnapshot?> readCached() async {
    final saved = await _api.readCachedDashboard('parent');
    if (saved == null) return null;
    return ParentDashboardSnapshot(
      dashboard: saved.data,
      cache: saved.metadata,
    );
  }

  @override
  Future<Result<ParentDashboardSnapshot>> load() {
    return guardApi(() async {
      var cache = const CacheMetadata(isStale: false);
      final dashboard = await _api.getDashboard(
        'parent',
        refreshNetwork: true,
        onCacheMetadata: (value) => cache = value,
      );
      return ParentDashboardSnapshot(dashboard: dashboard, cache: cache);
    });
  }

  @override
  Future<Result<PaginatedList<Map<String, dynamic>>>> loadFeed() =>
      guardApi(() => _api.getHomeFeedEventPostsPage(page: 1, pageSize: 10));

  /// Legacy route fallback until all route entry points receive overrides.
  static ApiParentDashboardRepository get legacyDefault =>
      ApiParentDashboardRepository(BackendApiClient.instance);
}
