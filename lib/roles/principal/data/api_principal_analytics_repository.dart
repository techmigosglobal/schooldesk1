import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/repositories/api_repository_utils.dart';
import 'package:schooldesk1/core/utils/result.dart';
import 'package:schooldesk1/roles/principal/domain/principal_analytics_repository.dart';

class ApiPrincipalAnalyticsRepository implements PrincipalAnalyticsRepository {
  ApiPrincipalAnalyticsRepository(this._api);

  final BackendApiClient _api;

  @override
  Future<Result<PrincipalAnalyticsSnapshot>> load({bool forceRefresh = false}) {
    return guardApi(() async {
      final invoicesFuture =
          _api.currentRoleName?.trim().toLowerCase() == 'coordinator'
          ? Future<List<Map<String, dynamic>>>.value(const [])
          : _loadAllInvoices(forceRefresh: forceRefresh);
      final alertsFuture = _api.getNotifications();
      final staffFuture = _loadAllStaff();
      final values = await Future.wait<Object>([
        invoicesFuture,
        alertsFuture,
        staffFuture,
      ]);
      return PrincipalAnalyticsSnapshot(
        invoices: values[0] as List<Map<String, dynamic>>,
        alerts: values[1] as List<Map<String, dynamic>>,
        staff: values[2] as List<Map<String, dynamic>>,
      );
    });
  }

  Future<List<Map<String, dynamic>>> _loadAllInvoices({
    required bool forceRefresh,
  }) async {
    const pageSize = 100;
    final rows = <Map<String, dynamic>>[];
    var page = 1;
    while (true) {
      final result = await _api.getInvoicesPage(
        page: page,
        pageSize: pageSize,
        refreshNonce: forceRefresh
            ? DateTime.now().millisecondsSinceEpoch
            : null,
      );
      rows.addAll(result.data);
      if (!result.hasMore) return rows;
      page++;
    }
  }

  Future<List<Map<String, dynamic>>> _loadAllStaff() async {
    const pageSize = 100;
    final rows = <Map<String, dynamic>>[];
    var page = 1;
    while (true) {
      final result = await _api.getStaff(page: page, pageSize: pageSize);
      rows.addAll(
        result.data.map(
          (staff) => {
            'id': staff.id,
            'name': staff.fullName,
            'employeeId': staff.staffCode,
            'designation': staff.designation,
            'email': staff.email,
            'phone': staff.phone,
            'status': staff.status,
          },
        ),
      );
      if (!result.hasMore) return rows;
      page++;
    }
  }

  static ApiPrincipalAnalyticsRepository get legacyDefault =>
      ApiPrincipalAnalyticsRepository(BackendApiClient.instance);
}
