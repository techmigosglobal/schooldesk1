import 'package:flutter/material.dart';

import 'package:schooldesk1/core/theme/design_tokens.dart';
import 'desktop_platform.dart';
import 'desktop_toolbar.dart';
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
          final theme = Theme.of(context);
          final tokens = theme.schoolDesk;
          return Material(
            color: tokens.pageBackground,
            child: Overlay(
              initialEntries: [
                OverlayEntry(
                  builder: (context) => Column(
                    children: [
                      // Windows uses a hidden native title bar. Keep the custom title
                      // bar visible at every supported window size so drag, minimize,
                      // maximize, and close controls never disappear after resizing.
                      if (showToolbar)
                        const DesktopToolbar(),
                      Expanded(child: child),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
