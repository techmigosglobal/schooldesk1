import 'package:schooldesk1/core/repositories/api_repository_utils.dart';
import 'package:schooldesk1/core/services/backend_data_service.dart';
import 'package:schooldesk1/core/utils/result.dart';
import 'package:schooldesk1/modules/academics/domain/academic_management_repository.dart';

class ApiAcademicManagementRepository implements AcademicManagementRepository {
  ApiAcademicManagementRepository(this._service);

  final BackendDataService _service;

  @override
  Future<Result<AcademicManagementSnapshot>> load({
    bool forceRefresh = false,
  }) => guardApi(() async {
    await _service.ensureAcademicManagementLoaded();
    final values = await Future.wait<Object>([
      _service.getList(BackendDataService.kAcademicYears),
      _service.getList(BackendDataService.kAcademicSubjects),
      _service.getList(BackendDataService.kAcademicClasses),
      _service.getList(BackendDataService.kAcademicCurriculum),
      _service.getList(BackendDataService.kAdminTeachers),
    ]);
    return AcademicManagementSnapshot(
      academicYears: List<Map<String, dynamic>>.from(
        values[0] as List<Map<String, dynamic>>,
      ),
      subjects: List<Map<String, dynamic>>.from(
        values[1] as List<Map<String, dynamic>>,
      ),
      classes: List<Map<String, dynamic>>.from(
        values[2] as List<Map<String, dynamic>>,
      ),
      curriculum: List<Map<String, dynamic>>.from(
        values[3] as List<Map<String, dynamic>>,
      ),
      staff: List<Map<String, dynamic>>.from(
        values[4] as List<Map<String, dynamic>>,
      ),
    );
  });

  @override
  Future<void> saveAcademicYearRecord(Map<String, dynamic> row) =>
      _service.saveAcademicYearRecord(row);

  @override
  Future<void> deleteAcademicYearRecord(String id) =>
      _service.deleteAcademicYearRecord(id);

  @override
  Future<void> saveAcademicSubjectRecord(Map<String, dynamic> row) =>
      _service.saveAcademicSubjectRecord(row);

  @override
  Future<void> deleteAcademicSubjectRecord(String id) =>
      _service.deleteAcademicSubjectRecord(id);

  @override
  Future<void> saveAcademicClassRecord(Map<String, dynamic> row) =>
      _service.saveAcademicClassRecord(row);

  @override
  Future<void> deleteAcademicClassRecord(Map<String, dynamic> row) =>
      _service.deleteAcademicClassRecord(row);

  @override
  Future<void> saveAcademicCurriculumRecord(Map<String, dynamic> row) =>
      _service.saveAcademicCurriculumRecord(row);

  @override
  Future<void> deleteAcademicCurriculumRecord(String id) =>
      _service.deleteAcademicCurriculumRecord(id);

  static ApiAcademicManagementRepository get legacyDefault =>
      ApiAcademicManagementRepository(BackendDataService.instance);
}
