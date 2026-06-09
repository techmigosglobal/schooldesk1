import 'package:flutter/material.dart';

import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/services/role_access_service.dart';
import 'package:schooldesk1/core/theme/app_theme.dart';
import 'package:schooldesk1/core/widgets/teacher_flow_ui.dart';

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
      final slots = await api.getTimetableSlots(
        staffId: staffId,
        dayOfWeek: DateTime.now().weekday,
      );
      final slot = _pickAttendanceSlot(slots);
      final classTeacherSectionId = RoleAccessService.teacherClassId;
      final sectionId = classTeacherSectionId.isNotEmpty
          ? classTeacherSectionId
          : teacherFlowText(slot['section_id']);
      final slotBelongsToSection =
          teacherFlowText(slot['section_id']) == sectionId;
      final subjectId = teacherFlowText(slot['subject_id']);
      final academicYearId = teacherFlowText(slot['academic_year_id']);
      final slotId = teacherFlowText(slot['id'] ?? slot['slot_id']);
      final periodNumber = teacherFlowInt(slot['period_number']);
      if (sectionId.isEmpty) {
        throw Exception('Class teacher section is not assigned.');
      }
      if (academicYearId.isEmpty || subjectId.isEmpty || periodNumber < 1) {
        throw Exception(
          'Today timetable slot is missing academic year, subject, or period.',
        );
      }
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
      final date = teacherFlowDate(DateTime.now());
      final sessions = await api.getAttendanceSessions(
        sectionId: sectionId,
        date: date,
      );
      final matching = sessions.where(
        (session) =>
            slotId.isNotEmpty && session.timetableSlotId == slotId ||
            session.periodNumber == periodNumber,
      );
      final session = matching.isNotEmpty
          ? matching.first
          : await api.createAttendanceSession(
              sectionId: sectionId,
              subjectId: subjectId,
              academicYearId: academicYearId,
              staffId: staffId,
              date: date,
              timetableSlotId: slotBelongsToSection ? slotId : null,
              periodNumber: periodNumber,
            );
      if (!mounted) return;
      setState(() {
        _classLabel = classTeacherSectionId.isNotEmpty
            ? RoleAccessService.teacherClassName
            : _classLabelFromSlot(slot);
        _subjectLabel = _subjectLabelFromSlot(slot);
        _timeLabel = _timeLabelFromSlot(slot);
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
      setState(() => _saving = false);
      await _loadFlow();
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to submit attendance: $error'),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _markAll(String status) {
    setState(() {
      _students = _students
          .map((student) => student.copyWith(status: status))
          .toList();
    });
  }

  void _markOne(_AttendanceStudent student, String status) {
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
    return TeacherFlowScaffold(
      title: 'Student Attendance',
      subtitle: 'Class teacher first-period attendance',
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
                label: 'All Present',
                icon: Icons.done_all_rounded,
                filled: true,
                onTap: () => _markAll('present'),
              ),
              TeacherFlowAction(
                label: 'Refresh',
                icon: Icons.refresh_rounded,
                onTap: _loadFlow,
              ),
            ],
          ),
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
                color: AppTheme.error,
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
                body: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final status in ['present', 'absent', 'late'])
                      ChoiceChip(
                        label: Text(teacherFlowTitleCase(status)),
                        selected: student.status == status,
                        onSelected: (_) => _markOne(student, status),
                      ),
                    if (student.enrollmentMissing)
                      const TeacherInfoPill(
                        icon: Icons.warning_amber_rounded,
                        label: 'Enrollment missing',
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: _saving || _students.isEmpty ? null : _submit,
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

  Map<String, dynamic> _pickAttendanceSlot(List<Map<String, dynamic>> slots) {
    if (slots.isEmpty) return const {};
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

  String _classLabelFromSlot(Map<String, dynamic> slot) {
    final section = teacherFlowMap(slot['section']);
    final grade = teacherFlowText(section['grade_name']);
    final sectionName = teacherFlowText(section['section_name']);
    final label = [
      grade,
      sectionName,
    ].where((part) => part.isNotEmpty).join(' ');
    if (label.isNotEmpty) return label;
    return RoleAccessService.teacherClassName;
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
      'absent' => AppTheme.error,
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
