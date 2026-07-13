import 'package:flutter/material.dart';

import 'package:schooldesk1/core/theme/design_tokens.dart';
import 'package:schooldesk1/core/widgets/erp_navigation.dart';

import 'desktop_hover_effects.dart';
import 'desktop_responsive_breakpoints.dart';

/// Persistent sidebar navigation for desktop — replaces drawer overlay.
class DesktopNavigationRail extends StatefulWidget {
  final SchoolDeskRole role;
  final String portalLabel;
  final String organizationName;
  final String organizationSubtitle;
  final String userName;
  final String userSubtitle;
  final String initials;
  final IconData portalIcon;
  final Widget? organizationLogo;
  final Widget? userAvatar;
  final int? selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<SchoolDeskNavigationSection> sections;
  final List<SchoolDeskNavigationFooterAction> footerActions;
  final bool initiallyExpanded;

  const DesktopNavigationRail({
    super.key,
    required this.role,
    required this.portalLabel,
    required this.organizationName,
    required this.organizationSubtitle,
    required this.userName,
    required this.userSubtitle,
    required this.initials,
    required this.portalIcon,
    this.organizationLogo,
    this.userAvatar,
    this.selectedIndex,
    required this.onDestinationSelected,
    required this.sections,
    this.footerActions = const [],
    this.initiallyExpanded = true,
  });

  @override
  State<DesktopNavigationRail> createState() => _DesktopNavigationRailState();
}

class _DesktopNavigationRailState extends State<DesktopNavigationRail> {
  bool? _userExpanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;
    final roleColor = tokens.roleColor(widget.role);

    final screenWidth = MediaQuery.sizeOf(context).width;
    final isNarrow = screenWidth < 1150;
    final expanded = _userExpanded ?? (isNarrow ? false : widget.initiallyExpanded);

    final width = expanded
        ? DesktopBreakpoints.sidebarExpanded
        : DesktopBreakpoints.sidebarCollapsed;

    return AnimatedContainer(
      duration: tokens.motion.normal,
      curve: tokens.motion.curve,
      width: width,
      decoration: BoxDecoration(
        color: tokens.panel,
        border: Border(right: BorderSide(color: tokens.panelBorder)),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withAlpha(tokens.isDark ? 40 : 16),
            blurRadius: 12,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          _DesktopRailHeader(
            expanded: expanded,
            roleColor: roleColor,
            portalLabel: widget.portalLabel,
            organizationName: widget.organizationName,
            organizationLogo: widget.organizationLogo,
            portalIcon: widget.portalIcon,
            onToggle: () => setState(() => _userExpanded = !expanded),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(
                horizontal: expanded ? tokens.spacing.sm : tokens.spacing.xs,
                vertical: tokens.spacing.sm,
              ),
              children: [
                for (final section in widget.sections) ...[
                  if (expanded)
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        tokens.spacing.sm,
                        tokens.spacing.md,
                        tokens.spacing.sm,
                        tokens.spacing.xs,
                      ),
                      child: Text(
                        section.label.toUpperCase(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: tokens.textMuted,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  for (final item in section.items)
                    _DesktopRailItem(
                      expanded: expanded,
                      item: item,
                      roleColor: roleColor,
                      isSelected: widget.selectedIndex == item.index,
                      onTap: () => widget.onDestinationSelected(item.index),
                    ),
                ],
              ],
            ),
          ),
          if (widget.footerActions.isNotEmpty)
            _DesktopRailFooter(
              expanded: expanded,
              actions: widget.footerActions,
            ),
          _DesktopRailUserFooter(
            expanded: expanded,
            userName: widget.userName,
            userSubtitle: widget.userSubtitle,
            initials: widget.initials,
            userAvatar: widget.userAvatar,
          ),
        ],
      ),
    );
  }
}

class _DesktopRailHeader extends StatelessWidget {
  final bool expanded;
  final Color roleColor;
  final String portalLabel;
  final String organizationName;
  final Widget? organizationLogo;
  final IconData portalIcon;
  final VoidCallback onToggle;

