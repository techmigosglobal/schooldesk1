import 'package:flutter/material.dart';

import 'package:schooldesk1/core/navigation/role_nav_indices.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/services/role_access_service.dart';
import 'package:schooldesk1/core/widgets/teacher_flow_ui.dart';

class TeacherTimetableScreen extends StatefulWidget {
  const TeacherTimetableScreen({super.key});

  @override
  State<TeacherTimetableScreen> createState() => _TeacherTimetableScreenState();
}

class _TeacherTimetableScreenState extends State<TeacherTimetableScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _slots = const [];
  bool _usingAssignedClassFallback = false;

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
      final slots = await _loadTeacherTimetableSlots();
      if (!mounted) return;
      setState(() {
        _slots = slots.rows;
        _usingAssignedClassFallback = slots.usedClassFallback;
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

  Future<_TeacherTimetableLoadResult> _loadTeacherTimetableSlots() async {
    final staffScopedSlots = await BackendApiClient.instance.getTimetableSlots(
      staffId: RoleAccessService.teacherStaffId,
    );
    final assignedSectionIds = RoleAccessService.teacherSectionIds;
    if (staffScopedSlots.isNotEmpty || assignedSectionIds.isEmpty) {
      return _TeacherTimetableLoadResult(
        rows: staffScopedSlots,
        usedClassFallback: false,
      );
    }

    final classScopedSlots = <Map<String, dynamic>>[];
    for (final sectionId in assignedSectionIds) {
      classScopedSlots.addAll(
        await BackendApiClient.instance.getTimetableSlots(sectionId: sectionId),
      );
    }
    return _TeacherTimetableLoadResult(
      rows: classScopedSlots,
      usedClassFallback: classScopedSlots.isNotEmpty,
    );
  }

  Map<int, List<Map<String, dynamic>>> get _slotsByDay {
    final grouped = <int, List<Map<String, dynamic>>>{};
    for (final slot in _slots) {
      final day = teacherFlowInt(slot['day_of_week']);
      if (day < 1 || day > 7) continue;
      grouped.putIfAbsent(day, () => <Map<String, dynamic>>[]).add(slot);
    }
    for (final rows in grouped.values) {
      rows.sort(
        (a, b) => teacherFlowInt(
          a['period_number'],
        ).compareTo(teacherFlowInt(b['period_number'])),
      );
    }
    return grouped;
  }

  List<String> get _weeklySubjects {
    return _slots
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
    if (_slots.isNotEmpty) {
      final section = teacherFlowMap(_slots.first['section']);
      final grade = teacherFlowText(section['grade_name']);
      final sec = teacherFlowText(section['section_name']);
      if (grade.isNotEmpty) return sec.isEmpty ? grade : '$grade - $sec';
    }
    return RoleAccessService.teacherClassName;
  }

  @override
  Widget build(BuildContext context) {
    final slotsByDay = _slotsByDay;
    final subjects = _weeklySubjects;
    final classLabel = _assignedClass;

    return TeacherFlowScaffold(
      title: 'Weekly Timetable',
      subtitle: _usingAssignedClassFallback ? 'Timetable source: assigned class' : 'Read-only schedule from Principal timetable setup',
      selectedIndex: TeacherNav.timetable,
      loading: _loading,
      error: _error,
      onRefresh: _load,
      child: TeacherFlowScrollView(
        children: [
          if (!RoleAccessService.hasAssignedClasses)
            const TeacherFlowCard(
              icon: Icons.class_outlined,
              title: 'No class assigned yet.',
              subtitle:
                  'Your assignment will appear after Principal assigns you.',
            )
          else ...[
            // ── Card 1: Today's Full-Day Assigned Class ──────────────────
            _FullDayClassCard(
              classLabel: classLabel,
              subjects: subjects,
              date: _weekLabel(),
              mappedSubjects: RoleAccessService.teacherSubjectIds.length,
            ),
            const SizedBox(height: 16),

            TeacherFlowSectionHeader(title: 'Weekly Timetable'),
            const SizedBox(height: 8),
            if (_slots.isEmpty)
              const TeacherFlowCard(
                icon: Icons.calendar_month_outlined,
                title: 'No timetable published yet.',
                subtitle:
                    'Ask Principal to assign subjects, staff, and timetable slots for your staff profile.',
              )
            else
              ...List.generate(6, (index) => index + 1).map(
                (day) => _DayScheduleCard(
                  dayName: _dayName(day),
                  slots: slotsByDay[day] ?? const [],
                  slotSubject: _slotSubject,
                  slotTime: _slotTime,
                ),
              ),
          ],
        ],
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
    if (start.isEmpty && end.isEmpty) {
      return 'Period ${teacherFlowInt(slot['period_number'])}';
    }
    return [start, end].where((p) => p.isNotEmpty).join(' – ');
  }

  String _weekLabel() {
    final now = DateTime.now();
    return 'Week of ${now.day}/${now.month}/${now.year}';
  }

  String _dayName(int day) {
    const days = [
      '',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return day >= 1 && day < days.length ? days[day] : 'Day $day';
  }
}

// ── Full-Day Class Card ──────────────────────────────────────────────────────

class _FullDayClassCard extends StatelessWidget {
  final String classLabel;
  final List<String> subjects;
  final String date;
  final int mappedSubjects;

  const _FullDayClassCard({
    required this.classLabel,
    required this.subjects,
    required this.date,
    required this.mappedSubjects,
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
                child: const Icon(
                  Icons.class_rounded,
                  color: teacherFlowAccent,
                  size: 26,
                ),
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
              const Icon(
                Icons.calendar_today_outlined,
                size: 15,
                color: teacherFlowAccent,
              ),
              const SizedBox(width: 6),
              Text(
                '$date · $mappedSubjects mapped subjects',
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
                      label: Text(
                        s,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      backgroundColor: teacherFlowAccent.withValues(
                        alpha: 0.12,
                      ),
                      side: BorderSide(
                        color: teacherFlowAccent.withValues(alpha: 0.25),
                      ),
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

class _TeacherTimetableLoadResult {
  final List<Map<String, dynamic>> rows;
  final bool usedClassFallback;

  const _TeacherTimetableLoadResult({
    required this.rows,
    required this.usedClassFallback,
  });
}

class _DayScheduleCard extends StatelessWidget {
  final String dayName;
  final List<Map<String, dynamic>> slots;
  final String Function(Map<String, dynamic>) slotSubject;
  final String Function(Map<String, dynamic>) slotTime;

  const _DayScheduleCard({
    required this.dayName,
    required this.slots,
    required this.slotSubject,
    required this.slotTime,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TeacherFlowCard(
        icon: Icons.calendar_view_week_rounded,
        title: dayName,
        subtitle: slots.isEmpty
            ? 'No periods assigned'
            : '${slots.length} period${slots.length == 1 ? '' : 's'} assigned',
        body: slots.isEmpty
            ? null
            : Column(
                children: slots
                    .map(
                      (slot) => Material(
                        color: Colors.transparent,
                        child: ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            radius: 16,
                            backgroundColor: teacherFlowAccent.withValues(
                              alpha: 0.12,
                            ),
                            child: Text(
                              '${teacherFlowInt(slot['period_number'])}',
                              style: const TextStyle(
                                color: teacherFlowAccent,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          title: Text(slotSubject(slot)),
                          subtitle: Text(slotTime(slot)),
                        ),
                      ),
                    )
                    .toList(),
              ),
      ),
    );
  }
}
