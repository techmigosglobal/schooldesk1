import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/modules/academics/domain/admin_timetable_repository.dart';

class ApiAdminTimetableRepository implements AdminTimetableRepository {
  ApiAdminTimetableRepository(this._api);

  final BackendApiClient _api;

  @override
  Future<List<AcademicYearModel>> loadAcademicYears({
    bool forceRefresh = false,
  }) {
    return _api.getAcademicYears(forceRefresh: forceRefresh);
  }

  @override
  Future<List<SectionModel>> loadSections({bool forceRefresh = false}) {
    return _api.getSections(forceRefresh: forceRefresh);
  }

  @override
  Future<List<int>> loadWorkingDays() => _api.getTimetableWorkingDays();

  @override
  Future<List<Map<String, dynamic>>> loadSlots() => _api.getTimetableSlots();

  @override
  Future<List<Map<String, dynamic>>> loadSubjects() {
    return _api.getRawList(
      '/subjects',
      queryParameters: const {'page_size': 100},
    );
  }

  @override
  Future<List<Map<String, dynamic>>> loadGradeSubjects() {
    return _api.getRawList(
      '/grade-subjects',
      queryParameters: const {'page_size': 100},
    );
  }

  @override
  Future<List<Map<String, dynamic>>> loadStaffSubjects() {
    return _api.getRawList(
      '/staff-subjects',
      queryParameters: const {'page_size': 100},
    );
  }

  @override
  Future<Map<String, dynamic>> replaceTimetableDays({
    required String sectionId,
    required String academicYearId,
    required List<int> days,
    required List<Map<String, dynamic>> rows,
  }) {
    return _api.replaceTimetableDays(
      sectionId: sectionId,
      academicYearId: academicYearId,
      days: days,
      rows: rows,
    );
  }

  static ApiAdminTimetableRepository get legacyDefault =>
      ApiAdminTimetableRepository(BackendApiClient.instance);
}
