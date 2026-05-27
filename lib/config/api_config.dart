import 'package:flutter/foundation.dart';

class ApiConfig {
  ApiConfig._();

  static const String _configuredBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static const String _localApiHost = String.fromEnvironment(
    'LOCAL_API_HOST',
    defaultValue: '',
  );

  static const String productionBaseUrl = String.fromEnvironment(
    'PRODUCTION_API_BASE_URL',
    defaultValue: 'https://api.yourschool.com/api',
  );

  static String get baseUrl {
    if (_configuredBaseUrl.isNotEmpty) {
      return _withoutTrailingSlash(_configuredBaseUrl);
    }
    if (kReleaseMode) {
      return productionBaseUrl;
    }
    if (kIsWeb) {
      return 'http://localhost:8080/api';
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        if (_localApiHost.isNotEmpty) {
          return 'http://$_localApiHost:8080/api';
        }
        return 'http://10.0.2.2:8080/api';
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
      case TargetPlatform.fuchsia:
        return 'http://localhost:8080/api';
    }
  }

  static String get legacyV1BaseUrl {
    return v1BaseUrlFrom(baseUrl);
  }

  static String v1BaseUrlFrom(String value) {
    final clean = _withoutTrailingSlash(value);
    if (clean.endsWith('/api/v1')) return clean;
    final root = clean.endsWith('/api')
        ? clean.substring(0, clean.length - 4)
        : clean;
    return '$root/api/v1';
  }

  static String _withoutTrailingSlash(String value) {
    return value.endsWith('/') ? value.substring(0, value.length - 1) : value;
  }
}
