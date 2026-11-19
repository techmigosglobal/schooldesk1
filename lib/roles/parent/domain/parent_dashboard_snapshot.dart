import 'package:schooldesk1/core/network/models/backend_models.dart';

/// The backend dashboard is the single authorized source of linked children.
class ParentDashboardSnapshot {
  const ParentDashboardSnapshot({
    required this.dashboard,
    this.cache = const CacheMetadata(isStale: false),
  });

  final Map<String, dynamic> dashboard;
  final CacheMetadata cache;
}
