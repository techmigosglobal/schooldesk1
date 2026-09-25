import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/repositories/api_repository_utils.dart';
import 'package:schooldesk1/core/utils/result.dart';
import 'package:schooldesk1/roles/parent/domain/parent_timetable_repository.dart';

class ApiParentTimetableRepository implements ParentTimetableRepository {
  ApiParentTimetableRepository(this._api);

  final BackendApiClient _api;

  @override
  Future<Result<List<Map<String, dynamic>>>> loadChildren() {
    return guardApi(_api.getMyStudents);
  }

  @override
  Future<Result<List<Map<String, dynamic>>>> loadSlots({
    required String sectionId,
  }) {
    return guardApi(() => _api.getTimetableSlots(sectionId: sectionId));
  }

  static ApiParentTimetableRepository get legacyDefault =>
      ApiParentTimetableRepository(BackendApiClient.instance);
}
