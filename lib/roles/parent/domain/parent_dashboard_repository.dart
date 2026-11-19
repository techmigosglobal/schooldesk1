import 'package:schooldesk1/core/network/models/backend_models.dart';
import 'package:schooldesk1/core/utils/result.dart';
import 'package:schooldesk1/roles/parent/domain/parent_dashboard_snapshot.dart';

abstract interface class ParentDashboardRepository {
  Future<ParentDashboardSnapshot?> readCached();

  Future<Result<ParentDashboardSnapshot>> load();

  Future<Result<PaginatedList<Map<String, dynamic>>>> loadFeed();
}
