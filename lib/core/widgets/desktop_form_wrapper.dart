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
        final tokens = Theme.of(context).schoolDesk;
        final effectivePadding = padding ?? EdgeInsets.all(tokens.spacing.md);

        return Padding(
          padding: effectivePadding,
          child: LayoutBuilder(
            builder: (context, contentConstraints) {
              final isDesktop = DesktopBreakpoints.isDesktopWidth(
                contentConstraints.maxWidth,
              );
              if (!isDesktop || desktopColumns <= 1) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < fields.length; i++) ...[
                      if (i > 0) SizedBox(height: spacing),
                      fields[i],
                    ],
                  ],
                );
              }

              final columns = desktopColumns.clamp(2, 3);
              final columnWidth =
                  (contentConstraints.maxWidth - spacing * (columns - 1)) /
                  columns;

              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  for (final field in fields)
                    SizedBox(width: columnWidth, child: field),
                ],
              );
            },
          ),
        );
      },
    );
  }
}
