import 'package:flutter/material.dart';

import 'package:schooldesk1/routes/app_routes.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/theme/app_theme.dart';
import 'package:schooldesk1/core/widgets/admin_navigation.dart';
import 'package:schooldesk1/core/widgets/dashboard_fab_widget.dart';
import 'package:schooldesk1/core/widgets/erp_module_scaffold.dart';
import 'package:schooldesk1/core/widgets/operations_workspace.dart';
import 'package:schooldesk1/features/academics/presentation/screens/admin_timetable_screen/admin_timetable_form_screens.dart';

class AdminTimetableScreen extends StatefulWidget {
  const AdminTimetableScreen({super.key});

  @override
  State<AdminTimetableScreen> createState() => _AdminTimetableScreenState();
}

class _AdminTimetableScreenState extends State<AdminTimetableScreen> {
  static const _days = <String>[
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];

  bool _loading = true;
  String? _error;
  String _selectedSectionId = '';
  int _selectedDay = DateTime.now().weekday.clamp(1, 6).toInt();

  List<Map<String, dynamic>> _slots = [];
  List<Map<String, dynamic>> _subjects = [];
  List<Map<String, dynamic>> _terms = [];
  List<Map<String, dynamic>> _substitutions = [];
  List<SectionModel> _sections = [];
  List<StaffModel> _staff = [];
  List<AcademicYearModel> _academicYears = [];

  @override
  void initState() {
    super.initState();
    _loadBackendTimetable();
  }

