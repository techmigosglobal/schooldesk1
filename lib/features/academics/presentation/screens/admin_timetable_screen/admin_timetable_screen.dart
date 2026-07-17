import 'package:flutter/material.dart';

import 'package:schooldesk1/core/navigation/role_nav_indices.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/widgets/app_navigation.dart';
import 'package:schooldesk1/core/desktop/desktop_platform.dart';

enum _ManualTimetableStage { selectClass, settings, editor, preview }

class AdminTimetableScreen extends StatefulWidget {
  const AdminTimetableScreen({super.key});

  @override
  State<AdminTimetableScreen> createState() => _AdminTimetableScreenState();
}

class _AdminTimetableScreenState extends State<AdminTimetableScreen> {
  static const _accent = Color(0xFF0877D8);
  static const _ink = Color(0xFF172B3A);
  static const _muted = Color(0xFF667989);
  static const _bg = Color(0xFFF3F8FC);
  static const _border = Color(0xFFDDE7F0);

  static const _dayShortLabels = <String>[
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
  ];
  static const _dayFullLabels = <String>[
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];

  final _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _loading = true;
  bool _saving = false;
  String? _error;
  int _selectedOverviewDay = 1;
  String _selectedSectionId = '';
  _ManualTimetableStage _stage = _ManualTimetableStage.selectClass;
  _TimetableSettings _settings = _TimetableSettings.defaults();
  List<_ManualTimetableCell> _draftCells = [];
  final Set<int> _selectedEditorDays = {
    DateTime.now().weekday.clamp(1, 6).toInt(),
  };

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
        _slots = (results[2] as List<Map<String, dynamic>>)..sort(_slotSort);
        _subjects = results[3] as List<Map<String, dynamic>>;
        _gradeSubjects = results[4] as List<Map<String, dynamic>>;
        _staffSubjects = results[5] as List<Map<String, dynamic>>;
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
        _error = 'Unable to load timetable setup. $error';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = DesktopPlatform.isDesktopLayout(context);
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _bg,
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
            constraints: BoxConstraints(maxWidth: isDesktop ? 980 : 460),
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
                      padding: const EdgeInsets.fromLTRB(18, 8, 18, 92),
                      sliver: SliverToBoxAdapter(child: _buildStage()),
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
    final title = switch (_stage) {
      _ManualTimetableStage.selectClass => 'Timetable Management',
      _ManualTimetableStage.settings => 'Create Timetable',
      _ManualTimetableStage.editor => '$_selectedClassLabel Timetable',
      _ManualTimetableStage.preview => 'Timetable Preview',
    };
    final subtitle = switch (_stage) {
      _ManualTimetableStage.selectClass => 'Select class to continue',
      _ManualTimetableStage.settings => _selectedClassLabel,
      _ManualTimetableStage.editor => 'Draft',
      _ManualTimetableStage.preview => _selectedClassLabel,
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 10, 12, 8),
      child: Row(
        children: [
          if (!DesktopPlatform.isDesktopLayout(context) ||
              _stage != _ManualTimetableStage.selectClass)
            IconButton(
              tooltip: _stage == _ManualTimetableStage.selectClass
                  ? 'Menu'
                  : 'Back',
              onPressed: _saving
                  ? null
                  : _stage == _ManualTimetableStage.selectClass
                  ? () => _scaffoldKey.currentState?.openDrawer()
                  : _goBack,
              icon: Icon(
                _stage == _ManualTimetableStage.selectClass
                    ? Icons.menu_rounded
                    : Icons.arrow_back_ios_new_rounded,
                size: 21,
              ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: _ink,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: _ink.withOpacity(0.6)),
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

  Widget _buildStage() {
    return switch (_stage) {
      _ManualTimetableStage.selectClass => _buildSelectClass(),
      _ManualTimetableStage.settings => _buildSettings(),
      _ManualTimetableStage.editor => _buildManualEditor(),
      _ManualTimetableStage.preview => _buildPreview(),
    };
  }

  Widget _buildSelectClass() {
    if (_sections.isEmpty) {
      return _emptyState(
        icon: Icons.groups_2_outlined,
        title: 'No active classes found',
        message: 'Create active classes before setting a timetable.',
      );
    }
    final selectedSlots = _selectedClassSlots;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle('Select Class'),
        const SizedBox(height: 10),
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
                    setState(() {
                      _selectedSectionId = value;
                      _draftCells = [];
                      _settings = _TimetableSettings.defaults();
                    });
                  },
          ),
        ),
        const SizedBox(height: 16),
        if (selectedSlots.isEmpty)
          _statusCard(
            icon: Icons.event_busy_outlined,
            title: 'No Timetable Found',
            lines: const ['This class does not have a timetable yet.'],
            buttonLabel: 'Create Timetable',
            onPressed: _openSettings,
          )
        else
          Column(
            children: [
              _statusCard(
                icon: Icons.event_available_outlined,
                title: 'Existing Timetable',
                lines: [
                  'Last updated: ${_lastUpdatedLabel(selectedSlots)}',
                  'Status: Active',
                  '${_teachingPeriodCount(selectedSlots)} periods, ${_breakCount(selectedSlots)} breaks',
                ],
                buttonLabel: 'View / Edit Timetable',
                onPressed: _openExistingTimetable,
                secondaryButtonLabel: 'Delete Whole Timetable',
                onSecondaryPressed: _deleteWholeTimetable,
              ),
              const SizedBox(height: 12),
              _panel(child: _buildSavedTimetablePreview(selectedSlots)),
            ],
          ),
      ],
    );
  }

  Widget _buildSavedTimetablePreview(List<Map<String, dynamic>> slots) {
    final availableDays =
        slots
            .map((slot) => _int(slot['day_of_week']))
            .where((day) => day >= 1 && day <= _dayShortLabels.length)
            .toSet()
            .toList()
          ..sort();
    if (availableDays.isEmpty) return const SizedBox.shrink();

    final activeDay = availableDays.contains(_selectedOverviewDay)
        ? _selectedOverviewDay
        : availableDays.first;
    final daySlots =
        slots.where((slot) => _int(slot['day_of_week']) == activeDay).toList()
          ..sort(_slotSort);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Current timetable',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ),
            Text(
              '${daySlots.length} slots',
              style: const TextStyle(
                color: _muted,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final day in availableDays)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(_dayShortLabels[day - 1]),
                    selected: day == activeDay,
                    selectedColor: const Color(0xFF2563EB),
                    backgroundColor: const Color(0xFFF1F5F9),
                    side: const BorderSide(color: Color(0xFFBFDBFE)),
                    labelStyle: TextStyle(
                      color: day == activeDay
                          ? Colors.white
                          : const Color(0xFF1E3A5F),
                      fontWeight: FontWeight.w800,
                    ),
                    onSelected: (_) =>
                        setState(() => _selectedOverviewDay = day),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (final slot in daySlots)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _savedTimetableSlotRow(slot),
          ),
      ],
    );
  }

  Widget _savedTimetableSlotRow(Map<String, dynamic> slot) {
    final isBreak = _isBreakSlot(slot);
    final slotColor = isBreak
        ? const Color(0xFFF59E0B)
        : const Color(0xFF2563EB);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isBreak ? const Color(0xFFFFFBEB) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isBreak ? const Color(0xFFFDE68A) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 32,
            decoration: BoxDecoration(
              color: slotColor,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 102,
            child: Text(
              '${_text(slot['start_time'])}–${_text(slot['end_time'])}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          Expanded(
            child: Text(
              _subjectName(slot),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isBreak
                    ? const Color(0xFF92400E)
                    : const Color(0xFF172033),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Icon(
            isBreak ? Icons.coffee_outlined : Icons.menu_book_outlined,
            size: 18,
            color: slotColor,
          ),
        ],
      ),
    );
  }

  Widget _buildSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle('Basic Timing'),
        const SizedBox(height: 10),
        _panel(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _timeField(
                      label: 'Start Time',
                      value: _settings.startTime,
                      onTap: () => _pickTime(
                        initial: _settings.startTime,
                        onPicked: (value) =>
                            setState(() => _settings.startTime = value),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _timeField(
                      label: 'End Time',
                      value: _settings.endTime,
                      onTap: () => _pickTime(
                        initial: _settings.endTime,
                        onPicked: (value) =>
                            setState(() => _settings.endTime = value),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _settings.periodDurationMinutes,
                      decoration: const InputDecoration(
                        labelText: 'Period Dur',
                      ),
                      items: const [30, 35, 40, 45, 50, 60]
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text('$value mins'),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _settings.periodDurationMinutes = value);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _settings.gapDurationMinutes,
                      decoration: const InputDecoration(labelText: 'Gap'),
                      items: const [0, 5, 10, 15]
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text('$value mins'),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _settings.gapDurationMinutes = value);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _buildBreakSettings(),
        const SizedBox(height: 18),
        _sectionTitle('Working Days'),
        const SizedBox(height: 10),
        _panel(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var day = 1; day <= 6; day++)
                FilterChip(
                  label: Text(
                    _dayShortLabels[day - 1],
                    style: TextStyle(
                      color: _settings.workingDays.contains(day)
                          ? Colors.white
                          : const Color(0xFF1E3A5F),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  selected: _settings.workingDays.contains(day),
                  selectedColor: const Color(0xFF2563EB),
                  backgroundColor: const Color(0xFFF1F5F9),
                  checkmarkColor: Colors.white,
                  side: const BorderSide(color: Color(0xFFBFDBFE)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _settings.workingDays.add(day);
                      } else if (_settings.workingDays.length > 1) {
                        _settings.workingDays.remove(day);
                      }
                      for (final item in _settings.breaks) {
                        item.keepDaysInside(_settings.workingDays);
                      }
                    });
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: _createEditableTimetable,
          icon: const Icon(Icons.table_chart_outlined),
          label: const Text('Create Editable Timetable'),
        ),
      ],
    );
  }

  Widget _buildBreakSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: _sectionTitle('Breaks')),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _settings.breaks.add(
                    _TimetableBreakDraft(
                      name: 'Short Break',
                      startTime: '10:40',
                      durationMinutes: 10,
                      days: _settings.workingDays,
                    ),
                  );
                });
              },
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add Break'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_settings.breaks.isEmpty)
          _panel(child: const Text('Breaks are optional.'))
        else
          for (final item in _settings.breaks)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _panel(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: item.name,
                            decoration: const InputDecoration(
                              labelText: 'Break Name',
                            ),
                            onChanged: (value) => item.name = value,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Remove',
                          onPressed: () {
                            setState(() => _settings.breaks.remove(item));
                          },
                          icon: const Icon(Icons.delete_outline_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _timeField(
                            label: 'Start',
                            value: item.startTime,
                            onTap: () => _pickTime(
                              initial: item.startTime,
                              onPicked: (value) =>
                                  setState(() => item.startTime = value),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            initialValue: item.durationMinutes,
                            decoration: const InputDecoration(
                              labelText: 'Duration',
                            ),
                            items: const [5, 10, 15, 20, 30, 45]
                                .map(
                                  (value) => DropdownMenuItem(
                                    value: value,
                                    child: Text('$value mins'),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() => item.durationMinutes = value);
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }

  Widget _buildManualEditor() {
    final subjectOptions = _subjectOptionsForSelectedClass;
    // Class teacher stays fixed: classTeacherName
    final classTeacherName = _selectedSection?.classTeacherName ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildEditorActions(preview: false),
        const SizedBox(height: 12),
        _hintText(
          'Class teacher stays fixed: $classTeacherName. Choose a subject and set each row\'s own start and end time.',
        ),
        const SizedBox(height: 12),
        _buildDayWiseEditor(subjectOptions),
        const SizedBox(height: 14),
        _sectionTitle('Week-wise Timetable'),
        const SizedBox(height: 8),
        _hintText('Swipe horizontally to edit week-wise cells.'),
        const SizedBox(height: 10),
        _buildTimetableTable(editable: true, subjectOptions: subjectOptions),
        const SizedBox(height: 14),
        _buildBreakSummary(),
      ],
    );
  }

  Widget _buildPreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildEditorActions(preview: true),
        const SizedBox(height: 12),
        _sectionTitle('Day-wise Timetable'),
        const SizedBox(height: 8),
        _buildDaySelector(),
        const SizedBox(height: 10),
        _buildDayPreview(_subjectOptionsForSelectedClass),
        const SizedBox(height: 14),
        _sectionTitle('Week-wise Timetable'),
        const SizedBox(height: 8),
        _hintText('Swipe horizontally to review the full week.'),
        const SizedBox(height: 10),
        _buildTimetableTable(
          editable: false,
          subjectOptions: _subjectOptionsForSelectedClass,
        ),
        const SizedBox(height: 14),
        _panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle('Summary'),
              const SizedBox(height: 10),
              _summaryLine('Class', _selectedClassLabel),
              _summaryLine('Working days', _workingDaysLabel),
              _summaryLine('Total periods/day', '$_maxTeachingPeriodsPerDay'),
              _summaryLine('Breaks', '${_settings.breaks.length}'),
              _summaryLine('Status', 'Ready to Save'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEditorActions({required bool preview}) {
    return _panel(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 620;
          final editAction = OutlinedButton.icon(
            onPressed: _saving
                ? null
                : preview
                ? () => setState(() => _stage = _ManualTimetableStage.editor)
                : _resetDraft,
            icon: Icon(
              preview ? Icons.edit_outlined : Icons.refresh_rounded,
              size: 18,
            ),
            label: Text(preview ? 'Continue Editing' : 'Reset Draft'),
          );
          final previewAction = OutlinedButton.icon(
            onPressed: _draftCells.isEmpty
                ? null
                : () => setState(() => _stage = _ManualTimetableStage.preview),
            icon: const Icon(Icons.visibility_outlined, size: 18),
            label: const Text('Preview'),
          );
          final deleteAction = OutlinedButton.icon(
            onPressed: _saving || _selectedSectionId.isEmpty
                ? null
                : _deleteWholeTimetable,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFB42318),
            ),
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            label: const Text('Delete Whole Timetable'),
          );
          final saveAction = FilledButton.icon(
            onPressed: _saving || _draftCells.isEmpty
                ? null
                : _saveManualTimetable,
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_rounded, size: 18),
            label: const Text('Save Timetable'),
          );

          if (!compact) {
            return Row(
              children: [
                editAction,
                if (!preview) ...[const SizedBox(width: 8), previewAction],
                const Spacer(),
                deleteAction,
                const SizedBox(width: 8),
                saveAction,
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _sectionTitle(preview ? 'Review timetable' : 'Edit timetable'),
              const SizedBox(height: 10),
              if (preview)
                SizedBox(width: double.infinity, child: editAction)
              else
                Row(
                  children: [
                    Expanded(child: editAction),
                    const SizedBox(width: 8),
                    Expanded(child: previewAction),
                  ],
                ),
              const SizedBox(height: 8),
              SizedBox(width: double.infinity, child: deleteAction),
              const SizedBox(height: 8),
              SizedBox(width: double.infinity, child: saveAction),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDayWiseEditor(List<_ClassSubjectOption> subjectOptions) {
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionTitle('Day-wise Timetable'),
          const SizedBox(height: 8),
          _buildDaySelector(),
          const SizedBox(height: 10),
          if (_dayCells.isEmpty)
            _hintText(
              _selectedEditorDays.isEmpty
                  ? 'Select one or more days to edit.'
                  : 'No periods for $_selectedDaysLabel.',
            )
          else
            for (final cell in _dayCells)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _dayPeriodRow(cell, subjectOptions, editable: true),
              ),
        ],
      ),
    );
  }

  Widget _buildDayPreview(List<_ClassSubjectOption> subjectOptions) {
    if (_dayCells.isEmpty) {
      return _panel(
        child: _hintText(
          _selectedEditorDays.isEmpty
              ? 'Select one or more days to preview.'
              : 'No periods for $_selectedDaysLabel.',
        ),
      );
    }
    return _panel(
      child: Column(
        children: [
          for (final cell in _dayCells)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _dayPeriodRow(cell, subjectOptions, editable: false),
            ),
        ],
      ),
    );
  }

  Widget _buildDaySelector() {
    final days = _draftCells.map((cell) => cell.day).toSet().toList()..sort();
    final visibleDays = days.isEmpty
        ? (_settings.workingDays.toList()..sort())
        : days;
    final allSelected = visibleDays.every(
      (day) => _selectedEditorDays.contains(day),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _selectedEditorDays.isEmpty
                    ? 'Tap days to edit'
                    : '${_selectedEditorDays.length} day(s) selected — changes apply to all',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: _selectedEditorDays.length > 1 ? _accent : _muted,
                ),
              ),
            ),
            InkWell(
              onTap: () {
                setState(() {
                  if (allSelected) {
                    _selectedEditorDays.clear();
                    if (visibleDays.isNotEmpty) {
                      _selectedEditorDays.add(visibleDays.first);
                    }
                  } else {
                    _selectedEditorDays
                      ..clear()
                      ..addAll(visibleDays);
                  }
                });
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  allSelected ? 'Clear' : 'Select All',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: _accent,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final day in visibleDays)
              FilterChip(
                label: Text(
                  _dayShortLabels[day - 1],
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: _selectedEditorDays.contains(day)
                        ? Colors.white
                        : _ink,
                  ),
                ),
                selected: _selectedEditorDays.contains(day),
                selectedColor: _accent,
                checkmarkColor: Colors.white,
                backgroundColor: const Color(0xFFEBF0F7),
                side: BorderSide(
                  color: _selectedEditorDays.contains(day)
                      ? _accent
                      : const Color(0xFF9BACC0),
                  width: 2,
                ),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedEditorDays.add(day);
                    } else if (_selectedEditorDays.length > 1) {
                      _selectedEditorDays.remove(day);
                    }
                  });
                },
              ),
          ],
        ),
      ],
    );
  }

  Widget _dayPeriodRow(
    _ManualTimetableCell cell,
    List<_ClassSubjectOption> subjectOptions, {
    required bool editable,
  }) {
    final validSubject = subjectOptions.any(
      (subject) => subject.id == cell.subjectId,
    );
    final title = cell.isBreak ? cell.label : 'P${cell.periodNumber}';
    return Material(
      color: const Color(0xFFF7FAFD),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 390;
            final timing = _dayRowTimingEditor(cell, editable: editable);
            final subject = _dayRowSubjectEditor(
              cell,
              subjectOptions,
              validSubject: validSubject,
              editable: editable,
            );
            final actions = editable
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Add period after $title',
                        onPressed: () => _addPeriodAfter(cell),
                        icon: const Icon(Icons.add_circle_outline_rounded),
                      ),
                      IconButton(
                        tooltip: 'Delete $title',
                        onPressed: () => _deleteDayCell(cell),
                        icon: const Icon(Icons.delete_outline_rounded),
                      ),
                    ],
                  )
                : const SizedBox.shrink();

            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            color: _ink,
                          ),
                        ),
                      ),
                      actions,
                    ],
                  ),
                  const SizedBox(height: 8),
                  timing,
                  const SizedBox(height: 8),
                  subject,
                ],
              );
            }

            return Row(
              children: [
                SizedBox(
                  width: 122,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: _ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      timing,
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child: subject),
                actions,
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _dayRowTimingEditor(
    _ManualTimetableCell cell, {
    required bool editable,
  }) {
    if (!editable) {
      return Text(
        '${cell.startTime} - ${cell.endTime}',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: _muted,
        ),
      );
    }
    return Row(
      children: [
        Expanded(
          child: _compactTimeButton(
            tooltip: 'Start time for P${cell.periodNumber}',
            value: cell.startTime,
            onPressed: () => _pickDayCellTime(cell, isStart: true),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 3),
          child: Text('–', style: TextStyle(color: _muted)),
        ),
        Expanded(
          child: _compactTimeButton(
            tooltip: 'End time for P${cell.periodNumber}',
            value: cell.endTime,
            onPressed: () => _pickDayCellTime(cell, isStart: false),
          ),
        ),
      ],
    );
  }

  Widget _compactTimeButton({
    required String tooltip,
    required String value,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 34),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          visualDensity: VisualDensity.compact,
        ),
        child: Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.fade,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  Widget _dayRowSubjectEditor(
    _ManualTimetableCell cell,
    List<_ClassSubjectOption> subjectOptions, {
    required bool validSubject,
    required bool editable,
  }) {
    if (cell.isBreak || !editable) {
      return Text(
        _subjectLabel(cell, subjectOptions),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w800, color: _ink),
      );
    }
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: validSubject ? cell.subjectId : '',
        isExpanded: true,
        items: [
          const DropdownMenuItem(value: '', child: Text('Free Period')),
          for (final subject in subjectOptions)
            DropdownMenuItem(
              value: subject.id,
              child: Text(subject.name, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: (value) {
          setState(() {
            final newSubjectId = value ?? '';
            for (final day in _selectedEditorDays) {
              final target = _cellFor(day, cell.periodNumber);
              if (target == null || target.isBreak) continue;
              target.subjectId = newSubjectId;
              target.staffId = _teacherIdForSubject(newSubjectId);
              target.slotType = newSubjectId.isEmpty ? 'free' : 'regular';
            }
          });
        },
      ),
    );
  }

  Widget _buildTimetableTable({
    required bool editable,
    required List<_ClassSubjectOption> subjectOptions,
  }) {
    final days = _draftCells.map((cell) => cell.day).toSet().toList()..sort();
    final columns = _columns;
    if (days.isEmpty || columns.isEmpty) {
      return _emptyState(
        icon: Icons.table_chart_outlined,
        title: 'No editable grid yet',
        message: 'Create timing settings to build a timetable grid.',
      );
    }
    return _panel(
      padding: EdgeInsets.zero,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Column(
              children: [
                _tableHeaderCell('Day / Period', height: 66),
                for (final day in days)
                  _tableBodyCell(_dayFullLabels[day - 1], height: 62),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      for (final column in columns) _periodHeaderCell(column),
                    ],
                  ),
                  for (final day in days)
                    Row(
                      children: [
                        for (final column in columns)
                          _editableCell(
                            _cellFor(day, column.periodNumber),
                            editable,
                            subjectOptions,
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _periodHeaderCell(_ManualTimetableCell column) {
    final title = column.isBreak ? column.label : 'P${column.periodNumber}';
    return Container(
      width: 104,
      height: 66,
      padding: const EdgeInsets.all(8),
      decoration: const BoxDecoration(
        color: Color(0xFFE8F3FF),
        border: Border(left: BorderSide(color: _border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w900, color: _ink),
          ),
          const SizedBox(height: 2),
          Text(
            column.startTime,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: _muted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _editableCell(
    _ManualTimetableCell? cell,
    bool editable,
    List<_ClassSubjectOption> subjectOptions,
  ) {
    if (cell == null) {
      return _tableBodyCell('', width: 104, height: 62);
    }
    if (cell.isBreak) {
      return _tableBodyCell(cell.label, width: 104, height: 62, soft: true);
    }
    if (!editable) {
      return _tableBodyCell(
        _subjectLabel(cell, subjectOptions),
        width: 104,
        height: 62,
      );
    }
    final validSubject = subjectOptions.any(
      (subject) => subject.id == cell.subjectId,
    );
    return Container(
      width: 104,
      height: 62,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          left: BorderSide(color: _border),
          top: BorderSide(color: _border),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: validSubject ? cell.subjectId : '',
          isExpanded: true,
          iconSize: 18,
          items: [
            const DropdownMenuItem(value: '', child: Text('Free Period')),
            for (final subject in subjectOptions)
              DropdownMenuItem(
                value: subject.id,
                child: Text(subject.name, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (value) {
            setState(() {
              cell.subjectId = value ?? '';
              cell.staffId = _teacherIdForSubject(cell.subjectId);
              cell.slotType = cell.subjectId.isEmpty ? 'free' : 'regular';
            });
          },
        ),
      ),
    );
  }

  Widget _buildBreakSummary() {
    final breaks = _draftCells.where((cell) => cell.isBreak).toList();
    if (breaks.isEmpty) return const SizedBox.shrink();
    final unique = <String>{};
    for (final cell in breaks) {
      unique.add('${cell.label}: ${cell.startTime} - ${cell.endTime}');
    }
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final label in unique)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: _ink,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _statusCard({
    required IconData icon,
    required String title,
    required List<String> lines,
    required String buttonLabel,
    required VoidCallback onPressed,
    String? secondaryButtonLabel,
    VoidCallback? onSecondaryPressed,
  }) {
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _accent.withAlpha(24),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: _accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: _ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Text(
                line,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: _muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton(onPressed: onPressed, child: Text(buttonLabel)),
                if (secondaryButtonLabel != null &&
                    onSecondaryPressed != null) ...[
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: onSecondaryPressed,
                    child: Text(secondaryButtonLabel),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _panel({required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7FA6BD).withAlpha(28),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
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
          Icon(icon, color: _muted, size: 34),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: _ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: _muted,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 12),
            FilledButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w900,
        color: _ink,
      ),
    );
  }

  Widget _hintText(String text) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: _muted,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  Widget _timeField({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.schedule_rounded),
        ),
        child: Text(value),
      ),
    );
  }

  Widget _tableHeaderCell(
    String text, {
    double width = 96,
    double height = 66,
  }) {
    return Container(
      width: width,
      height: height,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.all(8),
      decoration: const BoxDecoration(color: Color(0xFFE8F3FF)),
      child: Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w900, color: _ink),
      ),
    );
  }

  Widget _tableBodyCell(
    String text, {
    double width = 96,
    double height = 62,
    bool soft = false,
  }) {
    return Container(
      width: width,
      height: height,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: soft ? const Color(0xFFF7FAFD) : Colors.white,
        border: const Border(top: BorderSide(color: _border)),
      ),
      child: Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: soft ? _muted : _ink,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _summaryLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: _muted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w900, color: _ink),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickTime({
    required String initial,
    required ValueChanged<String> onPicked,
  }) async {
    final minutes = _clockMinutes(initial) ?? 9 * 60;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
    );
    if (picked == null) return;
    onPicked(_formatMinutes(picked.hour * 60 + picked.minute));
  }

  void _openSettings() {
    setState(() {
      _settings = _TimetableSettings.defaults();
      _draftCells = [];
      _selectedEditorDays
        ..clear()
        ..add(_settings.workingDays.first);
      _stage = _ManualTimetableStage.settings;
    });
  }

  void _openExistingTimetable() {
    final existing = _selectedClassSlots;
    setState(() {
      _settings = _settingsFromSlots(existing);
      _draftCells = existing.map(_ManualTimetableCell.fromSlot).toList()
        ..sort(_cellSort);
      _selectedEditorDays
        ..clear()
        ..add(_firstDraftDay);
      _stage = _ManualTimetableStage.editor;
    });
  }

  void _createEditableTimetable() {
    final validation = _validateSettings();
    if (validation != null) {
      _showSnack(validation);
      return;
    }
    final draft = _buildDraftFromSettings();
    if (draft.isEmpty) {
      _showSnack('No periods fit inside the selected timings.');
      return;
    }
    setState(() {
      _draftCells = draft;
      _selectedEditorDays
        ..clear()
        ..add(_firstDraftDay);
      _stage = _ManualTimetableStage.editor;
    });
  }

  List<_ManualTimetableCell> _buildDraftFromSettings() {
    final cells = <_ManualTimetableCell>[];
    final start = _clockMinutes(_settings.startTime)!;
    final end = _clockMinutes(_settings.endTime)!;
    for (final day in _settings.workingDays.toList()..sort()) {
      final dayBreaks = _breakCellsForDay(day)..sort(_cellSort);
      var cursor = start;
      var period = 1;
      var breakIndex = 0;
      while (cursor + _settings.periodDurationMinutes <= end && period < 30) {
        if (breakIndex < dayBreaks.length) {
          final nextBreak = dayBreaks[breakIndex];
          final breakStart = _clockMinutes(nextBreak.startTime) ?? cursor;
          final breakEnd = _clockMinutes(nextBreak.endTime) ?? breakStart;
          if (cursor >= breakStart) {
            cells.add(nextBreak.copyWith(periodNumber: period));
            cursor = breakEnd + _settings.gapDurationMinutes;
            period++;
            breakIndex++;
            continue;
          }
          if (cursor + _settings.periodDurationMinutes > breakStart) {
            cursor = breakStart;
            continue;
          }
        }
        cells.add(
          _ManualTimetableCell(
            day: day,
            periodNumber: period,
            startTime: _formatMinutes(cursor),
            endTime: _formatMinutes(cursor + _settings.periodDurationMinutes),
            slotType: 'free',
            subjectId: '',
            staffId: '',
            label: 'Free Period',
          ),
        );
        cursor +=
            _settings.periodDurationMinutes + _settings.gapDurationMinutes;
        period++;
      }
    }
    return cells..sort(_cellSort);
  }

  List<_ManualTimetableCell> _breakCellsForDay(int day) {
    return _settings.breaks.where((item) => item.days.contains(day)).map((
      item,
    ) {
      final start = _clockMinutes(item.startTime) ?? 0;
      return _ManualTimetableCell(
        day: day,
        periodNumber: 0,
        startTime: _formatMinutes(start),
        endTime: _formatMinutes(start + item.durationMinutes),
        slotType: 'break',
        subjectId: '',
        staffId: '',
        label: item.name.trim().isEmpty ? 'Break' : item.name.trim(),
      );
    }).toList();
  }

  Future<void> _deleteWholeTimetable() async {
    if (_selectedSectionId.isEmpty) {
      _showSnack('Select a class before deleting its timetable.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete whole timetable?'),
        content: Text(
          'This will remove every timetable slot for $_selectedClassLabel.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _saving = true);
    try {
      final api = BackendApiClient.instance;
      await api.deleteTimetableSlotsForSection(
        sectionId: _selectedSectionId,
        academicYearId: _currentAcademicYear?.id ?? '',
      );
      await _loadData();
      if (!mounted) return;
      setState(() {
        _saving = false;
        _draftCells = [];
        _settings = _TimetableSettings.defaults();
        _stage = _ManualTimetableStage.selectClass;
      });
      _showSnack('Whole timetable deleted.');
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showSnack('Unable to delete timetable. $error');
    }
  }

  Future<void> _saveManualTimetable() async {
    if (_selectedSectionId.isEmpty || _currentAcademicYear == null) {
      _showSnack('Select class and academic year before saving.');
      return;
    }
    final validation = _validateDraftCells();
    if (validation != null) {
      _showSnack(validation);
      return;
    }
    setState(() => _saving = true);
    try {
      final api = BackendApiClient.instance;
      final existingSlots = _selectedClassSlots.where((slot) {
        final yearId = _text(slot['academic_year_id']);
        return yearId.isEmpty || yearId == _currentAcademicYear!.id;
      }).toList();
      for (final slot in existingSlots) {
        await api.deleteTimetableSlot(_text(slot['id']));
      }
      for (final cell in _draftCells) {
        await api.createTimetableSlot(
          sectionId: _selectedSectionId,
          academicYearId: _currentAcademicYear!.id,
          dayOfWeek: cell.day,
          periodNumber: cell.periodNumber,
          subjectId: cell.isRegular ? cell.subjectId : '',
          staffId: cell.staffId,
          startTime: cell.startTime,
          endTime: cell.endTime,
          slotType: cell.slotType,
        );
      }
      await _loadData();
      if (!mounted) return;
      setState(() {
        _saving = false;
        _stage = _ManualTimetableStage.selectClass;
        _draftCells = [];
      });
      _showSnack('Timetable saved and published.');
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showSnack('Unable to save timetable. $error');
    }
  }

  void _resetDraft() {
    if (_selectedClassSlots.isNotEmpty) {
      _openExistingTimetable();
    } else {
      setState(() {
        _draftCells = _buildDraftFromSettings();
        _selectedEditorDays
          ..clear()
          ..add(_firstDraftDay);
      });
    }
  }

  void _deleteDayCell(_ManualTimetableCell cell) {
    setState(() {
      _draftCells.remove(cell);
      _renumberDay(cell.day);
      if (_dayCells.isEmpty) {
        _selectedEditorDays
          ..clear()
          ..add(_firstDraftDay);
      }
    });
  }

  Future<void> _pickDayCellTime(
    _ManualTimetableCell cell, {
    required bool isStart,
  }) async {
    await _pickTime(
      initial: isStart ? cell.startTime : cell.endTime,
      onPicked: (value) {
        final selectedValue = _clockMinutes(value);
        if (selectedValue == null) return;
        final targets = [
          for (final day in _selectedEditorDays)
            if (_cellFor(day, cell.periodNumber) case final target?) target,
        ];
        final hasInvalidRange = targets.any((target) {
          final otherValue = _clockMinutes(
            isStart ? target.endTime : target.startTime,
          );
          return otherValue == null ||
              (isStart
                  ? selectedValue >= otherValue
                  : selectedValue <= otherValue);
        });
        if (hasInvalidRange) {
          _showSnack(
            isStart
                ? 'Start time must be before the end time.'
                : 'End time must be after the start time.',
          );
          return;
        }
        setState(() {
          for (final target in targets) {
            if (isStart) {
              target.startTime = value;
            } else {
              target.endTime = value;
            }
          }
          _draftCells.sort(_cellSort);
        });
      },
    );
  }

  void _addPeriodAfter(_ManualTimetableCell cell) {
    var added = 0;
    setState(() {
      for (final day in _selectedEditorDays.toList()..sort()) {
        final anchor = _cellFor(day, cell.periodNumber);
        if (anchor == null) continue;
        final start = _clockMinutes(anchor.endTime) ?? 9 * 60;
        final duration =
            (_clockMinutes(anchor.endTime) ?? start) -
            (_clockMinutes(anchor.startTime) ?? start);
        final newPeriod = anchor.periodNumber + 1;
        for (final existing in _draftCells) {
          if (existing.day == day && existing.periodNumber >= newPeriod) {
            existing.periodNumber++;
          }
        }
        _draftCells.add(
          _ManualTimetableCell(
            day: day,
            periodNumber: newPeriod,
            startTime: _formatMinutes(start),
            endTime: _formatMinutes(
              start +
                  (duration > 0 ? duration : _settings.periodDurationMinutes),
            ),
            slotType: 'free',
            subjectId: '',
            staffId: '',
            label: 'Free Period',
          ),
        );
        added++;
      }
      _draftCells.sort(_cellSort);
    });
    if (added > 0) {
      _showSnack('New row added. Set its start and end time as needed.');
    }
  }

  void _renumberDay(int day) {
    final dayCells = _draftCells.where((cell) => cell.day == day).toList()
      ..sort((a, b) {
        final aStart = _clockMinutes(a.startTime) ?? 0;
        final bStart = _clockMinutes(b.startTime) ?? 0;
        if (aStart != bStart) return aStart.compareTo(bStart);
        return a.periodNumber.compareTo(b.periodNumber);
      });
    for (var index = 0; index < dayCells.length; index++) {
      dayCells[index].periodNumber = index + 1;
    }
    _draftCells.sort(_cellSort);
  }

  void _goBack() {
    setState(() {
      _stage = switch (_stage) {
        _ManualTimetableStage.preview => _ManualTimetableStage.editor,
        _ManualTimetableStage.editor =>
          _selectedClassSlots.isEmpty
              ? _ManualTimetableStage.settings
              : _ManualTimetableStage.selectClass,
        _ManualTimetableStage.settings => _ManualTimetableStage.selectClass,
        _ManualTimetableStage.selectClass => _ManualTimetableStage.selectClass,
      };
    });
  }

  String? _validateSettings() {
    final start = _clockMinutes(_settings.startTime);
    final end = _clockMinutes(_settings.endTime);
    if (start == null || end == null || end <= start) {
      return 'End time must be after start time.';
    }
    if (_settings.periodDurationMinutes <= 0) {
      return 'Period duration is required.';
    }
    if (_settings.workingDays.isEmpty) {
      return 'Select at least one working day.';
    }
    for (final item in _settings.breaks) {
      final breakStart = _clockMinutes(item.startTime);
      if (breakStart == null || item.durationMinutes <= 0) {
        return 'Complete break timings before creating timetable.';
      }
    }
    return null;
  }

  String? _validateDraftCells() {
    for (final day in _draftCells.map((cell) => cell.day).toSet()) {
      final dayCells = _draftCells.where((cell) => cell.day == day).toList()
        ..sort((a, b) {
          final startCompare = (_clockMinutes(a.startTime) ?? -1).compareTo(
            _clockMinutes(b.startTime) ?? -1,
          );
          return startCompare != 0
              ? startCompare
              : a.periodNumber.compareTo(b.periodNumber);
        });
      var previousEnd = -1;
      for (final cell in dayCells) {
        final start = _clockMinutes(cell.startTime);
        final end = _clockMinutes(cell.endTime);
        if (start == null || end == null || end <= start) {
          return 'Set a valid start and end time for ${_dayFullLabels[day - 1]} P${cell.periodNumber}.';
        }
        if (start < previousEnd) {
          return 'Period timings overlap on ${_dayFullLabels[day - 1]}. Adjust the row times before saving.';
        }
        previousEnd = end;
      }
    }
    return null;
  }

  _TimetableSettings _settingsFromSlots(List<Map<String, dynamic>> slots) {
    if (slots.isEmpty) return _TimetableSettings.defaults();
    final sorted = [...slots]..sort(_slotSort);
    final first = sorted.first;
    final last = sorted.last;
    final days = sorted
        .map((slot) => _int(slot['day_of_week']))
        .where((day) => day >= 1 && day <= 6)
        .toSet();
    final breaks = <String, _TimetableBreakDraft>{};
    for (final slot in sorted.where(_isBreakSlot)) {
      final key = '${_subjectName(slot)}|${_text(slot['start_time'])}';
      final start = _clockMinutes(_text(slot['start_time'])) ?? 0;
      final end = _clockMinutes(_text(slot['end_time'])) ?? start;
      breaks.putIfAbsent(
        key,
        () => _TimetableBreakDraft(
          name: _subjectName(slot),
          startTime: _formatMinutes(start),
          durationMinutes: (end - start).clamp(1, 240),
          days: <int>{},
        ),
      );
      breaks[key]!.days.add(_int(slot['day_of_week']));
    }
    return _TimetableSettings(
      startTime: _text(first['start_time'], fallback: '09:00'),
      endTime: _text(last['end_time'], fallback: '15:30'),
      periodDurationMinutes: 45,
      gapDurationMinutes: 10,
      workingDays: days.isEmpty ? {1, 2, 3, 4, 5, 6} : days,
      breaks: breaks.values.toList(),
    );
  }

  List<_ClassSubjectOption> get _subjectOptionsForSelectedClass {
    final section = _selectedSection;
    if (section == null) return const [];
    final subjectIds = <String>{};
    for (final row in _gradeSubjects) {
      final sectionId = _text(row['section_id']);
      final gradeId = _text(row['grade_id']);
      final matchesSection = sectionId.isNotEmpty && sectionId == section.id;
      final matchesGrade = sectionId.isEmpty && gradeId == section.gradeId;
      if (!matchesSection && !matchesGrade) continue;
      final subjectId = _text(row['subject_id'] ?? _map(row['subject'])['id']);
      if (subjectId.isNotEmpty) subjectIds.add(subjectId);
    }
    // Fallback: if no grade_subjects mapped, use all school-wide subjects
    if (subjectIds.isEmpty) {
      for (final row in _subjects) {
        final subjectId = _text(row['id'] ?? row['subject_id']);
        if (subjectId.isNotEmpty) subjectIds.add(subjectId);
      }
    }
    final options = <_ClassSubjectOption>[];
    for (final subjectId in subjectIds) {
      final subject = _subjectById(subjectId);
      final name = _text(
        subject['subject_name'] ?? subject['name'],
        fallback: subjectId,
      );
      final code = _text(subject['subject_code'] ?? subject['code']);
      options.add(
        _ClassSubjectOption(
          id: subjectId,
          name: code.isEmpty ? name : '$name ($code)',
          staffId: _teacherIdForSubject(subjectId),
        ),
      );
    }
    options.sort((a, b) => a.name.compareTo(b.name));
    return options;
  }

  String _teacherIdForSubject(String subjectId) {
    if (subjectId.trim().isEmpty) return '';
    final section = _selectedSection;
    if (section == null) return '';
    if (section.classTeacherId.trim().isNotEmpty) {
      return section.classTeacherId.trim();
    }
    if (section.coTeacherId.trim().isNotEmpty) {
      return section.coTeacherId.trim();
    }
    for (final row in _staffSubjects) {
      if (_text(row['subject_id'] ?? _map(row['subject'])['id']) != subjectId) {
        continue;
      }
      final sectionId = _text(row['section_id']);
      final gradeId = _text(row['grade_id']);
      final matchesSection = sectionId.isNotEmpty && sectionId == section.id;
      final matchesGrade = sectionId.isEmpty && gradeId == section.gradeId;
      if (!matchesSection && !matchesGrade) continue;
      final staffId = _text(row['staff_id'] ?? _map(row['staff'])['id']);
      if (staffId.isNotEmpty) return staffId;
    }
    return '';
  }

  Map<String, dynamic> _subjectById(String subjectId) {
    for (final row in _subjects) {
      if (_text(row['id'] ?? row['subject_id']) == subjectId) return row;
    }
    for (final row in _gradeSubjects) {
      final subject = _map(row['subject']);
      if (_text(subject['id'] ?? subject['subject_id']) == subjectId) {
        return subject;
      }
    }
    return const {};
  }

  List<Map<String, dynamic>> get _selectedClassSlots {
    return _slots.where((slot) {
      return _text(slot['section_id']) == _selectedSectionId;
    }).toList()..sort(_slotSort);
  }

  List<_ManualTimetableCell> get _columns {
    final byPeriod = <int, _ManualTimetableCell>{};
    for (final cell in _draftCells) {
      byPeriod.putIfAbsent(cell.periodNumber, () => cell);
    }
    return byPeriod.values.toList()..sort(_cellSort);
  }

  _ManualTimetableCell? _cellFor(int day, int period) {
    for (final cell in _draftCells) {
      if (cell.day == day && cell.periodNumber == period) return cell;
    }
    return null;
  }

  List<_ManualTimetableCell> get _dayCells {
    if (_selectedEditorDays.isEmpty) return const [];
    // Use the first selected day as the reference for display
    final refDay = _selectedEditorDays.first;
    return _draftCells.where((cell) => cell.day == refDay).toList()
      ..sort(_cellSort);
  }

  String _subjectLabel(
    _ManualTimetableCell cell,
    List<_ClassSubjectOption> options,
  ) {
    if (cell.isBreak) return cell.label;
    if (cell.subjectId.isEmpty || cell.slotType == 'free') return 'Free Period';
    for (final option in options) {
      if (option.id == cell.subjectId) return option.name;
    }
    return cell.label.isEmpty ? 'Subject' : cell.label;
  }

  int get _maxTeachingPeriodsPerDay {
    final counts = <int, int>{};
    for (final cell in _draftCells.where((cell) => !cell.isBreak)) {
      counts[cell.day] = (counts[cell.day] ?? 0) + 1;
    }
    if (counts.isEmpty) return 0;
    return counts.values.reduce((a, b) => a > b ? a : b);
  }

  int get _firstDraftDay {
    final days = _draftCells.map((cell) => cell.day).toSet().toList()..sort();
    if (days.isNotEmpty) return days.first;
    final settingsDays = _settings.workingDays.toList()..sort();
    return settingsDays.isEmpty ? 1 : settingsDays.first;
  }

  String get _workingDaysLabel {
    final days = _draftCells.map((cell) => cell.day).toSet().toList()..sort();
    if (days.isEmpty) days.addAll(_settings.workingDays.toList()..sort());
    return days.map((day) => _dayShortLabels[day - 1]).join(' - ');
  }

  SectionModel? get _selectedSection {
    for (final section in _sections) {
      if (section.id == _selectedSectionId) return section;
    }
    return null;
  }

  AcademicYearModel? get _currentAcademicYear {
    for (final year in _academicYears) {
      if (year.isCurrent) return year;
    }
    return _academicYears.isEmpty ? null : _academicYears.first;
  }

  String get _selectedDaysLabel {
    if (_selectedEditorDays.isEmpty) return '';
    final sorted = _selectedEditorDays.toList()..sort();
    return sorted.map((d) => _dayShortLabels[d - 1]).join(', ');
  }

  String get _selectedClassLabel => _sectionLabel(_selectedSection);

  String _sectionLabel(SectionModel? section) {
    if (section == null) return 'Class';
    final grade = section.gradeName.trim();
    final name = section.sectionName.trim();
    if (grade.isEmpty) return name.isEmpty ? 'Class' : name;
    if (name.isEmpty) return grade;
    return '$grade - $name';
  }

  String _lastUpdatedLabel(List<Map<String, dynamic>> slots) {
    var latest = DateTime.fromMillisecondsSinceEpoch(0);
    for (final slot in slots) {
      final value = DateTime.tryParse(_text(slot['updated_at']));
      if (value != null && value.isAfter(latest)) latest = value;
    }
    if (latest.millisecondsSinceEpoch == 0) return 'Not available';
    return '${latest.day.toString().padLeft(2, '0')} ${_monthLabel(latest.month)}';
  }

  int _teachingPeriodCount(List<Map<String, dynamic>> slots) {
    return slots.where((slot) => !_isBreakSlot(slot)).length;
  }

  int _breakCount(List<Map<String, dynamic>> slots) {
    return slots.where(_isBreakSlot).length;
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

  static int _cellSort(_ManualTimetableCell a, _ManualTimetableCell b) {
    final day = a.day.compareTo(b.day);
    if (day != 0) return day;
    final period = a.periodNumber.compareTo(b.periodNumber);
    if (period != 0) return period;
    return a.startTime.compareTo(b.startTime);
  }

  static bool _isBreakSlot(Map<String, dynamic> slot) {
    final type = _text(slot['slot_type']).toLowerCase();
    final subject = _subjectName(slot).toLowerCase();
    return type == 'break' ||
        subject.contains('break') ||
        subject.contains('lunch');
  }

  static String _subjectName(Map<String, dynamic> slot) {
    final subject = _map(slot['subject']);
    return _text(
      subject['subject_name'] ??
          slot['subject_name'] ??
          slot['slot_label'] ??
          slot['label'],
      fallback: 'Break',
    );
  }

  static Map<String, dynamic> _map(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.map((key, val) => MapEntry('$key', val));
    return const {};
  }

  static int? _clockMinutes(String value) {
    final text = value.trim();
    final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(text);
    if (match == null) return null;
    final hours = int.tryParse(match.group(1) ?? '');
    final minutes = int.tryParse(match.group(2) ?? '');
    if (hours == null || minutes == null) return null;
    if (hours < 0 || hours > 23 || minutes < 0 || minutes > 59) return null;
    return hours * 60 + minutes;
  }

  static String _formatMinutes(int totalMinutes) {
    final hours = (totalMinutes ~/ 60) % 24;
    final minutes = totalMinutes % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
  }

  static String _monthLabel(int month) {
    const months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return month >= 1 && month < months.length ? months[month] : '';
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

class _TimetableSettings {
  String startTime;
  String endTime;
  int periodDurationMinutes;
  int gapDurationMinutes;
  Set<int> workingDays;
  List<_TimetableBreakDraft> breaks;

  _TimetableSettings({
    required this.startTime,
    required this.endTime,
    required this.periodDurationMinutes,
    required this.gapDurationMinutes,
    required Set<int> workingDays,
    required this.breaks,
  }) : workingDays = {...workingDays};

  factory _TimetableSettings.defaults() {
    return _TimetableSettings(
      startTime: '09:00',
      endTime: '15:30',
      periodDurationMinutes: 45,
      gapDurationMinutes: 10,
      workingDays: {1, 2, 3, 4, 5, 6},
      breaks: [],
    );
  }
}

class _TimetableBreakDraft {
  String name;
  String startTime;
  int durationMinutes;
  Set<int> days;

  _TimetableBreakDraft({
    required this.name,
    required this.startTime,
    required this.durationMinutes,
    required Set<int> days,
  }) : days = {...days};

  void keepDaysInside(Set<int> workingDays) {
    days = days.where(workingDays.contains).toSet();
    if (days.isEmpty && workingDays.isNotEmpty) days.add(workingDays.first);
  }
}

class _ManualTimetableCell {
  final int day;
  int periodNumber;
  String startTime;
  String endTime;
  String slotType;
  String subjectId;
  String staffId;
  final String label;

  _ManualTimetableCell({
    required this.day,
    required this.periodNumber,
    required this.startTime,
    required this.endTime,
    required this.slotType,
    required this.subjectId,
    required this.staffId,
    required this.label,
  });

  factory _ManualTimetableCell.fromSlot(Map<String, dynamic> slot) {
    final subject = _AdminTimetableScreenState._map(slot['subject']);
    final slotType = _AdminTimetableScreenState._text(slot['slot_type']).isEmpty
        ? (_AdminTimetableScreenState._text(slot['subject_id']).isEmpty
              ? 'free'
              : 'regular')
        : _AdminTimetableScreenState._text(slot['slot_type']);
    final label = _AdminTimetableScreenState._text(
      subject['subject_name'] ?? slot['subject_name'],
      fallback: slotType == 'break' ? 'Break' : 'Free Period',
    );
    return _ManualTimetableCell(
      day: _AdminTimetableScreenState._int(slot['day_of_week']),
      periodNumber: _AdminTimetableScreenState._int(slot['period_number']),
      startTime: _AdminTimetableScreenState._text(slot['start_time']),
      endTime: _AdminTimetableScreenState._text(slot['end_time']),
      slotType: slotType,
      subjectId: _AdminTimetableScreenState._text(slot['subject_id']),
      staffId: _AdminTimetableScreenState._text(slot['staff_id']),
      label: label,
    );
  }

  bool get isBreak => slotType == 'break';

  bool get isRegular => slotType == 'regular' && subjectId.trim().isNotEmpty;

  _ManualTimetableCell copyWith({int? periodNumber}) {
    return _ManualTimetableCell(
      day: day,
      periodNumber: periodNumber ?? this.periodNumber,
      startTime: startTime,
      endTime: endTime,
      slotType: slotType,
      subjectId: subjectId,
      staffId: staffId,
      label: label,
    );
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
