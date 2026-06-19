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
  String _sectionId = '';
  String _staffId = '';
  String _subjectId = '';
  String _academicYearId = '';
  String _timetableSlotId = '';
  int _periodNumber = 1;

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

      // Use an existing session only. New sessions are created on Save Draft or Submit Final.
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

      final session = matching.isNotEmpty ? matching.first : null;

      if (!mounted) return;
      setState(() {
        _sectionId = sectionId;
        _staffId = staffId;
        _subjectId = subjectId;
        _academicYearId = effectiveAcademicYearId;
        _timetableSlotId = slotId;
        _periodNumber = effectivePeriodNumber;
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

  Future<AttendanceSessionModel> _ensureSessionForSave() async {
    final existing = _session;
    if (existing != null) return existing;
    if (_sectionId.isEmpty || _staffId.isEmpty || _academicYearId.isEmpty) {
      throw Exception('Assigned class or academic year is not ready.');
    }
    final session = await BackendApiClient.instance.createAttendanceSession(
      sectionId: _sectionId,
      subjectId: _subjectId,
      academicYearId: _academicYearId,
      staffId: _staffId,
      date: teacherFlowDate(_selectedDate),
      timetableSlotId: _timetableSlotId.isNotEmpty ? _timetableSlotId : null,
      periodNumber: _periodNumber,
    );
    if (mounted) setState(() => _session = session);
    return session;
  }

  Future<void> _saveAttendance({required bool finalize}) async {
    if (_session?.isFinalized ?? false) {
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
    final missingReason = _students.where(
      (student) => student.requiresReason && student.reason.trim().isEmpty,
    );
    if (missingReason.isNotEmpty) {
      final student = missingReason.first;
      await _editReason(student);
      if (!mounted) return;
      final updated = _students.where((row) => row.id == student.id).first;
      if (updated.reason.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reason is required for ${student.name}.'),
            backgroundColor: context.appTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }
    final missing = _students.where((student) => student.enrollmentMissing);
    if (missing.isNotEmpty) {
      throw Exception('Enrollment record missing for ${missing.first.name}');
    }
    setState(() => _saving = true);
    try {
      final session = await _ensureSessionForSave();
      final attendances = _students.map((student) {
        final enrollmentId = student.enrollmentId;
        return {
          'student_id': student.id,
          'enrollment_id': enrollmentId,
          'status': student.status,
          'reason': student.reason,
          'enrollment_missing': enrollmentId.isEmpty,
        };
      }).toList();
      await BackendApiClient.instance.markAttendance(
        session.id,
        attendances,
        finalize: finalize,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            finalize ? 'Attendance submitted and locked' : 'Draft saved',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      if (finalize) {
        await _offerDiaryAfterPeriod();
      }
      setState(() => _saving = false);
      await _loadFlow();
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to save attendance: $error'),
          backgroundColor: context.appTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _requestCorrection() async {
    final session = _session;
    if (session == null || !session.isFinalized) return;
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request Correction'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Reason',
            hintText: 'Explain what needs correction',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason == null || reason.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await BackendApiClient.instance.requestAttendanceCorrection(
        session.id,
        reason: reason.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Correction request sent to principal'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() => _saving = false);
      await _loadFlow();
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to request correction: $error'),
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
          .map(
            (student) => student.copyWith(
              status: status,
              reason: _statusRequiresReason(status) ? student.reason : '',
            ),
          )
          .toList();
    });
  }

  Future<void> _markOne(_AttendanceStudent student, String status) async {
    if (_session?.isFinalized ?? false) return;
    String reason = student.reason;
    if (_statusRequiresReason(status)) {
      reason = await _reasonForStatus(student, status) ?? student.reason;
      if (reason.trim().isEmpty) return;
    } else {
      reason = '';
    }
    setState(() {
      _students = _students
          .map(
            (row) => row.id == student.id
                ? row.copyWith(status: status, reason: reason)
                : row,
          )
          .toList();
    });
  }

  Future<void> _editReason(_AttendanceStudent student) async {
    final reason = await _reasonForStatus(student, student.status);
    if (reason == null) return;
    setState(() {
      _students = _students
          .map(
            (row) => row.id == student.id ? row.copyWith(reason: reason) : row,
          )
          .toList();
    });
  }

  Future<String?> _reasonForStatus(
    _AttendanceStudent student,
    String status,
  ) async {
    final controller = TextEditingController(text: student.reason);
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${_statusLabel(status)} reason'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: 'Reason',
            hintText: 'Required for ${_statusLabel(status)}',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    return reason;
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
              status: _statusLabel(_session?.status ?? 'submitted'),
              statusColor: Colors.green,
              body: Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: _saving ? null : _requestCorrection,
                  icon: const Icon(Icons.report_problem_rounded, size: 18),
                  label: const Text('Request Correction'),
                ),
              ),
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
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final option in _attendanceStatusOptions)
                        _buildAttendanceButton(
                          student: student,
                          status: option['status']!,
                          label: option['label']!,
                          color: _statusColor(option['status']!),
                        ),
                      if (student.requiresReason)
                        TextButton.icon(
                          onPressed: locked ? null : () => _editReason(student),
                          icon: const Icon(Icons.notes_rounded, size: 16),
                          label: Text(
                            student.reason.trim().isEmpty
                                ? 'Add reason'
                                : 'Edit reason',
                          ),
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
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _saving || _students.isEmpty || locked
                      ? null
                      : () => _saveAttendance(finalize: false),
                  icon: const Icon(Icons.save_rounded),
                  label: const Text('Save Draft'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _saving || _students.isEmpty || locked
                      ? null
                      : () => _saveAttendance(finalize: true),
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.lock_rounded),
                  label: Text(_saving ? 'Saving...' : 'Submit Final'),
                ),
              ),
            ],
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
  }) {
    final isSelected = student.status == status;
    return InkWell(
      onTap: () => _markOne(student, status),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        constraints: const BoxConstraints(minWidth: 92, minHeight: 40),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? color : Colors.grey.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
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

  static const _attendanceStatusOptions = [
    {'status': 'present', 'label': 'Present'},
    {'status': 'absent', 'label': 'Absent'},
    {'status': 'late', 'label': 'Late'},
    {'status': 'leave', 'label': 'Leave'},
    {'status': 'half_day', 'label': 'Half Day'},
  ];

  static bool _statusRequiresReason(String status) {
    return const {'absent', 'late', 'leave', 'half_day'}.contains(status);
  }

  static String _statusLabel(String status) {
    return switch (status) {
      'not_started' => 'Not Started',
      'needs_review' => 'Needs Review',
      'half_day' => 'Half Day',
      'submitted' => 'Submitted',
      'reopened' => 'Reopened',
      'corrected' => 'Corrected',
      'draft' => 'Draft',
      'present' => 'Present',
      'absent' => 'Absent',
      'late' => 'Late',
      'leave' => 'Leave',
      _ => teacherFlowTitleCase(status),
    };
  }

  static Color _statusColor(String status) {
    return switch (status) {
      'present' => Colors.green,
      'absent' => Colors.red,
      'late' => Colors.orange,
      'leave' => Colors.blue,
      'half_day' => Colors.purple,
      _ => teacherFlowAccent,
    };
  }
}

class _AttendanceStudent {
  final String id;
  final String name;
  final String roll;
  final String enrollmentId;
  final bool enrollmentMissing;
  final String status;
  final String reason;

  const _AttendanceStudent({
    required this.id,
    required this.name,
    required this.roll,
    required this.enrollmentId,
    required this.enrollmentMissing,
    this.status = 'present',
    this.reason = '',
  });

  bool get requiresReason =>
      _TeacherAttendanceScreenState._statusRequiresReason(status);

  Color get statusColor {
    return _TeacherAttendanceScreenState._statusColor(status);
  }

  _AttendanceStudent copyWith({String? status, String? reason}) {
    return _AttendanceStudent(
      id: id,
      name: name,
      roll: roll,
      enrollmentId: enrollmentId,
      enrollmentMissing: enrollmentMissing,
      status: status ?? this.status,
      reason: reason ?? this.reason,
    );
  }
}
