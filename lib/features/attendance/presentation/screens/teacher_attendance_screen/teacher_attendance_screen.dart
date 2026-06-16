import 'package:flutter/material.dart';

import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/services/role_access_service.dart';

import 'package:schooldesk1/core/widgets/teacher_flow_ui.dart';
import 'package:schooldesk1/core/utils/extensions.dart';
import 'package:schooldesk1/routes/app_routes.dart';

class TeacherAttendanceScreen extends StatefulWidget {
  const TeacherAttendanceScreen({super.key});

  @override
  State<TeacherAttendanceScreen> createState() =>
      _TeacherAttendanceScreenState();
}

class _TeacherAttendanceScreenState extends State<TeacherAttendanceScreen> {
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String _classLabel = 'Assigned class';
  String _subjectLabel = 'Subject';
  String _timeLabel = 'First period';
  AttendanceSessionModel? _session;
  List<_AttendanceStudent> _students = [];
  DateTime _selectedDate = DateTime.now();
  String _selectedSlotId = '';
  List<Map<String, dynamic>> _slots = const [];

  @override
  void initState() {
    super.initState();
    _loadFlow();
  }

  Future<void> _loadFlow() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await RoleAccessService.initialize();
      final api = BackendApiClient.instance;
      final staffId = RoleAccessService.teacherStaffId;
      if (staffId.isEmpty) {
        throw Exception('Teacher staff profile is not linked to this login.');
      }
      final sectionId = RoleAccessService.teacherClassId;
      if (sectionId.isEmpty) {
        throw Exception(
          'You are not assigned as a class teacher to any section.\n'
          'Please contact Admin/Principal to set your class teacher assignment.',
        );
      }

      // Load timetable slots for the teacher's section on the selected day.
      // This is optional — attendance can be taken even without a timetable slot.
      List<Map<String, dynamic>> slots = [];
      try {
        slots = await api.getTimetableSlots(
          sectionId: sectionId,
          dayOfWeek: _selectedDate.weekday,
        );
      } catch (_) {
        slots = [];
      }
      _slots = slots;

      // Pick the best matching slot for this section (or empty if none).
      final slot = _pickAttendanceSlot(slots);
      final subjectId = teacherFlowText(slot['subject_id']);
      final academicYearId = teacherFlowText(slot['academic_year_id']);
      final slotId = teacherFlowText(slot['id'] ?? slot['slot_id']);
      // Default to period 1 if no slot is available.
      final periodNumber = slot.isNotEmpty
          ? teacherFlowInt(slot['period_number'])
          : 1;
      final effectivePeriodNumber = periodNumber < 1 ? 1 : periodNumber;

      // Load students for the class-teacher's section.
      final studentsPage = await api.getStudents(
        sectionId: sectionId,
        page: 1,
        pageSize: 120,
      );
      final students = <_AttendanceStudent>[];
      for (final s in studentsPage.data) {
        final enrollments = await api.getStudentEnrollments(s.id);
        final enrollmentId = _activeEnrollmentId(enrollments);
        students.add(
          _AttendanceStudent(
            id: s.id,
            name: s.fullName,
            roll: s.admissionNumber.isNotEmpty
                ? s.admissionNumber
                : s.studentCode,
            enrollmentId: enrollmentId,
            enrollmentMissing: enrollmentId.isEmpty,
          ),
        );
      }

      final date = teacherFlowDate(_selectedDate);
      final sessions = await api.getAttendanceSessions(
        sectionId: sectionId,
        date: date,
      );

      // Match an existing session by slot id or period number.
      final matching = sessions.where(
        (session) =>
            (slotId.isNotEmpty && session.timetableSlotId == slotId) ||
            session.periodNumber == effectivePeriodNumber,
      );

      // Use existing session or create a new one.
      // If no timetable slot provides academic year / subject, fetch them.
      String effectiveAcademicYearId = academicYearId;
      if (effectiveAcademicYearId.isEmpty) {
        try {
          final years = await api.getAcademicYears();
          final active = years.where((y) => y.isCurrent);
          if (active.isNotEmpty) {
            effectiveAcademicYearId = active.first.id;
          } else if (years.isNotEmpty) {
            effectiveAcademicYearId = years.first.id;
          }
        } catch (_) {
          // If we can't get academic year, proceed with empty — backend may still accept.
        }
      }

