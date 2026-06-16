import 'package:flutter/material.dart';

import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/services/role_access_service.dart';
import 'package:schooldesk1/core/widgets/teacher_flow_ui.dart';
import 'package:schooldesk1/routes/app_routes.dart';

class TeacherTimetableScreen extends StatefulWidget {
  const TeacherTimetableScreen({super.key});

  @override
  State<TeacherTimetableScreen> createState() => _TeacherTimetableScreenState();
}

class _TeacherTimetableScreenState extends State<TeacherTimetableScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _slots = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await RoleAccessService.initialize();
      if (!RoleAccessService.hasTeacherStaffLink) {
        throw Exception(RoleAccessService.teacherScopeStatus);
      }
      final slots = await BackendApiClient.instance.getTimetableSlots(
        staffId: RoleAccessService.teacherStaffId,
      );
      if (!mounted) return;
      setState(() {
        _slots = slots;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  /// Slots for today only
  List<Map<String, dynamic>> get _todaySlots {
    final today = DateTime.now().weekday;
    return _slots
        .where((s) => teacherFlowInt(s['day_of_week']) == today)
        .toList()
      ..sort((a, b) => teacherFlowInt(a['period_number'])
          .compareTo(teacherFlowInt(b['period_number'])));
  }

  /// Unique subjects from today's slots
  List<String> get _todaySubjects {
    return _todaySlots
        .map((s) {
          final sub = teacherFlowMap(s['subject']);
          return teacherFlowText(
            sub['subject_name'] ?? s['subject_name'] ?? s['subject_id'],
            fallback: '',
          );
        })
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();
  }

  String get _assignedClass {
    if (_todaySlots.isNotEmpty) {
      final section = teacherFlowMap(_todaySlots.first['section']);
      final grade = teacherFlowText(section['grade_name']);
      final sec = teacherFlowText(section['section_name']);
      if (grade.isNotEmpty) return sec.isEmpty ? grade : '$grade - $sec';
    }
    return RoleAccessService.teacherClassName;
  }

  @override
  Widget build(BuildContext context) {
    final today = _todaySlots;
    final subjects = _todaySubjects;
    final classLabel = _assignedClass;

    return TeacherFlowScaffold(
      title: 'Timetable',
      subtitle: 'Full-day class assignment',
      selectedIndex: 1,
      loading: _loading,
      error: _error,
      onRefresh: _load,
      child: TeacherFlowScrollView(
        children: [
          if (!RoleAccessService.hasAssignedClasses)
            const TeacherFlowCard(
              icon: Icons.class_outlined,
              title: 'No class assigned yet.',
              subtitle: 'Your assignment will appear after Admin/Principal assigns you.',
            )
          else ...[
            // ── Card 1: Today's Full-Day Assigned Class ──────────────────
            _FullDayClassCard(
              classLabel: classLabel,
              subjects: subjects,
              date: _todayLabel(),
            ),
            const SizedBox(height: 16),

            // ── Card 2: Quick Actions ────────────────────────────────────
            _buildQuickActions(context),
            const SizedBox(height: 16),

            // ── Card 3: Today's Periods (read-only list) ─────────────────
            TeacherFlowSectionHeader(title: 'Today\'s Periods'),
            const SizedBox(height: 8),
            if (today.isEmpty)
              const TeacherFlowCard(
                icon: Icons.calendar_month_outlined,
                title: 'No periods for today.',
                subtitle: 'Your timetable is empty for today.',
              )
            else
              ...today.map(
                (slot) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: TeacherFlowCard(
                    icon: Icons.schedule_rounded,
                    title: _slotSubject(slot),
                    subtitle: _slotTime(slot),
                    status: 'Period ${teacherFlowInt(slot['period_number'])}',
                    statusColor: teacherFlowAccent,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Actions',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _ActionChip(
                  label: 'Attendance',
                  icon: Icons.how_to_reg_rounded,
                  onTap: () =>
                      Navigator.pushNamed(context, AppRoutes.teacherAttendance),
                ),
                _ActionChip(
                  label: 'Homework',
                  icon: Icons.menu_book_outlined,
                  onTap: () =>
                      Navigator.pushNamed(context, AppRoutes.teacherHomework),
                ),
                _ActionChip(
                  label: 'Lesson Planner',
                  icon: Icons.auto_stories_outlined,
                  onTap: () => Navigator.pushNamed(
                      context, AppRoutes.teacherLessonPlanner),
                ),
                _ActionChip(
                  label: 'Event Post',
                  icon: Icons.post_add_outlined,
                  onTap: () =>
                      Navigator.pushNamed(context, AppRoutes.teacherEventPosts),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _slotSubject(Map<String, dynamic> slot) {
    final sub = teacherFlowMap(slot['subject']);
    return teacherFlowText(
      sub['subject_name'] ?? slot['subject_name'] ?? slot['subject_id'],
      fallback: 'Subject',
    );
  }

  String _slotTime(Map<String, dynamic> slot) {
    final start = teacherFlowText(slot['start_time']);
    final end = teacherFlowText(slot['end_time']);
    if (start.isEmpty && end.isEmpty) return 'Period ${teacherFlowInt(slot['period_number'])}';
    return [start, end].where((p) => p.isNotEmpty).join(' – ');
  }

  String _todayLabel() {
    final days = ['', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final now = DateTime.now();
    final dayName = days[now.weekday];
    return '$dayName, ${now.day}/${now.month}/${now.year}';
  }
}

// ── Full-Day Class Card ──────────────────────────────────────────────────────

class _FullDayClassCard extends StatelessWidget {
  final String classLabel;
  final List<String> subjects;
  final String date;

  const _FullDayClassCard({
    required this.classLabel,
    required this.subjects,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: teacherFlowAccent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: teacherFlowAccent.withValues(alpha: 0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: teacherFlowAccent.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.class_rounded,
                    color: teacherFlowAccent, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Today\'s Assigned Class',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: teacherFlowAccent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      classLabel,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.calendar_today_outlined,
                  size: 15, color: teacherFlowAccent),
              const SizedBox(width: 6),
              Text(
                date,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          if (subjects.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'Class Subjects',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: subjects
                  .map(
                    (s) => Chip(
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: EdgeInsets.zero,
                      label: Text(s,
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          )),
                      backgroundColor:
                          teacherFlowAccent.withValues(alpha: 0.12),
                      side: BorderSide(
                          color: teacherFlowAccent.withValues(alpha: 0.25)),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Action Chip ───────────────────────────────────────────────────────────────

class _ActionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _ActionChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 18, color: teacherFlowAccent),
      label: Text(label),
      onPressed: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: teacherFlowAccent.withValues(alpha: 0.35)),
      ),
      backgroundColor: teacherFlowAccent.withValues(alpha: 0.08),
    );
  }
}
