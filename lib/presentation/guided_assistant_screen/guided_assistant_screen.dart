import 'package:flutter/material.dart';

import '../../routes/app_routes.dart';
import '../../services/backend_api_client.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/admin_navigation.dart';
import '../../widgets/app_navigation.dart';
import '../../widgets/erp_module_scaffold.dart';

class GuidedAssistantScreen extends StatefulWidget {
  const GuidedAssistantScreen({super.key});

  @override
  State<GuidedAssistantScreen> createState() => _GuidedAssistantScreenState();
}

class _GuidedAssistantScreenState extends State<GuidedAssistantScreen> {
  final _api = BackendApiClient.instance;
  final _commandController = TextEditingController();
  final _searchController = TextEditingController();
  final _bulkController = TextEditingController();
  final Map<String, TextEditingController> _controllers = {};

  bool _loading = true;
  bool _busy = false;
  String? _error;
  List<Map<String, dynamic>> _actionCards = [];
  List<Map<String, dynamic>> _sessions = [];
  List<Map<String, dynamic>> _workflows = [];
  List<AcademicYearModel> _academicYears = [];
  List<StaffModel> _staff = [];
  List<SectionModel> _sections = [];
  Map<String, dynamic>? _session;
  Map<String, dynamic> _draft = {};
  Map<String, dynamic> _validation = {};
  int _stepIndex = 0;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _commandController.dispose();
    _searchController.dispose();
    _bulkController.dispose();
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait<Object>([
        _api.getAssistantCatalog(),
        _api.getAssistantSessions(),
        _api.getAcademicYears(),
        _api.getStaff(page: 1, pageSize: 300, status: 'active'),
        _api.getSections(),
      ]);
      final catalog = _map(results[0]);
      if (!mounted) return;
      setState(() {
        _actionCards = _listMap(catalog['action_cards']);
        _workflows = _listMap(catalog['workflows']);
        _sessions = _listMap(results[1]);
        _academicYears = results[2] as List<AcademicYearModel>;
        _staff = (results[3] as PaginatedList<StaffModel>).data;
        _sections = results[4] as List<SectionModel>;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load Guided Assistant. $error';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = (_api.currentRoleName ?? 'principal').toLowerCase();
    return SchoolDeskModuleScaffold(
      title: 'Guided Assistant',
      subtitle: 'Administrative workflows',
      drawer: role == 'admin'
          ? AdminDrawer(selectedIndex: 16, onDestinationSelected: (_) {})
          : PrincipalDrawer(selectedIndex: 17, onDestinationSelected: (_) {}),
      actions: [
        if (_session != null)
          IconButton(
            tooltip: 'Bulk import',
            icon: const Icon(Icons.upload_file_outlined),
            onPressed: _busy ? null : _openBulkImport,
          ),
        IconButton(
          tooltip: 'Refresh',
          icon: const Icon(Icons.refresh_rounded),
          onPressed: _busy ? null : _load,
        ),
      ],
      bodyIsScrollable: true,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _StatusPanel(message: _error!, onRetry: _load)
          : AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: _session == null ? _buildLanding() : _buildWorkflow(),
            ),
    );
  }

