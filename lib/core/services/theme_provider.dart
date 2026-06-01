import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Theme provider for app-wide dark/light mode toggle.
class ThemeProvider extends ChangeNotifier {
  static const String _kThemeMode = 'app_theme_mode';
  static SharedPreferences? _prefs;

  ThemeMode _themeMode = ThemeMode.light;
  ThemeMode get themeMode => _themeMode;
  bool get isDark => _themeMode == ThemeMode.dark;

  static Future<ThemeProvider> create() async {
    final provider = ThemeProvider._();
    _prefs ??= await SharedPreferences.getInstance();
    final saved = _prefs?.getString(_kThemeMode);
    if (saved == 'dark') {
      provider._themeMode = ThemeMode.dark;
    } else if (saved == 'system') {
      provider._themeMode = ThemeMode.system;
    } else {
      provider._themeMode = ThemeMode.light;
    }
    return provider;
  }

  ThemeProvider._();

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _prefs?.setString(
      _kThemeMode,
      mode == ThemeMode.dark
          ? 'dark'
          : mode == ThemeMode.system
          ? 'system'
          : 'light',
    );
    notifyListeners();
  }

  Future<void> toggleDarkMode() async {
    await setThemeMode(
      _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark,
    );
  }
}

/// App settings provider for global settings state.
class AppSettingsProvider extends ChangeNotifier {
  static const String _kSettings = 'app_settings_data';
  static SharedPreferences? _prefs;

  Map<String, dynamic> _settings = {};

  double get appTextScaleFactor {
    final value = getSetting<String>('font_size', 'medium');
    switch (value) {
      case 'small':
        return 0.94;
      case 'large':
        return 1.12;
      case 'medium':
      default:
        return 1.0;
    }
  }

  static Future<AppSettingsProvider> create() async {
    final provider = AppSettingsProvider._();
    _prefs ??= await SharedPreferences.getInstance();
    final raw = _prefs?.getString(_kSettings);
    if (raw != null) {
      try {
        provider._settings = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      } catch (_) {}
    }
    // Set defaults
    provider._settings.putIfAbsent('font_size', () => 'medium');
    provider._settings.putIfAbsent('session_timeout', () => 30);
    provider._settings.putIfAbsent('show_attendance_alerts', () => true);
    provider._settings.putIfAbsent('show_fee_alerts', () => true);
    provider._settings.putIfAbsent('show_exam_alerts', () => true);
    provider._settings.putIfAbsent('show_leave_alerts', () => true);
    provider._settings.putIfAbsent('compact_view', () => false);
    return provider;
  }

  AppSettingsProvider._();

  T getSetting<T>(String key, T defaultValue) {
    return (_settings[key] as T?) ?? defaultValue;
  }

  Future<void> setSetting(String key, dynamic value) async {
    _settings[key] = value;
    await _prefs?.setString(_kSettings, jsonEncode(_settings));
    notifyListeners();
  }
}