  Future<void> _loadBackendTimetable() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = BackendApiClient.instance;
      final academicYears = await api.getAcademicYears();
      final currentYear = _currentAcademicYearFrom(academicYears);
      final terms = currentYear == null
          ? <Map<String, dynamic>>[]
          : await api.getTerms(currentYear.id);
      final results = await Future.wait<Object>([
        api.getTimetableSlots(),
        api.getSubstitutions(),
        api.getSections(),
        api.getStaff(page: 1, pageSize: 300, status: 'active'),
        api.getRawList('/subjects'),
      ]);
      final sections = results[2] as List<SectionModel>;
      if (!mounted) return;
      setState(() {
        _academicYears = academicYears;
        _terms = terms;
        _slots = (results[0] as List<Map<String, dynamic>>)..sort(_slotSort);
        _substitutions = results[1] as List<Map<String, dynamic>>;
        _sections = sections;
        _staff = (results[3] as PaginatedList<StaffModel>).data;
        _subjects = results[4] as List<Map<String, dynamic>>;
        if (_selectedSectionId.isEmpty && sections.isNotEmpty) {
          _selectedSectionId = sections.first.id;
        }
        if (!_sections.any((section) => section.id == _selectedSectionId)) {
          _selectedSectionId = sections.isEmpty ? '' : sections.first.id;
        }
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load timetable builder from backend. $error';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SchoolDeskModuleScaffold(
      title: 'Timetable Builder',
      subtitle:
          'Class week grid, conflict checks, substitutions, and generated periods',
      drawer: AdminDrawer(selectedIndex: 5, onDestinationSelected: (_) {}),
      railBreakpoint: double.infinity,
      navigationDrawerEnabled: false,
      floatingActionButton: const DashboardFabWidget(role: DashboardRole.admin),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      actions: [
        IconButton(
          tooltip: 'Generate suggestions',
          icon: const Icon(Icons.auto_awesome_rounded),
          onPressed: _selectedSection == null
              ? null
              : _openGenerateTimetableForm,
        ),
        IconButton(
          tooltip: 'Add period',
          icon: const Icon(Icons.add_rounded),
          onPressed: _selectedSection == null ? null : _openAddPeriodForm,
        ),
        IconButton(
          tooltip: 'Refresh timetable',
          icon: const Icon(Icons.refresh_rounded),
          onPressed: _loadBackendTimetable,
        ),
      ],
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return OpsEmptyState(
        icon: Icons.calendar_view_week_outlined,
        title: 'Timetable unavailable',
        message: _error!,
        actionLabel: 'Retry',
        onAction: _loadBackendTimetable,
      );
    }
    return OpsWorkspace(
      children: [
        OpsResponsiveGrid(
          minTileWidth: 210,
          children: [
            OpsMetricCard(
              label: 'Total periods',
              value: '${_slots.length}',
              icon: Icons.event_note_rounded,
              color: Colors.indigo,
              caption: '/timetable/slots',
            ),
            OpsMetricCard(
              label: 'Classes configured',
              value: '$_classesCovered',
              icon: Icons.meeting_room_rounded,
              color: Colors.teal,
              caption: 'Class teacher ready',
            ),
            OpsMetricCard(
              label: 'Teacher load',
              value: '$_teachersScheduled',
              icon: Icons.badge_outlined,
              color: Colors.deepPurple,
              caption: 'Scheduled staff',
            ),
            OpsMetricCard(
              label: 'Conflicts',
              value: '${_conflicts.length}',
              icon: Icons.warning_amber_rounded,
              color: _conflicts.isEmpty ? Colors.green : Colors.orange,
              caption: 'Same teacher/time',
            ),
          ],
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 980;
            final filters = _buildControlPanel();
            final grid = _buildWeekGrid();
            return wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: 330, child: filters),
                      const SizedBox(width: 16),
                      Expanded(child: grid),
                    ],
                  )
                : Column(children: [filters, const SizedBox(height: 16), grid]);
          },
        ),
        OpsResponsiveGrid(
          minTileWidth: 360,
          children: [_buildSubstitutionPanel(), _buildConflictPanel()],
        ),
      ],
    );
  }

  Widget _buildControlPanel() {
    return OpsPanel(
      title: 'Builder Controls',
      subtitle: 'Select a class and weekday before creating slots',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _selectedSectionId.isEmpty
                ? null
                : _selectedSectionId,
            decoration: const InputDecoration(
              labelText: 'Class / section',
              prefixIcon: Icon(Icons.school_outlined),
            ),
            items: _sections
                .map(
                  (section) => DropdownMenuItem(
                    value: section.id,
                    child: Text(_sectionLabel(section)),
                  ),
                )
                .toList(),
            onChanged: (value) =>
                setState(() => _selectedSectionId = value ?? ''),
          ),
          const SizedBox(height: 12),
          OpsModeSelector<int>(
            selected: _selectedDay,
            options: [
              for (var i = 0; i < _days.length; i++)
                OpsModeOption(
                  value: i + 1,
                  label: _days[i].substring(0, 3),
                  icon: Icons.calendar_today_outlined,
                ),
            ],
            onSelected: (value) => setState(() => _selectedDay = value),
          ),
          const SizedBox(height: 18),
          OpsStatusPill(
            label: _selectedSection?.classTeacherName.trim().isEmpty ?? true
                ? 'Class teacher: Not assigned'
                : 'Class teacher: ${_selectedSection!.classTeacherName}',
            color: _selectedSection?.classTeacherName.trim().isEmpty ?? true
                ? Colors.orange
                : Colors.green,
            icon: Icons.person_pin_circle_outlined,
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _selectedSection == null ? null : _openAddPeriodForm,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add period'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _selectedSection == null ? null : _openSubstitutionForm,
            icon: const Icon(Icons.swap_horiz_rounded),
            label: const Text('Add substitution'),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekGrid() {
    final periods = _periodsForSelection();
    return OpsPanel(
      title: '${_sectionLabel(_selectedSection)} - ${_dayLabel(_selectedDay)}',
      subtitle:
          'Admin owns create, edit, delete, and generated timetable writes',
      trailing: OpsStatusPill(
        label: '${periods.length} period${periods.length == 1 ? '' : 's'}',
        color: Colors.indigo,
        icon: Icons.view_week_outlined,
      ),
      child: periods.isEmpty
          ? OpsEmptyState(
              icon: Icons.calendar_view_day_outlined,
              title: 'No periods for this selection',
              message:
                  'Use Add period or Generate suggestions to write slots through the timetable API.',
            )
          : Column(
              children: [for (final period in periods) _buildPeriodRow(period)],
            ),
    );
  }

  Widget _buildPeriodRow(Map<String, dynamic> period) {
    final conflict = _isConflict(period);
    return OpsListRow(
      icon: conflict ? Icons.warning_amber_rounded : Icons.schedule_rounded,
      title:
          'Period ${_int(period['period_number'])} - ${_subjectName(period)}',
      subtitle: '${_slotTime(period)} | ${_staffName(period)}',
      trailing: Wrap(
        spacing: 8,
        children: [
          OpsStatusPill(
            label: conflict ? 'Conflict' : 'Ready',
            color: conflict ? Colors.orange : Colors.green,
          ),
          IconButton(
            tooltip: 'Edit period',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _openEditPeriodForm(period),
          ),
          IconButton(
            tooltip: 'Delete period',
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () => _deletePeriod(period),
          ),
        ],
      ),
      onTap: () => _openEditPeriodForm(period),
    );
  }

  Widget _buildSubstitutionPanel() {
    return OpsPanel(
      title: 'Substitutions',
      subtitle: 'Emergency substitutions stay on the support endpoint',
      trailing: IconButton(
        tooltip: 'Add substitution',
        icon: const Icon(Icons.add_rounded),
        onPressed: _openSubstitutionForm,
      ),
      child: _substitutions.isEmpty
          ? const Text('No substitutions recorded from backend.')
          : Column(
              children: [
                for (final row in _substitutions.take(5))
                  OpsListRow(
                    icon: Icons.swap_horiz_rounded,
                    title: _text(row['date'], fallback: 'Substitution'),
                    subtitle:
                        '${_text(row['original_staff_name'] ?? row['original_staff_id'])} -> ${_text(row['substitute_staff_name'] ?? row['substitute_staff_id'])}',
                  ),
              ],
            ),
    );
  }

  Widget _buildConflictPanel() {
    return OpsPanel(
      title: 'Conflict Validation',
      subtitle: 'Flags duplicate teacher/class periods before publishing',
      child: _conflicts.isEmpty
          ? OpsListRow(
              icon: Icons.verified_outlined,
              title: 'No conflicts detected',
              subtitle:
                  'Current backend slots are clean for duplicate teacher and class timings.',
              trailing: const OpsStatusPill(
                label: 'Clear',
                color: Colors.green,
              ),
            )
          : Column(
              children: [
                for (final row in _conflicts.take(6))
                  OpsListRow(
                    icon: Icons.warning_amber_rounded,
                    title: row,
                    subtitle: 'Resolve by editing the conflicting period.',
                    trailing: const OpsStatusPill(
                      label: 'Review',
                      color: Colors.orange,
                    ),
                  ),
              ],
            ),
    );
  }

  Future<void> _openGenerateTimetableForm() async {
    final result = await Navigator.pushNamed(
      context,
      AppRoutes.adminTimetableGenerationForm,
      arguments: AdminTimetableGenerationFormArgs(
        classLabel: _sectionLabel(_selectedSection),
        section: _selectedSection,
        academicYear: _currentAcademicYear,
        termId: _currentTermId,
        dayLabel: _dayLabel(_selectedDay),
        dayNumber: _selectedDay,
      ),
    );
    await _handleTimetableResult(result);
  }

  Future<void> _openAddPeriodForm() async {
    final periods = _periodsForSelection();
    final result = await Navigator.pushNamed(
      context,
      AppRoutes.adminTimetablePeriodForm,
      arguments: AdminTimetablePeriodFormArgs(
        classLabel: _sectionLabel(_selectedSection),
        section: _selectedSection,
        academicYear: _currentAcademicYear,
        termId: _currentTermId,
        dayLabel: _dayLabel(_selectedDay),
        dayNumber: _selectedDay,
        nextPeriodNumber: periods.length + 1,
        subjects: _subjects,
        staff: _staff,
      ),
    );
    await _handleTimetableResult(result);
  }

  Future<void> _openEditPeriodForm(Map<String, dynamic> period) async {
    final result = await Navigator.pushNamed(
      context,
      AppRoutes.adminTimetablePeriodForm,
      arguments: AdminTimetablePeriodFormArgs(
        classLabel: _sectionLabel(_selectedSection),
        section: _selectedSection,
        academicYear: _currentAcademicYear,
        termId: _currentTermId,
        dayLabel: _dayLabel(_selectedDay),
        dayNumber: _selectedDay,
        nextPeriodNumber: _int(period['period_number']),
        subjects: _subjects,
        staff: _staff,
        period: period,
      ),
    );
    await _handleTimetableResult(result);
  }

  Future<void> _openSubstitutionForm({Map<String, dynamic>? period}) async {
    final result = await Navigator.pushNamed(
      context,
      AppRoutes.adminTimetableSubstitutionForm,
      arguments: AdminTimetableSubstitutionFormArgs(
        classLabel: _sectionLabel(_selectedSection),
        dayLabel: _dayLabel(_selectedDay),
        periods: _periodsForSelection(),
        staff: _staff,
        initialPeriod: period,
      ),
    );
    await _handleTimetableResult(result);
  }

  Future<void> _handleTimetableResult(Object? result) async {
    if (!mounted || result is! AdminTimetableFormResult) return;
    await _loadBackendTimetable();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: AppTheme.success,
      ),
    );
  }

  Future<void> _deletePeriod(Map<String, dynamic> period) async {
    final id = _text(period['id']);
    if (id.isEmpty) return;
    try {
      await BackendApiClient.instance.deleteRaw('/timetable/slots/$id');
      await _loadBackendTimetable();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Timetable period deleted'),
          backgroundColor: AppTheme.success,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to delete timetable period: $error'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  List<Map<String, dynamic>> _periodsForSelection() {
    return _slots
        .where(
          (slot) =>
              _text(slot['section_id']) == _selectedSectionId &&
              _int(slot['day_of_week']) == _selectedDay,
        )
        .toList();
  }

  List<String> get _conflicts {
    final seen = <String, Map<String, dynamic>>{};
    final issues = <String>[];
    for (final slot in _slots) {
      final day = _int(slot['day_of_week']);
      final period = _int(slot['period_number']);
      final staff = _text(slot['staff_id']);
      if (staff.isEmpty) continue;
      final key = '$staff:$day:$period';
      final previous = seen[key];
      if (previous != null && _text(previous['id']) != _text(slot['id'])) {
        issues.add(
          '${_staffName(slot)} is double-booked on ${_dayLabel(day)} period $period',
        );
      }
      seen[key] = slot;
    }
    return issues.toSet().toList();
  }

  bool _isConflict(Map<String, dynamic> period) {
    final staff = _text(period['staff_id']);
    if (staff.isEmpty) return false;
    final day = _int(period['day_of_week']);
    final periodNumber = _int(period['period_number']);
    return _slots.where((slot) {
      return _text(slot['id']) != _text(period['id']) &&
          _text(slot['staff_id']) == staff &&
          _int(slot['day_of_week']) == day &&
          _int(slot['period_number']) == periodNumber;
    }).isNotEmpty;
  }

  int get _classesCovered => _slots
      .map((slot) => _text(slot['section_id']))
      .where((id) => id.isNotEmpty)
      .toSet()
      .length;

  int get _teachersScheduled => _slots
      .map((slot) => _text(slot['staff_id']))
      .where((id) => id.isNotEmpty)
      .toSet()
      .length;

  SectionModel? get _selectedSection {
    for (final section in _sections) {
      if (section.id == _selectedSectionId) return section;
    }
    return null;
  }

  AcademicYearModel? get _currentAcademicYear =>
      _currentAcademicYearFrom(_academicYears);

  AcademicYearModel? _currentAcademicYearFrom(List<AcademicYearModel> years) {
    for (final year in years) {
      if (year.isCurrent) return year;
    }
    return years.isEmpty ? null : years.first;
  }

  String get _currentTermId => _terms.isEmpty ? '' : _text(_terms.first['id']);

  String _sectionLabel(SectionModel? section) {
    if (section == null) return 'No class selected';
    final grade = section.gradeName.trim();
    final name = section.sectionName.trim();
    if (grade.isEmpty && name.isEmpty) return section.id;
    if (grade.isEmpty) return 'Section $name';
    if (name.isEmpty) return grade;
    return '$grade - $name';
  }

  String _subjectName(Map<String, dynamic> slot) {
    final subject = slot['subject'];
    if (subject is Map) {
      return _text(
        subject['subject_name'] ?? subject['name'],
        fallback: 'Subject',
      );
    }
    return _text(
      slot['subject_name'] ?? slot['subject_id'],
      fallback: 'Subject',
    );
  }

  String _staffName(Map<String, dynamic> slot) {
    final staff = slot['staff'];
    if (staff is Map) {
      final name = _text(staff['name']);
      if (name.isNotEmpty) return name;
      final fullName =
          '${_text(staff['first_name'])} ${_text(staff['last_name'])}'.trim();
      if (fullName.isNotEmpty) return fullName;
    }
    return _text(
      slot['staff_name'] ?? slot['staff_id'],
      fallback: 'Teacher pending',
    );
  }

  String _slotTime(Map<String, dynamic> slot) {
    final start = _text(slot['start_time']);
    final end = _text(slot['end_time']);
    if (start.isEmpty && end.isEmpty) return 'Time pending';
    if (end.isEmpty) return start;
    return '$start - $end';
  }

  String _dayLabel(int day) => _days[(day - 1).clamp(0, _days.length - 1)];

  static int _slotSort(Map<String, dynamic> a, Map<String, dynamic> b) {
    final day = _int(a['day_of_week']).compareTo(_int(b['day_of_week']));
    if (day != 0) return day;
    return _int(a['period_number']).compareTo(_int(b['period_number']));
  }

  static int _int(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }

  static String _text(Object? value, {String fallback = ''}) {
    final text = '${value ?? ''}'.trim();
    return text.isEmpty || text == 'null' ? fallback : text;
  }
}
