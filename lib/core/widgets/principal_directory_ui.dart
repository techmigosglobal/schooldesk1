import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:schooldesk1/core/widgets/app_navigation.dart';
import 'package:schooldesk1/core/widgets/empty_state_widget.dart';
import 'package:schooldesk1/core/utils/extensions.dart';

const Color principalDirectoryBackground = Color(0xFFF0F4F8);
const Color principalDirectoryAccent = Color(0xFF1D4ED8);
const Color principalDirectoryText = Color(0xFF0F172A);
const Color principalDirectoryMuted = Color(0xFF64748B);

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

  final List<Widget>? secondaryActions;

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
    this.secondaryActions,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appTheme.background,
      floatingActionButton: onAdd == null
          ? null
          : FloatingActionButton(
              heroTag: 'principal-directory-add-$title',
              tooltip: addTooltip,
              onPressed: onAdd,
              backgroundColor: context.appTheme.primary,
              foregroundColor: Colors.white,
              elevation: 8,
              shape: const CircleBorder(),
              child: Icon(addIcon, size: 30),
            ),
      bottomNavigationBar: const PrincipalShellBottomBar(),
      body: SafeArea(
        child: RefreshIndicator(
          color: context.appTheme.primary,
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
                  actions: secondaryActions ?? const [],
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
                        const EmptyStateWidget(
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
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF103869), Color(0xFF1D4ED8), Color(0xFF0F766E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top bar: back + actions ────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 12, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                    tooltip: 'Back',
                  ),
                  const Spacer(),
                  if (actions.isNotEmpty)
                    ...actions.map(
                      (w) => IconTheme(
                        data: const IconThemeData(color: Colors.white),
                        child: w,
                      ),
                    )
                  else
                    IconButton(
                      onPressed: onRefresh == null ? null : () => onRefresh!(),
                      icon: const Icon(
                        Icons.refresh_rounded,
                        size: 22,
                        color: Colors.white,
                      ),
                      tooltip: 'Refresh',
                    ),
                ],
              ),
            ),
            // ── Title block ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      title,
                      maxLines: 1,
                      style: GoogleFonts.dmSans(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        height: 1.1,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withAlpha(200),
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PrincipalDirectorySearchBox extends StatefulWidget {
  final String hint;
  final ValueChanged<String> onChanged;

  const PrincipalDirectorySearchBox({
    super.key,
    required this.hint,
    required this.onChanged,
  });

  @override
  State<PrincipalDirectorySearchBox> createState() =>
      _PrincipalDirectorySearchBoxState();
}

class _PrincipalDirectorySearchBoxState
    extends State<PrincipalDirectorySearchBox> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (v) => setState(() => _focused = v),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: context.appTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _focused
                ? context.appTheme.primary
                : context.appTheme.outlineVariant,
            width: _focused ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: _focused
                  ? context.appTheme.primary.withAlpha(20)
                  : context.appTheme.onSurface.withAlpha(10),
              blurRadius: _focused ? 12 : 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: TextField(
          onChanged: widget.onChanged,
          style: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: widget.hint,
            prefixIcon: Icon(
              Icons.search_rounded,
              color: _focused
                  ? context.appTheme.primary
                  : context.appTheme.muted,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: context.appTheme.surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        constraints: const BoxConstraints(minHeight: 36),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  colors: [Color(0xFF1D4ED8), Color(0xFF0F766E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: selected ? null : context.appTheme.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? Colors.transparent
                : context.appTheme.outlineVariant,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: const Color(0xFF1D4ED8).withAlpha(50),
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
              Icon(
                icon,
                size: 15,
                color: selected ? Colors.white : context.appTheme.muted,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.dmSans(
                color: selected ? Colors.white : context.appTheme.onSurface,
                fontSize: 12,
                fontWeight: FontWeight.w700,
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
    this.tone = Colors.white,
  });
}

class _MetricTile extends StatelessWidget {
  final PrincipalDirectoryMetric metric;

  const _MetricTile({required this.metric});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      constraints: const BoxConstraints(minHeight: 86),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            metric.color.withAlpha(isDark ? 45 : 22),
            metric.color.withAlpha(isDark ? 25 : 12),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: metric.color.withAlpha(55)),
        boxShadow: [
          BoxShadow(
            color: metric.color.withAlpha(isDark ? 30 : 20),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [metric.color, metric.color.withAlpha(200)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: metric.color.withAlpha(60),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(metric.icon, color: Colors.white, size: 22),
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
                      color: context.appTheme.onSurface,
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
                    fontWeight: FontWeight.w700,
                    color: context.appTheme.muted,
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
        ? context.appTheme.primary
        : context.appTheme.outlineVariant;
    final semanticLabel = status == null || status!.isEmpty
        ? title
        : '$title, $status';
    final card = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: context.appTheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: selected ? 2 : 1),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7FA6BD).withAlpha(selected ? 70 : 30),
                blurRadius: selected ? 20 : 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Accent left bar ──────────────────────────────────
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        principalDirectoryAccent,
                        principalDirectoryAccent.withAlpha(140),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(14),
                      bottomLeft: Radius.circular(14),
                    ),
                  ),
                ),
                // ── Card content ─────────────────────────────────────
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                principalDirectoryAccent.withAlpha(30),
                                principalDirectoryAccent.withAlpha(18),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: principalDirectoryAccent.withAlpha(40),
                            ),
                          ),
                          child: Icon(
                            icon,
                            color: principalDirectoryAccent,
                            size: 24,
                          ),
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
                                        color: context.appTheme.onSurface,
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
                                  fontWeight: FontWeight.w600,
                                  height: 1.4,
                                  color: context.appTheme.muted,
                                ),
                              ),
                              if (chips.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: chips,
                                ),
                              ],
                              if (body != null) ...[
                                const SizedBox(height: 12),
                                body!,
                              ],
                            ],
                          ),
                        ),
                        if (trailing != null) ...[
                          const SizedBox(width: 8),
                          trailing!,
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return Semantics(
      button: onTap != null,
      label: semanticLabel,
      enabled: onTap != null,
      child: card,
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
        gradient: LinearGradient(
          colors: [color.withAlpha(30), color.withAlpha(18)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: color, size: 12),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.dmSans(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
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
        backgroundColor: const Color(0xFF1D4ED8),
        foregroundColor: Colors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF103869), Color(0xFF1D4ED8), Color(0xFF0F766E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.dmSans(
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        actions: [
          if (menuItems.isNotEmpty)
            PopupMenuButton<String>(
              tooltip: 'Options',
              onSelected: onMenuSelected,
              icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
              itemBuilder: (_) => menuItems,
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 96),
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
      decoration: BoxDecoration(
        color: context.appTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7FA6BD).withAlpha(30),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Gradient top accent strip ──────────────────────────────
          Container(
            height: 4,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1D4ED8), Color(0xFF0F766E)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
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
          ),
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
    return Semantics(
      button: onTap != null,
      label: title,
      enabled: onTap != null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color, color.withAlpha(180)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: color.withAlpha(55),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 20),
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
                        fontWeight: FontWeight.w600,
                        height: 1.3,
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
        backgroundColor: const Color(0xFF1D4ED8),
        foregroundColor: Colors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF103869), Color(0xFF1D4ED8), Color(0xFF0F766E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: Text(
          title,
          style: GoogleFonts.dmSans(
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Icon(icon, color: Colors.white.withAlpha(200), size: 22),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            PrincipalDetailCard(title: title, children: [child]),
          ],
        ),
      ),
    );
  }
}
