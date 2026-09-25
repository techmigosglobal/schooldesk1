import 'dart:typed_data';

import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/modules/people/domain/guardian_directory_repository.dart';

class ApiGuardianDirectoryRepository implements GuardianDirectoryRepository {
  ApiGuardianDirectoryRepository(this._api);

  final BackendApiClient _api;

  @override
  Future<PaginatedList<Map<String, dynamic>>> loadGuardians({
    String? search,
    String? status,
    int page = 1,
    int pageSize = 20,
  }) => _api.getGuardianDirectory(
    search: search,
    status: status,
    page: page,
    pageSize: pageSize,
  );

  @override
  Future<PaginatedList<StudentModel>> loadStudents({
    int page = 1,
    int pageSize = 20,
  }) => _api.getStudents(page: page, pageSize: pageSize);

  @override
  Future<UserAccountModel> createParent({
    required String username,
    required String password,
    required String fullName,
    required String email,
    required String phone,
    required bool isActive,
    required bool requestPrincipalApproval,
  }) => _api.createUser(
    username: username,
    password: password,
    role: 'Parent',
    fullName: fullName,
    email: email,
    phone: phone,
    isActive: isActive,
    requestPrincipalApproval: requestPrincipalApproval,
  );

  @override
  Future<UserAccountModel> updateParent(
    String id, {
    String? username,
    String? password,
    String? fullName,
    String? email,
    String? phone,
    bool? isActive,
  }) => _api.updateUser(
    id,
    username: username,
    password: password,
    role: 'Parent',
    fullName: fullName,
    email: email,
    phone: phone,
    isActive: isActive,
  );

  @override
  Future<void> uploadAvatar({
    required String userId,
    required String filePath,
    required Uint8List fileBytes,
    required String fileName,
    required String mimeType,
  }) async {
    await _api.uploadUserAvatar(
      userId: userId,
      filePath: filePath,
      fileBytes: fileBytes,
      fileName: fileName,
      mimeType: mimeType,
    );
  }

  @override
  Future<void> assignStudents({
    required String parentUserId,
    required List<String> admissionNumbers,
    required List<String> studentIds,
  }) => _api.assignParentStudents(
    parentUserId: parentUserId,
    admissionNumbers: admissionNumbers,
    studentIds: studentIds,
  );

  @override
  Future<Map<String, dynamic>> createRaw(
    String path,
    Map<String, dynamic> payload,
  ) => _api.createRaw(path, payload);

  @override
  Future<Map<String, dynamic>> updateRaw(
    String path,
    Map<String, dynamic> payload,
  ) => _api.updateRaw(path, payload);

  @override
  Future<void> deleteRaw(String path) => _api.deleteRaw(path);

  @override
  Future<void> linkGuardian({
    required String studentId,
    required String guardianId,
    required bool isPrimary,
    required bool canPickup,
  }) => _api.linkGuardianToStudent(
    studentId: studentId,
    guardianId: guardianId,
    isPrimary: isPrimary,
    canPickup: canPickup,
  );

  @override
  Future<void> setActive(String id, bool active) async {
    await _api.updateUser(id, isActive: active);
  }

  @override
  Future<void> deleteParent(String id, {bool permanent = false}) =>
      _api.deleteUser(id, permanent: permanent);

  static ApiGuardianDirectoryRepository get legacyDefault =>
      ApiGuardianDirectoryRepository(BackendApiClient.instance);
}
