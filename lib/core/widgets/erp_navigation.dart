import 'package:flutter/material.dart';

import 'package:schooldesk1/routes/schooldesk_screen_registry.dart';
import 'package:schooldesk1/core/services/feature_availability_service.dart';
import 'package:schooldesk1/core/theme/design_tokens.dart';
import 'package:schooldesk1/core/widgets/erp_components.dart';

@immutable
class SchoolDeskNavigationSection {
  final String label;
  final List<SchoolDeskNavigationItem> items;

  const SchoolDeskNavigationSection({required this.label, required this.items});
}

@immutable
class SchoolDeskNavigationItem {
  final int index;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String? route;
  final Object? arguments;
  final int badgeCount;
  final bool enabled;
  final String? disabledReason;
  final bool resetStack;

  const SchoolDeskNavigationItem({
    required this.index,
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.route,
    this.arguments,
    this.badgeCount = 0,
    this.enabled = true,
    this.disabledReason,
    this.resetStack = true,
  });
}

@immutable
class SchoolDeskNavigationFooterAction {
  final IconData icon;
  final String label;
  final Color? color;
  final String? route;
  final Object? arguments;
  final int badgeCount;
  final bool resetStack;
  final void Function(BuildContext context)? onPressed;

  const SchoolDeskNavigationFooterAction({
    required this.icon,
    required this.label,
    this.color,
    this.route,
    this.arguments,
    this.badgeCount = 0,
    this.resetStack = false,
    this.onPressed,
  });
}

class SchoolDeskNavigationDrawer extends StatelessWidget {
  final SchoolDeskRole role;
  final String portalLabel;
  final String organizationName;
  final String organizationSubtitle;
  final String userName;
  final String userSubtitle;
  final String initials;
  final IconData portalIcon;
  final Widget? organizationLogo;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<SchoolDeskNavigationSection> sections;
  final List<SchoolDeskNavigationFooterAction> footerActions;
  final double width;

