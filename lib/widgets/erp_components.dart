import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../services/feature_availability_service.dart';
import '../theme/design_tokens.dart';

class SchoolDeskUiIllustrations {
  SchoolDeskUiIllustrations._();

  static const secureLogin = 'assets/images/ui/secure-login.svg';
  static const emptyState = 'assets/images/ui/empty-state.svg';
  static const attendance = 'assets/images/ui/illustration-attendance.svg';
  static const homework = 'assets/images/ui/illustration-homework.svg';
  static const notices = 'assets/images/ui/illustration-notices.svg';
  static const fees = 'assets/images/ui/illustration-fees.svg';
  static const chat = 'assets/images/ui/illustration-chat.svg';
  static const calendar = 'assets/images/ui/illustration-calendar.svg';
  static const classRoutine = 'assets/images/ui/illustration-class-routine.svg';
  static const resources = 'assets/images/ui/illustration-resources.svg';
  static const lessonPlanner =
      'assets/images/ui/illustration-lesson-planner.svg';
  static const principalStudents = 'assets/images/ui/principal-students.svg';
  static const principalGuidedAssistant =
      'assets/images/ui/principal-guided-assistant.svg';
  static const principalStaffManagement =
      'assets/images/ui/principal-staff-management.svg';
  static const principalGuardians = 'assets/images/ui/principal-guardians.svg';
  static const principalClasses = 'assets/images/ui/principal-classes.svg';
  static const principalSubjects = 'assets/images/ui/principal-subjects.svg';
  static const principalTimetable = 'assets/images/ui/principal-timetable.svg';
  static const principalExams = 'assets/images/ui/principal-exams.svg';
  static const principalResults = 'assets/images/ui/principal-results.svg';
  static const principalFees = 'assets/images/ui/principal-fees.svg';
  static const principalEvents = 'assets/images/ui/principal-events.svg';
  static const principalInbox = 'assets/images/ui/principal-inbox.svg';
}

class SchoolDeskSectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? action;
  final EdgeInsetsGeometry? padding;

  const SchoolDeskSectionCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    this.action,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;
    return Container(
      padding: padding ?? EdgeInsets.all(tokens.spacing.md),
      decoration: BoxDecoration(
        color: tokens.panel,
        borderRadius: BorderRadius.circular(tokens.radius.card),
        border: Border.all(color: tokens.panelBorder),
        boxShadow: tokens.elevation.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleMedium),
                    if (subtitle != null) ...[
                      SizedBox(height: tokens.spacing.xs),
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: tokens.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (action != null) ...[
                SizedBox(width: tokens.spacing.sm),
                action!,
              ],
            ],
          ),
          SizedBox(height: tokens.spacing.md),
          child,
        ],
      ),
    );
  }
}

class SchoolDeskQuickActionTile extends StatelessWidget {
  final String label;
  final String? subtitle;
  final IconData icon;
  final Color? color;
  final VoidCallback? onTap;
  final int? badgeCount;
  final String? semanticLabel;

