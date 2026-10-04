part of '../backend_api_client.dart';

Map<String, dynamic> _profilePayloadFromEnvelope(Map<String, dynamic> data) {
  final payload = data['data'];
  if (payload is Map) {
    final profile = payload['profile'];
    if (profile is Map) return Map<String, dynamic>.from(profile);
    return Map<String, dynamic>.from(payload);
  }
  return <String, dynamic>{};
}

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
        setCurrentUserId(resp.user.id);
        _cachedProfile = resp.user;
        await TokenStorageService.saveTokens(
          accessToken: resp.token,
          refreshToken: resp.refreshToken,
          roleName: resp.user.roleName,
        );
        await TokenStorageService.saveUserId(resp.user.id);
        if (resp.user.schoolId.isNotEmpty) {
          await setActiveBranchId(resp.user.schoolId);
        }
        return resp;
      }
      throw ServerException(message: data['error'] ?? 'Login failed');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> logout() async {
    final refresh = await TokenStorageService.getRefreshToken();
    final previousScope = offlineAccountKey;
    if (_authToken != null) {
      try {
        await _dio.post('/auth/logout', data: {'refresh_token': refresh ?? ''});
      } on Object catch (_) {
        // Ignore logout network failures; client-side token clear is mandatory.
      }
    }
    await offlineSync?.clearAccountData(previousScope);
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

  /// Refreshes the JWT using the stored refresh token.
  ///
  /// **Deduplication**: If a refresh is already in flight when another
  /// transport receives a 401, the shared session coordinator returns the
  /// existing future so only one refresh-token rotation is performed.
  Future<bool> refreshSession() async {
    final refreshed = await SessionRefreshCoordinator.instance.refresh(baseUrl);
    if (refreshed) {
      final token = await TokenStorageService.getAccessToken();
      if (token != null && token.isNotEmpty) setAuthToken(token);
    }
    return refreshed;
  }

  Future<bool> restoreStoredSession() async {
    if (_authToken == null || _authToken!.isEmpty) {
      return false;
    }

    try {
      final profile = await getProfile();
      _applyRestoredRole(profile.roleName);
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
        _applyRestoredRole(profile.roleName);
        return true;
      } on Object catch (_) {
        return currentRoleName != null;
      }
    } on Object catch (_) {
      return currentRoleName != null;
    }
  }

  /// Applies a role returned by the profile endpoint, with a guard to prevent
  /// downgrading a super_admin session due to a stale public.users row.
  void _applyRestoredRole(String roleName) {
    final incoming = roleName.trim().toLowerCase();
    final existing = currentRoleName?.trim().toLowerCase() ?? '';
    if (existing == 'super_admin' &&
        incoming.isNotEmpty &&
        incoming != 'super_admin') {
      // The token says super_admin but profile disagrees — trust the token;
      // the profile row is stale.  Do not save either.
      return;
    }
    setCurrentRole(roleName);
    TokenStorageService.saveRoleName(roleName);
  }

  Future<UserResponse> getProfile({bool forceRefresh = false}) async {
    try {
      final cached = _cachedProfile;
      if (cached != null && !forceRefresh) return cached;
      final response = await _get(
        '/auth/profile',
        queryParameters: forceRefresh
            ? {'refresh_nonce': DateTime.now().millisecondsSinceEpoch}
            : null,
        options: forceRefresh
            ? Options(headers: const {'Cache-Control': 'no-store'})
            : null,
      );
      final data = _asMap(response.data);
      if (data['success'] == true) {
        final profile = UserResponse.fromJson(
          _profilePayloadFromEnvelope(data),
        );
        _cachedProfile = profile;
        return profile;
      }
      throw ServerException(message: data['error'] ?? 'Failed to get profile');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<UserResponse> updateProfile(Map<String, dynamic> payload) async {
    try {
      final response = await _dio.patch('/auth/profile', data: payload);
      final data = _asMap(response.data);
      if (data['success'] == true) {
        final profile = UserResponse.fromJson(
          _profilePayloadFromEnvelope(data),
        );
        _cachedProfile = profile;
        return profile;
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to update profile',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<String> uploadProfileAvatar(
    String filePath, {
    Uint8List? fileBytes,
    String? fileName,
    String? mimeType,
  }) async {
    try {
      final formData = FormData.fromMap({
        'avatar': await _multipartUpload(
          filePath: filePath,
          fileBytes: fileBytes,
          filename: (fileName ?? '').trim().isEmpty
              ? 'profile-avatar.jpg'
              : fileName!.trim(),
          contentType: _resolveMediaType(mimeType, fileName ?? filePath),
        ),
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
      final sync = offlineSync;
      if (sync != null && OfflineSyncEngine.isTransportFailure(e)) {
        final queued = await sync.enqueueFileUpload(
          path: '/auth/profile/avatar',
          fields: const {},
          fieldName: 'avatar',
          fileName: (fileName ?? '').trim().isEmpty
              ? 'profile-avatar.jpg'
              : fileName!.trim(),
          mimeType: mimeType,
          filePath: filePath,
          fileBytes: fileBytes,
          idempotencyKey: e.requestOptions.headers['Idempotency-Key']
              ?.toString(),
        );
        if (queued != null) return queued.placeholder;
      }
      throw _handleError(e);
    }
  }
}
