import 'package:schooldesk1/core/utils/result.dart';

class AcademicManagementSnapshot {
  const AcademicManagementSnapshot({
    required this.academicYears,
    required this.subjects,
    required this.classes,
    required this.curriculum,
    required this.staff,
  });

  final List<Map<String, dynamic>> academicYears;
  final List<Map<String, dynamic>> subjects;
  final List<Map<String, dynamic>> classes;
  final List<Map<String, dynamic>> curriculum;
  final List<Map<String, dynamic>> staff;
}

abstract interface class AcademicManagementRepository {
  Future<Result<AcademicManagementSnapshot>> load({bool forceRefresh = false});

  Future<void> saveAcademicYearRecord(Map<String, dynamic> row);

  Future<void> deleteAcademicYearRecord(String id);

  Future<void> saveAcademicSubjectRecord(Map<String, dynamic> row);

  Future<void> deleteAcademicSubjectRecord(String id);

  Future<void> saveAcademicClassRecord(Map<String, dynamic> row);

  Future<void> deleteAcademicClassRecord(Map<String, dynamic> row);

  Future<void> saveAcademicCurriculumRecord(Map<String, dynamic> row);

  Future<void> deleteAcademicCurriculumRecord(String id);
}
