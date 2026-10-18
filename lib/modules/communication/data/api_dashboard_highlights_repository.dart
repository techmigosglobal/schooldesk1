import 'package:schooldesk1/core/network/backend_api_client.dart';

/// Loads the server-authoritative highlights for the authenticated role.
class ApiDashboardHighlightsRepository {
  ApiDashboardHighlightsRepository({BackendApiClient? api})
    : _api = api ?? BackendApiClient.instance;

  final BackendApiClient _api;

  Future<Map<String, dynamic>> load() => _api.getRawMap(
    '/dashboard/highlights',
    queryParameters: {'refresh_nonce': DateTime.now().microsecondsSinceEpoch},
  );
}
