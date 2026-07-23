import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:schooldesk1/core/constants/app_constants.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/services/pdf_service.dart';
import 'package:schooldesk1/core/services/share_export_service.dart';
import 'package:schooldesk1/core/utils/extensions.dart';
import 'package:schooldesk1/routes/app_routes.dart';

enum _AttendanceView { staff, students, classes, monitor, reports }

class PrincipalAttendanceScreen extends StatefulWidget {
  const PrincipalAttendanceScreen({super.key});

  @override
  State<PrincipalAttendanceScreen> createState() =>
      _PrincipalAttendanceScreenState();
}

class _PrincipalAttendanceScreenState extends State<PrincipalAttendanceScreen> {
  bool _loading = true;
  bool _detailLoading = false;
  bool _exporting = false;
  String? _error;
  String _search = '';
  _AttendanceView _view = _AttendanceView.staff;
  String _selectedSectionId = '';
  String _selectedStudentId = '';
  DateTime _selectedDate = DateTime.now();
  late final PageController _pageController;
  Timer? _staffAttendancePollingTimer;

  List<StaffAttendanceModel> _staffAttendance = [];
  List<StaffAttendanceModel> _monthlyStaffAttendance = [];
  List<StaffModel> _staff = [];
  Map<String, dynamic> _staffDailySummary = const {};
  List<SectionModel> _sections = [];
  List<AttendanceSessionModel> _sessions = [];
  List<AttendanceSessionModel> _monthlySessions = [];
  List<StudentModel> _sectionStudents = [];
  List<Map<String, dynamic>> _studentAttendanceRecords = [];
  final Map<String, List<StudentModel>> _studentsBySection = {};
  final Map<String, List<Map<String, dynamic>>> _recordsByStudent = {};

