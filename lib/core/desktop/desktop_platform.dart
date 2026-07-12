import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'desktop_responsive_breakpoints.dart';

/// Platform detection with graceful fallbacks for web/mobile.
abstract final class DesktopPlatform {
  static bool get isDesktop {
    if (kIsWeb) return false;
    return switch (defaultTargetPlatform) {
      TargetPlatform.windows ||
      TargetPlatform.macOS ||
      TargetPlatform.linux => true,
      _ => false,
    };
  }

  static bool get isWindows {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.windows;
  }

  static bool isDesktopLayout(BuildContext context) {
    if (!isDesktop) return false;
    return DesktopBreakpoints.isDesktopWidth(
      MediaQuery.sizeOf(context).width,
    );
  }

  static bool shouldUsePersistentSidebar(BuildContext context) {
    if (!isDesktop) {
      return MediaQuery.sizeOf(context).width >= 980;
    }
    return MediaQuery.sizeOf(context).width >= 900;
  }
}
