import 'dart:typed_data';

import 'package:schooldesk1/core/network/models/backend_models.dart';

abstract interface class ProfileRepository {
  Future<UserResponse> loadProfile();

  Future<Map<String, dynamic>> loadCurrentSchool();

  Future<StaffModel> loadStaffMember(String id);

  Future<UserResponse> updateProfile(Map<String, dynamic> payload);

  /// Password changes are online-only and must never enter offline outbox.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  Future<Map<String, dynamic>> updateCurrentSchool(
    Map<String, dynamic> payload,
  );

  Future<String> uploadCurrentSchoolLogo(
    String path, {
    Uint8List? fileBytes,
    String? fileName,
    String? mimeType,
  });

  Future<String> uploadCurrentSchoolSignature(
    String path, {
    Uint8List? fileBytes,
    String? fileName,
    String? mimeType,
  });

  Future<String> uploadAvatar(
    String path, {
    Uint8List? fileBytes,
    String? fileName,
    String? mimeType,
  });
}