  String get _todayText => DateFormat('yyyy-MM-dd').format(DateTime.now());
  String get _selectedDateText =>
      DateFormat('yyyy-MM-dd').format(_selectedDate);
  bool get _isViewingToday => _selectedDateText == _todayText;
  DateTime get _monthStart => DateTime(_selectedDate.year, _selectedDate.month);
  DateTime get _monthEnd =>
      DateTime(_selectedDate.year, _selectedDate.month + 1, 0);
  String get _monthStartText => DateFormat('yyyy-MM-dd').format(_monthStart);
  String get _monthEndText => DateFormat('yyyy-MM-dd').format(_monthEnd);

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _load();
    _startStaffAttendancePolling();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _staffAttendancePollingTimer?.cancel();
    super.dispose();
  }

  void _startStaffAttendancePolling() {
    _staffAttendancePollingTimer?.cancel();
    _staffAttendancePollingTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _pollStaffAttendance(),
    );
  }

  Future<void> _pollStaffAttendance() async {
    if (!_isViewingToday) return;
    try {
      final results = await Future.wait<Object>([
        BackendApiClient.instance.getStaffAttendanceForDate(
          date: _selectedDateText,
        ),
        BackendApiClient.instance.getStaffDailyAttendanceSummary(
          date: _selectedDateText,
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _staffAttendance = results[0] as List<StaffAttendanceModel>;
        _staffDailySummary = results[1] as Map<String, dynamic>;
      });
    } on Object {
      // Silently ignore polling errors
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = BackendApiClient.instance;
      final results = await Future.wait<Object>([
        api.getStaffAttendanceForDate(date: _selectedDateText),
        api.getStaffAttendanceForDate(
          startDate: _monthStartText,
          endDate: _monthEndText,
        ),
        api.getStaff(page: 1, pageSize: 500, status: 'active'),
        api.getSections(),
        api.getAttendanceSessions(date: _selectedDateText),
        api.getAttendanceSessions(
          startDate: _monthStartText,
          endDate: _monthEndText,
        ),
        api.getStaffDailyAttendanceSummary(date: _selectedDateText),
      ]);
      final sections = results[3] as List<SectionModel>;
      if (!mounted) return;
      setState(() {
        _staffAttendance = results[0] as List<StaffAttendanceModel>;
        _monthlyStaffAttendance = results[1] as List<StaffAttendanceModel>;
        _staff = (results[2] as PaginatedList<StaffModel>).data;
        _sections = sections;
        _sessions = results[4] as List<AttendanceSessionModel>;
        _monthlySessions = results[5] as List<AttendanceSessionModel>;
        _staffDailySummary = results[6] as Map<String, dynamic>;
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
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load attendance dashboard. $error';
        _loading = false;
      });
    }
  }

  Future<void> _loadSectionStudents(String sectionId) async {
    final cached = _studentsBySection[sectionId];
    if (cached != null) {
      setState(() {
        _sectionStudents = cached;
        _selectedStudentId =
            _selectedStudentId.isNotEmpty &&
                cached.any((student) => student.id == _selectedStudentId)
            ? _selectedStudentId
            : (cached.isEmpty ? '' : cached.first.id);
      });
      await _loadRecordsForStudents(cached);
      return;
    }
    setState(() => _detailLoading = true);
    try {
      final response = await BackendApiClient.instance.getStudents(
        sectionId: sectionId,
        page: 1,
        pageSize: 120,
      );
      if (!mounted) return;
      setState(() {
        _studentsBySection[sectionId] = response.data;
        _sectionStudents = response.data;
        _selectedStudentId =
            _selectedStudentId.isNotEmpty &&
                response.data.any((student) => student.id == _selectedStudentId)
            ? _selectedStudentId
            : (response.data.isEmpty ? '' : response.data.first.id);
        _detailLoading = false;
      });
      await _loadRecordsForStudents(response.data);
    } on Object catch (error) {
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
            month: _selectedDate.month,
            year: _selectedDate.year,
          );
      if (!mounted) return;
      setState(() {
        _recordsByStudent[studentId] = records;
        _studentAttendanceRecords = records;
        _detailLoading = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _studentAttendanceRecords = const [];
        _detailLoading = false;
      });
      _showSnack('Student attendance records unavailable: $error');
    }
  }

  Future<void> _loadRecordsForStudents(List<StudentModel> students) async {
    final missing = students
        .where((student) => !_recordsByStudent.containsKey(student.id))
        .take(30)
        .toList();
    if (missing.isEmpty) return;
    final results = await Future.wait(
      missing.map((student) async {
        try {
          final records = await BackendApiClient.instance
              .getStudentAttendanceRecords(
                student.id,
                month: _selectedDate.month,
                year: _selectedDate.year,
              );
          return _StudentRecordLoad.success(student.id, records);
        } on Object catch (error) {
          return _StudentRecordLoad.failure(student.id, error);
        }
      }),
    );
    if (!mounted) return;
    final failures = results.where((result) => result.error != null).toList();
    setState(() {
      for (final result in results.where((result) => result.error == null)) {
        _recordsByStudent[result.studentId] = result.records;
      }
    });
    if (failures.isNotEmpty) {
      _showSnack(
        '${failures.length} student attendance row${failures.length == 1 ? '' : 's'} could not be loaded.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _setView(_AttendanceView.staff);
      },
      child: Scaffold(
        backgroundColor: context.appTheme.background,
        body: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? _errorView()
              : Column(
                  children: [
                    _topBar(),
                    _modePicker(),
                    _dateNavigator(),
                    Expanded(child: _viewPage(_activePrincipalView())),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _activePrincipalView() {
    return _view == _AttendanceView.staff ? _staffView() : _studentsView();
  }

  Widget _viewPage(Widget child) {
    return RefreshIndicator(
      onRefresh: _load,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(child: child),
          const SliverToBoxAdapter(child: SizedBox(height: 88)),
        ],
      ),
    );
  }

  Widget _errorView() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(22),
      children: [
        _topBar(),
        const SizedBox(height: 32),
        _SoftCard(
          child: Column(
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                color: Color(0xFFEF4444),
                size: 36,
              ),
              const SizedBox(height: 12),
              const Text(
                'Attendance data unavailable',
                style: _UiText.title,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: _UiText.caption,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_screenTitle, style: _UiText.headline),
                Text(
                  _screenSubtitle,
                  style: GoogleFonts.dmSans(
                    fontSize: 12.5,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF667085),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'Manage class setup',
            onPressed: _openClassHubSetup,
            icon: const Icon(Icons.tune_rounded),
          ),
        ],
      ),
    );
  }

  void _openClassHubSetup() {
    Navigator.of(context).pushNamed(
      AppRoutes.principalClasses,
      arguments: {
        'source': 'principal_attendance',
        'action': 'manage_attendance_setup',
        'sectionId': _selectedSectionId,
        'selectedStep': 0,
        'classId': _selectedSectionId,
      },
    );
  }

  String get _screenTitle {
    return switch (_view) {
      _AttendanceView.staff => 'Attendance',
      _AttendanceView.classes => 'Student Attendance Monitor',
      _AttendanceView.monitor => 'Monitor',
      _AttendanceView.students => 'Student Attendance',
      _AttendanceView.reports => 'Reports',
    };
  }

  String get _screenSubtitle {
    return switch (_view) {
      _AttendanceView.staff => 'Select staff or student attendance',
      _AttendanceView.classes => 'Welcome back, Principal',
      _AttendanceView.monitor => 'Class registers and correction review',
      _AttendanceView.students => 'Choose a class to inspect marked students',
      _AttendanceView.reports => 'Attendance insights and exports',
    };
  }

  Widget _modePicker() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _ModeCard(
                  icon: Icons.badge_outlined,
                  title: 'Staff Attendance',
                  subtitle:
                      '${_summaryCount('checked_in', _staffAttendance.where((row) => row.checkedIn).length)}/${_summaryCount('expected_staff', _staff.length)} checked in',
                  selected: _view == _AttendanceView.staff,
                  onTap: () => _setView(_AttendanceView.staff),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ModeCard(
                  icon: Icons.groups_2_outlined,
                  title: 'Student Attendance',
                  subtitle: _selectedSectionId.isEmpty
                      ? 'Select a class'
                      : _sectionLabel(_selectedSectionId),
                  selected: _view == _AttendanceView.students,
                  onTap: () => _setView(_AttendanceView.students),
                ),
              ),
            ],
          ),
          if (_view == _AttendanceView.students) ...[
            const SizedBox(height: 14),
            _SearchBox(
              hint: 'Search by name or admission no.',
              onChanged: (value) => setState(() => _search = value),
            ),
          ],
        ],
      ),
    );
  }

  void _setView(_AttendanceView view) {
    setState(() => _view = view);
  }

  Widget _dateNavigator() {
    final dateLabel = DateFormat('EEE, dd MMM yyyy').format(_selectedDate);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: _SoftCard(
        color: const Color(0xFFEAF5FF),
        child: Row(
          children: [
            const _IconBubble(
              icon: Icons.calendar_month_rounded,
              color: Color(0xFF1976E8),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isViewingToday
                        ? 'Reviewing today'
                        : 'Reviewing $dateLabel',
                    style: _UiText.title,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${DateFormat('MMMM yyyy').format(_selectedDate)} archive is available below.',
                    style: _UiText.caption,
                  ),
                ],
              ),
            ),
            if (!_isViewingToday)
              TextButton(onPressed: _showToday, child: const Text('Today')),
            IconButton(
              tooltip: 'Choose attendance date',
              onPressed: _chooseAttendanceDate,
              icon: const Icon(Icons.edit_calendar_rounded),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showToday() => _setAttendanceDate(DateTime.now());

  Future<void> _chooseAttendanceDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      helpText: 'Review attendance by date',
    );
    if (picked != null) await _setAttendanceDate(picked);
  }

  Future<void> _setAttendanceDate(DateTime date) async {
    final normalized = DateTime(date.year, date.month, date.day);
    final monthChanged =
        normalized.year != _selectedDate.year ||
        normalized.month != _selectedDate.month;
    setState(() {
      _selectedDate = normalized;
      if (monthChanged) {
        _recordsByStudent.clear();
        _studentAttendanceRecords = const [];
      }
    });
    await _load();
  }

  Widget _staffView() {
    final attendanceByStaffId = {
      for (final row in _staffAttendance) row.staffId: row,
    };
    final rows = _staff;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Staff Attendance Record', action: _selectedDateText),
          const SizedBox(height: 12),
          _SoftCard(
            child: Row(
              children: [
                const _IconBubble(
                  icon: Icons.verified_rounded,
                  color: Color(0xFF24A765),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${_summaryCount('checked_in', _staffAttendance.where((row) => row.checkedIn).length)} checked in · ${_summaryCount('checked_out', _staffAttendance.where((row) => row.checkOut != null).length)} checked out\n${_summaryCount('currently_on_site', _staffAttendance.where((row) => row.checkedIn && row.checkOut == null).length)} on-site · ${_summaryCount('pending', (_staff.length - _staffAttendance.where((row) => row.checkedIn).length).clamp(0, _staff.length))} pending',
                    style: _UiText.title,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (rows.isEmpty)
            const _SoftCard(child: _EmptyLine('No staff records found.'))
          else
            for (final staff in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _SoftCard(
                  child: _StaffAttendanceRow(
                    staff: staff,
                    attendance: attendanceByStaffId[staff.id],
                  ),
                ),
              ),
          const SizedBox(height: 8),
          _monthlyStaffArchive(),
        ],
      ),
    );
  }

  int _summaryCount(String key, int fallback) {
    final value = _staffDailySummary[key];
    return value is num ? value.toInt() : fallback;
  }

  Widget _monthlyStaffArchive() {
    final byDate = <String, List<StaffAttendanceModel>>{};
    for (final row in _monthlyStaffAttendance) {
      final date = row.date == null
          ? ''
          : DateFormat('yyyy-MM-dd').format(row.date!.toLocal());
      if (date.isEmpty) continue;
      byDate.putIfAbsent(date, () => []).add(row);
    }
    final dates = byDate.keys.toList()..sort((a, b) => b.compareTo(a));
    return _SoftCard(
      padding: EdgeInsets.zero,
      child: ExpansionTile(
        leading: const _IconBubble(
          icon: Icons.inventory_2_outlined,
          color: Color(0xFF6557E8),
        ),
        title: Text(
          '${DateFormat('MMMM').format(_selectedDate)} staff archive',
          style: _UiText.title,
        ),
        subtitle: Text(
          '${_monthlyStaffAttendance.length} check-in${_monthlyStaffAttendance.length == 1 ? '' : 's'} this month',
          style: _UiText.caption,
        ),
        children: dates.isEmpty
            ? const [
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: _EmptyLine('No staff check-ins for this month.'),
                ),
              ]
            : dates.map((date) {
                final rows = byDate[date] ?? const [];
                final checkedIn = rows.where((row) => row.checkedIn).length;
                return ListTile(
                  leading: const Icon(Icons.event_available_rounded),
                  title: Text(
                    DateFormat('EEE, dd MMM').format(DateTime.parse(date)),
                  ),
                  subtitle: Text(
                    '$checkedIn staff check-in${checkedIn == 1 ? '' : 's'}',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _setAttendanceDate(DateTime.parse(date)),
                );
              }).toList(),
      ),
    );
  }

  // ignore: unused_element
  Widget _classesDashboard() {
    final recent = _filteredStudents.take(4).toList();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Today at a glance', action: 'View all'),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 0.9,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            children: [
              _MetricTile(
                icon: Icons.calendar_month_rounded,
                value: '${_sessions.length}',
                label: 'Sessions\nToday',
                color: const Color(0xFF1976E8),
                tone: const Color(0xFFEAF3FF),
              ),
              _MetricTile(
                icon: Icons.check_circle_outline_rounded,
                value: '$_presentStudentsToday',
                label: 'Present\nToday',
                color: const Color(0xFF24A765),
                tone: const Color(0xFFEAFBF2),
              ),
              _MetricTile(
                icon: Icons.groups_2_outlined,
                value: '$_markedStudentsToday/$_expectedStudentsToday',
                label: 'Marked\nToday',
                color: const Color(0xFF10A7A7),
                tone: const Color(0xFFE7FBFA),
              ),
            ],
          ),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.9,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            children: [
              _MetricTile(
                icon: Icons.badge_outlined,
                value:
                    '${_staffAttendance.where((row) => row.checkedIn).length}/${_staff.length}',
                label: 'Staff Check-in\nMonitor',
                color: const Color(0xFF6557E8),
                tone: const Color(0xFFF0EEFF),
                compact: true,
              ),
              _MetricTile(
                icon: Icons.warning_amber_rounded,
                value: '${_exceptions.length}',
                label: 'Exceptions',
                color: const Color(0xFFF59E0B),
                tone: const Color(0xFFFFF5E5),
                compact: true,
              ),
            ],
          ),
          const SizedBox(height: 24),
          _sectionHeader('Recent Students', action: 'View all'),
          const SizedBox(height: 12),
          _SoftCard(
            padding: EdgeInsets.zero,
            child: recent.isEmpty
                ? const _EmptyLine('No students loaded for selected class.')
                : Column(
                    children: [
                      for (var i = 0; i < recent.length; i++)
                        _StudentRow(
                          student: recent[i],
                          sectionLabel: _sectionLabel(
                            recent[i].currentSectionId ?? _selectedSectionId,
                          ),
                          percent: recent[i].attendancePercent,
                          statusLabel: _studentStatusLabel(recent[i].id),
                          statusColor: _studentStatusColor(recent[i].id),
                          onTap: () => _openStudent(recent[i]),
                          showDivider: i != recent.length - 1,
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _monitorView() {
    final sessions = _filteredSessions;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Class Registers', action: _selectedDateText),
          const SizedBox(height: 12),
          if (sessions.isEmpty)
            const _SoftCard(
              child: _EmptyLine('No sessions found for this date.'),
            )
          else
            for (final session in sessions)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _SoftCard(
                  child: Row(
                    children: [
                      _IconBubble(
                        icon: _isIncompleteSession(session)
                            ? Icons.pending_actions_rounded
                            : Icons.fact_check_rounded,
                        color: _sessionStatusColor(session),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _sectionLabel(session.sectionId),
                              style: _UiText.title,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_sessionStaffLabel(session)} · ${_attendancePercent(session).toStringAsFixed(0)}%',
                              style: _UiText.caption,
                            ),
                          ],
                        ),
                      ),
                      _StatusPill(
                        label: _sessionStatusLabel(session),
                        color: _sessionStatusColor(session),
                      ),
                      IconButton(
                        onPressed: () => _openSessionDetail(session),
                        icon: const Icon(Icons.chevron_right_rounded),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Widget _studentsView() {
    final students = _filteredStudents;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            value: _selectedSectionId.isEmpty ? null : _selectedSectionId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Select Class',
              prefixIcon: Icon(Icons.class_rounded),
              border: OutlineInputBorder(),
            ),
            items: _sections
                .map(
                  (section) => DropdownMenuItem(
                    value: section.id,
                    child: Text(_sectionLabel(section.id)),
                  ),
                )
                .toList(),
            onChanged: (value) async {
              if (value == null || value == _selectedSectionId) return;
              setState(() => _selectedSectionId = value);
              await _loadSectionStudents(value);
            },
          ),
          const SizedBox(height: 16),
          _sectionHeader(
            _selectedSectionId.isEmpty
                ? 'Select a class'
                : '${_sectionLabel(_selectedSectionId)} Students',
            action: '${students.length}',
          ),
          const SizedBox(height: 12),
          if (_selectedSectionId.isEmpty)
            const _SoftCard(
              child: _EmptyLine('Choose a class to see student attendance.'),
            )
          else if (_detailLoading)
            const _SoftCard(child: _EmptyLine('Loading students...'))
          else if (students.isEmpty)
            const _SoftCard(child: _EmptyLine('No students found.'))
          else ...[
            _SoftCard(
              color: const Color(0xFFEAF5FF),
              child: Row(
                children: [
                  const _IconBubble(
                    icon: Icons.fact_check_rounded,
                    color: Color(0xFF1976E8),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Marked ${_isViewingToday ? 'today' : DateFormat('dd MMM').format(_selectedDate)}: $_markedStudentsToday/$_expectedStudentsToday',
                      style: _UiText.title,
                    ),
                  ),
                  _StatusPill(
                    label: '$_presentStudentsToday Present',
                    color: const Color(0xFF24A765),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            for (final student in students)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _SoftCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _StudentRow(
                        student: student,
                        sectionLabel: _sectionLabel(
                          student.currentSectionId ?? _selectedSectionId,
                        ),
                        percent: _studentAttendancePercent(student),
                        statusLabel: _studentStatusLabel(student.id),
                        statusColor: _studentStatusColor(student.id),
                        onTap: () => _openStudent(student),
                      ),
                      _StudentAttendanceMeta(
                        record: _selectedDayStudentRecord(student.id),
                        dateLabel: _recordDate,
                        timeLabel: _recordTime,
                        statusLabel: _recordStatus,
                        teacherLabel: _recordTeacher,
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 8),
            _monthlyStudentArchive(),
          ],
        ],
      ),
    );
  }

  Widget _monthlyStudentArchive() {
    final sessions = _monthlySessions
        .where(
          (session) =>
              _selectedSectionId.isEmpty ||
              session.sectionId == _selectedSectionId,
        )
        .toList();
    final byDate = <String, List<AttendanceSessionModel>>{};
    for (final session in sessions) {
      final date = session.date.trim();
      if (date.isEmpty) continue;
      byDate.putIfAbsent(date, () => []).add(session);
    }
    final dates = byDate.keys.toList()..sort((a, b) => b.compareTo(a));
    return _SoftCard(
      padding: EdgeInsets.zero,
      child: ExpansionTile(
        leading: const _IconBubble(
          icon: Icons.history_rounded,
          color: Color(0xFF10A7A7),
        ),
        title: Text(
          '${DateFormat('MMMM').format(_selectedDate)} class archive',
          style: _UiText.title,
        ),
        subtitle: Text(
          '${sessions.length} class register${sessions.length == 1 ? '' : 's'} this month',
          style: _UiText.caption,
        ),
        children: dates.isEmpty
            ? const [
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: _EmptyLine('No class registers for this month.'),
                ),
              ]
            : dates.map((date) {
                final daySessions = byDate[date] ?? const [];
                final marked = daySessions.fold<int>(
                  0,
                  (sum, session) => sum + _effectiveMarkedCount(session),
                );
                final present = daySessions.fold<int>(
                  0,
                  (sum, session) => sum + _effectivePresentCount(session),
                );
                final isComplete = daySessions.every(
                  (session) => !_isIncompleteSession(session),
                );
                return ListTile(
                  leading: Icon(
                    isComplete
                        ? Icons.fact_check_rounded
                        : Icons.pending_actions_rounded,
                    color: isComplete
                        ? const Color(0xFF24A765)
                        : const Color(0xFFF59E0B),
                  ),
                  title: Text(
                    DateFormat('EEE, dd MMM').format(DateTime.parse(date)),
                  ),
                  subtitle: Text(
                    '${daySessions.length} register${daySessions.length == 1 ? '' : 's'} · $present present · $marked marked',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _setAttendanceDate(DateTime.parse(date)),
                );
              }).toList(),
      ),
    );
  }

  // ignore: unused_element
  Widget _reportsView() {
    final reports = [
      _ReportItem(
        'Daily Attendance Report',
        'View class-wise attendance for today',
        Icons.calendar_month_rounded,
        const Color(0xFF1976E8),
        () => _openReportDetail('Daily Attendance Report', 'pdf'),
      ),
      _ReportItem(
        'Class Attendance Report',
        'Detailed report for a specific class',
        Icons.assignment_rounded,
        const Color(0xFF6557E8),
        () => _openReportDetail('Class Attendance Report', 'csv'),
      ),
      _ReportItem(
        'Daily Summary',
        'Overall attendance summary for today',
        Icons.summarize_rounded,
        const Color(0xFF13B8A6),
        () => _openReportDetail('Daily Summary', 'pdf'),
      ),
      _ReportItem(
        'Exceptions Report',
        'Students with attendance issues',
        Icons.warning_amber_rounded,
        const Color(0xFFF97316),
        () => _openReportDetail('Exceptions Report', 'csv'),
      ),
      _ReportItem(
        'Staff Check-in Report',
        'View staff check-in activity',
        Icons.badge_rounded,
        const Color(0xFF8B5CF6),
        () => _openReportDetail('Staff Check-in Report', 'pdf'),
      ),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SoftCard(
            color: Color(0xFFEAF5FF),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Attendance Insights', style: _UiText.title),
                      SizedBox(height: 8),
                      Text(
                        'Get complete attendance reports and analytics for your school.',
                        style: _UiText.caption,
                      ),
                    ],
                  ),
                ),
                _IconBubble(
                  icon: Icons.analytics_outlined,
                  color: Color(0xFF1976E8),
                  large: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const Text('Daily Reports', style: _UiText.section),
          const SizedBox(height: 12),
          for (final item in reports)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ReportRow(item: item),
            ),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _exporting
                  ? null
                  : () => _exportAttendanceReport('Attendance Summary', 'pdf'),
              icon: const Icon(Icons.ios_share_rounded),
              label: Text(
                _exporting ? 'Preparing...' : 'Export / Share Reports',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, {String action = ''}) {
    return Row(
      children: [
        Expanded(child: Text(title, style: _UiText.section)),
        if (action.isNotEmpty) Text(action, style: _UiText.link),
      ],
    );
  }

  // ignore: unused_element
  Widget _bottomBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFEAF0F7))),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _BottomItem(
                icon: Icons.home_rounded,
                label: 'Classes',
                selected: _view == _AttendanceView.classes,
                onTap: () => _setView(_AttendanceView.classes),
              ),
              _BottomItem(
                icon: Icons.groups_2_outlined,
                label: 'Students',
                selected: _view == _AttendanceView.students,
                onTap: () => _setView(_AttendanceView.students),
              ),
              _BottomItem(
                icon: Icons.fact_check_outlined,
                label: 'Monitor',
                selected: _view == _AttendanceView.monitor,
                onTap: () => _setView(_AttendanceView.monitor),
              ),
              _BottomItem(
                icon: Icons.summarize_outlined,
                label: 'Reports',
                selected: _view == _AttendanceView.reports,
                onTap: () => _setView(_AttendanceView.reports),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openStudent(StudentModel student) async {
    if (_recordsByStudent.containsKey(student.id)) {
      _studentAttendanceRecords = _recordsByStudent[student.id] ?? const [];
    } else {
      await _loadStudentAttendance(student.id);
    }
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => _StudentDetailPage(
          student: student,
          sectionLabel: _sectionLabel(student.currentSectionId ?? ''),
          statusLabel: _studentStatusLabel(student.id),
          statusColor: _studentStatusColor(student.id),
          records: _studentAttendanceRecords,
          staffDirectory: _staff,
          onReopen: _sessions.isEmpty
              ? null
              : () => _openSessionDetail(_sessions.first),
        ),
      ),
    );
  }

  Future<void> _openSessionDetail(AttendanceSessionModel session) async {
    final reason = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_sectionLabel(session.sectionId), style: _UiText.headline),
            const SizedBox(height: 8),
            Text(
              '${_sessionStaffLabel(session)} · ${_sessionStatusLabel(session)} · ${_attendancePercent(session).toStringAsFixed(0)}%',
              style: _UiText.caption,
            ),
            const SizedBox(height: 18),
            ListTile(
              leading: const Icon(Icons.lock_open_rounded),
              title: const Text('Reopen Attendance'),
              subtitle: const Text('Allow the teacher to submit a correction'),
              onTap: () async {
                final entered = await _promptReason('Reopen Attendance');
                if (!mounted) return;
                Navigator.pop(context, entered);
              },
            ),
            ListTile(
              leading: const Icon(Icons.notifications_active_outlined),
              title: const Text('Send Reminder'),
              subtitle: Text('Notify ${_sessionStaffLabel(session)}'),
              onTap: () {
                Navigator.pop(context);
                _showSnack(
                  'Reminder queued for ${_sessionStaffLabel(session)}',
                  success: true,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.table_chart_outlined),
              title: const Text('Export Class Register'),
              subtitle: const Text('Open attendance register export'),
              onTap: () {
                Navigator.pop(context);
                _openReportDetail('Class Attendance Report', 'csv');
              },
            ),
            ListTile(
              leading: const Icon(Icons.history_rounded),
              title: const Text('Audit Trail'),
              subtitle: Text(_auditTrailSummary(session)),
            ),
          ],
        ),
      ),
    );
    if (reason == null || reason.trim().isEmpty) return;
    try {
      await BackendApiClient.instance.reopenAttendanceSession(
        session.id,
        reason: reason.trim(),
      );
      if (!mounted) return;
      _showSnack('Attendance reopened', success: true);
      await _load();
    } on Object catch (error) {
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

  Future<void> _openReportDetail(String title, String format) async {
    await _exportAttendanceReport(title, format);
  }

  Future<void> _exportAttendanceReport(String title, String format) async {
    if (_exporting) return;
    setState(() => _exporting = true);
    final normalizedFormat = format == 'zip' ? 'pdf' : format.toLowerCase();
    try {
      final rows = _studentReportRows();
      final export = await BackendApiClient.instance.createReportExport(
        '/attendance/reports/exports',
        reportTitle: title,
        format: normalizedFormat == 'csv' ? 'csv' : 'pdf',
        reportType: 'attendance',
        scope: 'principal_attendance',
        parameters: {
          'section_id': _selectedSectionId,
          'date': _selectedDateText,
          'student_count': rows.length,
          'sessions': _sessions.length,
        },
      );
      if (normalizedFormat == 'csv') {
        final bytes = Uint8List.fromList(utf8.encode(_attendanceCsv()));
        await const ShareExportService().shareBytes(
          bytes: bytes,
          fileName:
              'attendance_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv',
          mimeType: 'text/csv',
          title: title,
          subject: title,
          text: 'Attendance export generated from ${AppConstants.appName}.',
          context: context,
        );
      } else {
        final bytes = await PdfService.getInstance().generateAttendanceReport(
          className: _sectionLabel(_selectedSectionId),
          month: DateFormat('dd MMM yyyy').format(_selectedDate),
          students: rows,
          schoolName: AppConstants.appName,
        );
        if (!mounted) return;
        await PdfService.getInstance().previewDocument(context, bytes, title);
      }
      if (!mounted) return;
      _showSnack(
        'Export ready${_text(export['download_url']).isEmpty ? '' : ': ${export['download_url']}'}',
        success: true,
      );
    } on Object catch (error) {
      _showSnack('Unable to export report: $error');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  List<StudentModel> get _filteredStudents {
    final query = _search.trim().toLowerCase();
    return _sectionStudents.where((student) {
      final inSection =
          _selectedSectionId.isEmpty ||
          student.currentSectionId == null ||
          student.currentSectionId == _selectedSectionId;
      if (!inSection) return false;
      if (query.isEmpty) return true;
      final haystack =
          '${student.fullName} ${student.admissionNumber} ${student.studentCode} ${_sectionLabel(student.currentSectionId ?? '')}'
              .toLowerCase();
      return haystack.contains(query);
    }).toList();
  }

  Map<String, dynamic>? _selectedDayStudentRecord(String studentId) {
    final records = (_recordsByStudent[studentId] ?? const [])
        .where((row) => _recordDate(row) == _selectedDateText)
        .toList();
    if (records.isEmpty) return null;
    records.sort((a, b) => _recordDateTime(b).compareTo(_recordDateTime(a)));
    return records.first;
  }

  DateTime _recordDateTime(Map<String, dynamic> row) {
    final marked = DateTime.tryParse(
      _text(row['marked_at'] ?? row['created_at'] ?? row['updated_at']),
    );
    if (marked != null) return marked;
    final session = row['session'] is Map
        ? Map<String, dynamic>.from(row['session'] as Map)
        : const <String, dynamic>{};
    return DateTime.tryParse(_text(session['date'])) ?? DateTime(1970);
  }

  String _recordDate(Map<String, dynamic> row) {
    final session = row['session'] is Map
        ? Map<String, dynamic>.from(row['session'] as Map)
        : const <String, dynamic>{};
    final raw = _text(session['date'], fallback: _text(row['date']));
    if (raw.isEmpty) {
      return _dateOnly(
        _text(row['marked_at'] ?? row['created_at'] ?? row['updated_at']),
      );
    }
    return raw.split('T').first;
  }

  String _recordTime(Map<String, dynamic> row) {
    final markedAt = DateTime.tryParse(
      _text(row['marked_at'] ?? row['created_at'] ?? row['updated_at']),
    );
    if (markedAt == null) return 'Time not recorded';
    return DateFormat('hh:mm a').format(markedAt.toLocal());
  }

  String _recordTeacher(Map<String, dynamic> row) {
    return _readableAttendanceTeacherLabel(row, staffDirectory: _staff);
  }

  String _recordStatus(Map<String, dynamic> row) {
    final status = _text(
      row['status'],
      fallback: 'unmarked',
    ).replaceAll('_', ' ').trim();
    if (status.isEmpty) return 'Unmarked';
    return status[0].toUpperCase() + status.substring(1);
  }

  double _studentAttendancePercent(StudentModel student) {
    final records = _recordsByStudent[student.id] ?? const [];
    if (records.isEmpty) return student.attendancePercent;
    final present = records.where((row) {
      final status = _text(row['status']).toLowerCase();
      return status == 'present' || status == 'late';
    }).length;
    return (present / records.length) * 100;
  }

  List<Map<String, dynamic>> _studentReportRows() {
    final students = _filteredStudents.isEmpty
        ? _sectionStudents
        : _filteredStudents;
    return students.map((student) {
      final records = _recordsByStudent[student.id] ?? const [];
      final present = records.where((row) {
        final status = _text(row['status']).toLowerCase();
        return status == 'present' || status == 'late';
      }).length;
      final absent = records.where((row) {
        final status = _text(row['status']).toLowerCase();
        return status == 'absent';
      }).length;
      final total = records.length;
      final percentage = total == 0
          ? student.attendancePercent
          : (present / total) * 100;
      return {
        'name': student.fullName,
        'present': present,
        'absent': absent,
        'total': total,
        'percentage': percentage.toStringAsFixed(0),
      };
    }).toList();
  }

  String _attendanceCsv() {
    final buffer = StringBuffer(
      'student,admission,class,date,time,status,teacher,session_id\n',
    );
    for (final student in _filteredStudents) {
      final records = _recordsByStudent[student.id] ?? const [];
      if (records.isEmpty) {
        buffer.writeln(
          [
            student.fullName,
            student.admissionNumber,
            _sectionLabel(student.currentSectionId ?? _selectedSectionId),
            '',
            '',
            'No records',
            '',
            '',
          ].map(_csvCell).join(','),
        );
      }
      for (final row in records) {
        buffer.writeln(
          [
            student.fullName,
            student.admissionNumber,
            _sectionLabel(student.currentSectionId ?? _selectedSectionId),
            _recordDate(row),
            _recordTime(row),
            _recordStatus(row),
            _recordTeacher(row),
            _text(row['session_id']),
          ].map(_csvCell).join(','),
        );
      }
    }
    return buffer.toString();
  }

  String _csvCell(Object? value) {
    final text = _text(value).replaceAll('"', '""');
    return '"$text"';
  }

  List<AttendanceSessionModel> get _filteredSessions {
    final query = _search.trim().toLowerCase();
    return _sessions.where((session) {
      if (query.isEmpty) return true;
      final haystack =
          '${_sectionLabel(session.sectionId)} ${_sessionStaffLabel(session)} ${_sessionStatusLabel(session)}'
              .toLowerCase();
      return haystack.contains(query);
    }).toList();
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

  List<AttendanceSessionModel> get _selectedSectionSessions => _sessions
      .where(
        (session) =>
            _selectedSectionId.isEmpty ||
            session.sectionId == _selectedSectionId,
      )
      .toList();

  int get _presentStudentsToday => _selectedSectionSessions.fold(
    0,
    (sum, session) => sum + _effectivePresentCount(session),
  );

  int get _markedStudentsToday => _selectedSectionSessions.fold(
    0,
    (sum, session) => sum + _effectiveMarkedCount(session),
  );

  int get _expectedStudentsToday => _selectedSectionSessions.fold(
    0,
    (sum, session) => sum + _effectiveTotalStudents(session),
  );

  String _studentStatusLabel(String studentId) {
    final record = _selectedDayStudentRecord(studentId);
    if (record == null) return 'Unmarked';
    final status = _recordStatus(record);
    return status.toLowerCase() == 'unmarked' ? 'Unmarked' : status;
  }

  Color _studentStatusColor(String studentId) {
    final status = _studentStatusLabel(studentId).toLowerCase();
    if (status == 'present' || status == 'late') {
      return const Color(0xFF24A765);
    }
    if (status == 'absent') return const Color(0xFFEF4444);
    if (status == 'leave' || status == 'half day') {
      return const Color(0xFFF97316);
    }
    return const Color(0xFF94A3B8);
  }

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
    if (session.sectionId == _selectedSectionId &&
        _sectionStudents.isNotEmpty) {
      return _sectionStudents.length;
    }
    return 0;
  }

  String _sectionLabel(String sectionId) {
    if (sectionId.trim().isEmpty) return 'All Classes';
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
    if (_isIncompleteSession(session)) return const Color(0xFFF59E0B);
    return switch (session.status) {
      'submitted' => const Color(0xFF24A765),
      'corrected' => const Color(0xFF24A765),
      'draft' => const Color(0xFFF59E0B),
      'reopened' => const Color(0xFFF59E0B),
      'needs_review' => const Color(0xFFEF4444),
      _ =>
        session.totalStudents > 0
            ? const Color(0xFF24A765)
            : const Color(0xFFF59E0B),
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
    return parts.join(' · ');
  }

  String _dateOnly(String value) {
    final text = value.trim();
    if (text.isEmpty) return _selectedDateText;
    return text.split('T').first;
  }

  void _showSnack(String message, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success
            ? const Color(0xFF24A765)
            : const Color(0xFFEF4444),
      ),
    );
  }

  static String _text(Object? value, {String fallback = ''}) {
    final text = '${value ?? ''}'.trim();
    return text.isEmpty || text == 'null' ? fallback : text;
  }
}

class _StudentDetailPage extends StatelessWidget {
  final StudentModel student;
  final String sectionLabel;
  final String statusLabel;
  final Color statusColor;
  final List<Map<String, dynamic>> records;
  final List<StaffModel> staffDirectory;
  final VoidCallback? onReopen;

  const _StudentDetailPage({
    required this.student,
    required this.sectionLabel,
    required this.statusLabel,
    required this.statusColor,
    required this.records,
    this.staffDirectory = const [],
    this.onReopen,
  });

  @override
  Widget build(BuildContext context) {
    final present = records.where((row) {
      final status = _detailText(row['status']).toLowerCase();
      return status == 'present' || status == 'late';
    }).length;
    final percent = records.isEmpty
        ? student.attendancePercent
        : (present / records.length) * 100;
    return Scaffold(
      backgroundColor: context.appTheme.background,
      appBar: AppBar(
        title: Text(
          student.fullName.isEmpty ? 'Student Detail' : student.fullName,
        ),
        actions: [
          IconButton(
            onPressed: onReopen,
            icon: const Icon(Icons.more_vert_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          _SoftCard(
            child: Row(
              children: [
                _Avatar(name: student.fullName, large: true),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(student.fullName, style: _UiText.headline),
                      const SizedBox(height: 6),
                      Text(
                        'Admission ${student.admissionNumber} · $sectionLabel',
                        style: _UiText.caption,
                      ),
                    ],
                  ),
                ),
                _StatusPill(label: statusLabel, color: statusColor),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _SoftCard(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Attendance', style: _UiText.section),
                      const SizedBox(height: 8),
                      Text(
                        '${percent.toStringAsFixed(1)}%',
                        style: _UiText.big,
                      ),
                      const Text('Overall Attendance', style: _UiText.caption),
                    ],
                  ),
                ),
                SizedBox(
                  width: 72,
                  height: 72,
                  child: CircularProgressIndicator(
                    value: (percent / 100).clamp(0, 1),
                    strokeWidth: 7,
                    backgroundColor: const Color(0xFFE9EEF6),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const Text('Recent Weekdays', style: _UiText.section),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final day in _weekItems())
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _DayTile(day: day),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 22),
          const Text('Day-wise Attendance History', style: _UiText.section),
          const SizedBox(height: 12),
          _SoftCard(
            child: records.isEmpty
                ? const _EmptyLine('No recent attendance activity.')
                : Column(
                    children: [
                      for (final record in records.take(5))
                        _AttendanceHistoryLine(
                          record: record,
                          staffDirectory: staffDirectory,
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  List<_WeekDay> _weekItems() {
    final now = DateTime.now();
    final weekdays = <DateTime>[];
    var cursor = now;
    while (weekdays.length < 5) {
      if (cursor.weekday >= DateTime.monday &&
          cursor.weekday <= DateTime.friday) {
        weekdays.add(cursor);
      }
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return weekdays.reversed.map((date) {
      final key = DateFormat('yyyy-MM-dd').format(date);
      final matching = records.where((row) => _detailRecordDate(row) == key);
      final status = matching.isEmpty
          ? 'unmarked'
          : _detailText(matching.first['status'], fallback: 'unmarked');
      return _WeekDay(date: date, status: status);
    }).toList();
  }

  static String _detailRecordDate(Map<String, dynamic> row) {
    final session = row['session'] is Map
        ? Map<String, dynamic>.from(row['session'] as Map)
        : const <String, dynamic>{};
    final raw = _detailText(
      session['date'],
      fallback: _detailText(row['date']),
    );
    if (raw.isNotEmpty) return raw.split('T').first;
    return _detailText(
      row['marked_at'] ?? row['created_at'] ?? row['updated_at'],
    ).split('T').first;
  }

  static String _detailText(Object? value, {String fallback = ''}) {
    final text = '${value ?? ''}'.trim();
    return text.isEmpty || text == 'null' ? fallback : text;
  }
}

class _UiText {
  static const headline = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w800,
    color: Color(0xFF111827),
    height: 1.15,
  );
  static const title = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w800,
    color: Color(0xFF1F2937),
  );
  static const section = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w800,
    color: Color(0xFF1F2937),
  );
  static const caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: Color(0xFF6B7280),
    height: 1.35,
  );
  static const link = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w800,
    color: Color(0xFF1976E8),
  );
  static const big = TextStyle(
    fontSize: 27,
    fontWeight: FontWeight.w900,
    color: Color(0xFF111827),
  );
}

class _SoftCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;

  const _SoftCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEAF0F7)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SearchBox extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onChanged;

  const _SearchBox({required this.hint, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search_rounded),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFEAF0F7)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFEAF0F7)),
        ),
      ),
    );
  }
}

