import 'package:flutter/material.dart';

import 'package:schooldesk1/core/desktop/desktop_hover_effects.dart';
import 'package:schooldesk1/core/theme/design_tokens.dart';

// ---------------------------------------------------------------------------
// DesktopPageHeader — Windows 11-style page header with breadcrumb, title,
// subtitle, and action buttons. Consistent across all desktop screens.
// ---------------------------------------------------------------------------

/// Windows 11-inspired page header for desktop screens.
///
/// Shows a breadcrumb trail, page title, subtitle, and optional action buttons.
/// Adapts layout for narrow (< 620px) and wide desktops.
class DesktopPageHeader extends StatelessWidget {
  final List<String> breadcrumbs;
  final String title;
  final String? subtitle;
  final List<Widget> actions;

  const DesktopPageHeader({
    super.key,
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
            children: [
              // Breadcrumbs
              if (breadcrumbs.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(bottom: tokens.spacing.xs),
                  child: _BreadcrumbTrail(items: breadcrumbs),
                ),
              // Title + subtitle
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
                Align(
                  alignment: Alignment.topRight,
                  child: actionRow,
                ),
              ],
            ],
          );
        },
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
              fontWeight:
                  i == items.length - 1 ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          if (i < items.length - 1)
            Icon(Icons.chevron_right_rounded, size: 14, color: tokens.textMuted),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// DesktopSearchFilterBar — Windows 11-style search + filter + sort bar
// Used at the top of list screens (Students, Staff, Fees, etc.)
// ---------------------------------------------------------------------------

/// Windows 11-inspired search and filter bar for desktop list screens.
///
/// Features a search input, filter chips, and optional action buttons.
class DesktopSearchFilterBar extends StatefulWidget {
  final String searchHint;
  final ValueChanged<String>? onSearchChanged;
  final List<DesktopFilterChip> filterChips;
  final List<Widget> actions;

  const DesktopSearchFilterBar({
    super.key,
    this.searchHint = 'Search...',
    this.onSearchChanged,
    this.filterChips = const [],
    this.actions = const [],
  });

  @override
  State<DesktopSearchFilterBar> createState() => _DesktopSearchFilterBarState();
}

class _DesktopSearchFilterBarState extends State<DesktopSearchFilterBar> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.lg,
        vertical: tokens.spacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Search bar + action buttons
          Row(
            children: [
              Expanded(
                child: _SearchInput(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  hint: widget.searchHint,
                  onChanged: widget.onSearchChanged,
                ),
              ),
              if (widget.actions.isNotEmpty) ...[
                SizedBox(width: tokens.spacing.sm),
                ...widget.actions,
              ],
            ],
          ),
          // Filter chips
          if (widget.filterChips.isNotEmpty) ...[
            SizedBox(height: tokens.spacing.sm),
            Wrap(
              spacing: tokens.spacing.sm,
              runSpacing: tokens.spacing.xs,
              children: widget.filterChips.map((chip) {
                return _DesktopFilterChipWidget(
                  chip: chip,
                  onSelected: (selected) {
                    setState(() => chip.selected = selected);
                    chip.onSelected?.call(selected);
                  },
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _SearchInput extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final ValueChanged<String>? onChanged;

  const _SearchInput({
    required this.controller,
    required this.focusNode,
    required this.hint,
    this.onChanged,
  });

  @override
  State<_SearchInput> createState() => _SearchInputState();
}

class _SearchInputState extends State<_SearchInput> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(covariant _SearchInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onTextChanged);
      widget.controller.addListener(_onTextChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;
    final hasText = widget.controller.text.isNotEmpty;

    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: tokens.panelMuted,
        borderRadius: BorderRadius.circular(tokens.radius.control),
        border: Border.all(color: tokens.panelBorder),
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: widget.focusNode,
        onChanged: widget.onChanged,
        textInputAction: TextInputAction.search,
        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: widget.hint,
          hintStyle: theme.textTheme.bodyMedium?.copyWith(
            color: tokens.textMuted,
          ),
          prefixIcon: Icon(Icons.search_rounded, size: 18, color: tokens.textMuted),
          prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          suffixIcon: hasText
              ? IconButton(
                  icon: Icon(Icons.close_rounded, size: 16, color: tokens.textMuted),
                  onPressed: () {
                    widget.controller.clear();
                    widget.onChanged?.call('');
                  },
                )
              : null,
        ),
      ),
    );
  }
}

