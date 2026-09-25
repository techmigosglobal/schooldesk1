import 'package:flutter/material.dart';

import 'package:schooldesk1/core/desktop/desktop_responsive_breakpoints.dart';
import 'package:schooldesk1/core/theme/design_tokens.dart';
import 'package:schooldesk1/core/widgets/desktop_responsive_grid.dart';

/// Multi-column dashboard shell with header, stat row, and content zones.
class DesktopDashboardWidget extends StatelessWidget {
  final Widget? header;
  final List<Widget>? statCards;
  final Widget? primaryContent;
  final Widget? secondaryContent;
  final Widget? sidebarContent;
  final EdgeInsetsGeometry? padding;

  const DesktopDashboardWidget({
    super.key,
    this.header,
    this.statCards,
    this.primaryContent,
    this.secondaryContent,
    this.sidebarContent,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isDesktop = DesktopBreakpoints.isDesktopWidth(width);
        final tokens = Theme.of(context).schoolDesk;
        final effectivePadding =
            padding ??
            EdgeInsets.all(isDesktop ? tokens.spacing.lg : tokens.spacing.md);
        final maxContentWidth = DesktopBreakpoints.contentMaxWidth(width);

        final content = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (header != null) ...[
              header!,
              SizedBox(height: tokens.spacing.lg),
            ],
            if (statCards != null && statCards!.isNotEmpty) ...[
              DesktopResponsiveGrid(
                spacing: tokens.spacing.md,
                runSpacing: tokens.spacing.md,
                maxColumns: isDesktop ? 4 : 2,
                children: statCards!,
              ),
              SizedBox(height: tokens.spacing.lg),
            ],
            if (isDesktop &&
                (primaryContent != null || secondaryContent != null))
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (primaryContent != null)
                      Expanded(
                        flex: sidebarContent != null ? 3 : 1,
                        child: primaryContent!,
                      ),
                    if (secondaryContent != null) ...[
                      SizedBox(width: tokens.spacing.lg),
                      Expanded(
                        flex: 2,
                        child: secondaryContent!,
                      ),
                    ],
                    if (sidebarContent != null) ...[
                      SizedBox(width: tokens.spacing.lg),
                      SizedBox(
                        width: 320,
                        child: sidebarContent!,
                      ),
                    ],
                  ],
                ),
              )
            else ...[
              if (primaryContent != null) primaryContent!,
              if (secondaryContent != null) ...[
                SizedBox(height: tokens.spacing.lg),
                secondaryContent!,
              ],
            ],
          ],
        );

        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxContentWidth),
            child: Padding(
              padding: effectivePadding,
              child: isDesktop && primaryContent != null
                  ? content
                  : SingleChildScrollView(child: content),
            ),
          ),
        );
      },
    );
  }
}

/// Compact KPI stat card for desktop dashboard rows.
class DesktopStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color accent;
  final String? trend;
  final bool trendUp;

  const DesktopStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
    this.trend,
    this.trendUp = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;

    return Container(
      padding: EdgeInsets.all(tokens.spacing.md),
      decoration: BoxDecoration(
        color: tokens.panel,
        borderRadius: BorderRadius.circular(tokens.radius.card),
        border: Border.all(color: tokens.panelBorder),
        boxShadow: tokens.elevation.card,
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: accent.withAlpha(tokens.isDark ? 50 : 30),
              borderRadius: BorderRadius.circular(tokens.radius.control),
            ),
            child: Icon(icon, color: accent, size: 24),
          ),
          SizedBox(width: tokens.spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: tokens.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  value,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (trend != null)
                  Row(
                    children: [
                      Icon(
                        trendUp
                            ? Icons.trending_up_rounded
                            : Icons.trending_down_rounded,
                        size: 14,
                        color: trendUp
                            ? const Color(0xFF16A34A)
                            : theme.colorScheme.error,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        trend!,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: tokens.textMuted,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Panel container for dashboard sections.
class DesktopDashboardPanel extends StatelessWidget {
  final String title;
  final Widget child;
  final List<Widget>? actions;
  final EdgeInsetsGeometry? padding;

  const DesktopDashboardPanel({
    super.key,
    required this.title,
    required this.child,
    this.actions,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;

    return Container(
      decoration: BoxDecoration(
        color: tokens.panel,
        borderRadius: BorderRadius.circular(tokens.radius.card),
        border: Border.all(color: tokens.panelBorder),
        boxShadow: tokens.elevation.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              tokens.spacing.md,
              tokens.spacing.md,
              tokens.spacing.sm,
              tokens.spacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (actions != null) ...actions!,
              ],
            ),
          ),
          Divider(height: 1, color: tokens.panelBorder),
          Padding(
            padding: padding ?? EdgeInsets.all(tokens.spacing.md),
            child: child,
          ),
        ],
      ),
    );
  }
}