// ignore: unused_element
class _SegmentChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SegmentChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        showCheckmark: false,
        selectedColor: const Color(0xFF1976E8),
        backgroundColor: Colors.white,
        labelStyle: TextStyle(
          color: selected ? Colors.white : const Color(0xFF4B5563),
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
        side: const BorderSide(color: Color(0xFFEAF0F7)),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final Color tone;
  final bool compact;

  const _MetricTile({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    required this.tone,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tone,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.12)),
      ),
      child: compact
          ? Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(value, style: _UiText.big.copyWith(fontSize: 21)),
                      Text(label, style: _UiText.caption),
                    ],
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: color, size: 24),
                const Spacer(),
                Text(value, style: _UiText.big.copyWith(fontSize: 22)),
                const SizedBox(height: 2),
                Text(label, style: _UiText.caption),
              ],
            ),
    );
  }
}

class _StudentRow extends StatelessWidget {
  final StudentModel student;
  final String sectionLabel;
  final double percent;
  final String statusLabel;
  final Color statusColor;
  final VoidCallback onTap;
  final bool showDivider;

  const _StudentRow({
    required this.student,
    required this.sectionLabel,
    required this.percent,
    required this.statusLabel,
    required this.statusColor,
    required this.onTap,
    this.showDivider = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _Avatar(name: student.fullName),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(student.fullName, style: _UiText.title),
                      const SizedBox(height: 4),
                      Text(
                        'Adm ${student.admissionNumber} · $sectionLabel',
                        style: _UiText.caption,
                      ),
                    ],
                  ),
                ),
                _StatusPill(label: statusLabel, color: statusColor),
                const SizedBox(width: 10),
                Text('${percent.toStringAsFixed(0)}%', style: _UiText.caption),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF94A3B8),
                ),
              ],
            ),
          ),
          if (showDivider)
            const Divider(height: 1, indent: 62, color: Color(0xFFEAF0F7)),
        ],
      ),
    );
  }
}

