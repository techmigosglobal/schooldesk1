import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/repositories/api_repository_utils.dart';
import 'package:schooldesk1/core/utils/result.dart';
import 'package:schooldesk1/roles/parent/domain/parent_health_repository.dart';

class ApiParentHealthRepository implements ParentHealthRepository {
  ApiParentHealthRepository(this._api);

  final BackendApiClient _api;

  @override
  Future<Result<List<Map<String, dynamic>>>> loadChildren() {
    return guardApi(_api.getMyStudents);
  }

  @override
  Future<Result<List<Map<String, dynamic>>>> loadReminders(String studentId) {
    return guardApi(() async {
      final response = await _api.dio.get(
        '/health-reminders',
        queryParameters: {'student_id': studentId},
      );
      final data = response.data;
      final rows = data is Map ? data['data'] : data;
      if (rows is! List) return const <Map<String, dynamic>>[];
      return rows
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
    });
  }

  @override
  Future<Result<void>> createReminder(Map<String, dynamic> payload) {
    return guardApi(() async {
      await _api.dio.post('/health-reminders', data: payload);
    });
  }

  @override
  Future<Result<void>> updateReminder(
    String reminderId,
    Map<String, dynamic> payload,
  ) {
    return guardApi(() async {
      await _api.dio.patch('/health-reminders/$reminderId', data: payload);
    });
  }

  @override
  Future<Result<void>> deleteReminder(String reminderId) {
    return guardApi(() async {
      await _api.dio.delete('/health-reminders/$reminderId');
    });
  }

  static ApiParentHealthRepository get legacyDefault =>
      ApiParentHealthRepository(BackendApiClient.instance);
}
