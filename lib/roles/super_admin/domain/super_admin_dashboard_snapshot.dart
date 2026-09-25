import 'package:schooldesk1/core/network/models/backend_models.dart';

class SuperAdminDashboardSnapshot {
  const SuperAdminDashboardSnapshot({
    required this.profile,
    required this.school,
    required this.dashboard,
    required this.branchOverview,
  });

  final UserResponse profile;
  final Map<String, dynamic> school;
  final Map<String, dynamic> dashboard;
  final List<Map<String, dynamic>> branchOverview;
}
