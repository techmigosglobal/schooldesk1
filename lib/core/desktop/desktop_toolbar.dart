import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'package:schooldesk1/core/theme/design_tokens.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'desktop_platform.dart';

/// Top application toolbar acting as the custom window titlebar with native-like controls.
class DesktopToolbar extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final List<Widget> actions;
  final bool showWindowControls;

  const DesktopToolbar({
    super.key,
    this.title,
    this.subtitle,
    this.actions = const [],
    this.showWindowControls = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!DesktopPlatform.isDesktop) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;

    String displayTitle = title ?? 'Arish Ville PreSchool App';
    final role = BackendApiClient.instance.currentRoleName?.trim().toLowerCase();
    if (role != null && role.isNotEmpty) {
      final portalName = switch (role) {
        'principal' || 'admin' => 'Principal Portal',
        'super_admin' => 'Super Admin Portal',
        'teacher' => 'Teacher Portal',
        'parent' => 'Parent Portal',
        _ => '',
      };
      if (portalName.isNotEmpty) {
        displayTitle = 'Arish Ville PreSchool App · $portalName';
      }
    }

    if (subtitle != null && subtitle!.isNotEmpty) {
      displayTitle += ' · $subtitle';
    }

    return DragToMoveArea(
      child: Container(
        height: 40,
        padding: EdgeInsets.only(left: tokens.spacing.md),
        decoration: BoxDecoration(
          color: tokens.panel,
          border: Border(bottom: BorderSide(color: tokens.panelBorder)),
        ),
        child: Row(
          children: [
            Icon(Icons.school_rounded, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              displayTitle,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            const Spacer(),
            ...actions,
            if (showWindowControls) ...[
              const _WindowControlButtons(),
            ],
          ],
        ),
      ),
    );
  }
}

class _WindowControlButtons extends StatelessWidget {
  const _WindowControlButtons();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _WindowButton(
          icon: Icons.remove_rounded,
          tooltip: 'Minimize',
          onPressed: () => windowManager.minimize(),
        ),
        _WindowButton(
          icon: Icons.crop_square_rounded,
          tooltip: 'Maximize',
          onPressed: () async {
            if (await windowManager.isMaximized()) {
              await windowManager.unmaximize();
            } else {
              await windowManager.maximize();
            }
          },
        ),
        _WindowButton(
          icon: Icons.close_rounded,
          tooltip: 'Close',
          hoverColor: Colors.red,
          onPressed: () => windowManager.close(),
        ),
      ],
    );
  }
}

class _WindowButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color? hoverColor;

  const _WindowButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.hoverColor,
  });

  @override
  State<_WindowButton> createState() => _WindowButtonState();
}

class _WindowButtonState extends State<_WindowButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final hover = widget.hoverColor;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: Tooltip(
        message: widget.tooltip,
        child: InkWell(
          onTap: widget.onPressed,
          child: Container(
            width: 46,
            height: 40,
            alignment: Alignment.center,
            color: _hovering && hover != null
                ? hover
                : _hovering
                    ? Theme.of(context).hoverColor
                    : Colors.transparent,
            child: Icon(
              widget.icon,
              size: 16,
              color: _hovering && hover != null ? Colors.white : null,
            ),
          ),
        ),
      ),
    );
  }
}
