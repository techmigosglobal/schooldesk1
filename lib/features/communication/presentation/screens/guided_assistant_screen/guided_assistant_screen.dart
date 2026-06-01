import 'package:flutter/material.dart';

import 'package:schooldesk1/routes/app_routes.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';

class GuidedAssistantScreen extends StatefulWidget {
  const GuidedAssistantScreen({super.key});

  @override
  State<GuidedAssistantScreen> createState() => _GuidedAssistantScreenState();
}

class _GuidedAssistantScreenState extends State<GuidedAssistantScreen> {
  final _api = BackendApiClient.instance;
  final _commandController = TextEditingController();
  final _searchController = TextEditingController();
  final Map<String, TextEditingController> _controllers = {};

  bool _loading = true;
  bool _busy = false;
  String? _error;
  List<Map<String, dynamic>> _actionCards = [];
  List<Map<String, dynamic>> _sessions = [];
  List<Map<String, dynamic>> _workflows = [];
  List<AcademicYearModel> _academicYears = [];
  List<GradeModel> _grades = [];
  List<SubjectModel> _subjects = [];
  List<StaffModel> _staff = [];
  List<SectionModel> _sections = [];
  int _unreadNotifications = 0;
  Map<String, dynamic> _readiness = {};
  Map<String, dynamic>? _session;
  Map<String, dynamic> _draft = {};
  Map<String, dynamic> _validation = {};
  int _stepIndex = 0;
  String _search = '';

