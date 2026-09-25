import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/repositories/api_repository_utils.dart';
import 'package:schooldesk1/core/utils/result.dart';
import 'package:schooldesk1/roles/super_admin/domain/super_admin_dashboard_repository.dart';
import 'package:schooldesk1/roles/super_admin/domain/super_admin_dashboard_snapshot.dart';

class ApiSuperAdminDashboardRepository
    implements SuperAdminDashboardRepository {
  ApiSuperAdminDashboardRepository(this._api);

  final BackendApiClient _api;

  @override
  Future<Result<SuperAdminDashboardSnapshot>> load() {
    return guardApi(() async {
      final results = await Future.wait<Object>([
        _api.getProfile(),
        _api.getCurrentSchool(),
        _api.getDashboard('super_admin', forceRefresh: true),
        _api.getBranchOverview(),
      ]);
      return SuperAdminDashboardSnapshot(
        profile: results[0] as UserResponse,
        school: Map<String, dynamic>.from(results[1] as Map),
        dashboard: Map<String, dynamic>.from(results[2] as Map),
        branchOverview: (results[3] as List)
            .whereType<Map>()
            .map(Map<String, dynamic>.from)
            .toList(),
      );
    });
  }

  @override
  Future<Result<Map<String, dynamic>>> backupDatabase() {
    return guardApi(_api.backupDatabase);
  }

  /// Legacy route fallback until all route entry points receive overrides.
  static ApiSuperAdminDashboardRepository get legacyDefault =>
      ApiSuperAdminDashboardRepository(BackendApiClient.instance);
}
