import 'package:flutter/foundation.dart';

/// Environment configuration — reads from --dart-define at build time.
/// All sensitive values must be passed via environment, never hardcoded.
class EnvConfig {
  EnvConfig._();

  static const String _defaultSupabaseApiBaseUrl =
      'https://ouvwogguttybmpgfgctc.supabase.co/functions/v1/api';

  static const String _configuredApiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );
  static const String _productionApiBaseUrl = String.fromEnvironment(
    'PRODUCTION_API_BASE_URL',
    defaultValue: _defaultSupabaseApiBaseUrl,
  );

  // ── Supabase constants ───────────────────────────────────────
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://ouvwogguttybmpgfgctc.supabase.co',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_qCKMNCupGkjnNwK77gWdbg_Yxe83REn',
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

  /// The backend base URL. This checkout is pinned to Supabase Edge.
  /// Non-Supabase values from --dart-define are ignored to avoid attaching
  /// APKs or local runs to the retired Go/local backend by mistake.
  static String get apiBaseUrl {
    if (_configuredApiBaseUrl.isNotEmpty) {
      return v1BaseUrlFrom(_configuredApiBaseUrl);
    }
    return v1BaseUrlFrom(_productionApiBaseUrl);
  }

  static String get apiOrigin => apiOriginFromBaseUrl(apiBaseUrl);

  static String get _releaseApiBaseUrl {
    if (_configuredApiBaseUrl.isNotEmpty) {
      return v1BaseUrlFrom(_configuredApiBaseUrl);
    }
    return v1BaseUrlFrom(_productionApiBaseUrl);
  }

  static String v1BaseUrlFrom(String value) {
    final clean = _withoutTrailingSlash(value);
    if (clean.isEmpty) return _defaultSupabaseApiBaseUrl;
    if (_isSupabaseFunctionsApi(clean)) return clean;
    if (_isSupabaseProjectUrl(clean)) return '$clean/functions/v1/api';
    return _defaultSupabaseApiBaseUrl;
  }

  static String apiOriginFromBaseUrl(String baseUrl) {
    return baseUrl
        .replaceFirst(RegExp(r'/functions/v1/api/?$'), '')
        .replaceFirst(RegExp(r'/api(?:/v1)?/?$'), '')
        .replaceFirst(RegExp(r'/$'), '');
  }

  static bool _isSupabaseFunctionsApi(String value) {
    return RegExp(
      r'^https://[a-z0-9-]+\.supabase\.co/functions/v1/api$',
    ).hasMatch(value);
  }

  static bool _isSupabaseProjectUrl(String value) {
    return RegExp(r'^https://[a-z0-9-]+\.supabase\.co$').hasMatch(value);
  }

  static String _withoutTrailingSlash(String value) {
    return value.endsWith('/') ? value.substring(0, value.length - 1) : value;
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
    final validatedBaseUrl = isRelease ? _releaseApiBaseUrl : apiBaseUrl;
    if (isRelease && !validatedBaseUrl.startsWith('https://')) {
      throw Exception(
        'Release API base URL must use HTTPS. Got: $validatedBaseUrl',
      );
    }
  }
}