  const SchoolDeskQuickActionTile({
    super.key,
    required this.label,
    this.subtitle,
    required this.icon,
    this.color,
    this.onTap,
    this.badgeCount,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;
    final accent = color ?? theme.colorScheme.primary;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final isCompactText = textScale > 1.2;
    final minHeight = 116 * textScale.clamp(1.0, 1.25).toDouble();
    final content = AnimatedContainer(
      duration: tokens.motion.fast,
      curve: tokens.motion.curve,
      constraints: BoxConstraints(minHeight: minHeight),
      decoration: BoxDecoration(
        color: tokens.panel,
        borderRadius: BorderRadius.circular(tokens.radius.card),
        border: Border.all(color: tokens.panelBorder),
        boxShadow: onTap == null ? null : tokens.elevation.card,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compactHeight =
              constraints.hasBoundedHeight && constraints.maxHeight < 144;
          final compact = isCompactText || compactHeight;
          final tilePadding = EdgeInsets.all(
            compact ? tokens.spacing.sm + tokens.spacing.xs : tokens.spacing.md,
          );
          final iconSize = compact ? 40.0 : 42.0;
          final labelMaxLines = compactHeight ? 1 : 2;
          final subtitleMaxLines = compact ? 1 : 2;

          return Padding(
            padding: tilePadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: iconSize,
                      height: iconSize,
                      decoration: BoxDecoration(
                        color: accent.withAlpha(tokens.isDark ? 54 : 28),
                        borderRadius: BorderRadius.circular(
                          tokens.radius.control,
                        ),
                      ),
                      child: Icon(icon, color: accent, size: 23),
                    ),
                    const Spacer(),
                    if (badgeCount != null && badgeCount! > 0)
                      Badge.count(
                        count: badgeCount! > 99 ? 99 : badgeCount!,
                        backgroundColor: accent,
                      ),
                  ],
                ),
                SizedBox(
                  height: compact ? tokens.spacing.sm : tokens.spacing.md,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        label,
                        maxLines: labelMaxLines,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (subtitle != null) ...[
                        SizedBox(height: tokens.spacing.xs),
                        Flexible(
                          child: Text(
                            subtitle!,
                            maxLines: subtitleMaxLines,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: tokens.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    return Semantics(
      label: semanticLabel ?? label,
      button: onTap != null,
      enabled: onTap != null,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(tokens.radius.card),
          child: content,
        ),
      ),
    );
  }
}

class SchoolDeskMetricRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  const SchoolDeskMetricRow({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;
    final accent = color ?? theme.colorScheme.primary;
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: accent.withAlpha(tokens.isDark ? 48 : 24),
            borderRadius: BorderRadius.circular(tokens.radius.control),
          ),
          child: Icon(icon, color: accent, size: 18),
        ),
        SizedBox(width: tokens.spacing.sm),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(color: tokens.textMuted),
          ),
        ),
        SizedBox(width: tokens.spacing.sm),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class SchoolDeskAttentionItem {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  const SchoolDeskAttentionItem({
    required this.label,
    required this.value,
    required this.icon,
    this.color,
  });
}

class SchoolDeskAttentionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<SchoolDeskAttentionItem> items;
  final Widget? action;

  const SchoolDeskAttentionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.items,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;
    return SchoolDeskSectionCard(
      title: title,
      subtitle: subtitle,
      action: action,
      child: Wrap(
        spacing: tokens.spacing.sm,
        runSpacing: tokens.spacing.sm,
        children: [
          for (final item in items)
            _AttentionPill(
              label: item.label,
              value: item.value,
              icon: item.icon,
              color: item.color ?? theme.colorScheme.primary,
            ),
        ],
      ),
    );
  }
}