/// Data class for a filter chip in the search bar.
class DesktopFilterChip {
  final String label;
  bool selected;
  final ValueChanged<bool>? onSelected;

  DesktopFilterChip({
    required this.label,
    this.selected = false,
    this.onSelected,
  });
}

class _DesktopFilterChipWidget extends StatelessWidget {
  final DesktopFilterChip chip;
  final ValueChanged<bool> onSelected;

  const _DesktopFilterChipWidget({
    required this.chip,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;
    final primary = theme.colorScheme.primary;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => onSelected(!chip.selected),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: chip.selected
                ? primary.withAlpha(tokens.isDark ? 50 : 25)
                : tokens.panel,
            borderRadius: BorderRadius.circular(tokens.radius.pill),
            border: Border.all(
              color: chip.selected ? primary.withAlpha(120) : tokens.panelBorder,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (chip.selected) ...[
                Icon(Icons.check_rounded, size: 14, color: primary),
                const SizedBox(width: 4),
              ],
              Text(
                chip.label,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: chip.selected ? primary : tokens.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// DesktopEmptyState — Windows 11-style empty state for desktop screens.
// ---------------------------------------------------------------------------

/// Windows 11-inspired empty state widget for desktop screens.
///
/// Shows an icon, title, message, and optional action button.
class DesktopEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const DesktopEmptyState({
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: tokens.panelMuted,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, size: 36, color: tokens.textMuted.withAlpha(150)),
            ),
            SizedBox(height: tokens.spacing.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: tokens.spacing.sm),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: tokens.textMuted,
                  height: 1.5,
                ),
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              SizedBox(height: tokens.spacing.lg),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// DesktopFormDialog — Windows 11-style centered form dialog.
// ---------------------------------------------------------------------------

/// Shows a Windows 11-style centered form dialog for desktop screens.
///
/// Use this instead of navigating to a new screen for create/edit forms.
Future<T?> showDesktopFormDialog<T>({
  required BuildContext context,
  required String title,
  required Widget content,
  List<Widget>? actions,
  double maxWidth = 560,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: Colors.black38,
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (context, animation, secondaryAnimation) {
      return _DesktopFormDialog<T>(
        title: title,
        content: content,
        actions: actions,
        maxWidth: maxWidth,
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          ),
          child: child,
        ),
      );
    },
  );
}

class _DesktopFormDialog<T> extends StatelessWidget {
  final String title;
  final Widget content;
  final List<Widget>? actions;
  final double maxWidth;

  const _DesktopFormDialog({
    required this.title,
    required this.content,
    this.actions,
    this.maxWidth = 560,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: 680),
          margin: EdgeInsets.all(tokens.spacing.lg),
          decoration: BoxDecoration(
            color: tokens.panel,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(25),
                blurRadius: 40,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Padding(
                padding: EdgeInsets.fromLTRB(
                  tokens.spacing.lg,
                  tokens.spacing.lg,
                  tokens.spacing.sm,
                  tokens.spacing.sm,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    DesktopHoverIconButton(
                      icon: Icons.close_rounded,
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: tokens.panelBorder),
              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(tokens.spacing.lg),
                  child: content,
                ),
              ),
              // Actions
              if (actions != null && actions!.isNotEmpty) ...[
                Divider(height: 1, color: tokens.panelBorder),
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: tokens.spacing.lg,
                    vertical: tokens.spacing.md,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: actions!,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
