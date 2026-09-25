import 'dart:typed_data';

import 'package:schooldesk1/core/network/models/backend_models.dart';

abstract interface class StudentOversightRepository {
  Future<PaginatedList<StudentModel>> loadStudents({
    String? search,
    String? sectionId,
    String? status,
    int page = 1,
    int pageSize = 20,
  });

  Future<List<SectionModel>> loadSections({bool forceRefresh = false});

  Future<List<GradeModel>> loadGrades({bool forceRefresh = false});

  Future<List<AcademicYearModel>> loadAcademicYears({
    bool forceRefresh = false,
  });

  Future<Map<String, dynamic>> loadDirectorySummary();

  Future<Map<String, dynamic>> loadParentIntegrity();

  Future<PaginatedList<UserAccountModel>> loadParentAccounts({
    int page = 1,
    int pageSize = 20,
  });

  Future<List<Map<String, dynamic>>> loadFeeStructures();

  Future<UserAccountModel> createParentAccount({
    required String username,
    required String password,
    required String fullName,
    required String email,
    required String phone,
  });

  Future<UserAccountModel> updateParentAccount(
    String id, {
    String? fullName,
    String? email,
    String? phone,
  });

  Future<void> deleteParentAccount(String id, {bool permanent = false});

  Future<StudentModel> createStudent({
    required String firstName,
    required String lastName,
    required String dateOfBirth,
    required String gender,
    String? admissionNumber,
    String? studentCode,
    String? currentSectionId,
    String? parentUserId,
    bool requireParentLink = false,
    String? admissionDate,
    String status = 'active',
  });

  Future<void> updateStudent(
    String id, {
    required String firstName,
    required String lastName,
    required String dateOfBirth,
    required String gender,
    String? admissionNumber,
    String? studentCode,
    String? currentSectionId,
    String? parentUserId,
    bool requireParentLink = false,
    String? admissionDate,
    String status = 'active',
  });

  Future<void> setStudentParent({
    required String studentId,
    String? parentUserId,
  });

  Future<void> deleteStudent(String id);

  Future<String> uploadStudentPhoto({
    required String studentId,
    String? filePath,
    Uint8List? fileBytes,
    String? fileName,
  });

  Future<String> uploadStudentDocument({
    required String studentId,
    String? filePath,
    Uint8List? fileBytes,
    String? fileName,
    required String docType,
  });

  Future<StudentModel> loadStudent(String id);

  Future<Map<String, dynamic>> createRaw(
    String path,
    Map<String, dynamic> payload,
  );

  Future<void> linkGuardianToStudent({
    required String studentId,
    required String guardianId,
    bool isPrimary = false,
    bool canPickup = false,
  });

  Future<Map<String, dynamic>> createReportExport({
    required String reportTitle,
    required String format,
    String scope = '',
    Map<String, dynamic> parameters = const {},
  });
}