class _AttentionPill extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _AttentionPill({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;
    return Container(
      constraints: const BoxConstraints(minHeight: 46, minWidth: 148),
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.sm,
        vertical: tokens.spacing.sm,
      ),
      decoration: BoxDecoration(
        color: color.withAlpha(tokens.isDark ? 48 : 24),
        borderRadius: BorderRadius.circular(tokens.radius.control),
        border: Border.all(color: color.withAlpha(86)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          SizedBox(width: tokens.spacing.sm),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum SchoolDeskStatusTone { neutral, success, warning, danger, info }

class SchoolDeskStatusChip extends StatelessWidget {
  final String label;
  final SchoolDeskStatusTone tone;
  final IconData? icon;

  const SchoolDeskStatusChip({
    super.key,
    required this.label,
    this.tone = SchoolDeskStatusTone.neutral,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;
    final color = _chipColor(theme, tone);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.sm,
        vertical: tokens.spacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withAlpha(tokens.isDark ? 58 : 26),
        borderRadius: BorderRadius.circular(tokens.radius.pill),
        border: Border.all(color: color.withAlpha(82)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: color, size: 14),
            SizedBox(width: tokens.spacing.xs),
          ],
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class SchoolDeskResponsiveActions extends StatelessWidget {
  final List<Widget> primaryActions;
  final List<PopupMenuEntry<void>> overflowItems;
  final String overflowTooltip;

  const SchoolDeskResponsiveActions({
    super.key,
    this.primaryActions = const [],
    this.overflowItems = const [],
    this.overflowTooltip = 'More actions',
  });

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).schoolDesk;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 420;
        final visibleActions = compact && primaryActions.length > 1
            ? primaryActions.take(1).toList()
            : primaryActions;
        final showOverflow =
            overflowItems.isNotEmpty ||
            (compact && primaryActions.length > visibleActions.length);

        return Wrap(
          spacing: tokens.spacing.sm,
          runSpacing: tokens.spacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ...visibleActions,
            if (showOverflow)
              PopupMenuButton<void>(
                tooltip: overflowTooltip,
                itemBuilder: (_) => overflowItems,
                icon: const Icon(Icons.more_horiz_rounded),
              ),
          ],
        );
      },
    );
  }
}

class SchoolDeskIllustration extends StatelessWidget {
  final String asset;
  final double size;
  final String semanticLabel;

  const SchoolDeskIllustration({
    super.key,
    required this.asset,
    this.size = 132,
    required this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: semanticLabel,
      child: SvgPicture.asset(
        asset,
        width: size,
        height: size,
        fit: BoxFit.contain,
      ),
    );
  }
}

class SchoolDeskVisualPanel extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const SchoolDeskVisualPanel({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;
    return Container(
      padding: padding ?? EdgeInsets.all(tokens.spacing.md),
      decoration: BoxDecoration(
        color: tokens.panel,
        borderRadius: BorderRadius.circular(tokens.radius.card),
        border: Border.all(color: tokens.panelBorder),
        boxShadow: tokens.elevation.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          if (subtitle != null) ...[
            SizedBox(height: tokens.spacing.xs),
            Text(
              subtitle!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: tokens.textMuted,
              ),
            ),
          ],
          SizedBox(height: tokens.spacing.md),
          child,
        ],
      ),
    );
  }
}

class SchoolDeskVisualSummaryRecord extends StatelessWidget {
  final String title;
  final String subtitle;
  final String value;
  final IconData icon;
  final Color? color;
  final VoidCallback? onTap;
  final String? semanticLabel;

  const SchoolDeskVisualSummaryRecord({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.icon,
    this.color,
    this.onTap,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;
    final accent = color ?? theme.colorScheme.primary;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final minHeight = 96 * textScale.clamp(1.0, 1.18).toDouble();
    final card = Container(
      constraints: BoxConstraints(minHeight: minHeight),
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
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: accent.withAlpha(tokens.isDark ? 56 : 24),
              borderRadius: BorderRadius.circular(tokens.radius.control),
            ),
            child: Icon(icon, color: accent, size: 28),
          ),
          SizedBox(width: tokens.spacing.md),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: tokens.spacing.xs),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: tokens.textMuted,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: tokens.spacing.sm),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 116),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                value,
                maxLines: 1,
                textAlign: TextAlign.right,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    return Semantics(
      button: onTap != null,
      label: semanticLabel ?? '$title, $value, $subtitle',
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(tokens.radius.card),
          onTap: onTap,
          child: card,
        ),
      ),
    );
  }
}

class SchoolDeskVisualActionTile extends StatelessWidget {
  final String label;
  final String? subtitle;
  final IconData icon;
  final Color? color;
  final VoidCallback? onTap;
  final String? semanticLabel;

  const SchoolDeskVisualActionTile({
    super.key,
    required this.label,
    this.subtitle,
    required this.icon,
    this.color,
    this.onTap,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;
    final accent = color ?? theme.colorScheme.primary;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final minHeight = 112 * textScale.clamp(1.0, 1.2).toDouble();
    final tile = Container(
      constraints: BoxConstraints(minHeight: minHeight),
      padding: EdgeInsets.all(tokens.spacing.sm),
      decoration: BoxDecoration(
        color: tokens.panelMuted,
        borderRadius: BorderRadius.circular(tokens.radius.card),
        border: Border.all(color: tokens.panelBorder),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compactHeight =
              constraints.hasBoundedHeight && constraints.maxHeight < 104;
          final iconSize = compactHeight ? 42.0 : 48.0;
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: iconSize,
                height: iconSize,
                decoration: BoxDecoration(
                  color: accent.withAlpha(tokens.isDark ? 56 : 28),
                  borderRadius: BorderRadius.circular(tokens.radius.control),
                ),
                child: Icon(icon, color: accent, size: compactHeight ? 23 : 26),
              ),
              SizedBox(
                height: compactHeight ? tokens.spacing.xs : tokens.spacing.sm,
              ),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style:
                    (compactHeight
                            ? theme.textTheme.labelMedium
                            : theme.textTheme.labelLarge)
                        ?.copyWith(fontWeight: FontWeight.w800),
              ),
              if (subtitle != null) ...[
                SizedBox(height: compactHeight ? 2 : tokens.spacing.xs),
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: tokens.textMuted,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );

    return Semantics(
      button: onTap != null,
      label: semanticLabel ?? '$label${subtitle == null ? '' : ', $subtitle'}',
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(tokens.radius.card),
          onTap: onTap,
          child: tile,
        ),
      ),
    );
  }
}

