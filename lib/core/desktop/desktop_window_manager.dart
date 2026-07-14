import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'desktop_platform.dart';
import 'desktop_responsive_breakpoints.dart';

/// Initializes and configures the native desktop window.
abstract final class DesktopWindowManager {
  static bool _initialized = false;

  static bool get isInitialized => _initialized;

  static Future<void> init() async {
    // The custom frame and controls are intentionally Windows-only. Other
    // desktop targets retain their native title bars until explicitly designed.
    if (!DesktopPlatform.isWindows || _initialized) return;

    try {
      await windowManager.ensureInitialized();

      const options = WindowOptions(
        size: Size(
          DesktopBreakpoints.defaultWindowWidth,
          DesktopBreakpoints.defaultWindowHeight,
        ),
        minimumSize: Size(
          DesktopBreakpoints.minWindowWidth,
          DesktopBreakpoints.minWindowHeight,
        ),
        center: true,
        titleBarStyle: TitleBarStyle.hidden,
        title: 'Arish Ville PreSchool App',
      );

      await windowManager.waitUntilReadyToShow(options, () async {
        await windowManager.maximize();
        await windowManager.show();
        await windowManager.focus();
      });

      _initialized = true;
    } on Object catch (error, stack) {
      developer.log(
        'Desktop window init failed — falling back to default window: $error',
        name: 'DesktopWindowManager',
        error: error,
        stackTrace: stack,
      );
    }
  }

  static Future<void> setTitle(String title) async {
    if (!_initialized) return;
    try {
      await windowManager.setTitle(title);
    } on Object catch (_) {}
  }
}
