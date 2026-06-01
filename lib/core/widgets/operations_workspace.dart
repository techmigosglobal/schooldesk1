import 'package:flutter/material.dart';

import 'package:schooldesk1/core/theme/design_tokens.dart';
import 'package:schooldesk1/core/widgets/erp_components.dart';

class OpsWorkspace extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsetsGeometry? padding;
  final double? maxWidth;

  const OpsWorkspace({
    super.key,
    required this.children,
    this.padding,
    this.maxWidth,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).schoolDesk;
    final width = MediaQuery.sizeOf(context).width;
    final horizontalPadding =
        SchoolDeskResponsive.contentHorizontalPaddingForWidth(
          width,
          tokens.spacing,
        );
    return SingleChildScrollView(
      padding:
          padding ??
          EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: tokens.spacing.lg,
          ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: maxWidth ?? tokens.sizing.contentMaxWidth,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: _withSpacing(children, tokens.spacing.lg),
          ),
        ),
      ),
    );
  }
}

class OpsResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final double minTileWidth;
  final double spacing;
  final double runSpacing;

  const OpsResponsiveGrid({
    super.key,
    required this.children,
    this.minTileWidth = 220,
    this.spacing = 16,
    this.runSpacing = 16,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final standardColumns = SchoolDeskResponsive.gridColumnsForWidth(width);
        final widthBasedColumns = (width / minTileWidth).floor().clamp(1, 6);
        final columns =
            (width < 280
                    ? 1
                    : standardColumns.clamp(2, widthBasedColumns.clamp(2, 6)))
                .toInt();
        final tileWidth = (width - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: [
            for (final child in children)
              SizedBox(width: tileWidth.toDouble(), child: child),
          ],
        );
      },
    );
  }
}

class OpsMetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;
  final String? caption;

  const OpsMetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color,
    this.caption,
  });

  @override
  Widget build(BuildContext context) {
    return SchoolDeskStatBox(
      label: label,
      value: value,
      icon: icon,
      color: color,
      caption: caption,
    );
  }
}

class OpsPanel extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;
  final EdgeInsetsGeometry? padding;

  const OpsPanel({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    this.trailing,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).schoolDesk;
    return SchoolDeskSectionCard(
      title: title,
      subtitle: subtitle,
      action: trailing,
      padding: padding ?? EdgeInsets.all(tokens.spacing.lg),
      child: child,
    );
  }
}

class OpsModeOption<T> {
  final T value;
  final String label;
  final IconData icon;

  const OpsModeOption({
    required this.value,
    required this.label,
    required this.icon,
  });
}

class OpsModeSelector<T> extends StatelessWidget {
  final List<OpsModeOption<T>> options;
  final T selected;
  final ValueChanged<T>? onSelected;
  final bool enabled;

  const OpsModeSelector({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).schoolDesk;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final columns = SchoolDeskResponsive.gridColumnsForWidth(width);
        final itemWidth = (width - tokens.spacing.sm * (columns - 1)) / columns;
        return Wrap(
          spacing: tokens.spacing.sm,
          runSpacing: tokens.spacing.sm,
          children: [
            for (final option in options)
              SizedBox(
                width: itemWidth.clamp(0, width).toDouble(),
                child: _OpsModeButton<T>(
                  option: option,
                  selected: option.value == selected,
                  enabled: enabled && onSelected != null,
                  onTap: () => onSelected?.call(option.value),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _OpsModeButton<T> extends StatelessWidget {
  final OpsModeOption<T> option;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _OpsModeButton({
    required this.option,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;
    final accent = !enabled
        ? tokens.textMuted.withAlpha(150)
        : selected
        ? theme.colorScheme.primary
        : tokens.textMuted;
    return Material(
      color: !enabled
          ? tokens.panelMuted
          : selected
          ? theme.colorScheme.primary.withAlpha(tokens.isDark ? 52 : 24)
          : tokens.panel,
      borderRadius: BorderRadius.circular(tokens.radius.control),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(tokens.radius.control),
        child: Container(
          constraints: BoxConstraints(minHeight: tokens.sizing.buttonHeight),
          padding: EdgeInsets.symmetric(horizontal: tokens.spacing.sm),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(tokens.radius.control),
            border: Border.all(
              color: selected ? theme.colorScheme.primary : tokens.panelBorder,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(option.icon, size: 18, color: accent),
              SizedBox(width: tokens.spacing.xs),
              Flexible(
                child: Text(
                  option.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: selected
                        ? theme.colorScheme.primary
                        : enabled
                        ? theme.colorScheme.onSurface
                        : tokens.textMuted,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OpsStatusPill extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const OpsStatusPill({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.sm,
        vertical: tokens.spacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withAlpha(tokens.isDark ? 46 : 24),
        borderRadius: BorderRadius.circular(tokens.radius.pill),
        border: Border.all(color: color.withAlpha(tokens.isDark ? 120 : 70)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            SizedBox(width: tokens.spacing.xs),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class OpsEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const OpsEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 42, color: tokens.textMuted),
              SizedBox(height: tokens.spacing.md),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: tokens.spacing.xs),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: tokens.textMuted,
                ),
              ),
              if (actionLabel != null && onAction != null) ...[
                SizedBox(height: tokens.spacing.lg),
                FilledButton.icon(
                  onPressed: onAction,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(actionLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class OpsListRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const OpsListRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SchoolDeskListTile(
      title: title,
      subtitle: subtitle,
      leadingIcon: icon,
      trailing: trailing,
      onTap: onTap,
    );
  }
}

List<Widget> _withSpacing(List<Widget> children, double spacing) {
  if (children.isEmpty) return const [];
  return [
    for (var i = 0; i < children.length; i++) ...[
      if (i > 0) SizedBox(height: spacing),
      children[i],
    ],
  ];
}
