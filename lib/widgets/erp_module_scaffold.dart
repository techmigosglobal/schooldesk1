import 'package:flutter/material.dart';

import '../core/constants/schooldesk_glossary.dart';
import '../routes/app_routes.dart';
import '../routes/route_access_guard.dart';
import '../services/backend_api_client.dart';
import '../services/notification_service.dart';
import '../theme/design_tokens.dart';

class SchoolDeskModuleScaffold extends StatefulWidget {
  static const String openNavigationAction = '__schooldesk_open_navigation__';

  final String title;
  final String? subtitle;
  final Widget drawer;
  final Widget body;
  final List<Widget> actions;
  final PreferredSizeWidget? bottom;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final double railBreakpoint;
  final bool bodyIsScrollable;
  final List<SchoolDeskModuleBottomAction>? mobileBottomActions;

  const SchoolDeskModuleScaffold({
    super.key,
    required this.title,
    this.subtitle,
    required this.drawer,
    required this.body,
    this.actions = const [],
    this.bottom,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.railBreakpoint = 980,
    this.bodyIsScrollable = false,
    this.mobileBottomActions,
  });

  @override
  State<SchoolDeskModuleScaffold> createState() =>
      _SchoolDeskModuleScaffoldState();
}

class _SchoolDeskModuleScaffoldState extends State<SchoolDeskModuleScaffold> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  NotificationService? _notificationService;
  int _unreadCount = 0;

  String get _role =>
      BackendApiClient.instance.currentRoleName?.trim().toLowerCase() ?? '';

  bool get _hasRoleShell =>
      const {'principal', 'admin', 'teacher', 'parent'}.contains(_role);

  @override
  void initState() {
    super.initState();
    _loadNotificationBadge();
  }

  Future<void> _loadNotificationBadge() async {
    if (!BackendApiClient.instance.isAuthenticated) return;
    try {
      final service = await NotificationService.getInstance();
      if (!mounted) return;
      _notificationService = service;
      _syncUnreadCount();
      service.addListener(_syncUnreadCount);
    } catch (_) {
      // Global chrome should never block a module when notifications are offline.
    }
  }

  void _syncUnreadCount() {
    if (!mounted) return;
    final role = _role;
    setState(() {
      _unreadCount = role.isEmpty
          ? _notificationService?.totalUnread ?? 0
          : _notificationService?.getUnreadCountForRole(role) ?? 0;
    });
  }

  @override
  void dispose() {
    _notificationService?.removeListener(_syncUnreadCount);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showRail = MediaQuery.sizeOf(context).width >= widget.railBreakpoint;
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;

    return Semantics(
      label: '${widget.title} module',
      container: true,
      explicitChildNodes: true,
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: tokens.pageBackground,
        drawer: showRail ? null : widget.drawer,
        floatingActionButton: widget.floatingActionButton,
        floatingActionButtonLocation: widget.floatingActionButtonLocation,
        bottomNavigationBar: !showRail && _hasRoleShell
            ? _ModuleBottomActionBar(
                role: _role,
                unreadCount: _unreadCount,
                customActions: widget.mobileBottomActions,
                onSelected: _navigateGlobal,
                onOpenNavigation: () => _scaffoldKey.currentState?.openDrawer(),
              )
            : null,
        body: Row(
          children: [
            if (showRail) widget.drawer,
            Expanded(
              child: Column(
                children: [
                  Material(
                    color: tokens.panel,
                    elevation: 0,
                    child: SafeArea(
                      bottom: false,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _ModuleToolbar(
                            title: widget.title,
                            subtitle: widget.subtitle,
                            showMenu: !showRail,
                            onMenuPressed: () =>
                                _scaffoldKey.currentState?.openDrawer(),
                            actions: widget.actions,
                            globalActions: _hasRoleShell
                                ? (showRail
                                      ? _globalToolbarActions()
                                      : _compactToolbarActions())
                                : const [],
                          ),
                          if (widget.bottom != null) widget.bottom!,
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: widget.bodyIsScrollable
                        ? SingleChildScrollView(child: widget.body)
                        : widget.body,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _globalToolbarActions() {
    return [
      _PortalContextChip(role: _role),
      _ToolbarSearchButton(
        onPressed: () => _navigateGlobal(AppRoutes.globalSearch),
      ),
      _ToolbarIconButton(
        tooltip: SchoolDeskGlossary.notifications,
        icon: Icons.notifications_none_rounded,
        badgeCount: _unreadCount,
        onPressed: () => _navigateGlobal(AppRoutes.notificationCenter),
      ),
      _ToolbarIconButton(
        tooltip: SchoolDeskGlossary.profile,
        icon: Icons.account_circle_outlined,
        onPressed: () => _navigateGlobal(AppRoutes.profileScreen),
      ),
      _ToolbarIconButton(
        tooltip: SchoolDeskGlossary.settings,
        icon: Icons.settings_outlined,
        onPressed: () => _navigateGlobal(AppRoutes.settingsScreen),
      ),
    ];
  }

  List<Widget> _compactToolbarActions() {
    return [
      _ToolbarIconButton(
        tooltip: SchoolDeskGlossary.notifications,
        icon: Icons.notifications_none_rounded,
        badgeCount: _unreadCount,
        onPressed: () => _navigateGlobal(AppRoutes.notificationCenter),
      ),
      _ToolbarIconButton(
        tooltip: SchoolDeskGlossary.profile,
        icon: Icons.account_circle_outlined,
        onPressed: () => _navigateGlobal(AppRoutes.profileScreen),
      ),
    ];
  }

  void _navigateGlobal(String route, {Object? arguments}) {
    final navigator = Navigator.of(context);
    final role = _role.isEmpty ? 'admin' : _role;
    final target = route == AppRoutes.initial
        ? RouteAccessGuard.dashboardForRole(role) ?? AppRoutes.landingPage
        : route;
    final args = arguments ?? _argumentsFor(target, role);

    if (target == RouteAccessGuard.dashboardForRole(role)) {
      navigator.pushNamedAndRemoveUntil(target, (existing) => false);
      return;
    }
    navigator.pushNamed(target, arguments: args);
  }

  Object? _argumentsFor(String route, String role) {
    if (route == AppRoutes.notificationCenter ||
        route == AppRoutes.settingsScreen ||
        route == AppRoutes.profileScreen) {
      return role;
    }
    return null;
  }
}

@immutable
class SchoolDeskModuleBottomAction {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final String route;
  final Object? arguments;
  final int badgeCount;

  const SchoolDeskModuleBottomAction({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.route,
    this.arguments,
    this.badgeCount = 0,
  });
}

class _ModuleToolbar extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool showMenu;
  final VoidCallback onMenuPressed;
  final List<Widget> actions;
  final List<Widget> globalActions;

  const _ModuleToolbar({
    required this.title,
    required this.subtitle,
    required this.showMenu,
    required this.onMenuPressed,
    required this.actions,
    required this.globalActions,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;
    final trailingActions = [...actions, ...globalActions];
    return Container(
      constraints: const BoxConstraints(minHeight: 64),
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.md,
        vertical: tokens.spacing.sm,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: tokens.panelBorder)),
      ),
      child: showMenu
          ? Row(
              children: [
                SizedBox(
                  width: 48,
                  child: IconButton(
                    tooltip: 'Open navigation',
                    onPressed: onMenuPressed,
                    icon: const Icon(Icons.menu_rounded),
                  ),
                ),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (subtitle != null) ...[
                        SizedBox(height: tokens.spacing.xs),
                        Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: tokens.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(
                  width: trailingActions.isEmpty ? 48 : null,
                  child: trailingActions.isEmpty
                      ? const SizedBox.shrink()
                      : Wrap(
                          spacing: tokens.spacing.xs,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: trailingActions,
                        ),
                ),
              ],
            )
          : Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleLarge,
                      ),
                      if (subtitle != null) ...[
                        SizedBox(height: tokens.spacing.xs),
                        Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: tokens.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (actions.isNotEmpty) ...[
                  SizedBox(width: tokens.spacing.sm),
                  Wrap(
                    spacing: tokens.spacing.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: actions,
                  ),
                ],
                if (globalActions.isNotEmpty) ...[
                  SizedBox(width: tokens.spacing.sm),
                  SizedBox(
                    height: 32,
                    child: VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: tokens.panelBorder,
                    ),
                  ),
                  SizedBox(width: tokens.spacing.xs),
                  Wrap(
                    spacing: tokens.spacing.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: globalActions,
                  ),
                ],
              ],
            ),
    );
  }
}

class _PortalContextChip extends StatelessWidget {
  final String role;

  const _PortalContextChip({required this.role});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;
    return Semantics(
      label: SchoolDeskGlossary.portalLabel(role),
      child: Container(
        constraints: const BoxConstraints(minHeight: 36),
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spacing.sm,
          vertical: tokens.spacing.xs,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer.withAlpha(
            tokens.isDark ? 80 : 150,
          ),
          borderRadius: BorderRadius.circular(tokens.radius.control),
          border: Border.all(color: tokens.panelBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.verified_user_outlined,
              size: 18,
              color: theme.colorScheme.primary,
            ),
            SizedBox(width: tokens.spacing.xs),
            Text(
              SchoolDeskGlossary.portalLabel(role),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolbarSearchButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _ToolbarSearchButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;
    return Tooltip(
      message: SchoolDeskGlossary.globalSearch,
      child: InkWell(
        borderRadius: BorderRadius.circular(tokens.radius.control),
        onTap: onPressed,
        child: Container(
          constraints: const BoxConstraints(
            minWidth: 160,
            maxWidth: 240,
            minHeight: 44,
          ),
          padding: EdgeInsets.symmetric(horizontal: tokens.spacing.sm),
          decoration: BoxDecoration(
            color: tokens.panelMuted,
            borderRadius: BorderRadius.circular(tokens.radius.control),
            border: Border.all(color: tokens.panelBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_rounded, size: 18, color: tokens.textMuted),
              SizedBox(width: tokens.spacing.sm),
              Flexible(
                child: Text(
                  SchoolDeskGlossary.search,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: tokens.textMuted,
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

class _ToolbarIconButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final int badgeCount;
  final VoidCallback onPressed;

  const _ToolbarIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final button = IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon),
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
    );
    if (badgeCount <= 0) return button;
    return Badge.count(count: badgeCount > 99 ? 99 : badgeCount, child: button);
  }
}

class _ModuleBottomActionBar extends StatelessWidget {
  final String role;
  final int unreadCount;
  final List<SchoolDeskModuleBottomAction>? customActions;
  final void Function(String route, {Object? arguments}) onSelected;
  final VoidCallback onOpenNavigation;

  const _ModuleBottomActionBar({
    required this.role,
    required this.unreadCount,
    required this.customActions,
    required this.onSelected,
    required this.onOpenNavigation,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).schoolDesk;
    final currentRoute = ModalRoute.of(context)?.settings.name;
    final homeRoute =
        RouteAccessGuard.dashboardForRole(role) ?? AppRoutes.landingPage;
    final configuredActions = customActions;
    final actions = configuredActions == null
        ? [
            _BottomAction(
              label: 'Home',
              icon: Icons.home_outlined,
              activeIcon: Icons.home_rounded,
              route: AppRoutes.initial,
              selected: currentRoute == homeRoute,
            ),
            _BottomAction(
              label: SchoolDeskGlossary.search,
              icon: Icons.search_rounded,
              activeIcon: Icons.manage_search_rounded,
              route: AppRoutes.globalSearch,
              selected: currentRoute == AppRoutes.globalSearch,
            ),
            _BottomAction(
              label: SchoolDeskGlossary.notifications,
              icon: Icons.notifications_none_rounded,
              activeIcon: Icons.notifications_rounded,
              route: AppRoutes.notificationCenter,
              selected: currentRoute == AppRoutes.notificationCenter,
              badgeCount: unreadCount,
            ),
            _BottomAction(
              label: SchoolDeskGlossary.profile,
              icon: Icons.account_circle_outlined,
              activeIcon: Icons.account_circle_rounded,
              route: AppRoutes.profileScreen,
              selected: currentRoute == AppRoutes.profileScreen,
            ),
          ]
        : [
            for (final action in configuredActions)
              _BottomAction(
                label: action.label,
                icon: action.icon,
                activeIcon: action.activeIcon,
                route: action.route,
                arguments: action.arguments,
                selected:
                    (action.route == AppRoutes.initial &&
                        currentRoute == homeRoute) ||
                    action.route == currentRoute,
                badgeCount: action.badgeCount,
              ),
          ];

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
              for (final action in actions)
                Expanded(
                  child: _BottomActionButton(
                    action: action,
                    onTap: () {
                      if (action.route ==
                          SchoolDeskModuleScaffold.openNavigationAction) {
                        onOpenNavigation();
                        return;
                      }
                      onSelected(action.route, arguments: action.arguments);
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomAction {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final String route;
  final Object? arguments;
  final bool selected;
  final int badgeCount;

  const _BottomAction({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.route,
    this.arguments,
    required this.selected,
    this.badgeCount = 0,
  });
}

class _BottomActionButton extends StatelessWidget {
  final _BottomAction action;
  final VoidCallback onTap;

  const _BottomActionButton({required this.action, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;
    final color = action.selected
        ? theme.colorScheme.primary
        : tokens.textMuted;
    final icon = Icon(
      action.selected ? action.activeIcon : action.icon,
      color: color,
      size: 22,
    );

    return Semantics(
      button: true,
      selected: action.selected,
      label: action.label,
      child: InkWell(
        borderRadius: BorderRadius.circular(tokens.radius.control),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: tokens.spacing.xs),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                action.badgeCount > 0
                    ? Badge.count(
                        count: action.badgeCount > 99 ? 99 : action.badgeCount,
                        child: icon,
                      )
                    : icon,
                const SizedBox(height: 3),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    action.label,
                    maxLines: 1,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: color,
                      fontWeight: action.selected
                          ? FontWeight.w700
                          : FontWeight.w500,
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

enum RecordChipTone { neutral, success, warning, danger, info }

class SchoolDeskRecordChip {
  final String label;
  final RecordChipTone tone;

  const SchoolDeskRecordChip({
    required this.label,
    this.tone = RecordChipTone.neutral,
  });
}

class SchoolDeskRecordCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData leadingIcon;
  final List<SchoolDeskRecordChip> chips;
  final Widget? trailing;
  final VoidCallback? onTap;
  final String? semanticLabel;

  const SchoolDeskRecordCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.leadingIcon,
    this.chips = const [],
    this.trailing,
    this.onTap,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;
    final content = AnimatedContainer(
      duration: tokens.motion.fast,
      curve: tokens.motion.curve,
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
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withAlpha(
                tokens.isDark ? 80 : 180,
              ),
              borderRadius: BorderRadius.circular(tokens.radius.control),
            ),
            child: Icon(
              leadingIcon,
              color: theme.colorScheme.primary,
              size: 22,
            ),
          ),
          SizedBox(width: tokens.spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
                if (subtitle != null) ...[
                  SizedBox(height: tokens.spacing.xs),
                  Text(
                    subtitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: tokens.textMuted,
                    ),
                  ),
                ],
                if (chips.isNotEmpty) ...[
                  SizedBox(height: tokens.spacing.sm),
                  Wrap(
                    spacing: tokens.spacing.xs,
                    runSpacing: tokens.spacing.xs,
                    children: chips.map((chip) => _RecordChip(chip)).toList(),
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
    );

    return Semantics(
      label: semanticLabel ?? [title, subtitle].whereType<String>().join(', '),
      button: onTap != null,
      onTap: onTap,
      excludeSemantics: true,
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

class _RecordChip extends StatelessWidget {
  final SchoolDeskRecordChip chip;

  const _RecordChip(this.chip);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;
    final color = switch (chip.tone) {
      RecordChipTone.success => AppSemanticColor.success.resolve(theme),
      RecordChipTone.warning => AppSemanticColor.warning.resolve(theme),
      RecordChipTone.danger => theme.colorScheme.error,
      RecordChipTone.info => theme.colorScheme.primary,
      RecordChipTone.neutral => tokens.textMuted,
    };

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.sm,
        vertical: tokens.spacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withAlpha(tokens.isDark ? 48 : 24),
        borderRadius: BorderRadius.circular(tokens.radius.pill),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Text(
        chip.label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

enum AppSemanticColor { success, warning }

extension on AppSemanticColor {
  Color resolve(ThemeData theme) {
    return switch (this) {
      AppSemanticColor.success =>
        theme.brightness == Brightness.dark
            ? const Color(0xFF86EFAC)
            : const Color(0xFF15803D),
      AppSemanticColor.warning =>
        theme.brightness == Brightness.dark
            ? const Color(0xFFFCD34D)
            : const Color(0xFFB45309),
    };
  }
}
