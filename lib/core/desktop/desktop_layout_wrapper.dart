import 'package:flutter/material.dart';

import 'desktop_platform.dart';
import 'desktop_responsive_breakpoints.dart';
import 'desktop_toolbar.dart';
import 'desktop_window_manager.dart';
import 'keyboard_shortcuts_manager.dart';

/// Root wrapper that detects platform and applies desktop chrome.
class DesktopLayoutWrapper extends StatelessWidget {
  final Widget child;
  final bool showToolbar;

  const DesktopLayoutWrapper({
    super.key,
    required this.child,
    this.showToolbar = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!DesktopPlatform.isDesktop) return child;

    return DesktopKeyboardShortcutsManager(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = DesktopBreakpoints.isDesktopWidth(constraints.maxWidth);

          return Column(
            children: [
              if (isWide && showToolbar && DesktopWindowManager.isInitialized)
                const DesktopToolbar(),
              Expanded(child: child),
            ],
          );
        },
      ),
    );
  }
}
