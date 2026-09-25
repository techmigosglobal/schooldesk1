// A named interface keeps role composition testable and overrideable.
// ignore_for_file: one_member_abstracts

import 'package:schooldesk1/core/utils/result.dart';
import 'package:schooldesk1/roles/super_admin/domain/super_admin_dashboard_snapshot.dart';

abstract interface class SuperAdminDashboardRepository {
  Future<Result<SuperAdminDashboardSnapshot>> load();

  Future<Result<Map<String, dynamic>>> backupDatabase();
}
