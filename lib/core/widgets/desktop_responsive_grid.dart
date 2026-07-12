import 'package:flutter/material.dart';

import 'package:schooldesk1/core/desktop/desktop_responsive_breakpoints.dart';
import 'package:schooldesk1/core/theme/design_tokens.dart';

/// Multi-column grid tuned for desktop viewports (4–6 columns vs 2–3 mobile).
class DesktopResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final double spacing;
  final double runSpacing;
  final int? maxColumns;
  final int? minColumns;
  final double? minTileWidth;

  const DesktopResponsiveGrid({
    super.key,
    required this.children,
    this.spacing = 16,
    this.runSpacing = 16,
    this.maxColumns,
    this.minColumns,
    this.minTileWidth = 220,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final tokens = Theme.of(context).schoolDesk;
        final columns = _columnsForWidth(width);

        if (columns <= 1) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) SizedBox(height: runSpacing),
                children[i],
              ],
            ],
          );
        }

        final tileWidth =
            (width - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: [
            for (final child in children)
              SizedBox(
                width: tileWidth.clamp(minTileWidth ?? 0, width),
                child: child,
              ),
          ],
        );
      },
    );
  }

  int _columnsForWidth(double width) {
    var columns = DesktopBreakpoints.gridColumnsForWidth(width);
    if (maxColumns != null) columns = columns.clamp(1, maxColumns!);
    if (minColumns != null) columns = columns.clamp(minColumns!, 6);
    if (minTileWidth != null && minTileWidth! > 0) {
      final fit = ((width + spacing) / (minTileWidth! + spacing)).floor();
      columns = columns.clamp(1, fit);
    }
    return columns;
  }
}
