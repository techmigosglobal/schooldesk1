import 'package:schooldesk1/core/utils/result.dart';

class PrincipalAnalyticsSnapshot {
  const PrincipalAnalyticsSnapshot({
    required this.invoices,
    required this.alerts,
    required this.staff,
  });

  final List<Map<String, dynamic>> invoices;
  final List<Map<String, dynamic>> alerts;
  final List<Map<String, dynamic>> staff;
}

abstract interface class PrincipalAnalyticsRepository {
  Future<Result<PrincipalAnalyticsSnapshot>> load({bool forceRefresh = false});
}