class _StudentAttendanceMeta extends StatelessWidget {
  final Map<String, dynamic>? record;
  final String Function(Map<String, dynamic>) dateLabel;
  final String Function(Map<String, dynamic>) timeLabel;
  final String Function(Map<String, dynamic>) statusLabel;
  final String Function(Map<String, dynamic>) teacherLabel;

  const _StudentAttendanceMeta({
    required this.record,
    required this.dateLabel,
    required this.timeLabel,
    required this.statusLabel,
    required this.teacherLabel,
  });

  @override
  Widget build(BuildContext context) {
    final row = record;
    final text = row == null
        ? 'No attendance marked yet'
        : '${dateLabel(row)} · ${timeLabel(row)} · ${statusLabel(row)} · ${teacherLabel(row)}';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(62, 0, 12, 12),
      child: Text(text, style: _UiText.caption),
    );
  }
}

String _readableAttendanceTeacherLabel(
  Map<String, dynamic> row, {
  List<StaffModel> staffDirectory = const [],
}) {
  final nestedName = _attendanceStaffNameFromMap(row['staff']);
  if (nestedName.isNotEmpty) return nestedName;

  final session = row['session'] is Map
      ? Map<String, dynamic>.from(row['session'] as Map)
      : const <String, dynamic>{};
  final sessionStaffName = _attendanceStaffNameFromMap(session['staff']);
  if (sessionStaffName.isNotEmpty) return sessionStaffName;

  final marker = _attendanceLabelText(row['marked_by']);
  if (marker.isNotEmpty && !_looksLikeIdentifier(marker)) return marker;

  final candidateIds = [
    marker,
    _attendanceLabelText(row['marked_by_id']),
    _attendanceLabelText(row['staff_id']),
    _attendanceLabelText(row['teacher_id']),
    _attendanceLabelText(session['staff_id']),
  ].where((value) => value.isNotEmpty);

  for (final candidateId in candidateIds) {
    for (final staff in staffDirectory) {
      if (staff.id == candidateId || staff.staffCode == candidateId) {
        final name = staff.fullName.trim();
        if (name.isNotEmpty) return name;
      }
    }
  }

  return 'Teacher';
}

