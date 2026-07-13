import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:schooldesk1/core/desktop/desktop_responsive_breakpoints.dart';
import 'package:schooldesk1/core/theme/design_tokens.dart';
import 'package:schooldesk1/core/widgets/app_background.dart';
import 'package:schooldesk1/core/widgets/app_navigation.dart';

/// Desktop shell for the principal portal — persistent sidebar + full-width body.
class PrincipalDashboardDesktopShell extends StatelessWidget {
  final Widget body;
  final bool isSuperAdmin;
  final VoidCallback onBackPressed;

  const PrincipalDashboardDesktopShell({
    super.key,
    required this.body,
    required this.isSuperAdmin,
    required this.onBackPressed,
  });

  @override
  Widget build(BuildContext context) {
    final drawer = isSuperAdmin
        ? SuperAdminDrawer(selectedIndex: 0, onDestinationSelected: (_) {})
        : PrincipalDrawer(selectedIndex: 0, onDestinationSelected: (_) {});

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) onBackPressed();
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: AppBackground(
          accent: const Color(0xFF1478F2),
          child: SafeArea(
            bottom: false,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: DesktopBreakpoints.sidebarExpanded,
                  child: Material(
                    elevation: 0,
                    color: Colors.transparent,
                    child: drawer,
                  ),
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: DesktopBreakpoints.contentMaxWidth(
                          MediaQuery.sizeOf(context).width -
                              DesktopBreakpoints.sidebarExpanded,
                        ),
                      ),
                      child: body,
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

/// Premium desktop body for the principal dashboard — true multi-column layout.
///
/// Delivers an executive-dashboard feel with:
/// • A full-width header with KPI stat cards
/// • Left main column: Academics module grid + School setup progress
/// • Right sidebar: Today's highlights + pending actions panel
class PrincipalDashboardDesktopBody extends StatelessWidget {
  final Widget header;
  final Widget searchBar;
  final Widget statsRow;
  final Widget academicsSection;
  final Widget highlights;
  final Widget setupSection;

  const PrincipalDashboardDesktopBody({
    super.key,
    required this.header,
    required this.searchBar,
    required this.statsRow,
    required this.academicsSection,
    required this.highlights,
    required this.setupSection,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).schoolDesk;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isWide = DesktopBreakpoints.isWideWidth(width);
        final useTwoPane = DesktopBreakpoints.isTwoPaneWidth(width);
        // Side panel: 340px on standard desktop, 380px on wide
        final sidePanelWidth = isWide ? 380.0 : 340.0;
        final contentSpacing = tokens.spacing.lg;
        final isNarrow = !useTwoPane;

        final twoColumnContent = isNarrow
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Main column
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _SectionLabel(
                        label: 'Academics',
                        icon: Icons.school_rounded,
                        color: Color(0xFF1478F2),
                      ),
                      SizedBox(height: tokens.spacing.sm),
                      academicsSection,
                      SizedBox(height: contentSpacing),
                      const _SectionLabel(
                        label: 'School Setup',
                        icon: Icons.tune_rounded,
                        color: Color(0xFF7C3AED),
                      ),
                      SizedBox(height: tokens.spacing.sm),
                      setupSection,
                    ],
                  ),
                  SizedBox(height: contentSpacing * 1.5),
                  // Highlights
                  const _SectionLabel(
                    label: "Today's Highlights",
                    icon: Icons.today_rounded,
                    color: Color(0xFF0E9384),
                  ),
                  SizedBox(height: tokens.spacing.sm),
                  highlights,
                ],
              )
            : IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Main column: Academics grid + setup
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Academics section header
                          const _SectionLabel(
                            label: 'Academics',
                            icon: Icons.school_rounded,
                            color: Color(0xFF1478F2),
                          ),
                          SizedBox(height: tokens.spacing.sm),
                          academicsSection,
                          SizedBox(height: contentSpacing),
                          // School setup (full width within main column)
                          const _SectionLabel(
                            label: 'School Setup',
                            icon: Icons.tune_rounded,
                            color: Color(0xFF7C3AED),
                          ),
                          SizedBox(height: tokens.spacing.sm),
                          setupSection,
                        ],
                      ),
                    ),
                    SizedBox(width: contentSpacing),

                    // Sidebar: Today's highlights + pending actions
                    SizedBox(
                      width: sidePanelWidth,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const _SectionLabel(
                            label: "Today's Highlights",
                            icon: Icons.today_rounded,
                            color: Color(0xFF0E9384),
                          ),
                          SizedBox(height: tokens.spacing.sm),
                          highlights,
                        ],
                      ),
                    ),
                  ],
                ),
              );

        return RefreshIndicator(
          onRefresh: () async {},
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              contentSpacing,
              contentSpacing,
              contentSpacing,
              contentSpacing * 2,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Header row: greeting + search bar ──────────────────────
                if (useTwoPane)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: header),
                      SizedBox(width: contentSpacing),
                      SizedBox(width: sidePanelWidth, child: searchBar),
                    ],
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      header,
                      SizedBox(height: contentSpacing),
                      searchBar,
                    ],
                  ),
                SizedBox(height: contentSpacing),

                // ── KPI stats row (full-width) ─────────────────────────────
                statsRow,
                SizedBox(height: contentSpacing),

                // ── Two-column zone ────────────────────────────────────────
                twoColumnContent,
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Section label with accent icon for desktop dashboard panels.
class _SectionLabel extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _SectionLabel({
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color.withAlpha(20),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

/// Desktop back handler helper for principal portal root.
void handlePrincipalDesktopBack(BuildContext context, DateTime? lastPress) {
  final now = DateTime.now();
  if (lastPress != null &&
      now.difference(lastPress) <= const Duration(seconds: 2)) {
    SystemNavigator.pop();
    return;
  }
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(
      const SnackBar(
        content: Text('Press back again to exit'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
}
