import 'package:flutter/foundation.dart';

import '../../config/api_config.dart';

/// Environment configuration — reads from --dart-define at build time.
/// All sensitive values must be passed via environment, never hardcoded.
class EnvConfig {
  EnvConfig._();

  static const String _configuredApiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static const String appEnv = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'development',
  );

  static const int apiTimeoutSeconds = int.fromEnvironment(
    'API_TIMEOUT',
    defaultValue: 30,
  );

  static const bool enableAnalytics = bool.fromEnvironment(
    'ENABLE_ANALYTICS',
    defaultValue: false,
  );

  static const bool _enableLogging = bool.fromEnvironment(
    'ENABLE_LOGGING',
    defaultValue: false,
  );
  static const bool _hasEnableLogging = bool.hasEnvironment('ENABLE_LOGGING');

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );
  static const String firebaseApiKey = String.fromEnvironment(
    'FIREBASE_API_KEY',
  );
  static const String firebaseProjectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
  );
  static const String firebaseMessagingSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
  );
  static const String firebaseAndroidAppId = String.fromEnvironment(
    'FIREBASE_ANDROID_APP_ID',
  );
  static const String firebaseIosAppId = String.fromEnvironment(
    'FIREBASE_IOS_APP_ID',
  );
  static const String firebaseWebAppId = String.fromEnvironment(
    'FIREBASE_WEB_APP_ID',
  );
  static const String firebaseAuthDomain = String.fromEnvironment(
    'FIREBASE_AUTH_DOMAIN',
  );
  static const String firebaseStorageBucket = String.fromEnvironment(
    'FIREBASE_STORAGE_BUCKET',
  );
  static const String firebaseMeasurementId = String.fromEnvironment(
    'FIREBASE_MEASUREMENT_ID',
  );
  static const String firebaseVapidKey = String.fromEnvironment(
    'FIREBASE_VAPID_KEY',
  );

  static bool get isProduction => appEnv == 'production';
  static bool get isDevelopment => appEnv == 'development';
  static bool get isStaging => appEnv == 'staging';

  /// The backend base URL. Always reads from --dart-define=API_BASE_URL first.
  /// Defaults to the local Docker Go API for development.
  static String get apiBaseUrl {
    if (_configuredApiBaseUrl.isNotEmpty) {
      return _configuredApiBaseUrl;
    }
    return ApiConfig.legacyV1BaseUrl;
  }

  static String get apiOrigin => apiOriginFromBaseUrl(apiBaseUrl);

  static String apiOriginFromBaseUrl(String baseUrl) {
    return baseUrl
        .replaceFirst(RegExp(r'/api(?:/v1)?/?$'), '')
        .replaceFirst(RegExp(r'/$'), '');
  }

  /// Logging defaults to off in production unless explicitly enabled.
  static bool get enableLogging {
    if (_hasEnableLogging) {
      return _enableLogging;
    }
    return !isProduction;
  }

  /// Validates that all required environment variables are set.
  static void validate({bool isRelease = kReleaseMode}) {
    if (isRelease && _configuredApiBaseUrl.isEmpty) {
      throw Exception(
        'API_BASE_URL must be provided in release builds.\n'
        'Pass --dart-define=API_BASE_URL=https://your-api-domain',
      );
    }
    if (isRelease &&
        _configuredApiBaseUrl.isNotEmpty &&
        !_configuredApiBaseUrl.startsWith('https://')) {
      throw Exception(
        'API_BASE_URL must use HTTPS in release builds. '
        'Got: $_configuredApiBaseUrl',
      );
    }
  }
}
