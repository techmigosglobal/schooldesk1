import 'package:flutter/material.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:schooldesk1/core/services/feature_availability_service.dart';
import 'package:schooldesk1/core/theme/design_tokens.dart';

class SchoolDeskAdaptiveText extends StatelessWidget {
  final String data;
  final TextStyle? style;
  final int maxLines;
  final TextAlign? textAlign;
  final TextOverflow overflow;
  final double? minFontSize;
  final bool softWrap;
  final bool wrapWords;
  final String? semanticsLabel;

  const SchoolDeskAdaptiveText(
    this.data, {
    super.key,
    this.style,
    this.maxLines = 1,
    this.textAlign,
    this.overflow = TextOverflow.ellipsis,
    this.minFontSize,
    this.softWrap = true,
    this.wrapWords = true,
    this.semanticsLabel,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = DefaultTextStyle.of(context).style.merge(style);
    final baseSize = effectiveStyle.fontSize ?? 14;
    final rawMin = minFontSize ?? (baseSize * 0.72).clamp(9.5, baseSize);
    final adaptiveMin = (rawMin * 2).roundToDouble() / 2;
    return AutoSizeText(
      data,
      style: effectiveStyle,
      maxLines: maxLines,
      minFontSize: adaptiveMin.toDouble(),
      stepGranularity: 0.5,
      textAlign: textAlign,
      overflow: overflow,
      softWrap: softWrap,
      wrapWords: wrapWords,
      semanticsLabel: semanticsLabel,
    );
  }
}

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

class SchoolDeskCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? color;
  final bool elevated;
  final String? semanticLabel;

  const SchoolDeskCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.color,
    this.elevated = true,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).schoolDesk;
    final content = Container(
      padding: padding ?? EdgeInsets.all(tokens.spacing.md),
      decoration: BoxDecoration(
        color: color ?? tokens.panel,
        borderRadius: BorderRadius.circular(tokens.radius.card),
        border: Border.all(color: tokens.panelBorder),
        boxShadow: elevated ? tokens.elevation.card : null,
      ),
      child: child,
    );

    if (onTap == null) {
      return Semantics(
        label: semanticLabel,
        container: semanticLabel != null,
        child: content,
      );
    }

    return Semantics(
      label: semanticLabel,
      button: true,
      onTap: onTap,
      excludeSemantics: semanticLabel != null,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(tokens.radius.card),
        child: InkWell(
          borderRadius: BorderRadius.circular(tokens.radius.card),
          onTap: onTap,
          child: content,
        ),
      ),
    );
  }
}

class SchoolDeskIconContainer extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final double? size;
  final double? iconSize;
  final Widget? child;

  const SchoolDeskIconContainer({
    super.key,
    required this.icon,
    this.color,
    this.size,
    this.iconSize,
    this.child,
  });

  const SchoolDeskIconContainer.compact({
    super.key,
    required this.icon,
    this.color,
    this.child,
  }) : size = null,
       iconSize = 24;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;
    final accent = color ?? theme.colorScheme.primary;
    final dimension = size ?? tokens.sizing.iconContainer;
    return SizedBox.square(
      dimension: dimension,
      child: Container(
        decoration: BoxDecoration(
          color: accent.withAlpha(tokens.isDark ? 54 : 28),
          borderRadius: BorderRadius.circular(tokens.radius.control),
        ),
        child:
            child ??
            Icon(icon, color: accent, size: iconSize ?? dimension * 0.55),
      ),
    );
  }
}

class SchoolDeskSectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? action;

  const SchoolDeskSectionTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SchoolDeskAdaptiveText(
                title,
                maxLines: 2,
                style: theme.textTheme.headlineMedium,
              ),
              if (subtitle != null) ...[
                SizedBox(height: tokens.spacing.xs),
                SchoolDeskAdaptiveText(
                  subtitle!,
                  maxLines: 3,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: tokens.textMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (action != null) ...[SizedBox(width: tokens.spacing.sm), action!],
      ],
    );
  }
}

enum SchoolDeskButtonStyle { filled, outlined, text }

class SchoolDeskButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final SchoolDeskButtonStyle style;
  final bool expand;

  const SchoolDeskButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.style = SchoolDeskButtonStyle.filled,
    this.expand = false,
  });

  const SchoolDeskButton.outlined({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = false,
  }) : style = SchoolDeskButtonStyle.outlined;

  const SchoolDeskButton.text({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = false,
  }) : style = SchoolDeskButtonStyle.text;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).schoolDesk;
    final child = icon == null
        ? SchoolDeskAdaptiveText(
            label,
            maxLines: 1,
            textAlign: TextAlign.center,
            minFontSize: 10.5,
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20),
              SizedBox(width: tokens.spacing.sm),
              Flexible(
                child: SchoolDeskAdaptiveText(
                  label,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  minFontSize: 10.5,
                ),
              ),
            ],
          );
    final button = switch (style) {
      SchoolDeskButtonStyle.filled => FilledButton(
        onPressed: onPressed,
        child: child,
      ),
      SchoolDeskButtonStyle.outlined => OutlinedButton(
        onPressed: onPressed,
        child: child,
      ),
      SchoolDeskButtonStyle.text => TextButton(
        onPressed: onPressed,
        child: child,
      ),
    };

    return ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: tokens.sizing.buttonHeight,
        minWidth: expand ? double.infinity : tokens.sizing.buttonHeight,
      ),
      child: expand ? SizedBox(width: double.infinity, child: button) : button,
    );
  }
}

class SchoolDeskTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? initialValue;
  final String label;
  final String? hint;
  final IconData? prefixIcon;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;
  final bool obscureText;
  final int maxLines;

  const SchoolDeskTextField({
    super.key,
    this.controller,
    this.initialValue,
    required this.label,
    this.hint,
    this.prefixIcon,
    this.suffix,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.validator,
    this.obscureText = false,
    this.maxLines = 1,
  }) : assert(controller == null || initialValue == null);

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).schoolDesk;
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: tokens.sizing.formFieldHeight),
      child: TextFormField(
        controller: controller,
        initialValue: initialValue,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        onChanged: onChanged,
        validator: validator,
        obscureText: obscureText,
        maxLines: obscureText ? 1 : maxLines,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: prefixIcon == null ? null : Icon(prefixIcon, size: 20),
          suffixIcon: suffix,
        ),
      ),
    );
  }
}

class SchoolDeskSearchBar extends StatelessWidget {
  final String label;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final bool autofocus;

  const SchoolDeskSearchBar({
    super.key,
    this.label = 'Search',
    this.controller,
    this.onChanged,
    this.onClear,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).schoolDesk;
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: tokens.sizing.searchBarHeight),
      child: TextField(
        controller: controller,
        autofocus: autofocus,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.search_rounded, size: 20),
          suffixIcon: onClear == null
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  onPressed: onClear,
                  icon: const Icon(Icons.close_rounded),
                ),
        ),
      ),
    );
  }
}

