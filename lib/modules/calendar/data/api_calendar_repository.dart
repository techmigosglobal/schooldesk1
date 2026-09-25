import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/modules/calendar/domain/calendar_repository.dart';

class ApiCalendarRepository implements CalendarRepository {
  ApiCalendarRepository(this._api);

  final BackendApiClient _api;

  @override
  String? get currentRoleName => _api.currentRoleName;

  @override
  Future<List<AcademicYearModel>> loadAcademicYears() {
    return _api.getAcademicYears();
  }

  @override
  Future<List<Map<String, dynamic>>> loadEvents({String? academicYearId}) {
    return _api.getEvents(academicYearId: academicYearId);
  }

  @override
  Future<List<Map<String, dynamic>>> loadHolidays({String? academicYearId}) {
    return _api.getHolidays(academicYearId: academicYearId);
  }

  @override
  Future<Map<String, dynamic>> loadPreferences() {
    return _api.getCalendarPreferences();
  }

  @override
  Future<Map<String, dynamic>> resetCalendar() {
    return _api.resetSchoolCalendar();
  }

  @override
  Future<void> deleteEvent(String eventId) {
    return _api.deleteRaw('/events/$eventId');
  }

  @override
  Future<Map<String, dynamic>> updateEvent(
    String eventId,
    Map<String, dynamic> payload,
  ) {
    return _api.updateRaw('/events/$eventId', payload);
  }

  @override
  Future<void> createEvent(Map<String, dynamic> payload) {
    return _api.createEventPayload(payload);
  }

  static ApiCalendarRepository get legacyDefault =>
      ApiCalendarRepository(BackendApiClient.instance);
}
