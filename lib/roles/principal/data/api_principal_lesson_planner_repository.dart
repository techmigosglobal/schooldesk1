import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/roles/principal/domain/principal_lesson_planner_repository.dart';

class ApiPrincipalLessonPlannerRepository
    implements PrincipalLessonPlannerRepository {
  ApiPrincipalLessonPlannerRepository(this._api);

  final BackendApiClient _api;

  @override
  Future<List<Map<String, dynamic>>> loadLessonPlanners() =>
      _api.getPrincipalLessonPlanners();

  @override
  Future<List<Map<String, dynamic>>> loadSections() async {
    final sections = await _api.getSections();
    return sections
        .map(
          (section) => {
            'id': section.id,
            'grade_id': section.gradeId,
            'grade_name': section.gradeName,
            'section_name': section.sectionName,
          },
        )
        .toList();
  }

  static ApiPrincipalLessonPlannerRepository get legacyDefault =>
      ApiPrincipalLessonPlannerRepository(BackendApiClient.instance);
}
