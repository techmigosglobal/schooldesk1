import 'dart:typed_data';

import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/modules/people/domain/staff_directory_repository.dart';

class ApiStaffDirectoryRepository implements StaffDirectoryRepository {
  ApiStaffDirectoryRepository(this._api);

  final BackendApiClient _api;

  @override
  Future<PaginatedList<StaffModel>> loadStaff({
    String? search,
    String? status,
    String? designation,
    int page = 1,
    int pageSize = 20,
  }) => _api.getStaff(
    search: search,
    status: status,
    designation: designation,
    page: page,
    pageSize: pageSize,
  );

  @override
  Future<List<LeaveApplicationModel>> loadLeaveApplications() =>
      _api.getLeaveApplications();

  @override
  Future<StaffDirectorySupport> loadSupportData() async {
    final grades = await _api.getGrades();
    final sections = await _api.getSections();
    final subjects = await _api.getRawList(
      '/subjects',
      queryParameters: const {'page': 1, 'page_size': 20},
    );
    final staffSubjects = await _api.getRawList(
      '/staff-subjects',
      queryParameters: const {'page': 1, 'page_size': 20},
    );
    final users = (await _api.getUsers(page: 1, pageSize: 20)).data;
    return StaffDirectorySupport(
      grades: grades,
      sections: sections,
      subjects: subjects,
      staffSubjects: staffSubjects,
      users: users,
    );
  }

  @override
  Future<StaffModel> createStaff({
    required String firstName,
    required String lastName,
    String? staffCode,
    String? username,
    String? email,
    String? phone,
    String? designation,
    String? password,
    String accountRole = 'Teacher',
    String gender = 'unspecified',
    String? employmentType,
    String? joinDate,
    String? dateOfBirth,
    double basicSalary = 0,
    bool requestPrincipalApproval = false,
  }) => _api.createStaff(
    firstName: firstName,
    lastName: lastName,
    staffCode: staffCode,
    username: username,
    email: email,
    phone: phone,
    designation: designation,
    password: password,
    accountRole: accountRole,
    gender: gender,
    employmentType: employmentType,
    joinDate: joinDate,
    dateOfBirth: dateOfBirth,
    basicSalary: basicSalary,
    requestPrincipalApproval: requestPrincipalApproval,
  );

  @override
  Future<void> updateStaff(
    String id, {
    required String firstName,
    required String lastName,
    String? staffCode,
    String? username,
    String? email,
    String? designation,
    String? phone,
    String? password,
    String accountRole = 'Teacher',
    String gender = 'unspecified',
    String? employmentType,
    String? joinDate,
    String? dateOfBirth,
    double basicSalary = 0,
  }) => _api.updateStaff(
    id,
    firstName: firstName,
    lastName: lastName,
    staffCode: staffCode,
    username: username,
    email: email,
    designation: designation,
    phone: phone,
    password: password,
    accountRole: accountRole,
    gender: gender,
    employmentType: employmentType,
    joinDate: joinDate,
    dateOfBirth: dateOfBirth,
    basicSalary: basicSalary,
  );

  @override
  Future<void> decideLeave(String id, {required String status}) =>
      _api.decideLeaveApplication(id, status: status);

  @override
  Future<void> deleteStaff(String id) => _api.deleteStaff(id);

  @override
  Future<String> uploadStaffPhoto({
    required String staffId,
    String? filePath,
    Uint8List? fileBytes,
    String? fileName,
  }) => _api.uploadStaffPhoto(
    staffId: staffId,
    filePath: filePath,
    fileBytes: fileBytes,
    fileName: fileName,
  );

  @override
  Future<String> uploadStaffDocument({
    required String staffId,
    String? filePath,
    Uint8List? fileBytes,
    String? fileName,
    required String documentType,
  }) => _api.uploadStaffDocument(
    staffId: staffId,
    filePath: filePath,
    fileBytes: fileBytes,
    fileName: fileName,
    documentType: documentType,
  );

  @override
  Future<Map<String, dynamic>> createApprovalRequest({
    required String module,
    required String operationType,
    required String entityType,
    String entityId = '',
    String academicYearId = '',
    String status = 'draft',
    Map<String, dynamic> payload = const {},
    Map<String, dynamic> beforeSnapshot = const {},
    Map<String, dynamic> afterSnapshot = const {},
  }) => _api.createApprovalRequest(
    module: module,
    operationType: operationType,
    entityType: entityType,
    entityId: entityId,
    academicYearId: academicYearId,
    status: status,
    payload: payload,
    beforeSnapshot: beforeSnapshot,
    afterSnapshot: afterSnapshot,
  );

  @override
  Future<Map<String, dynamic>> submitApprovalRequest(String id) =>
      _api.submitApprovalRequest(id);

  @override
  Future<void> deleteStaffSubject(String id) =>
      _api.deleteRaw('/staff-subjects/$id');

  @override
  Future<void> createStaffSubject(Map<String, dynamic> payload) async {
    await _api.createRaw('/staff-subjects', payload);
  }

  @override
  Future<void> updateSection(String id, Map<String, dynamic> payload) async {
    await _api.updateRaw('/sections/$id', payload);
  }

  static ApiStaffDirectoryRepository get legacyDefault =>
      ApiStaffDirectoryRepository(BackendApiClient.instance);
}
