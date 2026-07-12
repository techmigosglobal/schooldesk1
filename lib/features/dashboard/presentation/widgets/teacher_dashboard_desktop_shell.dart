import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:schooldesk1/core/desktop/desktop_responsive_breakpoints.dart';
import 'package:schooldesk1/core/theme/design_tokens.dart';
import 'package:schooldesk1/core/widgets/teacher_flow_ui.dart';
import 'package:schooldesk1/routes/app_routes.dart';
import 'package:schooldesk1/features/dashboard/presentation/widgets/todays_highlights_card.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';

/// Desktop body for the teacher dashboard — true two-column layout.
///
/// Left (main): Current class hero card + timetable feed.
/// Right (sidebar): Quick-action grid + today's action queue + notices.
class TeacherDashboardDesktopBody extends StatelessWidget {
  final String teacherName;
  final String assignedClass;
  final String assignedSubject;
  final List<Map<String, dynamic>> timetable;
  final List<dynamic> announcements;
  final int attendancePending;
  final bool roleScopeLoaded;
  final bool hasStaffLink;
  final bool hasAssignedClasses;
  final StaffAttendanceModel? myAttendance;
  final VoidCallback onRefresh;

  const TeacherDashboardDesktopBody({
    super.key,
    required this.teacherName,
    required this.assignedClass,
    required this.assignedSubject,
    required this.timetable,
    required this.announcements,
    required this.attendancePending,
    required this.roleScopeLoaded,
    required this.hasStaffLink,
    required this.hasAssignedClasses,
    this.myAttendance,
    required this.onRefresh,
  });

  String get _shortName => teacherName.split(' ').take(2).join(' ');

  String get _currentClass {
    if (timetable.isNotEmpty) {
      final label = teacherFlowText(timetable.first['class']);
      if (label.isNotEmpty) return label;
    }
    return assignedClass;
  }

