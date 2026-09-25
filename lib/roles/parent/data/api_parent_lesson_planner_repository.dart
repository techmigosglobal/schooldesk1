import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/roles/parent/domain/parent_lesson_planner_repository.dart';

class ApiParentLessonPlannerRepository
    implements ParentLessonPlannerRepository {
  ApiParentLessonPlannerRepository(this._api);

  final BackendApiClient _api;

  @override
  Future<List<Map<String, dynamic>>> loadLessonPlanners() {
    return _api.getParentLessonPlanners();
  }

  static ApiParentLessonPlannerRepository get legacyDefault =>
      ApiParentLessonPlannerRepository(BackendApiClient.instance);
}
