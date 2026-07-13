import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:schooldesk1/routes/app_routes.dart';

import 'desktop_platform.dart';

/// App-wide keyboard shortcut definitions for desktop.
class DesktopKeyboardShortcutsManager extends StatelessWidget {
  final Widget child;
  final VoidCallback? onSearch;
  final VoidCallback? onSettings;
  final VoidCallback? onHelp;
  final VoidCallback? onRefresh;

  const DesktopKeyboardShortcutsManager({
    super.key,
    required this.child,
    this.onSearch,
    this.onSettings,
    this.onHelp,
    this.onRefresh,
  });

  static const _searchIntent = _DesktopShortcutIntent('search');
  static const _settingsIntent = _DesktopShortcutIntent('settings');
  static const _helpIntent = _DesktopShortcutIntent('help');
  static const _refreshIntent = _DesktopShortcutIntent('refresh');

  @override
  Widget build(BuildContext context) {
    if (!DesktopPlatform.isDesktop) return child;

    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.keyK, control: true): _searchIntent,
        SingleActivator(LogicalKeyboardKey.comma, control: true):
            _settingsIntent,
        SingleActivator(LogicalKeyboardKey.slash, control: true): _helpIntent,
        SingleActivator(LogicalKeyboardKey.keyR, control: true): _refreshIntent,
        SingleActivator(LogicalKeyboardKey.f5): _refreshIntent,
      },
      child: Actions(
        actions: {
          _DesktopShortcutIntent: CallbackAction<_DesktopShortcutIntent>(
            onInvoke: (intent) {
              switch (intent.action) {
                case 'search':
                  _invokeOrNavigate(context, onSearch, AppRoutes.globalSearch);
                case 'settings':
                  _invokeOrNavigate(
                    context,
                    onSettings,
                    AppRoutes.settingsScreen,
                  );
                case 'help':
                  _invokeOrNavigate(context, onHelp, AppRoutes.help);
                case 'refresh':
                  onRefresh?.call();
              }
              return null;
            },
          ),
        },
        child: Focus(autofocus: true, child: child),
      ),
    );
  }

  void _invokeOrNavigate(
    BuildContext context,
    VoidCallback? callback,
    String route,
  ) {
    if (callback != null) {
      callback();
      return;
    }
    final navigator = Navigator.maybeOf(context);
    if (navigator != null) {
      navigator.pushNamed(route);
    }
  }
}

class _DesktopShortcutIntent extends Intent {
  final String action;
  const _DesktopShortcutIntent(this.action);
}

/// Tooltip suffix showing keyboard shortcut hint.
String desktopShortcutLabel(String label, String shortcut) {
  if (!DesktopPlatform.isDesktop) return label;
  return '$label ($shortcut)';
}
