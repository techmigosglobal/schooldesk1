import 'dart:typed_data';

import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/roles/principal/domain/principal_academic_year_repository.dart';

class ApiPrincipalAcademicYearRepository
    implements PrincipalAcademicYearRepository {
  ApiPrincipalAcademicYearRepository(this._api);

  final BackendApiClient _api;

  @override
  Future<List<AcademicYearModel>> loadAcademicYears() =>
      _api.getAcademicYears();

  @override
  Future<AcademicYearModel> createAcademicYear({
    required String yearLabel,
    required String startDate,
    required String endDate,
    bool isCurrent = false,
  }) => _api.createAcademicYear(
    yearLabel: yearLabel,
    startDate: startDate,
    endDate: endDate,
    isCurrent: isCurrent,
  );

  @override
  Future<AcademicYearModel> updateAcademicYear(
    String id, {
    required String yearLabel,
    required String startDate,
    required String endDate,
    bool isCurrent = false,
  }) => _api.updateAcademicYear(
    id,
    yearLabel: yearLabel,
    startDate: startDate,
    endDate: endDate,
    isCurrent: isCurrent,
  );

  @override
  Future<void> deleteAcademicYear(
    String id, {
    required bool cascadeConfirmed,
  }) => _api.deleteAcademicYear(id, cascadeConfirmed: cascadeConfirmed);

  @override
  Future<Map<String, dynamic>> loadAcademicYearSummary(String id) =>
      _api.getAcademicYearSummary(id);

  @override
  Future<List<GradeModel>> loadGrades() => _api.getGrades();

  @override
  Future<List<SectionModel>> loadSections({String? yearId}) =>
      _api.getSections(yearId: yearId);

  @override
  Future<PaginatedList<StudentModel>> loadStudents({int pageSize = 20}) =>
      _api.getStudents(pageSize: pageSize);

  @override
  Future<List<Map<String, dynamic>>> loadFeeStructures({
    String? academicYearId,
  }) => _api.getFeeStructures(academicYearId: academicYearId);

  @override
  Future<PaginatedList<Map<String, dynamic>>> loadInvoicesPage({
    String? academicYearId,
    int pageSize = 20,
  }) => _api.getInvoicesPage(
    academicYearId: academicYearId,
    pageSize: pageSize,
  );

  @override
  Future<PaginatedList<UserAccountModel>> loadUsers({
    required String role,
    String? status,
    int pageSize = 20,
  }) => _api.getUsers(role: role, status: status, pageSize: pageSize);

  @override
  Future<Map<String, dynamic>> queueReportExport(
    String path, {
    required String reportTitle,
    required String format,
    String reportType = '',
    String scope = '',
    Map<String, dynamic> parameters = const {},
  }) => _api.createReportExport(
    path,
    reportTitle: reportTitle,
    reportType: reportType,
    format: format,
    scope: scope,
    parameters: parameters,
  );

  @override
  Future<Uint8List> downloadReportExport(String downloadUrl) =>
      _api.downloadReportExport(downloadUrl);

  static ApiPrincipalAcademicYearRepository get legacyDefault =>
      ApiPrincipalAcademicYearRepository(BackendApiClient.instance);
}
