import 'package:schooldesk1/core/auth/auth_repository.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';

class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository(this._api);

  final BackendApiClient _api;

  @override
  Future<LoginResponse> login(LoginRequest request) => _api.login(request);

  @override
  Future<void> logout() => _api.logout();

  @override
  String? get currentRoleName => _api.currentRoleName;

  static ApiAuthRepository get legacyDefault =>
      ApiAuthRepository(BackendApiClient.instance);
}