  Widget _buildLanding() {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;
    final cards = _filteredActionCards;
    return Padding(
      padding: EdgeInsets.all(tokens.spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ChatConversationShell(
            header: 'SchoolDesk Assistant',
            subheader:
                'Guided operations with validation, review, and safe execution.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _ChatBubble(
                  isAssistant: true,
                  child: Text('Good Morning, What would you like to do today?'),
                ),
                const SizedBox(height: 10),
                _ChatBubble(
                  isAssistant: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'You can type an operation or choose a guided action. I will ask one question at a time and will not save anything until you confirm.',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _QuickReplyChip(
                            label: 'Create PP1 class',
                            icon: Icons.school_outlined,
                            onTap: () {
                              _commandController.text = 'Create PP1 class';
                              _startFromCommand();
                            },
                          ),
                          _QuickReplyChip(
                            label: 'Add new student',
                            icon: Icons.person_add_alt_1_outlined,
                            onTap: () => _startWorkflow('student_onboarding'),
                          ),
                          _QuickReplyChip(
                            label: 'Setup fees',
                            icon: Icons.receipt_long_outlined,
                            onTap: () => _startWorkflow('fee_setup'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _CommandComposer(
                  commandController: _commandController,
                  searchController: _searchController,
                  onCommand: _startFromCommand,
                  onSearchChanged: (value) => setState(() => _search = value),
                ),
              ],
            ),
          ),
          SizedBox(height: tokens.spacing.md),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 820;
              final recent = _RecentWorkflowsPanel(
                sessions: _sessions,
                onResume: _resumeSession,
              );
              final suggestions = _AssistantSuggestionsPanel(
                suggestions: const [
                  'Create class can continue into sections, subjects, fees, timetable, and notifications.',
                  'Student admission will ask parent details and class fee assignment.',
                  'Teacher onboarding will suggest subject mapping before timetable generation.',
                ],
              );
              if (!wide) {
                return Column(
                  children: [
                    suggestions,
                    SizedBox(height: tokens.spacing.md),
                    recent,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: suggestions),
                  SizedBox(width: tokens.spacing.md),
                  Expanded(flex: 2, child: recent),
                ],
              );
            },
          ),
          SizedBox(height: tokens.spacing.lg),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 1100
                  ? 4
                  : constraints.maxWidth >= 780
                  ? 3
                  : constraints.maxWidth >= 520
                  ? 2
                  : 1;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: cards.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: columns == 1 ? 4.2 : 2.7,
                ),
                itemBuilder: (context, index) {
                  final card = cards[index];
                  return _AssistantActionCard(
                    title: _text(card['title']),
                    category: _text(card['category']),
                    icon: _iconFor(_text(card['title'])),
                    onTap: () => _startOrOpen(card),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildWorkflow() {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;
    final steps = _currentSteps;
    final safeIndex = steps.isEmpty
        ? 0
        : _stepIndex.clamp(0, steps.length - 1).toInt();
    final current = steps.isEmpty ? <String, dynamic>{} : steps[safeIndex];
    final stepId = _text(current['id']);
    final suggestions = _currentSuggestions;
    return Padding(
      padding: EdgeInsets.all(tokens.spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _text(_session?['title'], fallback: 'Guided workflow'),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _busy ? null : _cancelWorkflow,
                icon: const Icon(Icons.close_rounded),
                label: const Text('Cancel'),
              ),
            ],
          ),
          SizedBox(height: tokens.spacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: steps.isEmpty ? 0 : (_stepIndex + 1) / steps.length,
              minHeight: 8,
            ),
          ),
          SizedBox(height: tokens.spacing.md),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 980;
              final conversation = _ChatConversationShell(
                header: _text(current['title']),
                subheader: '${safeIndex + 1} of ${steps.length} guided steps',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ChatBubble(
                      isAssistant: true,
                      child: Text(_workflowPrompt(current, stepId)),
                    ),
                    const SizedBox(height: 10),
                    _ChatBubble(
                      isAssistant: false,
                      child: Text(_stepAnswerSummary(stepId)),
                    ),
                    const SizedBox(height: 10),
                    _ChatBubble(
                      isAssistant: true,
                      child: _WorkflowPanel(
                        title: 'Your answer',
                        prompt:
                            'Fill this card, then use Next. I will autosave this draft.',
                        child: _buildStepContent(stepId),
                      ),
                    ),
                    if (suggestions.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _ChatBubble(
                        isAssistant: true,
                        child: _AssistantSuggestionsPanel(
                          title: 'Suggestions for this operation',
                          suggestions: suggestions,
                          compact: true,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    _buildStepQuickReplies(stepId),
                  ],
                ),
              );
              final progress = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StepRail(
                    steps: steps,
                    selectedIndex: _stepIndex,
                    onSelected: (index) => setState(() => _stepIndex = index),
                  ),
                  SizedBox(height: tokens.spacing.md),
                  _WorkflowReadinessCard(
                    draftCount: _draft.length,
                    completedCount: _textList(
                      _session?['completed_steps'],
                    ).length,
                    totalSteps: steps.length,
                    validation: _validation,
                  ),
                ],
              );
              if (!wide) {
                return Column(
                  children: [
                    conversation,
                    SizedBox(height: tokens.spacing.md),
                    progress,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 7, child: conversation),
                  SizedBox(width: tokens.spacing.md),
                  SizedBox(width: 300, child: progress),
                ],
              );
            },
          ),
          SizedBox(height: tokens.spacing.md),
          _buildWorkflowActions(stepId, steps.length),
        ],
      ),
    );
  }

  Widget _buildStepContent(String stepId) {
    switch (stepId) {
      case 'class_details':
        return _buildClassDetails();
      case 'sections':
        return _buildSections();
      case 'subjects':
        return _buildSubjects();
      case 'class_teacher':
        return _buildClassTeacher();
      case 'subject_teachers':
        return _buildSubjectTeachers();
      case 'fee_structure':
      case 'fee_items':
        return _buildFees(stepId);
      case 'timetable':
      case 'timetable_details':
        return _buildTimetable(stepId);
      case 'notifications':
        return _buildSettings();
      case 'review':
        return _buildReview();
      default:
        return _buildGenericStep(stepId);
    }
  }

  Widget _buildClassDetails() {
    return _FormGrid(
      children: [
        _textField('class_details', 'class_name', 'Class name'),
        _dropdownField(
          stepId: 'class_details',
          field: 'academic_year_id',
          label: 'Academic year',
          items: [
            for (final year in _academicYears)
              DropdownMenuItem(value: year.id, child: Text(year.yearLabel)),
          ],
        ),
        _textField(
          'class_details',
          'section_count',
          'Section count',
          number: true,
        ),
        _textField('class_details', 'capacity', 'Capacity', number: true),
        _textField(
          'class_details',
          'grade_number',
          'Grade number',
          number: true,
        ),
      ],
    );
  }

  Widget _buildSections() {
    final rows = _list('sections');
    return _EditableRows(
      emptyLabel: 'No sections added',
      onAdd: () => _addRow('sections', {
        'section_name': String.fromCharCode(65 + rows.length),
        'capacity': _field('class_details', 'capacity'),
      }),
      children: [
        for (var i = 0; i < rows.length; i++)
          _EditableRow(
            title: 'Section ${i + 1}',
            onDelete: () => _removeRow('sections', i),
            children: [
              _rowTextField('sections', i, 'section_name', 'Section'),
              _rowTextField(
                'sections',
                i,
                'capacity',
                'Capacity',
                number: true,
              ),
              _rowTextField('sections', i, 'room_id', 'Room ID'),
            ],
          ),
      ],
    );
  }

  Widget _buildSubjects() {
    final rows = _list('subjects');
    return _EditableRows(
      emptyLabel: 'No subjects added',
      onAdd: () => _addRow('subjects', {
        'subject_name': '',
        'subject_type': 'core',
        'periods_per_week': 5,
      }),
      children: [
        for (var i = 0; i < rows.length; i++)
          _EditableRow(
            title: _text(rows[i]['subject_name'], fallback: 'Subject ${i + 1}'),
            onDelete: () => _removeRow('subjects', i),
            children: [
              _rowTextField('subjects', i, 'subject_name', 'Subject'),
              _rowTextField('subjects', i, 'subject_code', 'Code'),
              _rowTextField(
                'subjects',
                i,
                'periods_per_week',
                'Periods',
                number: true,
              ),
              SwitchListTile(
                value: _bool(rows[i]['is_elective']),
                onChanged: (value) =>
                    _setRowField('subjects', i, 'is_elective', value),
                title: const Text('Elective'),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildClassTeacher() {
    return _FormGrid(
      children: [
        _staffDropdown('class_teacher', 'class_teacher_id', 'Class teacher'),
      ],
    );
  }

  Widget _buildSubjectTeachers() {
    final subjects = _list('subjects');
    final rows = _list('subject_teachers');
    if (rows.isEmpty && subjects.isNotEmpty) {
      for (final subject in subjects) {
        rows.add({'subject_name': subject['subject_name'], 'teacher_id': ''});
      }
      _draft['subject_teachers'] = rows;
    }
    return _EditableRows(
      emptyLabel: 'Add subjects first',
      onAdd: () =>
          _addRow('subject_teachers', {'subject_name': '', 'teacher_id': ''}),
      children: [
        for (var i = 0; i < rows.length; i++)
          _EditableRow(
            title: _text(
              rows[i]['subject_name'],
              fallback: 'Subject teacher ${i + 1}',
            ),
            onDelete: () => _removeRow('subject_teachers', i),
            children: [
              _rowTextField('subject_teachers', i, 'subject_name', 'Subject'),
              _rowStaffDropdown('subject_teachers', i, 'teacher_id', 'Teacher'),
            ],
          ),
      ],
    );
  }

  Widget _buildFees(String stepId) {
    final key = stepId == 'fee_items' ? 'fee_items' : 'fee_structure';
    final rows = _list(key);
    return _EditableRows(
      emptyLabel: 'No fee items added',
      onAdd: () => _addRow(key, {
        'category_name': 'Tuition',
        'frequency': 'term',
        'amount': 0,
        'due_day': 10,
      }),
      children: [
        for (var i = 0; i < rows.length; i++)
          _EditableRow(
            title: _text(rows[i]['category_name'], fallback: 'Fee ${i + 1}'),
            onDelete: () => _removeRow(key, i),
            children: [
              _rowTextField(key, i, 'category_name', 'Category'),
              _rowTextField(key, i, 'amount', 'Amount', number: true),
              _rowTextField(key, i, 'frequency', 'Frequency'),
              _rowTextField(key, i, 'due_day', 'Due day', number: true),
            ],
          ),
      ],
    );
  }

  Widget _buildTimetable(String stepId) {
    final targetStep = stepId == 'timetable_details'
        ? 'timetable_details'
        : 'timetable';
    return Column(
      children: [
        if (targetStep == 'timetable_details')
          _FormGrid(
            children: [
              _dropdownField(
                stepId: 'timetable_details',
                field: 'section_id',
                label: 'Section',
                items: [
                  for (final section in _sections)
                    DropdownMenuItem(
                      value: section.id,
                      child: Text(
                        [
                          section.gradeName,
                          section.sectionName,
                        ].where((part) => part.trim().isNotEmpty).join(' '),
                      ),
                    ),
                ],
              ),
              _dropdownField(
                stepId: 'timetable_details',
                field: 'academic_year_id',
                label: 'Academic year',
                items: [
                  for (final year in _academicYears)
                    DropdownMenuItem(
                      value: year.id,
                      child: Text(year.yearLabel),
                    ),
                ],
              ),
              _textField('timetable_details', 'term_id', 'Term ID'),
            ],
          )
        else
          Column(
            children: [
              SwitchListTile(
                value: _bool(_field('timetable', 'auto_generate')),
                onChanged: (value) => setState(
                  () => _setField('timetable', 'auto_generate', value),
                ),
                title: const Text('Auto generate timetable'),
                contentPadding: EdgeInsets.zero,
              ),
              _FormGrid(
                children: [
                  _textField('timetable', 'term_id', 'Term ID'),
                  _textField(
                    'timetable',
                    'periods_per_day',
                    'Periods per day',
                    number: true,
                  ),
                  _textField('timetable', 'start_time', 'Start time'),
                  _textField(
                    'timetable',
                    'period_duration_minutes',
                    'Period minutes',
                    number: true,
                  ),
                ],
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildSettings() {
    return Column(
      children: [
        SwitchListTile(
          value: _bool(_field('notifications', 'notify_staff')),
          onChanged: (value) =>
              setState(() => _setField('notifications', 'notify_staff', value)),
          title: const Text('Notify staff'),
          contentPadding: EdgeInsets.zero,
        ),
        _FormGrid(
          children: [
            _textField('notifications', 'attendance_rule', 'Attendance rule'),
            _textField('notifications', 'grading_system', 'Grading system'),
          ],
        ),
      ],
    );
  }

  Widget _buildGenericStep(String stepId) {
    final fields = _currentSteps.firstWhere(
      (step) => _text(step['id']) == stepId,
      orElse: () => const <String, dynamic>{},
    )['fields'];
    final list = fields is List ? fields : const [];
    return _FormGrid(
      children: [
        for (final field in list)
          _textField(stepId, '$field', _label('$field')),
      ],
    );
  }

  Widget _buildReview() {
    final issues = _listMap(_validation['issues']);
    final suggestions = _textList(_validation['suggestions']);
    final valid = _validation['valid'] == true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _SummaryChip(
              label: 'Sections',
              value: '${_list('sections').length}',
            ),
            _SummaryChip(
              label: 'Subjects',
              value: '${_list('subjects').length}',
            ),
            _SummaryChip(
              label: 'Fees',
              value:
                  '${_list('fee_structure').length + _list('fee_items').length}',
            ),
            _SummaryChip(label: 'Ready', value: valid ? 'Yes' : 'Check'),
          ],
        ),
        const SizedBox(height: 16),
        if (issues.isEmpty)
          const _InlineNotice(
            icon: Icons.task_alt_rounded,
            message: 'Run validation before execution.',
          )
        else
          for (final issue in issues)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _InlineNotice(
                icon: _text(issue['severity']) == 'error'
                    ? Icons.error_outline_rounded
                    : Icons.info_outline_rounded,
                message: _text(issue['message']),
                isError: _text(issue['severity']) == 'error',
              ),
            ),
        if (suggestions.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Operational suggestions',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          for (final suggestion in suggestions)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _InlineNotice(
                icon: Icons.lightbulb_outline_rounded,
                message: suggestion,
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildWorkflowActions(String stepId, int stepCount) {
    final last = _stepIndex >= stepCount - 1;
    return _Surface(
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.spaceBetween,
        children: [
          OutlinedButton.icon(
            onPressed: _busy || _stepIndex == 0
                ? null
                : () => setState(() => _stepIndex--),
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Back'),
          ),
          OutlinedButton.icon(
            onPressed: _busy ? null : () => _saveStep(stepId, completed: false),
            icon: const Icon(Icons.save_outlined),
            label: const Text('Save draft'),
          ),
          if (!last)
            FilledButton.icon(
              onPressed: _busy ? null : () => _nextStep(stepId),
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('Next question'),
            )
          else ...[
            OutlinedButton.icon(
              onPressed: _busy ? null : _validateSession,
              icon: const Icon(Icons.rule_rounded),
              label: const Text('Validate'),
            ),
            FilledButton.icon(
              onPressed: _busy ? null : _executeSession,
              icon: const Icon(Icons.verified_rounded),
              label: const Text('Confirm & execute'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStepQuickReplies(String stepId) {
    final last = _stepIndex >= _currentSteps.length - 1;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (stepId == 'class_details') ...[
          _QuickReplyChip(
            label: '2 sections',
            icon: Icons.splitscreen_rounded,
            onTap: () =>
                setState(() => _setField('class_details', 'section_count', 2)),
          ),
          _QuickReplyChip(
            label: '30 capacity',
            icon: Icons.groups_2_outlined,
            onTap: () =>
                setState(() => _setField('class_details', 'capacity', 30)),
          ),
        ],
        if (stepId == 'subjects')
          _QuickReplyChip(
            label: 'Add core subjects',
            icon: Icons.menu_book_outlined,
            onTap: () => setState(() {
              _draft['subjects'] = [
                {'subject_name': 'English', 'periods_per_week': 5},
                {'subject_name': 'Math', 'periods_per_week': 5},
                {'subject_name': 'EVS', 'periods_per_week': 4},
              ];
            }),
          ),
        if (stepId == 'fee_structure' || stepId == 'fee_items')
          _QuickReplyChip(
            label: 'Add common fees',
            icon: Icons.receipt_long_outlined,
            onTap: () => setState(() {
              final key = stepId == 'fee_items' ? 'fee_items' : 'fee_structure';
              _draft[key] = [
                {
                  'category_name': 'Tuition',
                  'frequency': 'term',
                  'amount': 0,
                  'due_day': 10,
                },
                {
                  'category_name': 'Books',
                  'frequency': 'annual',
                  'amount': 0,
                  'due_day': 10,
                },
              ];
            }),
          ),
        _QuickReplyChip(
          label: 'Save answer',
          icon: Icons.save_outlined,
          onTap: () {
            _saveStep(stepId, completed: false);
          },
        ),
        _QuickReplyChip(
          label: last ? 'Validate now' : 'Ask next question',
          icon: last ? Icons.rule_rounded : Icons.arrow_forward_rounded,
          onTap: () {
            if (last) {
              _validateSession();
            } else {
              _nextStep(stepId);
            }
          },
        ),
      ],
    );
  }

  String _workflowPrompt(Map<String, dynamic> current, String stepId) {
    final prompt = _text(current['prompt']);
    switch (stepId) {
      case 'class_details':
        return 'Sure. First I need the class name, academic year, section count, and capacity. $prompt';
      case 'sections':
        return 'Now tell me the sections and room allocations. If you do not add names, I can generate Section A, B, and so on.';
      case 'subjects':
        return 'Which subjects should this class study? Add compulsory subjects now so timetable and reports are ready.';
      case 'class_teacher':
        return 'Who should be the class teacher? I will validate the teacher belongs to this school before execution.';
      case 'subject_teachers':
        return 'Now map each subject to a teacher. This helps avoid timetable gaps later.';
      case 'fee_structure':
      case 'fee_items':
        return 'Do you want to attach the fee structure now? Add tuition, books, transport, or mark optional fees later.';
      case 'timetable':
      case 'timetable_details':
        return 'Should I generate the timetable from teacher-subject mappings? I will check availability rules before final save.';
      case 'notifications':
        return 'Last setup question: choose attendance, grading, and notification preferences.';
      case 'review':
        return 'Please review everything. I will only execute after you validate and confirm.';
      default:
        return prompt.isEmpty ? 'Please answer this setup question.' : prompt;
    }
  }

  String _stepAnswerSummary(String stepId) {
    switch (stepId) {
      case 'class_details':
        final name = _field('class_details', 'class_name');
        final sections = _field('class_details', 'section_count');
        final capacity = _field('class_details', 'capacity');
        if ([name, sections, capacity].every((value) => value.isEmpty)) {
          return 'I have not entered class details yet.';
        }
        return 'Class: ${_text(name, fallback: 'not set')}, sections: ${_text(sections, fallback: 'not set')}, capacity: ${_text(capacity, fallback: 'not set')}.';
      case 'sections':
        final rows = _list('sections');
        return rows.isEmpty
            ? 'No section names added yet.'
            : '${rows.length} section${rows.length == 1 ? '' : 's'} added.';
      case 'subjects':
        final rows = _list('subjects');
        return rows.isEmpty
            ? 'No subjects added yet.'
            : rows.map((row) => _text(row['subject_name'])).join(', ');
      case 'class_teacher':
        return _field('class_teacher', 'class_teacher_id').isEmpty
            ? 'Class teacher is not selected yet.'
            : 'Class teacher selected.';
      case 'subject_teachers':
        final rows = _list('subject_teachers');
        return rows.isEmpty
            ? 'Subject teachers are not mapped yet.'
            : '${rows.length} subject teacher mapping${rows.length == 1 ? '' : 's'} drafted.';
      case 'fee_structure':
      case 'fee_items':
        final rows = _list(
          stepId == 'fee_items' ? 'fee_items' : 'fee_structure',
        );
        return rows.isEmpty
            ? 'Fee structure is not added yet.'
            : '${rows.length} fee item${rows.length == 1 ? '' : 's'} drafted.';
      case 'timetable':
      case 'timetable_details':
        return _bool(_field('timetable', 'auto_generate'))
            ? 'Auto timetable generation is enabled.'
            : 'Timetable generation is not enabled yet.';
      case 'notifications':
        return _bool(_field('notifications', 'notify_staff'))
            ? 'Staff notification is enabled.'
            : 'Notification preferences are not finalized.';
      case 'review':
        return _validation.isEmpty
            ? 'Validation has not been run yet.'
            : 'Validation is ready for review.';
      default:
        return 'I am ready for your answer.';
    }
  }

  List<String> get _currentSuggestions {
    final steps = _currentSteps;
    if (steps.isEmpty) return const [];
    final safeIndex = _stepIndex.clamp(0, steps.length - 1).toInt();
    final current = steps[safeIndex];
    final stepId = _text(current['id']);
    final suggestions = <String>[
      ..._textList(current['suggestions']),
      ..._textList(_validation['suggestions']),
      ..._stepSuggestions(stepId),
    ];
    final seen = <String>{};
    return suggestions.where((item) => seen.add(item)).take(5).toList();
  }

  List<String> _stepSuggestions(String stepId) {
    switch (stepId) {
      case 'class_details':
        return const [
          'Start with academic year and capacity because section and fee setup depend on them.',
          'If you typed a command like Create PP1 class, review the detected class name before moving ahead.',
        ];
      case 'sections':
        return const [
          'Assign rooms here if classroom allocation is already decided.',
          'Leaving sections empty allows the assistant to generate Section A from the section count.',
        ];
      case 'subjects':
        return const [
          'Add core subjects now to avoid a second setup pass before timetable generation.',
        ];
      case 'class_teacher':
        return const [
          'Choose an active staff member so workload and school-scope checks can run.',
        ];
      case 'subject_teachers':
        return const [
          'Subject teacher mapping improves timetable generation and classroom reporting.',
        ];
      case 'fee_structure':
      case 'fee_items':
        return const [
          'Add due day and frequency now so invoices and reports stay complete.',
        ];
      case 'timetable':
      case 'timetable_details':
        return const [
          'Generate timetable after subject teachers are mapped to reduce manual correction.',
        ];
      case 'notifications':
        return const [
          'Enable staff notification if teachers should be informed after the class is created.',
        ];
      case 'review':
        return const [
          'Run validation first, then confirm execution only after the summary looks correct.',
        ];
      default:
        return const [];
    }
  }

  Future<void> _startOrOpen(Map<String, dynamic> card) async {
    final type = _text(card['workflow_type']);
    if (_workflows.any((workflow) => _text(workflow['type']) == type)) {
      await _startWorkflow(type);
      return;
    }
    final route = _quickRoute(type);
    if (route != null && mounted) {
      Navigator.of(
        context,
      ).pushNamed(route, arguments: type == 'notifications' ? _role : null);
      return;
    }
    _showError(
      'This assistant workflow will be available in a future setup wave.',
    );
  }

  Future<void> _startFromCommand() async {
    final command = _commandController.text.trim();
    if (command.isEmpty) return;
    await _startWorkflow('', command: command);
  }

  Future<void> _startWorkflow(
    String workflowType, {
    String command = '',
  }) async {
    setState(() => _busy = true);
    try {
      final session = await _api.createAssistantSession(
        workflowType: workflowType,
        command: command,
      );
      _useSession(session);
    } catch (error) {
      _showError('$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _resumeSession(Map<String, dynamic> session) {
    _useSession(session);
  }

  void _useSession(Map<String, dynamic> session) {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
    final draft = _map(session['draft_data']);
    setState(() {
      _session = session;
      _draft = draft;
      _validation = _map(session['validation_summary']);
      _stepIndex = _stepIndexFor(_text(session['current_step_id']));
    });
  }

  Future<void> _nextStep(String stepId) async {
    await _saveStep(stepId, completed: true);
    if (!mounted) return;
    setState(() {
      final maxIndex = _currentSteps.isEmpty ? 0 : _currentSteps.length - 1;
      _stepIndex = (_stepIndex + 1).clamp(0, maxIndex).toInt();
    });
  }

  Future<void> _saveStep(String stepId, {required bool completed}) async {
    final session = _session;
    if (session == null) return;
    setState(() => _busy = true);
    try {
      final updated = await _api.saveAssistantStep(
        sessionId: _text(session['id']),
        stepId: stepId,
        draftData: _draft,
        completed: completed,
        currentStepId: stepId,
      );
      if (mounted) {
        setState(() {
          _session = updated;
          _draft = _map(updated['draft_data']);
        });
      }
    } catch (error) {
      _showError('$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _validateSession() async {
    final session = _session;
    if (session == null) return;
    await _saveStep('review', completed: true);
    setState(() => _busy = true);
    try {
      final result = await _api.validateAssistantSession(_text(session['id']));
      if (!mounted) return;
      setState(() {
        _session = _map(result['session']);
        _validation = _map(result['validation']);
      });
    } catch (error) {
      _showError('$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _executeSession() async {
    final session = _session;
    if (session == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm execution'),
        content: const Text(
          'This will apply the reviewed operations to the ERP records.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Execute'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      final result = await _api.executeAssistantSession(_text(session['id']));
      if (!mounted) return;
      setState(() {
        _session = _map(result['session']);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Assistant workflow executed')),
      );
    } catch (error) {
      _showError('$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancelWorkflow() async {
    final session = _session;
    if (session != null && _text(session['id']).isNotEmpty) {
      await _api.cancelAssistantSession(_text(session['id']));
    }
    if (!mounted) return;
    setState(() {
      _session = null;
      _draft = {};
      _validation = {};
    });
    await _load();
  }

  Future<void> _openBulkImport() async {
    final session = _session;
    if (session == null) return;
    final workflowType = _text(session['workflow_type']);
    final template = await _api.getAssistantTemplate(workflowType);
    String format = 'csv';
    _bulkController.text = _text(template['sample_csv']);
    if (!mounted) return;
    final imported = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Bulk input'),
          content: SizedBox(
            width: 560,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'csv', label: Text('CSV')),
                    ButtonSegment(value: 'txt', label: Text('TXT')),
                  ],
                  selected: {format},
                  onSelectionChanged: (value) {
                    setDialogState(() {
                      format = value.first;
                      _bulkController.text = format == 'csv'
                          ? _text(template['sample_csv'])
                          : _text(template['txt_format']);
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _bulkController,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Close'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Import'),
            ),
          ],
        ),
      ),
    );
    if (imported != true) return;
    setState(() => _busy = true);
    try {
      final result = await _api.importAssistantPreview(
        sessionId: _text(session['id']),
        format: format,
        content: _bulkController.text,
      );
      if (!mounted) return;
      _useSession(_map(result['session']));
    } catch (error) {
      _showError('$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _textField(
    String stepId,
    String field,
    String label, {
    bool number = false,
  }) {
    final key = '$stepId.$field';
    final controller = _controller(key, _field(stepId, field));
    return TextFormField(
      controller: controller,
      keyboardType: number ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      onChanged: (value) => _setField(
        stepId,
        field,
        number ? (num.tryParse(value) ?? value) : value,
      ),
    );
  }

  Widget _rowTextField(
    String listKey,
    int index,
    String field,
    String label, {
    bool number = false,
  }) {
    final rows = _list(listKey);
    final key = '$listKey.$index.$field';
    final controller = _controller(
      key,
      rows.length > index ? '${rows[index][field] ?? ''}' : '',
    );
    return TextFormField(
      controller: controller,
      keyboardType: number ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      onChanged: (value) => _setRowField(
        listKey,
        index,
        field,
        number ? (num.tryParse(value) ?? value) : value,
      ),
    );
  }

  Widget _dropdownField({
    required String stepId,
    required String field,
    required String label,
    required List<DropdownMenuItem<String>> items,
  }) {
    final value = _field(stepId, field);
    final allowed = items.any((item) => item.value == value);
    return DropdownButtonFormField<String>(
      value: allowed ? value : null,
      items: items,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      onChanged: (value) =>
          setState(() => _setField(stepId, field, value ?? '')),
    );
  }

  Widget _staffDropdown(String stepId, String field, String label) {
    return _dropdownField(
      stepId: stepId,
      field: field,
      label: label,
      items: [
        for (final staff in _staff)
          DropdownMenuItem(
            value: staff.id,
            child: Text('${staff.firstName} ${staff.lastName}'.trim()),
          ),
      ],
    );
  }

  Widget _rowStaffDropdown(
    String listKey,
    int index,
    String field,
    String label,
  ) {
    final rows = _list(listKey);
    final value = rows.length > index ? _text(rows[index][field]) : '';
    final allowed = _staff.any((item) => item.id == value);
    return DropdownButtonFormField<String>(
      value: allowed ? value : null,
      items: [
        for (final staff in _staff)
          DropdownMenuItem(
            value: staff.id,
            child: Text('${staff.firstName} ${staff.lastName}'.trim()),
          ),
      ],
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      onChanged: (value) =>
          setState(() => _setRowField(listKey, index, field, value ?? '')),
    );
  }

  TextEditingController _controller(String key, String value) {
    return _controllers.putIfAbsent(
      key,
      () => TextEditingController(text: value),
    );
  }

  String _field(String stepId, String field) {
    final map = _map(_draft[stepId]);
    return _text(map[field]);
  }

  void _setField(String stepId, String field, Object? value) {
    final map = Map<String, dynamic>.from(_map(_draft[stepId]));
    map[field] = value;
    _draft[stepId] = map;
  }

  List<Map<String, dynamic>> _list(String key) {
    final value = _draft[key];
    if (value is List) return _listMap(value);
    final nested = _map(value);
    if (nested['items'] is List) return _listMap(nested['items']);
    return <Map<String, dynamic>>[];
  }

  void _addRow(String key, Map<String, dynamic> row) {
    setState(() {
      final rows = _list(key);
      rows.add(row);
      _draft[key] = rows;
    });
  }

  void _removeRow(String key, int index) {
    setState(() {
      final rows = _list(key);
      if (index >= 0 && index < rows.length) rows.removeAt(index);
      _draft[key] = rows;
    });
  }

  void _setRowField(String key, int index, String field, Object? value) {
    final rows = _list(key);
    if (index < 0 || index >= rows.length) return;
    rows[index][field] = value;
    _draft[key] = rows;
  }

  int _stepIndexFor(String stepId) {
    final steps = _currentSteps;
    final index = steps.indexWhere((step) => _text(step['id']) == stepId);
    return index < 0 ? 0 : index;
  }

  List<Map<String, dynamic>> get _currentSteps {
    final def = _map(_session?['definition']);
    return _listMap(def['steps']);
  }

  List<Map<String, dynamic>> get _filteredActionCards {
    final query = _search.trim().toLowerCase();
    if (query.isEmpty) return _actionCards;
    return _actionCards.where((card) {
      return _text(card['title']).toLowerCase().contains(query) ||
          _text(card['category']).toLowerCase().contains(query);
    }).toList();
  }

  String get _role => (_api.currentRoleName ?? 'principal').toLowerCase();

  String? _quickRoute(String type) {
    final principal = _role == 'principal';
    switch (type) {
      case 'attendance':
        return principal
            ? AppRoutes.principalAttendance
            : AppRoutes.adminAttendance;
      case 'exams':
        return principal ? AppRoutes.principalExams : AppRoutes.adminExams;
      case 'notifications':
        return AppRoutes.notificationCenter;
      case 'reports':
        return principal ? AppRoutes.principalResults : AppRoutes.adminReports;
      default:
        return null;
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  IconData _iconFor(String title) {
    switch (title.toLowerCase()) {
      case 'create class':
        return Icons.add_business_outlined;
      case 'add students':
        return Icons.person_add_alt_1_outlined;
      case 'staff management':
        return Icons.groups_2_outlined;
      case 'fees':
        return Icons.account_balance_wallet_outlined;
      case 'timetable':
        return Icons.calendar_month_outlined;
      case 'attendance':
        return Icons.fact_check_outlined;
      case 'exams':
        return Icons.quiz_outlined;
      case 'notifications':
        return Icons.campaign_outlined;
      case 'reports':
        return Icons.bar_chart_outlined;
      case 'transport':
        return Icons.directions_bus_outlined;
      case 'library':
        return Icons.local_library_outlined;
      case 'inventory':
        return Icons.inventory_2_outlined;
      default:
        return Icons.assistant_direction_outlined;
    }
  }

  String _label(String raw) => raw
      .split('_')
      .map(
        (part) => part.isEmpty
            ? part
            : '${part[0].toUpperCase()}${part.substring(1)}',
      )
      .join(' ');

  bool _bool(dynamic value) {
    if (value is bool) return value;
    final text = '$value'.toLowerCase();
    return text == 'true' || text == 'yes' || text == '1';
  }

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  List<Map<String, dynamic>> _listMap(dynamic value) {
    if (value is! List) return [];
    return value
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  List<String> _textList(dynamic value) {
    if (value is! List) return [];
    return value
        .map((item) => _text(item))
        .where((item) => item.isNotEmpty)
        .toList();
  }

  String _text(dynamic value, {String fallback = ''}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty || text == 'null' ? fallback : text;
  }
}

class _ChatConversationShell extends StatelessWidget {
  final String header;
  final String subheader;
  final Widget child;

  const _ChatConversationShell({
    required this.header,
    required this.subheader,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tokens.panelBorder),
        color: theme.colorScheme.surface,
      ),
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _AssistantAvatar(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        header,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subheader,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Chip(
                  avatar: const Icon(Icons.verified_user_outlined, size: 16),
                  label: const Text('Safe mode'),
                  visualDensity: VisualDensity.compact,
                  side: BorderSide(color: tokens.panelBorder),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _AssistantAvatar extends StatelessWidget {
  const _AssistantAvatar();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return CircleAvatar(
      radius: 19,
      backgroundColor: color.withValues(alpha: 0.12),
      child: Icon(Icons.support_agent_rounded, color: color),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final bool isAssistant;
  final Widget child;

  const _ChatBubble({required this.isAssistant, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;
    final background = isAssistant
        ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.55)
        : theme.colorScheme.primary.withValues(alpha: 0.10);
    final borderColor = isAssistant
        ? tokens.panelBorder
        : theme.colorScheme.primary.withValues(alpha: 0.24);
    return Align(
      alignment: isAssistant ? Alignment.centerLeft : Alignment.centerRight,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(8),
              topRight: const Radius.circular(8),
              bottomLeft: Radius.circular(isAssistant ? 2 : 8),
              bottomRight: Radius.circular(isAssistant ? 8 : 2),
            ),
            border: Border.all(color: borderColor),
          ),
          child: Padding(padding: const EdgeInsets.all(12), child: child),
        ),
      ),
    );
  }
}

class _CommandComposer extends StatelessWidget {
  final TextEditingController commandController;
  final TextEditingController searchController;
  final VoidCallback onCommand;
  final ValueChanged<String> onSearchChanged;

  const _CommandComposer({
    required this.commandController,
    required this.searchController,
    required this.onCommand,
    required this.onSearchChanged,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 720;
        final command = TextField(
          controller: commandController,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.chat_bubble_outline_rounded),
            labelText: 'Type your operation',
            hintText: 'Example: Create PP1 class',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              tooltip: 'Send',
              icon: const Icon(Icons.send_rounded),
              onPressed: onCommand,
            ),
          ),
          onSubmitted: (_) => onCommand(),
        );
        final search = TextField(
          controller: searchController,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search_rounded),
            labelText: 'Search actions',
            border: OutlineInputBorder(),
          ),
          onChanged: onSearchChanged,
        );
        if (!wide) {
          return Column(
            children: [command, const SizedBox(height: 10), search],
          );
        }
        return Row(
          children: [
            Expanded(flex: 3, child: command),
            const SizedBox(width: 10),
            Expanded(flex: 2, child: search),
          ],
        );
      },
    );
  }
}

class _QuickReplyChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _QuickReplyChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}

class _AssistantSuggestionsPanel extends StatelessWidget {
  final String title;
  final List<String> suggestions;
  final bool compact;

  const _AssistantSuggestionsPanel({
    required this.suggestions,
    this.title = 'Operational suggestions',
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tokens.panelBorder),
        color: theme.colorScheme.surface,
      ),
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            if (!compact) ...[
              const SizedBox(height: 4),
              Text(
                'These are deterministic ERP suggestions, not free-form AI actions.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 10),
            for (final suggestion in suggestions)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.lightbulb_outline_rounded,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(suggestion)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _WorkflowReadinessCard extends StatelessWidget {
  final int draftCount;
  final int completedCount;
  final int totalSteps;
  final Map<String, dynamic> validation;

  const _WorkflowReadinessCard({
    required this.draftCount,
    required this.completedCount,
    required this.totalSteps,
    required this.validation,
  });

  @override
  Widget build(BuildContext context) {
    final issues = validation['issues'];
    final issueCount = issues is List ? issues.length : 0;
    final ready = validation['valid'] == true;
    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Workflow readiness',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          _ReadinessRow(
            icon: Icons.edit_note_rounded,
            label: 'Draft data',
            value: '$draftCount groups',
          ),
          _ReadinessRow(
            icon: Icons.fact_check_outlined,
            label: 'Completed',
            value: '$completedCount/$totalSteps steps',
          ),
          _ReadinessRow(
            icon: ready ? Icons.verified_rounded : Icons.warning_amber_rounded,
            label: 'Validation',
            value: ready ? 'Ready' : '$issueCount issue(s)',
          ),
          const SizedBox(height: 10),
          const _InlineNotice(
            icon: Icons.lock_outline_rounded,
            message: 'Execution needs final confirmation.',
          ),
        ],
      ),
    );
  }
}

class _ReadinessRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ReadinessRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _RecentWorkflowsPanel extends StatelessWidget {
  final List<Map<String, dynamic>> sessions;
  final ValueChanged<Map<String, dynamic>> onResume;

  const _RecentWorkflowsPanel({required this.sessions, required this.onResume});

  @override
  Widget build(BuildContext context) {
    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent workflows',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          if (sessions.isEmpty)
            const _InlineNotice(
              icon: Icons.history_rounded,
              message: 'No unfinished workflows',
            )
          else
            for (final session in sessions.take(4))
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${session['title'] ?? 'Workflow'}'),
                subtitle: Text('${session['status'] ?? 'draft'}'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => onResume(session),
              ),
        ],
      ),
    );
  }
}

class _AssistantActionCard extends StatelessWidget {
  final String title;
  final String category;
  final IconData icon;
  final VoidCallback onTap;

  const _AssistantActionCard({
    required this.title,
    required this.category,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(child: Icon(icon)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepRail extends StatelessWidget {
  final List<Map<String, dynamic>> steps;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const _StepRail({
    required this.steps,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return _Surface(
      child: Column(
        children: [
          for (var i = 0; i < steps.length; i++)
            ListTile(
              dense: true,
              selected: i == selectedIndex,
              leading: CircleAvatar(radius: 14, child: Text('${i + 1}')),
              title: Text(
                '${steps[i]['title'] ?? ''}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => onSelected(i),
            ),
        ],
      ),
    );
  }
}

class _WorkflowPanel extends StatelessWidget {
  final String title;
  final String prompt;
  final Widget child;

  const _WorkflowPanel({
    required this.title,
    required this.prompt,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tokens.panelBorder),
        color: theme.colorScheme.surface,
      ),
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(prompt, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _FormGrid extends StatelessWidget {
  final List<Widget> children;
  const _FormGrid({required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 680;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final child in children)
              SizedBox(
                width: wide
                    ? (constraints.maxWidth - 12) / 2
                    : constraints.maxWidth,
                child: child,
              ),
          ],
        );
      },
    );
  }
}

class _EditableRows extends StatelessWidget {
  final String emptyLabel;
  final VoidCallback onAdd;
  final List<Widget> children;

  const _EditableRows({
    required this.emptyLabel,
    required this.onAdd,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (children.isEmpty)
          _InlineNotice(icon: Icons.playlist_add_rounded, message: emptyLabel),
        ...children,
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add'),
          ),
        ),
      ],
    );
  }
}

class _EditableRow extends StatelessWidget {
  final String title;
  final VoidCallback onDelete;
  final List<Widget> children;

  const _EditableRow({
    required this.title,
    required this.onDelete,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Remove',
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                ],
              ),
              _FormGrid(children: children),
            ],
          ),
        ),
      ),
    );
  }
}

class _Surface extends StatelessWidget {
  final Widget child;
  const _Surface({required this.child});

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).schoolDesk;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: tokens.panelBorder),
      ),
      child: Padding(padding: EdgeInsets.all(tokens.spacing.md), child: child),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text('$label: $value'));
  }
}

class _InlineNotice extends StatelessWidget {
  final IconData icon;
  final String message;
  final bool isError;
  const _InlineNotice({
    required this.icon,
    required this.message,
    this.isError = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isError
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.primary;
    return Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 8),
        Expanded(child: Text(message)),
      ],
    );
  }
}

class _StatusPanel extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _StatusPanel({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: _Surface(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 36),
            const SizedBox(height: 12),
            Text(message),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
