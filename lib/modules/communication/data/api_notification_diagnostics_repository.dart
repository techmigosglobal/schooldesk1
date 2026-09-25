import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/modules/communication/domain/notification_diagnostics_repository.dart';

class ApiNotificationDiagnosticsRepository
    implements NotificationDiagnosticsRepository {
  ApiNotificationDiagnosticsRepository(this._api);

  final BackendApiClient _api;

  @override
  Future<Map<String, dynamic>> runPushDiagnostics() =>
      _api.runPushDiagnostics();

  static ApiNotificationDiagnosticsRepository get legacyDefault =>
      ApiNotificationDiagnosticsRepository(BackendApiClient.instance);
}
