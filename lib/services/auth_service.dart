import '../models/user_model.dart';
import 'api_service.dart';
import 'token_storage_service.dart';

class AuthService {
  AuthService({ApiService? api}) : _api = api ?? ApiService.instance;

  final ApiService _api;

  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/auth/login',
      data: {'email': email, 'password': password},
    );
    final payload = Map<String, dynamic>.from(response.data!['data'] as Map);
    await TokenStorageService.saveTokens(
      accessToken: payload['token'].toString(),
      refreshToken: payload['refresh_token'].toString(),
    );
    return UserModel.fromJson(
      Map<String, dynamic>.from(payload['user'] as Map),
    );
  }

  Future<UserModel> me() async {
    final response = await _api.get<Map<String, dynamic>>('/auth/me');
    final payload = Map<String, dynamic>.from(response.data!['data'] as Map);
    return UserModel.fromJson(payload);
  }

  Future<void> logout() async {
    final refresh = await TokenStorageService.getRefreshToken();
    await _api.post<Map<String, dynamic>>(
      '/auth/logout',
      data: {'refresh_token': refresh ?? ''},
    );
    await TokenStorageService.clear();
  }
}
