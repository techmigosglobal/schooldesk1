import 'package:schooldesk1/core/utils/result.dart';

class AdminDashboardData {
  const AdminDashboardData({
    required this.students,
    required this.staff,
    required this.classes,
    required this.alerts,
    required this.invoices,
  });

  final List<Map<String, dynamic>> students;
  final List<Map<String, dynamic>> staff;
  final List<Map<String, dynamic>> classes;
  final List<Map<String, dynamic>> alerts;
  final List<Map<String, dynamic>> invoices;
}

abstract interface class AdminDashboardRepository {
  Future<Result<AdminDashboardData>> load({bool forceRefresh = false});
}
