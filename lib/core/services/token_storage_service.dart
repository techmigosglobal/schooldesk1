import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:schooldesk1/core/config/env_config.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TokenStorageService {
  TokenStorageService._();

  static const _storage = FlutterSecureStorage();
  static const _accessKey = 'auth_access_token';
  static const _refreshKey = 'auth_refresh_token';
  static const _roleKey = 'auth_role_name';
  static const _userIdKey = 'auth_user_id';

  // On web, SharedPreferences maps to localStorage which is readable by any
  // JavaScript on the same origin (XSS risk). The short-lived access token is
  // therefore kept in process memory only. The refresh token and role are
  // written to SharedPreferences (localStorage) since they are needed across
  // page reloads and are less immediately exploitable than a valid access token.
  static final Map<String, String> _webMemoryCache = {};

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

  static Future<String?> getUserId() => _readAuthValue(_userIdKey);

  static Future<void> saveRoleName(String roleName) async {
    await _writeAuthValue(_roleKey, roleName.trim());
  }

  static Future<void> saveUserId(String userId) async {
    await _writeAuthValue(_userIdKey, userId.trim());
  }

  static Future<void> clear() async {
    await Future.wait([
      _deleteAuthValue(_accessKey),
      _deleteAuthValue(_refreshKey),
      _deleteAuthValue(_roleKey),
      _deleteAuthValue(_userIdKey),
    ]);
  }

  static Future<String?> _readAuthValue(String key) async {
    if (kIsWeb) {
      if (key == _accessKey) return _webMemoryCache[key]; // memory-only on web
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(key);
    }

    try {
      return await _storage.read(key: key);
    } on PlatformException catch (error, stackTrace) {
      if (EnvConfig.enableLogging) {
        developer.log(
          'Secure auth storage could not be read. Clearing stored session.',
          name: 'TokenStorageService',
          error: error,
          stackTrace: stackTrace,
        );
      }
      await clear();
      return null;
    }
  }

  static Future<void> _writeAuthValue(String key, String value) async {
    if (kIsWeb) {
      if (key == _accessKey) {
        _webMemoryCache[key] =
            value; // memory-only on web; never written to localStorage
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
      return;
    }

    try {
      await _storage.write(key: key, value: value);
    } on PlatformException catch (error, stackTrace) {
      if (EnvConfig.enableLogging) {
        developer.log(
          'Secure auth storage value could not be saved.',
          name: 'TokenStorageService',
          error: error,
          stackTrace: stackTrace,
        );
      }
      rethrow;
    }
  }

  static Future<void> _deleteAuthValue(String key) async {
    if (kIsWeb) {
      if (key == _accessKey) {
        _webMemoryCache.remove(key);
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
      return;
    }

    try {
      await _storage.delete(key: key);
    } on PlatformException catch (error, stackTrace) {
      if (EnvConfig.enableLogging) {
        developer.log(
          'Secure auth storage value could not be cleared.',
          name: 'TokenStorageService',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
  }
}
