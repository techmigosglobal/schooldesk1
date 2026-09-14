import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:schooldesk1/core/desktop/desktop_responsive_breakpoints.dart';
import 'package:schooldesk1/core/theme/design_tokens.dart';
import 'package:schooldesk1/routes/app_routes.dart';
import 'package:schooldesk1/features/dashboard/presentation/widgets/todays_highlights_card.dart';
import 'package:schooldesk1/features/dashboard/presentation/widgets/school_feed_preview.dart';

/// Desktop body for the parent portal — true two-column layout.
///
/// Left (main): School feed carousel + today's highlights + quick access.
/// Right (sidebar): Active child overview + stats + child switcher.
class ParentDashboardDesktopBody extends StatelessWidget {
  final List<Map<String, dynamic>> children;
  final Map<String, dynamic> dashboard;
  final int activeChildIndex;
  final List<dynamic> eventPosts;
  final String? feedError;
  final bool feedStale;
  final VoidCallback? onFeedRetry;
  final ValueChanged<int> onChildSelected;

  const ParentDashboardDesktopBody({
    super.key,
    required this.children,
    required this.dashboard,
    required this.activeChildIndex,
    required this.eventPosts,
    this.feedError,
    this.feedStale = false,
    this.onFeedRetry,
    required this.onChildSelected,
  });

  Map<String, dynamic> get _activeChild =>
      children.isNotEmpty ? children[activeChildIndex] : const {};

