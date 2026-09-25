import 'package:schooldesk1/core/network/models/backend_models.dart';

abstract interface class AuthRepository {
  Future<LoginResponse> login(LoginRequest request);

  Future<void> logout();

  String? get currentRoleName;
}
