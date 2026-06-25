import 'package:flutter/material.dart';

import 'package:schooldesk1/core/navigation/role_nav_indices.dart';
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
  String _subjectLabel = 'Daily attendance';
  String _timeLabel = 'Whole day';
  AttendanceSessionModel? _session;
  List<_AttendanceStudent> _students = [];
  DateTime _selectedDate = DateTime.now();
  String _selectedSectionId = '';
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
      final classOptions = _attendanceClassOptions;
      final sectionId = _selectedSectionId.isNotEmpty
          ? _selectedSectionId
          : (RoleAccessService.teacherClassId.isNotEmpty
                ? RoleAccessService.teacherClassId
                : _sectionIdFromClassRow(
                    classOptions.isEmpty ? const {} : classOptions.first,
                  ));
      if (sectionId.isEmpty) {
        throw Exception(
          'You are not assigned as a class teacher to any section.\n'
          'Please contact Admin/Principal to set your class teacher assignment.',
        );
      }

      String effectiveAcademicYearId = '';
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

      // Load students for the class-teacher's section.
      final studentsPage = await api.getStudents(
        sectionId: sectionId,
        page: 1,
        pageSize: 120,
      );
      final students = <_AttendanceStudent>[];
      for (final s in studentsPage.data) {
        final enrollmentId = await _resolveEnrollmentId(
          api,
          s,
          sectionId: sectionId,
          academicYearId: effectiveAcademicYearId,
        );
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

      final matching = sessions.where((session) => session.periodNumber == 1);

      // Use an existing session only. New sessions are created on Save Draft or Submit Final.
      final session = matching.isNotEmpty ? matching.first : null;
      final attendanceRows = _hydrateSavedAttendanceRows(students, session);

      if (!mounted) return;
      setState(() {
        _selectedSectionId = sectionId;
        _sectionId = sectionId;
        _staffId = staffId;
        _subjectId = '';
        _academicYearId = effectiveAcademicYearId;
        _timetableSlotId = '';
        _periodNumber = 1;
        _classLabel = _classLabelForSection(sectionId);
        _subjectLabel = 'Daily attendance';
        _timeLabel = 'Whole day';
        _session = session;
        _students = attendanceRows;
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
    if (finalize && _unmarkedStudents.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Mark every student before final submit.'),
          backgroundColor: context.appTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (!finalize && _markedStudents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Mark at least one student before saving draft.'),
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
      final session = await _ensureSessionForSave();
      final rowsForSave = finalize ? _students : _markedStudents;
      final attendances = rowsForSave.map((student) {
        final enrollmentId = student.enrollmentId;
        return {
          'student_id': student.id,
          'enrollment_id': enrollmentId,
          'status': student.status,
          'reason': '',
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
          .map((student) => student.copyWith(status: status, reason: ''))
          .toList();
    });
  }

  List<_AttendanceStudent> _hydrateSavedAttendanceRows(
    List<_AttendanceStudent> students,
    AttendanceSessionModel? session,
  ) {
    if (session == null || session.studentAttendances.isEmpty) {
      return students;
    }
    final rowsByStudentId = <String, Map<String, dynamic>>{};
    for (final row in session.studentAttendances) {
      final studentId = teacherFlowText(row['student_id']);
      if (studentId.isNotEmpty) rowsByStudentId[studentId] = row;
    }
    return students.map((student) {
      final row = rowsByStudentId[student.id];
      if (row == null) return student;
      final status = _normalizeAttendanceStatus(row['status']);
      if (status == 'unmarked') return student;
      return student.copyWith(
        status: status,
        reason: teacherFlowText(row['reason']),
      );
    }).toList();
  }

  Future<void> _markOne(_AttendanceStudent student, String status) async {
    if (_session?.isFinalized ?? false) return;
    setState(() {
      _students = _students
          .map(
            (row) => row.id == student.id
                ? row.copyWith(status: status, reason: '')
                : row,
          )
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final locked = _session?.isFinalized ?? false;
    final unmarkedCount = _unmarkedStudents.length;
    return TeacherFlowScaffold(
      title: 'Student Attendance',
      subtitle: 'Class teacher attendance',
      selectedIndex: TeacherNav.attendance,
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
                label: 'Marked',
                value: '${_markedStudents.length}/${_students.length}',
                icon: Icons.how_to_reg_rounded,
                color: Colors.indigo,
                tone: const Color(0xFFEAF0FF),
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
                label: 'Not Marked',
                value: '$unmarkedCount',
                icon: Icons.radio_button_unchecked_rounded,
                color: Colors.blueGrey,
                tone: const Color(0xFFF1F5F9),
              ),
              TeacherFlowMetric(
                label: 'Absent',
                value: '${_students.where((s) => s.status == 'absent').length}',
                icon: Icons.cancel_rounded,
                color: context.appTheme.error,
                tone: const Color(0xFFFFEEEE),
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
          if (unmarkedCount > 0 && !locked) ...[
            const SizedBox(height: 8),
            TeacherInfoPill(
              icon: Icons.info_outline_rounded,
              label:
                  '$unmarkedCount student${unmarkedCount == 1 ? '' : 's'} not marked yet',
            ),
          ],
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
                status: _statusLabel(student.status),
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
                  onPressed:
                      _saving ||
                          _students.isEmpty ||
                          locked ||
                          _markedStudents.isEmpty
                      ? null
                      : () => _saveAttendance(finalize: false),
                  icon: const Icon(Icons.save_rounded),
                  label: const Text('Save Draft'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed:
                      _saving ||
                          _students.isEmpty ||
                          locked ||
                          _unmarkedStudents.isNotEmpty
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

  String _attendanceEnrollmentId(
    List<Map<String, dynamic>> enrollments, {
    required String sectionId,
    required String academicYearId,
    String fallbackEnrollmentId = '',
  }) {
    if (enrollments.isEmpty) return '';
    final matching = enrollments.where((row) {
      final rowSectionId = teacherFlowText(row['section_id']);
      final rowAcademicYearId = teacherFlowText(row['academic_year_id']);
      return rowSectionId == sectionId &&
          (academicYearId.isEmpty || rowAcademicYearId == academicYearId);
    }).toList();
    if (matching.isNotEmpty) {
      final active = matching.where(
        (row) => teacherFlowText(row['status']).toLowerCase() == 'active',
      );
      final row = active.isNotEmpty ? active.first : matching.first;
      return teacherFlowText(row['id'] ?? row['enrollment_id']);
    }
    if (fallbackEnrollmentId.trim().isNotEmpty) return fallbackEnrollmentId;
    final active = enrollments.where(
      (row) => teacherFlowText(row['status']).toLowerCase() == 'active',
    );
    final row = active.isNotEmpty ? active.first : enrollments.first;
    return teacherFlowText(row['id'] ?? row['enrollment_id']);
  }

  Future<String> _resolveEnrollmentId(
    BackendApiClient api,
    StudentModel s, {
    required String sectionId,
    required String academicYearId,
  }) async {
    final enrollments = await api.getStudentEnrollments(s.id);
    return _attendanceEnrollmentId(
      enrollments,
      sectionId: sectionId,
      academicYearId: academicYearId,
      fallbackEnrollmentId: s.activeEnrollmentId,
    );
  }

  Widget _selectionPanel() {
    final classOptions = _attendanceClassOptions;
    final selectedSection = _selectedSectionId.isNotEmpty
        ? _selectedSectionId
        : RoleAccessService.teacherClassId;
    return TeacherFlowCard(
      icon: Icons.tune_rounded,
      title: 'Attendance selection',
      subtitle: '${teacherFlowDate(_selectedDate)} · Whole day',
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
          if (classOptions.length > 1) ...[
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: selectedSection.isEmpty ? null : selectedSection,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Class / Section',
                prefixIcon: Icon(Icons.class_rounded),
              ),
              items: classOptions
                  .map(
                    (row) => DropdownMenuItem(
                      value: _sectionIdFromClassRow(row),
                      child: Text(_classLabelFromRow(row)),
                    ),
                  )
                  .where((item) => item.value?.trim().isNotEmpty == true)
                  .toList(),
              onChanged: (value) {
                if (value == null || value == _selectedSectionId) return;
                setState(() {
                  _selectedSectionId = value;
                  _session = null;
                  _students = [];
                });
                _loadFlow();
              },
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

  List<Map<String, dynamic>> get _attendanceClassOptions {
    final classTeacherClasses = RoleAccessService.teacherClassTeacherClasses;
    if (classTeacherClasses.isNotEmpty) return classTeacherClasses;
    return RoleAccessService.assignedTeacherClasses;
  }

  String _sectionIdFromClassRow(Map<String, dynamic> row) {
    return teacherFlowText(row['id'] ?? row['section_id']);
  }

  String _classLabelFromRow(Map<String, dynamic> row) {
    final label = teacherFlowText(row['label']);
    if (label.isNotEmpty) return label;
    final grade = teacherFlowText(row['grade_name'] ?? row['class_name']);
    final section = teacherFlowText(row['section_name'] ?? row['section']);
    final joined = [grade, section].where((part) => part.isNotEmpty).join(' ');
    return joined.isEmpty ? 'Class / Section' : joined;
  }

  static const _attendanceStatusOptions = [
    {'status': 'present', 'label': 'Present'},
    {'status': 'absent', 'label': 'Absent'},
  ];

  static String _statusLabel(String status) {
    return switch (status) {
      'not_started' => 'Not Started',
      'needs_review' => 'Needs Review',
      'submitted' => 'Submitted',
      'reopened' => 'Reopened',
      'corrected' => 'Corrected',
      'draft' => 'Draft',
      'unmarked' => 'Not Marked',
      'present' => 'Present',
      'absent' => 'Absent',
      _ => teacherFlowTitleCase(status),
    };
  }

  static Color _statusColor(String status) {
    return switch (status) {
      'unmarked' => Colors.blueGrey,
      'present' => Colors.green,
      'absent' => Colors.red,
      _ => teacherFlowAccent,
    };
  }

  static String _normalizeAttendanceStatus(Object? value) {
    final status = teacherFlowText(
      value,
    ).toLowerCase().replaceAll('-', '_').replaceAll(' ', '_');
    if (_attendanceStatusOptions.any((option) => option['status'] == status)) {
      return status;
    }
    return 'unmarked';
  }

  List<_AttendanceStudent> get _unmarkedStudents =>
      _students.where((student) => student.status == 'unmarked').toList();

  List<_AttendanceStudent> get _markedStudents =>
      _students.where((student) => student.status != 'unmarked').toList();
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
    this.status = 'unmarked',
    this.reason = '',
  });

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
