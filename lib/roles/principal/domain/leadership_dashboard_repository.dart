// A named interface keeps role composition testable and overrideable.
// ignore_for_file: one_member_abstracts

import 'package:schooldesk1/core/utils/result.dart';
import 'package:schooldesk1/roles/principal/domain/leadership_dashboard_snapshot.dart';

abstract interface class LeadershipDashboardRepository {
  Future<LeadershipDashboardCriticalSnapshot?> readCachedDashboard({
    required String role,
  });

  Future<Result<LeadershipDashboardCriticalSnapshot>> loadCritical({
    required String role,
  });

  Future<Result<LeadershipDashboardIdentity>> loadIdentity();

  Future<Result<Map<String, int>>> loadAttention();

  Future<Result<Map<String, dynamic>>> loadStaffAttendance();

  Future<Result<List<Map<String, dynamic>>>> loadNotifications();

  Future<Result<LeadershipDashboardOptionalSnapshot>> loadOptional({
    required String role,
  });
}
