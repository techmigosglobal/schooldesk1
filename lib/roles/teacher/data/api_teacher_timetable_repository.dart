import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/repositories/api_repository_utils.dart';
import 'package:schooldesk1/core/utils/result.dart';
import 'package:schooldesk1/roles/teacher/domain/teacher_timetable_repository.dart';

class ApiTeacherTimetableRepository implements TeacherTimetableRepository {
  ApiTeacherTimetableRepository(this._api);

  final BackendApiClient _api;

  @override
  Future<Result<List<int>>> loadWorkingDays() {
    return guardApi(_api.getTimetableWorkingDays);
  }

  @override
  Future<Result<List<Map<String, dynamic>>>> loadSlots({
    required String sectionId,
  }) {
    return guardApi(() => _api.getTimetableSlots(sectionId: sectionId));
  }

  static ApiTeacherTimetableRepository get legacyDefault =>
      ApiTeacherTimetableRepository(BackendApiClient.instance);
}