class SchoolDeskIllustratedActionTile extends StatelessWidget {
  final String label;
  final String? subtitle;
  final String illustrationAsset;
  final Color? color;
  final VoidCallback? onTap;
  final String? semanticLabel;

  const SchoolDeskIllustratedActionTile({
    super.key,
    required this.label,
    this.subtitle,
    required this.illustrationAsset,
    this.color,
    this.onTap,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;
    final accent = color ?? theme.colorScheme.primary;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final responsiveScale = textScale.clamp(1.0, 1.25).toDouble();
    final minHeight = 152 * responsiveScale;

    final tile = AnimatedContainer(
      duration: tokens.motion.fast,
      curve: tokens.motion.curve,
      constraints: BoxConstraints(minHeight: minHeight),
      padding: EdgeInsets.all(tokens.spacing.sm + tokens.spacing.xs),
      decoration: BoxDecoration(
        color: tokens.panel,
        borderRadius: BorderRadius.circular(tokens.radius.card),
        border: Border.all(color: tokens.panelBorder),
        boxShadow: onTap == null ? null : tokens.elevation.card,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compactHeight =
              constraints.hasBoundedHeight && constraints.maxHeight < 150;
          final compact = compactHeight || textScale > 1.25;
          final imageSize = compact ? 50.0 : 58.0;
          final imageBackplateWidth = imageSize + 24;
          final imageBackplateHeight = imageSize + 16;

          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: imageBackplateWidth,
                height: imageBackplateHeight,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: imageBackplateWidth,
                      height: imageBackplateHeight,
                      decoration: BoxDecoration(
                        color: accent.withAlpha(tokens.isDark ? 48 : 24),
                        borderRadius: BorderRadius.circular(
                          tokens.radius.control,
                        ),
                      ),
                    ),
                    SvgPicture.asset(
                      illustrationAsset,
                      width: imageSize,
                      height: imageSize,
                      fit: BoxFit.contain,
                    ),
                  ],
                ),
              ),
              SizedBox(height: compact ? tokens.spacing.xs : tokens.spacing.sm),
              Text(
                label,
                maxLines: compact ? 1 : 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (subtitle != null) ...[
                SizedBox(height: compact ? 2 : tokens.spacing.xs),
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: tokens.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );

    return Semantics(
      button: onTap != null,
      label: semanticLabel ?? '$label${subtitle == null ? '' : ', $subtitle'}',
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(tokens.radius.card),
          onTap: onTap,
          child: tile,
        ),
      ),
    );
  }
}

class SchoolDeskKpiCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color? color;
  final String? semanticLabel;
  final VoidCallback? onTap;

  const SchoolDeskKpiCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    required this.icon,
    this.color,
    this.semanticLabel,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;
    final accent = color ?? theme.colorScheme.primary;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final responsiveScale = textScale.clamp(1.0, 1.25).toDouble();
    final card = AnimatedContainer(
      duration: tokens.motion.fast,
      constraints: BoxConstraints(minHeight: 96 * responsiveScale),
      padding: EdgeInsets.all(tokens.spacing.md),
      decoration: BoxDecoration(
        color: tokens.panel,
        borderRadius: BorderRadius.circular(tokens.radius.card),
        border: Border.all(color: tokens.panelBorder),
        boxShadow: tokens.elevation.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accent.withAlpha(tokens.isDark ? 46 : 26),
                  borderRadius: BorderRadius.circular(tokens.radius.control),
                ),
                child: Icon(icon, color: accent, size: 20),
              ),
              const Spacer(),
              Flexible(
                child: FittedBox(
                  alignment: Alignment.centerRight,
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: theme.textTheme.headlineSmall,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: tokens.spacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge,
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: tokens.textMuted,
                  ),
                ),
            ],
          ),
        ],
      ),
    );

    return Semantics(
      label:
          semanticLabel ??
          '$title $value${subtitle == null ? '' : ', $subtitle'}',
      button: onTap != null,
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(tokens.radius.card),
          child: card,
        ),
      ),
    );
  }
}

