import 'package:flutter/material.dart';

import 'package:schooldesk1/core/desktop/desktop_responsive_breakpoints.dart';
import 'package:schooldesk1/core/theme/design_tokens.dart';

/// Master-detail pattern: list panel + detail panel side by side on desktop.
class DesktopMasterDetailLayout extends StatefulWidget {
  final Widget master;
  final Widget? detail;
  final String? emptyDetailMessage;
  final IconData emptyDetailIcon;
  final double masterWidth;
  final bool showDivider;

  const DesktopMasterDetailLayout({
    super.key,
    required this.master,
    this.detail,
    this.emptyDetailMessage,
    this.emptyDetailIcon = Icons.touch_app_outlined,
    this.masterWidth = DesktopBreakpoints.masterPanelMax,
    this.showDivider = true,
  });

  @override
  State<DesktopMasterDetailLayout> createState() =>
      _DesktopMasterDetailLayoutState();
}

class _DesktopMasterDetailLayoutState extends State<DesktopMasterDetailLayout> {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = DesktopBreakpoints.isDesktopWidth(constraints.maxWidth);

        if (!isDesktop) {
          return widget.detail ?? widget.master;
        }

        final tokens = Theme.of(context).schoolDesk;
        final masterWidth = widget.masterWidth.clamp(
          DesktopBreakpoints.masterPanelMin,
          constraints.maxWidth * 0.45,
        );

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: masterWidth,
              child: widget.master,
            ),
            if (widget.showDivider)
              VerticalDivider(width: 1, color: tokens.panelBorder),
            Expanded(
              child: widget.detail ??
                  _EmptyDetailPlaceholder(
                    message: widget.emptyDetailMessage ??
                        'Select an item to view details',
                    icon: widget.emptyDetailIcon,
                  ),
            ),
          ],
        );
      },
    );
  }
}

class _EmptyDetailPlaceholder extends StatelessWidget {
  final String message;
  final IconData icon;

  const _EmptyDetailPlaceholder({
    required this.message,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: tokens.textMuted.withAlpha(120)),
          SizedBox(height: tokens.spacing.md),
          Text(
            message,
            style: theme.textTheme.bodyLarge?.copyWith(color: tokens.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