  static const _pageBackground = Color(0xFFF8FAFF);
  static const _ink = Color(0xFF111827);
  static const _muted = Color(0xFF64748B);
  static const _line = Color(0xFFE2E8F0);
  static const _primary = Color(0xFF5B35F5);
  static const _primaryDark = Color(0xFF4323D7);
  static const _success = Color(0xFF12B76A);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _commandController.dispose();
    _searchController.dispose();
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
        _api.getGrades(),
        _api.getSubjects(),
        _api.getStaff(page: 1, pageSize: 300, status: 'active'),
        _api.getSections(),
        _api.getNotifications(),
      ]);
      final catalog = _map(results[0]);
      final notifications = _listMap(results[7]);
      if (!mounted) return;
      setState(() {
        _actionCards = _listMap(catalog['action_cards']);
        _workflows = _listMap(catalog['workflows']);
        _readiness = _map(catalog['readiness']);
        _sessions = _listMap(results[1]);
        _academicYears = results[2] as List<AcademicYearModel>;
        _grades = results[3] as List<GradeModel>;
        _subjects = results[4] as List<SubjectModel>;
        _staff = (results[5] as PaginatedList<StaffModel>).data;
        _sections = results[6] as List<SectionModel>;
        _unreadNotifications = notifications
            .where((row) => row['is_read'] != true)
            .length;
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
    final workflow = _session;
    final role = _role;
    final workflowTitle = _text(workflow?['title'], fallback: 'Create Class');
    return Scaffold(
      backgroundColor: _pageBackground,
      bottomNavigationBar: _AssistantBottomNav(
        unreadNotifications: _unreadNotifications,
        onHome: _goHome,
        onHistory: _showHistory,
        onNotifications: () => Navigator.of(
          context,
        ).pushNamed(AppRoutes.notificationCenter, arguments: role),
        onProfile: () => Navigator.of(
          context,
        ).pushNamed(AppRoutes.profileScreen, arguments: role),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _AssistantTopBar(
              title: workflow == null ? _portalTitle : workflowTitle,
              subtitle: workflow == null
                  ? 'Your smart school admin assistant'
                  : null,
              isWorkflow: workflow != null,
              onBack: _workflowBack,
              onHistory: _showHistory,
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? _AssistantStatusPanel(message: _error!, onRetry: _load)
                  : AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: workflow == null
                          ? _buildLanding()
                          : _buildWorkflow(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanding() {
    final cards = _visiblePrimaryActions;
    final suggestions = _landingSuggestions;
    final showWhyPanel = MediaQuery.sizeOf(context).width >= 720;
    final mainContent = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        const _RobotHero(),
        const SizedBox(height: 14),
        _AssistantGreetingCard(
          title: 'Good Morning, $_roleLabel',
          subtitle: 'What would you like to do today?',
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cards.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisExtent: 96,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemBuilder: (context, index) {
            final card = cards[index];
            return _AssistantMenuCard(
              title: _displayActionTitle(card),
              subtitle: _displayActionSubtitle(card),
              icon: _iconFor(_text(card['title'])),
              tone: index,
              onTap: () => _startOrOpen(card),
            );
          },
        ),
        const SizedBox(height: 8),
        _ViewMoreButton(
          visible: _filteredActionCards.length > cards.length,
          onTap: _showAllActions,
        ),
        const SizedBox(height: 14),
        _CommandInputBar(
          controller: _commandController,
          enabled: !_busy,
          onSubmit: _startFromCommand,
        ),
        const SizedBox(height: 20),
      ],
    );
    return _AssistantCanvas(
      maxWidth: showWhyPanel ? 1040 : null,
      child: SingleChildScrollView(
        padding: _screenPadding(context),
        physics: const BouncingScrollPhysics(),
        child: showWhyPanel
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: mainContent),
                  const SizedBox(width: 28),
                  Expanded(child: _WhyAssistantPanel(suggestions: suggestions)),
                ],
              )
            : mainContent,
      ),
    );
  }

  Widget _buildWorkflow() {
    final session = _session;
    final status = _text(session?['status']);
    if (status == 'executed') {
      return _AssistantCanvas(child: _buildSuccess());
    }
    final steps = _currentSteps;
    final safeIndex = steps.isEmpty
        ? 0
        : _stepIndex.clamp(0, steps.length - 1).toInt();
    final current = steps.isEmpty ? <String, dynamic>{} : steps[safeIndex];
    final stepId = _text(current['id']);
    final createClass = _text(session?['workflow_type']) == 'create_class';
    final classDetailsStep = createClass && stepId == 'class_details';
    final className = _field('class_details', 'class_name');
    final showClassNameComposer = classDetailsStep && className.isEmpty;
    final showWorkflowFooter = !classDetailsStep;
    return _AssistantCanvas(
      child: Column(
        children: [
          Padding(
            padding: _screenPadding(context).copyWith(bottom: 0),
            child: _StepProgressBar(
              total: steps.length,
              index: safeIndex,
              color: _primary,
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: _screenPadding(context).copyWith(top: 18, bottom: 18),
              physics: const BouncingScrollPhysics(),
              child: createClass
                  ? _buildCreateClassStep(stepId)
                  : _buildGenericWorkflowStep(stepId, current),
            ),
          ),
          if (showClassNameComposer)
            _AssistantComposerFooter(
              child: _CommandInputBar(
                controller: _controller('class_details.class_name', className),
                enabled: !_busy,
                hint: 'Type here...',
                actionIcon: Icons.send_rounded,
                onSubmit: _submitClassNameFromComposer,
              ),
            )
          else if (showWorkflowFooter)
            _AssistantFooterActions(
              busy: _busy,
              last: safeIndex >= steps.length - 1,
              canBack: safeIndex > 0,
              onBack: _workflowBack,
              onNext: () => _nextStep(stepId),
              onConfirm: _confirmAndCreate,
            ),
        ],
      ),
    );
  }

  Widget _buildCreateClassStep(String stepId) {
    switch (stepId) {
      case 'class_details':
        return _buildClassDetailsStep();
      case 'sections':
        return _buildSectionsStep();
      case 'subjects':
        return _buildSubjectsStep();
      case 'class_teacher':
        return _buildClassTeacherStep();
      case 'subject_teachers':
        return _buildSubjectTeachersStep();
      case 'fee_structure':
        return _buildFeesStep('fee_structure');
      case 'timetable':
        return _buildTimetableStep();
      case 'notifications':
        return _buildSettingsStep();
      case 'review':
        return _buildReviewStep();
      default:
        return _buildGenericWorkflowStep(stepId, const {});
    }
  }

  Widget _buildClassDetailsStep() {
    final years = _academicYears;
    final className = _field('class_details', 'class_name');
    final selectedYear = _field('class_details', 'academic_year_id');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _AssistantBubble(
          text:
              'Let us create a new class. What would you like to name this class?',
        ),
        if (className.isNotEmpty) ...[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: _UserReplyBubble(text: className),
          ),
          const SizedBox(height: 18),
          _AssistantBubble(
            text: 'Great! $className\n\nWhich academic year is this class for?',
          ),
          const SizedBox(height: 12),
          if (years.isEmpty)
            _ReferenceTextField(
              controller: _controller(
                'class_details.academic_year_label',
                _field('class_details', 'academic_year_label'),
              ),
              hint: 'Academic year label',
              onChanged: (value) =>
                  _setField('class_details', 'academic_year_label', value),
              onSubmitted: (_) => _nextStep('class_details'),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final year in years)
                  _ChoicePill(
                    label: year.yearLabel,
                    selected: selectedYear == year.id,
                    onTap: () async => _selectClassAcademicYear(year.id),
                  ),
              ],
            ),
        ],
      ],
    );
  }

  Widget _buildSectionsStep() {
    final rows = _ensureSectionRows();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _AssistantBubble(
          text: 'How many sections would you like to create for this class?',
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: _UserReplyBubble(text: '${rows.length}'),
        ),
        const SizedBox(height: 12),
        const _AssistantBubble(
          text: 'Great. Let us name the sections and set capacity.',
        ),
        const SizedBox(height: 12),
        _ReferencePanel(
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                _SectionInputRow(
                  nameController: _controller(
                    'sections.$i.section_name',
                    _text(rows[i]['section_name']),
                  ),
                  capacityController: _controller(
                    'sections.$i.capacity',
                    _text(rows[i]['capacity']),
                  ),
                  onNameChanged: (value) =>
                      _setRowField('sections', i, 'section_name', value),
                  onCapacityChanged: (value) => _setRowField(
                    'sections',
                    i,
                    'capacity',
                    num.tryParse(value) ?? value,
                  ),
                  onDelete: rows.length <= 1
                      ? null
                      : () => _removeSectionRow(i),
                ),
                if (i < rows.length - 1) const Divider(height: 16),
              ],
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _addSectionRow,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add Another Section'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSubjectsStep() {
    final query = _search.trim().toLowerCase();
    final filtered = _subjects.where((subject) {
      if (query.isEmpty) return true;
      return subject.subjectName.toLowerCase().contains(query) ||
          subject.subjectCode.toLowerCase().contains(query);
    }).toList();
    final selectedIds = _list('subjects')
        .map((row) => _text(row['subject_id']))
        .where((id) => id.isNotEmpty)
        .toSet();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _AssistantBubble(
          text:
              'Let us add subjects for this class. Select subjects from your school catalog.',
        ),
        const SizedBox(height: 14),
        _ReferenceSearchField(
          controller: _searchController,
          hint: 'Search subjects...',
          onChanged: (value) => setState(() => _search = value),
        ),
        const SizedBox(height: 10),
        _ReferencePanel(
          padding: EdgeInsets.zero,
          child: filtered.isEmpty
              ? const _EmptyState(text: 'No subjects found in backend catalog.')
              : Column(
                  children: [
                    for (var i = 0; i < filtered.length; i++) ...[
                      _SubjectCheckRow(
                        subject: filtered[i],
                        selected: selectedIds.contains(filtered[i].id),
                        onChanged: (value) =>
                            _toggleSubject(filtered[i], value),
                      ),
                      if (i < filtered.length - 1) const Divider(height: 1),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildClassTeacherStep() {
    final selected = _field('class_teacher', 'class_teacher_id');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _AssistantBubble(
          text:
              'Now let us assign a class teacher. Choose from available active teachers.',
        ),
        const SizedBox(height: 14),
        _ReferenceSearchField(
          controller: _searchController,
          hint: 'Search teachers...',
          onChanged: (value) => setState(() => _search = value),
        ),
        const SizedBox(height: 10),
        _ReferencePanel(
          padding: EdgeInsets.zero,
          child: _filteredStaff.isEmpty
              ? const _EmptyState(text: 'No active staff found from backend.')
              : Column(
                  children: [
                    for (var i = 0; i < _filteredStaff.length; i++) ...[
                      _TeacherRadioRow(
                        staff: _filteredStaff[i],
                        selected: selected == _filteredStaff[i].id,
                        onTap: () => setState(
                          () => _setField(
                            'class_teacher',
                            'class_teacher_id',
                            _filteredStaff[i].id,
                          ),
                        ),
                      ),
                      if (i < _filteredStaff.length - 1)
                        const Divider(height: 1),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildSubjectTeachersStep() {
    final rows = _ensureSubjectTeacherRows();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _AssistantBubble(
          text: 'Assign teachers for each selected subject.',
        ),
        const SizedBox(height: 14),
        _ReferencePanel(
          padding: EdgeInsets.zero,
          child: rows.isEmpty
              ? const _EmptyState(
                  text: 'Select subjects before assigning teachers.',
                )
              : Column(
                  children: [
                    for (var i = 0; i < rows.length; i++) ...[
                      _SubjectTeacherDropdownRow(
                        subjectName: _text(
                          rows[i]['subject_name'],
                          fallback: 'Subject ${i + 1}',
                        ),
                        staff: _staff,
                        value: _text(rows[i]['teacher_id']),
                        onChanged: (value) => setState(
                          () => _setRowField(
                            'subject_teachers',
                            i,
                            'teacher_id',
                            value ?? '',
                          ),
                        ),
                      ),
                      if (i < rows.length - 1) const Divider(height: 1),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildFeesStep(String key) {
    final rows = _list(key);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _AssistantBubble(
          text: 'Let us set up the fee structure for this class.',
        ),
        const SizedBox(height: 14),
        _ReferencePanel(
          child: Column(
            children: [
              if (rows.isEmpty)
                const _EmptyState(text: 'No fee items added yet.')
              else
                for (var i = 0; i < rows.length; i++) ...[
                  _FeeInputRow(
                    nameController: _controller(
                      '$key.$i.category_name',
                      _text(rows[i]['category_name']),
                    ),
                    amountController: _controller(
                      '$key.$i.amount',
                      _text(rows[i]['amount']),
                    ),
                    onNameChanged: (value) =>
                        _setRowField(key, i, 'category_name', value),
                    onAmountChanged: (value) => _setRowField(
                      key,
                      i,
                      'amount',
                      num.tryParse(value) ?? value,
                    ),
                    onDelete: () => _removeRow(key, i),
                  ),
                  if (i < rows.length - 1) const Divider(height: 16),
                ],
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _addRow(key, {
                    'category_name': '',
                    'frequency': 'term',
                    'amount': 0,
                    'due_day': 10,
                  }),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add Fee Item'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimetableStep() {
    final auto = _bool(_field('timetable', 'auto_generate'));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _AssistantBubble(
          text: 'Would you like me to auto-generate timetable for this class?',
        ),
        const SizedBox(height: 14),
        _OptionCard(
          selected: auto,
          icon: Icons.auto_awesome_rounded,
          title: 'Auto Generate',
          subtitle: 'System will generate based on teacher availability.',
          onTap: () => setState(() {
            _setField('timetable', 'auto_generate', true);
            _setField('timetable', 'periods_per_day', 6);
          }),
        ),
        const SizedBox(height: 10),
        _OptionCard(
          selected: !auto,
          icon: Icons.edit_calendar_outlined,
          title: 'I will do it manually',
          subtitle: 'Create timetable later from the timetable module.',
          onTap: () =>
              setState(() => _setField('timetable', 'auto_generate', false)),
        ),
        if (auto) ...[
          const SizedBox(height: 14),
          _ReferencePanel(
            child: _ReferenceTextField(
              controller: _controller(
                'timetable.periods_per_day',
                _field('timetable', 'periods_per_day'),
              ),
              hint: 'Periods per day',
              keyboardType: TextInputType.number,
              onChanged: (value) => _setField(
                'timetable',
                'periods_per_day',
                num.tryParse(value) ?? value,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSettingsStep() {
    final notify = _bool(_field('notifications', 'notify_staff'));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _AssistantBubble(
          text:
              'Choose final settings before review. These are saved with the workflow draft.',
        ),
        const SizedBox(height: 14),
        _ReferencePanel(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              SwitchListTile(
                value: notify,
                activeColor: _primary,
                title: const Text('Notify staff after class creation'),
                onChanged: (value) => setState(
                  () => _setField('notifications', 'notify_staff', value),
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(14),
                child: _ReferenceTextField(
                  controller: _controller(
                    'notifications.attendance_rule',
                    _field('notifications', 'attendance_rule'),
                  ),
                  hint: 'Attendance rule',
                  onChanged: (value) =>
                      _setField('notifications', 'attendance_rule', value),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReviewStep() {
    final issues = _listMap(_validation['issues']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _AssistantBubble(
          text: 'Please review all details before creating the class.',
        ),
        const SizedBox(height: 14),
        _ReferencePanel(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _ReviewRow(
                label: 'Class Name',
                value: _field('class_details', 'class_name'),
              ),
              _ReviewRow(label: 'Sections', value: _sectionSummary()),
              _ReviewRow(label: 'Subjects', value: _subjectSummary()),
              _ReviewRow(
                label: 'Class Teacher',
                value: _teacherName(
                  _field('class_teacher', 'class_teacher_id'),
                ),
              ),
              _ReviewRow(
                label: 'Subject Teachers',
                value: '${_list('subject_teachers').length} assigned',
              ),
              _ReviewRow(
                label: 'Fee Structure',
                value: '${_list('fee_structure').length} item(s)',
              ),
              _ReviewRow(
                label: 'Timetable',
                value: _bool(_field('timetable', 'auto_generate'))
                    ? 'Auto Generate'
                    : 'Manual',
                last: issues.isEmpty,
              ),
              if (issues.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final issue in issues)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _InlineAlert(
                            text: _text(issue['message']),
                            error: _text(issue['severity']) == 'error',
                          ),
                        ),
                    ],
                  ),
                )
              else if (_validation.isNotEmpty)
                const Padding(
                  padding: EdgeInsets.all(14),
                  child: _InlineAlert(
                    text: 'Validation passed. You can confirm and create.',
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGenericWorkflowStep(
    String stepId,
    Map<String, dynamic> current,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AssistantBubble(
          text: _text(
            current['prompt'],
            fallback: 'Please complete this assistant step.',
          ),
        ),
        const SizedBox(height: 14),
        _ReferencePanel(child: _buildLegacyStepContent(stepId)),
      ],
    );
  }

  Widget _buildLegacyStepContent(String stepId) {
    switch (stepId) {
      case 'student_details':
        return _simpleForm([
          _textField('student_details', 'first_name', 'First name'),
          _textField('student_details', 'last_name', 'Last name'),
          _textField('student_details', 'date_of_birth', 'Date of birth'),
          _choiceField(
            stepId: 'student_details',
            field: 'gender',
            label: 'Gender',
            values: const ['female', 'male', 'other'],
          ),
          _sectionDropdown(
            'student_details',
            'current_section_id',
            'Class section',
          ),
        ]);
      case 'guardian_details':
        return _simpleForm([
          _textField('guardian_details', 'full_name', 'Full name'),
          _textField('guardian_details', 'phone', 'Phone'),
          _textField('guardian_details', 'email', 'Email'),
        ]);
      case 'fee_assignment':
        return SwitchListTile(
          value: _bool(_field('fee_assignment', 'create_invoice')),
          onChanged: (value) => setState(
            () => _setField('fee_assignment', 'create_invoice', value),
          ),
          title: const Text('Create admission invoice'),
        );
      case 'staff_details':
        return _simpleForm([
          _textField('staff_details', 'staff_code', 'Employee ID'),
          _textField('staff_details', 'first_name', 'First name'),
          _textField('staff_details', 'last_name', 'Last name'),
          _textField('staff_details', 'email', 'Email'),
          _textField('staff_details', 'phone', 'Phone'),
          _textField('staff_details', 'username', 'Login username'),
          _textField('staff_details', 'password', 'Temporary password'),
        ]);
      case 'subject_mapping':
        return _buildSubjectMapping();
      case 'fee_details':
        return _simpleForm([
          if (_academicYears.isNotEmpty)
            _dropdownField(
              stepId: 'fee_details',
              field: 'academic_year_id',
              label: 'Existing academic year',
              items: [
                for (final year in _academicYears)
                  DropdownMenuItem(value: year.id, child: Text(year.yearLabel)),
              ],
            ),
          _gradeDropdown('fee_details', 'grade_id', 'Existing class'),
          _textField('fee_details', 'grade_name', 'New class name'),
        ]);
      case 'fee_items':
        return _buildFeesStep('fee_items');
      case 'timetable_details':
        return _simpleForm([
          _sectionDropdown('timetable_details', 'section_id', 'Section'),
          if (_academicYears.isNotEmpty)
            _dropdownField(
              stepId: 'timetable_details',
              field: 'academic_year_id',
              label: 'Academic year',
              items: [
                for (final year in _academicYears)
                  DropdownMenuItem(value: year.id, child: Text(year.yearLabel)),
              ],
            ),
          _textField('timetable_details', 'term_id', 'Term ID'),
        ]);
      case 'timetable':
        return _buildTimetableStep();
      case 'review':
        return _buildReviewStep();
      default:
        return const _EmptyState(
          text: 'This step is controlled by backend workflow fields.',
        );
    }
  }

  Widget _buildSubjectMapping() {
    final rows = _list('subject_mapping');
    return Column(
      children: [
        if (rows.isEmpty)
          const _EmptyState(text: 'No subject mappings added yet.'),
        for (var i = 0; i < rows.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _simpleForm([
              _rowSubjectDropdown(
                'subject_mapping',
                i,
                'subject_id',
                'Subject',
              ),
              _rowGradeDropdown('subject_mapping', i, 'grade_id', 'Class'),
              _rowSectionDropdown(
                'subject_mapping',
                i,
                'section_id',
                'Section',
              ),
            ]),
          ),
        TextButton.icon(
          onPressed: () => _addRow('subject_mapping', {
            'subject_id': '',
            'grade_id': '',
            'section_id': '',
          }),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add mapping'),
        ),
      ],
    );
  }

  Widget _buildSuccess() {
    final summary = _map(_session?['review_summary']);
    return SingleChildScrollView(
      padding: _screenPadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 56),
          const _SuccessMark(),
          const SizedBox(height: 18),
          const Text(
            'Class Created Successfully',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _ink,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              height: 1.08,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _successSummary(summary),
            textAlign: TextAlign.center,
            style: const TextStyle(color: _muted, fontSize: 14, height: 1.35),
          ),
          const SizedBox(height: 34),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pushNamed(AppRoutes.principalClasses),
            style: FilledButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('View Class'),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: _goHome,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Go to Dashboard'),
          ),
        ],
      ),
    );
  }

  Widget _simpleForm(List<Widget> children) {
    return Column(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          children[i],
          if (i < children.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }

  Future<void> _startOrOpen(Map<String, dynamic> card) async {
    final type = _text(card['workflow_type']);
    if (_workflows.any((workflow) => _text(workflow['type']) == type)) {
      await _startWorkflow(type);
      return;
    }
    final route = _text(
      card['target_route'],
      fallback: _quickRoute(type) ?? '',
    );
    if (route.isNotEmpty && mounted) {
      Navigator.of(
        context,
      ).pushNamed(route, arguments: type == 'notifications' ? _role : null);
      return;
    }
    _showError('No live route is configured for this assistant action.');
  }

  Future<void> _startFromCommand() async {
    final command = _commandController.text.trim();
    if (command.isEmpty) return;
    await _startWorkflow('', command: command);
  }

  void _submitClassNameFromComposer() {
    final controller = _controllers['class_details.class_name'];
    final className = controller?.text.trim() ?? '';
    if (className.isEmpty) {
      _showError('Class name is required before choosing academic year.');
      return;
    }
    setState(() => _setField('class_details', 'class_name', className));
  }

  Future<void> _selectClassAcademicYear(String yearId) async {
    if (_busy) return;
    setState(() {
      _setField('class_details', 'academic_year_id', yearId);
      _setField('class_details', 'academic_year_label', '');
    });
    await _nextStep('class_details');
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
    Navigator.of(context).maybePop();
    _useSession(session);
  }

  void _useSession(Map<String, dynamic> session) {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
    _searchController.clear();
    final draft = _map(session['draft_data']);
    setState(() {
      _session = session;
      _draft = draft;
      _validation = _map(session['validation_summary']);
      _stepIndex = _stepIndexFor(_text(session['current_step_id']));
      _search = '';
    });
  }

  Future<void> _nextStep(String stepId) async {
    final issue = _localStepIssue(stepId);
    if (issue != null) {
      _showError(issue);
      return;
    }
    final maxIndex = _currentSteps.isEmpty ? 0 : _currentSteps.length - 1;
    final nextIndex = (_stepIndex + 1).clamp(0, maxIndex).toInt();
    final nextStepId = _text(
      _currentSteps.isEmpty ? null : _currentSteps[nextIndex]['id'],
    );
    await _saveStep(
      stepId,
      completed: true,
      currentStepId: nextStepId.isEmpty ? stepId : nextStepId,
    );
    if (!mounted) return;
    setState(() {
      _stepIndex = nextIndex;
      _search = '';
      _searchController.clear();
    });
  }

  String? _localStepIssue(String stepId) {
    switch (stepId) {
      case 'class_details':
        if (_field('class_details', 'class_name').isEmpty) {
          return 'Class name is required before the next question.';
        }
        if (_field('class_details', 'academic_year_id').isEmpty &&
            _field('class_details', 'academic_year_label').isEmpty) {
          return 'Select an academic year or enter a new academic year label.';
        }
        break;
      case 'sections':
        final rows = _list('sections');
        if (rows.isEmpty) return 'Add at least one section.';
        for (final row in rows) {
          if (_text(row['section_name']).isEmpty) {
            return 'Every section needs a name.';
          }
          if ((num.tryParse(_text(row['capacity'])) ?? 0) <= 0) {
            return 'Every section capacity must be greater than zero.';
          }
        }
        final classDetails = Map<String, dynamic>.from(
          _map(_draft['class_details']),
        );
        classDetails['section_count'] = rows.length;
        final firstCapacity = rows
            .map((row) => num.tryParse(_text(row['capacity'])) ?? 0)
            .firstWhere((value) => value > 0, orElse: () => 0);
        if (firstCapacity > 0) classDetails['capacity'] = firstCapacity;
        _draft['class_details'] = classDetails;
        break;
      case 'student_details':
        if (_field('student_details', 'first_name').isEmpty ||
            _field('student_details', 'date_of_birth').isEmpty ||
            _field('student_details', 'gender').isEmpty) {
          return 'Student name, date of birth, and gender are required.';
        }
        break;
      case 'staff_details':
        if (_field('staff_details', 'first_name').isEmpty ||
            _field('staff_details', 'last_name').isEmpty) {
          return 'Teacher first name and last name are required.';
        }
        break;
      case 'fee_details':
        if (_field('fee_details', 'academic_year_id').isEmpty &&
            _field('fee_details', 'academic_year_label').isEmpty) {
          return 'Academic year is required for fee setup.';
        }
        if (_field('fee_details', 'grade_id').isEmpty &&
            _field('fee_details', 'grade_name').isEmpty) {
          return 'Class or grade is required for fee setup.';
        }
        break;
      case 'fee_items':
        if (_list('fee_items').isEmpty) {
          return 'Add at least one fee item before review.';
        }
        break;
    }
    return null;
  }

  Future<void> _saveStep(
    String stepId, {
    required bool completed,
    String? currentStepId,
  }) async {
    final session = _session;
    if (session == null) return;
    setState(() => _busy = true);
    try {
      final updated = await _api.saveAssistantStep(
        sessionId: _text(session['id']),
        stepId: stepId,
        draftData: _draft,
        completed: completed,
        currentStepId: currentStepId ?? stepId,
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

  Future<bool> _validateSession() async {
    final session = _session;
    if (session == null) return false;
    await _saveStep('review', completed: true);
    setState(() => _busy = true);
    try {
      final result = await _api.validateAssistantSession(_text(session['id']));
      if (!mounted) return false;
      final validation = _map(result['validation']);
      setState(() {
        _session = _map(result['session']);
        _validation = validation;
      });
      return validation['valid'] == true;
    } catch (error) {
      _showError('$error');
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmAndCreate() async {
    final valid = await _validateSession();
    if (!valid || !mounted) return;
    await _executeSession();
  }

  Future<void> _executeSession() async {
    final session = _session;
    if (session == null) return;
    setState(() => _busy = true);
    try {
      final result = await _api.executeAssistantSession(_text(session['id']));
      if (!mounted) return;
      setState(() {
        _session = _map(result['session']);
      });
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
      _stepIndex = 0;
    });
    await _load();
  }

  void _workflowBack() {
    if (_session == null) return;
    if (_stepIndex > 0) {
      setState(() => _stepIndex--);
      return;
    }
    _cancelWorkflow();
  }

  void _goHome() {
    final role = _role;
    final route = role == 'admin'
        ? AppRoutes.adminDashboard
        : AppRoutes.principalDashboard;
    Navigator.of(context).pushNamedAndRemoveUntil(route, (_) => false);
  }

  void _showHistory() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Workflow History',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              if (_sessions.isEmpty)
                const _EmptyState(text: 'No unfinished workflows.')
              else
                for (final session in _sessions.take(5))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(_text(session['title'], fallback: 'Workflow')),
                    subtitle: Text(_text(session['status'], fallback: 'draft')),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _resumeSession(session),
                  ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAllActions() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'All Assistant Actions',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              for (final card in _filteredActionCards)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    _iconFor(_text(card['title'])),
                    color: _primary,
                  ),
                  title: Text(_displayActionTitle(card)),
                  subtitle: Text(_text(card['category'])),
                  onTap: () {
                    Navigator.pop(context);
                    _startOrOpen(card);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _ensureSectionRows() {
    final rows = _list('sections');
    if (rows.isNotEmpty) return rows;
    final count = (num.tryParse(_field('class_details', 'section_count')) ?? 2)
        .clamp(1, 8)
        .toInt();
    final generated = [
      for (var i = 0; i < count; i++)
        {'section_name': String.fromCharCode(65 + i), 'capacity': ''},
    ];
    _draft['sections'] = generated;
    return generated;
  }

  void _addSectionRow() {
    final rows = _list('sections');
    rows.add({
      'section_name': String.fromCharCode(65 + rows.length),
      'capacity': '',
    });
    setState(() {
      _draft['sections'] = rows;
      _setField('class_details', 'section_count', rows.length);
    });
  }

  void _removeSectionRow(int index) {
    final rows = _list('sections');
    if (index < 0 || index >= rows.length || rows.length <= 1) return;
    rows.removeAt(index);
    setState(() {
      _draft['sections'] = rows;
      _setField('class_details', 'section_count', rows.length);
    });
  }

  List<Map<String, dynamic>> _ensureSubjectTeacherRows() {
    final selectedSubjects = _list('subjects');
    final currentRows = _list('subject_teachers');
    if (selectedSubjects.isEmpty) return currentRows;
    final rows = <Map<String, dynamic>>[];
    for (final subject in selectedSubjects) {
      final subjectId = _text(subject['subject_id']);
      final existing = currentRows.firstWhere(
        (row) =>
            _text(row['subject_id']) == subjectId ||
            _text(row['subject_name']) == _text(subject['subject_name']),
        orElse: () => const <String, dynamic>{},
      );
      rows.add({
        'subject_id': subjectId,
        'subject_name': _text(subject['subject_name']),
        'teacher_id': _text(existing['teacher_id']),
      });
    }
    _draft['subject_teachers'] = rows;
    return rows;
  }

  void _toggleSubject(SubjectModel subject, bool selected) {
    final rows = _list('subjects');
    rows.removeWhere((row) => _text(row['subject_id']) == subject.id);
    if (selected) {
      rows.add({
        'subject_id': subject.id,
        'subject_name': subject.subjectName,
        'subject_code': subject.subjectCode,
        'subject_type': subject.subjectType,
        'periods_per_week': 5,
      });
    }
    setState(() {
      _draft['subjects'] = rows;
    });
  }

  Widget _textField(
    String stepId,
    String field,
    String label, {
    bool number = false,
  }) {
    final key = '$stepId.$field';
    final controller = _controller(key, _field(stepId, field));
    return _ReferenceTextField(
      controller: controller,
      hint: label,
      keyboardType: number ? TextInputType.number : TextInputType.text,
      onChanged: (value) => _setField(
        stepId,
        field,
        number ? (num.tryParse(value) ?? value) : value,
      ),
    );
  }

  Widget _choiceField({
    required String stepId,
    required String field,
    required String label,
    required List<String> values,
    bool allowCustomValue = false,
  }) {
    final current = _field(stepId, field);
    final options = [...values];
    if (allowCustomValue && current.isNotEmpty && !options.contains(current)) {
      options.add(current);
    }
    return _dropdownField(
      stepId: stepId,
      field: field,
      label: label,
      items: [
        for (final value in options)
          DropdownMenuItem(value: value, child: Text(_label(value))),
      ],
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
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onChanged: (value) =>
          setState(() => _setField(stepId, field, value ?? '')),
    );
  }

  Widget _gradeDropdown(String stepId, String field, String label) {
    return _dropdownField(
      stepId: stepId,
      field: field,
      label: label,
      items: [
        for (final grade in _grades)
          DropdownMenuItem(value: grade.id, child: Text(grade.gradeName)),
      ],
    );
  }

  Widget _sectionDropdown(String stepId, String field, String label) {
    return _dropdownField(
      stepId: stepId,
      field: field,
      label: label,
      items: [
        for (final section in _sections)
          DropdownMenuItem(
            value: section.id,
            child: Text(_sectionLabel(section)),
          ),
      ],
    );
  }

  Widget _rowSubjectDropdown(
    String listKey,
    int index,
    String field,
    String label,
  ) {
    final rows = _list(listKey);
    final value = rows.length > index ? _text(rows[index][field]) : '';
    final allowed = _subjects.any((item) => item.id == value);
    return DropdownButtonFormField<String>(
      value: allowed ? value : null,
      items: [
        for (final subject in _subjects)
          DropdownMenuItem(value: subject.id, child: Text(subject.subjectName)),
      ],
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onChanged: (value) =>
          setState(() => _setRowField(listKey, index, field, value ?? '')),
    );
  }

  Widget _rowGradeDropdown(
    String listKey,
    int index,
    String field,
    String label,
  ) {
    final rows = _list(listKey);
    final value = rows.length > index ? _text(rows[index][field]) : '';
    final allowed = _grades.any((item) => item.id == value);
    return DropdownButtonFormField<String>(
      value: allowed ? value : null,
      items: [
        for (final grade in _grades)
          DropdownMenuItem(value: grade.id, child: Text(grade.gradeName)),
      ],
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onChanged: (value) =>
          setState(() => _setRowField(listKey, index, field, value ?? '')),
    );
  }

  Widget _rowSectionDropdown(
    String listKey,
    int index,
    String field,
    String label,
  ) {
    final rows = _list(listKey);
    final value = rows.length > index ? _text(rows[index][field]) : '';
    final allowed = _sections.any((item) => item.id == value);
    return DropdownButtonFormField<String>(
      value: allowed ? value : null,
      items: [
        for (final section in _sections)
          DropdownMenuItem(
            value: section.id,
            child: Text(_sectionLabel(section)),
          ),
      ],
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onChanged: (value) =>
          setState(() => _setRowField(listKey, index, field, value ?? '')),
    );
  }

  TextEditingController _controller(String key, String value) {
    final controller = _controllers.putIfAbsent(
      key,
      () => TextEditingController(text: value),
    );
    if (controller.text.isEmpty && value.isNotEmpty) {
      controller.text = value;
    }
    return controller;
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

  List<Map<String, dynamic>> get _visiblePrimaryActions {
    const preferred = [
      'create class',
      'add students',
      'staff management',
      'fees',
      'timetable',
      'exams',
    ];
    final source = _filteredActionCards;
    final ordered = <Map<String, dynamic>>[];
    for (final title in preferred) {
      final match = source.where(
        (card) => _text(card['title']).toLowerCase() == title,
      );
      if (match.isNotEmpty) ordered.add(match.first);
    }
    if (ordered.length < 6) {
      for (final card in source) {
        if (!ordered.contains(card)) ordered.add(card);
        if (ordered.length == 6) break;
      }
    }
    return ordered.take(6).toList();
  }

  List<StaffModel> get _filteredStaff {
    final query = _search.trim().toLowerCase();
    if (query.isEmpty) return _staff;
    return _staff.where((staff) {
      final name = '${staff.firstName} ${staff.lastName}'.toLowerCase();
      return name.contains(query) ||
          (staff.designation ?? '').toLowerCase().contains(query);
    }).toList();
  }

  List<String> get _landingSuggestions {
    final readinessSuggestions = _textList(_map(_readiness)['suggestions']);
    if (readinessSuggestions.isNotEmpty) {
      return readinessSuggestions;
    }
    return const [
      'Chat-like interaction for school operations.',
      'Step by step guidance with backend validation.',
      'Review before save so you stay in control.',
    ];
  }

  String get _role => (_api.currentRoleName ?? 'principal').toLowerCase();

  String get _roleLabel {
    final role = _role;
    return role.isEmpty
        ? 'Principal'
        : '${role[0].toUpperCase()}${role.substring(1)}';
  }

  String get _portalTitle =>
      _role == 'admin' ? 'Admin Assistant' : 'Principal Assistant';

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

  String _displayActionTitle(Map<String, dynamic> card) {
    final title = _text(card['title']);
    return title == 'Fees' ? 'Fees & Payments' : title;
  }

  String _displayActionSubtitle(Map<String, dynamic> card) {
    switch (_text(card['title']).toLowerCase()) {
      case 'create class':
        return 'Add new class, sections, subjects...';
      case 'add students':
        return 'Create new student admissions';
      case 'staff management':
        return 'Manage teachers or staff';
      case 'fees':
        return 'Manage fees, collections';
      case 'timetable':
        return 'Create and manage timetable';
      case 'exams':
        return 'Schedule exams and view results';
      default:
        return _text(card['category']);
    }
  }

  String _sectionLabel(SectionModel section) {
    return [
      section.gradeName,
      section.sectionName,
    ].where((part) => part.trim().isNotEmpty).join(' ');
  }

  String _sectionSummary() {
    final rows = _list('sections');
    if (rows.isEmpty) return 'Not added';
    return rows.map((row) => _text(row['section_name'])).join(', ');
  }

  String _subjectSummary() {
    final rows = _list('subjects');
    if (rows.isEmpty) return 'Not added';
    return rows.map((row) => _text(row['subject_name'])).join(', ');
  }

  String _teacherName(String id) {
    for (final staff in _staff) {
      if (staff.id == id) {
        return '${staff.firstName} ${staff.lastName}'.trim();
      }
    }
    return id.isEmpty ? 'Not assigned' : 'Selected';
  }

  String _successSummary(Map<String, dynamic> summary) {
    final preview = _map(summary['preview']);
    final className = _text(
      preview['class'],
      fallback: _field('class_details', 'class_name'),
    );
    final sections = _list('sections').length;
    final subjects = _list('subjects').length;
    final fees = _list('fee_structure').length;
    return [
      if (className.isNotEmpty) '$className has been created',
      if (sections > 0) 'with $sections section${sections == 1 ? '' : 's'}',
      if (subjects > 0) '$subjects subject${subjects == 1 ? '' : 's'}',
      if (fees > 0) '$fees fee item${fees == 1 ? '' : 's'}',
      'and live backend records.',
    ].join(' ');
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
        return Icons.manage_accounts_outlined;
      case 'fees':
        return Icons.receipt_long_outlined;
      case 'timetable':
        return Icons.calendar_month_outlined;
      case 'attendance':
        return Icons.fact_check_outlined;
      case 'exams':
        return Icons.assignment_outlined;
      case 'notifications':
        return Icons.notifications_none_rounded;
      case 'reports':
        return Icons.bar_chart_outlined;
      default:
        return Icons.auto_awesome_outlined;
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

  EdgeInsets _screenPadding(BuildContext context) {
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    return EdgeInsets.fromLTRB(20, 12, 20, 22 + bottom);
  }
}

class _AssistantCanvas extends StatelessWidget {
  final Widget child;
  final double? maxWidth;

  const _AssistantCanvas({required this.child, this.maxWidth});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth > 560;
        return ColoredBox(
          color: _GuidedAssistantScreenState._pageBackground,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: maxWidth ?? (wide ? 520 : constraints.maxWidth),
              ),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

class _AssistantTopBar extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool isWorkflow;
  final VoidCallback onBack;
  final VoidCallback onHistory;

  const _AssistantTopBar({
    required this.title,
    required this.subtitle,
    required this.isWorkflow,
    required this.onBack,
    required this.onHistory,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _GuidedAssistantScreenState._pageBackground,
      child: Container(
        height: isWorkflow ? 58 : 76,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            if (isWorkflow)
              IconButton(
                tooltip: 'Back',
                onPressed: onBack,
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: _GuidedAssistantScreenState._ink,
                ),
              )
            else ...[
              const Icon(
                Icons.auto_awesome_rounded,
                color: _GuidedAssistantScreenState._primary,
                size: 16,
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: isWorkflow
                    ? CrossAxisAlignment.start
                    : CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _GuidedAssistantScreenState._ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _GuidedAssistantScreenState._muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'History',
              onPressed: onHistory,
              icon: const Icon(
                Icons.history_rounded,
                color: _GuidedAssistantScreenState._ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RobotHero extends StatelessWidget {
  const _RobotHero();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        height: 92,
        width: 96,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 78,
              height: 78,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _GuidedAssistantScreenState._primary.withValues(
                  alpha: 0.08,
                ),
              ),
            ),
            Container(
              width: 54,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFBFD3FF)),
                boxShadow: [
                  BoxShadow(
                    color: _GuidedAssistantScreenState._primary.withValues(
                      alpha: 0.15,
                    ),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(
                Icons.smart_toy_rounded,
                color: _GuidedAssistantScreenState._primary,
                size: 28,
              ),
            ),
            Positioned(
              bottom: 10,
              child: Container(
                width: 36,
                height: 12,
                decoration: BoxDecoration(
                  color: const Color(0xFFE9EEFF),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AssistantGreetingCard extends StatelessWidget {
  final String title;
  final String subtitle;

  const _AssistantGreetingCard({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return _ReferencePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: _GuidedAssistantScreenState._ink,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              color: _GuidedAssistantScreenState._ink,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _AssistantMenuCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final int tone;
  final VoidCallback onTap;

  const _AssistantMenuCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.tone,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = const [
      Color(0xFF5B35F5),
      Color(0xFF12B76A),
      Color(0xFF2E90FA),
      Color(0xFFF97316),
      Color(0xFF7C3AED),
      Color(0xFFF43F5E),
    ];
    final color = colors[tone % colors.length];
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _GuidedAssistantScreenState._line),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _GuidedAssistantScreenState._ink,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        height: 1.12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _GuidedAssistantScreenState._muted,
                        fontSize: 10.5,
                        height: 1.16,
                      ),
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

class _ViewMoreButton extends StatelessWidget {
  final bool visible;
  final VoidCallback onTap;

  const _ViewMoreButton({required this.visible, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _GuidedAssistantScreenState._line),
          ),
          child: const Text(
            'View More',
            style: TextStyle(
              color: _GuidedAssistantScreenState._primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _CommandInputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onSubmit;
  final String hint;
  final IconData actionIcon;

  const _CommandInputBar({
    required this.controller,
    required this.enabled,
    required this.onSubmit,
    this.hint = 'Or type your request...',
    this.actionIcon = Icons.mic_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            enabled: enabled,
            decoration: InputDecoration(
              hintText: hint,
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(99),
                borderSide: const BorderSide(
                  color: _GuidedAssistantScreenState._line,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(99),
                borderSide: const BorderSide(
                  color: _GuidedAssistantScreenState._line,
                ),
              ),
            ),
            onSubmitted: (_) => onSubmit(),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 48,
          height: 48,
          child: FilledButton(
            onPressed: enabled ? onSubmit : null,
            style: FilledButton.styleFrom(
              shape: const CircleBorder(),
              padding: EdgeInsets.zero,
              backgroundColor: _GuidedAssistantScreenState._primary,
              foregroundColor: Colors.white,
            ),
            child: Icon(actionIcon),
          ),
        ),
      ],
    );
  }
}

class _AssistantComposerFooter extends StatelessWidget {
  final Widget child;

  const _AssistantComposerFooter({required this.child});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: child,
        ),
      ),
    );
  }
}

class _WhyAssistantPanel extends StatelessWidget {
  final List<String> suggestions;

  const _WhyAssistantPanel({required this.suggestions});

  @override
  Widget build(BuildContext context) {
    return _ReferencePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Why it is easy to use?',
            style: TextStyle(
              color: _GuidedAssistantScreenState._ink,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 14),
          const _FeatureLine(
            icon: Icons.chat_bubble_outline_rounded,
            color: _GuidedAssistantScreenState._primary,
            title: 'Chat-like Interaction',
            subtitle: 'Feels like chatting with an assistant.',
          ),
          const _FeatureLine(
            icon: Icons.alt_route_rounded,
            color: Color(0xFF7C3AED),
            title: 'Step by Step Guidance',
            subtitle: 'Each step saves into a live workflow draft.',
          ),
          const _FeatureLine(
            icon: Icons.verified_outlined,
            color: Color(0xFF12B76A),
            title: 'No Data Missing',
            subtitle: 'Validation runs before anything is created.',
          ),
          const _FeatureLine(
            icon: Icons.fact_check_outlined,
            color: Color(0xFFF43F5E),
            title: 'Review Before Save',
            subtitle: 'You are always in control.',
          ),
          if (suggestions.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final item in suggestions.take(2))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _InlineAlert(text: item),
              ),
          ],
        ],
      ),
    );
  }
}

class _FeatureLine extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  const _FeatureLine({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _GuidedAssistantScreenState._ink,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: _GuidedAssistantScreenState._muted,
                    fontSize: 12,
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

class _StepProgressBar extends StatelessWidget {
  final int total;
  final int index;
  final Color color;

  const _StepProgressBar({
    required this.total,
    required this.index,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (total <= 0) return const SizedBox.shrink();
    return Row(
      children: [
        for (var i = 0; i < total; i++) ...[
          Expanded(
            child: Container(
              height: 3,
              decoration: BoxDecoration(
                color: i <= index ? color : const Color(0xFFD8DEE9),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: i <= index ? color : const Color(0xFFD8DEE9),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
          if (i < total - 1)
            Expanded(
              child: Container(
                height: 3,
                decoration: BoxDecoration(
                  color: i < index ? color : const Color(0xFFD8DEE9),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _AssistantBubble extends StatelessWidget {
  final String text;

  const _AssistantBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SmallBotAvatar(),
        const SizedBox(width: 9),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _GuidedAssistantScreenState._line),
            ),
            child: Text(
              text,
              style: const TextStyle(
                color: _GuidedAssistantScreenState._ink,
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _UserReplyBubble extends StatelessWidget {
  final String text;

  const _UserReplyBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 58),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            _GuidedAssistantScreenState._primary,
            _GuidedAssistantScreenState._primaryDark,
          ],
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SmallBotAvatar extends StatelessWidget {
  const _SmallBotAvatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: const Color(0xFFEFF4FF),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(
        Icons.smart_toy_rounded,
        color: _GuidedAssistantScreenState._primary,
        size: 19,
      ),
    );
  }
}

class _ReferencePanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _ReferencePanel({
    required this.child,
    this.padding = const EdgeInsets.all(14),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _GuidedAssistantScreenState._line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: padding,
      child: child,
    );
  }
}

class _ReferenceTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputType keyboardType;

  const _ReferenceTextField({
    required this.controller,
    required this.hint,
    required this.onChanged,
    this.onSubmitted,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(
            color: _GuidedAssistantScreenState._line,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(
            color: _GuidedAssistantScreenState._line,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(
            color: _GuidedAssistantScreenState._primary,
            width: 1.4,
          ),
        ),
      ),
      onChanged: onChanged,
      onSubmitted: onSubmitted,
    );
  }
}

class _ReferenceSearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  const _ReferenceSearchField({
    required this.controller,
    required this.hint,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search_rounded, size: 20),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(
            color: _GuidedAssistantScreenState._line,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(
            color: _GuidedAssistantScreenState._line,
          ),
        ),
      ),
      onChanged: onChanged,
    );
  }
}

class _ChoicePill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ChoicePill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      selected: selected,
      label: Text(label),
      onSelected: (_) => onTap(),
      selectedColor: _GuidedAssistantScreenState._primary,
      labelStyle: TextStyle(
        color: selected ? Colors.white : _GuidedAssistantScreenState._ink,
        fontWeight: FontWeight.w800,
      ),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      side: BorderSide(
        color: selected
            ? _GuidedAssistantScreenState._primary
            : _GuidedAssistantScreenState._line,
      ),
    );
  }
}

class _SectionInputRow extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController capacityController;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<String> onCapacityChanged;
  final VoidCallback? onDelete;

  const _SectionInputRow({
    required this.nameController,
    required this.capacityController,
    required this.onNameChanged,
    required this.onCapacityChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: _ReferenceTextField(
            controller: nameController,
            hint: 'Section',
            onChanged: onNameChanged,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: _ReferenceTextField(
            controller: capacityController,
            hint: 'Capacity',
            keyboardType: TextInputType.number,
            onChanged: onCapacityChanged,
          ),
        ),
        const SizedBox(width: 4),
        IconButton(
          tooltip: 'Remove section',
          onPressed: onDelete,
          icon: const Icon(
            Icons.delete_outline_rounded,
            color: Color(0xFFF04438),
          ),
        ),
      ],
    );
  }
}

class _SubjectCheckRow extends StatelessWidget {
  final SubjectModel subject;
  final bool selected;
  final ValueChanged<bool> onChanged;

  const _SubjectCheckRow({
    required this.subject,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      value: selected,
      onChanged: (value) => onChanged(value ?? false),
      activeColor: _GuidedAssistantScreenState._primary,
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      title: Text(
        subject.subjectName,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: subject.subjectCode.isEmpty ? null : Text(subject.subjectCode),
    );
  }
}

class _TeacherRadioRow extends StatelessWidget {
  final StaffModel staff;
  final bool selected;
  final VoidCallback onTap;

  const _TeacherRadioRow({
    required this.staff,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = '${staff.firstName} ${staff.lastName}'.trim();
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: const Color(0xFFEFF4FF),
        child: Text(
          _initials(name),
          style: const TextStyle(
            color: _GuidedAssistantScreenState._primary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      title: Text(
        name.isEmpty ? staff.staffCode : name,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: Text((staff.designation ?? '').trim()),
      trailing: Radio<bool>(
        value: true,
        groupValue: selected,
        activeColor: _GuidedAssistantScreenState._primary,
        onChanged: (_) => onTap(),
      ),
    );
  }
}

class _SubjectTeacherDropdownRow extends StatelessWidget {
  final String subjectName;
  final List<StaffModel> staff;
  final String value;
  final ValueChanged<String?> onChanged;

  const _SubjectTeacherDropdownRow({
    required this.subjectName,
    required this.staff,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final allowed = staff.any((item) => item.id == value);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              subjectName,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: allowed ? value : null,
              items: [
                for (final teacher in staff)
                  DropdownMenuItem(
                    value: teacher.id,
                    child: Text(
                      '${teacher.firstName} ${teacher.lastName}'.trim(),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              decoration: InputDecoration(
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeeInputRow extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController amountController;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<String> onAmountChanged;
  final VoidCallback onDelete;

  const _FeeInputRow({
    required this.nameController,
    required this.amountController,
    required this.onNameChanged,
    required this.onAmountChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            children: [
              _ReferenceTextField(
                controller: nameController,
                hint: 'Fee item',
                onChanged: onNameChanged,
              ),
              const SizedBox(height: 8),
              _ReferenceTextField(
                controller: amountController,
                hint: 'Amount',
                keyboardType: TextInputType.number,
                onChanged: onAmountChanged,
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Remove fee',
          onPressed: onDelete,
          icon: const Icon(
            Icons.delete_outline_rounded,
            color: Color(0xFFF04438),
          ),
        ),
      ],
    );
  }
}

class _OptionCard extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _OptionCard({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFF2EEFF) : Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected
                  ? _GuidedAssistantScreenState._primary.withValues(alpha: 0.30)
                  : _GuidedAssistantScreenState._line,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: _GuidedAssistantScreenState._primary,
              ),
              const SizedBox(width: 12),
              Icon(icon, color: _GuidedAssistantScreenState._primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: _GuidedAssistantScreenState._ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: _GuidedAssistantScreenState._muted,
                        fontSize: 12,
                      ),
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

class _ReviewRow extends StatelessWidget {
  final String label;
  final String value;
  final bool last;

  const _ReviewRow({
    required this.label,
    required this.value,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(
                bottom: BorderSide(color: _GuidedAssistantScreenState._line),
              ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: _GuidedAssistantScreenState._muted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? 'Not added' : value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: _GuidedAssistantScreenState._ink,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineAlert extends StatelessWidget {
  final String text;
  final bool error;

  const _InlineAlert({required this.text, this.error = false});

  @override
  Widget build(BuildContext context) {
    final color = error ? const Color(0xFFF04438) : const Color(0xFF12B76A);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          error
              ? Icons.error_outline_rounded
              : Icons.check_circle_outline_rounded,
          color: color,
          size: 18,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: _GuidedAssistantScreenState._muted,
              fontSize: 12,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String text;

  const _EmptyState({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: _GuidedAssistantScreenState._muted),
        ),
      ),
    );
  }
}

class _AssistantFooterActions extends StatelessWidget {
  final bool busy;
  final bool last;
  final bool canBack;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final VoidCallback onConfirm;

  const _AssistantFooterActions({
    required this.busy,
    required this.last,
    required this.canBack,
    required this.onBack,
    required this.onNext,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: busy || !canBack ? null : onBack,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Back'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: busy ? null : (last ? onConfirm : onNext),
                  style: FilledButton.styleFrom(
                    backgroundColor: last
                        ? _GuidedAssistantScreenState._success
                        : _GuidedAssistantScreenState._primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(last ? 'Confirm & Create' : 'Next'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AssistantBottomNav extends StatelessWidget {
  final int unreadNotifications;
  final VoidCallback onHome;
  final VoidCallback onHistory;
  final VoidCallback onNotifications;
  final VoidCallback onProfile;

  const _AssistantBottomNav({
    required this.unreadNotifications,
    required this.onHome,
    required this.onHistory,
    required this.onNotifications,
    required this.onProfile,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Material(
        color: Colors.white,
        elevation: 10,
        shadowColor: Colors.black.withValues(alpha: 0.12),
        child: Container(
          height: 70,
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: _GuidedAssistantScreenState._line),
            ),
          ),
          child: Row(
            children: [
              _BottomItem(
                icon: Icons.home_outlined,
                activeIcon: Icons.home_rounded,
                label: 'Home',
                selected: true,
                onTap: onHome,
              ),
              _BottomItem(
                icon: Icons.history_rounded,
                activeIcon: Icons.history_rounded,
                label: 'History',
                onTap: onHistory,
              ),
              _BottomItem(
                icon: Icons.notifications_none_rounded,
                activeIcon: Icons.notifications_rounded,
                label: 'Notifications',
                badge: unreadNotifications,
                onTap: onNotifications,
              ),
              _BottomItem(
                icon: Icons.person_outline_rounded,
                activeIcon: Icons.person_rounded,
                label: 'Profile',
                onTap: onProfile,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final int badge;
  final VoidCallback onTap;

  const _BottomItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.badge = 0,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? _GuidedAssistantScreenState._primary
        : _GuidedAssistantScreenState._muted;
    final navIcon = Icon(selected ? activeIcon : icon, color: color, size: 21);
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            badge > 0
                ? Badge.count(
                    count: badge,
                    backgroundColor: const Color(0xFFF04438),
                    child: navIcon,
                  )
                : navIcon,
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AssistantStatusPanel extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _AssistantStatusPanel({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: _ReferencePanel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 34),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      ),
    );
  }
}

class _SuccessMark extends StatelessWidget {
  const _SuccessMark();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 94,
        height: 94,
        decoration: const BoxDecoration(
          color: _GuidedAssistantScreenState._success,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check_rounded, color: Colors.white, size: 58),
      ),
    );
  }
}

String _initials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return 'T';
  if (parts.length == 1) return parts.first.characters.first.toUpperCase();
  return '${parts.first.characters.first}${parts.last.characters.first}'
      .toUpperCase();
}
