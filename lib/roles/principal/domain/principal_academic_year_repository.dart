import 'dart:typed_data';

import 'package:schooldesk1/core/network/models/backend_models.dart';

abstract interface class PrincipalAcademicYearRepository {
  Future<List<AcademicYearModel>> loadAcademicYears();

  Future<AcademicYearModel> createAcademicYear({
    required String yearLabel,
    required String startDate,
    required String endDate,
    bool isCurrent,
  });

  Future<AcademicYearModel> updateAcademicYear(
    String id, {
    required String yearLabel,
    required String startDate,
    required String endDate,
    bool isCurrent,
  });

  Future<void> deleteAcademicYear(
    String id, {
    required bool cascadeConfirmed,
  });

  Future<Map<String, dynamic>> loadAcademicYearSummary(String id);

  Future<List<GradeModel>> loadGrades();

  Future<List<SectionModel>> loadSections({String? yearId});

  Future<PaginatedList<StudentModel>> loadStudents({int pageSize});

  Future<List<Map<String, dynamic>>> loadFeeStructures({
    String? academicYearId,
  });

  Future<PaginatedList<Map<String, dynamic>>> loadInvoicesPage({
    String? academicYearId,
    int pageSize,
  });

  Future<PaginatedList<UserAccountModel>> loadUsers({
    required String role,
    String? status,
    int pageSize,
  });

  Future<Map<String, dynamic>> queueReportExport(
    String path, {
    required String reportTitle,
    required String format,
    String reportType,
    String scope,
    Map<String, dynamic> parameters,
  });

  Future<Uint8List> downloadReportExport(String downloadUrl);
}
