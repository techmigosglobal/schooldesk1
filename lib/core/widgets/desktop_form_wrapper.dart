import 'package:flutter/material.dart';

import 'package:schooldesk1/core/desktop/desktop_responsive_breakpoints.dart';
import 'package:schooldesk1/core/theme/design_tokens.dart';

/// Wraps form fields in side-by-side columns on desktop.
class DesktopFormWrapper extends StatelessWidget {
  final List<Widget> fields;
  final int desktopColumns;
  final double spacing;
  final EdgeInsetsGeometry? padding;

  const DesktopFormWrapper({
    super.key,
    required this.fields,
    this.desktopColumns = 2,
    this.spacing = 16,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = DesktopBreakpoints.isDesktopWidth(constraints.maxWidth);
        final tokens = Theme.of(context).schoolDesk;
        final effectivePadding = padding ?? EdgeInsets.all(tokens.spacing.md);

        if (!isDesktop || desktopColumns <= 1) {
          return Padding(
            padding: effectivePadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < fields.length; i++) ...[
                  if (i > 0) SizedBox(height: spacing),
                  fields[i],
                ],
              ],
            ),
          );
        }

        final columns = desktopColumns.clamp(2, 3);
        final columnWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return Padding(
          padding: effectivePadding,
          child: Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: [
              for (final field in fields)
                SizedBox(
                  width: columnWidth,
                  child: field,
                ),
            ],
          ),
        );
      },
    );
  }
}
