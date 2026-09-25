import 'package:flutter/material.dart';

import 'package:schooldesk1/core/theme/design_tokens.dart';

/// Reusable wrapper that provides a consistent Windows 11-style desktop layout
/// for any screen. Wraps the mobile layout with a clean header and content area.
///
/// Usage:
/// ```dart
/// Widget build(BuildContext context) {
///   final isDesktop = DesktopBreakpoints.isDesktopWidth(
///     MediaQuery.sizeOf(context).width,
///   );
///   if (isDesktop) {
///     return DesktopScreenWrapper(
///       breadcrumbs: ['Home', 'Students'],
///       title: 'Student Directory',
///       subtitle: 'Manage student records',
///       actions: [IconButton(...)],
///       child: _buildBody(),
///     );
///   }
///   return _buildMobileBody();
/// }
/// ```
class DesktopScreenWrapper extends StatelessWidget {
  final List<String> breadcrumbs;
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget child;
  final Widget? floatingActionButton;
  final Color backgroundColor;
  final double? maxWidth;

  const DesktopScreenWrapper({
    super.key,
    required this.breadcrumbs,
    required this.title,
    this.subtitle,
    this.actions = const [],
    required this.child,
    this.floatingActionButton,
    this.backgroundColor = const Color(0xFFF7FAFF),
    this.maxWidth,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Windows 11-style header with breadcrumbs
          _DesktopScreenHeader(
            breadcrumbs: breadcrumbs,
            title: title,
            subtitle: subtitle,
            actions: actions,
          ),
          // Content area with proper padding
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: maxWidth ?? double.infinity,
                ),
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    tokens.spacing.lg,
                    tokens.spacing.md,
                    tokens.spacing.lg,
                    tokens.spacing.xxl,
                  ),
                  child: child,
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: floatingActionButton,
    );
  }
}

class _DesktopScreenHeader extends StatelessWidget {
  final List<String> breadcrumbs;
  final String title;
  final String? subtitle;
  final List<Widget> actions;

  const _DesktopScreenHeader({
    required this.breadcrumbs,
    required this.title,
    this.subtitle,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;

    return Container(
      padding: EdgeInsets.fromLTRB(
        tokens.spacing.lg,
        tokens.spacing.md,
        tokens.spacing.lg,
        tokens.spacing.sm,
      ),
      decoration: BoxDecoration(
        color: tokens.panel,
        border: Border(bottom: BorderSide(color: tokens.panelBorder)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 620;

          final heading = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (breadcrumbs.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(bottom: tokens.spacing.xs),
                  child: _BreadcrumbTrail(items: breadcrumbs),
                ),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                SizedBox(height: tokens.spacing.xs),
                Text(
                  subtitle!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: tokens.textMuted,
                  ),
                ),
              ],
            ],
          );

          final actionRow = actions.isEmpty
              ? const SizedBox.shrink()
              : Wrap(
                  spacing: tokens.spacing.sm,
                  runSpacing: tokens.spacing.sm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: actions,
                );

          if (!wide) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                heading,
                if (actions.isNotEmpty) ...[
                  SizedBox(height: tokens.spacing.sm),
                  actionRow,
                ],
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: heading),
              if (actions.isNotEmpty) ...[
                SizedBox(width: tokens.spacing.lg),
                Align(alignment: Alignment.topRight, child: actionRow),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Shared action button for desktop layouts.
///
/// Used across fee, attendance, and other desktop screens to provide
/// consistent filled/outlined button styling.
class DesktopActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool outlined;

  const DesktopActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    if (outlined) {
      return OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }
    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}

class _BreadcrumbTrail extends StatelessWidget {
  final List<String> items;
  const _BreadcrumbTrail({required this.items});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: tokens.spacing.xs,
      runSpacing: tokens.spacing.xs,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          Text(
            items[i],
            style: theme.textTheme.labelSmall?.copyWith(
              color: i == items.length - 1
                  ? theme.colorScheme.primary
                  : tokens.textMuted,
              fontWeight: i == items.length - 1
                  ? FontWeight.w700
                  : FontWeight.w500,
            ),
          ),
          if (i < items.length - 1)
            Icon(
              Icons.chevron_right_rounded,
              size: 14,
              color: tokens.textMuted,
            ),
        ],
      ],
    );
  }
}
