import 'package:flutter/material.dart';

import '../../routes/app_routes.dart';
import '../../services/backend_api_client.dart';
import '../../theme/app_theme.dart';
import '../../widgets/admin_navigation.dart';
import '../../widgets/dashboard_fab_widget.dart';
import '../../widgets/erp_module_scaffold.dart';
import '../../widgets/operations_workspace.dart';
import 'admin_exam_form_screens.dart';

enum _ExamWorkspaceView { campaigns, schedules, marks, reports }

class AdminExamsScreen extends StatefulWidget {
  const AdminExamsScreen({super.key});

  @override
  State<AdminExamsScreen> createState() => _AdminExamsScreenState();
}

class _AdminExamsScreenState extends State<AdminExamsScreen> {
  bool _loading = true;
  String? _error;
  _ExamWorkspaceView _view = _ExamWorkspaceView.campaigns;

  List<Map<String, dynamic>> _exams = [];
  List<Map<String, dynamic>> _examSchedules = [];
  List<Map<String, dynamic>> _reportCards = [];
  List<AcademicYearModel> _academicYears = [];
  List<Map<String, dynamic>> _examTypes = [];
  List<GradeModel> _grades = [];
  List<SectionModel> _sections = [];
  List<Map<String, dynamic>> _subjects = [];

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
      final exams = await api.getExams();
      final schedules = await api.getRawList('/exams/schedules');
      final reportCards = await api.getRawList('/exams/report-cards');
      final academicYears = await api.getAcademicYears();
      final examTypes = await api.getExamTypes();
      final grades = await api.getGrades();
      final sections = await api.getSections();
      final subjects = await api.getRawList('/subjects');
      if (!mounted) return;
      setState(() {
        _examSchedules = schedules.map(_normaliseSchedule).toList();
        _reportCards = reportCards;
        _academicYears = academicYears;
        _examTypes = examTypes;
        _grades = grades;
        _sections = sections;
        _subjects = subjects;
        _exams = exams.map((exam) => _examRow(exam, _examSchedules)).toList();
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load exam administration from backend. $error';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SchoolDeskModuleScaffold(
      title: 'Exam Operations',
      subtitle:
          'Campaigns, schedules, marks, report cards, and publishing status',
      drawer: AdminDrawer(selectedIndex: 6, onDestinationSelected: (_) {}),
      railBreakpoint: double.infinity,
      navigationDrawerEnabled: false,
      floatingActionButton: const DashboardFabWidget(role: DashboardRole.admin),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      actions: [
        IconButton(
          tooltip: 'Create exam campaign',
          icon: const Icon(Icons.add_rounded),
          onPressed: _openExamForm,
        ),
        IconButton(
          tooltip: 'Add exam type',
          icon: const Icon(Icons.category_outlined),
          onPressed: _openExamTypeForm,
        ),
        IconButton(
          tooltip: 'Refresh exams',
          icon: const Icon(Icons.refresh_rounded),
          onPressed: _loadData,
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
        icon: Icons.fact_check_outlined,
        title: 'Exam operations unavailable',
        message: _error!,
        actionLabel: 'Retry',
        onAction: _loadData,
      );
    }
    return OpsWorkspace(
      children: [
        OpsResponsiveGrid(
          minTileWidth: 210,
          children: [
            OpsMetricCard(
              label: 'Exam campaigns',
              value: '${_exams.length}',
              icon: Icons.assignment_outlined,
              color: Colors.indigo,
              caption: '/exams',
            ),
            OpsMetricCard(
              label: 'Schedules',
              value: '${_examSchedules.length}',
              icon: Icons.event_available_outlined,
              color: Colors.teal,
              caption: '/exams/schedules',
            ),
            OpsMetricCard(
              label: 'Published',
              value:
                  '${_exams.where((exam) => exam['isPublished'] == true).length}',
              icon: Icons.publish_outlined,
              color: Colors.green,
              caption: 'Report ready',
            ),
            OpsMetricCard(
              label: 'Report cards',
              value: '${_reportCards.length}',
              icon: Icons.description_outlined,
              color: Colors.deepPurple,
              caption: '/exams/report-cards',
            ),
          ],
        ),
        _buildModePicker(),
        _buildCurrentView(),
      ],
    );
  }

  Widget _buildModePicker() {
    return OpsPanel(
      title: 'Exam Workspace',
      subtitle:
          'One canonical exam campaign model with schedules, marks, and reports as support workflows',
      trailing: FilledButton.icon(
        onPressed: _openScheduleForm,
        icon: const Icon(Icons.add_task_rounded),
        label: const Text('Add schedule'),
      ),
      child: OpsModeSelector<_ExamWorkspaceView>(
        selected: _view,
        options: const [
          OpsModeOption(
            value: _ExamWorkspaceView.campaigns,
            icon: Icons.assignment_outlined,
            label: 'Campaigns',
          ),
          OpsModeOption(
            value: _ExamWorkspaceView.schedules,
            icon: Icons.calendar_month_outlined,
            label: 'Schedules',
          ),
          OpsModeOption(
            value: _ExamWorkspaceView.marks,
            icon: Icons.edit_note_rounded,
            label: 'Marks',
          ),
          OpsModeOption(
            value: _ExamWorkspaceView.reports,
            icon: Icons.summarize_outlined,
            label: 'Reports',
          ),
        ],
        onSelected: (value) => setState(() => _view = value),
      ),
    );
  }

  Widget _buildCurrentView() {
    return switch (_view) {
      _ExamWorkspaceView.campaigns => _buildCampaigns(),
      _ExamWorkspaceView.schedules => _buildSchedules(),
      _ExamWorkspaceView.marks => _buildMarks(),
      _ExamWorkspaceView.reports => _buildReports(),
    };
  }

  Widget _buildCampaigns() {
    return OpsPanel(
      title: 'Exam Campaigns',
      subtitle:
          'Create exam roots here; class/subject/date rows live in schedules',
      trailing: OutlinedButton.icon(
        onPressed: _openExamForm,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Create exam'),
      ),
      child: _exams.isEmpty
          ? OpsEmptyState(
              icon: Icons.assignment_late_outlined,
              title: 'No exam campaigns yet',
              message:
                  'Create the campaign first, then add schedule rows for classes and subjects.',
            )
          : Column(children: [for (final exam in _exams) _buildExamRow(exam)]),
    );
  }

  Widget _buildExamRow(Map<String, dynamic> exam) {
    final published = exam['isPublished'] == true;
    return OpsListRow(
      icon: published
          ? Icons.verified_outlined
          : Icons.pending_actions_outlined,
      title: _text(exam['name'], fallback: 'Exam campaign'),
      subtitle:
          '${_formatDate(exam['startDate'])} - ${_formatDate(exam['endDate'])} | ${exam['scheduleCount']} schedules | ${_text(exam['subjects'], fallback: 'Subjects pending')}',
      trailing: Wrap(
        spacing: 8,
        children: [
          OpsStatusPill(
            label: published ? 'Published' : 'Draft',
            color: published ? Colors.green : Colors.orange,
          ),
          IconButton(
            tooltip: published ? 'Unpublish exam' : 'Publish exam',
            icon: Icon(
              published
                  ? Icons.visibility_off_outlined
                  : Icons.publish_outlined,
            ),
            onPressed: () => _setExamPublished(_text(exam['id']), !published),
          ),
        ],
      ),
    );
  }

  Widget _buildSchedules() {
    return OpsPanel(
      title: 'Schedule Matrix',
      subtitle:
          'Class, section, subject, date, room, and invigilator readiness',
      child: _examSchedules.isEmpty
          ? OpsEmptyState(
              icon: Icons.event_busy_outlined,
              title: 'No schedules configured',
              message:
                  'Use Add schedule to create class and subject exam rows.',
            )
          : Column(
              children: [
                for (final schedule in _examSchedules)
                  _buildScheduleRow(schedule),
              ],
            ),
    );
  }

  Widget _buildScheduleRow(Map<String, dynamic> schedule) {
    return OpsListRow(
      icon: Icons.event_note_outlined,
      title:
          '${_text(schedule['examName'], fallback: 'Exam')} - ${_text(schedule['subjectName'], fallback: 'Subject')}',
      subtitle:
          '${_classLabelForSchedules([schedule])} | ${_formatDate(schedule['examDate'])} | ${_text(schedule['startTime'])}-${_text(schedule['endTime'])}',
      trailing: Wrap(
        spacing: 8,
        children: [
          OpsStatusPill(
            label: _text(schedule['roomName'], fallback: 'Room pending'),
            color: Colors.indigo,
          ),
          IconButton(
            tooltip: 'Enter marks',
            icon: const Icon(Icons.edit_note_rounded),
            onPressed: () => _openMarksEntry(schedule),
          ),
        ],
      ),
    );
  }

  Widget _buildMarks() {
    final pending = _examSchedules
        .where(
          (schedule) =>
              _int(schedule['marksEntered']) < _int(schedule['studentCount']),
        )
        .toList();
    return OpsPanel(
      title: 'Marks And Evaluation',
      subtitle: 'Marks are entered against schedule support endpoints',
      child: pending.isEmpty
          ? OpsListRow(
              icon: Icons.verified_outlined,
              title: 'No pending marks detected',
              subtitle:
                  'Schedules with backend counts are fully entered or have no student rows yet.',
              trailing: const OpsStatusPill(
                label: 'Clear',
                color: Colors.green,
              ),
            )
          : Column(
              children: [
                for (final schedule in pending)
                  OpsListRow(
                    icon: Icons.pending_actions_outlined,
                    title:
                        '${_text(schedule['subjectName'], fallback: 'Subject')} marks pending',
                    subtitle:
                        '${_int(schedule['marksEntered'])}/${_int(schedule['studentCount'])} marks entered for ${_classLabelForSchedules([schedule])}',
                    trailing: TextButton.icon(
                      onPressed: () => _openMarksEntry(schedule),
                      icon: const Icon(Icons.edit_note_rounded),
                      label: const Text('Enter'),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildReports() {
    return OpsPanel(
      title: 'Report Cards',
      subtitle:
          'Publishing and report-card readiness are verified from backend rows',
      child: _reportCards.isEmpty
          ? OpsEmptyState(
              icon: Icons.description_outlined,
              title: 'No report cards generated',
              message:
                  'Report card rows will appear here after schedules and marks are ready.',
            )
          : Column(
              children: [
                for (final card in _reportCards.take(12))
                  OpsListRow(
                    icon: Icons.description_outlined,
                    title: _text(
                      card['student_name'] ?? card['student_id'],
                      fallback: 'Report card',
                    ),
                    subtitle:
                        '${_text(card['exam_name'] ?? card['exam_id'])} | ${_text(card['status'], fallback: 'Draft')}',
                    trailing: OpsStatusPill(
                      label: _text(card['status'], fallback: 'Draft'),
                      color: _text(card['status']).toLowerCase() == 'published'
                          ? Colors.green
                          : Colors.orange,
                    ),
                  ),
              ],
            ),
    );
  }

  Future<void> _openExamForm({Map<String, dynamic>? exam}) async {
    final result = await Navigator.pushNamed(
      context,
      AppRoutes.adminExamForm,
      arguments: AdminExamFormArgs(
        academicYears: _academicYears,
        examTypes: _examTypes,
        exam: exam,
      ),
    );
    await _handleExamResult(result);
  }

  Future<void> _openScheduleForm() async {
    final result = await Navigator.pushNamed(
      context,
      AppRoutes.adminExamScheduleForm,
      arguments: AdminExamScheduleFormArgs(
        exams: _exams,
        grades: _grades,
        sections: _sections,
        subjects: _subjects,
      ),
    );
    await _handleExamResult(result);
  }

  Future<void> _openMarksEntry(Map<String, dynamic> schedule) async {
    final result = await Navigator.of(context).push<AdminExamFormResult>(
      MaterialPageRoute(
        builder: (_) => AdminExamMarksEntryScreen(
          args: AdminExamMarksEntryArgs(schedule: schedule),
        ),
      ),
    );
    await _handleExamResult(result);
  }

  Future<void> _openExamTypeForm() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const _AdminExamTypeFormPage()),
    );
    if (result == true) {
      await _loadData();
    }
  }

  Future<void> _handleExamResult(Object? result) async {
    if (!mounted || result is! AdminExamFormResult) return;
    await _loadData();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: AppTheme.success,
      ),
    );
  }

  Future<void> _setExamPublished(String id, bool isPublished) async {
    if (id.isEmpty) return;
    try {
      await BackendApiClient.instance.setExamPublished(id, isPublished);
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isPublished ? 'Exam published' : 'Exam unpublished'),
          backgroundColor: AppTheme.success,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to update publish state: $error'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  Map<String, dynamic> _examRow(
    ExamModel exam,
    List<Map<String, dynamic>> schedules,
  ) {
    final related = schedules
        .where((s) => _scheduleExamId(s) == exam.id)
        .toList();
    return {
      'id': exam.id,
      'name': exam.examName,
      'academicYearId': exam.academicYearId,
      'termId': exam.termId,
      'examTypeId': exam.examTypeId,
      'startDate': exam.startDate,
      'endDate': exam.endDate,
      'class': _classLabelForSchedules(related),
      'from': _formatDate(exam.startDate),
      'to': _formatDate(exam.endDate),
      'scheduleCount': related.length,
      'subjects': _subjectLabelForSchedules(related),
      'status': exam.isPublished ? 'Published' : 'Draft',
      'isPublished': exam.isPublished,
    };
  }

  Map<String, dynamic> _normaliseSchedule(Map<String, dynamic> schedule) {
    final exam = _map(schedule['exam']);
    final grade = _map(schedule['grade']);
    final section = _map(schedule['section']);
    final subject = _map(schedule['subject']);
    final room = _map(schedule['room']);
    final marks = _list(schedule['student_marks']);
    return {
      ...schedule,
      'id': _text(schedule['id']),
      'examId': _scheduleExamId(schedule),
      'examName': _text(
        exam['exam_name'] ?? schedule['exam_name'] ?? schedule['exam_id'],
      ),
      'gradeName': _text(grade['grade_name'] ?? schedule['grade_name']),
      'sectionName': _text(section['section_name'] ?? schedule['section_name']),
      'subjectName': _text(
        subject['subject_name'] ??
            schedule['subject_name'] ??
            schedule['subject_id'],
      ),
      'roomName': _text(
        room['room_name'] ?? room['name'] ?? schedule['room_id'],
      ),
      'examDate': _text(schedule['exam_date'] ?? schedule['date']),
      'startTime': _text(schedule['start_time']),
      'endTime': _text(schedule['end_time']),
      'marksEntered': marks.length,
      'studentCount': _int(
        schedule['student_count'] ?? schedule['students_count'] ?? marks.length,
      ),
    };
  }

  String _classLabelForSchedules(List<Map<String, dynamic>> schedules) {
    final labels = schedules
        .map((schedule) {
          final grade = _text(schedule['gradeName'] ?? schedule['grade_name']);
          final section = _text(
            schedule['sectionName'] ?? schedule['section_name'],
          );
          if (grade.isEmpty && section.isEmpty) return '';
          if (grade.isEmpty) return section;
          if (section.isEmpty) return grade;
          return '$grade - $section';
        })
        .where((label) => label.isNotEmpty)
        .toSet()
        .toList();
    if (labels.isEmpty) return 'Class pending';
    if (labels.length == 1) return labels.first;
    return '${labels.length} classes';
  }

  String _subjectLabelForSchedules(List<Map<String, dynamic>> schedules) {
    final labels = schedules
        .map(
          (schedule) =>
              _text(schedule['subjectName'] ?? schedule['subject_name']),
        )
        .where((label) => label.isNotEmpty)
        .toSet()
        .toList();
    if (labels.isEmpty) return 'Subjects pending';
    if (labels.length <= 2) return labels.join(', ');
    return '${labels.take(2).join(', ')} +${labels.length - 2}';
  }

  String _formatDate(Object? value) {
    final date = DateTime.tryParse('${value ?? ''}');
    if (date == null) return 'Date pending';
    return date.toIso8601String().split('T').first;
  }

  static String _scheduleExamId(Map<String, dynamic> schedule) =>
      _text(schedule['exam_id'] ?? schedule['examId']);

  static Map<String, dynamic> _map(Object? value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  static List<Map<String, dynamic>> _list(Object? value) => value is List
      ? value.whereType<Map>().map(Map<String, dynamic>.from).toList()
      : [];

  static int _int(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }

  static String _text(Object? value, {String fallback = ''}) {
    final text = '${value ?? ''}'.trim();
    return text.isEmpty || text == 'null' ? fallback : text;
  }
}

class _AdminExamTypeFormPage extends StatefulWidget {
  const _AdminExamTypeFormPage();

  @override
  State<_AdminExamTypeFormPage> createState() => _AdminExamTypeFormPageState();
}

class _AdminExamTypeFormPageState extends State<_AdminExamTypeFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _weightController = TextEditingController(text: '10');
  bool _isBoardExam = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await BackendApiClient.instance.createRaw('/exams/types', {
        'name': _nameController.text.trim(),
        'weightage_percent':
            double.tryParse(_weightController.text.trim()) ?? 0,
        'is_board_exam': _isBoardExam,
      });
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '$error';
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SchoolDeskModuleScaffold(
      title: 'Create Exam Type',
      subtitle: 'Define the exam category used by campaigns',
      drawer: AdminDrawer(selectedIndex: 6, onDestinationSelected: (_) {}),
      railBreakpoint: double.infinity,
      navigationDrawerEnabled: false,
      actions: [
        IconButton(
          tooltip: 'Save exam type',
          icon: _saving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          onPressed: _saving ? null : _save,
        ),
      ],
      body: OpsWorkspace(
        maxWidth: 720,
        children: [
          OpsPanel(
            title: 'Exam Type Details',
            subtitle: 'These rows feed the canonical exams contract',
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  if (_error != null) ...[
                    OpsStatusPill(label: _error!, color: Colors.red),
                    const SizedBox(height: 16),
                  ],
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Exam type name',
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                    validator: (value) => (value ?? '').trim().isEmpty
                        ? 'Exam type name is required'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _weightController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Weightage percent',
                      prefixIcon: Icon(Icons.percent_rounded),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SwitchListTile(
                    value: _isBoardExam,
                    onChanged: (value) => setState(() => _isBoardExam = value),
                    title: const Text('Board exam'),
                    secondary: const Icon(Icons.verified_outlined),
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Save exam type'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
