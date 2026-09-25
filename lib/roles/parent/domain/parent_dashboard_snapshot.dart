import 'package:schooldesk1/core/network/models/backend_models.dart';

/// Child-scoped dashboard read model.
///
/// Backend returns already-authorized child rows. Parent UI must not issue a
/// second unscoped directory request.
class ParentDashboardSnapshot {
  const ParentDashboardSnapshot({
    required this.dashboard,
    required this.feed,
    this.feedError,
  });

  final Map<String, dynamic> dashboard;
  final PaginatedList<Map<String, dynamic>>? feed;
  final Object? feedError;

  bool get feedIsStale => feed?.isStale ?? false;
}