String _attendanceStaffNameFromMap(Object? value) {
  if (value is! Map) return '';
  final map = Map<String, dynamic>.from(value);
  final direct = _attendanceLabelText(map['full_name'] ?? map['name']);
  if (direct.isNotEmpty) return direct;
  return [
    map['first_name'],
    map['last_name'],
  ].map(_attendanceLabelText).where((part) => part.isNotEmpty).join(' ');
}

String _attendanceLabelText(Object? value) {
  final text = '${value ?? ''}'.trim();
  return text.isEmpty || text == 'null' ? '' : text;
}

bool _looksLikeIdentifier(String value) {
  final text = value.trim();
  if (text.isEmpty) return false;
  final uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );
  if (uuid.hasMatch(text)) return true;
  return RegExp(r'^[0-9a-fA-F]{24,}$').hasMatch(text);
}

class _AttendanceHistoryLine extends StatelessWidget {
  final Map<String, dynamic> record;
  final List<StaffModel> staffDirectory;

  const _AttendanceHistoryLine({
    required this.record,
    this.staffDirectory = const [],
  });

  @override
  Widget build(BuildContext context) {
    final date = _StudentDetailPage._detailRecordDate(record);
    final markedAt = DateTime.tryParse(
      _StudentDetailPage._detailText(
        record['marked_at'] ?? record['created_at'] ?? record['updated_at'],
      ),
    );
    final time = markedAt == null
        ? 'Time not recorded'
        : DateFormat('hh:mm a').format(markedAt.toLocal());
    final status = _StudentDetailPage._detailText(
      record['status'],
      fallback: 'unmarked',
    ).replaceAll('_', ' ');
    final teacher = _teacherLabel(record, staffDirectory);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IconBubble(
            icon: Icons.event_available_rounded,
            color: _statusColor(status),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$date · $time', style: _UiText.title),
                const SizedBox(height: 3),
                Text(
                  '${_labelize(status)} · Marked by $teacher',
                  style: _UiText.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _teacherLabel(
    Map<String, dynamic> row,
    List<StaffModel> staffDirectory,
  ) {
    return _readableAttendanceTeacherLabel(row, staffDirectory: staffDirectory);
  }

  static Color _statusColor(String status) {
    return switch (status.toLowerCase()) {
      'present' => const Color(0xFF24A765),
      'absent' => const Color(0xFFEF4444),
      'leave' => const Color(0xFFF97316),
      'late' => const Color(0xFF8B5CF6),
      _ => const Color(0xFF64748B),
    };
  }

  static String _labelize(String value) {
    final text = value.trim();
    if (text.isEmpty) return 'Unmarked';
    return text[0].toUpperCase() + text.substring(1);
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  final bool large;

  const _Avatar({required this.name, this.large = false});

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    final size = large ? 72.0 : 38.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFE8F2FF),
        border: Border.all(color: Colors.white, width: 3),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: const Color(0xFF1976E8),
          fontWeight: FontWeight.w900,
          fontSize: large ? 28 : 16,
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.11),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label.isEmpty ? 'Unmarked' : label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _IconBubble extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool large;

  const _IconBubble({
    required this.icon,
    required this.color,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: large ? 68 : 42,
      height: large ? 68 : 42,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(large ? 18 : 12),
      ),
      child: Icon(icon, color: color, size: large ? 34 : 22),
    );
  }
}

// ignore: unused_element
class _IconSquare extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _IconSquare({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFEAF0F7)),
        ),
        child: Icon(icon),
      ),
    );
  }
}

