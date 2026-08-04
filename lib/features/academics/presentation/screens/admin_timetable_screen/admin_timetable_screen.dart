import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:schooldesk1/core/desktop/desktop_platform.dart';
import 'package:schooldesk1/core/navigation/role_nav_indices.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/widgets/app_navigation.dart';

enum _TimetableStage { selectClass, editor }

class AdminTimetableScreen extends StatefulWidget {
  const AdminTimetableScreen({super.key});

  @override
  State<AdminTimetableScreen> createState() => _AdminTimetableScreenState();
}

class _AdminTimetableScreenState extends State<AdminTimetableScreen> {
  static const _accent = Color(0xFF0877D8);
  static const _ink = Color(0xFF172B3A);
  static const _muted = Color(0xFF667989);
  static const _background = Color(0xFFF3F8FC);
  static const _border = Color(0xFFDDE7F0);
  static const _defaultWorkingDays = <int>[1, 2, 3, 4, 5, 6];
  static const _dayLabels = <String>[
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _timePattern = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');

  bool _loading = true;
  bool _saving = false;
  String? _error;
  String _selectedSectionId = '';
  _TimetableStage _stage = _TimetableStage.selectClass;
  List<int> _workingDays = [..._defaultWorkingDays];
  Set<int> _selectedDays = {..._defaultWorkingDays};
  List<_TimetableRowDraft> _rows = [];

  List<Map<String, dynamic>> _slots = [];
  List<SectionModel> _sections = [];
  List<AcademicYearModel> _academicYears = [];
  List<Map<String, dynamic>> _subjects = [];
  List<Map<String, dynamic>> _gradeSubjects = [];
  List<Map<String, dynamic>> _staffSubjects = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _disposeRows();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = BackendApiClient.instance;
      final results = await Future.wait<Object>([
        api.getAcademicYears(forceRefresh: true),
        api.getSections(forceRefresh: true),
        api.getTimetableWorkingDays().catchError((_) => _defaultWorkingDays),
        api.getTimetableSlots(),
        api.getRawList('/subjects', queryParameters: const {'page_size': 500}),
        api.getRawList(
          '/grade-subjects',
          queryParameters: const {'page_size': 500},
        ),
        api.getRawList(
          '/staff-subjects',
          queryParameters: const {'page_size': 500},
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _academicYears = results[0] as List<AcademicYearModel>;
        _sections = results[1] as List<SectionModel>;
        final configuredDays =
            (results[2] as List<int>)
                .where((day) => day >= 1 && day <= 7)
                .toSet()
                .toList()
              ..sort();
        _workingDays = configuredDays.isEmpty
            ? [..._defaultWorkingDays]
            : configuredDays;
        if (_stage == _TimetableStage.selectClass) {
          _selectedDays = {..._workingDays};
        }
        _slots = (results[3] as List<Map<String, dynamic>>)..sort(_slotSort);
        _subjects = results[4] as List<Map<String, dynamic>>;
        _gradeSubjects = results[5] as List<Map<String, dynamic>>;
        _staffSubjects = results[6] as List<Map<String, dynamic>>;
        if (_selectedSectionId.isEmpty && _sections.isNotEmpty) {
          _selectedSectionId = _sections.first.id;
        }
        if (!_sections.any((section) => section.id == _selectedSectionId)) {
          _selectedSectionId = _sections.isEmpty ? '' : _sections.first.id;
        }
        _loading = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Unable to load timetable setup. $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = DesktopPlatform.isDesktopLayout(context);
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _background,
      drawer: isDesktop
          ? null
          : PrincipalDrawer(
              selectedIndex: PrincipalNav.timetable,
              onDestinationSelected: (_) {},
            ),
      bottomNavigationBar: isDesktop ? null : const PrincipalShellBottomBar(),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isDesktop ? 1040 : 560),
            child: RefreshIndicator(
              color: _accent,
              onRefresh: _loadData,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  SliverToBoxAdapter(child: _buildHeader()),
                  if (_loading)
                    const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_error != null)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: _emptyState(
                          icon: Icons.cloud_off_rounded,
                          title: 'Timetable unavailable',
                          message: _error!,
                          actionLabel: 'Retry',
                          onAction: _loadData,
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(18, 8, 18, 96),
                      sliver: SliverToBoxAdapter(child: _buildContent()),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final inEditor = _stage == _TimetableStage.editor;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 10, 12, 8),
      child: Row(
        children: [
          IconButton(
            tooltip: inEditor ? 'Back' : 'Menu',
            onPressed: _saving
                ? null
                : inEditor
                ? _closeEditor
                : () => _scaffoldKey.currentState?.openDrawer(),
            icon: Icon(
              inEditor ? Icons.arrow_back_ios_new_rounded : Icons.menu_rounded,
              size: 21,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  inEditor ? 'Edit Timetable' : 'Timetable Management',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: _ink,
                  ),
                ),
                Text(
                  inEditor ? _selectedClassLabel : 'Select class to continue',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _ink.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          IconButton.filledTonal(
            tooltip: 'Refresh',
            onPressed: _saving ? null : _loadData,
            icon: const Icon(Icons.refresh_rounded, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return switch (_stage) {
      _TimetableStage.selectClass => _buildClassSelection(),
      _TimetableStage.editor => _buildEditor(),
    };
  }

  Widget _buildClassSelection() {
    if (_sections.isEmpty) {
      return _emptyState(
        icon: Icons.groups_2_outlined,
        title: 'No active classes found',
        message: 'Create an active class before setting a timetable.',
      );
    }
    final slots = _selectedClassSlots;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _panel(
          child: DropdownButtonFormField<String>(
            initialValue: _selectedSectionId.isEmpty
                ? null
                : _selectedSectionId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Select Class',
              prefixIcon: Icon(Icons.groups_2_outlined),
            ),
            items: [
              for (final section in _sections)
                DropdownMenuItem(
                  value: section.id,
                  child: Text(
                    _sectionLabel(section),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: _saving
                ? null
                : (value) {
                    if (value == null) return;
                    _disposeRows();
                    setState(() {
                      _selectedSectionId = value;
                      _stage = _TimetableStage.selectClass;
                      _rows = [];
                      _selectedDays = {..._workingDays};
                    });
                  },
          ),
        ),
        const SizedBox(height: 14),
        _panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                slots.isEmpty ? 'No Timetable Found' : 'Existing Timetable',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                slots.isEmpty
                    ? 'Start with three rows and apply them to the selected days.'
                    : '${slots.length} saved row${slots.length == 1 ? '' : 's'} across ${slots.map((slot) => _int(slot['day_of_week'])).toSet().length} day(s).',
                style: const TextStyle(color: _muted),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving ? null : () => _openEditor(slots),
                  icon: Icon(
                    slots.isEmpty
                        ? Icons.table_chart_outlined
                        : Icons.edit_outlined,
                  ),
                  label: Text(
                    slots.isEmpty
                        ? 'Create Timetable'
                        : 'View / Edit Timetable',
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _panel(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline_rounded, color: _accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Choose the class first. The Subject dropdown will contain only subjects mapped to that class.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: _ink, height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEditor() {
    final options = _subjectOptionsForSelectedClass;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildDaySelection(),
        const SizedBox(height: 12),
        if (options.isEmpty)
          _panel(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.menu_book_outlined, color: _muted),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'No subjects are mapped to this class yet. Configure class subjects before adding teaching periods.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: _muted, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        if (options.isEmpty) const SizedBox(height: 12),
        _buildSpreadsheet(options),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _saving ? null : _closeEditor,
                icon: const Icon(Icons.close_rounded),
                label: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: _saving ? null : () => _save(options),
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_rounded),
                label: const Text('Save Timetable'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDaySelection() {
    final allSelected = _selectedDays.length == _workingDays.length;
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Apply to days',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: _ink,
                  ),
                ),
              ),
              TextButton(
                onPressed: _saving
                    ? null
                    : () {
                        setState(() {
                          _selectedDays = allSelected
                              ? {_workingDays.first}
                              : {..._workingDays};
                        });
                      },
                child: Text(allSelected ? 'Clear' : 'Select all'),
              ),
            ],
          ),
          Text(
            '${_selectedDays.length} day${_selectedDays.length == 1 ? '' : 's'} selected. Row edits and plus/minus apply to all selected days.',
            style: const TextStyle(color: _muted, fontSize: 12),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final day in _workingDays)
                FilterChip(
                  label: Text(_dayLabels[day - 1]),
                  selected: _selectedDays.contains(day),
                  selectedColor: _accent,
                  checkmarkColor: Colors.white,
                  labelStyle: TextStyle(
                    color: _selectedDays.contains(day) ? Colors.white : _ink,
                    fontWeight: FontWeight.w800,
                  ),
                  onSelected: _saving
                      ? null
                      : (selected) => _toggleDay(day, selected),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSpreadsheet(List<_ClassSubjectOption> options) {
    return _panel(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 14, 12, 10),
            child: Text(
              'Timetable rows',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: _ink,
              ),
            ),
          ),
          const Divider(height: 1, color: _border),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: 680,
              child: Column(
                children: [
                  _spreadsheetHeader(),
                  for (var index = 0; index < _rows.length; index++)
                    _spreadsheetRow(index, options),
                ],
              ),
            ),
          ),
          if (_rows.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: OutlinedButton.icon(
                onPressed: _saving ? null : _addRow,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add row'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _spreadsheetHeader() {
    return Container(
      height: 46,
      color: const Color(0xFFE8F3FF),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: const Row(
        children: [
          SizedBox(
            width: 232,
            child: Text(
              'Time',
              style: TextStyle(fontWeight: FontWeight.w900, color: _ink),
            ),
          ),
          SizedBox(
            width: 320,
            child: Text(
              'Subject',
              style: TextStyle(fontWeight: FontWeight.w900, color: _ink),
            ),
          ),
          SizedBox(width: 88),
        ],
      ),
    );
  }

  Widget _spreadsheetRow(int index, List<_ClassSubjectOption> options) {
    final row = _rows[index];
    final validSubject =
        row.subjectId.isEmpty ||
        options.any((option) => option.id == row.subjectId);
    return Container(
      constraints: const BoxConstraints(minHeight: 72),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(width: 232, child: _timeEditor(row)),
          const SizedBox(width: 8),
          SizedBox(
            width: 312,
            child: _subjectEditor(row, options, validSubject),
          ),
          SizedBox(
            width: 104,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: 'Add row after ${index + 1}',
                  onPressed: _saving ? null : () => _addRow(after: index),
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  color: _accent,
                  style: IconButton.styleFrom(
                    minimumSize: const Size(40, 40),
                    padding: EdgeInsets.zero,
                  ),
                ),
                IconButton(
                  tooltip: 'Remove row ${index + 1}',
                  onPressed: _saving || _rows.length <= 1
                      ? null
                      : () => _removeRow(index),
                  icon: const Icon(Icons.remove_circle_outline_rounded),
                  color: const Color(0xFFB42318),
                  style: IconButton.styleFrom(
                    minimumSize: const Size(40, 40),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _timeEditor(_TimetableRowDraft row) {
    return Row(
      children: [
        Expanded(child: _timeField(row.startController, 'From', row, true)),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 5),
          child: Text('to', style: TextStyle(color: _muted)),
        ),
        Expanded(child: _timeField(row.endController, 'To', row, false)),
      ],
    );
  }

  Widget _timeField(
    TextEditingController controller,
    String label,
    _TimetableRowDraft row,
    bool isStart,
  ) {
    return TextField(
      controller: controller,
      enabled: !_saving,
      keyboardType: TextInputType.datetime,
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9:]'))],
      onChanged: (value) {
        if (isStart) {
          row.startTime = value.trim();
        } else {
          row.endTime = value.trim();
        }
      },
      decoration: InputDecoration(
        labelText: label,
        hintText: 'HH:MM',
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
      ),
    );
  }

  Widget _subjectEditor(
    _TimetableRowDraft row,
    List<_ClassSubjectOption> options,
    bool validSubject,
  ) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: validSubject ? row.subjectId : '',
        isExpanded: true,
        icon: const Icon(Icons.keyboard_arrow_down_rounded),
        hint: const Text('Select subject'),
        items: [
          const DropdownMenuItem(value: '', child: Text('Free Period')),
          for (final option in options)
            DropdownMenuItem(
              value: option.id,
              child: Text(option.name, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: _saving
            ? null
            : (value) {
                setState(() {
                  row.subjectId = value ?? '';
                  row.staffId = _staffIdForSubject(row.subjectId, options);
                });
              },
      ),
    );
  }

  void _openEditor(List<Map<String, dynamic>> existingSlots) {
    _disposeRows();
    final existingDays =
        existingSlots
            .map((slot) => _int(slot['day_of_week']))
            .where((day) => day >= 1 && day <= 6)
            .toSet()
            .toList()
          ..sort();
    final referenceDay = existingDays.isEmpty ? 1 : existingDays.first;
    final initialRows = existingDays.isEmpty
        ? List.generate(3, (_) => _TimetableRowDraft.blank())
        : _rowsForDay(referenceDay);
    setState(() {
      _rows = initialRows;
      _selectedDays = {..._workingDays};
      _stage = _TimetableStage.editor;
    });
  }

  void _toggleDay(int day, bool selected) {
    if (!selected && _selectedDays.length == 1) return;
    final next = {..._selectedDays};
    if (selected) {
      next.add(day);
    } else {
      next.remove(day);
    }
    if (next.length == 1 && _selectedDays.length != 1) {
      final referenceRows = _rowsForDay(next.first);
      _disposeRows();
      _rows = referenceRows.isEmpty
          ? List.generate(3, (_) => _TimetableRowDraft.blank())
          : referenceRows;
    }
    setState(() => _selectedDays = next);
  }

  void _addRow({int? after}) {
    final insertAt = after == null
        ? _rows.length
        : (after + 1).clamp(0, _rows.length);
    setState(() {
      _rows.insert(insertAt, _TimetableRowDraft.blank());
    });
  }

  void _removeRow(int index) {
    if (_rows.length <= 1 || index < 0 || index >= _rows.length) return;
    final removed = _rows.removeAt(index);
    removed.dispose();
    setState(() {});
  }

  Future<void> _save(List<_ClassSubjectOption> options) async {
    final section = _selectedSection;
    final yearId = _currentAcademicYear?.id.trim() ?? '';
    if (section == null || yearId.isEmpty) {
      _showSnack('Select a class with an active academic year before saving.');
      return;
    }
    if (_selectedDays.isEmpty) {
      _showSnack('Select at least one day.');
      return;
    }
    final validation = _validateRows(options);
    if (validation != null) {
      _showSnack(validation);
      return;
    }
    final existingDays = _selectedClassSlots.where(
      (slot) => _selectedDays.contains(_int(slot['day_of_week'])),
    );
    if (existingDays.isNotEmpty) {
      final labels = _selectedDays.toList()..sort();
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Replace selected days?'),
          content: Text(
            'This will replace the existing timetable on ${labels.map((day) => _dayLabels[day - 1]).join(', ')}. Other days will stay unchanged.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Replace days'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    setState(() => _saving = true);
    try {
      await BackendApiClient.instance.replaceTimetableDays(
        sectionId: section.id,
        academicYearId: yearId,
        days: _selectedDays.toList()..sort(),
        rows: [
          for (final row in _rows)
            {
              'start_time': row.startTime,
              'end_time': row.endTime,
              'subject_id': row.subjectId.isEmpty ? null : row.subjectId,
              'staff_id': row.staffId.isEmpty ? null : row.staffId,
            },
        ],
      );
      await _loadData();
      if (!mounted) return;
      setState(() {
        _saving = false;
        _stage = _TimetableStage.selectClass;
        _disposeRows();
        _rows = [];
      });
      _showSnack('Timetable saved and published.');
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showSnack('Unable to save timetable. $error');
    }
  }

  String? _validateRows(List<_ClassSubjectOption> options) {
    if (_rows.isEmpty) return 'Add at least one timetable row.';
    var previousEnd = -1;
    for (var index = 0; index < _rows.length; index++) {
      final row = _rows[index];
      if (!_timePattern.hasMatch(row.startTime) ||
          !_timePattern.hasMatch(row.endTime)) {
        return 'Enter From and To as HH:MM for row ${index + 1}.';
      }
      final start = _clockMinutes(row.startTime)!;
      final end = _clockMinutes(row.endTime)!;
      if (end <= start) {
        return 'To time must be after From time on row ${index + 1}.';
      }
      if (start < previousEnd) {
        return 'Rows must be in ascending order and cannot overlap.';
      }
      if (row.subjectId.isNotEmpty &&
          !options.any((option) => option.id == row.subjectId)) {
        return 'Choose a subject mapped to this class on row ${index + 1}.';
      }
      previousEnd = end;
    }
    return null;
  }

  void _closeEditor() {
    _disposeRows();
    setState(() {
      _rows = [];
      _stage = _TimetableStage.selectClass;
    });
  }

  List<_TimetableRowDraft> _rowsForDay(int day) {
    final slots =
        _selectedClassSlots
            .where((slot) => _int(slot['day_of_week']) == day)
            .toList()
          ..sort(_slotSort);
    return slots.map(_TimetableRowDraft.fromSlot).toList();
  }

  void _disposeRows() {
    for (final row in _rows) {
      row.dispose();
    }
  }

  List<Map<String, dynamic>> get _selectedClassSlots {
    final section = _selectedSection;
    if (section == null) return const [];
    return _slots.where((slot) {
      if (_text(slot['section_id']) != section.id) return false;
      final yearId = _text(slot['academic_year_id']);
      return yearId.isEmpty || yearId == section.academicYearId;
    }).toList();
  }

  List<_ClassSubjectOption> get _subjectOptionsForSelectedClass {
    final section = _selectedSection;
    final yearId = _currentAcademicYear?.id ?? '';
    if (section == null) return const [];
    final subjectById = <String, Map<String, dynamic>>{
      for (final subject in _subjects)
        _text(subject['id'] ?? subject['subject_id']): subject,
    };
    final ids = <String>{};
    for (final mapping in _gradeSubjects) {
      final mappingSection = _text(mapping['section_id']);
      final mappingGrade = _text(mapping['grade_id']);
      final mappingYear = _text(mapping['academic_year_id']);
      final applies =
          (mappingSection.isNotEmpty
              ? mappingSection == section.id
              : mappingGrade == section.gradeId) &&
          (mappingYear.isEmpty || mappingYear == yearId);
      if (!applies) continue;
      final subjectId = _text(
        mapping['subject_id'] ?? _map(mapping['subject'])['id'],
      );
      if (subjectId.isNotEmpty) ids.add(subjectId);
    }
    final options = <_ClassSubjectOption>[];
    for (final id in ids) {
      final subject = subjectById[id];
      final name = _text(
        subject?['subject_name'] ?? subject?['name'] ?? _subjectFromMapping(id),
        fallback: id,
      );
      options.add(
        _ClassSubjectOption(
          id: id,
          name: name,
          staffId: _staffIdForSubject(id, const []),
        ),
      );
    }
    options.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return options;
  }

  String _subjectFromMapping(String subjectId) {
    for (final mapping in _gradeSubjects) {
      if (_text(mapping['subject_id']) != subjectId) continue;
      final nested = _map(mapping['subject']);
      final name = _text(nested['subject_name'] ?? nested['name']);
      if (name.isNotEmpty) return name;
    }
    return subjectId;
  }

  String _staffIdForSubject(
    String subjectId,
    List<_ClassSubjectOption> options,
  ) {
    if (subjectId.isEmpty) return '';
    final section = _selectedSection;
    final yearId = _currentAcademicYear?.id ?? '';
    if (section == null) return '';
    final candidates = _staffSubjects.where((mapping) {
      final mappingSubject = _text(
        mapping['subject_id'] ?? _map(mapping['subject'])['id'],
      );
      if (mappingSubject != subjectId) return false;
      final mappingSection = _text(mapping['section_id']);
      final mappingGrade = _text(mapping['grade_id']);
      final mappingYear = _text(mapping['academic_year_id']);
      return (mappingSection == section.id ||
              (mappingSection.isEmpty && mappingGrade == section.gradeId)) &&
          (mappingYear.isEmpty || mappingYear == yearId);
    }).toList();
    candidates.sort((a, b) {
      int score(Map<String, dynamic> row) {
        return (_text(row['section_id']) == section.id ? 8 : 0) +
            (_text(row['grade_id']) == section.gradeId ? 4 : 0) +
            (_text(row['academic_year_id']) == yearId ? 2 : 0) +
            (row['is_primary'] == true ? 1 : 0);
      }

      return score(b).compareTo(score(a));
    });
    if (candidates.isEmpty) return '';
    return _text(candidates.first['staff_id']);
  }

  SectionModel? get _selectedSection {
    for (final section in _sections) {
      if (section.id == _selectedSectionId) return section;
    }
    return null;
  }

  AcademicYearModel? get _currentAcademicYear {
    final sectionYear = _selectedSection?.academicYearId ?? '';
    for (final year in _academicYears) {
      if (sectionYear.isNotEmpty && year.id == sectionYear) return year;
    }
    for (final year in _academicYears) {
      if (year.isCurrent) return year;
    }
    return _academicYears.isEmpty ? null : _academicYears.first;
  }

  String get _selectedClassLabel => _sectionLabel(_selectedSection);

  String _sectionLabel(SectionModel? section) {
    if (section == null) return 'Class';
    final parts = [
      section.gradeName.trim(),
      section.sectionName.trim(),
    ].where((part) => part.isNotEmpty).toList();
    return parts.isEmpty ? 'Class' : parts.join(' - ');
  }

  Widget _panel({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(14),
  }) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border),
      ),
      child: child,
    );
  }

  Widget _emptyState({
    required IconData icon,
    required String title,
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return _panel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 42, color: _muted),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: _ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _muted),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 14),
            OutlinedButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ],
      ),
    );
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  static int _slotSort(Map<String, dynamic> a, Map<String, dynamic> b) {
    final day = _int(a['day_of_week']).compareTo(_int(b['day_of_week']));
    if (day != 0) return day;
    final period = _int(a['period_number']).compareTo(_int(b['period_number']));
    if (period != 0) return period;
    return _text(a['start_time']).compareTo(_text(b['start_time']));
  }

  static int? _clockMinutes(String value) {
    final match = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(value.trim());
    if (match == null) return null;
    final hours = int.tryParse(match.group(1)!);
    final minutes = int.tryParse(match.group(2)!);
    if (hours == null || minutes == null) return null;
    return hours * 60 + minutes;
  }

  static Map<String, dynamic> _map(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.map((key, val) => MapEntry('$key', val));
    return const {};
  }

  static int _int(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}') ?? 0;
  }

  static String _text(Object? value, {String fallback = ''}) {
    final text = '${value ?? ''}'.trim();
    return text.isEmpty || text == 'null' ? fallback : text;
  }
}

class _TimetableRowDraft {
  String startTime;
  String endTime;
  String subjectId;
  String staffId;
  final TextEditingController startController;
  final TextEditingController endController;

  _TimetableRowDraft({
    required this.startTime,
    required this.endTime,
    required this.subjectId,
    required this.staffId,
  }) : startController = TextEditingController(text: startTime),
       endController = TextEditingController(text: endTime);

  factory _TimetableRowDraft.blank() {
    return _TimetableRowDraft(
      startTime: '',
      endTime: '',
      subjectId: '',
      staffId: '',
    );
  }

  factory _TimetableRowDraft.fromSlot(Map<String, dynamic> slot) {
    final slotType = _AdminTimetableScreenState._text(slot['slot_type']);
    return _TimetableRowDraft(
      startTime: _AdminTimetableScreenState._text(slot['start_time']),
      endTime: _AdminTimetableScreenState._text(slot['end_time']),
      subjectId: slotType == 'free' || slotType == 'break'
          ? ''
          : _AdminTimetableScreenState._text(slot['subject_id']),
      staffId: _AdminTimetableScreenState._text(slot['staff_id']),
    );
  }

  void dispose() {
    startController.dispose();
    endController.dispose();
  }
}

class _ClassSubjectOption {
  final String id;
  final String name;
  final String staffId;

  const _ClassSubjectOption({
    required this.id,
    required this.name,
    required this.staffId,
  });
}
