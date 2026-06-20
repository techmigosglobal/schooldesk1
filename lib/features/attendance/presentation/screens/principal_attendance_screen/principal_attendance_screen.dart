import 'package:flutter/material.dart';

import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/widgets/empty_state_widget.dart';
import 'package:schooldesk1/core/widgets/principal_directory_ui.dart';
import 'package:schooldesk1/routes/app_routes.dart';
import 'package:schooldesk1/core/utils/extensions.dart';

enum _AttendanceView { classes, sessions, students, reports }

class PrincipalAttendanceScreen extends StatefulWidget {
  const PrincipalAttendanceScreen({super.key});

  @override
  State<PrincipalAttendanceScreen> createState() =>
      _PrincipalAttendanceScreenState();
}

class _PrincipalAttendanceScreenState extends State<PrincipalAttendanceScreen> {
  bool _loading = true;
  bool _detailLoading = false;
  String? _error;
  String _search = '';
  _AttendanceView _view = _AttendanceView.classes;
  String _selectedSectionId = '';
  String _selectedStudentId = '';

  List<StaffAttendanceModel> _staffAttendance = [];
  List<StaffModel> _staff = [];
  List<SectionModel> _sections = [];
  List<AttendanceSessionModel> _sessions = [];
  List<StudentModel> _sectionStudents = [];
  List<Map<String, dynamic>> _studentAttendanceRecords = [];