class _ReportItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ReportItem(
    this.title,
    this.subtitle,
    this.icon,
    this.color,
    this.onTap,
  );
}

class _ReportRow extends StatelessWidget {
  final _ReportItem item;

  const _ReportRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      padding: const EdgeInsets.all(12),
      child: InkWell(
        onTap: item.onTap,
        child: Row(
          children: [
            _IconBubble(icon: item.icon, color: item.color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, style: _UiText.title),
                  const SizedBox(height: 3),
                  Text(item.subtitle, style: _UiText.caption),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF64748B)),
          ],
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _ModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xFF1976E8) : const Color(0xFF64748B);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? const Color(0xFF1976E8) : const Color(0xFFEAF0F7),
            width: selected ? 1.5 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: const Color(0xFF1976E8).withOpacity(0.12),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ]
              : const [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 10),
            Text(title, style: _UiText.title),
            const SizedBox(height: 4),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: _UiText.caption,
            ),
          ],
        ),
      ),
    );
  }
}

class _StaffAttendanceRow extends StatelessWidget {
  final StaffModel staff;
  final StaffAttendanceModel? attendance;

  const _StaffAttendanceRow({required this.staff, required this.attendance});

  @override
  Widget build(BuildContext context) {
    final checkedIn = attendance?.checkedIn ?? false;
    final checkedOut = attendance?.checkOut != null;
    final color = checkedOut
        ? const Color(0xFF64748B)
        : checkedIn
        ? const Color(0xFF24A765)
        : const Color(0xFFF59E0B);
    final subtitleParts = [
      if ((staff.designation ?? '').trim().isNotEmpty)
        staff.designation!.trim(),
      if (staff.staffCode.trim().isNotEmpty) staff.staffCode.trim(),
    ];
    return Row(
      children: [
        _IconBubble(
          icon: checkedOut
              ? Icons.logout_rounded
              : checkedIn
              ? Icons.check_circle_rounded
              : Icons.schedule_rounded,
          color: color,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                staff.fullName.isEmpty
                    ? attendance?.staffName ?? staff.id
                    : staff.fullName,
                style: _UiText.title,
              ),
              const SizedBox(height: 4),
              Text(
                subtitleParts.isEmpty
                    ? 'Staff member'
                    : subtitleParts.join(' · '),
                style: _UiText.caption,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _StatusPill(
              label: checkedOut
                  ? 'Checked Out'
                  : checkedIn
                  ? 'Checked In'
                  : 'Pending',
              color: color,
            ),
            const SizedBox(height: 6),
            Text(
              checkedOut
                  ? 'In ${attendance?.checkInTimeLabel ?? '--:--'} · Out ${attendance?.checkOutTimeLabel ?? '--:--'}${attendance?.workedDurationLabel.isNotEmpty == true ? ' · ${attendance!.workedDurationLabel}' : ''}${attendance?.checkOutSource.isNotEmpty == true ? ' · ${attendance!.checkOutSource}' : ''}'
                  : attendance?.checkInTimeLabel ?? '--:--',
              style: _UiText.caption,
            ),
          ],
        ),
      ],
    );
  }
}

