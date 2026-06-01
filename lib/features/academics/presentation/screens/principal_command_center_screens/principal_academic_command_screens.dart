import 'package:flutter/material.dart';

import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/theme/app_theme.dart';
import 'package:schooldesk1/core/widgets/operations_workspace.dart';
import 'package:schooldesk1/core/widgets/principal_directory_ui.dart';

enum _TimetableMode { periods, coverage, staff, rooms, alerts }

enum _PrincipalCommandKind { timetable, exams, results }

class PrincipalTimetableScreen extends StatefulWidget {
  const PrincipalTimetableScreen({super.key});

  @override
  State<PrincipalTimetableScreen> createState() =>
      _PrincipalTimetableScreenState();
}

class _PrincipalTimetableScreenState extends State<PrincipalTimetableScreen> {
  _TimetableMode _mode = _TimetableMode.periods;

  @override
  Widget build(BuildContext context) {
    return _PrincipalCommandScreen(
      kind: _PrincipalCommandKind.timetable,
      title: 'Timetable Builder',
      subtitle:
          'Create class periods, review the schedule, and cleanly remove slots',
      icon: Icons.calendar_view_week_rounded,
      accent: Colors.teal,
      loadData: BackendApiClient.instance.getPrincipalTimetableOverview,
      onAddCreate: _openTimetableSlotForm,
      onEditEntry: (context, row) =>
          _openTimetableSlotForm(context, period: row),
      addIcon: Icons.add_rounded,
      addTooltip: 'Add timetable period',
      saveAction:
          ({
            required actionType,
            required message,
            title = '',
            priority = 'normal',
            entityId = '',
            dueDate = '',
          }) => BackendApiClient.instance.createPrincipalTimetableAction(
            actionType: actionType,
            message: message,
            title: title,
            priority: priority,
            slotId: entityId,
            dueDate: dueDate,
          ),
      metrics: (data) {
        final summary = _map(data['summary']);
        return [
          _Metric(
            'Slots',
            '${_int(summary['total_slots'])}',
            Icons.event_note_rounded,
            Colors.teal,
          ),
          _Metric(
            'Classes',
            '${_int(summary['classes_covered'])}',
            Icons.meeting_room_outlined,
            Colors.indigo,
          ),
          _Metric(
            'Conflicts',
            '${_int(summary['conflict_alerts'])}',
            Icons.warning_amber_rounded,
            Colors.orange,
          ),
          _Metric(
            'Today',
            '${_int(summary['today_classes'])}',
            Icons.today_outlined,
            Colors.green,
          ),
        ];
      },
      content: (data, openAction) => [
        const _TimetableWorkflowStrip(),
        _TimetableModePicker(
          selected: _mode,
          onSelected: (mode) => setState(() => _mode = mode),
        ),
        _buildTimetableMode(data, openAction),
      ],
    );
  }

  Widget _buildTimetableMode(
    Map<String, dynamic> data,
    void Function(_ActionSpec action) openAction,
  ) {
    final views = _map(data['views']);
    return switch (_mode) {
      _TimetableMode.periods => _rowsPanel(
        'Created Periods',
        'Only saved timetable slots are shown here',
        _list(views['periods']),
        Icons.schedule_outlined,
      ),
      _TimetableMode.coverage => OpsResponsiveGrid(
        minTileWidth: 360,
        children: [
          _rowsPanel(
            'Class Coverage',
            'Classes with saved timetable periods',
            _list(views['class_wise']),
            Icons.meeting_room_outlined,
          ),
          _rowsPanel(
            'Subject Coverage',
            'Subjects already mapped into the timetable',
            _list(views['subject_wise']),
            Icons.menu_book_outlined,
          ),
        ],
      ),
      _TimetableMode.staff => _rowsPanel(
        'Teacher Load',
        'Teacher load and schedule coverage',
        _list(views['teacher_wise']),
        Icons.badge_outlined,
      ),
      _TimetableMode.rooms => _rowsPanel(
        'Room Usage',
        'Room usage and availability',
        _list(views['room_wise']),
        Icons.door_back_door_outlined,
      ),
      _TimetableMode.alerts => _rowsPanel(
        'Conflict Alerts',
        'Conflicts detected by backend timetable analysis',
        _list(data['conflict_alerts']),
        Icons.warning_amber_rounded,
      ),
    };
  }

  Future<bool> _openTimetableSlotForm(
    BuildContext context, {
    Map<String, dynamic>? period,
  }) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PrincipalInputPage(
          title: period == null ? 'Add Timetable Period' : 'Edit Period',
          icon: Icons.calendar_view_week_rounded,
          child: _TimetableSlotInputForm(
            period: period,
            onSubmit: (payload) async {
              final id = _text(period?['id'] ?? period?['slot_id']);
              if (id.isEmpty) {
                await BackendApiClient.instance.createRaw(
                  '/timetable/slots',
                  payload,
                );
              } else {
                await BackendApiClient.instance.updateRaw(
                  '/timetable/slots/$id',
                  payload,
                );
              }
            },
          ),
        ),
      ),
    );
    return result == true;
  }
}

class PrincipalExamsScreen extends StatelessWidget {
  const PrincipalExamsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _PrincipalCommandScreen(
      kind: _PrincipalCommandKind.exams,
      title: 'Exam Workflow',
      subtitle: 'Prepare, schedule, monitor, evaluate, and publish exams',
      icon: Icons.fact_check_rounded,
      accent: Colors.indigo,
      loadData: BackendApiClient.instance.getPrincipalExamsOverview,
      onAddCreate: _openExamForm,
      onEditEntry: (context, row) => _openExamForm(context, exam: row),
      addIcon: Icons.add_rounded,
      addTooltip: 'Create exam',
      saveAction:
          ({
            required actionType,
            required message,
            title = '',
            priority = 'normal',
            entityId = '',
            dueDate = '',
          }) => BackendApiClient.instance.createPrincipalExamAction(
            actionType: actionType,
            message: message,
            title: title,
            priority: priority,
            examId: entityId,
            dueDate: dueDate,
          ),
      metrics: (data) {
        final summary = _map(data['summary']);
        return [
          _Metric(
            'Upcoming',
            '${_int(summary['upcoming_exams'])}',
            Icons.upcoming_outlined,
            Colors.indigo,
          ),
          _Metric(
            'Schedules',
            '${_int(summary['schedules_configured'])}',
            Icons.event_available_outlined,
            Colors.teal,
          ),
          _Metric(
            'Evaluation pending',
            '${_int(summary['evaluation_pending'])}',
            Icons.pending_actions_outlined,
            Colors.orange,
          ),
          _Metric(
            'Published',
            '${_int(summary['published_exams'])}',
            Icons.publish_outlined,
            Colors.green,
          ),
        ];
      },
      content: (data, openAction) {
        final controls = _map(data['creation_controls']);
        final monitoring = _map(data['monitoring_panel']);
        final evaluation = _map(data['evaluation_tracking']);
        return [
          const _ExamWorkflowStrip(),
          OpsResponsiveGrid(
            minTileWidth: 360,
            children: [
              _rowsPanel(
                '1. Readiness',
                'Exam types, grades, subjects, rooms, and invigilators',
                _optionRows(controls),
                Icons.add_task_outlined,
              ),
              _rowsPanel(
                '2. Scheduled Exams',
                'Created exams and their publish state',
                _list(data['exam_dashboard']),
                Icons.assignment_outlined,
              ),
              _rowsPanel(
                '3. Live Monitoring',
                'Exam progress, absentees, and paper submission',
                _list(monitoring['live_exam_progress']),
                Icons.monitor_heart_outlined,
              ),
              _rowsPanel(
                '4. Evaluation',
                'Marks pending and delayed evaluation follow-up',
                _list(evaluation['marks_pending']),
                Icons.edit_note_outlined,
              ),
            ],
          ),
          _actionsPanel(
            title: '5. Publish',
            subtitle: 'Approve schedules, publish results, or record notes',
            rows: _list(data['actions']),
            openAction: openAction,
            actionType: 'exam_readiness',
          ),
        ];
      },
    );
  }

  Future<bool> _openExamForm(
    BuildContext context, {
    Map<String, dynamic>? exam,
  }) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PrincipalInputPage(
          title: exam == null ? 'Create Exam' : 'Edit Exam',
          icon: Icons.fact_check_rounded,
          child: _ExamInputForm(
            exam: exam,
            onSubmit: (payload) async {
              final id = _text(exam?['exam_id'] ?? exam?['id']);
              if (id.isEmpty) {
                await BackendApiClient.instance.createRaw('/exams', payload);
              } else {
                await BackendApiClient.instance.updateRaw(
                  '/exams/$id',
                  payload,
                );
              }
            },
          ),
        ),
      ),
    );
    return result == true;
  }
}

