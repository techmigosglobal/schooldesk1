// Repository seam intentionally stays abstract for provider/test overrides.
// ignore_for_file: one_member_abstracts

/// Child-scoped lesson plans shown in Parent portal.
abstract class ParentLessonPlannerRepository {
  Future<List<Map<String, dynamic>>> loadLessonPlanners();
}
