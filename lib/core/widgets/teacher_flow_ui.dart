import 'dart:math';
import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:schooldesk1/routes/app_routes.dart';
import 'package:schooldesk1/core/services/role_access_service.dart';
import 'package:schooldesk1/core/config/env_config.dart';

import 'package:schooldesk1/core/theme/design_tokens.dart';
import 'package:schooldesk1/core/widgets/erp_module_scaffold.dart';
import 'package:schooldesk1/core/widgets/teacher_navigation.dart';
import 'package:schooldesk1/core/utils/extensions.dart';

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
    return TeacherFlowBackgroundDecorator(
      child: SchoolDeskModuleScaffold(
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
        showBackButton: false,
        bodyIsScrollable: false,
        body: AnimatedSwitcher(
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
    label: 'Classes',
    icon: Icons.class_outlined,
    activeIcon: Icons.class_rounded,
    route: AppRoutes.teacherClasses,
  ),
  SchoolDeskModuleBottomAction(
    label: 'Attendance',
    icon: Icons.how_to_reg_outlined,
    activeIcon: Icons.how_to_reg_rounded,
    route: AppRoutes.teacherAttendance,
  ),
  SchoolDeskModuleBottomAction(
    label: 'Profile',
    icon: Icons.account_circle_outlined,
    activeIcon: Icons.account_circle_rounded,
    route: AppRoutes.profileScreen,
    arguments: 'teacher',
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
  final String? subject;
  final String? timeLabel;
  final List<TeacherFlowAction> actions;
  final String? avatar;

  const TeacherCurrentClassCard({
    super.key,
    required this.greeting,
    required this.classLabel,
    this.subject,
    this.timeLabel,
    this.actions = const [],
    this.avatar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            teacherFlowInk.withOpacity(0.95),
            const Color(0xFF0F5A51),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.12), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A2E2A).withOpacity(0.25),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: Colors.white.withOpacity(0.12),
                backgroundImage: avatar != null && avatar!.isNotEmpty
                    ? NetworkImage(
                        avatar!.startsWith('http')
                            ? avatar!
                            : '${EnvConfig.apiOrigin}$avatar',
                      )
                    : null,
                child: avatar == null || avatar!.isEmpty
                    ? const Icon(
                        Icons.person_rounded,
                        color: Colors.white,
                        size: 24,
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      greeting,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                        color: Colors.white.withOpacity(0.85),
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      classLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Glowing active badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.15)),
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
                      'ACTIVE',
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
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 20),
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
          alignment: WrapAlignment.center,
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
              color: context.appTheme.surface.withAlpha(220),
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
    final card = Material(
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
                          Flexible(
                            child: TeacherStatusPill(
                              label: status!,
                              color: statusColor,
                            ),
                          ),
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
    return Semantics(
      button: onTap != null,
      label: title,
      enabled: onTap != null,
      child: card,
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
          Flexible(
            child: Text(
              label,
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
    final filledActions = actions.where((a) => a.filled).toList();
    final outlinedActions = actions.where((a) => !a.filled).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (filledActions.isNotEmpty) ...[
          for (var i = 0; i < filledActions.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            Semantics(
              button: true,
              label: filledActions[i].label,
              enabled: filledActions[i].onTap != null,
              child: SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: filledActions[i].onTap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF0F5A51),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: GoogleFonts.dmSans(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  icon: Icon(filledActions[i].icon, size: 18),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      filledActions[i].label,
                      maxLines: 1,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
        if (filledActions.isNotEmpty && outlinedActions.isNotEmpty)
          const SizedBox(height: 10),
        if (outlinedActions.isNotEmpty) ...[
          Row(
            children: [
              for (var i = 0; i < outlinedActions.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(
                  child: Semantics(
                    button: true,
                    label: outlinedActions[i].label,
                    enabled: outlinedActions[i].onTap != null,
                    child: SizedBox(
                      height: 44,
                      child: OutlinedButton.icon(
                        onPressed: outlinedActions[i].onTap,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.white.withOpacity(0.06),
                          side: BorderSide(
                            color: Colors.white.withOpacity(0.18),
                            width: 1.2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: GoogleFonts.dmSans(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        icon: Icon(outlinedActions[i].icon, size: 16),
                        label: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            outlinedActions[i].label,
                            maxLines: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
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
            Icon(
              Icons.cloud_off_rounded,
              size: 40,
              color: context.appTheme.error,
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

String teacherFlowTimeOnly(Object? value) {
  final text = teacherFlowText(value);
  if (text.isEmpty) return '';
  final parts = text.split('T');
  if (parts.length < 2) return '';
  final timeStr = parts[1].split('.').first; // remove milliseconds
  final timeParts = timeStr.split(':');
  if (timeParts.length >= 2) {
    return '${timeParts[0]}:${timeParts[1]}';
  }
  return timeStr;
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
  return 'Hello';
}

String teacherCurrentClassLabel() {
  final label = RoleAccessService.teacherClassName;
  return label.trim().isEmpty ? 'No class assigned' : label;
}

class TeacherFlowBackgroundDecorator extends StatefulWidget {
  final Widget child;
  const TeacherFlowBackgroundDecorator({super.key, required this.child});

  @override
  State<TeacherFlowBackgroundDecorator> createState() => _TeacherFlowBackgroundDecoratorState();
}

class _TeacherFlowBackgroundDecoratorState extends State<TeacherFlowBackgroundDecorator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Offset _mouseOffset = Offset.zero;
  Offset _smoothMouseOffset = Offset.zero;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onHover(PointerHoverEvent event) {
    setState(() {
      final size = MediaQuery.sizeOf(context);
      final centerX = size.width / 2;
      final centerY = size.height / 2;
      _mouseOffset = Offset(
        centerX > 0 ? (event.position.dx - centerX) / centerX : 0.0,
        centerY > 0 ? (event.position.dy - centerY) / centerY : 0.0,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    _smoothMouseOffset = Offset.lerp(_smoothMouseOffset, _mouseOffset, 0.05) ?? Offset.zero;

    return MouseRegion(
      onHover: _onHover,
      child: Stack(
        children: [
          // 1. Base Gradient
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFEFFBFA),
                    Color(0xFFF4FAFB),
                  ],
                ),
              ),
            ),
          ),
          // 2. Animated / Interactive Blobs
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final progress = _controller.value * 2 * pi;
                final size = MediaQuery.sizeOf(context);
                
                final blob1X = -50.0 + sin(progress) * 40.0 + (_smoothMouseOffset.dx * 24.0);
                final blob1Y = -50.0 + cos(progress) * 40.0 + (_smoothMouseOffset.dy * 24.0);

                final blob2X = size.width - 230.0 + cos(progress + pi) * 45.0 + (_smoothMouseOffset.dx * 20.0);
                final blob2Y = size.height - 230.0 + sin(progress + pi) * 45.0 + (_smoothMouseOffset.dy * 20.0);

                final blob3X = -80.0 + sin(progress * 1.5) * 35.0 + (_smoothMouseOffset.dx * 18.0);
                final blob3Y = size.height / 2 - 130.0 + cos(progress * 1.5) * 35.0 + (_smoothMouseOffset.dy * 18.0);

                return Stack(
                  children: [
                    Positioned(
                      left: blob1X,
                      top: blob1Y,
                      child: Container(
                        width: 320,
                        height: 320,
                        decoration: BoxDecoration(
                          color: teacherFlowAccent.withOpacity(0.08),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Positioned(
                      left: blob2X,
                      top: blob2Y,
                      child: Container(
                        width: 280,
                        height: 280,
                        decoration: BoxDecoration(
                          color: teacherFlowWarm.withOpacity(0.06),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Positioned(
                      left: blob3X,
                      top: blob3Y,
                      child: Container(
                        width: 260,
                        height: 260,
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6).withOpacity(0.05),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          // 3. Blur layer
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 70.0, sigmaY: 70.0),
              child: const SizedBox.expand(),
            ),
          ),
          // 4. Graph overlay
          Positioned.fill(
            child: CustomPaint(
              painter: _TeacherGridPainter(
                color: teacherFlowInk.withOpacity(0.012),
              ),
            ),
          ),
          // 5. Child content
          Positioned.fill(
            child: widget.child,
          ),
        ],
      ),
    );
  }
}

class _TeacherGridPainter extends CustomPainter {
  final Color color;
  const _TeacherGridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0;

    const step = 34.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _TeacherGridPainter oldDelegate) => false;
}