class PrincipalResultsScreen extends StatelessWidget {
  const PrincipalResultsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _PrincipalCommandScreen(
      kind: _PrincipalCommandKind.results,
      title: 'Results Command Center',
      subtitle:
          'Result Dashboard, Toppers Section, Weak Student Detection, and Export Options',
      icon: Icons.emoji_events_rounded,
      accent: Colors.deepPurple,
      loadData: BackendApiClient.instance.getPrincipalResultsOverview,
      saveAction:
          ({
            required actionType,
            required message,
            title = '',
            priority = 'normal',
            entityId = '',
            dueDate = '',
          }) => BackendApiClient.instance.createPrincipalResultAction(
            actionType: actionType,
            message: message,
            title: title,
            priority: priority,
            examId: entityId,
            dueDate: dueDate,
          ),
      metrics: (data) {
        final summary = _map(data['summary']);
        return [
          _Metric(
            'Performance',
            '${_num(summary['overall_school_performance']).toStringAsFixed(0)}%',
            Icons.analytics_outlined,
            Colors.green,
          ),
          _Metric(
            'Pass %',
            '${_num(summary['pass_percentage']).toStringAsFixed(0)}%',
            Icons.verified_outlined,
            Colors.indigo,
          ),
          _Metric(
            'Weak students',
            '${_int(summary['weak_students'])}',
            Icons.warning_amber_rounded,
            Colors.orange,
          ),
          _Metric(
            'Report cards',
            '${_int(summary['report_cards'])}',
            Icons.description_outlined,
            Colors.deepPurple,
          ),
        ];
      },
      content: (data, openAction) {
        final dashboard = _map(data['result_dashboard']);
        final toppers = _map(data['toppers']);
        final reports = _map(data['reports']);
        return [
          OpsResponsiveGrid(
            minTileWidth: 360,
            children: [
              _rowsPanel(
                'Result Dashboard',
                'Class and subject performance summary',
                _list(dashboard['class_performance']),
                Icons.analytics_outlined,
              ),
              _rowsPanel(
                'Toppers Section',
                'School, class, and Subject-wise Topper List',
                _list(toppers['school_toppers']),
                Icons.emoji_events_outlined,
              ),
              _rowsPanel(
                'Weak Student Detection',
                'Attendance and marks correlation',
                _list(data['weak_students']),
                Icons.warning_amber_rounded,
              ),
              _rowsPanel(
                'Export Options',
                'PDF, Excel, and comparative report card exports',
                _list(reports['export_options']),
                Icons.file_download_outlined,
              ),
            ],
          ),
          _actionsPanel(
            title: 'Result Actions',
            subtitle:
                'Generate improvement plans and request report-card publishing follow-up',
            rows: _list(data['actions']),
            openAction: openAction,
            actionType: 'improvement_plan',
          ),
        ];
      },
    );
  }
}

class _PrincipalCommandScreen extends StatefulWidget {
  final _PrincipalCommandKind kind;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final Future<bool> Function(BuildContext context)? onAddCreate;
  final Future<bool> Function(BuildContext context, Map<String, dynamic> row)?
  onEditEntry;
  final IconData addIcon;
  final String addTooltip;
  final Future<Map<String, dynamic>> Function() loadData;
  final Future<Map<String, dynamic>> Function({
    required String actionType,
    required String message,
    String title,
    String priority,
    String entityId,
    String dueDate,
  })
  saveAction;
  final List<_Metric> Function(Map<String, dynamic> data) metrics;
  final List<Widget> Function(
    Map<String, dynamic> data,
    void Function(_ActionSpec action) openAction,
  )
  content;

  const _PrincipalCommandScreen({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    this.onAddCreate,
    this.onEditEntry,
    this.addIcon = Icons.add_task_rounded,
    this.addTooltip = 'Create action',
    required this.loadData,
    required this.saveAction,
    required this.metrics,
    required this.content,
  });

  @override
  State<_PrincipalCommandScreen> createState() =>
      _PrincipalCommandScreenState();
}

