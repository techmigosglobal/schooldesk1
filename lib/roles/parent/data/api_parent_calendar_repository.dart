import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/roles/parent/domain/parent_calendar_repository.dart';

class ApiParentCalendarRepository implements ParentCalendarRepository {
  ApiParentCalendarRepository(this._api);

  final BackendApiClient _api;

  @override
  Future<List<AcademicYearModel>> loadAcademicYears() {
    return _api.getAcademicYears();
  }

  @override
  Future<List<Map<String, dynamic>>> loadEvents() {
    return _api.getEvents();
  }

  @override
  Future<Map<String, dynamic>> loadAcademicYear(String academicYearId) {
    return _api.getRawMap('/academic-years/$academicYearId');
  }

  static ApiParentCalendarRepository get legacyDefault =>
      ApiParentCalendarRepository(BackendApiClient.instance);
}
