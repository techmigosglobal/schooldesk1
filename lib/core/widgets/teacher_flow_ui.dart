import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:schooldesk1/routes/app_routes.dart';
import 'package:schooldesk1/core/services/role_access_service.dart';
import 'package:schooldesk1/core/theme/app_theme.dart';
import 'package:schooldesk1/core/theme/design_tokens.dart';
import 'package:schooldesk1/core/widgets/erp_module_scaffold.dart';
import 'package:schooldesk1/core/widgets/teacher_navigation.dart';

const Color teacherFlowBackground = Color(0xFFF4FAFB);
const Color teacherFlowAccent = Color(0xFF0F9F8E);
const Color teacherFlowInk = Color(0xFF183037);
const Color teacherFlowMuted = Color(0xFF61727B);
const Color teacherFlowWarm = Color(0xFFF59E0B);

class TeacherFlowScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final int selectedIndex;
  final Widget child;
  final bool loading;
  final String? error;
  final Future<void> Function()? onRefresh;
  final List<Widget> actions;
  final Widget? floatingActionButton;
  final List<SchoolDeskModuleBottomAction>? mobileBottomActions;

  const TeacherFlowScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.selectedIndex,
    required this.child,
    this.loading = false,
    this.error,
    this.onRefresh,
    this.actions = const [],
    this.floatingActionButton,
    this.mobileBottomActions,
  });

  @override
  Widget build(BuildContext context) {
    return SchoolDeskModuleScaffold(
      title: title,
      subtitle: subtitle,
      drawer: TeacherDrawer(
        selectedIndex: selectedIndex,
        onDestinationSelected: (_) {},
      ),
      actions: [
        ...actions,
        if (onRefresh != null)
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: loading ? null : () => onRefresh!(),
          ),
      ],
      mobileBottomActions: mobileBottomActions ?? teacherFlowBottomActions,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bodyIsScrollable: false,
      body: Container(
        color: teacherFlowBackground,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: loading
              ? const TeacherFlowLoading()
              : error != null
              ? TeacherFlowError(message: error!, onRetry: onRefresh)
              : child,
        ),
      ),
    );
  }
}

const List<SchoolDeskModuleBottomAction> teacherFlowBottomActions = [
  SchoolDeskModuleBottomAction(
    label: 'Home',
    icon: Icons.home_outlined,
    activeIcon: Icons.home_rounded,
    route: AppRoutes.teacherDashboard,
  ),
  SchoolDeskModuleBottomAction(
    label: 'Scan',
    icon: Icons.qr_code_scanner_outlined,
    activeIcon: Icons.qr_code_scanner_rounded,
    route: AppRoutes.teacherMyAttendance,
  ),
  SchoolDeskModuleBottomAction(
    label: 'Class',
    icon: Icons.school_outlined,
    activeIcon: Icons.school_rounded,
    route: AppRoutes.teacherAttendance,
  ),
  SchoolDeskModuleBottomAction(
    label: 'Diary',
    icon: Icons.assignment_outlined,
    activeIcon: Icons.assignment_rounded,
    route: AppRoutes.teacherHomework,
  ),
];

class TeacherFlowScrollView extends StatelessWidget {
  final List<Widget> children;

  const TeacherFlowScrollView({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final horizontal = width >= 840 ? 28.0 : 18.0;
    return ListView(
      padding: EdgeInsets.fromLTRB(horizontal, 18, horizontal, 96),
      children: children,
    );
  }
}

class TeacherCurrentClassCard extends StatelessWidget {
  final String greeting;
  final String classLabel;
  final String subject;
  final String timeLabel;
  final List<TeacherFlowAction> actions;

  const TeacherCurrentClassCard({
    super.key,
    required this.greeting,
    required this.classLabel,
    required this.subject,
    required this.timeLabel,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final teacherColor = Theme.of(
      context,
    ).schoolDesk.roleColor(SchoolDeskRole.teacher);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: teacherColor.withAlpha(48)),
        boxShadow: [
          BoxShadow(
            color: teacherColor.withAlpha(28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: teacherColor.withAlpha(24),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.auto_stories_rounded,
                  color: teacherColor,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      greeting,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                        color: teacherFlowMuted,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      classLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                        color: teacherFlowInk,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$subject · $timeLabel',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                        color: teacherFlowMuted,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 16),
            TeacherFlowActionWrap(actions: actions),
          ],
        ],
      ),
    );
  }
}

class TeacherFlowMetricGrid extends StatelessWidget {
  final List<TeacherFlowMetric> metrics;

  const TeacherFlowMetricGrid({super.key, required this.metrics});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final columns = SchoolDeskResponsive.gridColumnsForWidth(width);
        final spacing = Theme.of(context).schoolDesk.spacing.compact;
        final tileWidth = (width - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final metric in metrics)
              SizedBox(width: tileWidth, child: _TeacherMetricTile(metric)),
          ],
        );
      },
    );
  }
}

