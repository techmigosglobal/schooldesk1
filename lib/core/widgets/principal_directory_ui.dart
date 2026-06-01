import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:schooldesk1/core/theme/app_theme.dart';
import 'package:schooldesk1/core/widgets/app_navigation.dart';
import 'package:schooldesk1/core/widgets/empty_state_widget.dart';

const Color principalDirectoryBackground = Color(0xFFEFF8FD);
const Color principalDirectoryAccent = Color(0xFF0887F2);
const Color principalDirectoryText = Color(0xFF1A2A33);
const Color principalDirectoryMuted = Color(0xFF64727E);

class PrincipalDirectoryScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool loading;
  final String? error;
  final Future<void> Function() onRefresh;
  final VoidCallback? onAdd;
  final IconData addIcon;
  final String addTooltip;
  final ScrollController? controller;
  final Widget filters;
  final List<Widget> slivers;
  final Widget? emptyState;
  final bool isEmpty;

  const PrincipalDirectoryScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.loading,
    required this.error,
    required this.onRefresh,
    required this.filters,
    required this.slivers,
    this.onAdd,
    this.addIcon = Icons.add_rounded,
    this.addTooltip = 'Add',
    this.controller,
    this.emptyState,
    this.isEmpty = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: principalDirectoryBackground,
      floatingActionButton: onAdd == null
          ? null
          : FloatingActionButton(
              heroTag: 'principal-directory-add-$title',
              tooltip: addTooltip,
              onPressed: onAdd,
              backgroundColor: principalDirectoryAccent,
              foregroundColor: Colors.white,
              elevation: 8,
              shape: const CircleBorder(),
              child: Icon(addIcon, size: 30),
            ),
      bottomNavigationBar: const PrincipalShellBottomBar(),
      body: SafeArea(
        child: RefreshIndicator(
          color: principalDirectoryAccent,
          onRefresh: onRefresh,
          child: CustomScrollView(
            controller: controller,
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(
                child: PrincipalDirectoryHeader(
                  title: title,
                  subtitle: subtitle,
                  onRefresh: onRefresh,
                ),
              ),
              SliverToBoxAdapter(child: filters),
              if (loading)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (error != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: EmptyStateWidget(
                      icon: Icons.cloud_off_rounded,
                      title: 'Unable to load $title',
                      description: error!,
                    ),
                  ),
                )
              else if (isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child:
                        emptyState ??
                        EmptyStateWidget(
                          icon: Icons.folder_open_rounded,
                          title: 'Nothing to show yet',
                          description:
                              'Create a record or adjust the filters to continue.',
                        ),
                  ),
                )
              else
                ...slivers,
            ],
          ),
        ),
      ),
    );
  }
}

class PrincipalDirectoryHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Future<void> Function()? onRefresh;
  final List<Widget> actions;

  const PrincipalDirectoryHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.onRefresh,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
      child: Column(
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                  tooltip: 'Back',
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          title,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          style: GoogleFonts.dmSans(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: principalDirectoryText,
                          ),
                        ),
                      ),
                      if (subtitle.trim().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.dmSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                            color: principalDirectoryMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (actions.isNotEmpty)
                  ...actions
                else
                  IconButton(
                    onPressed: onRefresh == null ? null : () => onRefresh!(),
                    icon: const Icon(Icons.refresh_rounded, size: 22),
                    tooltip: 'Refresh',
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PrincipalDirectorySearchBox extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onChanged;

  const PrincipalDirectorySearchBox({
    super.key,
    required this.hint,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(12),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextField(
        onChanged: onChanged,
        style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Icon(Icons.search_rounded),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }
}

class PrincipalDirectoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  const PrincipalDirectoryChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final background = selected ? principalDirectoryAccent : Colors.white;
    final foreground = selected ? Colors.white : principalDirectoryText;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        constraints: const BoxConstraints(minHeight: 36),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? principalDirectoryAccent
                : const Color(0xFFD8E4EA),
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: principalDirectoryAccent.withAlpha(44),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: foreground),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.dmSans(
                color: foreground,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PrincipalDirectoryMetricStrip extends StatelessWidget {
  final List<PrincipalDirectoryMetric> metrics;

  const PrincipalDirectoryMetricStrip({super.key, required this.metrics});

  @override
  Widget build(BuildContext context) {
    if (metrics.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 620;
          final width = compact
              ? (constraints.maxWidth - 10) / 2
              : (constraints.maxWidth - 30) / 4;
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final metric in metrics)
                SizedBox(
                  width: width,
                  child: _MetricTile(metric: metric),
                ),
            ],
          );
        },
      ),
    );
  }
}