  const SchoolDeskNavigationDrawer({
    super.key,
    required this.role,
    required this.portalLabel,
    required this.organizationName,
    required this.organizationSubtitle,
    required this.userName,
    required this.userSubtitle,
    required this.initials,
    required this.portalIcon,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.sections,
    this.organizationLogo,
    this.footerActions = const [],
    this.width = 304,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;

    return Drawer(
      width: width,
      backgroundColor: tokens.panel,
      child: SafeArea(
        child: FocusTraversalGroup(
          policy: ReadingOrderTraversalPolicy(),
          child: Semantics(
            container: true,
            label: '$portalLabel navigation',
            child: Column(
              children: [
                _NavigationHeader(
                  role: role,
                  portalLabel: portalLabel,
                  organizationName: organizationName,
                  organizationSubtitle: organizationSubtitle,
                  userName: userName,
                  userSubtitle: userSubtitle,
                  initials: initials,
                  portalIcon: portalIcon,
                  organizationLogo: organizationLogo,
                ),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      tokens.spacing.sm,
                      tokens.spacing.sm,
                      tokens.spacing.sm,
                      tokens.spacing.md,
                    ),
                    children: [
                      for (final section in sections) ...[
                        _NavigationSectionLabel(label: section.label),
                        for (final item in section.items)
                          _NavigationItemTile(
                            role: role,
                            item: item,
                            isSelected: selectedIndex == item.index,
                            onSelected: onDestinationSelected,
                          ),
                        SizedBox(height: tokens.spacing.sm),
                      ],
                    ],
                  ),
                ),
                if (footerActions.isNotEmpty)
                  _NavigationFooter(actions: footerActions),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavigationHeader extends StatelessWidget {
  final SchoolDeskRole role;
  final String portalLabel;
  final String organizationName;
  final String organizationSubtitle;
  final String userName;
  final String userSubtitle;
  final String initials;
  final IconData portalIcon;
  final Widget? organizationLogo;

  const _NavigationHeader({
    required this.role,
    required this.portalLabel,
    required this.organizationName,
    required this.organizationSubtitle,
    required this.userName,
    required this.userSubtitle,
    required this.initials,
    required this.portalIcon,
    this.organizationLogo,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;
    final roleColor = tokens.roleColor(role);
    final onRoleColor = _bestTextColor(roleColor);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        tokens.spacing.md,
        tokens.spacing.lg,
        tokens.spacing.md,
        tokens.spacing.md,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            roleColor,
            Color.alphaBlend(
              theme.colorScheme.primary.withAlpha(tokens.isDark ? 72 : 44),
              roleColor,
            ),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SchoolDeskAdaptiveText(
            portalLabel,
            maxLines: 1,
            minFontSize: 10.5,
            style: theme.textTheme.labelLarge?.copyWith(
              color: onRoleColor,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: tokens.spacing.sm),
          Row(
            children: [
              _HeaderIcon(
                icon: portalIcon,
                roleColor: roleColor,
                child: organizationLogo,
              ),
              SizedBox(width: tokens.spacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SchoolDeskAdaptiveText(
                      organizationName,
                      maxLines: 1,
                      minFontSize: 11,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: onRoleColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: tokens.spacing.xs),
                    SchoolDeskAdaptiveText(
                      organizationSubtitle,
                      maxLines: 1,
                      minFontSize: 9.5,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: onRoleColor.withAlpha(210),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: tokens.spacing.md),
          Container(
            padding: EdgeInsets.all(tokens.spacing.sm),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(tokens.isDark ? 22 : 34),
              borderRadius: BorderRadius.circular(tokens.radius.card),
              border: Border.all(color: Colors.white.withAlpha(46)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 17,
                  backgroundColor: onRoleColor.withAlpha(34),
                  foregroundColor: onRoleColor,
                  child: Text(
                    _initials(initials, userName),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: onRoleColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                SizedBox(width: tokens.spacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SchoolDeskAdaptiveText(
                        userName,
                        maxLines: 1,
                        minFontSize: 10.5,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: onRoleColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SchoolDeskAdaptiveText(
                        userSubtitle.isEmpty ? portalLabel : userSubtitle,
                        maxLines: 1,
                        minFontSize: 9.5,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: onRoleColor.withAlpha(210),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  final IconData icon;
  final Color roleColor;
  final Widget? child;

  const _HeaderIcon({required this.icon, required this.roleColor, this.child});

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).schoolDesk;
    return Container(
      width: tokens.sizing.iconContainer,
      height: tokens.sizing.iconContainer,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(tokens.isDark ? 32 : 42),
        borderRadius: BorderRadius.circular(tokens.radius.control),
        border: Border.all(color: Colors.white.withAlpha(52)),
      ),
      child: child ?? Icon(icon, color: _bestTextColor(roleColor), size: 24),
    );
  }
}

class _NavigationSectionLabel extends StatelessWidget {
  final String label;

  const _NavigationSectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        tokens.spacing.sm,
        tokens.spacing.sm,
        tokens.spacing.sm,
        tokens.spacing.xs,
      ),
      child: SchoolDeskAdaptiveText(
        label.toUpperCase(),
        maxLines: 1,
        minFontSize: 8.5,
        style: theme.textTheme.labelSmall?.copyWith(
          color: tokens.textMuted,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _NavigationItemTile extends StatelessWidget {
  final SchoolDeskRole role;
  final SchoolDeskNavigationItem item;
  final bool isSelected;
  final ValueChanged<int> onSelected;

  const _NavigationItemTile({
    required this.role,
    required this.item,
    required this.isSelected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;
    final colorScheme = theme.colorScheme;
    final roleColor = tokens.roleColor(role);
    final metadata = item.route == null
        ? null
        : SchoolDeskScreenRegistry.byRoute(item.route!);
    final availability = metadata?.feature == null
        ? null
        : FeatureAvailabilityService.stateFor(metadata!.feature!);
    final isBackendPending = availability != null && !availability.isAvailable;
    final foreground = isSelected
        ? roleColor
        : item.enabled
        ? colorScheme.onSurfaceVariant
        : tokens.textMuted;
    final label = [
      item.label,
      if (isSelected) 'selected',
      if (!item.enabled) 'unavailable',
      if (!item.enabled && item.disabledReason != null) item.disabledReason!,
      if (item.enabled && isBackendPending) 'backend pending',
    ].join(', ');

    return Padding(
      padding: EdgeInsets.symmetric(vertical: tokens.spacing.xs / 2),
      child: Tooltip(
        message: item.enabled
            ? (isBackendPending ? availability.reason ?? 'Backend pending' : '')
            : item.disabledReason ?? 'Unavailable',
        excludeFromSemantics: true,
        child: Semantics(
          label: label,
          button: true,
          enabled: item.enabled,
          selected: isSelected,
          excludeSemantics: true,
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(tokens.radius.control),
            child: InkWell(
              borderRadius: BorderRadius.circular(tokens.radius.control),
              onTap: item.enabled ? () => _activate(context) : null,
              child: AnimatedContainer(
                duration: tokens.motion.fast,
                curve: tokens.motion.curve,
                constraints: BoxConstraints(
                  minHeight: tokens.sizing.iconContainer,
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: tokens.spacing.sm,
                  vertical: tokens.spacing.sm,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? roleColor.withAlpha(tokens.isDark ? 42 : 24)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(tokens.radius.control),
                  border: Border.all(
                    color: isSelected
                        ? roleColor.withAlpha(96)
                        : Colors.transparent,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isSelected ? item.activeIcon : item.icon,
                      color: foreground,
                      size: 24,
                    ),
                    SizedBox(width: tokens.spacing.sm),
                    Expanded(
                      child: SchoolDeskAdaptiveText(
                        item.label,
                        maxLines: 1,
                        minFontSize: 10,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: foreground,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                    if (item.badgeCount > 0)
                      _NavigationPill(
                        label: item.badgeCount > 99
                            ? '99+'
                            : '${item.badgeCount}',
                        color: colorScheme.error,
                      ),
                    if (!item.enabled)
                      _NavigationPill(
                        label: 'Unavailable',
                        color: colorScheme.error,
                      )
                    else if (isBackendPending)
                      _NavigationPill(
                        label: 'Pending',
                        color: colorScheme.tertiary,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _activate(BuildContext context) {
    onSelected(item.index);
    if (item.route == null) return;

    final currentRoute = ModalRoute.of(context)?.settings.name;
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    }
    if (currentRoute == item.route) return;

    if (item.resetStack) {
      navigator.pushNamedAndRemoveUntil(
        item.route!,
        (route) => false,
        arguments: item.arguments,
      );
    } else {
      navigator.pushNamed(item.route!, arguments: item.arguments);
    }
  }
}

class _NavigationFooter extends StatelessWidget {
  final List<SchoolDeskNavigationFooterAction> actions;

  const _NavigationFooter({required this.actions});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;
    return Container(
      padding: EdgeInsets.all(tokens.spacing.sm),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: tokens.panelBorder)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final action in actions) _FooterActionTile(action: action),
        ],
      ),
    );
  }
}

class _FooterActionTile extends StatelessWidget {
  final SchoolDeskNavigationFooterAction action;

  const _FooterActionTile({required this.action});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;
    final color = action.color ?? theme.colorScheme.primary;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: tokens.spacing.xs / 2),
      child: Semantics(
        label: action.badgeCount > 0
            ? '${action.label}, ${action.badgeCount} unread'
            : action.label,
        button: true,
        excludeSemantics: true,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(tokens.radius.control),
          child: InkWell(
            borderRadius: BorderRadius.circular(tokens.radius.control),
            onTap: () => _activate(context),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: tokens.sizing.iconContainer,
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: tokens.spacing.sm),
                child: Row(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(action.icon, color: color, size: 24),
                        if (action.badgeCount > 0)
                          Positioned(
                            right: -8,
                            top: -7,
                            child: _NavigationDot(
                              label: action.badgeCount > 9
                                  ? '9+'
                                  : '${action.badgeCount}',
                            ),
                          ),
                      ],
                    ),
                    SizedBox(width: tokens.spacing.sm),
                    Expanded(
                      child: SchoolDeskAdaptiveText(
                        action.label,
                        maxLines: 1,
                        minFontSize: 10,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _activate(BuildContext context) {
    if (action.onPressed != null) {
      action.onPressed!(context);
      return;
    }
    if (action.route == null) return;
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    }
    if (action.resetStack) {
      navigator.pushNamedAndRemoveUntil(
        action.route!,
        (route) => false,
        arguments: action.arguments,
      );
    } else {
      navigator.pushNamed(action.route!, arguments: action.arguments);
    }
  }
}

class _NavigationPill extends StatelessWidget {
  final String label;
  final Color color;

  const _NavigationPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;
    return Container(
      margin: EdgeInsets.only(left: tokens.spacing.xs),
      padding: EdgeInsets.symmetric(horizontal: tokens.spacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(tokens.isDark ? 58 : 28),
        borderRadius: BorderRadius.circular(tokens.radius.pill),
        border: Border.all(color: color.withAlpha(88)),
      ),
      child: SchoolDeskAdaptiveText(
        label,
        maxLines: 1,
        minFontSize: 8.5,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _NavigationDot extends StatelessWidget {
  final String label;

  const _NavigationDot({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.error,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.colorScheme.surface, width: 1.5),
      ),
      child: Center(
        child: SchoolDeskAdaptiveText(
          label,
          maxLines: 1,
          textAlign: TextAlign.center,
          minFontSize: 7.5,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onError,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

String _initials(String initials, String fallbackName) {
  final trimmed = initials.trim();
  if (trimmed.isNotEmpty) return trimmed.toUpperCase();
  final nameParts = fallbackName
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .take(2);
  final generated = nameParts.map((part) => part[0].toUpperCase()).join();
  return generated.isEmpty ? 'U' : generated;
}

Color _bestTextColor(Color background) {
  return background.computeLuminance() > 0.45 ? Colors.black : Colors.white;
}
