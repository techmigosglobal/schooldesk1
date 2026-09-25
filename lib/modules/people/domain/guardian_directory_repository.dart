import 'dart:typed_data';

import 'package:schooldesk1/core/network/models/backend_models.dart';

abstract interface class GuardianDirectoryRepository {
  Future<PaginatedList<Map<String, dynamic>>> loadGuardians({
    String? search,
    String? status,
    int page = 1,
    int pageSize = 20,
  });

  Future<PaginatedList<StudentModel>> loadStudents({
    int page = 1,
    int pageSize = 20,
  });

  Future<UserAccountModel> createParent({
    required String username,
    required String password,
    required String fullName,
    required String email,
    required String phone,
    required bool isActive,
    required bool requestPrincipalApproval,
  });

  Future<UserAccountModel> updateParent(
    String id, {
    String? username,
    String? password,
    String? fullName,
    String? email,
    String? phone,
    bool? isActive,
  });

  Future<void> uploadAvatar({
    required String userId,
    required String filePath,
    required Uint8List fileBytes,
    required String fileName,
    required String mimeType,
  });

  Future<void> assignStudents({
    required String parentUserId,
    required List<String> admissionNumbers,
    required List<String> studentIds,
  });

  Future<Map<String, dynamic>> createRaw(
    String path,
    Map<String, dynamic> payload,
  );

  Future<Map<String, dynamic>> updateRaw(
    String path,
    Map<String, dynamic> payload,
  );

  Future<void> deleteRaw(String path);

  Future<void> linkGuardian({
    required String studentId,
    required String guardianId,
    required bool isPrimary,
    required bool canPickup,
  });

  Future<void> setActive(String id, bool active);

  Future<void> deleteParent(String id, {bool permanent = false});
}
