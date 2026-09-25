// A named interface keeps role composition testable and overrideable.
// ignore_for_file: one_member_abstracts

import 'package:schooldesk1/core/utils/result.dart';
import 'package:schooldesk1/roles/parent/domain/parent_dashboard_snapshot.dart';

abstract interface class ParentDashboardRepository {
  Future<Result<ParentDashboardSnapshot>> load({
    bool forceRefresh = false,
    bool includeFeedPosts = true,
  });
}