  const _DesktopRailHeader({
    required this.expanded,
    required this.roleColor,
    required this.portalLabel,
    required this.organizationName,
    this.organizationLogo,
    required this.portalIcon,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;

    return Container(
      padding: EdgeInsets.all(tokens.spacing.sm),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [roleColor, roleColor.withAlpha(200)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          if (organizationLogo != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(tokens.radius.control),
              child: SizedBox(width: 36, height: 36, child: organizationLogo),
            )
          else
            Icon(portalIcon, color: Colors.white, size: 28),
          if (expanded) ...[
            SizedBox(width: tokens.spacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    portalLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: Colors.white.withAlpha(230),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    organizationName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
          DesktopHoverIconButton(
            icon: expanded
                ? Icons.chevron_left_rounded
                : Icons.chevron_right_rounded,
            tooltip: expanded ? 'Collapse sidebar' : 'Expand sidebar',
            onPressed: onToggle,
            color: Colors.white,
          ),
        ],
      ),
    );
  }
}

class _DesktopRailItem extends StatelessWidget {
  final bool expanded;
  final SchoolDeskNavigationItem item;
  final Color roleColor;
  final bool isSelected;
  final VoidCallback onTap;

  const _DesktopRailItem({
    required this.expanded,
    required this.item,
    required this.roleColor,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;
    final icon = isSelected ? item.activeIcon : item.icon;

    final tile = Material(
      color: Colors.transparent,
      child: DesktopHoverInkWell(
        onTap: item.enabled ? onTap : null,
        borderRadius: BorderRadius.circular(tokens.radius.control),
        child: AnimatedContainer(
          duration: tokens.motion.fast,
          margin: EdgeInsets.only(bottom: tokens.spacing.xs),
          padding: EdgeInsets.symmetric(
            horizontal: expanded ? tokens.spacing.sm : 0,
            vertical: tokens.spacing.sm,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? roleColor.withAlpha(tokens.isDark ? 60 : 30)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(tokens.radius.control),
            border: isSelected
                ? Border.all(color: roleColor.withAlpha(100))
                : null,
          ),
          child: Row(
            mainAxisAlignment:
                expanded ? MainAxisAlignment.start : MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 22,
                color: isSelected ? roleColor : tokens.textMuted,
              ),
              if (expanded) ...[
                SizedBox(width: tokens.spacing.sm),
                Expanded(
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? roleColor : tokens.onSurface,
                    ),
                  ),
                ),
                if (item.badgeCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.error,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${item.badgeCount > 99 ? '99+' : item.badgeCount}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );

    if (expanded) return tile;
    return Tooltip(message: item.label, child: tile);
  }
}

class _DesktopRailFooter extends StatelessWidget {
  final bool expanded;
  final List<SchoolDeskNavigationFooterAction> actions;

  const _DesktopRailFooter({required this.expanded, required this.actions});

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).schoolDesk;
    return Padding(
      padding: EdgeInsets.all(tokens.spacing.sm),
      child: Column(
        children: [
          Divider(color: tokens.panelBorder, height: 1),
          SizedBox(height: tokens.spacing.sm),
          for (final action in actions)
            ListTile(
              dense: true,
              leading: Icon(action.icon, size: 20, color: action.color),
              title: expanded
                  ? Text(action.label, style: Theme.of(context).textTheme.bodySmall)
                  : null,
              onTap: action.onPressed != null
                  ? () => action.onPressed!(context)
                  : null,
            ),
        ],
      ),
    );
  }
}

class _DesktopRailUserFooter extends StatelessWidget {
  final bool expanded;
  final String userName;
  final String userSubtitle;
  final String initials;
  final Widget? userAvatar;

  const _DesktopRailUserFooter({
    required this.expanded,
    required this.userName,
    required this.userSubtitle,
    required this.initials,
    this.userAvatar,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;

    return Container(
      padding: EdgeInsets.all(tokens.spacing.sm),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: tokens.panelBorder)),
        color: tokens.panelMuted,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: theme.colorScheme.primaryContainer,
            child: userAvatar ??
                Text(
                  initials,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
          ),
          if (expanded) ...[
            SizedBox(width: tokens.spacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    userName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    userSubtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: tokens.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