      final session = matching.isNotEmpty
          ? matching.first
          : await api.createAttendanceSession(
              sectionId: sectionId,
              subjectId: subjectId,
              academicYearId: effectiveAcademicYearId,
              staffId: staffId,
              date: date,
              timetableSlotId: slotId.isNotEmpty ? slotId : null,
              periodNumber: effectivePeriodNumber,
            );

      if (!mounted) return;
      setState(() {
        _classLabel = _classLabelForSection(sectionId);
        _subjectLabel = slot.isNotEmpty
            ? _subjectLabelFromSlot(slot)
            : 'Class Attendance';
        _timeLabel = slot.isNotEmpty
            ? _timeLabelFromSlot(slot)
            : 'Period $effectivePeriodNumber';
        _session = session;
        _students = students;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _submit() async {
    if (_session == null) return;
    if (_session!.isFinalized) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Attendance is locked until the principal reopens it.',
          ),
          backgroundColor: context.appTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final missing = _students.where((student) => student.enrollmentMissing);
    if (missing.isNotEmpty) {
      throw Exception('Enrollment record missing for ${missing.first.name}');
    }
    setState(() => _saving = true);
    try {
      final sessionId = _session!.id;
      final attendances = _students.map((student) {
        final enrollmentId = student.enrollmentId;
        return {
          'student_id': student.id,
          'enrollment_id': enrollmentId,
          'status': student.status,
          'remarks': '',
          'enrollment_missing': enrollmentId.isEmpty,
        };
      }).toList();
      await BackendApiClient.instance.markAttendance(sessionId, attendances);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Attendance shared'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _offerDiaryAfterPeriod();
      setState(() => _saving = false);
      await _loadFlow();
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to submit attendance: $error'),
          backgroundColor: context.appTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _offerDiaryAfterPeriod() async {
    final session = _session;
    if (session == null || !mounted) return;
    final record = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Record period ${session.periodNumber} diary?'),
        content: const Text(
          'Add what was taught, next class plan, and practice work before moving on.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Later'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.menu_book_rounded),
            label: const Text('Open Diary'),
          ),
        ],
      ),
    );
    if (record != true || !mounted) return;
    await Navigator.pushNamed(
      context,
      AppRoutes.teacherDiary,
      arguments: {
        'period_number': session.periodNumber,
        'subject': _subjectLabel,
      },
    );
  }

  void _markAll(String status) {
    if (_session?.isFinalized ?? false) return;
    setState(() {
      _students = _students
          .map((student) => student.copyWith(status: status))
          .toList();
    });
  }

  void _markOne(_AttendanceStudent student, String status) {
    if (_session?.isFinalized ?? false) return;
    setState(() {
      _students = _students
          .map(
            (row) => row.id == student.id ? row.copyWith(status: status) : row,
          )
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final locked = _session?.isFinalized ?? false;
    return TeacherFlowScaffold(
      title: 'Student Attendance',
      subtitle: 'Class teacher attendance',
      selectedIndex: 2,
      loading: _loading,
      error: _error,
      onRefresh: _loadFlow,
      child: TeacherFlowScrollView(
        children: [
          TeacherCurrentClassCard(
            greeting: 'Attendance window',
            classLabel: _classLabel,
            subject: _subjectLabel,
            timeLabel: _timeLabel,
            actions: [
              TeacherFlowAction(
                label: 'History',
                icon: Icons.history_rounded,
                onTap: () => Navigator.pushNamed(
                  context,
                  AppRoutes.teacherAttendanceHistory,
                ),
              ),
              TeacherFlowAction(
                label: 'All Present',
                icon: Icons.done_all_rounded,
                filled: true,
                onTap: locked ? null : () => _markAll('present'),
              ),
              TeacherFlowAction(
                label: 'Refresh',
                icon: Icons.refresh_rounded,
                onTap: _loadFlow,
              ),
            ],
          ),
          const SizedBox(height: 18),
          _selectionPanel(),
          const SizedBox(height: 18),
          TeacherFlowMetricGrid(
            metrics: [
              TeacherFlowMetric(
                label: 'Students',
                value: '${_students.length}',
                icon: Icons.groups_rounded,
                color: teacherFlowAccent,
                tone: const Color(0xFFE3FAF5),
              ),
              TeacherFlowMetric(
                label: 'Present',
                value:
                    '${_students.where((s) => s.status == 'present').length}',
                icon: Icons.check_circle_rounded,
                color: Colors.green,
                tone: const Color(0xFFEAFBF0),
              ),
              TeacherFlowMetric(
                label: 'Absent',
                value: '${_students.where((s) => s.status == 'absent').length}',
                icon: Icons.cancel_rounded,
                color: context.appTheme.error,
                tone: const Color(0xFFFFEEEE),
              ),
              TeacherFlowMetric(
                label: 'Late',
                value: '${_students.where((s) => s.status == 'late').length}',
                icon: Icons.schedule_rounded,
                color: Colors.orange,
                tone: const Color(0xFFFFF4E5),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (locked) ...[
            TeacherFlowCard(
              icon: Icons.lock_rounded,
              title: 'Attendance locked',
              subtitle:
                  'This session has been submitted. The principal must reopen it before edits are allowed.',
              status: 'Submitted',
              statusColor: Colors.green,
            ),
            const SizedBox(height: 12),
          ],
          TeacherFlowSectionHeader(title: 'Swipe-free Quick Marking'),
          const SizedBox(height: 10),
          ..._students.map(
            (student) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TeacherFlowCard(
                icon: Icons.person_rounded,
                title: student.name,
                subtitle: student.roll.isEmpty
                    ? 'Roll not assigned'
                    : student.roll,
                status: teacherFlowTitleCase(student.status),
                statusColor: student.statusColor,
                body: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      _buildAttendanceButton(
                        student: student,
                        status: 'present',
                        label: 'Present',
                        color: Colors.green,
                        isFirst: true,
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: Colors.grey.shade300,
                      ),
                      _buildAttendanceButton(
                        student: student,
                        status: 'absent',
                        label: 'Absent',
                        color: Colors.red,
                        isFirst: false,
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: Colors.grey.shade300,
                      ),
                      _buildAttendanceButton(
                        student: student,
                        status: 'late',
                        label: 'Late',
                        color: Colors.orange,
                        isFirst: false,
                        isLast: true,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_students.any((s) => s.enrollmentMissing))
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TeacherInfoPill(
                icon: Icons.warning_amber_rounded,
                label: 'Some students are missing enrollments',
              ),
            ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: _saving || _students.isEmpty || locked ? null : _submit,
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_done_rounded),
            label: Text(_saving ? 'Submitting...' : 'Submit Attendance'),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceButton({
    required _AttendanceStudent student,
    required String status,
    required String label,
    required Color color,
    bool isFirst = false,
    bool isLast = false,
  }) {
    final isSelected = student.status == status;
    return Expanded(
      child: GestureDetector(
        onTap: () => _markOne(student, status),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.horizontal(
              left: isFirst ? const Radius.circular(12) : Radius.zero,
              right: isLast ? const Radius.circular(12) : Radius.zero,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isSelected) ...[
                Icon(Icons.check_circle_rounded, color: color, size: 16),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? color : Colors.grey.shade600,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Map<String, dynamic> _pickAttendanceSlot(List<Map<String, dynamic>> slots) {
    if (slots.isEmpty) return const {};
    if (_selectedSlotId.isNotEmpty) {
      final selected = slots.where(
        (slot) =>
            teacherFlowText(slot['id'] ?? slot['slot_id']) == _selectedSlotId &&
            teacherFlowText(slot['section_id']) ==
                RoleAccessService.teacherClassId,
      );
      if (selected.isNotEmpty) return selected.first;
    }
    final ownClassSlots = slots
        .where(
          (slot) =>
              teacherFlowText(slot['section_id']) ==
              RoleAccessService.teacherClassId,
        )
        .toList();
    if (ownClassSlots.isNotEmpty) {
      final firstPeriod = ownClassSlots.where(
        (slot) => teacherFlowInt(slot['period_number']) == 1,
      );
      return firstPeriod.isNotEmpty ? firstPeriod.first : ownClassSlots.first;
    }
    final firstPeriod = slots.where(
      (slot) => teacherFlowInt(slot['period_number']) == 1,
    );
    return firstPeriod.isNotEmpty ? firstPeriod.first : slots.first;
  }

  String _activeEnrollmentId(List<Map<String, dynamic>> enrollments) {
    if (enrollments.isEmpty) return '';
    final active = enrollments.where(
      (row) => teacherFlowText(row['status']).toLowerCase() == 'active',
    );
    final row = active.isNotEmpty ? active.first : enrollments.first;
    return teacherFlowText(row['id'] ?? row['enrollment_id']);
  }

  String _subjectLabelFromSlot(Map<String, dynamic> slot) {
    final subject = teacherFlowMap(slot['subject']);
    final label = teacherFlowText(
      subject['subject_name'] ?? slot['subject_name'] ?? slot['subject_id'],
    );
    return label.isEmpty ? RoleAccessService.teacherSubject : label;
  }

  String _timeLabelFromSlot(Map<String, dynamic> slot) {
    final start = teacherFlowText(slot['start_time']);
    final end = teacherFlowText(slot['end_time']);
    if (start.isEmpty && end.isEmpty) {
      return 'Period ${teacherFlowInt(slot['period_number'])}';
    }
    return [start, end].where((part) => part.isNotEmpty).join(' - ');
  }

  Widget _selectionPanel() {
    final selectedSection = RoleAccessService.teacherClassId;
    final sectionSlots = _slots
        .where((slot) => teacherFlowText(slot['section_id']) == selectedSection)
        .toList();
    return TeacherFlowCard(
      icon: Icons.tune_rounded,
      title: 'Attendance selection',
      subtitle:
          '${teacherFlowDate(_selectedDate)} · ${sectionSlots.length} period${sectionSlots.length == 1 ? '' : 's'}',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TeacherFlowActionWrap(
            actions: [
              TeacherFlowAction(
                label: 'Date',
                icon: Icons.calendar_today_rounded,
                onTap: _pickDate,
              ),
            ],
          ),
          if (sectionSlots.length > 1) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: sectionSlots.map((slot) {
                final id = teacherFlowText(slot['id'] ?? slot['slot_id']);
                return ChoiceChip(
                  label: Text(_timeLabelFromSlot(slot)),
                  selected: _selectedSlotId == id,
                  onSelected: (_) {
                    setState(() => _selectedSlotId = id);
                    _loadFlow();
                  },
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked == null) return;
    setState(() {
      _selectedDate = picked;
      _selectedSlotId = '';
    });
    await _loadFlow();
  }

  String _classLabelForSection(String sectionId) {
    final match = RoleAccessService.assignedTeacherClasses.where(
      (row) => teacherFlowText(row['id'] ?? row['section_id']) == sectionId,
    );
    if (match.isNotEmpty) return teacherFlowText(match.first['label']);
    return RoleAccessService.teacherClassName;
  }
}

class _AttendanceStudent {
  final String id;
  final String name;
  final String roll;
  final String enrollmentId;
  final bool enrollmentMissing;
  final String status;

  const _AttendanceStudent({
    required this.id,
    required this.name,
    required this.roll,
    required this.enrollmentId,
    required this.enrollmentMissing,
    this.status = 'present',
  });

  Color get statusColor {
    return switch (status) {
      'present' => Colors.green,
      'absent' => Colors.red,
      'late' => Colors.orange,
      _ => teacherFlowAccent,
    };
  }

  _AttendanceStudent copyWith({String? status}) {
    return _AttendanceStudent(
      id: id,
      name: name,
      roll: roll,
      enrollmentId: enrollmentId,
      enrollmentMissing: enrollmentMissing,
      status: status ?? this.status,
    );
  }
}
