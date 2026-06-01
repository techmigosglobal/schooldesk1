part of '../backend_api_client.dart';

extension BackendAuthApi on BackendApiClient {
  // ─── Authentication ────────────────────────────────────────────────────────

  Future<LoginResponse> login(LoginRequest request) async {
    try {
      final response = await _dio.post('/auth/login', data: request.toJson());
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        final loginData = data['data'] as Map<String, dynamic>;
        final resp = LoginResponse.fromJson(loginData);
        setAuthToken(resp.token);
        setCurrentRole(resp.user.roleName);
        await TokenStorageService.saveTokens(
          accessToken: resp.token,
          refreshToken: resp.refreshToken,
          roleName: resp.user.roleName,
        );
        return resp;
      }
      throw ServerException(message: data['error'] ?? 'Login failed');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<LoginResponse> setupSchool(SchoolSetupRequest request) async {
    try {
      final response = await _dio.post(
        '/schools/setup',
        data: request.toJson(),
      );
      final data = _asMap(response.data);
      if (data['success'] == true) {
        final setupData = _asMap(data['data']);
        final resp = LoginResponse.fromJson(_asMap(setupData['auth']));
        setAuthToken(resp.token);
        setCurrentRole(resp.user.roleName);
        await TokenStorageService.saveTokens(
          accessToken: resp.token,
          refreshToken: resp.refreshToken,
          roleName: resp.user.roleName,
        );
        return resp;
      }
      throw ServerException(message: data['error'] ?? 'School setup failed');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> logout() async {
    final refresh = await TokenStorageService.getRefreshToken();
    if (_authToken != null) {
      try {
        await _dio.post('/auth/logout', data: {'refresh_token': refresh ?? ''});
      } catch (_) {
        // Ignore logout network failures; client-side token clear is mandatory.
      }
    }
    clearAuthToken();
    await TokenStorageService.clear();
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/password',
        data: {
          'current_password': currentPassword,
          'new_password': newPassword,
        },
      );
      final data = _asMap(response.data);
      if (data['success'] != true) {
        throw ServerException(
          message: data['error'] ?? 'Password update failed',
        );
      }
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<bool> refreshSession() async {
    if (_refreshCompleter != null) {
      return _refreshCompleter!.future;
    }

    final refresh = await TokenStorageService.getRefreshToken();
    if (refresh == null || refresh.isEmpty) {
      return false;
    }

    final completer = Completer<bool>();
    _refreshCompleter = completer;
    try {
      final response = await _dio.post(
        '/auth/refresh',
        data: {'refresh_token': refresh},
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] != true) {
        if (!completer.isCompleted) completer.complete(false);
        return false;
      }
      final payload = data['data'] as Map<String, dynamic>;
      final token = payload['token'] as String?;
      final nextRefresh =
          (payload['refresh_token'] as String?) ?? (token ?? '');
      if (token == null || token.isEmpty) {
        if (!completer.isCompleted) completer.complete(false);
        return false;
      }
      setAuthToken(token);
      await TokenStorageService.saveTokens(
        accessToken: token,
        refreshToken: nextRefresh,
      );
      if (!completer.isCompleted) completer.complete(true);
      return true;
    } catch (_) {
      if (!completer.isCompleted) completer.complete(false);
      return false;
    } finally {
      _refreshCompleter = null;
    }
  }

  Future<bool> restoreStoredSession() async {
    if (_authToken == null || _authToken!.isEmpty) {
      return false;
    }

    try {
      final profile = await getProfile();
      setCurrentRole(profile.roleName);
      await TokenStorageService.saveRoleName(profile.roleName);
      return true;
    } on AuthException {
      final refreshed = await refreshSession();
      if (!refreshed) {
        await TokenStorageService.clear();
        clearAuthToken();
        return false;
      }
      try {
        final profile = await getProfile();
        setCurrentRole(profile.roleName);
        await TokenStorageService.saveRoleName(profile.roleName);
        return true;
      } catch (_) {
        return currentRoleName != null;
      }
    } catch (_) {
      return currentRoleName != null;
    }
  }

  Future<UserResponse> getProfile() async {
    try {
      final response = await _dio.get('/auth/profile');
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return UserResponse.fromJson(data['data'] as Map<String, dynamic>);
      }
      throw ServerException(message: data['error'] ?? 'Failed to get profile');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<UserResponse> updateProfile(Map<String, dynamic> payload) async {
    try {
      final response = await _dio.patch('/auth/profile', data: payload);
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return UserResponse.fromJson(data['data'] as Map<String, dynamic>);
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to update profile',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<String> uploadProfileAvatar(String filePath) async {
    try {
      final formData = FormData.fromMap({
        'avatar': await MultipartFile.fromFile(filePath),
      });
      final response = await _dio.post('/auth/profile/avatar', data: formData);
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        final payload = data['data'] as Map<String, dynamic>? ?? {};
        return '${payload['avatar'] ?? ''}';
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to upload profile avatar',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }
}
