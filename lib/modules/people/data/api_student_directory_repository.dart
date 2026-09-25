import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/modules/people/domain/student_directory_repository.dart';

class ApiStudentDirectoryRepository implements StudentDirectoryRepository {
  ApiStudentDirectoryRepository(this._api);

  final BackendApiClient _api;

  @override
  Future<List<GradeModel>> loadGrades({bool forceRefresh = false}) =>
      _api.getGrades(forceRefresh: forceRefresh);

  @override
  Future<List<SectionModel>> loadSections({bool forceRefresh = false}) =>
      _api.getSections(forceRefresh: forceRefresh);

  @override
  Future<PaginatedList<StudentModel>> loadStudents({
    String? search,
    String? sectionId,
    int page = 1,
    int pageSize = 20,
  }) => _api.getStudents(
    search: search,
    sectionId: sectionId,
    page: page,
    pageSize: pageSize,
  );

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
  Future<PaginatedList<Map<String, dynamic>>> loadGuardianDirectory({
    int page = 1,
    int pageSize = 20,
  }) => _api.getGuardianDirectory(page: page, pageSize: pageSize);

  @override
  Future<UserAccountModel> createParentAccount({
    required String username,
    required String password,
    required String fullName,
    required String email,
    required String phone,
    bool isActive = true,
  }) => _api.createUser(
    username: username,
    password: password,
    role: 'Parent',
    fullName: fullName,
    email: email,
    phone: phone,
    isActive: isActive,
  );

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
  Future<void> deleteStudent(String id) => _api.deleteStudent(id);

  @override
  Future<void> deleteUser(String id, {bool permanent = false}) =>
      _api.deleteUser(id, permanent: permanent);

  @override
  Future<void> setStudentParent({
    required String studentId,
    String? parentUserId,
  }) => _api.setStudentParent(studentId: studentId, parentUserId: parentUserId);

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
  Future<Map<String, dynamic>> createRaw(
    String path,
    Map<String, dynamic> payload,
  ) => _api.createRaw(path, payload);

  static ApiStudentDirectoryRepository get legacyDefault =>
      ApiStudentDirectoryRepository(BackendApiClient.instance);
}
