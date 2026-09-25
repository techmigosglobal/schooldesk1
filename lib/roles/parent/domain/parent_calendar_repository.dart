import 'package:schooldesk1/core/network/models/backend_models.dart';

abstract class ParentCalendarRepository {
  Future<List<AcademicYearModel>> loadAcademicYears();

  Future<List<Map<String, dynamic>>> loadEvents();

  Future<Map<String, dynamic>> loadAcademicYear(String academicYearId);
}
