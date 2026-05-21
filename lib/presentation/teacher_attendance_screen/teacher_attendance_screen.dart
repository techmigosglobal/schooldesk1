import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../services/backend_api_client.dart';
import '../../services/role_access_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/dashboard_fab_widget.dart';
import '../../widgets/erp_module_scaffold.dart';
import '../../widgets/teacher_navigation.dart';

class TeacherAttendanceScreen extends StatefulWidget {
  const TeacherAttendanceScreen({super.key});

  @override
  State<TeacherAttendanceScreen> createState() =>
      _TeacherAttendanceScreenState();
}

class _TeacherAttendanceScreenState extends State<TeacherAttendanceScreen> {
  int _selectedNavIndex = 2;
  String? _selectedSlotId;
  String? _selectedSectionId;
  bool _loading = true;
  bool _saved = false;
  String? _error;

  final Map<String, List<Map<String, dynamic>>> _studentsBySection = {};
  final Map<String, SectionModel> _sectionsById = {};
  List<Map<String, dynamic>> _timetableSlots = const [];

  String get _selectedDate => DateFormat('d MMM yyyy').format(DateTime.now());

  Map<String, dynamic>? get _selectedSlot {
    final slotId = _selectedSlotId;
    if (slotId == null || slotId.isEmpty) return null;
    for (final slot in _timetableSlots) {
      if (_slotId(slot) == slotId) return slot;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await RoleAccessService.initialize();
      final staffId = RoleAccessService.teacherStaffId;
      if (staffId.isEmpty) {
        throw Exception('Teacher profile is not linked to a staff record.');
      }

      final api = BackendApiClient.instance;
      final slots = await api.getTimetableSlots(
        staffId: staffId,
        dayOfWeek: DateTime.now().weekday,
      );
      final sections = await api.getSections();
      final usableSlots =
          slots
              .where(
                (slot) =>
                    _text(slot['id']).isNotEmpty &&
                    _text(slot['section_id']).isNotEmpty &&
                    _text(slot['subject_id']).isNotEmpty,
              )
              .toList()
            ..sort(
              (a, b) => _intValue(
                a['period_number'],
              ).compareTo(_intValue(b['period_number'])),
            );

      final selected = usableSlots.isEmpty
          ? null
          : usableSlots.firstWhere(
              (slot) => _slotId(slot) == _selectedSlotId,
              orElse: () => usableSlots.first,
            );
      final sectionId = selected == null ? null : _text(selected['section_id']);

      if (!mounted) return;
      setState(() {
        _sectionsById
          ..clear()
          ..addEntries(
            sections.map((section) => MapEntry(section.id, section)),
          );
        _timetableSlots = usableSlots;
        _selectedSlotId = selected == null ? null : _slotId(selected);
        _selectedSectionId = sectionId;
      });

      if (sectionId == null || sectionId.isEmpty) {
        setState(() => _loading = false);
        return;
      }
      await _loadStudentsForSection(sectionId);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load timetable attendance: $e';
        _loading = false;
      });
    }
  }

  Future<void> _loadStudentsForSection(String sectionId) async {
    try {
      final studentsResponse = await BackendApiClient.instance.getStudents(
        sectionId: sectionId,
        pageSize: 100,
      );

      final rows = <Map<String, dynamic>>[];
      for (final s in studentsResponse.data) {
        final enrollments = await BackendApiClient.instance
            .getStudentEnrollments(s.id);
        String enrollmentId = '';
        String roll = s.studentCode;
        for (final e in enrollments) {
          if (_text(e['section_id']) == sectionId) {
            enrollmentId = _text(e['id']);
            roll = _text(e['roll_number'], fallback: s.studentCode);
            break;
          }
        }
        rows.add({
          'id': s.id,
          'enrollment_id': enrollmentId,
          'name': s.fullName,
          'roll': roll,
          'status': 'present',
          'enrollment_missing': enrollmentId.isEmpty,
        });
      }

      if (!mounted) return;
      setState(() {
        _studentsBySection[sectionId] = rows;
        _loading = false;
        _saved = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load students for this timetable slot: $e';
        _loading = false;
      });
    }
  }

  Future<void> _selectSlot(String? slotId) async {
    if (slotId == null || slotId == _selectedSlotId) return;
    final slot = _timetableSlots.firstWhere(
      (row) => _slotId(row) == slotId,
      orElse: () => const <String, dynamic>{},
    );
    final sectionId = _text(slot['section_id']);
    if (sectionId.isEmpty) return;
    setState(() {
      _selectedSlotId = slotId;
      _selectedSectionId = sectionId;
      _loading = true;
      _error = null;
    });
    if (_studentsBySection.containsKey(sectionId)) {
      setState(() {
        _loading = false;
        _saved = false;
      });
      return;
    }
    await _loadStudentsForSection(sectionId);
  }

  void _setStatus(int index, String status) {
    final sid = _selectedSectionId;
    if (sid == null) return;
    setState(() {
      _studentsBySection[sid]![index]['status'] = status;
      _saved = false;
    });
  }

  void _markAllPresent() {
    final sid = _selectedSectionId;
    if (sid == null) return;
    setState(() {
      for (final s in _studentsBySection[sid] ?? <Map<String, dynamic>>[]) {
        s['status'] = 'present';
      }
      _saved = false;
    });
  }

  Future<void> _saveAttendance() async {
    final slot = _selectedSlot;
    final sid = _selectedSectionId;
    if (slot == null || sid == null) return;

    setState(() => _loading = true);
    try {
      final students = _studentsBySection[sid] ?? <Map<String, dynamic>>[];
      final missingEnrollment = students.where(
        (s) => s['enrollment_missing'] == true,
      );
      if (missingEnrollment.isNotEmpty) {
        final names = missingEnrollment
            .map((s) => _text(s['name'], fallback: 'student'))
            .take(3)
            .join(', ');
        throw Exception('Enrollment record missing for $names.');
      }

      final attendances = students
          .map(
            (s) => {
              'student_id': s['id'],
              'enrollment_id': s['enrollment_id'],
              'status': s['status'],
              'reason': '',
            },
          )
          .toList();

      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final subjectId = _text(slot['subject_id']);
      final staffId = _text(
        slot['staff_id'],
        fallback: RoleAccessService.teacherStaffId,
      );
      final periodNumber = _intValue(slot['period_number']);
      final slotId = _slotId(slot);
      if (subjectId.isEmpty || staffId.isEmpty || periodNumber < 1) {
        throw Exception('Selected timetable slot is incomplete.');
      }

      final sessions = await BackendApiClient.instance.getAttendanceSessions(
        sectionId: sid,
        date: today,
      );
      final existingSession = _matchingSession(
        sessions,
        staffId: staffId,
        subjectId: subjectId,
        periodNumber: periodNumber,
        timetableSlotId: slotId,
      );

      final sessionId =
          existingSession?.id ??
          (await BackendApiClient.instance.createAttendanceSession(
            sectionId: sid,
            subjectId: subjectId,
            staffId: staffId,
            date: today,
            periodNumber: periodNumber,
            timetableSlotId: slotId,
          )).id;

      await BackendApiClient.instance.markAttendance(sessionId, attendances);
      if (!mounted) return;
      setState(() {
        _saved = true;
        _loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Attendance saved for ${_slotLabel(slot)}'),
          backgroundColor: AppTheme.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save attendance: $e')));
    }
  }

  AttendanceSessionModel? _matchingSession(
    List<AttendanceSessionModel> sessions, {
    required String staffId,
    required String subjectId,
    required int periodNumber,
    required String timetableSlotId,
  }) {
    for (final session in sessions) {
      final slotMatches =
          timetableSlotId.isEmpty ||
          session.timetableSlotId.isEmpty ||
          session.timetableSlotId == timetableSlotId;
      if (session.staffId == staffId &&
          session.subjectId == subjectId &&
          session.periodNumber == periodNumber &&
          slotMatches) {
        return session;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final drawer = TeacherDrawer(
      selectedIndex: _selectedNavIndex,
      onDestinationSelected: (i) => setState(() => _selectedNavIndex = i),
    );
    if (_loading) {
      return SchoolDeskModuleScaffold(
        title: 'Student Attendance',
        subtitle: 'Mark attendance from today timetable',
        drawer: drawer,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return SchoolDeskModuleScaffold(
        title: 'Student Attendance',
        subtitle: 'Mark attendance from today timetable',
        drawer: drawer,
        body: _emptyState(_error!, actionLabel: 'Retry', onAction: _loadData),
      );
    }
    if (_timetableSlots.isEmpty || _selectedSlot == null) {
      return SchoolDeskModuleScaffold(
        title: 'Student Attendance',
        subtitle: 'Mark attendance from today timetable',
        drawer: drawer,
        body: _emptyState(
          'No timetable periods are assigned to you today. Attendance will unlock when Admin or Principal adds today timetable slots for your staff profile.',
          actionLabel: 'Refresh',
          onAction: _loadData,
        ),
      );
    }

    final sid = _selectedSectionId;
    final students = sid == null
        ? <Map<String, dynamic>>[]
        : _studentsBySection[sid] ?? <Map<String, dynamic>>[];
    final presentCount = students.where((s) => s['status'] == 'present').length;
    final absentCount = students.where((s) => s['status'] == 'absent').length;
    final lateCount = students.where((s) => s['status'] == 'late').length;
    final halfDayCount = students
        .where((s) => s['status'] == 'half-day')
        .length;

    return SchoolDeskModuleScaffold(
      title: 'Student Attendance',
      subtitle: 'Mark attendance from today timetable',
      drawer: drawer,
      floatingActionButton: const DashboardFabWidget(
        role: DashboardRole.teacher,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      body: Column(
        children: [
          Container(
            color: AppTheme.surface,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _selectedSlotId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Timetable period',
                    prefixIcon: Icon(Icons.calendar_view_day_rounded),
                  ),
                  items: _timetableSlots
                      .map(
                        (slot) => DropdownMenuItem(
                          value: _slotId(slot),
                          child: Text(
                            _slotLabel(slot),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: _selectSlot,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${_sectionLabelForId(sid ?? '')} · $_selectedDate',
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          color: AppTheme.muted,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _markAllPresent,
                      icon: const Icon(Icons.done_all_rounded, size: 14),
                      label: Text(
                        'All Present',
                        style: GoogleFonts.dmSans(fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _badge('Present', presentCount, AppTheme.success),
                    _badge('Absent', absentCount, AppTheme.error),
                    _badge('Late', lateCount, AppTheme.warning),
                    _badge('Half-Day', halfDayCount, AppTheme.info),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: students.isEmpty
                ? _emptyState('No enrolled students found for this section.')
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: students.length,
                    itemBuilder: (_, i) => _row(students[i], i),
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              border: Border(top: BorderSide(color: AppTheme.outlineVariant)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _loadData,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Refresh'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: students.isEmpty ? null : _saveAttendance,
                    icon: Icon(
                      _saved ? Icons.check_rounded : Icons.save_rounded,
                      size: 16,
                    ),
                    label: Text(_saved ? 'Saved!' : 'Save Attendance'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _saved
                          ? AppTheme.success
                          : AppTheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(
    String message, {
    String? actionLabel,
    Future<void> Function()? onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.event_busy_rounded,
              color: AppTheme.muted,
              size: 42,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(fontSize: 13, color: AppTheme.muted),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 14),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _badge(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label: $count',
        style: GoogleFonts.dmSans(fontSize: 11, color: color),
      ),
    );
  }

  Widget _row(Map<String, dynamic> student, int index) {
    final status = (student['status'] ?? 'present').toString();
    final missingEnrollment = student['enrollment_missing'] == true;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: missingEnrollment ? AppTheme.warning : AppTheme.outlineVariant,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(
              (student['roll'] ?? '-').toString(),
              style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Text((student['name'] ?? 'Student').toString()),
                ),
                if (missingEnrollment)
                  const Tooltip(
                    message: 'Enrollment record missing for this section',
                    child: Icon(
                      Icons.warning_amber_rounded,
                      color: AppTheme.warning,
                      size: 18,
                    ),
                  ),
              ],
            ),
          ),
          _statusBtn('P', 'present', status, index, AppTheme.success),
          const SizedBox(width: 4),
          _statusBtn('A', 'absent', status, index, AppTheme.error),
          const SizedBox(width: 4),
          _statusBtn('L', 'late', status, index, AppTheme.warning),
          const SizedBox(width: 4),
          _statusBtn('H', 'half-day', status, index, AppTheme.info),
        ],
      ),
    );
  }

  Widget _statusBtn(
    String label,
    String value,
    String current,
    int index,
    Color color,
  ) {
    final selected = current == value;
    return GestureDetector(
      onTap: () => _setStatus(index, value),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: selected ? color : color.withAlpha(20),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : color,
            ),
          ),
        ),
      ),
    );
  }

  String _slotId(Map<String, dynamic> slot) => _text(slot['id']);

  String _slotLabel(Map<String, dynamic> slot) {
    final period = _intValue(slot['period_number']);
    final parts = [
      if (period > 0) 'P$period',
      _subjectLabel(slot),
      _sectionLabelForId(_text(slot['section_id'])),
      _timeLabel(slot),
    ].where((part) => part.trim().isNotEmpty).toList();
    return parts.isEmpty ? _slotId(slot) : parts.join(' · ');
  }

  String _subjectLabel(Map<String, dynamic> slot) {
    final subject = slot['subject'];
    if (subject is Map) {
      final name = _text(
        subject['subject_name'],
        fallback: _text(subject['name']),
      );
      if (name.isNotEmpty) return name;
    }
    return _text(slot['subject_name'], fallback: _text(slot['subject_id']));
  }

  String _sectionLabelForId(String sectionId) {
    final section = _sectionsById[sectionId];
    if (section == null) return sectionId;
    final label = [
      section.gradeName,
      section.sectionName,
    ].where((part) => part.trim().isNotEmpty).join(' ');
    return label.isEmpty ? section.id : label;
  }

  String _timeLabel(Map<String, dynamic> slot) {
    final start = _text(slot['start_time']);
    final end = _text(slot['end_time']);
    if (start.isEmpty && end.isEmpty) return '';
    if (end.isEmpty) return start;
    return '$start - $end';
  }

  int _intValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _text(dynamic value, {String fallback = ''}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty || text == 'null' ? fallback : text;
  }
}
