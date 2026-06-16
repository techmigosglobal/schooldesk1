import 'package:flutter/material.dart';

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
  bool _todayOnly = true;
  String _sectionFilter = '';
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

  @override
  Widget build(BuildContext context) {
    final classes = RoleAccessService.assignedTeacherClasses;
    final visible = _visibleSlots;
    return TeacherFlowScaffold(
      title: 'Teacher Timetable',
      subtitle: 'Periods assigned to you',
      selectedIndex: 1,
      loading: _loading,
      error: _error,
      onRefresh: _load,
      child: TeacherFlowScrollView(
        children: [
          TeacherFlowSectionHeader(
            title: 'Schedule',
            actionLabel: _todayOnly ? 'Week' : 'Today',
            onAction: () => setState(() => _todayOnly = !_todayOnly),
          ),
          const SizedBox(height: 10),
          if (classes.length > 1) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('All classes'),
                  selected: _sectionFilter.isEmpty,
                  onSelected: (_) => setState(() => _sectionFilter = ''),
                ),
                ...classes.map((row) {
                  final id = teacherFlowText(row['id'] ?? row['section_id']);
                  return ChoiceChip(
                    label: Text(teacherFlowText(row['label'])),
                    selected: _sectionFilter == id,
                    onSelected: (_) => setState(() => _sectionFilter = id),
                  );
                }),
              ],
            ),
            const SizedBox(height: 14),
          ],
          if (!RoleAccessService.hasAssignedClasses)
            const TeacherFlowCard(
              icon: Icons.class_outlined,
              title: 'No classes assigned yet.',
              subtitle:
                  'Your timetable will appear after Admin/Principal assigns sections.',
            )
          else if (visible.isEmpty)
            const TeacherFlowCard(
              icon: Icons.calendar_month_outlined,
              title: 'No timetable assigned yet.',
              subtitle: 'No periods match the selected timetable filter.',
            )
          else
            ..._groupedByDay(visible).entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TeacherFlowSectionHeader(title: _dayName(entry.key)),
                    const SizedBox(height: 8),
                    ...entry.value.map(
                      (slot) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: TeacherFlowCard(
                          icon: Icons.schedule_rounded,
                          title: _slotClass(slot),
                          subtitle:
                              '${_slotTime(slot)} · ${_slotSubject(slot)}',
                          status: _slotRoom(slot).isEmpty
                              ? 'Period ${teacherFlowInt(slot['period_number'])}'
                              : _slotRoom(slot),
                          statusColor: teacherFlowAccent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> get _visibleSlots {
    final today = DateTime.now().weekday;
    final rows = _slots
        .where((slot) {
          if (_todayOnly && teacherFlowInt(slot['day_of_week']) != today) {
            return false;
          }
          if (_sectionFilter.isNotEmpty &&
              teacherFlowText(slot['section_id']) != _sectionFilter) {
            return false;
          }
          return true;
        })
        .map((slot) => Map<String, dynamic>.from(slot))
        .toList();
    rows.sort((a, b) {
      final day = teacherFlowInt(
        a['day_of_week'],
      ).compareTo(teacherFlowInt(b['day_of_week']));
      if (day != 0) return day;
      return teacherFlowInt(
        a['period_number'],
      ).compareTo(teacherFlowInt(b['period_number']));
    });
    return rows;
  }

  Map<int, List<Map<String, dynamic>>> _groupedByDay(
    List<Map<String, dynamic>> slots,
  ) {
    final grouped = <int, List<Map<String, dynamic>>>{};
    for (final slot in slots) {
      grouped.putIfAbsent(teacherFlowInt(slot['day_of_week']), () => []);
      grouped[teacherFlowInt(slot['day_of_week'])]!.add(slot);
    }
    return grouped;
  }

  String _slotClass(Map<String, dynamic> slot) {
    final section = teacherFlowMap(slot['section']);
    final grade = teacherFlowText(section['grade_name']);
    final sectionName = teacherFlowText(section['section_name']);
    final label = [
      grade,
      sectionName,
    ].where((part) => part.isNotEmpty).join(' ');
    if (label.isNotEmpty) return label;
    final match = RoleAccessService.assignedTeacherClasses.where(
      (row) =>
          teacherFlowText(row['id']) == teacherFlowText(slot['section_id']),
    );
    return match.isEmpty
        ? 'Assigned class'
        : teacherFlowText(match.first['label']);
  }

  String _slotSubject(Map<String, dynamic> slot) {
    final subject = teacherFlowMap(slot['subject']);
    return teacherFlowText(
      subject['subject_name'] ?? slot['subject_name'] ?? slot['subject_id'],
      fallback: 'Subject',
    );
  }

  String _slotTime(Map<String, dynamic> slot) {
    final start = teacherFlowText(slot['start_time']);
    final end = teacherFlowText(slot['end_time']);
    if (start.isEmpty && end.isEmpty) {
      return 'Period ${teacherFlowInt(slot['period_number'])}';
    }
    return [start, end].where((part) => part.isNotEmpty).join(' - ');
  }

  String _slotRoom(Map<String, dynamic> slot) {
    final room = slot['room'];
    if (room is Map) {
      return teacherFlowText(room['room_number']);
    }
    return teacherFlowText(room ?? slot['room_number']);
  }

  String _dayName(int weekday) {
    const names = {
      1: 'Monday',
      2: 'Tuesday',
      3: 'Wednesday',
      4: 'Thursday',
      5: 'Friday',
      6: 'Saturday',
      7: 'Sunday',
    };
    return names[weekday] ?? 'Unscheduled';
  }
}