class _EmptyLine extends StatelessWidget {
  final String text;

  const _EmptyLine(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Center(child: Text(text, style: _UiText.caption)),
    );
  }
}

class _BottomItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _BottomItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xFF1976E8) : const Color(0xFF64748B);
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        width: 76,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekDay {
  final DateTime date;
  final String status;

  const _WeekDay({required this.date, required this.status});
}

class _StudentRecordLoad {
  final String studentId;
  final List<Map<String, dynamic>> records;
  final Object? error;

  const _StudentRecordLoad._({
    required this.studentId,
    required this.records,
    this.error,
  });

  factory _StudentRecordLoad.success(
    String studentId,
    List<Map<String, dynamic>> records,
  ) {
    return _StudentRecordLoad._(studentId: studentId, records: records);
  }

  factory _StudentRecordLoad.failure(String studentId, Object error) {
    return _StudentRecordLoad._(
      studentId: studentId,
      records: const [],
      error: error,
    );
  }
}

class _DayTile extends StatelessWidget {
  final _WeekDay day;

  const _DayTile({required this.day});

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (day.status) {
      'present' => const Color(0xFF24A765),
      'absent' => const Color(0xFFEF4444),
      'leave' => const Color(0xFFF97316),
      'unmarked' => const Color(0xFF94A3B8),
      _ => const Color(0xFF8B5CF6),
    };
    final label = day.status.trim().isEmpty
        ? 'Unmarked'
        : day.status[0].toUpperCase() + day.status.substring(1);
    return _SoftCard(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      child: Column(
        children: [
          Text(
            ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'][day.date.weekday - 1],
            style: _UiText.caption,
          ),
          const SizedBox(height: 8),
          Icon(
            Icons.check_circle_outline_rounded,
            color: statusColor,
            size: 21,
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: _UiText.caption.copyWith(fontSize: 10, color: statusColor),
          ),
        ],
      ),
    );
  }
}
