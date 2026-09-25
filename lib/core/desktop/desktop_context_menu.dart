import 'package:flutter/material.dart';

import 'package:schooldesk1/core/theme/design_tokens.dart';

import 'desktop_platform.dart';

/// Right-click context menu for desktop interactions.
class DesktopContextMenu extends StatelessWidget {
  final Widget child;
  final List<DesktopContextMenuItem> items;
  final Offset? position;

  const DesktopContextMenu({
    super.key,
    required this.child,
    required this.items,
    this.position,
  });

  static Future<void> show({
    required BuildContext context,
    required Offset position,
    required List<DesktopContextMenuItem> items,
  }) {
    if (!DesktopPlatform.isDesktop || items.isEmpty) {
      return Future.value();
    }

    return showMenu<void>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: [
        for (final item in items)
          if (item.isDivider)
            const PopupMenuDivider()
          else
            PopupMenuItem<void>(
              enabled: item.enabled,
              onTap: item.onTap,
              child: Row(
                children: [
                  if (item.icon != null) ...[
                    Icon(item.icon, size: 18),
                    const SizedBox(width: 12),
                  ],
                  Expanded(child: Text(item.label)),
                  if (item.shortcut != null)
                    Text(
                      item.shortcut!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).schoolDesk.textMuted,
                      ),
                    ),
                ],
              ),
            ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!DesktopPlatform.isDesktop) return child;

    return GestureDetector(
      onSecondaryTapDown: (details) {
        show(
          context: context,
          position: details.globalPosition,
          items: items,
        );
      },
      child: child,
    );
  }
}

class DesktopContextMenuItem {
  final String label;
  final IconData? icon;
  final String? shortcut;
  final VoidCallback? onTap;
  final bool enabled;
  final bool isDivider;

  const DesktopContextMenuItem({
    required this.label,
    this.icon,
    this.shortcut,
    this.onTap,
    this.enabled = true,
  }) : isDivider = false;

  const DesktopContextMenuItem.divider()
    : label = '',
      icon = null,
      shortcut = null,
      onTap = null,
      enabled = false,
      isDivider = true;
}