class FeatureUnavailablePanel extends StatelessWidget {
  final FeatureAvailabilityState state;

  const FeatureUnavailablePanel({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;
    return Container(
      padding: EdgeInsets.all(tokens.spacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withAlpha(
          tokens.isDark ? 80 : 96,
        ),
        borderRadius: BorderRadius.circular(tokens.radius.card),
        border: Border.all(color: theme.colorScheme.error.withAlpha(80)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_clock_rounded, color: theme.colorScheme.error),
          SizedBox(width: tokens.spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Backend not ready', style: theme.textTheme.titleSmall),
                SizedBox(height: tokens.spacing.xs),
                Text(
                  '${state.label}: ${state.reason ?? 'This workflow is unavailable.'}',
                  style: theme.textTheme.bodySmall,
                ),
                if (state.recommendedAction != null) ...[
                  SizedBox(height: tokens.spacing.xs),
                  Text(
                    state.recommendedAction!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SchoolDeskResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final double minTileWidth;
  final double spacing;
  final double? mainAxisExtent;

  const SchoolDeskResponsiveGrid({
    super.key,
    required this.children,
    this.minTileWidth = 220,
    this.spacing = 12,
    this.mainAxisExtent,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = (constraints.maxWidth / minTileWidth).floor().clamp(
          1,
          6,
        );
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final responsiveScale = (1 + ((textScale - 1) * 1.4))
            .clamp(1.0, 1.5)
            .toDouble();
        final effectiveMainAxisExtent = mainAxisExtent == null
            ? null
            : mainAxisExtent! * responsiveScale;
        return GridView.count(
          crossAxisCount: columns,
          mainAxisSpacing: spacing,
          crossAxisSpacing: spacing,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: effectiveMainAxisExtent == null
              ? 1.8
              : (constraints.maxWidth / columns) / effectiveMainAxisExtent,
          children: children,
        );
      },
    );
  }
}

class SchoolDeskPageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;

  const SchoolDeskPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;
    return Padding(
      padding: EdgeInsets.only(bottom: tokens.spacing.md),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: tokens.spacing.md,
        runSpacing: tokens.spacing.sm,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.headlineMedium),
                if (subtitle != null) ...[
                  SizedBox(height: tokens.spacing.xs),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: tokens.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (actions.isNotEmpty)
            Wrap(
              spacing: tokens.spacing.sm,
              runSpacing: tokens.spacing.sm,
              children: actions,
            ),
        ],
      ),
    );
  }
}

class SchoolDeskDataToolbar extends StatelessWidget {
  final String searchLabel;
  final ValueChanged<String>? onSearchChanged;
  final VoidCallback? onFilter;
  final VoidCallback? onExport;
  final List<Widget> actions;

  const SchoolDeskDataToolbar({
    super.key,
    this.searchLabel = 'Search',
    this.onSearchChanged,
    this.onFilter,
    this.onExport,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;
    return Wrap(
      spacing: tokens.spacing.sm,
      runSpacing: tokens.spacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 220, maxWidth: 420),
          child: TextField(
            onChanged: onSearchChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              labelText: searchLabel,
              prefixIcon: const Icon(Icons.search_rounded),
            ),
          ),
        ),
        if (onFilter != null)
          OutlinedButton.icon(
            onPressed: onFilter,
            icon: const Icon(Icons.tune_rounded, size: 18),
            label: const Text('Filters'),
          ),
        if (onExport != null)
          OutlinedButton.icon(
            onPressed: onExport,
            icon: const Icon(Icons.download_rounded, size: 18),
            label: const Text('Export'),
          ),
        ...actions,
      ],
    );
  }
}

