import 'package:schooldesk1/core/network/models/backend_models.dart';

abstract interface class AdminTimetableRepository {
  Future<List<AcademicYearModel>> loadAcademicYears({
    bool forceRefresh = false,
  });

  Future<List<SectionModel>> loadSections({bool forceRefresh = false});

  Future<List<int>> loadWorkingDays();

  Future<List<Map<String, dynamic>>> loadSlots();

  Future<List<Map<String, dynamic>>> loadSubjects();

  Future<List<Map<String, dynamic>>> loadGradeSubjects();

  Future<List<Map<String, dynamic>>> loadStaffSubjects();

  Future<Map<String, dynamic>> replaceTimetableDays({
    required String sectionId,
    required String academicYearId,
    required List<int> days,
    required List<Map<String, dynamic>> rows,
  });
}