class SchoolDeskStatBox extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;
  final String? caption;
  final VoidCallback? onTap;
  final String? semanticLabel;

  const SchoolDeskStatBox({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color,
    this.caption,
    this.onTap,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;
    final accent = color ?? theme.colorScheme.primary;
    return SchoolDeskCard(
      onTap: onTap,
      semanticLabel: semanticLabel ?? '$label $value',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SchoolDeskIconContainer(
                icon: icon,
                color: accent,
                size: tokens.sizing.compactIconContainer,
              ),
              const Spacer(),
              if (caption != null)
                Flexible(
                  child: SchoolDeskAdaptiveText(
                    caption!,
                    maxLines: 1,
                    textAlign: TextAlign.end,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: tokens.textMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: tokens.spacing.md),
          SchoolDeskAdaptiveText(
            value,
            maxLines: 1,
            minFontSize: 12,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          SizedBox(height: tokens.spacing.xs),
          SchoolDeskAdaptiveText(
            label,
            maxLines: 2,
            style: theme.textTheme.bodySmall?.copyWith(
              color: tokens.textMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class SchoolDeskListTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? leadingIcon;
  final Widget? trailing;
  final VoidCallback? onTap;

  const SchoolDeskListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leadingIcon,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(tokens.radius.control),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(tokens.radius.control),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: tokens.spacing.md,
            vertical: tokens.spacing.sm,
          ),
          child: Row(
            children: [
              if (leadingIcon != null) ...[
                SchoolDeskIconContainer(
                  icon: leadingIcon!,
                  size: tokens.sizing.compactIconContainer,
                ),
                SizedBox(width: tokens.spacing.md),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SchoolDeskAdaptiveText(
                      title,
                      maxLines: SchoolDeskResponsive.textScaleOf(context) > 1.2
                          ? 2
                          : 1,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (subtitle != null) ...[
                      SizedBox(height: tokens.spacing.xs),
                      SchoolDeskAdaptiveText(
                        subtitle!,
                        maxLines: 2,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: tokens.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                SizedBox(width: tokens.spacing.sm),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

@immutable
class SchoolDeskBottomNavItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final bool selected;
  final int badgeCount;
  final VoidCallback onTap;

  const SchoolDeskBottomNavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.selected,
    required this.onTap,
    this.badgeCount = 0,
  });
}

class SchoolDeskBottomNavigationBar extends StatelessWidget {
  final List<SchoolDeskBottomNavItem> items;

  const SchoolDeskBottomNavigationBar({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;
    return SafeArea(
      top: false,
      child: Material(
        color: tokens.panel,
        elevation: 10,
        shadowColor: Colors.black.withAlpha(24),
        child: Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: tokens.panelBorder)),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: tokens.spacing.xs,
            vertical: tokens.spacing.xs,
          ),
          child: Row(
            children: [
              for (final item in items)
                Expanded(child: _SchoolDeskBottomNavButton(item: item)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SchoolDeskBottomNavButton extends StatelessWidget {
  final SchoolDeskBottomNavItem item;

  const _SchoolDeskBottomNavButton({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;
    final textScale = SchoolDeskResponsive.textScaleOf(context);
    final minHeight = SchoolDeskResponsive.bottomNavigationHeightForTextScale(
      tokens,
      textScale,
    );
    final color = item.selected ? theme.colorScheme.primary : tokens.textMuted;
    final icon = AnimatedSwitcher(
      duration: tokens.motion.fast,
      switchInCurve: tokens.motion.curve,
      switchOutCurve: tokens.motion.curve,
      child: Icon(
        item.selected ? item.activeIcon : item.icon,
        key: ValueKey('${item.label}-${item.selected}'),
        color: color,
        size: 24,
      ),
    );

    return Semantics(
      button: true,
      selected: item.selected,
      label: item.label,
      child: InkWell(
        borderRadius: BorderRadius.circular(tokens.radius.control),
        onTap: item.onTap,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: minHeight),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: tokens.spacing.xs),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                item.badgeCount > 0
                    ? Badge.count(
                        count: item.badgeCount > 99 ? 99 : item.badgeCount,
                        child: icon,
                      )
                    : icon,
                SizedBox(height: tokens.spacing.xs),
                Flexible(
                  child: AnimatedDefaultTextStyle(
                    duration: tokens.motion.fast,
                    curve: tokens.motion.curve,
                    style:
                        theme.textTheme.labelSmall?.copyWith(
                          color: color,
                          fontWeight: item.selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          height: 1.05,
                        ) ??
                        TextStyle(color: color),
                    child: SchoolDeskAdaptiveText(
                      item.label,
                      maxLines: textScale > 1.2 ? 2 : 1,
                      textAlign: TextAlign.center,
                      minFontSize: 9,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SchoolDeskAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget? leading;

  const SchoolDeskAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.leading,
  });

  @override
  Size get preferredSize =>
      Size.fromHeight(SchoolDeskSizing.standard.appBarHeight);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;
    return AppBar(
      toolbarHeight: tokens.sizing.appBarHeight,
      leading: leading,
      titleSpacing: tokens.spacing.md,
      actions: actions,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SchoolDeskAdaptiveText(
            title,
            maxLines: 1,
            minFontSize: 11,
            style: Theme.of(context).appBarTheme.titleTextStyle,
          ),
          if (subtitle != null) ...[
            SizedBox(height: tokens.spacing.xs),
            SchoolDeskAdaptiveText(
              subtitle!,
              maxLines: 1,
              minFontSize: 9.5,
              style: theme.textTheme.bodySmall?.copyWith(
                color: tokens.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class SchoolDeskBottomSheet extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final List<Widget> actions;

  const SchoolDeskBottomSheet({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          tokens.spacing.md,
          tokens.spacing.sm,
          tokens.spacing.md,
          tokens.spacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: tokens.sizing.iconContainer,
                height: tokens.spacing.xs,
                decoration: BoxDecoration(
                  color: tokens.panelBorder,
                  borderRadius: BorderRadius.circular(tokens.radius.pill),
                ),
              ),
            ),
            SizedBox(height: tokens.spacing.md),
            SchoolDeskSectionTitle(title: title, subtitle: subtitle),
            SizedBox(height: tokens.spacing.md),
            Flexible(child: SingleChildScrollView(child: child)),
            if (actions.isNotEmpty) ...[
              SizedBox(height: tokens.spacing.md),
              SchoolDeskResponsiveActions(primaryActions: actions),
            ],
          ],
        ),
      ),
    );
  }
}

Future<T?> showSchoolDeskBottomSheet<T>({
  required BuildContext context,
  required String title,
  required Widget child,
  String? subtitle,
  List<Widget> actions = const [],
}) {
  final tokens = Theme.of(context).schoolDesk;
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: tokens.panel,
    constraints: BoxConstraints(maxWidth: tokens.sizing.bottomSheetMaxWidth),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(tokens.radius.sheet),
      ),
    ),
    builder: (context) => SchoolDeskBottomSheet(
      title: title,
      subtitle: subtitle,
      actions: actions,
      child: child,
    ),
  );
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
    return SchoolDeskCard(
      padding: padding ?? EdgeInsets.all(tokens.spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SchoolDeskSectionTitle(
            title: title,
            subtitle: subtitle,
            action: action,
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
    final textScale = SchoolDeskResponsive.textScaleOf(context);
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
          final iconSize = compact
              ? tokens.sizing.compactIconContainer
              : tokens.sizing.iconContainer;
          final labelMaxLines = compactHeight ? 1 : 2;
          final subtitleMaxLines = compact ? 1 : 2;

          return Padding(
            padding: tilePadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SchoolDeskIconContainer(
                      icon: icon,
                      color: accent,
                      size: iconSize,
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
                      SchoolDeskAdaptiveText(
                        label,
                        maxLines: labelMaxLines,
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (subtitle != null) ...[
                        SizedBox(height: tokens.spacing.xs),
                        Flexible(
                          child: SchoolDeskAdaptiveText(
                            subtitle!,
                            maxLines: subtitleMaxLines,
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
        SchoolDeskIconContainer(
          icon: icon,
          color: accent,
          size: tokens.sizing.compactIconContainer,
          iconSize: 20,
        ),
        SizedBox(width: tokens.spacing.sm),
        Expanded(
          child: SchoolDeskAdaptiveText(
            label,
            maxLines: 1,
            style: theme.textTheme.bodySmall?.copyWith(color: tokens.textMuted),
          ),
        ),
        SizedBox(width: tokens.spacing.sm),
        Flexible(
          child: SchoolDeskAdaptiveText(
            value,
            textAlign: TextAlign.end,
            maxLines: 1,
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
                SchoolDeskAdaptiveText(
                  value,
                  maxLines: 1,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SchoolDeskAdaptiveText(
                  label,
                  maxLines: 1,
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
          SchoolDeskAdaptiveText(
            label,
            maxLines: 1,
            minFontSize: 9,
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
          SchoolDeskAdaptiveText(
            title,
            maxLines: 2,
            style: theme.textTheme.titleMedium,
          ),
          if (subtitle != null) ...[
            SizedBox(height: tokens.spacing.xs),
            SchoolDeskAdaptiveText(
              subtitle!,
              maxLines: 3,
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
    final textScale = SchoolDeskResponsive.textScaleOf(context);
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
                SchoolDeskAdaptiveText(
                  title,
                  maxLines: 1,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: tokens.spacing.xs),
                SchoolDeskAdaptiveText(
                  subtitle,
                  maxLines: 1,
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
              child: SchoolDeskAdaptiveText(
                value,
                maxLines: 1,
                textAlign: TextAlign.right,
                minFontSize: 12,
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
    final textScale = SchoolDeskResponsive.textScaleOf(context);
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
              SchoolDeskAdaptiveText(
                label,
                maxLines: compactHeight ? 1 : 2,
                textAlign: TextAlign.center,
                style:
                    (compactHeight
                            ? theme.textTheme.labelMedium
                            : theme.textTheme.labelLarge)
                        ?.copyWith(fontWeight: FontWeight.w800),
              ),
              if (subtitle != null) ...[
                SizedBox(height: compactHeight ? 2 : tokens.spacing.xs),
                SchoolDeskAdaptiveText(
                  subtitle!,
                  maxLines: 1,
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
    final textScale = SchoolDeskResponsive.textScaleOf(context);
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
              SchoolDeskAdaptiveText(
                label,
                maxLines: compact ? 1 : 2,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (subtitle != null) ...[
                SizedBox(height: compact ? 2 : tokens.spacing.xs),
                SchoolDeskAdaptiveText(
                  subtitle!,
                  maxLines: 1,
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

    return SchoolDeskCard(
      onTap: onTap,
      semanticLabel:
          semanticLabel ??
          '$title $value${subtitle == null ? '' : ', $subtitle'}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              SchoolDeskIconContainer(
                icon: icon,
                color: accent,
                size: tokens.sizing.compactIconContainer,
                iconSize: 20,
              ),
              SizedBox(width: tokens.spacing.sm),
              Expanded(
                child: SizedBox(
                  height: tokens.sizing.compactIconContainer,
                  child: FittedBox(
                    alignment: Alignment.centerRight,
                    fit: BoxFit.scaleDown,
                    child: SchoolDeskAdaptiveText(
                      value,
                      maxLines: 1,
                      textAlign: TextAlign.end,
                      minFontSize: 12,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: tokens.spacing.xs),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SchoolDeskAdaptiveText(
                title,
                maxLines: 1,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  height: 1.05,
                ),
              ),
              if (subtitle != null) ...[
                SizedBox(height: tokens.spacing.xs),
                SchoolDeskAdaptiveText(
                  subtitle!,
                  maxLines: 1,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: tokens.textMuted,
                    height: 1.05,
                  ),
                ),
              ],
            ],
          ),
        ],
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
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final standardColumns = SchoolDeskResponsive.gridColumnsForWidth(width);
        final widthBasedColumns = (width / minTileWidth).floor().clamp(1, 6);
        final narrowPhone = width < 340;
        final columns = narrowPhone
            ? 1
            : standardColumns.clamp(2, widthBasedColumns.clamp(2, 6)).toInt();
        final textScale = SchoolDeskResponsive.textScaleOf(context);
        final responsiveScale = (1 + ((textScale - 1) * 1.4))
            .clamp(1.0, 1.3)
            .toDouble();
        final effectiveMainAxisExtent =
            (mainAxisExtent ?? 156) * responsiveScale;
        return GridView.count(
          crossAxisCount: columns,
          mainAxisSpacing: spacing,
          crossAxisSpacing: spacing,
          mainAxisExtent: effectiveMainAxisExtent,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : MediaQuery.sizeOf(context).width;
          final stacked = width < 620;
          final heading = ConstrainedBox(
            constraints: BoxConstraints(maxWidth: stacked ? width : 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SchoolDeskAdaptiveText(
                  title,
                  maxLines: stacked ? 3 : 2,
                  style: theme.textTheme.headlineMedium,
                ),
                if (subtitle != null) ...[
                  SizedBox(height: tokens.spacing.xs),
                  SchoolDeskAdaptiveText(
                    subtitle!,
                    maxLines: stacked ? 4 : 3,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: tokens.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          );
          final actionTray = actions.isEmpty
              ? const SizedBox.shrink()
              : Wrap(
                  spacing: tokens.spacing.sm,
                  runSpacing: tokens.spacing.sm,
                  children: actions,
                );
          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                heading,
                if (actions.isNotEmpty) ...[
                  SizedBox(height: tokens.spacing.sm),
                  actionTray,
                ],
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: heading),
              if (actions.isNotEmpty) ...[
                SizedBox(width: tokens.spacing.md),
                Flexible(
                  child: Align(
                    alignment: Alignment.topRight,
                    child: actionTray,
                  ),
                ),
              ],
            ],
          );
        },
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final searchWidth = width < 520
            ? width
            : (width * 0.48).clamp(220.0, 420.0);
        return Wrap(
          spacing: tokens.spacing.sm,
          runSpacing: tokens.spacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: searchWidth.toDouble(),
              child: SchoolDeskSearchBar(
                label: searchLabel,
                onChanged: onSearchChanged,
              ),
            ),
            if (onFilter != null)
              SchoolDeskButton.outlined(
                label: 'Filters',
                icon: Icons.tune_rounded,
                onPressed: onFilter,
              ),
            if (onExport != null)
              SchoolDeskButton.outlined(
                label: 'Export',
                icon: Icons.download_rounded,
                onPressed: onExport,
              ),
            ...actions,
          ],
        );
      },
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
          SchoolDeskAdaptiveText(
            title,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: theme.textTheme.titleMedium,
          ),
          SizedBox(height: tokens.spacing.xs),
          SchoolDeskAdaptiveText(
            message,
            textAlign: TextAlign.center,
            maxLines: 5,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: tokens.textMuted,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            SizedBox(height: tokens.spacing.md),
            SchoolDeskButton(label: actionLabel!, onPressed: onAction),
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
            SchoolDeskAdaptiveText(
              items[i],
              maxLines: 1,
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
