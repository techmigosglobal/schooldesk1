import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/roles/principal/domain/admin_reports_repository.dart';

class ApiAdminReportsRepository implements AdminReportsRepository {
  ApiAdminReportsRepository(this._api);

  final BackendApiClient _api;

  @override
  Future<Map<String, dynamic>> requestExport({
    required String reportTitle,
    required String format,
  }) {
    return _api.createReportExport(
      '/reports/exports',
      reportTitle: reportTitle,
      format: format,
      scope: 'admin',
      parameters: {
        'source_screen': 'admin_reports',
        'requested_at': DateTime.now().toUtc().toIso8601String(),
      },
    );
  }

  static ApiAdminReportsRepository get legacyDefault =>
      ApiAdminReportsRepository(BackendApiClient.instance);
}
