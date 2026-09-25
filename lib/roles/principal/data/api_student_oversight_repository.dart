import 'dart:typed_data';

import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/roles/principal/domain/student_oversight_repository.dart';

class ApiStudentOversightRepository implements StudentOversightRepository {
  ApiStudentOversightRepository(this._api);

  final BackendApiClient _api;

  @override
  Future<PaginatedList<StudentModel>> loadStudents({
    String? search,
    String? sectionId,
    String? status,
    int page = 1,
    int pageSize = 20,
  }) => _api.getStudents(
    sectionId: sectionId,
    status: status,
    search: search,
    page: page,
    pageSize: pageSize,
  );

  @override
  Future<List<SectionModel>> loadSections({bool forceRefresh = false}) =>
      _api.getSections(forceRefresh: forceRefresh);

  @override
  Future<List<GradeModel>> loadGrades({bool forceRefresh = false}) =>
      _api.getGrades(forceRefresh: forceRefresh);

  @override
  Future<List<AcademicYearModel>> loadAcademicYears({
    bool forceRefresh = false,
  }) => _api.getAcademicYears(forceRefresh: forceRefresh);

  @override
  Future<Map<String, dynamic>> loadDirectorySummary() =>
      _api.getStudentDirectorySummary();

  @override
  Future<Map<String, dynamic>> loadParentIntegrity() =>
      _api.getStudentParentIntegrityReport();

  @override
  Future<PaginatedList<UserAccountModel>> loadParentAccounts({
    int page = 1,
    int pageSize = 20,
  }) => _api.getUsers(
    role: 'Parent',
    status: 'active',
    page: page,
    pageSize: pageSize,
  );

  @override
  Future<List<Map<String, dynamic>>> loadFeeStructures() =>
      _api.getFeeStructures();

  @override
  Future<UserAccountModel> createParentAccount({
    required String username,
    required String password,
    required String fullName,
    required String email,
    required String phone,
  }) => _api.createUser(
    username: username,
    password: password,
    role: 'Parent',
    fullName: fullName,
    email: email,
    phone: phone,
    isActive: true,
  );

  @override
  Future<UserAccountModel> updateParentAccount(
    String id, {
    String? fullName,
    String? email,
    String? phone,
  }) => _api.updateUser(id, fullName: fullName, email: email, phone: phone);

  @override
  Future<void> deleteParentAccount(String id, {bool permanent = false}) =>
      _api.deleteUser(id, permanent: permanent);

  @override
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
  }) => _api.createStudent(
    firstName: firstName,
    lastName: lastName,
    dateOfBirth: dateOfBirth,
    gender: gender,
    admissionNumber: admissionNumber,
    studentCode: studentCode,
    currentSectionId: currentSectionId,
    parentUserId: parentUserId,
    requireParentLink: requireParentLink,
    admissionDate: admissionDate,
    status: status,
  );

  @override
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
  }) => _api.updateStudent(
    id,
    firstName: firstName,
    lastName: lastName,
    dateOfBirth: dateOfBirth,
    gender: gender,
    admissionNumber: admissionNumber,
    studentCode: studentCode,
    currentSectionId: currentSectionId,
    parentUserId: parentUserId,
    requireParentLink: requireParentLink,
    admissionDate: admissionDate,
    status: status,
  );

  @override
  Future<void> setStudentParent({
    required String studentId,
    String? parentUserId,
  }) => _api.setStudentParent(studentId: studentId, parentUserId: parentUserId);

  @override
  Future<void> deleteStudent(String id) => _api.deleteStudent(id);

  @override
  Future<String> uploadStudentPhoto({
    required String studentId,
    String? filePath,
    Uint8List? fileBytes,
    String? fileName,
  }) => _api.uploadStudentPhoto(
    studentId: studentId,
    filePath: filePath,
    fileBytes: fileBytes,
    fileName: fileName,
  );

  @override
  Future<String> uploadStudentDocument({
    required String studentId,
    String? filePath,
    Uint8List? fileBytes,
    String? fileName,
    required String docType,
  }) => _api.uploadStudentDocument(
    studentId: studentId,
    filePath: filePath,
    fileBytes: fileBytes,
    fileName: fileName,
    docType: docType,
  );

  @override
  Future<StudentModel> loadStudent(String id) => _api.getStudent(id);

  @override
  Future<Map<String, dynamic>> createRaw(
    String path,
    Map<String, dynamic> payload,
  ) => _api.createRaw(path, payload);

  @override
  Future<void> linkGuardianToStudent({
    required String studentId,
    required String guardianId,
    bool isPrimary = false,
    bool canPickup = false,
  }) => _api.linkGuardianToStudent(
    studentId: studentId,
    guardianId: guardianId,
    isPrimary: isPrimary,
    canPickup: canPickup,
  );

  @override
  Future<Map<String, dynamic>> createReportExport({
    required String reportTitle,
    required String format,
    String scope = '',
    Map<String, dynamic> parameters = const {},
  }) => _api.createReportExport(
    '/student-reports/exports',
    reportTitle: reportTitle,
    format: format,
    scope: scope,
    parameters: parameters,
  );

  static ApiStudentOversightRepository get legacyDefault =>
      ApiStudentOversightRepository(BackendApiClient.instance);
}
