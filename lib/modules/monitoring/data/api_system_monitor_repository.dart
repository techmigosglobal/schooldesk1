import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/modules/monitoring/domain/system_monitor_repository.dart';

class ApiSystemMonitorRepository implements SystemMonitorRepository {
  ApiSystemMonitorRepository(this._api);

  final BackendApiClient _api;

  @override
  Future<Map<String, dynamic>> loadErrorEvents({
    String? status,
    int pageSize = 50,
  }) => _api.getErrorEvents(status: status, pageSize: pageSize);

  @override
  Future<Map<String, dynamic>> loadRetentionMetrics() =>
      _api.getErrorRetentionMetrics();

  @override
  Future<Map<String, dynamic>> resolveErrorEvent(
    String id, {
    String resolutionNote = '',
  }) => _api.resolveErrorEvent(id, resolutionNote: resolutionNote);

  @override
  Future<void> deleteResolvedErrorEvent(String id) =>
      _api.deleteResolvedErrorEvent(id);

  @override
  Future<Map<String, dynamic>> updateRetentionSettings({
    required int warningKeepDays,
    required int resolvedKeepDays,
    required int resolvedFatalKeepDays,
    required int maxRawEvents,
  }) => _api.updateErrorRetentionSettings(
    warningKeepDays: warningKeepDays,
    resolvedKeepDays: resolvedKeepDays,
    resolvedFatalKeepDays: resolvedFatalKeepDays,
    maxRawEvents: maxRawEvents,
  );

  @override
  Future<Map<String, dynamic>> previewResolvedCleanup({DateTime? before}) =>
      _api.previewResolvedErrorCleanup(before: before);

  @override
  Future<Map<String, dynamic>> clearResolvedCleanup({DateTime? before}) =>
      _api.clearResolvedErrorEvents(before: before);

  @override
  Future<Map<String, dynamic>> backupDatabase() => _api.backupDatabase();

  @override
  Future<void> restoreDatabase(Map<String, dynamic> dump) =>
      _api.restoreDatabase(dump);

  @override
  Future<Map<String, dynamic>> wipeDatabase() => _api.wipeDatabase();

  static ApiSystemMonitorRepository get legacyDefault =>
      ApiSystemMonitorRepository(BackendApiClient.instance);
}
