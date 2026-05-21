import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../routes/app_routes.dart';
import '../../services/backend_api_client.dart';
import '../../theme/app_theme.dart';
import '../../widgets/admin_navigation.dart';
import '../../widgets/dashboard_fab_widget.dart';
import '../../widgets/erp_module_scaffold.dart';
import 'admin_timetable_form_screens.dart';

class AdminTimetableScreen extends StatefulWidget {
  const AdminTimetableScreen({super.key});

  @override
  State<AdminTimetableScreen> createState() => _AdminTimetableScreenState();
}

class _AdminTimetableScreenState extends State<AdminTimetableScreen> {
  String _selectedClass = '';
  List<String> _classes = [];
  final Map<String, SectionModel> _sectionsByClass = {};
  List<Map<String, dynamic>> _subjects = [];
  List<StaffModel> _staff = [];
  List<AcademicYearModel> _academicYears = [];
  List<Map<String, dynamic>> _terms = [];
  final List<String> _days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];

  Map<String, List<Map<String, dynamic>>> _timetable = {};
  List<Map<String, dynamic>> _substitutions = [];

  String _activeDay = 'Monday';

  @override
  void initState() {
    super.initState();
    _loadBackendTimetable();
  }

  Future<void> _loadBackendTimetable() async {
    final api = BackendApiClient.instance;
    final slots = await api.getTimetableSlots();
    final substitutions = await api.getSubstitutions();
    final sections = await api.getSections();
    final staff = await api.getStaff(page: 1, pageSize: 100);
    final subjects = await api.getRawList('/subjects');
    final academicYears = await api.getAcademicYears();
    final currentYear = academicYears.isEmpty
        ? null
        : academicYears.firstWhere(
            (year) => year.isCurrent,
            orElse: () => academicYears.first,
          );
    final terms = currentYear == null
        ? <Map<String, dynamic>>[]
        : await api.getTerms(currentYear.id);
    final parsed = <String, List<Map<String, dynamic>>>{};
    for (final day in _days) {
      parsed[day] = <Map<String, dynamic>>[];
    }
    for (final slot in slots) {
      final rawDay = (slot['day_of_week'] as num?)?.toInt() ?? 1;
      final dayIndex = (rawDay - 1).clamp(0, _days.length - 1).toInt();
      final day = _days[dayIndex];
      final subject = slot['subject'];
      final staffMember = slot['staff'];
      parsed[day]!.add({
        'id': slot['id'],
        'section_id': slot['section_id'],
        'academic_year_id': slot['academic_year_id'],
        'term_id': slot['term_id'],
        'day_of_week': rawDay,
        'period': slot['period_number'] ?? 0,
        'subject_id': slot['subject_id'],
        'subject': subject is Map
            ? subject['subject_name'] ?? slot['subject_id'] ?? ''
            : slot['subject_id'] ?? '',
        'staff_id': slot['staff_id'],
        'teacher': staffMember is! Map
            ? slot['staff_id'] ?? ''
            : '${staffMember['first_name'] ?? ''} ${staffMember['last_name'] ?? ''}'
                  .trim(),
        'start_time': slot['start_time'] ?? '',
        'end_time': slot['end_time'] ?? '',
        'time': _slotTime(slot),
        'conflict': slot['conflict'] == true,
      });
    }
    final labels = _uniqueClassLabels(sections);
    if (!mounted) return;
    setState(() {
      _subjects = subjects;
      _staff = staff.data;
      _academicYears = academicYears;
      _terms = terms;
      _classes = labels;
      if (_classes.isNotEmpty && !_classes.contains(_selectedClass)) {
        _selectedClass = _classes.first;
      }
      _timetable = parsed;
      _substitutions = substitutions;
    });
  }

  String _sectionLabel(SectionModel section) {
    final grade = section.gradeName.trim();
    final sectionName = section.sectionName.trim();
    if (grade.isEmpty && sectionName.isEmpty) return section.id;
    if (grade.isEmpty) return 'Section $sectionName';
    if (sectionName.isEmpty) return grade;
    return '$grade - $sectionName';
  }

  List<String> _uniqueClassLabels(List<SectionModel> sections) {
    _sectionsByClass.clear();
    final nameCounts = <String, int>{};
    for (final section in sections) {
      final name = _sectionLabel(section);
      nameCounts[name] = (nameCounts[name] ?? 0) + 1;
    }

    final used = <String>{};
    return sections.map<String>((section) {
      final name = _sectionLabel(section);
      var label = name;
      if ((nameCounts[name] ?? 0) > 1) {
        final suffix = section.id.length > 8
            ? section.id.substring(0, 8)
            : section.id;
        label = '$name ($suffix)';
        var duplicateIndex = 2;
        while (used.contains(label)) {
          label = '$name ($suffix-$duplicateIndex)';
          duplicateIndex++;
        }
      }
      used.add(label);
      _sectionsByClass[label] = section;
      return label;
    }).toList();
  }

  SectionModel? get _selectedSection => _sectionsByClass[_selectedClass];

  AcademicYearModel? get _currentAcademicYear {
    if (_academicYears.isEmpty) return null;
    return _academicYears.firstWhere(
      (year) => year.isCurrent,
      orElse: () => _academicYears.first,
    );
  }

  String get _defaultTermId => _terms.isEmpty ? '' : '${_terms.first['id']}';

  int get _activeDayNumber => _days.indexOf(_activeDay) + 1;

  String _slotTime(Map<String, dynamic> slot) {
    final start = '${slot['start_time'] ?? ''}'.trim();
    final end = '${slot['end_time'] ?? ''}'.trim();
    if (start.isEmpty && end.isEmpty) return 'TBD';
    if (end.isEmpty) return start;
    return '$start - $end';
  }

  @override
  Widget build(BuildContext context) {
    return SchoolDeskModuleScaffold(
      title: 'Timetable',
      subtitle:
          'Maintain class periods, teachers, conflicts, and substitutions',
      drawer: AdminDrawer(selectedIndex: 5, onDestinationSelected: (_) {}),
      floatingActionButton: const DashboardFabWidget(role: DashboardRole.admin),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      actions: [
        IconButton(
          tooltip: 'Generate suggestions',
          icon: const Icon(Icons.auto_awesome_outlined),
          onPressed: _openGenerateTimetableForm,
        ),
        IconButton(
          tooltip: 'Add period',
          icon: const Icon(Icons.add_rounded),
          onPressed: _openAddPeriodForm,
        ),
      ],
      body: Column(
        children: [
          _buildClassSelector(),
          _buildDaySelector(),
          _buildConflictBanner(),
          Expanded(child: _buildTimetableView()),
          _buildSubstitutionSection(),
        ],
      ),
    );
  }

  Widget _buildClassSelector() {
    if (_classes.isEmpty) {
      return Container(
        width: double.infinity,
        color: AppTheme.surface,
        padding: const EdgeInsets.all(12),
        child: Text(
          'No backend classes available',
          style: GoogleFonts.dmSans(fontSize: 12, color: AppTheme.muted),
        ),
      );
    }
    final selectedTeacher = _selectedSection?.classTeacherName.trim() ?? '';
    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _selectedClass,
            decoration: const InputDecoration(
              labelText: 'Select Class',
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: _classes
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (v) => setState(() => _selectedClass = v!),
          ),
          const SizedBox(height: 6),
          Text(
            selectedTeacher.isEmpty
                ? 'Class teacher: Not assigned'
                : 'Class teacher: $selectedTeacher',
            style: GoogleFonts.dmSans(fontSize: 11, color: AppTheme.muted),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildDaySelector() {
    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: SizedBox(
        height: 36,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _days.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final selected = _activeDay == _days[i];
            return FilterChip(
              label: Text(_days[i].substring(0, 3)),
              selected: selected,
              showCheckmark: false,
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              selectedColor: AppTheme.primaryContainer,
              backgroundColor: AppTheme.surfaceVariant,
              side: BorderSide(
                color: selected ? AppTheme.primary : AppTheme.outline,
              ),
              labelStyle: GoogleFonts.dmSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected ? AppTheme.primary : AppTheme.onSurface,
              ),
              onSelected: (_) => setState(() => _activeDay = _days[i]),
            );
          },
        ),
      ),
    );
  }

  Widget _buildConflictBanner() {
    final periods = _periodsForActiveClass();
    final conflicts = periods.where((p) => p['conflict'] as bool).length;
    if (conflicts == 0) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.errorContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_rounded, size: 16, color: AppTheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$conflicts timetable conflict(s) detected on $_activeDay',
              style: GoogleFonts.dmSans(fontSize: 12, color: AppTheme.error),
            ),
          ),
          TextButton(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Conflict details shown')),
            ),
            child: Text(
              'View',
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: AppTheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _periodsForActiveClass() {
    final sectionId = _selectedSection?.id;
    final periods = List<Map<String, dynamic>>.from(
      _timetable[_activeDay] ?? [],
    );
    if (sectionId == null || sectionId.isEmpty) return periods;
    return periods
        .where((period) => '${period['section_id'] ?? ''}' == sectionId)
        .toList();
  }

  Widget _buildTimetableView() {
    final periods = _periodsForActiveClass();
    if (periods.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.calendar_view_week_outlined,
              size: 48,
              color: AppTheme.muted,
            ),
            const SizedBox(height: 12),
            Text(
              'No periods scheduled for $_activeDay',
              style: GoogleFonts.dmSans(fontSize: 14, color: AppTheme.muted),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _openAddPeriodForm,
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Add Period'),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: periods.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (_, i) => _buildPeriodCard(periods[i]),
    );
  }

  Widget _buildPeriodCard(Map<String, dynamic> p) {
    final hasConflict = p['conflict'] as bool;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: hasConflict ? AppTheme.error : AppTheme.outlineVariant,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: hasConflict
                  ? AppTheme.errorContainer
                  : AppTheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                'P${p['period']}',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: hasConflict ? AppTheme.error : AppTheme.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p['subject'] as String,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${p['teacher']} • ${p['time']}',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: AppTheme.muted,
                  ),
                ),
                if (hasConflict)
                  Text(
                    '⚠ Conflict detected',
                    style: GoogleFonts.dmSans(
                      fontSize: 10,
                      color: AppTheme.error,
                    ),
                  ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(
              Icons.more_vert_rounded,
              size: 16,
              color: AppTheme.muted,
            ),
            onSelected: (v) {
              if (v == 'edit') _openEditPeriodForm(p);
              if (v == 'substitute') _openSubstituteForm(period: p);
              if (v == 'delete') _deletePeriod(p);
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Text('Edit Period')),
              const PopupMenuItem(
                value: 'substitute',
                child: Text('Assign Substitute'),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Text('Remove Period'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubstitutionSection() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 88, 12),
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          border: Border(top: BorderSide(color: AppTheme.outlineVariant)),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 148),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Substitutions',
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextButton(
                      onPressed: _openSubstituteForm,
                      child: Text(
                        '+ Add',
                        style: GoogleFonts.dmSans(fontSize: 12),
                      ),
                    ),
                  ],
                ),
                ..._substitutions.take(2).map(_buildSubstitutionRow),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubstitutionRow(Map<String, dynamic> s) {
    final status = '${s['status'] ?? 'Pending'}';
    final isActive = status.toLowerCase() == 'active';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${s['original'] ?? s['original_staff_id'] ?? 'Original'} → ${s['substitute'] ?? s['substitute_staff_id'] ?? 'Substitute'} (${s['date'] ?? 'TBD'}, ${s['period'] ?? s['period_number'] ?? 'Period'})',
              style: GoogleFonts.dmSans(
                fontSize: 11,
                color: AppTheme.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isActive
                  ? AppTheme.successContainer
                  : AppTheme.warningContainer,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              status,
              style: GoogleFonts.dmSans(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: isActive ? AppTheme.success : AppTheme.warning,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deletePeriod(Map<String, dynamic> period) async {
    final id = '${period['id'] ?? ''}';
    if (id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Backend timetable slot ID is missing'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }
    try {
      await BackendApiClient.instance.deleteRaw('/timetable/slots/$id');
      await _loadBackendTimetable();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Period removed from backend'),
          backgroundColor: AppTheme.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Period removal failed: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  Future<void> _openGenerateTimetableForm() async {
    final result = await Navigator.pushNamed(
      context,
      AppRoutes.adminTimetableGenerationForm,
      arguments: AdminTimetableGenerationFormArgs(
        classLabel: _selectedClass,
        section: _selectedSection,
        academicYear: _currentAcademicYear,
        termId: _defaultTermId,
        dayLabel: _activeDay,
        dayNumber: _activeDayNumber,
      ),
    );
    if (!mounted || result is! AdminTimetableFormResult) return;
    await _loadBackendTimetable();
    if (!mounted) return;
    _showSuccess(result.message);
  }

  Future<void> _openAddPeriodForm() => _openPeriodForm();

  Future<void> _openEditPeriodForm(Map<String, dynamic> period) =>
      _openPeriodForm(period: period);

  Future<void> _openPeriodForm({Map<String, dynamic>? period}) async {
    final result = await Navigator.pushNamed(
      context,
      AppRoutes.adminTimetablePeriodForm,
      arguments: AdminTimetablePeriodFormArgs(
        classLabel: _selectedClass,
        section: _selectedSection,
        academicYear: _currentAcademicYear,
        termId: _defaultTermId,
        dayLabel: _activeDay,
        dayNumber: _activeDayNumber,
        nextPeriodNumber: _periodsForActiveClass().length + 1,
        subjects: _subjects,
        staff: _staff,
        period: period,
      ),
    );
    if (!mounted || result is! AdminTimetableFormResult) return;
    await _loadBackendTimetable();
    if (!mounted) return;
    _showSuccess(result.message);
  }

  Future<void> _openSubstituteForm({Map<String, dynamic>? period}) async {
    final result = await Navigator.pushNamed(
      context,
      AppRoutes.adminTimetableSubstitutionForm,
      arguments: AdminTimetableSubstitutionFormArgs(
        classLabel: _selectedClass,
        dayLabel: _activeDay,
        periods: _periodsForActiveClass(),
        staff: _staff,
        initialPeriod: period,
      ),
    );
    if (!mounted || result is! AdminTimetableFormResult) return;
    await _loadBackendTimetable();
    if (!mounted) return;
    _showSuccess(result.message);
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.success),
    );
  }
}
