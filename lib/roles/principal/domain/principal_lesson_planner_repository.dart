abstract interface class PrincipalLessonPlannerRepository {
  Future<List<Map<String, dynamic>>> loadLessonPlanners();

  Future<List<Map<String, dynamic>>> loadSections();
}
