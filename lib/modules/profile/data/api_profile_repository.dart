import 'dart:typed_data';

import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/modules/profile/domain/profile_repository.dart';

class ApiProfileRepository implements ProfileRepository {
  ApiProfileRepository(this._api);

  final BackendApiClient _api;

  @override
  Future<UserResponse> loadProfile() => _api.getProfile();

  @override
  Future<Map<String, dynamic>> loadCurrentSchool() => _api.getCurrentSchool();

  @override
  Future<StaffModel> loadStaffMember(String id) => _api.getStaffMember(id);

  @override
  Future<UserResponse> updateProfile(Map<String, dynamic> payload) =>
      _api.updateProfile(payload);

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) => _api.changePassword(
    currentPassword: currentPassword,
    newPassword: newPassword,
  );

  @override
  Future<Map<String, dynamic>> updateCurrentSchool(
    Map<String, dynamic> payload,
  ) => _api.updateCurrentSchool(payload);

  @override
  Future<String> uploadCurrentSchoolLogo(
    String path, {
    Uint8List? fileBytes,
    String? fileName,
    String? mimeType,
  }) {
    return _api.uploadCurrentSchoolLogo(
      path,
      fileBytes: fileBytes,
      fileName: fileName,
      mimeType: mimeType,
    );
  }

  @override
  Future<String> uploadCurrentSchoolSignature(
    String path, {
    Uint8List? fileBytes,
    String? fileName,
    String? mimeType,
  }) {
    return _api.uploadCurrentSchoolSignature(
      path,
      fileBytes: fileBytes,
      fileName: fileName,
      mimeType: mimeType,
    );
  }

  @override
  Future<String> uploadAvatar(
    String path, {
    Uint8List? fileBytes,
    String? fileName,
    String? mimeType,
  }) {
    return _api.uploadProfileAvatar(
      path,
      fileBytes: fileBytes,
      fileName: fileName,
      mimeType: mimeType,
    );
  }

  static ApiProfileRepository get legacyDefault =>
      ApiProfileRepository(BackendApiClient.instance);
}