class _PrincipalCommandScreenState extends State<_PrincipalCommandScreen> {
  final _scrollController = ScrollController();
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String _search = '';
  String _selectedSection = 'All';
  Map<String, dynamic> _data = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.loadData();
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load ${widget.title} from backend. $error';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _buildBody();
  }

  Widget _buildBody() {
    final entries = _filteredEntries;
    return PrincipalDirectoryScaffold(
      title: _directoryTitle,
      subtitle: widget.subtitle,
      loading: _loading,
      error: _error,
      onRefresh: _load,
      onAdd: _handleAdd,
      addIcon: widget.addIcon,
      addTooltip: widget.addTooltip,
      controller: _scrollController,
      filters: _buildFilters(),
      isEmpty: !_loading && _error == null && entries.isEmpty,
      emptyState: OpsEmptyState(
        icon: widget.icon,
        title: _emptyTitle,
        message: _emptyMessage,
      ),
      slivers: [
        if (_isTimetable || _isExams)
          SliverToBoxAdapter(
            child: _isTimetable
                ? const _TimetableWorkflowStrip()
                : const _ExamWorkflowStrip(),
          ),
        SliverToBoxAdapter(
          child: PrincipalDirectoryMetricStrip(
            metrics: [
              for (final metric in widget.metrics(_data))
                PrincipalDirectoryMetric(
                  label: metric.label,
                  value: metric.value,
                  icon: metric.icon,
                  color: metric.color,
                  tone: metric.color.withAlpha(22),
                ),
            ],
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(22, 10, 22, 96),
          sliver: SliverList.builder(
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 13),
                child: PrincipalDirectoryCard(
                  icon: entry.icon,
                  title: entry.title,
                  subtitle: entry.subtitle,
                  status: entry.status,
                  statusColor: _statusColor(entry.status),
                  chips: [
                    PrincipalInfoPill(
                      icon: Icons.folder_open_rounded,
                      label: entry.section,
                    ),
                    if (entry.date.isNotEmpty)
                      PrincipalInfoPill(
                        icon: Icons.calendar_today_outlined,
                        label: entry.date,
                      ),
                    if (entry.value.isNotEmpty)
                      PrincipalInfoPill(
                        icon: Icons.insights_outlined,
                        label: entry.value,
                      ),
                  ],
                  trailing: _entryMenu(entry),
                  onTap: () => _openEntryDetail(entry),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _handleAdd() async {
    final creator = widget.onAddCreate;
    if (creator != null) {
      final changed = await creator(context);
      if (changed) await _load();
      return;
    }
    await _openAction(
      _ActionSpec(
        actionType: _defaultActionType,
        title: widget.title,
        priority: 'normal',
        entityId: '',
        dueDate: '',
      ),
    );
  }

  String get _directoryTitle {
    return switch (widget.kind) {
      _PrincipalCommandKind.timetable => 'Timetable Builder',
      _PrincipalCommandKind.exams => 'Exam Workflow',
      _PrincipalCommandKind.results => 'Results Directory',
    };
  }

  bool get _isTimetable => widget.kind == _PrincipalCommandKind.timetable;

  bool get _isExams => widget.kind == _PrincipalCommandKind.exams;

  bool get _allowsFollowUpActions => !_isTimetable;

  String get _emptyTitle {
    return switch (widget.kind) {
      _PrincipalCommandKind.timetable => 'No timetable periods yet',
      _PrincipalCommandKind.exams => 'No exams scheduled yet',
      _PrincipalCommandKind.results => 'No results rows',
    };
  }

  String get _emptyMessage {
    return switch (widget.kind) {
      _PrincipalCommandKind.timetable =>
        'Create the first class period, then it will appear here for review, edit, and delete.',
      _PrincipalCommandKind.exams =>
        'Create an exam schedule from the workflow, then monitor and evaluate it here.',
      _PrincipalCommandKind.results =>
        'Adjust search or wait for backend results data to arrive.',
    };
  }

  String get _searchHint {
    return switch (widget.kind) {
      _PrincipalCommandKind.timetable =>
        'Search class, subject, teacher, day...',
      _PrincipalCommandKind.exams => 'Search exam, class, subject, status...',
      _PrincipalCommandKind.results => 'Search results directory...',
    };
  }

  String get _defaultActionType {
    return switch (widget.kind) {
      _PrincipalCommandKind.timetable => 'schedule_review',
      _PrincipalCommandKind.exams => 'exam_readiness',
      _PrincipalCommandKind.results => 'improvement_plan',
    };
  }

  Widget _buildFilters() {
    final sections = ['All', ..._entries.map((entry) => entry.section).toSet()];
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 4, 22, 4),
      child: Column(
        children: [
          PrincipalDirectorySearchBox(
            hint: _searchHint,
            onChanged: (value) => setState(() => _search = value),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              children: [
                for (final section in sections)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: PrincipalDirectoryChip(
                      label: section,
                      selected: _selectedSection == section,
                      icon: section == 'All'
                          ? Icons.all_inclusive_rounded
                          : Icons.folder_open_rounded,
                      onTap: () => setState(() => _selectedSection = section),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<_CommandDirectoryEntry> get _filteredEntries {
    final query = _search.trim().toLowerCase();
    return _entries.where((entry) {
      final matchesSection =
          _selectedSection == 'All' || entry.section == _selectedSection;
      final matchesSearch =
          query.isEmpty || entry.searchText.contains(query.toLowerCase());
      return matchesSection && matchesSearch;
    }).toList();
  }

  List<_CommandDirectoryEntry> get _entries {
    return switch (widget.kind) {
      _PrincipalCommandKind.timetable => _timetableEntries(),
      _PrincipalCommandKind.exams => _examEntries(),
      _PrincipalCommandKind.results => _resultEntries(),
    };
  }

  List<_CommandDirectoryEntry> _timetableEntries() {
    final views = _map(_data['views']);
    return [
      ..._rowsToEntries(
        section: 'Periods',
        rows: _list(views['periods']),
        icon: Icons.schedule_outlined,
      ),
    ];
  }

  List<_CommandDirectoryEntry> _examEntries() {
    return [
      ..._rowsToEntries(
        section: 'Scheduled Exams',
        rows: _list(_data['exam_dashboard']),
        icon: Icons.assignment_outlined,
      ),
    ];
  }

  List<_CommandDirectoryEntry> _resultEntries() {
    final dashboard = _map(_data['result_dashboard']);
    final toppers = _map(_data['toppers']);
    final reports = _map(_data['reports']);
    return [
      ..._rowsToEntries(
        section: 'Performance',
        rows: _list(dashboard['class_performance']),
        icon: Icons.analytics_outlined,
      ),
      ..._rowsToEntries(
        section: 'Toppers',
        rows: _list(toppers['school_toppers']),
        icon: Icons.emoji_events_outlined,
      ),
      ..._rowsToEntries(
        section: 'Weak Students',
        rows: _list(_data['weak_students']),
        icon: Icons.warning_amber_rounded,
      ),
      ..._rowsToEntries(
        section: 'Exports',
        rows: _list(reports['export_options']),
        icon: Icons.file_download_outlined,
      ),
      ..._rowsToEntries(
        section: 'Actions',
        rows: _list(_data['actions']),
        icon: Icons.task_alt_outlined,
      ),
    ];
  }

  List<_CommandDirectoryEntry> _rowsToEntries({
    required String section,
    required List<Map<String, dynamic>> rows,
    required IconData icon,
  }) {
    return [
      for (final row in rows)
        _CommandDirectoryEntry(
          section: section,
          row: row,
          icon: icon,
          title: _rowTitle(row),
          subtitle: _rowSubtitle(row),
          status: _text(
            row['status'] ?? row['priority'] ?? row['state'],
            fallback: 'Live',
          ),
          date: _text(row['date'] ?? row['exam_date'] ?? row['start_date']),
          value: _text(row['value'] ?? row['count'] ?? row['percentage']),
        ),
    ];
  }

  Widget _entryMenu(_CommandDirectoryEntry entry) {
    return PopupMenuButton<String>(
      tooltip: '${entry.title} options',
      onSelected: (value) async {
        switch (value) {
          case 'open':
            await _openEntryDetail(entry);
            break;
          case 'action':
            await _openAction(
              _ActionSpec(
                actionType: _defaultActionType,
                title: entry.title,
                priority: 'normal',
                entityId: _entityIdFor(entry),
                dueDate: '',
              ),
            );
            break;
          case 'edit':
            await _editEntry(entry);
            break;
          case 'delete':
            await _deleteEntry(entry);
            break;
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'open', child: Text('View details')),
        if (_allowsFollowUpActions)
          const PopupMenuItem(value: 'action', child: Text('Create follow-up')),
        if (_canEditEntry(entry))
          PopupMenuItem(value: 'edit', child: Text(_editMenuLabel)),
        if (_canDeleteEntry(entry))
          PopupMenuItem(value: 'delete', child: Text(_deleteMenuLabel)),
      ],
    );
  }

  Future<void> _openEntryDetail(_CommandDirectoryEntry entry) async {
    final fields = entry.row.entries
        .where((item) => _text(item.value).isNotEmpty)
        .take(12)
        .toList();
    final canEdit = _canEditEntry(entry);
    final canDelete = _canDeleteEntry(entry);
    final hasActions = _allowsFollowUpActions || canEdit || canDelete;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (detailContext) => PrincipalDetailPage(
          title: entry.title,
          menuItems: [
            if (_allowsFollowUpActions)
              const PopupMenuItem(
                value: 'action',
                child: Text('Create follow-up'),
              ),
            if (canEdit)
              PopupMenuItem(value: 'edit', child: Text(_editMenuLabel)),
            if (canDelete)
              PopupMenuItem(value: 'delete', child: Text(_deleteMenuLabel)),
          ],
          onMenuSelected: (value) async {
            if (value == 'action') {
              Navigator.pop(detailContext);
              await _openAction(
                _ActionSpec(
                  actionType: _defaultActionType,
                  title: entry.title,
                  priority: 'normal',
                  entityId: _entityIdFor(entry),
                  dueDate: '',
                ),
              );
            } else if (value == 'edit') {
              Navigator.pop(detailContext);
              await _editEntry(entry);
            } else if (value == 'delete') {
              Navigator.pop(detailContext);
              await _deleteEntry(entry);
            }
          },
          children: [
            PrincipalDetailCard(
              title: entry.section,
              trailing: PrincipalStatusPill(
                label: entry.status,
                color: _statusColor(entry.status),
              ),
              children: [
                PrincipalDetailRow(label: 'Summary', value: entry.subtitle),
                if (entry.date.isNotEmpty)
                  PrincipalDetailRow(label: 'Date', value: entry.date),
                if (entry.value.isNotEmpty)
                  PrincipalDetailRow(label: 'Value', value: entry.value),
                for (final field in fields)
                  PrincipalDetailRow(
                    label: _labelize(field.key),
                    value: _text(field.value),
                  ),
              ],
            ),
            if (hasActions)
              PrincipalDetailCard(
                title: 'Actions',
                children: [
                  if (_allowsFollowUpActions)
                    PrincipalActionTile(
                      icon: Icons.add_task_rounded,
                      title: 'Create follow-up',
                      subtitle: 'Save a principal action against this row',
                      onTap: () {
                        Navigator.pop(detailContext);
                        _openAction(
                          _ActionSpec(
                            actionType: _defaultActionType,
                            title: entry.title,
                            priority: 'normal',
                            entityId: _entityIdFor(entry),
                            dueDate: '',
                          ),
                        );
                      },
                    ),
                  if (canEdit)
                    PrincipalActionTile(
                      icon: Icons.edit_calendar_outlined,
                      title: _editMenuLabel,
                      subtitle:
                          'Change the class, teacher, subject, day, or time.',
                      onTap: () {
                        Navigator.pop(detailContext);
                        _editEntry(entry);
                      },
                    ),
                  if (canDelete)
                    PrincipalActionTile(
                      icon: Icons.delete_outline_rounded,
                      title: _deleteMenuLabel,
                      subtitle: _deleteDetailHelp,
                      color: AppTheme.error,
                      onTap: () {
                        Navigator.pop(detailContext);
                        _deleteEntry(entry);
                      },
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  bool _canDeleteEntry(_CommandDirectoryEntry entry) {
    return _deletePathFor(entry).isNotEmpty;
  }

  bool _canEditEntry(_CommandDirectoryEntry entry) {
    return widget.onEditEntry != null && _deletePathFor(entry).isNotEmpty;
  }

  String _deletePathFor(_CommandDirectoryEntry entry) {
    switch (widget.kind) {
      case _PrincipalCommandKind.timetable:
        final id = _text(
          entry.row['id'] ??
              entry.row['slot_id'] ??
              entry.row['timetable_slot_id'],
        );
        final hasSlotShape =
            entry.row.containsKey('period') ||
            entry.row.containsKey('period_number') ||
            entry.row.containsKey('start_time') ||
            entry.row.containsKey('slot_type');
        if (id.isEmpty || !hasSlotShape) return '';
        return '/timetable/slots/$id';
      case _PrincipalCommandKind.exams:
        final id = _text(entry.row['exam_id'] ?? entry.row['id']);
        if (id.isEmpty) return '';
        final hasExamShape =
            entry.row.containsKey('exam_name') ||
            entry.row.containsKey('exam_type') ||
            entry.row.containsKey('start_date');
        if (!hasExamShape) return '';
        return '/exams/$id';
      case _PrincipalCommandKind.results:
        return '';
    }
  }

  String _entityIdFor(_CommandDirectoryEntry entry) {
    return _text(
      entry.row['id'] ??
          entry.row['slot_id'] ??
          entry.row['timetable_slot_id'] ??
          entry.row['exam_id'] ??
          entry.row['schedule_id'],
    );
  }

  String get _deleteMenuLabel {
    return switch (widget.kind) {
      _PrincipalCommandKind.timetable => 'Delete timetable slot',
      _PrincipalCommandKind.exams => 'Delete exam',
      _PrincipalCommandKind.results => 'Delete',
    };
  }

  String get _editMenuLabel {
    return switch (widget.kind) {
      _PrincipalCommandKind.timetable => 'Edit timetable slot',
      _PrincipalCommandKind.exams => 'Edit exam',
      _PrincipalCommandKind.results => 'Edit',
    };
  }

  String get _deleteDetailHelp {
    return switch (widget.kind) {
      _PrincipalCommandKind.timetable =>
        'Remove this individual timetable period from the backend.',
      _PrincipalCommandKind.exams =>
        'Backend blocks deletion when schedules, marks, or report cards exist.',
      _PrincipalCommandKind.results =>
        'Deletion is not available for aggregated result rows.',
    };
  }

  Future<void> _deleteEntry(_CommandDirectoryEntry entry) async {
    final path = _deletePathFor(entry);
    if (path.isEmpty) {
      _showSnack(
        'This row is an aggregate view and cannot be deleted directly.',
      );
      return;
    }
    final confirmed = await _confirmDelete(
      title: _deleteMenuLabel,
      message: 'Delete ${entry.title}? $_deleteDetailHelp',
    );
    if (!confirmed) return;
    try {
      await BackendApiClient.instance.deleteRaw(path);
      await _load();
      _showSnack('${entry.title} deleted', success: true);
    } catch (error) {
      _showSnack('Unable to delete ${entry.title}: $error');
    }
  }

  Future<void> _editEntry(_CommandDirectoryEntry entry) async {
    final editor = widget.onEditEntry;
    if (editor == null) return;
    final changed = await editor(context, entry.row);
    if (changed) {
      await _load();
      _showSnack('${entry.title} updated', success: true);
    }
  }

  Future<bool> _confirmDelete({
    required String title,
    required String message,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Delete'),
          ),
        ],
      ),
    );
    return result == true;
  }

  void _showSnack(String message, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? AppTheme.success : AppTheme.error,
      ),
    );
  }

  Future<void> _openAction(_ActionSpec action) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PrincipalInputPage(
          title: 'Create Action',
          icon: Icons.add_task_rounded,
          child: _CommandActionForm(
            saving: _saving,
            onSubmit: (message) async {
              setState(() => _saving = true);
              try {
                await widget.saveAction(
                  actionType: action.actionType,
                  title: action.title,
                  message: message,
                  priority: action.priority,
                  entityId: action.entityId,
                  dueDate: action.dueDate,
                );
                return true;
              } catch (error) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Unable to save action: $error'),
                      backgroundColor: AppTheme.error,
                    ),
                  );
                }
                return false;
              } finally {
                if (mounted) setState(() => _saving = false);
              }
            },
          ),
        ),
      ),
    );
    if (result == true) await _load();
  }

  String _labelize(String key) {
    final label = key.replaceAll('_', ' ').trim();
    if (label.isEmpty) return 'Field';
    return '${label[0].toUpperCase()}${label.substring(1)}';
  }
}

class _CommandDirectoryEntry {
  final String section;
  final Map<String, dynamic> row;
  final IconData icon;
  final String title;
  final String subtitle;
  final String status;
  final String date;
  final String value;

  const _CommandDirectoryEntry({
    required this.section,
    required this.row,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.date,
    required this.value,
  });

  String get searchText => [
    section,
    title,
    subtitle,
    status,
    date,
    value,
    row.values.map(_text).join(' '),
  ].join(' ').toLowerCase();
}

class _CommandActionForm extends StatefulWidget {
  final bool saving;
  final Future<bool> Function(String message) onSubmit;

  const _CommandActionForm({required this.saving, required this.onSubmit});

  @override
  State<_CommandActionForm> createState() => _CommandActionFormState();
}

class _CommandActionFormState extends State<_CommandActionForm> {
  final _controller = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _controller,
          minLines: 5,
          maxLines: 8,
          decoration: const InputDecoration(
            labelText: 'Action note',
            prefixIcon: Icon(Icons.rate_review_outlined),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send_outlined),
          label: Text(_saving ? 'Saving...' : 'Save action'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final message = _controller.text.trim();
    if (message.isEmpty) return;
    setState(() => _saving = true);
    final ok = await widget.onSubmit(message);
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.pop(context, true);
  }
}

class _TimetableWorkflowStrip extends StatelessWidget {
  const _TimetableWorkflowStrip();

  @override
  Widget build(BuildContext context) {
    return const _PrincipalWorkflowStrip(
      steps: [
        _WorkflowStep(
          icon: Icons.meeting_room_outlined,
          label: 'Pick class',
          helper: 'Choose section',
        ),
        _WorkflowStep(
          icon: Icons.calendar_today_outlined,
          label: 'Pick day',
          helper: 'Set weekday',
        ),
        _WorkflowStep(
          icon: Icons.menu_book_outlined,
          label: 'Assign subject',
          helper: 'Map teacher',
        ),
        _WorkflowStep(
          icon: Icons.schedule_outlined,
          label: 'Set time',
          helper: 'Save period',
        ),
      ],
    );
  }
}

class _ExamWorkflowStrip extends StatelessWidget {
  const _ExamWorkflowStrip();

  @override
  Widget build(BuildContext context) {
    return const _PrincipalWorkflowStrip(
      steps: [
        _WorkflowStep(
          icon: Icons.fact_check_outlined,
          label: 'Readiness',
          helper: 'Types and classes',
        ),
        _WorkflowStep(
          icon: Icons.event_available_outlined,
          label: 'Schedule',
          helper: 'Dates and subjects',
        ),
        _WorkflowStep(
          icon: Icons.monitor_heart_outlined,
          label: 'Monitor',
          helper: 'Live progress',
        ),
        _WorkflowStep(
          icon: Icons.edit_note_outlined,
          label: 'Evaluate',
          helper: 'Marks pending',
        ),
        _WorkflowStep(
          icon: Icons.publish_outlined,
          label: 'Publish',
          helper: 'Principal decision',
        ),
      ],
    );
  }
}

class _PrincipalWorkflowStrip extends StatelessWidget {
  final List<_WorkflowStep> steps;

  const _PrincipalWorkflowStrip({required this.steps});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 4),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFDDEAF2)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7FA6BD).withAlpha(28),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 430;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var index = 0; index < steps.length; index++)
                  SizedBox(
                    width: compact
                        ? (constraints.maxWidth - 8) / 2
                        : (constraints.maxWidth - (8 * (steps.length - 1))) /
                              steps.length,
                    child: _WorkflowStepTile(
                      number: index + 1,
                      step: steps[index],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _WorkflowStep {
  final IconData icon;
  final String label;
  final String helper;

  const _WorkflowStep({
    required this.icon,
    required this.label,
    required this.helper,
  });
}

class _WorkflowStepTile extends StatelessWidget {
  final int number;
  final _WorkflowStep step;

  const _WorkflowStepTile({required this.number, required this.step});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 72),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF5FAFE),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE1EDF5)),
      ),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: principalDirectoryAccent.withAlpha(18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  step.icon,
                  color: principalDirectoryAccent,
                  size: 18,
                ),
              ),
              Positioned(
                right: -4,
                top: -5,
                child: Container(
                  width: 16,
                  height: 16,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: principalDirectoryAccent,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$number',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: principalDirectoryText,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  step.helper,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: principalDirectoryMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExamInputForm extends StatefulWidget {
  final Map<String, dynamic>? exam;
  final Future<void> Function(Map<String, dynamic> payload) onSubmit;

  const _ExamInputForm({this.exam, required this.onSubmit});

  @override
  State<_ExamInputForm> createState() => _ExamInputFormState();
}

class _ExamInputFormState extends State<_ExamInputForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _startDate;
  late final TextEditingController _endDate;

  bool _loading = true;
  bool _saving = false;
  String? _error;
  String _academicYearId = '';
  String _termId = '';
  String _examTypeId = '';
  Map<String, dynamic> _exam = {};

  List<AcademicYearModel> _academicYears = [];
  List<Map<String, dynamic>> _terms = [];
  List<Map<String, dynamic>> _examTypes = [];

  bool get _ready =>
      _academicYearId.isNotEmpty &&
      _termId.isNotEmpty &&
      _examTypeId.isNotEmpty &&
      _examTypes.isNotEmpty &&
      _terms.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _exam = Map<String, dynamic>.from(widget.exam ?? const {});
    _name = TextEditingController(
      text: _text(_exam['exam_name'] ?? _exam['name']),
    );
    _startDate = TextEditingController(
      text: _dateOnly(
        _exam['start_date'],
        fallback: _dateInput(DateTime.now()),
      ),
    );
    _endDate = TextEditingController(
      text: _dateOnly(_exam['end_date'], fallback: _dateInput(DateTime.now())),
    );
    _loadReferences();
  }

  @override
  void dispose() {
    _name.dispose();
    _startDate.dispose();
    _endDate.dispose();
    super.dispose();
  }

  Future<void> _loadReferences() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = BackendApiClient.instance;
      final id = _text(_exam['exam_id'] ?? _exam['id']);
      if (id.isNotEmpty && _text(_exam['academic_year_id']).isEmpty) {
        _exam = await api.getRawMap('/exams/$id');
        _name.text = _text(_exam['exam_name'] ?? _exam['name']);
        _startDate.text = _dateOnly(
          _exam['start_date'],
          fallback: _dateInput(DateTime.now()),
        );
        _endDate.text = _dateOnly(
          _exam['end_date'],
          fallback: _dateInput(DateTime.now()),
        );
      }

      final years = await api.getAcademicYears();
      final examTypes = await api.getExamTypes();
      final yearId = _initialId(
        _text(_exam['academic_year_id']),
        years.map((year) => year.id),
        fallback: years.where((year) => year.isCurrent).firstOrNull?.id,
      );
      final terms = yearId.isEmpty
          ? <Map<String, dynamic>>[]
          : await api.getTerms(yearId);
      if (!mounted) return;
      setState(() {
        _academicYears = years;
        _examTypes = examTypes;
        _academicYearId = yearId;
        _terms = terms;
        _termId = _initialId(
          _text(_exam['term_id']),
          terms.map((term) => _text(term['id'])),
        );
        _examTypeId = _initialId(
          _text(_exam['exam_type_id']),
          examTypes.map((type) => _text(type['id'])),
        );
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load exam setup data. $error';
        _loading = false;
      });
    }
  }

  Future<void> _loadTermsForYear(String yearId) async {
    setState(() {
      _academicYearId = yearId;
      _termId = '';
      _terms = [];
    });
    if (yearId.isEmpty) return;
    try {
      final terms = await BackendApiClient.instance.getTerms(yearId);
      if (!mounted) return;
      setState(() {
        _terms = terms;
        _termId = _initialId('', terms.map((term) => _text(term['id'])));
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'Unable to load terms for academic year. $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return OpsEmptyState(
        icon: Icons.fact_check_outlined,
        title: 'Exam setup unavailable',
        message: _error!,
        actionLabel: 'Retry',
        onAction: _loadReferences,
      );
    }
    if (!_ready) {
      return const OpsEmptyState(
        icon: Icons.rule_folder_outlined,
        title: 'Exam setup required',
        message:
            'Create academic years, terms, and exam types before creating exams.',
      );
    }

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _name,
            enabled: !_saving,
            decoration: const InputDecoration(
              labelText: 'Exam name',
              prefixIcon: Icon(Icons.fact_check_outlined),
            ),
            validator: (value) => _required(value, 'Enter exam name.'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _academicYearId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Academic year',
              prefixIcon: Icon(Icons.calendar_month_outlined),
            ),
            items: _academicYears
                .map(
                  (year) => DropdownMenuItem(
                    value: year.id,
                    child: Text(year.yearLabel),
                  ),
                )
                .toList(),
            validator: (value) => _required(value, 'Select academic year.'),
            onChanged: _saving
                ? null
                : (value) => _loadTermsForYear(value ?? ''),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey('exam-term-$_academicYearId-$_termId'),
            initialValue: _termId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Term',
              prefixIcon: Icon(Icons.date_range_outlined),
            ),
            items: _terms
                .map(
                  (term) => DropdownMenuItem(
                    value: _text(term['id']),
                    child: Text(_termLabel(term)),
                  ),
                )
                .toList(),
            validator: (value) => _required(value, 'Select term.'),
            onChanged: _saving
                ? null
                : (value) => setState(() => _termId = value ?? ''),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _examTypeId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Exam type',
              prefixIcon: Icon(Icons.category_outlined),
            ),
            items: _examTypes
                .where((type) => _text(type['id']).isNotEmpty)
                .map(
                  (type) => DropdownMenuItem(
                    value: _text(type['id']),
                    child: Text(
                      _examTypeLabel(type),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            validator: (value) => _required(value, 'Select exam type.'),
            onChanged: _saving
                ? null
                : (value) => setState(() => _examTypeId = value ?? ''),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _startDate,
            enabled: !_saving,
            keyboardType: TextInputType.datetime,
            decoration: const InputDecoration(
              labelText: 'Start date',
              helperText: 'YYYY-MM-DD',
              prefixIcon: Icon(Icons.event_outlined),
            ),
            validator: _dateValidator,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _endDate,
            enabled: !_saving,
            keyboardType: TextInputType.datetime,
            decoration: const InputDecoration(
              labelText: 'End date',
              helperText: 'YYYY-MM-DD',
              prefixIcon: Icon(Icons.event_available_outlined),
            ),
            validator: _dateValidator,
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(_saving ? 'Saving...' : 'Save exam'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final start = DateTime.parse(_startDate.text.trim());
    final end = DateTime.parse(_endDate.text.trim());
    if (end.isBefore(start)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('End date cannot be before start date.'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.onSubmit({
        'academic_year_id': _academicYearId,
        'term_id': _termId,
        'exam_type_id': _examTypeId,
        'exam_name': _name.text.trim(),
        'start_date': _startDate.text.trim(),
        'end_date': _endDate.text.trim(),
      });
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to save exam: $error'),
          backgroundColor: AppTheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  static String _dateInput(DateTime date) =>
      date.toIso8601String().split('T').first;

  static String _dateOnly(Object? value, {required String fallback}) {
    final parsed = DateTime.tryParse(_text(value));
    return parsed == null ? fallback : _dateInput(parsed);
  }

  static String _initialId(
    String preferred,
    Iterable<String> options, {
    String? fallback,
  }) {
    final values = options.where((value) => value.trim().isNotEmpty).toList();
    if (preferred.trim().isNotEmpty && values.contains(preferred)) {
      return preferred;
    }
    if (fallback != null &&
        fallback.trim().isNotEmpty &&
        values.contains(fallback)) {
      return fallback;
    }
    return values.isEmpty ? '' : values.first;
  }

  static String _termLabel(Map<String, dynamic> term) {
    return _text(
      term['term_name'] ?? term['name'] ?? term['label'],
      fallback: _text(term['id'], fallback: 'Term'),
    );
  }

  static String _examTypeLabel(Map<String, dynamic> type) {
    return _text(
      type['name'] ?? type['exam_type'] ?? type['label'],
      fallback: _text(type['id'], fallback: 'Exam type'),
    );
  }

  static String? _required(String? value, String message) {
    return (value ?? '').trim().isEmpty ? message : null;
  }

  static String? _dateValidator(String? value) {
    final text = (value ?? '').trim();
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text)) {
      return 'Use YYYY-MM-DD.';
    }
    return DateTime.tryParse(text) == null ? 'Enter a valid date.' : null;
  }
}

class _TimetableSlotInputForm extends StatefulWidget {
  final Map<String, dynamic>? period;
  final Future<void> Function(Map<String, dynamic> payload) onSubmit;

  const _TimetableSlotInputForm({this.period, required this.onSubmit});

  @override
  State<_TimetableSlotInputForm> createState() =>
      _TimetableSlotInputFormState();
}

class _TimetableSlotInputFormState extends State<_TimetableSlotInputForm> {
  static const _days = <int, String>{
    1: 'Monday',
    2: 'Tuesday',
    3: 'Wednesday',
    4: 'Thursday',
    5: 'Friday',
    6: 'Saturday',
    7: 'Sunday',
  };

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _period;
  late final TextEditingController _start;
  late final TextEditingController _end;

  bool _loading = true;
  bool _saving = false;
  String? _error;
  String _sectionId = '';
  String _academicYearId = '';
  String _termId = '';
  String _subjectId = '';
  String _staffId = '';
  int _day = DateTime.now().weekday;

  List<SectionModel> _sections = [];
  List<AcademicYearModel> _academicYears = [];
  List<Map<String, dynamic>> _terms = [];
  List<Map<String, dynamic>> _subjects = [];
  List<StaffModel> _staff = [];

  bool get _ready =>
      _sectionId.isNotEmpty &&
      _academicYearId.isNotEmpty &&
      _termId.isNotEmpty &&
      _subjectId.isNotEmpty &&
      _staffId.isNotEmpty;

  @override
  void initState() {
    super.initState();
    final period = widget.period ?? const <String, dynamic>{};
    _period = TextEditingController(
      text: _text(period['period_number'] ?? period['period'], fallback: '1'),
    );
    _start = TextEditingController(
      text: _text(period['start_time'], fallback: '09:00'),
    );
    _end = TextEditingController(
      text: _text(period['end_time'], fallback: '09:40'),
    );
    final day = _int(period['day_of_week']);
    if (day >= 1 && day <= 7) _day = day;
    _loadReferences();
  }

  @override
  void dispose() {
    _period.dispose();
    _start.dispose();
    _end.dispose();
    super.dispose();
  }

  Future<void> _loadReferences() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = BackendApiClient.instance;
      final years = await api.getAcademicYears();
      final results = await Future.wait<Object>([
        api.getSections(),
        api.getStaff(page: 1, pageSize: 300, status: 'active'),
        api.getRawList('/subjects'),
      ]);
      final preferredYear = _text(widget.period?['academic_year_id']);
      final yearId = _initialId(
        preferredYear,
        years.map((year) => year.id),
        fallback: years.where((year) => year.isCurrent).firstOrNull?.id,
      );
      final terms = yearId.isEmpty
          ? <Map<String, dynamic>>[]
          : await api.getTerms(yearId);
      if (!mounted) return;
      final sections = results[0] as List<SectionModel>;
      final staff = (results[1] as PaginatedList<StaffModel>).data;
      final subjects = results[2] as List<Map<String, dynamic>>;
      setState(() {
        _academicYears = years;
        _sections = sections;
        _staff = staff;
        _subjects = subjects;
        _academicYearId = yearId;
        _terms = terms;
        _termId = _initialId(
          _text(widget.period?['term_id']),
          terms.map((term) => _text(term['id'])),
        );
        _sectionId = _initialId(
          _text(widget.period?['section_id']),
          sections.map((section) => section.id),
        );
        _subjectId = _initialId(
          _text(widget.period?['subject_id']),
          subjects.map((subject) => _text(subject['id'])),
        );
        _staffId = _initialId(
          _text(widget.period?['staff_id']),
          staff.map((item) => item.id),
        );
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load timetable setup data. $error';
        _loading = false;
      });
    }
  }

  Future<void> _loadTermsForYear(String yearId) async {
    setState(() {
      _academicYearId = yearId;
      _termId = '';
      _terms = [];
    });
    if (yearId.isEmpty) return;
    try {
      final terms = await BackendApiClient.instance.getTerms(yearId);
      if (!mounted) return;
      setState(() {
        _terms = terms;
        _termId = _initialId('', terms.map((term) => _text(term['id'])));
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'Unable to load terms for academic year. $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return OpsEmptyState(
        icon: Icons.calendar_view_week_outlined,
        title: 'Timetable setup unavailable',
        message: _error!,
        actionLabel: 'Retry',
        onAction: _loadReferences,
      );
    }
    if (!_ready) {
      return const OpsEmptyState(
        icon: Icons.rule_folder_outlined,
        title: 'Setup data required',
        message:
            'Create classes, academic terms, subjects, and active staff before creating timetable periods.',
      );
    }

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _academicYearId,
            decoration: const InputDecoration(labelText: 'Academic year'),
            items: _academicYears
                .map(
                  (year) => DropdownMenuItem(
                    value: year.id,
                    child: Text(year.yearLabel),
                  ),
                )
                .toList(),
            validator: (value) => _required(value, 'Select academic year.'),
            onChanged: _saving
                ? null
                : (value) => _loadTermsForYear(value ?? ''),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey('term-$_academicYearId-$_termId'),
            initialValue: _termId,
            decoration: const InputDecoration(labelText: 'Term'),
            items: _terms
                .map(
                  (term) => DropdownMenuItem(
                    value: _text(term['id']),
                    child: Text(_text(term['term_name'] ?? term['name'])),
                  ),
                )
                .toList(),
            validator: (value) => _required(value, 'Select term.'),
            onChanged: _saving
                ? null
                : (value) => setState(() => _termId = value ?? ''),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _sectionId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Class / section'),
            items: _sections
                .map(
                  (section) => DropdownMenuItem(
                    value: section.id,
                    child: Text(
                      _sectionLabel(section),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            validator: (value) => _required(value, 'Select class.'),
            onChanged: _saving
                ? null
                : (value) => setState(() => _sectionId = value ?? ''),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _day,
            decoration: const InputDecoration(labelText: 'Day'),
            items: [
              for (final entry in _days.entries)
                DropdownMenuItem(value: entry.key, child: Text(entry.value)),
            ],
            onChanged: _saving
                ? null
                : (value) => setState(() => _day = value ?? _day),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _period,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Period number'),
            validator: (value) {
              final parsed = int.tryParse((value ?? '').trim()) ?? 0;
              return parsed <= 0 ? 'Enter a positive period number.' : null;
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _subjectId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Subject'),
            items: _subjects
                .map(
                  (subject) => DropdownMenuItem(
                    value: _text(subject['id']),
                    child: Text(
                      _subjectLabel(subject),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            validator: (value) => _required(value, 'Select subject.'),
            onChanged: _saving
                ? null
                : (value) => setState(() => _subjectId = value ?? ''),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _staffId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Teacher'),
            items: _staff
                .map(
                  (staff) => DropdownMenuItem(
                    value: staff.id,
                    child: Text(
                      _staffLabel(staff),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            validator: (value) => _required(value, 'Select teacher.'),
            onChanged: _saving
                ? null
                : (value) => setState(() => _staffId = value ?? ''),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _start,
                  decoration: const InputDecoration(
                    labelText: 'Start time',
                    helperText: 'HH:MM',
                  ),
                  validator: _timeValidator,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _end,
                  decoration: const InputDecoration(
                    labelText: 'End time',
                    helperText: 'HH:MM',
                  ),
                  validator: _timeValidator,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(_saving ? 'Saving...' : 'Save timetable period'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await widget.onSubmit({
        'section_id': _sectionId,
        'academic_year_id': _academicYearId,
        'term_id': _termId,
        'day_of_week': _day,
        'period_number': int.parse(_period.text.trim()),
        'subject_id': _subjectId,
        'staff_id': _staffId,
        'start_time': _start.text.trim(),
        'end_time': _end.text.trim(),
      });
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to save timetable period: $error'),
          backgroundColor: AppTheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  static String _initialId(
    String preferred,
    Iterable<String> options, {
    String? fallback,
  }) {
    final values = options.where((value) => value.trim().isNotEmpty).toList();
    if (preferred.trim().isNotEmpty && values.contains(preferred)) {
      return preferred;
    }
    if (fallback != null &&
        fallback.trim().isNotEmpty &&
        values.contains(fallback)) {
      return fallback;
    }
    return values.isEmpty ? '' : values.first;
  }

  static String _sectionLabel(SectionModel section) {
    final grade = section.gradeName.trim();
    final name = section.sectionName.trim();
    if (grade.isEmpty) return name.isEmpty ? section.id : name;
    return name.isEmpty ? grade : '$grade - $name';
  }

  static String _subjectLabel(Map<String, dynamic> subject) => _text(
    subject['subject_name'] ?? subject['name'] ?? subject['subject_code'],
    fallback: _text(subject['id']),
  );

  static String _staffLabel(StaffModel staff) {
    final name = staff.fullName.trim();
    if (name.isNotEmpty) return name;
    final email = (staff.email ?? '').trim();
    return email.isEmpty ? staff.id : email;
  }

  static String? _required(String? value, String message) {
    return (value ?? '').trim().isEmpty ? message : null;
  }

  static String? _timeValidator(String? value) {
    final text = (value ?? '').trim();
    if (!RegExp(r'^\d{2}:\d{2}$').hasMatch(text)) return 'Use HH:MM.';
    final hour = int.tryParse(text.substring(0, 2)) ?? -1;
    final minute = int.tryParse(text.substring(3, 5)) ?? -1;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      return 'Enter a valid time.';
    }
    return null;
  }
}

class _TimetableModePicker extends StatelessWidget {
  final _TimetableMode selected;
  final ValueChanged<_TimetableMode> onSelected;

  const _TimetableModePicker({
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return OpsPanel(
      title: 'Timetable Views',
      subtitle:
          'Move through periods, class coverage, teacher load, room usage, and conflicts',
      child: OpsModeSelector<_TimetableMode>(
        selected: selected,
        onSelected: onSelected,
        options: const [
          OpsModeOption(
            value: _TimetableMode.periods,
            icon: Icons.schedule_outlined,
            label: 'Periods',
          ),
          OpsModeOption(
            value: _TimetableMode.coverage,
            icon: Icons.meeting_room_outlined,
            label: 'Coverage',
          ),
          OpsModeOption(
            value: _TimetableMode.staff,
            icon: Icons.badge_outlined,
            label: 'Staff',
          ),
          OpsModeOption(
            value: _TimetableMode.rooms,
            icon: Icons.door_back_door_outlined,
            label: 'Rooms',
          ),
          OpsModeOption(
            value: _TimetableMode.alerts,
            icon: Icons.warning_amber_rounded,
            label: 'Alerts',
          ),
        ],
      ),
    );
  }
}

Widget _rowsPanel(
  String title,
  String subtitle,
  List<Map<String, dynamic>> rows,
  IconData icon,
) {
  return OpsPanel(
    title: title,
    subtitle: subtitle,
    child: rows.isEmpty
        ? const Text('No backend rows to review.')
        : Column(
            children: [
              for (final row in rows.take(8))
                OpsListRow(
                  icon: icon,
                  title: _rowTitle(row),
                  subtitle: _rowSubtitle(row),
                  trailing: OpsStatusPill(
                    label: _text(
                      row['status'] ?? row['priority'] ?? row['state'],
                      fallback: 'Live',
                    ),
                    color: _statusColor(
                      _text(row['status'] ?? row['priority'] ?? row['state']),
                    ),
                  ),
                ),
            ],
          ),
  );
}

Widget _actionsPanel({
  required String title,
  required String subtitle,
  required List<Map<String, dynamic>> rows,
  required void Function(_ActionSpec action) openAction,
  required String actionType,
}) {
  return OpsPanel(
    title: title,
    subtitle: subtitle,
    trailing: FilledButton.icon(
      onPressed: () => openAction(
        _ActionSpec(
          actionType: actionType,
          title: title,
          priority: 'normal',
          entityId: '',
          dueDate: '',
        ),
      ),
      icon: const Icon(Icons.add_task_rounded),
      label: const Text('Create action'),
    ),
    child: rows.isEmpty
        ? const Text('No recent principal actions.')
        : Column(
            children: [
              for (final row in rows.take(8))
                OpsListRow(
                  icon: Icons.task_alt_outlined,
                  title: _text(
                    row['title'] ?? row['action_type'],
                    fallback: 'Principal action',
                  ),
                  subtitle: _text(row['message'], fallback: 'No message saved'),
                  trailing: OpsStatusPill(
                    label: _text(row['status'], fallback: 'Open'),
                    color: _statusColor(_text(row['status'])),
                  ),
                ),
            ],
          ),
  );
}

List<Map<String, dynamic>> _optionRows(Map<String, dynamic> controls) {
  return [
    {
      'label': 'Exam types',
      'value': _list(controls['exam_types']).length,
      'status': 'ready',
    },
    {
      'label': 'Grades',
      'value': _list(controls['grades']).length,
      'status': 'ready',
    },
    {
      'label': 'Subjects',
      'value': _list(controls['subjects']).length,
      'status': 'ready',
    },
    {
      'label': 'Rooms',
      'value': _list(controls['rooms']).length,
      'status': 'ready',
    },
    {
      'label': 'Assign invigilators',
      'value': _list(controls['staff']).length,
      'status': 'ready',
    },
  ];
}

String _rowTitle(Map<String, dynamic> row) {
  return _text(
    row['title'] ??
        row['label'] ??
        row['class_name'] ??
        row['teacher_name'] ??
        row['subject_name'] ??
        row['room_name'] ??
        row['exam_name'] ??
        row['student_name'] ??
        row['name'],
    fallback: 'Backend row',
  );
}

String _rowSubtitle(Map<String, dynamic> row) {
  final parts = <String>[
    _text(row['subtitle']),
    _text(row['description']),
    _text(row['date'] ?? row['exam_date']),
    _text(row['subject_name']),
    _text(row['teacher_name']),
    _text(row['class_name']),
    _text(row['value']),
  ]..removeWhere((part) => part.isEmpty);
  return parts.isEmpty ? 'Live backend row' : parts.take(3).join(' | ');
}

Color _statusColor(String status) {
  final lower = status.toLowerCase();
  if (lower.contains('complete') ||
      lower.contains('published') ||
      lower.contains('ready')) {
    return Colors.green;
  }
  if (lower.contains('high') ||
      lower.contains('delayed') ||
      lower.contains('conflict')) {
    return Colors.red;
  }
  if (lower.contains('pending') ||
      lower.contains('open') ||
      lower.contains('normal')) {
    return Colors.orange;
  }
  return Colors.indigo;
}

class _Metric {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _Metric(this.label, this.value, this.icon, this.color);
}

class _ActionSpec {
  final String actionType;
  final String title;
  final String priority;
  final String entityId;
  final String dueDate;

  const _ActionSpec({
    required this.actionType,
    this.title = '',
    this.priority = 'normal',
    this.entityId = '',
    this.dueDate = '',
  });
}

Map<String, dynamic> _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

List<Map<String, dynamic>> _list(Object? value) => value is List
    ? value.whereType<Map>().map(Map<String, dynamic>.from).toList()
    : [];

int _int(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? 0;
}

double _num(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse('$value') ?? 0;
}

String _text(Object? value, {String fallback = ''}) {
  final text = '${value ?? ''}'.trim();
  return text.isEmpty || text == 'null' ? fallback : text;
}
