import 'dart:developer' as developer;

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorageService {
  TokenStorageService._();

  static const _storage = FlutterSecureStorage();
  static const _accessKey = 'auth_access_token';
  static const _refreshKey = 'auth_refresh_token';
  static const _roleKey = 'auth_role_name';

  static Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    String? roleName,
  }) async {
    await _storage.write(key: _accessKey, value: accessToken);
    await _storage.write(key: _refreshKey, value: refreshToken);
    if (roleName != null && roleName.trim().isNotEmpty) {
      await saveRoleName(roleName);
    }
  }

  static Future<String?> getAccessToken() => _readAuthValue(_accessKey);

  static Future<String?> getRefreshToken() => _readAuthValue(_refreshKey);

  static Future<String?> getRoleName() => _readAuthValue(_roleKey);

  static Future<void> saveRoleName(String roleName) async {
    await _storage.write(key: _roleKey, value: roleName.trim());
  }

  static Future<void> clear() async {
    await Future.wait([
      _deleteAuthValue(_accessKey),
      _deleteAuthValue(_refreshKey),
      _deleteAuthValue(_roleKey),
    ]);
  }

  static Future<String?> _readAuthValue(String key) async {
    try {
      return await _storage.read(key: key);
    } on PlatformException catch (error, stackTrace) {
      developer.log(
        'Secure auth storage could not be read. Clearing stored session.',
        name: 'TokenStorageService',
        error: error,
        stackTrace: stackTrace,
      );
      await clear();
      return null;
    }
  }

  static Future<void> _deleteAuthValue(String key) async {
    try {
      await _storage.delete(key: key);
    } on PlatformException catch (error, stackTrace) {
      developer.log(
        'Secure auth storage value could not be cleared.',
        name: 'TokenStorageService',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