class TeacherFlowMetric {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color tone;

  const TeacherFlowMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.tone = Colors.white,
  });
}

class _TeacherMetricTile extends StatelessWidget {
  final TeacherFlowMetric metric;

  const _TeacherMetricTile(this.metric);

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 88),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: metric.tone,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: metric.color.withAlpha(54)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(220),
              borderRadius: BorderRadius.circular(10),
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
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: teacherFlowInk,
                    ),
                  ),
                ),
                Text(
                  metric.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: teacherFlowMuted,
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

class TeacherFlowCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? status;
  final Color statusColor;
  final Widget? body;
  final Widget? trailing;
  final VoidCallback? onTap;

  const TeacherFlowCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.status,
    this.statusColor = teacherFlowAccent,
    this.body,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(tokens.radius.card),
        child: Container(
          padding: EdgeInsets.all(tokens.spacing.compact),
          decoration: BoxDecoration(
            color: tokens.panel,
            borderRadius: BorderRadius.circular(tokens.radius.card),
            border: Border.all(color: const Color(0xFFD9E7EB)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6C98A5).withAlpha(28),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: tokens.sizing.iconContainer,
                height: tokens.sizing.iconContainer,
                decoration: BoxDecoration(
                  color: teacherFlowAccent.withAlpha(22),
                  borderRadius: BorderRadius.circular(tokens.radius.control),
                ),
                child: Icon(icon, color: teacherFlowAccent, size: 24),
              ),
              SizedBox(width: tokens.spacing.compact),
              Expanded(
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
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: teacherFlowInk,
                            ),
                          ),
                        ),
                        if (status != null)
                          TeacherStatusPill(label: status!, color: statusColor),
                      ],
                    ),
                    SizedBox(height: tokens.spacing.xs),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                        color: teacherFlowMuted,
                      ),
                    ),
                    if (body != null) ...[
                      SizedBox(height: tokens.spacing.compact),
                      body!,
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
        ),
      ),
    );
  }
}

class TeacherStatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const TeacherStatusPill({
    super.key,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(24),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.dmSans(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class TeacherInfoPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const TeacherInfoPill({super.key, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF5FBFD),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFDDECEF)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: teacherFlowMuted),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.dmSans(
                color: teacherFlowMuted,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TeacherFlowActionWrap extends StatelessWidget {
  final List<TeacherFlowAction> actions;

  const TeacherFlowActionWrap({super.key, required this.actions});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final action in actions)
          action.filled
              ? FilledButton.icon(
                  onPressed: action.onTap,
                  icon: Icon(action.icon, size: 18),
                  label: Text(action.label),
                )
              : OutlinedButton.icon(
                  onPressed: action.onTap,
                  icon: Icon(action.icon, size: 18),
                  label: Text(action.label),
                ),
      ],
    );
  }
}

class TeacherFlowAction {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool filled;

  const TeacherFlowAction({
    required this.label,
    required this.icon,
    this.onTap,
    this.filled = false,
  });
}

class TeacherFlowSectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const TeacherFlowSectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.dmSans(
              color: teacherFlowInk,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    );
  }
}

class TeacherTimelineItem extends StatelessWidget {
  final String time;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const TeacherTimelineItem({
    super.key,
    required this.time,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.color = teacherFlowAccent,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TeacherFlowCard(
      icon: icon,
      title: title,
      subtitle: subtitle,
      status: time,
      statusColor: color,
      onTap: onTap,
    );
  }
}

class TeacherFlowLoading extends StatelessWidget {
  const TeacherFlowLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class TeacherFlowError extends StatelessWidget {
  final String message;
  final Future<void> Function()? onRetry;

  const TeacherFlowError({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 40,
              color: AppTheme.error,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                color: teacherFlowInk,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: () => onRetry!(),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String teacherFlowText(Object? value, {String fallback = ''}) {
  final text = '${value ?? ''}'.trim();
  if (text.isEmpty || text == 'null') return fallback;
  return text;
}

int teacherFlowInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('${value ?? ''}') ?? 0;
}

String teacherFlowDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

String teacherFlowDateOnly(Object? value) {
  final text = teacherFlowText(value);
  if (text.isEmpty) return '';
  return text.split('T').first;
}

String teacherFlowTitleCase(String value) {
  return value
      .split(RegExp(r'[\s_]+'))
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}

Map<String, dynamic> teacherFlowMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const <String, dynamic>{};
}

List<Map<String, dynamic>> teacherFlowList(Object? value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((row) => Map<String, dynamic>.from(row))
      .toList();
}

String teacherFlowGreeting() {
  final hour = DateTime.now().hour;
  if (hour < 12) return 'Good Morning';
  if (hour < 17) return 'Good Afternoon';
  return 'Good Evening';
}

String teacherCurrentClassLabel() {
  final label = RoleAccessService.teacherClassName;
  return label.trim().isEmpty ? 'No class assigned' : label;
}