  List<Map<String, dynamic>> get _feedPosts => eventPosts
      .whereType<Map>()
      .map((row) => Map<String, dynamic>.from(row))
      .toList();

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).schoolDesk;
    final parentColor = tokens.roleColor(SchoolDeskRole.parent);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isWide = DesktopBreakpoints.isWideWidth(width);
        final useTwoPane = DesktopBreakpoints.isTwoPaneWidth(width);
        final sidebarWidth = isWide ? 360.0 : 300.0;
        final isNarrow = !useTwoPane;

        final childContent = isNarrow
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (children.isNotEmpty) ...[
                    _ChildSwitcherPanel(
                      children: children,
                      activeIndex: activeChildIndex,
                      onSelected: onChildSelected,
                      parentColor: parentColor,
                    ),
                    SizedBox(height: tokens.spacing.md),
                    _ChildOverviewPanel(
                      child: _activeChild,
                      dashboard: dashboard,
                      parentColor: parentColor,
                    ),
                    SizedBox(height: tokens.spacing.lg),
                  ],
                  SchoolFeedPreview(
                    posts: _feedPosts,
                    accentColor: parentColor,
                    isStale: feedStale,
                    errorMessage: feedError,
                    onRetry: onFeedRetry,
                  ),
                  SizedBox(height: tokens.spacing.lg),
                  const TodaysHighlightsCard(role: 'parent'),
                  SizedBox(height: tokens.spacing.lg),
                  _ParentQuickAccessDesktopPanel(parentColor: parentColor),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Left: School feed + highlights + quick access ──────────
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SchoolFeedPreview(
                          posts: _feedPosts,
                          accentColor: parentColor,
                          isStale: feedStale,
                          errorMessage: feedError,
                          onRetry: onFeedRetry,
                        ),
                        SizedBox(height: tokens.spacing.lg),
                        const TodaysHighlightsCard(role: 'parent'),
                        SizedBox(height: tokens.spacing.lg),
                        _ParentQuickAccessDesktopPanel(
                          parentColor: parentColor,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: tokens.spacing.lg),
                  // ── Right: Child overview sidebar ─────────────────────────
                  SizedBox(
                    width: sidebarWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (children.isNotEmpty) ...[
                          _ChildSwitcherPanel(
                            children: children,
                            activeIndex: activeChildIndex,
                            onSelected: onChildSelected,
                            parentColor: parentColor,
                          ),
                          SizedBox(height: tokens.spacing.md),
                          _ChildOverviewPanel(
                            child: _activeChild,
                            dashboard: dashboard,
                            parentColor: parentColor,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              );

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            tokens.spacing.xl,
            tokens.spacing.lg,
            tokens.spacing.xl,
            tokens.spacing.xxl,
          ),
          child: childContent,
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Child switcher panel
// ---------------------------------------------------------------------------

class _ChildSwitcherPanel extends StatelessWidget {
  final List<Map<String, dynamic>> children;
  final int activeIndex;
  final ValueChanged<int> onSelected;
  final Color parentColor;

  const _ChildSwitcherPanel({
    required this.children,
    required this.activeIndex,
    required this.onSelected,
    required this.parentColor,
  });

  String _text(Object? val) => '${val ?? ''}'.trim();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;

    if (children.length <= 1) return const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.all(tokens.spacing.md),
      decoration: BoxDecoration(
        color: tokens.panel,
        borderRadius: BorderRadius.circular(tokens.radius.card),
        border: Border.all(color: tokens.panelBorder),
        boxShadow: tokens.elevation.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelHeader(
            title: 'My Children',
            icon: Icons.child_care_rounded,
            accentColor: parentColor,
          ),
          SizedBox(height: tokens.spacing.sm),
          ...children.asMap().entries.map((entry) {
            final idx = entry.key;
            final child = entry.value;
            final name = _text(child['name'] ?? child['full_name']);
            final classSec = _text(
              child['class_section'] ??
                  child['grade'] ??
                  child['section_name'] ??
                  child['class'],
            );
            final isActive = idx == activeIndex;
            return Padding(
              padding: EdgeInsets.only(bottom: tokens.spacing.xs),
              child: InkWell(
                onTap: () => onSelected(idx),
                borderRadius: BorderRadius.circular(tokens.radius.control),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: EdgeInsets.all(tokens.spacing.sm),
                  decoration: BoxDecoration(
                    color: isActive
                        ? parentColor.withAlpha(tokens.isDark ? 50 : 25)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(tokens.radius.control),
                    border: Border.all(
                      color: isActive
                          ? parentColor.withAlpha(80)
                          : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: parentColor.withAlpha(30),
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: TextStyle(
                            color: parentColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name.isEmpty ? 'Child ${idx + 1}' : name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: isActive ? parentColor : null,
                              ),
                            ),
                            if (classSec.isNotEmpty)
                              Text(
                                classSec,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: tokens.textMuted,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (isActive)
                        Icon(
                          Icons.check_circle_rounded,
                          size: 16,
                          color: parentColor,
                        ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Child overview panel — attendance, fees, quick stats
// ---------------------------------------------------------------------------

class _ChildOverviewPanel extends StatelessWidget {
  final Map<String, dynamic> child;
  final Map<String, dynamic> dashboard;
  final Color parentColor;

  const _ChildOverviewPanel({
    required this.child,
    required this.dashboard,
    required this.parentColor,
  });

  String _text(Object? val) => '${val ?? ''}'.trim();
  double _double(Object? val) {
    if (val is num) return val.toDouble();
    return double.tryParse(_text(val)) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;

    final name = _text(child['name'] ?? child['full_name']);
    final classSec = _text(
      child['class_section'] ??
          child['grade'] ??
          child['section_name'] ??
          child['class'],
    );
    final attendancePct = _double(child['attendance_pct']);
    final feeBalance = _double(child['pending_fee_balance']);
    final homeworkPending = (child['homework_due'] as int?) ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: tokens.panel,
        borderRadius: BorderRadius.circular(tokens.radius.card),
        border: Border.all(color: tokens.panelBorder),
        boxShadow: tokens.elevation.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with child name
          Container(
            padding: EdgeInsets.all(tokens.spacing.md),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [parentColor, parentColor.withAlpha(180)],
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(tokens.radius.card),
                topRight: Radius.circular(tokens.radius.card),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name.isEmpty ? 'Your Child' : name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.dmSans(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (classSec.isNotEmpty)
                        Text(
                          classSec,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 13,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Stats
          Padding(
            padding: EdgeInsets.all(tokens.spacing.md),
            child: Column(
              children: [
                _StatRow(
                  label: "Attendance",
                  value: attendancePct > 0
                      ? '${attendancePct.toStringAsFixed(1)}%'
                      : 'N/A',
                  icon: Icons.bar_chart_rounded,
                  color: attendancePct >= 75
                      ? const Color(0xFF16A34A)
                      : attendancePct > 0
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFF6B7280),
                ),
                Divider(height: tokens.spacing.md, color: tokens.panelBorder),
                _StatRow(
                  label: 'Fee Balance',
                  value: feeBalance > 0
                      ? '₹${NumberFormat('#,##,###').format(feeBalance)}'
                      : 'Clear',
                  icon: Icons.account_balance_wallet_rounded,
                  color: feeBalance > 0
                      ? const Color(0xFFEF4444)
                      : const Color(0xFF16A34A),
                ),
                Divider(height: tokens.spacing.md, color: tokens.panelBorder),
                _StatRow(
                  label: 'Dairy Pending',
                  value: '$homeworkPending',
                  icon: Icons.assignment_outlined,
                  color: homeworkPending > 0
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFF16A34A),
                ),
                SizedBox(height: tokens.spacing.md),
                // Quick actions
                _ChildQuickActions(parentColor: parentColor),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;

    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withAlpha(20),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: tokens.textMuted,
            ),
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _ChildQuickActions extends StatelessWidget {
  final Color parentColor;

  const _ChildQuickActions({required this.parentColor});

  @override
  Widget build(BuildContext context) {
    final actions = [
      ('Attendance', Icons.bar_chart_rounded, AppRoutes.parentAttendance),
      ('Dairy', Icons.assignment_rounded, AppRoutes.parentHomework),
      ('Fee', Icons.account_balance_wallet_rounded, AppRoutes.parentFees),
      ('Leave', Icons.event_busy_rounded, AppRoutes.parentLeave),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 2.5,
      children: [
        for (final action in actions)
          _ChildActionButton(
            label: action.$1,
            icon: action.$2,
            color: parentColor,
            onTap: () => Navigator.pushNamed(context, action.$3),
          ),
      ],
    );
  }
}

class _ChildActionButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ChildActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  State<_ChildActionButton> createState() => _ChildActionButtonState();
}

class _ChildActionButtonState extends State<_ChildActionButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        decoration: BoxDecoration(
          color: _hovering
              ? widget.color.withAlpha(tokens.isDark ? 40 : 20)
              : tokens.panelMuted,
          borderRadius: BorderRadius.circular(tokens.radius.control),
          border: Border.all(
            color: _hovering ? widget.color.withAlpha(100) : tokens.panelBorder,
          ),
        ),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(tokens.radius.control),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(widget.icon, size: 14, color: widget.color),
                const SizedBox(width: 6),
                Text(
                  widget.label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: _hovering ? widget.color : null,
                    fontWeight: FontWeight.w700,
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

// ---------------------------------------------------------------------------
// Parent quick access desktop panel
// ---------------------------------------------------------------------------

class _ParentQuickAccessDesktopPanel extends StatelessWidget {
  final Color parentColor;

  const _ParentQuickAccessDesktopPanel({required this.parentColor});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;

    final actions = [
      (
        'Student Details',
        'Academic profile',
        Icons.person_rounded,
        const Color(0xFF5B35F5),
        AppRoutes.parentDashboard,
      ),
      (
        'Attendance',
        'Daily records',
        Icons.bar_chart_rounded,
        const Color(0xFF0E9384),
        AppRoutes.parentAttendance,
      ),
      (
        'Dairy',
        'Assignments',
        Icons.assignment_rounded,
        const Color(0xFF7C3AED),
        AppRoutes.parentHomework,
      ),
      (
        'Timetable',
        'Class schedule',
        Icons.calendar_month_rounded,
        const Color(0xFF2563EB),
        AppRoutes.parentTimetable,
      ),
      (
        'Fee Details',
        'Payments & balance',
        Icons.account_balance_wallet_rounded,
        const Color(0xFF16A34A),
        AppRoutes.parentFees,
      ),
      (
        'Notices',
        'School updates',
        Icons.campaign_rounded,
        const Color(0xFFEA580C),
        AppRoutes.parentDashboard,
      ),
      (
        'Student Leave',
        'Apply for absence',
        Icons.event_busy_rounded,
        const Color(0xFFDB2777),
        AppRoutes.parentLeave,
      ),
      (
        'Gallery',
        'School photos',
        Icons.photo_library_rounded,
        const Color(0xFF9333EA),
        AppRoutes.schoolGallery,
      ),
    ];

    return Container(
      padding: EdgeInsets.all(tokens.spacing.md),
      decoration: BoxDecoration(
        color: tokens.panel,
        borderRadius: BorderRadius.circular(tokens.radius.card),
        border: Border.all(color: tokens.panelBorder),
        boxShadow: tokens.elevation.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelHeader(
            title: 'Quick Access',
            icon: Icons.grid_view_rounded,
            accentColor: parentColor,
          ),
          SizedBox(height: tokens.spacing.md),
          LayoutBuilder(
            builder: (context, constraints) {
              final cols = constraints.maxWidth >= 600 ? 4 : 3;
              return GridView.count(
                crossAxisCount: cols,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.6,
                children: [
                  for (final action in actions)
                    _QuickAccessTile(
                      label: action.$1,
                      subtitle: action.$2,
                      icon: action.$3,
                      color: action.$4,
                      onTap: () => Navigator.pushNamed(context, action.$5),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _QuickAccessTile extends StatefulWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuickAccessTile({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  State<_QuickAccessTile> createState() => _QuickAccessTileState();
}

class _QuickAccessTileState extends State<_QuickAccessTile> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: _hovering
              ? widget.color.withAlpha(tokens.isDark ? 40 : 18)
              : tokens.panelMuted,
          borderRadius: BorderRadius.circular(tokens.radius.control),
          border: Border.all(
            color: _hovering ? widget.color.withAlpha(80) : tokens.panelBorder,
          ),
        ),
        transform: Matrix4.identity()..translate(0.0, _hovering ? -2.0 : 0.0),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(tokens.radius.control),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: widget.color.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(widget.icon, size: 16, color: widget.color),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: _hovering ? widget.color : null,
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

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

class _PanelHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color accentColor;

  const _PanelHeader({
    required this.title,
    required this.icon,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: accentColor.withAlpha(24),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: accentColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}
