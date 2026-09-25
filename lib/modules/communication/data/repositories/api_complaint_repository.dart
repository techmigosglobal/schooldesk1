import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/repositories/api_repository_utils.dart';
import 'package:schooldesk1/core/utils/result.dart';
import 'package:schooldesk1/modules/communication/domain/repositories/complaint_repository.dart';

class ApiComplaintRepository implements ComplaintRepository {
  ApiComplaintRepository(this._api);

  final BackendApiClient _api;

  @override
  Future<Result<List<Map<String, dynamic>>>> loadForRole(String role) {
    return guardApi(() async {
      final data = await _api.getRawList('/complaints');
      return data
          .where(
            (row) => row['role'] == role || row['reported_by_role'] == role,
          )
          .toList();
    });
  }

  @override
  Future<Result<Map<String, dynamic>>> save(
    Map<String, dynamic> complaint, {
    required String role,
  }) {
    return guardApi(() async {
      final payload = Map<String, dynamic>.from(complaint)..['role'] = role;
      final id = '${payload['id'] ?? ''}';
      final persisted =
          payload.containsKey('resource') || payload.containsKey('created_at');
      if (id.isEmpty ||
          (!persisted && (id.startsWith('cp') || id.startsWith('disc_')))) {
        return _api.createRaw('/complaints', payload);
      }
      return _api.updateRaw('/complaints/$id', payload);
    });
  }

  @override
  Future<Result<void>> reportToSuperAdmin({
    required Map<String, dynamic> complaint,
    required String role,
  }) {
    return guardApi(() async {
      await _api.createRaw('/error-reports', {
        'complaint_id': complaint['id'],
        'type': complaint['type'],
        'message': complaint['message'],
        'reported_by_role': role,
        'severity': 'high',
      });
    });
  }

  static ApiComplaintRepository get legacyDefault =>
      ApiComplaintRepository(BackendApiClient.instance);
}