enum SchoolDeskStatusKind { loading, empty, error, permission, offline }

class SchoolDeskStatusPanel extends StatelessWidget {
  final SchoolDeskStatusKind kind;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? illustrationAsset;

  const SchoolDeskStatusPanel.loading({
    super.key,
    this.message = 'Loading',
    this.illustrationAsset,
  }) : kind = SchoolDeskStatusKind.loading,
       title = 'Loading',
       actionLabel = null,
       onAction = null;

  const SchoolDeskStatusPanel.empty({
    super.key,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.illustrationAsset = SchoolDeskUiIllustrations.emptyState,
  }) : kind = SchoolDeskStatusKind.empty;

  const SchoolDeskStatusPanel.error({
    super.key,
    required this.title,
    required this.message,
    this.actionLabel = 'Retry',
    this.onAction,
    this.illustrationAsset,
  }) : kind = SchoolDeskStatusKind.error;

  const SchoolDeskStatusPanel.permission({
    super.key,
    this.title = 'Permission required',
    required this.message,
    this.illustrationAsset,
  }) : kind = SchoolDeskStatusKind.permission,
       actionLabel = null,
       onAction = null;

  const SchoolDeskStatusPanel.offline({
    super.key,
    this.title = 'You are offline',
    required this.message,
    this.actionLabel = 'Try again',
    this.onAction,
    this.illustrationAsset,
  }) : kind = SchoolDeskStatusKind.offline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;
    final icon = switch (kind) {
      SchoolDeskStatusKind.loading => Icons.autorenew_rounded,
      SchoolDeskStatusKind.empty => Icons.inbox_rounded,
      SchoolDeskStatusKind.error => Icons.error_outline_rounded,
      SchoolDeskStatusKind.permission => Icons.lock_outline_rounded,
      SchoolDeskStatusKind.offline => Icons.cloud_off_rounded,
    };
    final tone = switch (kind) {
      SchoolDeskStatusKind.loading => theme.colorScheme.primary,
      SchoolDeskStatusKind.empty => tokens.textMuted,
      SchoolDeskStatusKind.error => theme.colorScheme.error,
      SchoolDeskStatusKind.permission => theme.colorScheme.error,
      SchoolDeskStatusKind.offline => theme.colorScheme.secondary,
    };

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(tokens.spacing.lg),
      decoration: BoxDecoration(
        color: tokens.panel,
        borderRadius: BorderRadius.circular(tokens.radius.card),
        border: Border.all(color: tokens.panelBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (kind == SchoolDeskStatusKind.loading)
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: tone),
            )
          else if (illustrationAsset != null)
            SchoolDeskIllustration(
              asset: illustrationAsset!,
              size: 84,
              semanticLabel: title,
            )
          else
            Icon(icon, color: tone, size: 32),
          SizedBox(height: tokens.spacing.sm),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
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
            SizedBox(height: tokens.spacing.md),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

Color _chipColor(ThemeData theme, SchoolDeskStatusTone tone) {
  return switch (tone) {
    SchoolDeskStatusTone.success => const Color(0xFF15803D),
    SchoolDeskStatusTone.warning => const Color(0xFFB45309),
    SchoolDeskStatusTone.danger => theme.colorScheme.error,
    SchoolDeskStatusTone.info => theme.colorScheme.primary,
    SchoolDeskStatusTone.neutral => theme.colorScheme.onSurfaceVariant,
  };
}

class SchoolDeskBreadcrumbs extends StatelessWidget {
  final List<String> items;

  const SchoolDeskBreadcrumbs({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;
    return Semantics(
      label: 'Breadcrumb ${items.join(' / ')}',
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: tokens.spacing.xs,
        runSpacing: tokens.spacing.xs,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            Text(
              items[i],
              style: theme.textTheme.labelMedium?.copyWith(
                color: i == items.length - 1
                    ? theme.colorScheme.onSurface
                    : tokens.textMuted,
              ),
            ),
            if (i < items.length - 1)
              Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: tokens.textMuted,
              ),
          ],
        ],
      ),
    );
  }
}
