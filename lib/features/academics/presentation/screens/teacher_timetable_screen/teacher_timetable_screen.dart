import 'package:flutter/material.dart';

import 'package:schooldesk1/core/navigation/role_nav_indices.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/services/role_access_service.dart';
import 'package:schooldesk1/core/widgets/teacher_flow_ui.dart';

import 'teacher_timetable_day_selection.dart';

class TeacherTimetableScreen extends StatefulWidget {
  const TeacherTimetableScreen({super.key});

  @override
  State<TeacherTimetableScreen> createState() => _TeacherTimetableScreenState();
}

class _TeacherTimetableScreenState extends State<TeacherTimetableScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _slots = const [];
  String _selectedSectionId = '';
  List<int> _workingDays = defaultTeacherWorkingDays;
  int? _selectedDay;

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
      final workingDays = await _loadWorkingDays();
      final slots = await _loadTeacherTimetableSlots();
      if (!mounted) return;
      final sectionIds = _sectionIdsFor(slots);
      final normalizedWorkingDays = normalizeTeacherWorkingDays(workingDays);
      final selectedDay =
          _selectedDay != null && normalizedWorkingDays.contains(_selectedDay)
          ? _selectedDay!
          : selectInitialTeacherTimetableDay(
              workingDays: normalizedWorkingDays,
            );
      setState(() {
        _slots = slots;
        _workingDays = normalizedWorkingDays;
        _selectedDay = selectedDay;
        _selectedSectionId = sectionIds.contains(_selectedSectionId)
            ? _selectedSectionId
            : (sectionIds.isEmpty ? '' : sectionIds.first);
        _loading = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<List<int>> _loadWorkingDays() async {
    try {
      return await BackendApiClient.instance.getTimetableWorkingDays();
    } on Object {
      return const [];
    }
  }

  Future<List<Map<String, dynamic>>> _loadTeacherTimetableSlots() async {
    final assignedSectionIds = RoleAccessService.teacherSectionIds;
    final classScopedSlots = <Map<String, dynamic>>[];
    for (final sectionId in assignedSectionIds) {
      classScopedSlots.addAll(
        await BackendApiClient.instance.getTimetableSlots(sectionId: sectionId),
      );
    }
    return classScopedSlots;
  }

  List<String> _sectionIdsFor(List<Map<String, dynamic>> slots) {
    final ids = <String>{...RoleAccessService.teacherSectionIds};
    for (final slot in slots) {
      final id = teacherFlowText(slot['section_id']);
      if (id.isNotEmpty) ids.add(id);
    }
    return ids.toList();
  }

  List<Map<String, dynamic>> get _visibleSlots {
    if (_selectedSectionId.isEmpty) return _slots;
    return _slots
        .where(
          (slot) => teacherFlowText(slot['section_id']) == _selectedSectionId,
        )
        .toList();
  }

  Map<int, List<Map<String, dynamic>>> get _slotsByDay {
    final grouped = <int, List<Map<String, dynamic>>>{};
    for (final slot in _visibleSlots) {
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

  List<Map<String, dynamic>> get _selectedDaySlots {
    final selectedDay = _selectedDay;
    if (selectedDay == null) return const [];
    return _slotsByDay[selectedDay] ?? const [];
  }

  List<String> get _weeklySubjects {
    return _visibleSlots
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
    if (_visibleSlots.isNotEmpty) {
      final section = teacherFlowMap(_visibleSlots.first['section']);
      final grade = teacherFlowText(section['grade_name']);
      final sec = teacherFlowText(section['section_name']);
      if (grade.isNotEmpty) return sec.isEmpty ? grade : '$grade - $sec';
    }
    final selected = _selectedSectionId;
    if (selected.isNotEmpty) return selected;
    return RoleAccessService.teacherClassName;
  }

  @override
  Widget build(BuildContext context) {
    final subjects = _weeklySubjects;
    final classLabel = _assignedClass;
    final sectionIds = _sectionIdsFor(_slots);
    final selectedDay =
        _selectedDay ??
        selectInitialTeacherTimetableDay(workingDays: _workingDays);

    return TeacherFlowScaffold(
      title: 'Weekly Timetable',
      subtitle: 'Read-only schedule from Principal timetable setup',
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
            if (sectionIds.length > 1) ...[
              const TeacherFlowSectionHeader(title: 'Select class'),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: sectionIds.contains(_selectedSectionId)
                    ? _selectedSectionId
                    : sectionIds.first,
                decoration: const InputDecoration(
                  labelText: 'Class / section',
                  border: OutlineInputBorder(),
                ),
                items: sectionIds
                    .map(
                      (sectionId) => DropdownMenuItem<String>(
                        value: sectionId,
                        child: Text(_sectionLabel(sectionId)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _selectedSectionId = value);
                },
              ),
              const SizedBox(height: 16),
            ],
            // ── Card 1: Assigned Class Overview ───────────────────────────
            _FullDayClassCard(
              classLabel: classLabel,
              subjects: subjects,
              date: _weekLabel(),
              mappedSubjects: RoleAccessService.teacherSubjectIds.length,
            ),
            const SizedBox(height: 16),

            const TeacherFlowSectionHeader(title: 'Select weekday'),
            const SizedBox(height: 8),
            _TeacherWeekdaySelector(
              days: _workingDays,
              selectedDay: selectedDay,
              onSelected: (day) => setState(() => _selectedDay = day),
            ),
            const SizedBox(height: 16),
            _DayScheduleCard(
              key: const ValueKey('teacher-timetable-selected-day'),
              dayName: _dayName(selectedDay),
              slots: _selectedDaySlots,
              slotSubject: _slotSubject,
              slotTime: _slotTime,
            ),
          ],
        ],
      ),
    );
  }

  String _sectionLabel(String sectionId) {
    for (final slot in _slots) {
      if (teacherFlowText(slot['section_id']) != sectionId) continue;
      final section = teacherFlowMap(slot['section']);
      final grade = teacherFlowText(section['grade_name']);
      final name = teacherFlowText(section['section_name']);
      if (grade.isNotEmpty) return name.isEmpty ? grade : '$grade - $name';
    }
    final assignedSectionIds = RoleAccessService.teacherSectionIds;
    if (assignedSectionIds.isNotEmpty &&
        sectionId == assignedSectionIds.first) {
      return RoleAccessService.teacherClassName;
    }
    return sectionId;
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
                      'Assigned Class Overview',
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

class _DayScheduleCard extends StatelessWidget {
  final String dayName;
  final List<Map<String, dynamic>> slots;
  final String Function(Map<String, dynamic>) slotSubject;
  final String Function(Map<String, dynamic>) slotTime;

  const _DayScheduleCard({
    super.key,
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
        subtitle:
            '${slots.length} period${slots.length == 1 ? '' : 's'} assigned',
        body: slots.isEmpty
            ? Text(
                'No classes scheduled for $dayName.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: teacherFlowMuted,
                  fontWeight: FontWeight.w600,
                ),
              )
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

class _TeacherWeekdaySelector extends StatelessWidget {
  final List<int> days;
  final int selectedDay;
  final ValueChanged<int> onSelected;

  const _TeacherWeekdaySelector({
    required this.days,
    required this.selectedDay,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        key: const ValueKey('teacher-timetable-weekday-selector'),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(right: 8),
        itemCount: days.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final day = days[index];
          final selected = day == selectedDay;
          final dayName = _dayName(day);
          return Semantics(
            button: true,
            selected: selected,
            label: dayName,
            hint: 'Show $dayName timetable',
            child: ChoiceChip(
              key: ValueKey('teacher-timetable-day-$day'),
              label: Text(_shortDayName(day)),
              selected: selected,
              onSelected: (_) => onSelected(day),
              showCheckmark: false,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              labelStyle: TextStyle(
                color: selected ? Colors.white : teacherFlowInk,
                fontWeight: FontWeight.w800,
              ),
              selectedColor: teacherFlowAccent,
              backgroundColor: teacherFlowAccent.withValues(alpha: 0.08),
              side: BorderSide(
                color: selected
                    ? teacherFlowAccent
                    : teacherFlowAccent.withValues(alpha: 0.20),
              ),
            ),
          );
        },
      ),
    );
  }

  static String _dayName(int day) {
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

  static String _shortDayName(int day) {
    const days = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return day >= 1 && day < days.length ? days[day] : 'Day $day';
  }
}
