import 'package:flutter/foundation.dart';

/// Environment configuration — reads from --dart-define at build time.
///
/// ALL sensitive values (Supabase URL/key, Firebase keys) MUST be injected
/// via --dart-define or --dart-define-from-file during the build. There are
/// NO hardcoded fallback values for any secret or production URL.
///
/// Local development:
///   flutter run --dart-define-from-file=env.json
///
/// Production (APK / AAB):
///   flutter build apk --release --dart-define-from-file=env.supabase.json
///   scripts/build-android-supabase.sh apk
///
/// CI (Codemagic / GitHub Actions):
///   Pass all keys as --dart-define=KEY=$SECRET_VAR_FROM_CI
class EnvConfig {
  EnvConfig._();

  // ── API base URL ─────────────────────────────────────────────
  // Explicitly configured URL wins. Falls back to the Supabase project URL
  // if a bare project URL is supplied.  No hardcoded production fallback.
  static const String _configuredApiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );
  static const String _productionApiBaseUrl = String.fromEnvironment(
    'PRODUCTION_API_BASE_URL',
    defaultValue: '',
  );

  // ── Supabase ──────────────────────────────────────────────────
  /// Supabase project URL. Must be supplied via --dart-define=SUPABASE_URL.
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  /// Supabase anon (publishable) key. Must be supplied via
  /// --dart-define=SUPABASE_ANON_KEY. Removing the hardcoded default
  /// prevents the key from being baked into the binary at compile time.
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  // ── App environment ───────────────────────────────────────────
  static const String appEnv = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'development',
  );

  // ── Networking ────────────────────────────────────────────────
  static const int apiTimeoutSeconds = int.fromEnvironment(
    'API_TIMEOUT',
    defaultValue: 30,
  );

  // ── Analytics / Logging ───────────────────────────────────────
  static const bool enableAnalytics = bool.fromEnvironment(
    'ENABLE_ANALYTICS',
    defaultValue: false,
  );

  static const bool _enableLogging = bool.fromEnvironment(
    'ENABLE_LOGGING',
    defaultValue: false,
  );
  static const bool _hasEnableLogging = bool.hasEnvironment('ENABLE_LOGGING');

  // ── Firebase ──────────────────────────────────────────────────
  // All Firebase values are injected via --dart-define. They have no
  // defaultValue so a missing key produces an empty string, which
  // validate() will detect in production/staging builds.
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

  // ── Environment helpers ───────────────────────────────────────
  static bool get isProduction => appEnv == 'production';
  static bool get isDevelopment => appEnv == 'development';
  static bool get isStaging => appEnv == 'staging';
  static bool get isLocal => appEnv == 'local';

  // ── API URL resolution ────────────────────────────────────────
  /// The backend base URL, resolved from build-time defines.
  /// Accepts either a full edge-function path or a bare Supabase project URL.
  static String get apiBaseUrl {
    if (_configuredApiBaseUrl.isNotEmpty) {
      return v1BaseUrlFrom(_configuredApiBaseUrl);
    }
    if (_productionApiBaseUrl.isNotEmpty) {
      return v1BaseUrlFrom(_productionApiBaseUrl);
    }
    // Derive from supabaseUrl if no explicit API_BASE_URL was given.
    if (supabaseUrl.isNotEmpty) {
      return v1BaseUrlFrom(supabaseUrl);
    }
    return '';
  }

  static String get apiOrigin => apiOriginFromBaseUrl(apiBaseUrl);

  static String get _releaseApiBaseUrl => apiBaseUrl;

  static String v1BaseUrlFrom(String value) {
    final clean = _withoutTrailingSlash(value);
    if (clean.isEmpty) return '';
    if (_isSupabaseFunctionsApi(clean)) return clean;
    if (_isLocalSupabaseFunctionsApi(clean)) return clean;
    if (_isSupabaseProjectUrl(clean)) return '$clean/functions/v1/api';
    if (_isLocalSupabaseProjectUrl(clean)) return '$clean/functions/v1/api';
    // Unknown format — return as-is so validate() can surface the problem.
    return clean;
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

  static bool _isLocalSupabaseFunctionsApi(String value) {
    return RegExp(
      r'^http://(127\.0\.0\.1|localhost):54321/functions/v1/api$',
    ).hasMatch(value);
  }

  static bool _isLocalSupabaseProjectUrl(String value) {
    return RegExp(r'^http://(127\.0\.0\.1|localhost):54321$').hasMatch(value);
  }

  static String _withoutTrailingSlash(String value) {
    return value.endsWith('/') ? value.substring(0, value.length - 1) : value;
  }

  // ── Logging ───────────────────────────────────────────────────
  /// Logging defaults to off in production/staging unless explicitly enabled.
  static bool get enableLogging {
    if (_hasEnableLogging) {
      return _enableLogging;
    }
    return isDevelopment || isLocal;
  }

  // ── Validation ────────────────────────────────────────────────
  /// Validates that all required environment variables are present and sane.
  ///
  /// Called as the **first** operation in main() so the app fails fast with
  /// a clear error message instead of crashing silently on the first API call.
  ///
  /// Rules:
  ///  - In production or staging builds: Supabase URL, anon key, API URL,
  ///    and core Firebase keys MUST be non-empty and use HTTPS.
  ///  - In release mode (kReleaseMode): same rules apply regardless of APP_ENV.
  ///  - In development/local: only a warning is logged for missing values.
  static void validate({bool isRelease = kReleaseMode}) {
    final enforceStrict = isRelease || isProduction || isStaging;

    if (enforceStrict) {
      _requireNonEmpty(
        'SUPABASE_URL',
        supabaseUrl,
        hint: '--dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co',
      );
      _requireNonEmpty(
        'SUPABASE_ANON_KEY',
        supabaseAnonKey,
        hint: '--dart-define=SUPABASE_ANON_KEY=<your_anon_key>',
      );

      final resolvedApiUrl = _releaseApiBaseUrl;
      if (resolvedApiUrl.isEmpty) {
        throw Exception(
          '[EnvConfig] API_BASE_URL is required but not set.\n'
          'Pass it via --dart-define=API_BASE_URL=https://YOUR_PROJECT.supabase.co/functions/v1/api\n'
          'or use --dart-define-from-file=env.supabase.json',
        );
      }
      if (!resolvedApiUrl.startsWith('https://')) {
        throw Exception(
          '[EnvConfig] API base URL must use HTTPS in production/staging/release builds.\n'
          'Got: $resolvedApiUrl',
        );
      }
      if (!supabaseUrl.startsWith('https://')) {
        throw Exception(
          '[EnvConfig] SUPABASE_URL must use HTTPS in production/staging/release builds.\n'
          'Got: $supabaseUrl',
        );
      }

      // Firebase keys are required for push notifications to function.
      _requireNonEmpty(
        'FIREBASE_PROJECT_ID',
        firebaseProjectId,
        hint: '--dart-define=FIREBASE_PROJECT_ID=your-project-id',
      );
      _requireNonEmpty(
        'FIREBASE_MESSAGING_SENDER_ID',
        firebaseMessagingSenderId,
        hint: '--dart-define=FIREBASE_MESSAGING_SENDER_ID=<sender_id>',
      );
      _requireNonEmpty(
        'FIREBASE_API_KEY',
        firebaseApiKey,
        hint: '--dart-define=FIREBASE_API_KEY=<api_key>',
      );
    }
  }

  static void _requireNonEmpty(
    String name,
    String value, {
    required String hint,
  }) {
    if (value.isEmpty) {
      throw Exception(
        '[EnvConfig] Required environment variable "$name" is not set.\n'
        'How to fix: $hint\n'
        'Or use --dart-define-from-file=env.supabase.json which includes all keys.',
      );
    }
  }
}
