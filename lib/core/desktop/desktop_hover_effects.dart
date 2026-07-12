import 'package:flutter/material.dart';

import 'desktop_platform.dart';
import 'package:schooldesk1/core/theme/design_tokens.dart';

/// Mouse hover enhancements for desktop pointer interactions.
class DesktopHoverInkWell extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final BorderRadius? borderRadius;
  final Color? hoverColor;

  const DesktopHoverInkWell({
    super.key,
    required this.child,
    this.onTap,
    this.onDoubleTap,
    this.borderRadius,
    this.hoverColor,
  });

  @override
  State<DesktopHoverInkWell> createState() => _DesktopHoverInkWellState();
}

class _DesktopHoverInkWellState extends State<DesktopHoverInkWell> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final hoverColor =
        widget.hoverColor ?? Theme.of(context).hoverColor.withAlpha(40);

    Widget content = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        borderRadius: widget.borderRadius,
        color: DesktopPlatform.isDesktop && _hovering
            ? hoverColor
            : Colors.transparent,
      ),
      child: widget.child,
    );

    if (!DesktopPlatform.isDesktop) {
      return InkWell(
        onTap: widget.onTap,
        onDoubleTap: widget.onDoubleTap,
        borderRadius: widget.borderRadius,
        child: widget.child,
      );
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: widget.onTap,
        onDoubleTap: widget.onDoubleTap,
        child: content,
      ),
    );
  }
}

class DesktopHoverIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color? color;
  final double size;

  const DesktopHoverIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color,
    this.size = 20,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: DesktopHoverInkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: size, color: color),
        ),
      ),
    );
  }
}

/// Elevated card with desktop hover lift effect.
class DesktopHoverCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;

  const DesktopHoverCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
  });

  @override
  State<DesktopHoverCard> createState() => _DesktopHoverCardState();
}

class _DesktopHoverCardState extends State<DesktopHoverCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;
    final elevation = DesktopPlatform.isDesktop && _hovering ? 8.0 : 2.0;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(
          0,
          DesktopPlatform.isDesktop && _hovering ? -2 : 0,
          0,
        ),
        decoration: BoxDecoration(
          color: tokens.panel,
          borderRadius: widget.borderRadius,
          border: Border.all(color: tokens.panelBorder),
          boxShadow: [
            BoxShadow(
              color: theme.shadowColor.withAlpha(
                DesktopPlatform.isDesktop && _hovering ? 40 : 20,
              ),
              blurRadius: elevation * 2,
              offset: Offset(0, elevation),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: widget.borderRadius,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: widget.borderRadius,
            child: Padding(padding: widget.padding, child: widget.child),
          ),
        ),
      ),
    );
  }
}
