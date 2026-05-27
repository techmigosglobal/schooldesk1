import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../services/backend_api_client.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/principal_directory_ui.dart';

enum _AttendanceView { today, sessions, staffQr, students, reports }

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
  _AttendanceView _view = _AttendanceView.today;
  String _selectedSectionId = '';
  String _selectedStudentId = '';

  StaffQrTokenModel? _qrToken;
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
        api.getStaffQrToken(),
        api.getStaffAttendanceForDate(date: _todayText),
        api.getStaff(page: 1, pageSize: 500, status: 'active'),
        api.getSections(),
        api.getAttendanceSessions(date: _todayText),
      ]);
      final sections = results[3] as List<SectionModel>;
      if (!mounted) return;
      setState(() {
        _qrToken = results[0] as StaffQrTokenModel;
        _staffAttendance = results[1] as List<StaffAttendanceModel>;
        _staff = (results[2] as PaginatedList<StaffModel>).data;
        _sections = sections;
        _sessions = results[4] as List<AttendanceSessionModel>;
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
      title: 'Attendance Directory',
      subtitle:
          'Teacher / Staff Status, Class-wise Students, Attendance Reports',
      loading: _loading,
      error: _error,
      onRefresh: _load,
      onAdd: _openReportInput,
      addIcon: Icons.summarize_outlined,
      addTooltip: 'Create attendance report',
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
      color: AppTheme.primary,
      tone: const Color(0xFFEFF6FF),
    ),
    PrincipalDirectoryMetric(
      label: 'Marked Students',
      value: '$_markedStudents',
      icon: Icons.groups_outlined,
      color: AppTheme.success,
      tone: const Color(0xFFECFDF3),
    ),
    PrincipalDirectoryMetric(
      label: 'Staff Checked In',
      value:
          '${_staffAttendance.where((row) => row.checkedIn).length}/${_staff.length}',
      icon: Icons.badge_outlined,
      color: Colors.teal,
      tone: const Color(0xFFE6FFFB),
    ),
    PrincipalDirectoryMetric(
      label: 'Exceptions',
      value: '${_exceptions.length}',
      icon: Icons.warning_amber_rounded,
      color: _exceptions.isEmpty ? AppTheme.success : AppTheme.warning,
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
                _modeChip(_AttendanceView.today, 'Today', Icons.today_outlined),
                _modeChip(
                  _AttendanceView.sessions,
                  'Sessions',
                  Icons.list_alt_outlined,
                ),
                _modeChip(
                  _AttendanceView.staffQr,
                  'Staff QR',
                  Icons.qr_code_2_rounded,
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
      _AttendanceView.today => [
        ..._staffAttendance.map(_staffCard),
        ..._exceptions.map(_exceptionCard),
      ],
      _AttendanceView.sessions => _sessions.map(_sessionCard).toList(),
      _AttendanceView.staffQr => [_qrCard()],
      _AttendanceView.students =>
        _detailLoading
            ? [_loadingCard('Loading students', 'Fetching selected class roll')]
            : _sectionStudents.map(_studentCard).toList(),
      _AttendanceView.reports => [
        _reportCard('Daily attendance report', 'pdf'),
        _reportCard('Class attendance register', 'csv'),
      ],
    };
    final query = _search.trim().toLowerCase();
    if (query.isEmpty) return rows;
    return rows.where((card) => _widgetText(card).contains(query)).toList();
  }

  Widget _staffCard(StaffAttendanceModel row) {
    final checkedIn = row.checkedIn;
    return PrincipalDirectoryCard(
      icon: checkedIn ? Icons.verified_outlined : Icons.schedule_outlined,
      title: row.staffName,
      subtitle:
          'In ${row.checkInTimeLabel} | Out ${row.checkOutTimeLabel} | ${row.source}',
      status: checkedIn ? 'Checked in' : 'Pending',
      statusColor: checkedIn ? AppTheme.success : AppTheme.warning,
      chips: [
        PrincipalInfoPill(
          icon: Icons.badge_outlined,
          label: row.status.isEmpty ? 'staff' : row.status,
        ),
        PrincipalInfoPill(
          icon: Icons.calendar_today_outlined,
          label: _todayText,
        ),
      ],
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: principalDirectoryMuted,
      ),
      onTap: () => _openStaffDetail(row),
    );
  }

  Widget _exceptionCard(AttendanceSessionModel session) {
    return PrincipalDirectoryCard(
      icon: Icons.warning_amber_rounded,
      title: _sectionLabel(session.sectionId),
      subtitle:
          'Period ${session.periodNumber} | ${session.presentCount}/${session.totalStudents} present',
      status: 'Review',
      statusColor: AppTheme.warning,
      chips: [
        PrincipalInfoPill(
          icon: Icons.event_available_outlined,
          label: _dateOnly(session.date),
        ),
        PrincipalInfoPill(
          icon: Icons.groups_outlined,
          label: '${_attendancePercent(session).toStringAsFixed(0)}%',
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
    final marked = session.totalStudents > 0;
    return PrincipalDirectoryCard(
      icon: Icons.fact_check_outlined,
      title: _sectionLabel(session.sectionId),
      subtitle:
          'Period ${session.periodNumber} | ${session.presentCount}/${session.totalStudents} present | ${_dateOnly(session.date)}',
      status: marked ? 'Marked' : 'Pending',
      statusColor: marked ? AppTheme.success : AppTheme.warning,
      chips: [
        PrincipalInfoPill(
          icon: Icons.percent_rounded,
          label: '${_attendancePercent(session).toStringAsFixed(0)}%',
        ),
        PrincipalInfoPill(
          icon: Icons.menu_book_outlined,
          label: session.subjectId,
        ),
      ],
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: principalDirectoryMuted,
      ),
      onTap: () => _openSessionDetail(session),
    );
  }

  Widget _qrCard() {
    final token = _qrToken;
    final active = token != null && token.token.isNotEmpty && !token.isExpired;
    return PrincipalDirectoryCard(
      icon: Icons.qr_code_2_rounded,
      title: 'Daily Staff QR',
      subtitle: active
          ? 'Valid for ${token.secondsRemaining}s | ${token.schoolDate}'
          : 'QR token unavailable or expired',
      status: active ? 'Active' : 'Refresh',
      statusColor: active ? AppTheme.success : AppTheme.warning,
      chips: [
        PrincipalInfoPill(
          icon: Icons.timer_outlined,
          label: active ? '${token.secondsRemaining}s' : 'expired',
        ),
        PrincipalInfoPill(
          icon: Icons.calendar_today_outlined,
          label: token?.schoolDate ?? _todayText,
        ),
      ],
      trailing: IconButton(
        tooltip: 'Refresh QR',
        icon: const Icon(Icons.refresh_rounded),
        onPressed: _load,
      ),
      body: token == null || token.token.isEmpty
          ? null
          : Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE0E8F0)),
                ),
                child: QrImageView(
                  data: token.token,
                  version: QrVersions.auto,
                  size: 180,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
      onTap: _openQrDetail,
    );
  }

  Widget _studentCard(StudentModel student) {
    final selected = _selectedStudentId == student.id;
    return PrincipalDirectoryCard(
      icon: Icons.person_outline_rounded,
      title: student.fullName.isEmpty ? student.id : student.fullName,
      subtitle: 'Admission ${student.admissionNumber} | ${student.status}',
      status: selected ? 'Selected' : student.status,
      statusColor: selected ? AppTheme.primary : AppTheme.success,
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
      subtitle: 'Queue $format export for ${_sectionLabel(_selectedSectionId)}',
      status: format.toUpperCase(),
      statusColor: AppTheme.primary,
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
        tooltip: 'Create report',
        icon: const Icon(Icons.file_download_outlined),
        onPressed: () => _createReport(_reportTypeFor(title), format),
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
      statusColor: AppTheme.primary,
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
                label: session.totalStudents > 0 ? 'Marked' : 'Pending',
                color: session.totalStudents > 0
                    ? AppTheme.success
                    : AppTheme.warning,
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
                  label: 'Subject ID',
                  value: session.subjectId,
                ),
                PrincipalDetailRow(label: 'Staff ID', value: session.staffId),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openStaffDetail(StaffAttendanceModel row) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => PrincipalDetailPage(
          title: row.staffName,
          children: [
            PrincipalDetailCard(
              title: 'Staff Attendance',
              trailing: PrincipalStatusPill(
                label: row.checkedIn ? 'Checked in' : 'Pending',
                color: row.checkedIn ? AppTheme.success : AppTheme.warning,
              ),
              children: [
                PrincipalDetailRow(
                  label: 'Check in',
                  value: row.checkInTimeLabel,
                ),
                PrincipalDetailRow(
                  label: 'Check out',
                  value: row.checkOutTimeLabel,
                ),
                PrincipalDetailRow(label: 'Source', value: row.source),
                PrincipalDetailRow(
                  label: 'Status',
                  value: row.status.isEmpty ? '-' : row.status,
                ),
                PrincipalDetailRow(label: 'Staff ID', value: row.staffId),
              ],
            ),
          ],
        ),
      ),
    );
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
                color: AppTheme.primary,
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

  Future<void> _openQrDetail() async {
    final token = _qrToken;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => PrincipalDetailPage(
          title: 'Staff QR',
          children: [
            PrincipalDetailCard(
              title: 'Daily Staff QR',
              trailing: IconButton(
                tooltip: 'Refresh QR',
                icon: const Icon(Icons.refresh_rounded),
                onPressed: _load,
              ),
              children: [
                if (token == null || token.token.isEmpty)
                  const Text('The backend did not return a staff QR token.')
                else
                  Center(
                    child: Column(
                      children: [
                        QrImageView(
                          data: token.token,
                          version: QrVersions.auto,
                          size: 220,
                          backgroundColor: Colors.white,
                        ),
                        const SizedBox(height: 14),
                        PrincipalStatusPill(
                          label: 'Refreshes in ${token.secondsRemaining}s',
                          color: token.secondsRemaining <= 10
                              ? AppTheme.warning
                              : AppTheme.success,
                          icon: Icons.timer_outlined,
                        ),
                      ],
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
                  icon: Icons.file_download_outlined,
                  title: 'Create export',
                  subtitle:
                      'Queue this report through the backend export lifecycle',
                  onTap: () {
                    Navigator.pop(context);
                    _createReport(_reportTypeFor(title), format);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openReportInput() async {
    final queued = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PrincipalInputPage(
          title: 'Create Attendance Report',
          icon: Icons.summarize_outlined,
          child: _AttendanceReportForm(
            sections: _sections,
            selectedSectionId: _selectedSectionId,
            todayText: _todayText,
            sectionLabel: _sectionLabel,
          ),
        ),
      ),
    );
    if (queued == true) {
      _showSnack('Attendance report export queued', success: true);
    }
  }

  Future<void> _createReport(String reportType, String format) async {
    try {
      await BackendApiClient.instance.createReportExport(
        '/attendance/reports/exports',
        reportTitle: reportType,
        reportType: reportType,
        format: format,
        parameters: {'date': _todayText, 'section_id': _selectedSectionId},
      );
      _showSnack('Attendance report export queued', success: true);
    } catch (error) {
      _showSnack('Unable to queue report export: $error');
    }
  }

  List<AttendanceSessionModel> get _exceptions => _sessions
      .where(
        (session) =>
            session.totalStudents == 0 ||
            (session.totalStudents > 0 &&
                session.presentCount / session.totalStudents < 0.75),
      )
      .toList();

  int get _markedStudents =>
      _sessions.fold(0, (sum, session) => sum + session.presentCount);

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
    if (session.totalStudents <= 0) return 0;
    return (session.presentCount / session.totalStudents) * 100;
  }

  String _dateOnly(String value) {
    final text = value.trim();
    if (text.isEmpty) return _todayText;
    return text.split('T').first;
  }

  String _reportTypeFor(String title) {
    return title.toLowerCase().contains('class')
        ? 'class_attendance_register'
        : 'daily_attendance';
  }

  String _widgetText(Widget widget) => widget.toStringDeep().toLowerCase();

  void _showSnack(String message, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? AppTheme.success : AppTheme.error,
      ),
    );
  }

  static String _text(Object? value, {String fallback = ''}) {
    final text = '${value ?? ''}'.trim();
    return text.isEmpty || text == 'null' ? fallback : text;
  }
}

class _AttendanceReportForm extends StatefulWidget {
  final List<SectionModel> sections;
  final String selectedSectionId;
  final String todayText;
  final String Function(String sectionId) sectionLabel;

  const _AttendanceReportForm({
    required this.sections,
    required this.selectedSectionId,
    required this.todayText,
    required this.sectionLabel,
  });

  @override
  State<_AttendanceReportForm> createState() => _AttendanceReportFormState();
}

class _AttendanceReportFormState extends State<_AttendanceReportForm> {
  String _reportType = 'daily_attendance';
  String _format = 'pdf';
  String _sectionId = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _sectionId = widget.selectedSectionId;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          initialValue: _reportType,
          decoration: const InputDecoration(labelText: 'Report'),
          items: const [
            DropdownMenuItem(
              value: 'daily_attendance',
              child: Text('Daily attendance report'),
            ),
            DropdownMenuItem(
              value: 'class_attendance_register',
              child: Text('Class attendance register'),
            ),
          ],
          onChanged: (value) =>
              setState(() => _reportType = value ?? 'daily_attendance'),
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          initialValue: _format,
          decoration: const InputDecoration(labelText: 'Format'),
          items: const [
            DropdownMenuItem(value: 'pdf', child: Text('PDF')),
            DropdownMenuItem(value: 'csv', child: Text('CSV')),
          ],
          onChanged: (value) => setState(() => _format = value ?? 'pdf'),
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          initialValue: _sectionId.isEmpty ? null : _sectionId,
          decoration: const InputDecoration(labelText: 'Class'),
          items: [
            for (final section in widget.sections)
              DropdownMenuItem(
                value: section.id,
                child: Text(widget.sectionLabel(section.id)),
              ),
          ],
          onChanged: (value) => setState(() => _sectionId = value ?? ''),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.file_download_outlined),
          label: Text(_saving ? 'Queuing...' : 'Queue report'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await BackendApiClient.instance.createReportExport(
        '/attendance/reports/exports',
        reportTitle: _reportType,
        reportType: _reportType,
        format: _format,
        parameters: {'date': widget.todayText, 'section_id': _sectionId},
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to queue attendance report: $error'),
          backgroundColor: AppTheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