  String get _todayText => DateTime.now().toIso8601String().split('T').first;

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
      final api = BackendApiClient.instance;
      final results = await Future.wait<Object>([
        api.getStaffAttendanceForDate(date: _todayText),
        api.getStaff(page: 1, pageSize: 500, status: 'active'),
        api.getSections(),
        api.getAttendanceSessions(date: _todayText),
      ]);
      final sections = results[2] as List<SectionModel>;
      if (!mounted) return;
      setState(() {
        _staffAttendance = results[0] as List<StaffAttendanceModel>;
        _staff = (results[1] as PaginatedList<StaffModel>).data;
        _sections = sections;
        _sessions = results[3] as List<AttendanceSessionModel>;
        _selectedSectionId =
            _selectedSectionId.isNotEmpty &&
                sections.any((section) => section.id == _selectedSectionId)
            ? _selectedSectionId
            : (sections.isEmpty ? '' : sections.first.id);
        _loading = false;
      });
      if (_selectedSectionId.isNotEmpty) {
        await _loadSectionStudents(_selectedSectionId);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load attendance directory from backend. $error';
        _loading = false;
      });
    }
  }

  Future<void> _loadSectionStudents(String sectionId) async {
    setState(() => _detailLoading = true);
    try {
      final response = await BackendApiClient.instance.getStudents(
        sectionId: sectionId,
        page: 1,
        pageSize: 120,
      );
      if (!mounted) return;
      setState(() {
        _sectionStudents = response.data;
        _selectedStudentId =
            _selectedStudentId.isNotEmpty &&
                response.data.any((student) => student.id == _selectedStudentId)
            ? _selectedStudentId
            : (response.data.isEmpty ? '' : response.data.first.id);
        _detailLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _sectionStudents = const [];
        _selectedStudentId = '';
        _detailLoading = false;
      });
      _showSnack('Class students unavailable: $error');
    }
  }

  Future<void> _loadStudentAttendance(String studentId) async {
    setState(() {
      _selectedStudentId = studentId;
      _detailLoading = true;
    });
    try {
      final records = await BackendApiClient.instance
          .getStudentAttendanceRecords(
            studentId,
            month: DateTime.now().month,
            year: DateTime.now().year,
          );
      if (!mounted) return;
      setState(() {
        _studentAttendanceRecords = records;
        _detailLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _studentAttendanceRecords = const [];
        _detailLoading = false;
      });
      _showSnack('Student attendance records unavailable: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cards = _directoryCards;
    return PrincipalDirectoryScaffold(
      title: 'Student Attendance Monitor',
      subtitle: 'Class-period status, correction review, and registers',
      loading: _loading,
      error: _error,
      onRefresh: _load,
      filters: _buildFilters(),
      isEmpty: !_loading && _error == null && cards.isEmpty,
      emptyState: const EmptyStateWidget(
        icon: Icons.fact_check_outlined,
        title: 'No attendance rows found',
        description: 'Refresh the directory or adjust the attendance filters.',
      ),
      slivers: [
        SliverToBoxAdapter(
          child: PrincipalDirectoryMetricStrip(metrics: _metrics),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(22, 10, 22, 96),
          sliver: SliverList.builder(
            itemCount: cards.length,
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.only(bottom: 13),
              child: cards[index],
            ),
          ),
        ),
      ],
    );
  }

  List<PrincipalDirectoryMetric> get _metrics => [
    PrincipalDirectoryMetric(
      label: 'Sessions Today',
      value: '${_sessions.length}',
      icon: Icons.fact_check_outlined,
      color: context.appTheme.primary,
      tone: const Color(0xFFEFF6FF),
    ),
    PrincipalDirectoryMetric(
      label: 'Present Today',
      value: '$_presentStudentsToday',
      icon: Icons.groups_outlined,
      color: context.appTheme.success,
      tone: const Color(0xFFECFDF3),
    ),
    PrincipalDirectoryMetric(
      label: 'Marked Today',
      value: '$_markedStudentsToday/$_expectedStudentsToday',
      icon: Icons.how_to_reg_outlined,
      color: Colors.teal,
      tone: const Color(0xFFE6FFFB),
    ),
    PrincipalDirectoryMetric(
      label: 'Staff Check-in Monitor',
      value:
          '${_staffAttendance.where((row) => row.checkedIn).length}/${_staff.length}',
      icon: Icons.badge_outlined,
      color: Colors.indigo,
      tone: const Color(0xFFEAF0FF),
    ),
    PrincipalDirectoryMetric(
      label: 'Exceptions',
      value: '${_exceptions.length}',
      icon: Icons.warning_amber_rounded,
      color: _exceptions.isEmpty
          ? context.appTheme.success
          : context.appTheme.warning,
      tone: const Color(0xFFFFF7ED),
    ),
  ];

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 4, 22, 4),
      child: Column(
        children: [
          PrincipalDirectorySearchBox(
            hint: 'Search class, staff, student, status...',
            onChanged: (value) => setState(() => _search = value),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              children: [
                _modeChip(
                  _AttendanceView.classes,
                  'Classes',
                  Icons.apartment_outlined,
                ),
                _modeChip(
                  _AttendanceView.sessions,
                  'Monitor',
                  Icons.list_alt_outlined,
                ),
                _modeChip(
                  _AttendanceView.students,
                  'Students',
                  Icons.groups_outlined,
                ),
                _modeChip(
                  _AttendanceView.reports,
                  'Reports',
                  Icons.summarize_outlined,
                ),
              ],
            ),
          ),
          if (_view == _AttendanceView.students && _sections.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 42,
              child: ListView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                children: [
                  for (final section in _sections)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: PrincipalDirectoryChip(
                        label: _sectionLabel(section.id),
                        selected: _selectedSectionId == section.id,
                        icon: Icons.apartment_rounded,
                        onTap: () async {
                          setState(() => _selectedSectionId = section.id);
                          await _loadSectionStudents(section.id);
                        },
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _modeChip(_AttendanceView view, String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: PrincipalDirectoryChip(
        label: label,
        icon: icon,
        selected: _view == view,
        onTap: () => setState(() => _view = view),
      ),
    );
  }

  List<Widget> get _directoryCards {
    final rows = switch (_view) {
      _AttendanceView.classes => _classAttendanceCards,
      _AttendanceView.sessions => _sessions.map(_sessionCard).toList(),
      _AttendanceView.students =>
        _detailLoading
            ? [_loadingCard('Loading students', 'Fetching selected class roll')]
            : _sectionStudents.map(_studentCard).toList(),
      _AttendanceView.reports => _attendanceViewCards,
    };
    final query = _search.trim().toLowerCase();
    if (query.isEmpty) return rows;
    return rows.where((card) => _widgetText(card).contains(query)).toList();
  }

  List<Widget> get _classAttendanceCards {
    final sections = _sections.isEmpty
        ? _sessions
              .map((session) => session.sectionId)
              .where((id) => id.trim().isNotEmpty)
              .toSet()
              .map((id) => _AttendanceSectionSummary(id, _sectionLabel(id)))
              .toList()
        : _sections.map((section) {
            return _AttendanceSectionSummary(
              section.id,
              _sectionLabel(section.id),
            );
          }).toList();
    sections.sort((left, right) => left.label.compareTo(right.label));
    return [for (final section in sections) _classAttendanceCard(section)];
  }

  List<Widget> get _attendanceViewCards => [
    _reportCard('Daily attendance view', 'pdf'),
    _reportCard('Class attendance register', 'csv'),
    for (final session in _exceptions) _exceptionCard(session),
  ];

  Widget _classAttendanceCard(_AttendanceSectionSummary section) {
    final sessions = _sessions
        .where((session) => session.sectionId == section.sectionId)
        .toList();
    final present = sessions.fold(0, (sum, row) => sum + _effectivePresentCount(row));
    final total = sessions.fold(0, (sum, row) => sum + _effectiveTotalStudents(row));
    final percent = total <= 0 ? 0 : (present / total) * 100;
    final status = sessions.isEmpty
        ? 'Not Started'
        : sessions.any((row) => row.status == 'needs_review')
        ? 'Needs Review'
        : sessions.any((row) => row.status == 'draft')
        ? 'Draft'
        : sessions.any((row) => row.status == 'reopened')
        ? 'Reopened'
        : 'Submitted';
    final statusColor = total <= 0
        ? context.appTheme.warning
        : percent < 75
        ? context.appTheme.warning
        : context.appTheme.success;
    return PrincipalDirectoryCard(
      icon: Icons.apartment_outlined,
      title: section.label,
      subtitle: sessions.isEmpty
          ? 'No attendance sessions returned for today'
          : '${sessions.length} sessions | $present/$total marked present',
      status: status,
      statusColor: statusColor,
      chips: [
        PrincipalInfoPill(
          icon: Icons.percent_rounded,
          label: '${percent.toStringAsFixed(0)}%',
        ),
        PrincipalInfoPill(
          icon: Icons.fact_check_outlined,
          label: '${sessions.length} sessions',
        ),
      ],
      trailing: IconButton(
        tooltip: 'Open class in Classes Hub',
        icon: const Icon(Icons.account_tree_outlined),
        onPressed: () =>
            _openClassesHub(action: 'attendance', sectionId: section.sectionId),
      ),
      onTap: () async {
        setState(() {
          _selectedSectionId = section.sectionId;
          _view = _AttendanceView.students;
        });
        await _loadSectionStudents(section.sectionId);
      },
    );
  }

  Widget _exceptionCard(AttendanceSessionModel session) {
    final incomplete = _isIncompleteSession(session);
    return PrincipalDirectoryCard(
      icon: incomplete
          ? Icons.radio_button_unchecked_rounded
          : Icons.warning_amber_rounded,
      title: _sectionLabel(session.sectionId),
      subtitle: incomplete
          ? 'Period ${session.periodNumber} | ${_sessionStaffLabel(session)} has not submitted final attendance'
          : 'Period ${session.periodNumber} | ${session.presentCount}/${session.totalStudents} present',
      status: incomplete ? 'Incomplete' : 'Review',
      statusColor: context.appTheme.warning,
      chips: [
        PrincipalInfoPill(
          icon: Icons.event_available_outlined,
          label: _dateOnly(session.date),
        ),
        PrincipalInfoPill(
          icon: Icons.groups_outlined,
          label: incomplete
              ? '${_unmarkedCount(session)} unmarked'
              : '${_attendancePercent(session).toStringAsFixed(0)}%',
        ),
      ],
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: principalDirectoryMuted,
      ),
      onTap: () => _openSessionDetail(session),
    );
  }

  Widget _sessionCard(AttendanceSessionModel session) {
    final status = _sessionStatusLabel(session);
    final counts = _sessionStatusCounts(session);
    return PrincipalDirectoryCard(
      icon: Icons.fact_check_outlined,
      title: _sectionLabel(session.sectionId),
      subtitle:
          'Teacher ${_sessionStaffLabel(session)} | Period ${session.periodNumber} | ${_dateOnly(session.date)}',
      status: status,
      statusColor: _sessionStatusColor(session),
      chips: [
        PrincipalInfoPill(
          icon: Icons.check_circle_outline,
          label: 'Present ${counts['present']}',
        ),
        PrincipalInfoPill(
          icon: Icons.cancel_outlined,
          label: 'Absent ${counts['absent']}',
        ),
        PrincipalInfoPill(
          icon: Icons.schedule_outlined,
          label: 'Late ${counts['late']}',
        ),
        PrincipalInfoPill(
          icon: Icons.event_available_outlined,
          label: 'Leave ${counts['leave']}',
        ),
        if (_isIncompleteSession(session))
          PrincipalInfoPill(
            icon: Icons.radio_button_unchecked_rounded,
            label: '${_unmarkedCount(session)} unmarked',
          ),
        PrincipalInfoPill(
          icon: Icons.menu_book_outlined,
          label: _sessionSubjectLabel(session),
        ),
      ],
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: principalDirectoryMuted,
      ),
      onTap: () => _openSessionDetail(session),
    );
  }

  Widget _studentCard(StudentModel student) {
    final selected = _selectedStudentId == student.id;
    return PrincipalDirectoryCard(
      icon: Icons.person_outline_rounded,
      title: student.fullName.isEmpty ? student.id : student.fullName,
      subtitle: 'Admission ${student.admissionNumber} | ${student.status}',
      status: selected ? 'Selected' : student.status,
      statusColor: selected
          ? context.appTheme.primary
          : context.appTheme.success,
      chips: [
        PrincipalInfoPill(
          icon: Icons.apartment_rounded,
          label: _sectionLabel(student.currentSectionId ?? _selectedSectionId),
        ),
        PrincipalInfoPill(
          icon: Icons.percent_rounded,
          label: '${student.attendancePercent.toStringAsFixed(0)}%',
        ),
      ],
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: principalDirectoryMuted,
      ),
      selected: selected,
      onTap: () async {
        await _loadStudentAttendance(student.id);
        if (!mounted) return;
        _openStudentDetail(student);
      },
    );
  }

  Widget _reportCard(String title, String format) {
    return PrincipalDirectoryCard(
      icon: format == 'pdf'
          ? Icons.picture_as_pdf_outlined
          : Icons.table_chart_outlined,
      title: title,
      subtitle:
          'View class-wise attendance for ${_sectionLabel(_selectedSectionId)}',
      status: 'View',
      statusColor: context.appTheme.primary,
      chips: [
        PrincipalInfoPill(
          icon: Icons.calendar_today_outlined,
          label: _todayText,
        ),
        PrincipalInfoPill(
          icon: Icons.apartment_rounded,
          label: _sectionLabel(_selectedSectionId),
        ),
      ],
      trailing: IconButton(
        tooltip: 'Open class in Classes Hub',
        icon: const Icon(Icons.account_tree_outlined),
        onPressed: () => _openClassesHub(action: 'attendance'),
      ),
      onTap: () => _openReportDetail(title, format),
    );
  }

  Widget _loadingCard(String title, String subtitle) {
    return PrincipalDirectoryCard(
      icon: Icons.hourglass_top_rounded,
      title: title,
      subtitle: subtitle,
      status: 'Loading',
      statusColor: context.appTheme.primary,
    );
  }

  Future<void> _openSessionDetail(AttendanceSessionModel session) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => PrincipalDetailPage(
          title: _sectionLabel(session.sectionId),
          children: [
            PrincipalDetailCard(
              title: 'Attendance Session',
              trailing: PrincipalStatusPill(
                label: _sessionStatusLabel(session),
                color: _sessionStatusColor(session),
              ),
              children: [
                PrincipalDetailRow(
                  label: 'Date',
                  value: _dateOnly(session.date),
                ),
                PrincipalDetailRow(
                  label: 'Period',
                  value: '${session.periodNumber}',
                ),
                PrincipalDetailRow(
                  label: 'Present',
                  value: '${session.presentCount}/${session.totalStudents}',
                ),
                PrincipalDetailRow(
                  label: 'Attendance',
                  value: '${_attendancePercent(session).toStringAsFixed(1)}%',
                ),
                PrincipalDetailRow(
                  label: 'Subject',
                  value: _sessionSubjectLabel(session),
                ),
                PrincipalDetailRow(
                  label: 'Teacher',
                  value: _sessionStaffLabel(session),
                ),
                PrincipalDetailRow(
                  label: 'Reopen reason',
                  value: session.reopenReason.isEmpty
                      ? 'Not reopened'
                      : session.reopenReason,
                ),
                PrincipalDetailRow(
                  label: 'Correction request',
                  value: session.correctionReason.isEmpty
                      ? 'None'
                      : session.correctionReason,
                ),
                PrincipalActionTile(
                  icon: Icons.lock_open_rounded,
                  title: 'Reopen Attendance',
                  subtitle: 'Allow the assigned teacher to submit a correction',
                  onTap: () => _reopenAttendance(session),
                ),
                PrincipalActionTile(
                  icon: Icons.notifications_active_outlined,
                  title: 'Send Reminder',
                  subtitle: 'Notify teacher ${_sessionStaffLabel(session)}',
                  onTap: () => _showSnack(
                    'Reminder queued for ${_sessionStaffLabel(session)}',
                    success: true,
                  ),
                ),
                PrincipalActionTile(
                  icon: Icons.table_chart_outlined,
                  title: 'Export Class Register',
                  subtitle: 'Open the attendance register export',
                  onTap: () {
                    Navigator.pop(context);
                    _openReportDetail('Class attendance register', 'csv');
                  },
                ),
                PrincipalActionTile(
                  icon: Icons.history_rounded,
                  title: 'Audit Trail',
                  subtitle: _auditTrailSummary(session),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _reopenAttendance(AttendanceSessionModel session) async {
    final reason = await _promptReason('Reopen Attendance');
    if (reason == null || reason.trim().isEmpty) return;
    try {
      await BackendApiClient.instance.reopenAttendanceSession(
        session.id,
        reason: reason.trim(),
      );
      if (!mounted) return;
      _showSnack('Attendance reopened', success: true);
      Navigator.pop(context);
      await _load();
    } catch (error) {
      _showSnack('Unable to reopen attendance: $error');
    }
  }

  Future<String?> _promptReason(String title) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Reason',
            hintText: 'Required for audit trail',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Reopen'),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  Future<void> _openStudentDetail(StudentModel student) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => PrincipalDetailPage(
          title: student.fullName.isEmpty
              ? 'Student Attendance'
              : student.fullName,
          children: [
            PrincipalDetailCard(
              title: 'Student Summary',
              trailing: PrincipalStatusPill(
                label: student.status,
                color: context.appTheme.primary,
              ),
              children: [
                PrincipalDetailRow(
                  label: 'Admission',
                  value: student.admissionNumber,
                ),
                PrincipalDetailRow(
                  label: 'Class',
                  value: _sectionLabel(
                    student.currentSectionId ?? _selectedSectionId,
                  ),
                ),
                PrincipalDetailRow(
                  label: 'Attendance',
                  value: '${student.attendancePercent.toStringAsFixed(1)}%',
                ),
              ],
            ),
            PrincipalDetailCard(
              title: 'Current Month',
              children: _studentAttendanceRecords.isEmpty
                  ? const [Text('No day-wise attendance records returned yet.')]
                  : [
                      for (final record in _studentAttendanceRecords.take(16))
                        PrincipalActionTile(
                          icon: Icons.event_available_outlined,
                          title: _text(
                            record['date'],
                            fallback: 'Attendance record',
                          ),
                          subtitle: _text(
                            record['status'],
                            fallback: 'status pending',
                          ),
                        ),
                    ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openReportDetail(String title, String format) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => PrincipalDetailPage(
          title: title,
          children: [
            PrincipalDetailCard(
              title: 'Report Export',
              children: [
                PrincipalDetailRow(
                  label: 'Format',
                  value: format.toUpperCase(),
                ),
                PrincipalDetailRow(label: 'Date', value: _todayText),
                PrincipalDetailRow(
                  label: 'Class',
                  value: _sectionLabel(_selectedSectionId),
                ),
                PrincipalActionTile(
                  icon: Icons.account_tree_outlined,
                  title: 'Open class in Classes Hub',
                  subtitle:
                      'Attendance changes should start from the selected class',
                  onTap: () {
                    Navigator.pop(context);
                    _openClassesHub(action: 'attendance');
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openClassesHub({String action = 'details', String sectionId = ''}) {
    Navigator.pushNamed(
      context,
      AppRoutes.principalClasses,
      arguments: {
        'class_hub_action': action,
        'action': action,
        'selectedStep': action == 'attendance' ? 'section_setup' : action,
        'section_id': sectionId.isEmpty ? _selectedSectionId : sectionId,
        'sectionId': sectionId.isEmpty ? _selectedSectionId : sectionId,
        'classId': sectionId.isEmpty ? _selectedSectionId : sectionId,
        'source': 'principal_attendance',
      },
    );
  }

  List<AttendanceSessionModel> get _exceptions => _sessions
      .where(
        (session) =>
            _isIncompleteSession(session) ||
            (_effectiveTotalStudents(session) > 0 &&
                _effectivePresentCount(session) /
                        _effectiveTotalStudents(session) <
                    0.75),
      )
      .toList();

  int get _presentStudentsToday => _sessions.fold(
    0,
    (sum, session) => sum + _effectivePresentCount(session),
  );

  int get _markedStudentsToday => _sessions.fold(
    0,
    (sum, session) => sum + _effectiveMarkedCount(session),
  );

  int get _expectedStudentsToday => _sessions.fold(
    0,
    (sum, session) => sum + _effectiveTotalStudents(session),
  );

  int _effectivePresentCount(AttendanceSessionModel session) {
    final counts = _sessionStatusCounts(session);
    return counts['present']! + counts['late']!;
  }

  int _effectiveMarkedCount(AttendanceSessionModel session) {
    if (session.studentAttendances.isNotEmpty) {
      return session.studentAttendances.where((row) {
        final status = _text(row['status']).toLowerCase().replaceAll('-', '_');
        return status.isNotEmpty && status != 'unmarked';
      }).length;
    }
    return session.presentCount;
  }

  int _effectiveTotalStudents(AttendanceSessionModel session) {
    if (session.totalStudents > 0) return session.totalStudents;
    if (session.studentAttendances.isNotEmpty) {
      return session.studentAttendances.length;
    }
    if (session.sectionId == _selectedSectionId && _sectionStudents.isNotEmpty) {
      return _sectionStudents.length;
    }
    return 0;
  }

  String _sectionLabel(String sectionId) {
    if (sectionId.trim().isEmpty) return 'All classes';
    for (final section in _sections) {
      if (section.id == sectionId) {
        final grade = section.gradeName.trim();
        final name = section.sectionName.trim();
        if (grade.isEmpty && name.isEmpty) return section.id;
        if (grade.isEmpty) return 'Section $name';
        if (name.isEmpty) return grade;
        return '$grade - $name';
      }
    }
    return sectionId;
  }

  double _attendancePercent(AttendanceSessionModel session) {
    final total = _effectiveTotalStudents(session);
    if (total <= 0) return 0;
    return (_effectivePresentCount(session) / total) * 100;
  }

  String _sessionStatusLabel(AttendanceSessionModel session) {
    if (_isIncompleteSession(session)) return 'Incomplete';
    return switch (session.status) {
      'submitted' => 'Submitted',
      'draft' => 'Draft',
      'reopened' => 'Reopened',
      'needs_review' => 'Needs Review',
      'corrected' => 'Corrected',
      'not_started' => 'Not Started',
      _ => session.totalStudents > 0 ? 'Submitted' : 'Not Started',
    };
  }

  Color _sessionStatusColor(AttendanceSessionModel session) {
    if (_isIncompleteSession(session)) return context.appTheme.warning;
    return switch (session.status) {
      'submitted' => context.appTheme.success,
      'corrected' => context.appTheme.success,
      'draft' => context.appTheme.warning,
      'reopened' => context.appTheme.warning,
      'needs_review' => context.appTheme.error,
      _ =>
        session.totalStudents > 0
            ? context.appTheme.success
            : context.appTheme.warning,
    };
  }

  bool _isIncompleteSession(AttendanceSessionModel session) {
    final total = _effectiveTotalStudents(session);
    if (total == 0 ||
        session.status == 'draft' ||
        session.status == 'reopened' ||
        session.status == 'needs_review') {
      return true;
    }
    return _effectiveMarkedCount(session) < total;
  }

  int _unmarkedCount(AttendanceSessionModel session) {
    final total = _effectiveTotalStudents(session);
    if (session.studentAttendances.isEmpty) {
      return (total - _effectiveMarkedCount(session)).clamp(0, total);
    }
    return session.studentAttendances.where((row) {
      final status = _text(row['status']).toLowerCase().replaceAll('-', '_');
      return status == 'unmarked' || status.isEmpty;
    }).length;
  }

  Map<String, int> _sessionStatusCounts(AttendanceSessionModel session) {
    final counts = {
      'present': 0,
      'absent': 0,
      'late': 0,
      'leave': 0,
      'half_day': 0,
    };
    for (final row in session.studentAttendances) {
      final status = _text(row['status']).toLowerCase().replaceAll('-', '_');
      if (counts.containsKey(status)) counts[status] = counts[status]! + 1;
    }
    if (session.studentAttendances.isEmpty) {
      counts['present'] = session.presentCount;
      final total = _effectiveTotalStudents(session);
      counts['absent'] = (total - _effectivePresentCount(session)).clamp(
        0,
        total,
      );
    }
    return counts;
  }

  String _staffLabel(String staffId) {
    for (final staff in _staff) {
      if (staff.id == staffId) {
        final name = '${staff.firstName} ${staff.lastName}'.trim();
        return name.isEmpty ? staffId : name;
      }
    }
    return staffId;
  }

  String _sessionStaffLabel(AttendanceSessionModel session) {
    if (session.staffName.trim().isNotEmpty) return session.staffName.trim();
    return _staffLabel(session.staffId);
  }

  String _sessionSubjectLabel(AttendanceSessionModel session) {
    if (session.subjectName.trim().isNotEmpty) {
      return session.subjectName.trim();
    }
    return session.subjectId;
  }

  String _auditTrailSummary(AttendanceSessionModel session) {
    final parts = <String>[
      'Status ${_sessionStatusLabel(session)}',
      if (session.submittedAt.isNotEmpty)
        'Submitted ${_dateOnly(session.submittedAt)}',
      if (session.reopenedAt.isNotEmpty)
        'Reopened ${_dateOnly(session.reopenedAt)}',
      if (session.correctedAt.isNotEmpty)
        'Corrected ${_dateOnly(session.correctedAt)}',
    ];
    return parts.join(' | ');
  }

  String _dateOnly(String value) {
    final text = value.trim();
    if (text.isEmpty) return _todayText;
    return text.split('T').first;
  }

  String _widgetText(Widget widget) => widget.toStringDeep().toLowerCase();

  void _showSnack(String message, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success
            ? context.appTheme.success
            : context.appTheme.error,
      ),
    );
  }

  static String _text(Object? value, {String fallback = ''}) {
    final text = '${value ?? ''}'.trim();
    return text.isEmpty || text == 'null' ? fallback : text;
  }
}

class _AttendanceSectionSummary {
  final String sectionId;
  final String label;

  const _AttendanceSectionSummary(this.sectionId, this.label);
}