  String get _currentSubject {
    if (timetable.isNotEmpty) {
      final subjects = timetable
          .map((r) => teacherFlowText(r['subject']))
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList();
      if (subjects.isNotEmpty) return subjects.join(', ');
    }
    return assignedSubject;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).schoolDesk;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isWide = DesktopBreakpoints.isWideWidth(width);
        final sidebarWidth = isWide ? 380.0 : 320.0;

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            tokens.spacing.xl,
            tokens.spacing.lg,
            tokens.spacing.xl,
            tokens.spacing.xxl,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Main content column ──────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildClassHeroPanel(context, tokens),
                    SizedBox(height: tokens.spacing.lg),
                    const TodaysHighlightsCard(role: 'teacher'),
                    SizedBox(height: tokens.spacing.lg),
                    _buildTodayFeedPanel(context, tokens),
                    if (announcements.isNotEmpty) ...[
                      SizedBox(height: tokens.spacing.lg),
                      _buildNoticesPanel(context, tokens),
                    ],
                  ],
                ),
              ),
              SizedBox(width: tokens.spacing.lg),
              // ── Sidebar column ────────────────────────────────────────────
              SizedBox(
                width: sidebarWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildQuickActionsPanel(context, tokens),
                    SizedBox(height: tokens.spacing.md),
                    _buildActionQueuePanel(context, tokens),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildClassHeroPanel(BuildContext context, SchoolDeskTheme tokens) {
    final hasSetup = !roleScopeLoaded || (!hasStaffLink || !hasAssignedClasses);
    if (hasSetup) {
      return _DesktopTeacherSetupCard(
        hasStaffLink: !roleScopeLoaded || hasStaffLink,
      );
    }

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF183037), Color(0xFF0F5A51)],
        ),
        borderRadius: BorderRadius.circular(tokens.radius.card + 4),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A2E2A).withOpacity(0.3),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left: greeting + class info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFF10B981),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'CLASSROOM ACTIVE',
                            style: GoogleFonts.dmSans(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Good day, $_shortName',
                  style: GoogleFonts.dmSans(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _currentClass,
                  style: GoogleFonts.dmSans(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _currentSubject,
                  style: GoogleFonts.dmSans(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    _TeacherHeroAction(
                      label: 'My Login',
                      icon: Icons.qr_code_scanner_rounded,
                      filled: true,
                      onTap: () => Navigator.pushNamed(
                        context,
                        AppRoutes.teacherMyAttendance,
                        arguments: {'auto_scan': true},
                      ),
                    ),
                    _TeacherHeroAction(
                      label: 'Student Attendance',
                      icon: Icons.how_to_reg_rounded,
                      onTap: () => Navigator.pushNamed(
                        context,
                        AppRoutes.teacherAttendance,
                      ),
                    ),
                    _TeacherHeroAction(
                      label: 'Timetable',
                      icon: Icons.calendar_month_rounded,
                      onTap: () => Navigator.pushNamed(
                        context,
                        AppRoutes.teacherTimetable,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          // Right: stat pills
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _TeacherStatPill(
                label: 'Attendance Pending',
                value: '$attendancePending',
                icon: Icons.pending_actions_rounded,
                color: attendancePending > 0
                    ? const Color(0xFFF59E0B)
                    : const Color(0xFF10B981),
              ),
              const SizedBox(height: 10),
              _TeacherStatPill(
                label: 'Today Periods',
                value: '${timetable.length}',
                icon: Icons.schedule_rounded,
                color: const Color(0xFF60A5FA),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTodayFeedPanel(BuildContext context, SchoolDeskTheme tokens) {
    return _DesktopPanel(
      title: 'Today Feed',
      icon: Icons.today_rounded,
      accentColor: teacherFlowAccent,
      child: Column(
        children: [
          _FeedItem(
            time: 'Now',
            title: 'Self Attendance',
            subtitle: myAttendance == null
                ? 'Punch-in pending'
                : 'Punch-in ${myAttendance!.checkInTimeLabel}',
            icon: Icons.qr_code_scanner_rounded,
            color: teacherFlowAccent,
            onTap: () => Navigator.pushNamed(
              context,
              AppRoutes.teacherMyAttendance,
              arguments: {'auto_scan': true},
            ),
          ),
          if (timetable.isEmpty)
            _FeedItem(
              time: 'Today',
              title: 'No classes scheduled today',
              subtitle: 'Your weekly timetable is available in My Timetable.',
              icon: Icons.event_busy_rounded,
              color: Colors.orange,
              onTap: () =>
                  Navigator.pushNamed(context, AppRoutes.teacherTimetable),
            )
          else
            ...timetable.map((row) {
              final subject = teacherFlowText(row['subject'], fallback: 'Subject');
              final time = teacherFlowText(row['time'], fallback: 'Period');
              final classLabel =
                  teacherFlowText(row['class'], fallback: _currentClass);
              return _FeedItem(
                time: time,
                title: '$subject - $classLabel',
                subtitle: 'Review class period and plan next steps.',
                icon: Icons.auto_stories_rounded,
                color: teacherFlowAccent,
                onTap: () => Navigator.pushNamed(
                  context,
                  AppRoutes.teacherLessonPlanner,
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildNoticesPanel(BuildContext context, SchoolDeskTheme tokens) {
    return _DesktopPanel(
      title: 'School Notices',
      icon: Icons.campaign_rounded,
      accentColor: const Color(0xFFEA580C),
      child: Column(
        children: [
          for (final notice in announcements.take(3))
            if (notice is AnnouncementModel)
              _FeedItem(
                time: notice.isUrgent ? 'Urgent' : 'Notice',
                title: notice.title,
                subtitle: notice.content,
                icon: Icons.campaign_rounded,
                color: notice.isUrgent
                    ? const Color(0xFFEF4444)
                    : teacherFlowAccent,
                onTap: () => Navigator.pushNamed(
                  context,
                  AppRoutes.teacherCommunication,
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsPanel(BuildContext context, SchoolDeskTheme tokens) {
    final actions = [
      (
        'My Classes',
        'Assigned sections',
        Icons.class_rounded,
        const Color(0xFF5B35F5),
        AppRoutes.teacherClasses
      ),
      (
        'Timetable',
        'Today and week',
        Icons.calendar_month_rounded,
        const Color(0xFF0EA5E9),
        AppRoutes.teacherTimetable
      ),
      (
        'Attendance',
        'Mark your class',
        Icons.how_to_reg_rounded,
        const Color(0xFF0E9384),
        AppRoutes.teacherAttendance
      ),
      (
        'Lesson Planner',
        'Weekly plans',
        Icons.auto_stories_rounded,
        const Color(0xFFDB2777),
        AppRoutes.teacherLessonPlanner
      ),
      (
        'Homework',
        'Assignments & review',
        Icons.assignment_rounded,
        const Color(0xFF7C3AED),
        AppRoutes.teacherHomework
      ),
      (
        'Leaves',
        'Apply and track',
        Icons.event_busy_rounded,
        const Color(0xFFF59E0B),
        AppRoutes.teacherLeave
      ),
    ];

    return _DesktopPanel(
      title: 'Quick Actions',
      icon: Icons.grid_view_rounded,
      accentColor: teacherFlowAccent,
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 2.2,
        children: [
          for (final action in actions)
            _QuickActionTile(
              label: action.$1,
              subtitle: action.$2,
              icon: action.$3,
              color: action.$4,
              onTap: () => Navigator.pushNamed(context, action.$5),
            ),
        ],
      ),
    );
  }

  Widget _buildActionQueuePanel(BuildContext context, SchoolDeskTheme tokens) {
    return _DesktopPanel(
      title: 'Today Action Queue',
      icon: Icons.checklist_rounded,
      accentColor: const Color(0xFF2563EB),
      child: Column(
        children: [
          _ActionQueueItem(
            label: 'Mark Student Attendance',
            subtitle: attendancePending > 0
                ? 'Finish attendance for $attendancePending pending period${attendancePending == 1 ? '' : 's'}.'
                : 'Open attendance when your class is ready.',
            icon: Icons.how_to_reg_rounded,
            color: Colors.indigo,
            urgency: attendancePending > 0 ? 'Required' : 'Ready',
            onTap: () =>
                Navigator.pushNamed(context, AppRoutes.teacherAttendance),
          ),
          const SizedBox(height: 8),
          _ActionQueueItem(
            label: 'Track Leave',
            subtitle: 'Review your leave requests and approval status.',
            icon: Icons.event_busy_rounded,
            color: Colors.purple,
            urgency: 'Admin',
            onTap: () =>
                Navigator.pushNamed(context, AppRoutes.teacherLeave),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared desktop panel container
// ---------------------------------------------------------------------------

class _DesktopPanel extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color accentColor;
  final Widget child;

  const _DesktopPanel({
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;

    return Container(
      padding: EdgeInsets.all(tokens.spacing.md),
      decoration: BoxDecoration(
        color: tokens.panel,
        borderRadius: BorderRadius.circular(tokens.radius.card),
        border: Border.all(color: tokens.panelBorder),
        boxShadow: tokens.elevation.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
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
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          Divider(
            height: tokens.spacing.md + tokens.spacing.sm,
            color: tokens.panelBorder,
          ),
          child,
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Feed item row
// ---------------------------------------------------------------------------

class _FeedItem extends StatelessWidget {
  final String time;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _FeedItem({
    required this.time,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(tokens.radius.control),
        child: Container(
          padding: EdgeInsets.all(tokens.spacing.sm),
          decoration: BoxDecoration(
            color: color.withAlpha(tokens.isDark ? 20 : 10),
            borderRadius: BorderRadius.circular(tokens.radius.control),
            border: Border.all(color: color.withAlpha(40)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: tokens.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  time,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
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

// ---------------------------------------------------------------------------
// Quick action tile
// ---------------------------------------------------------------------------

class _QuickActionTile extends StatefulWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  State<_QuickActionTile> createState() => _QuickActionTileState();
}

class _QuickActionTileState extends State<_QuickActionTile> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: BoxDecoration(
          color: _hovering
              ? widget.color.withAlpha(tokens.isDark ? 40 : 20)
              : tokens.panelMuted,
          borderRadius: BorderRadius.circular(tokens.radius.control),
          border: Border.all(
            color: _hovering
                ? widget.color.withAlpha(100)
                : tokens.panelBorder,
          ),
        ),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(tokens.radius.control),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: widget.color.withAlpha(24),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(widget.icon, size: 16, color: widget.color),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        widget.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: tokens.textMuted,
                        ),
                      ),
                    ],
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
// Action queue item
// ---------------------------------------------------------------------------

class _ActionQueueItem extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String urgency;
  final VoidCallback onTap;

  const _ActionQueueItem({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.urgency,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(tokens.radius.control),
        child: Container(
          padding: EdgeInsets.all(tokens.spacing.sm),
          decoration: BoxDecoration(
            color: color.withAlpha(tokens.isDark ? 20 : 10),
            borderRadius: BorderRadius.circular(tokens.radius.control),
            border: Border.all(color: color.withAlpha(40)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: tokens.textMuted,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: color.withAlpha(20),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      urgency,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 12,
                    color: tokens.textMuted,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Teacher stat pill
// ---------------------------------------------------------------------------

class _TeacherStatPill extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _TeacherStatPill({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.dmSans(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              color: Colors.white.withOpacity(0.65),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Teacher hero action button
// ---------------------------------------------------------------------------

class _TeacherHeroAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool filled;
  final VoidCallback? onTap;

  const _TeacherHeroAction({
    required this.label,
    required this.icon,
    this.filled = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (filled) {
      return ElevatedButton.icon(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF0F5A51),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.dmSans(fontWeight: FontWeight.w800),
        ),
        icon: Icon(icon, size: 16),
        label: Text(label),
      );
    }
    return OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: BorderSide(color: Colors.white.withOpacity(0.25)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
      ),
      icon: Icon(icon, size: 16),
      label: Text(label),
    );
  }
}

// ---------------------------------------------------------------------------
// Setup card for teachers without staff link or assigned classes
// ---------------------------------------------------------------------------

class _DesktopTeacherSetupCard extends StatelessWidget {
  final bool hasStaffLink;

  const _DesktopTeacherSetupCard({required this.hasStaffLink});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: tokens.panel,
        borderRadius: BorderRadius.circular(tokens.radius.card + 4),
        border: Border.all(color: tokens.panelBorder),
        boxShadow: tokens.elevation.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: teacherFlowAccent.withAlpha(20),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.badge_outlined,
              color: teacherFlowAccent,
              size: 28,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            hasStaffLink
                ? 'No classes assigned yet.'
                : 'Account setup required.',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasStaffLink
                ? 'Your classes, timetable, and attendance workflow will appear after assignment.'
                : 'Your teacher account is not linked to a staff profile. Please contact Admin/Principal.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: tokens.textMuted,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
