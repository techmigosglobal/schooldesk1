import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    await _writeAuthValue(_accessKey, accessToken);
    await _writeAuthValue(_refreshKey, refreshToken);
    if (roleName != null && roleName.trim().isNotEmpty) {
      await saveRoleName(roleName);
    }
  }

  static Future<String?> getAccessToken() => _readAuthValue(_accessKey);

  static Future<String?> getRefreshToken() => _readAuthValue(_refreshKey);

  static Future<String?> getRoleName() => _readAuthValue(_roleKey);

  static Future<void> saveRoleName(String roleName) async {
    await _writeAuthValue(_roleKey, roleName.trim());
  }

  static Future<void> clear() async {
    await Future.wait([
      _deleteAuthValue(_accessKey),
      _deleteAuthValue(_refreshKey),
      _deleteAuthValue(_roleKey),
    ]);
  }

  static Future<String?> _readAuthValue(String key) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(key);
    }

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

  static Future<void> _writeAuthValue(String key, String value) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
      return;
    }

    try {
      await _storage.write(key: key, value: value);
    } on PlatformException catch (error, stackTrace) {
      developer.log(
        'Secure auth storage value could not be saved.',
        name: 'TokenStorageService',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  static Future<void> _deleteAuthValue(String key) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
      return;
    }

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
