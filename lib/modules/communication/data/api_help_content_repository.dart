import 'dart:typed_data';

import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/repositories/api_repository_utils.dart';
import 'package:schooldesk1/core/utils/result.dart';
import 'package:schooldesk1/modules/communication/domain/help_content_repository.dart';

class ApiHelpContentRepository implements HelpContentRepository {
  ApiHelpContentRepository(this._api);

  final BackendApiClient _api;

  @override
  Future<Result<List<Map<String, dynamic>>>> load(
    String role, {
    bool forceRefresh = false,
  }) {
    return guardApi(
      () => _api.getHelpContent(role, forceRefresh: forceRefresh),
    );
  }

  @override
  Future<Result<Map<String, dynamic>>> create(Map<String, dynamic> payload) {
    return guardApi(() => _api.createHelpContent(payload));
  }

  @override
  Future<Result<Map<String, dynamic>>> update(Map<String, dynamic> payload) {
    return guardApi(() => _api.updateHelpContent(payload));
  }

  @override
  Future<Result<void>> delete(String id) {
    return guardApi(() => _api.deleteHelpContent(id));
  }

  @override
  Future<Result<String>> loadPlaybackUrl(String id) {
    return guardApi(() => _api.getHelpTutorialPlaybackUrl(id));
  }

  @override
  Future<Result<Map<String, dynamic>>> uploadTutorial(
    String path, {
    required String filename,
    required String roleName,
    Uint8List? fileBytes,
    String? mimeType,
  }) {
    return guardApi(
      () => _api.uploadHelpTutorialVideo(
        path,
        filename: filename,
        roleName: roleName,
      ),
    );
  }

  static ApiHelpContentRepository get legacyDefault =>
      ApiHelpContentRepository(BackendApiClient.instance);
}