class PrincipalDirectoryMetric {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color tone;

  const PrincipalDirectoryMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.tone = const Color(0xFFFFFFFF),
  });
}

class _MetricTile extends StatelessWidget {
  final PrincipalDirectoryMetric metric;

  const _MetricTile({required this.metric});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 86),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: metric.tone == Colors.white ? Colors.white : metric.tone,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: metric.color.withAlpha(55)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(210),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(metric.icon, color: metric.color, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    metric.value,
                    style: GoogleFonts.dmSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF111827),
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  metric.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.onSurfaceVariant,
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

class PrincipalDirectoryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? status;
  final Color statusColor;
  final List<Widget> chips;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool selected;
  final Widget? trailing;
  final Widget? body;

  const PrincipalDirectoryCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.status,
    this.statusColor = Colors.indigo,
    this.chips = const [],
    this.onTap,
    this.onLongPress,
    this.selected = false,
    this.trailing,
    this.body,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = selected
        ? principalDirectoryAccent
        : const Color(0xFFE0E8F0);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor, width: selected ? 2 : 1),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7FA6BD).withAlpha(selected ? 70 : 36),
                blurRadius: selected ? 18 : 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: principalDirectoryAccent.withAlpha(24),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: principalDirectoryAccent, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.dmSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: principalDirectoryText,
                            ),
                          ),
                        ),
                        if (status != null)
                          PrincipalStatusPill(
                            label: status!,
                            color: statusColor,
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                        color: principalDirectoryMuted,
                      ),
                    ),
                    if (chips.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(spacing: 8, runSpacing: 8, children: chips),
                    ],
                    if (body != null) ...[const SizedBox(height: 12), body!],
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            ],
          ),
        ),
      ),
    );
  }
}

class PrincipalStatusPill extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const PrincipalStatusPill({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(24),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: color, size: 13),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.dmSans(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class PrincipalInfoPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const PrincipalInfoPill({super.key, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F8FC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFDCE8F5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: principalDirectoryMuted),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.dmSans(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: principalDirectoryMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PrincipalDetailPage extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final List<PopupMenuEntry<String>> menuItems;
  final ValueChanged<String>? onMenuSelected;

  const PrincipalDetailPage({
    super.key,
    required this.title,
    required this.children,
    this.menuItems = const [],
    this.onMenuSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: principalDirectoryBackground,
      appBar: AppBar(
        backgroundColor: principalDirectoryBackground,
        elevation: 0,
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (menuItems.isNotEmpty)
            PopupMenuButton<String>(
              tooltip: 'Options',
              onSelected: onMenuSelected,
              itemBuilder: (_) => menuItems,
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 96),
          children: children,
        ),
      ),
    );
  }
}

class PrincipalDetailCard extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final List<Widget> children;

  const PrincipalDetailCard({
    super.key,
    required this.title,
    required this.children,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7FA6BD).withAlpha(45),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: principalDirectoryText,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class PrincipalDetailRow extends StatelessWidget {
  final String label;
  final String value;

  const PrincipalDetailRow({
    super.key,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 128,
            child: Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: principalDirectoryMuted,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.dmSans(
                color: principalDirectoryText,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PrincipalActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Color color;

  const PrincipalActionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.color = principalDirectoryAccent,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withAlpha(22),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                      color: principalDirectoryText,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                      color: principalDirectoryMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(
                Icons.chevron_right_rounded,
                color: principalDirectoryMuted,
              ),
          ],
        ),
      ),
    );
  }
}

class PrincipalInputPage extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const PrincipalInputPage({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: principalDirectoryBackground,
      appBar: AppBar(
        backgroundColor: principalDirectoryBackground,
        elevation: 0,
        title: Text(title),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
          children: [
            PrincipalDetailCard(
              title: title,
              trailing: Icon(icon, color: principalDirectoryAccent),
              children: [child],
            ),
          ],
        ),
      ),
    );
  }
}
