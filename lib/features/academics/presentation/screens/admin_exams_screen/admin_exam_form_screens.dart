import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/theme/app_theme.dart';
import 'package:schooldesk1/core/widgets/admin_navigation.dart';
import 'package:schooldesk1/core/widgets/dashboard_fab_widget.dart';
import 'package:schooldesk1/core/widgets/erp_components.dart';
import 'package:schooldesk1/core/widgets/erp_module_scaffold.dart';

@immutable
class AdminExamFormArgs {
  final List<AcademicYearModel> academicYears;
  final List<Map<String, dynamic>> examTypes;
  final Map<String, dynamic>? exam;

  const AdminExamFormArgs({
    required this.academicYears,
    required this.examTypes,
    this.exam,
  });

  bool get isEditing => exam != null;
}

@immutable
class AdminExamScheduleFormArgs {
  final List<Map<String, dynamic>> exams;
  final List<GradeModel> grades;
  final List<SectionModel> sections;
  final List<Map<String, dynamic>> subjects;

  const AdminExamScheduleFormArgs({
    required this.exams,
    required this.grades,
    required this.sections,
    required this.subjects,
  });
}

@immutable
class AdminExamMarksEntryArgs {
  final Map<String, dynamic> schedule;

  const AdminExamMarksEntryArgs({required this.schedule});
}

@immutable
class AdminExamFormResult {
  final String message;

  const AdminExamFormResult(this.message);
}

class AdminExamFormScreen extends StatefulWidget {
  final AdminExamFormArgs args;

  const AdminExamFormScreen({super.key, required this.args});

  @override
  State<AdminExamFormScreen> createState() => _AdminExamFormScreenState();
}

class _AdminExamFormScreenState extends State<AdminExamFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  late final TextEditingController _startDateController;
  late final TextEditingController _endDateController;
  List<Map<String, dynamic>> _terms = [];
  String _academicYearId = '';
  String _termId = '';
  String _examTypeId = '';
  bool _loadingTerms = false;
  bool _saving = false;

  bool get _ready =>
      widget.args.academicYears.isNotEmpty &&
      widget.args.examTypes.isNotEmpty &&
      _terms.isNotEmpty;

  @override
  void initState() {
    super.initState();
    final exam = widget.args.exam;
    _nameController.text = _text(exam?['name']);
    _startDateController = TextEditingController(
      text: _dateOnly(
        _text(exam?['startDate']),
        fallback: _dateInput(DateTime.now()),
      ),
    );
    _endDateController = TextEditingController(
      text: _dateOnly(
        _text(exam?['endDate']),
        fallback: _dateInput(DateTime.now()),
      ),
    );
    _academicYearId = _initialId(
      _text(exam?['academicYearId']),
      widget.args.academicYears.map((year) => year.id),
    );
    _examTypeId = _initialId(
      _text(exam?['examTypeId']),
      widget.args.examTypes.map((type) => _text(type['id'])),
    );
    _loadTerms(preferredTermId: _text(exam?['termId']));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _ExamFormScaffold(
      title: widget.args.isEditing ? 'Edit Exam' : 'Create Exam',
      subtitle: 'Use backend academic year, term, and exam type records',
      saving: _saving,
      saveLabel: widget.args.isEditing ? 'Save exam' : 'Create exam',
      onSave: _ready ? _save : null,
      child: _ready
          ? Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameController,
                    enabled: !_saving,
                    decoration: const InputDecoration(labelText: 'Exam name'),
                    validator: (value) => _required(value, 'Enter exam name.'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _academicYearId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Academic year',
                    ),
                    items: widget.args.academicYears
                        .map(
                          (year) => DropdownMenuItem(
                            value: year.id,
                            child: Text(year.yearLabel),
                          ),
                        )
                        .toList(),
                    validator: (value) =>
                        _required(value, 'Select academic year.'),
                    onChanged: _saving
                        ? null
                        : (value) {
                            final next = value ?? '';
                            setState(() {
                              _academicYearId = next;
                              _terms = [];
                              _termId = '';
                            });
                            _loadTerms();
                          },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _termId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Term'),
                    items: _terms
                        .map(
                          (term) => DropdownMenuItem(
                            value: _text(term['id']),
                            child: Text(_termName(term)),
                          ),
                        )
                        .toList(),
                    validator: (value) => _required(value, 'Select term.'),
                    onChanged: _saving || _loadingTerms
                        ? null
                        : (value) => setState(() => _termId = value ?? ''),
                  ),
                  if (_loadingTerms)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: LinearProgressIndicator(minHeight: 2),
                    ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _examTypeId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Exam type'),
                    items: widget.args.examTypes
                        .where((type) => _text(type['id']).isNotEmpty)
                        .map(
                          (type) => DropdownMenuItem(
                            value: _text(type['id']),
                            child: Text(_examTypeName(type)),
                          ),
                        )
                        .toList(),
                    validator: (value) => _required(value, 'Select exam type.'),
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => _examTypeId = value ?? ''),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _dateField(
                          controller: _startDateController,
                          label: 'Start date',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _dateField(
                          controller: _endDateController,
                          label: 'End date',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            )
          : const SchoolDeskStatusPanel.empty(
              title: 'Exam setup required',
              message:
                  'Academic years, terms, and exam types must exist before creating exams.',
            ),
    );
  }

  Widget _dateField({
    required TextEditingController controller,
    required String label,
  }) {
    return TextFormField(
      controller: controller,
      enabled: !_saving,
      keyboardType: TextInputType.datetime,
      decoration: InputDecoration(labelText: label, helperText: 'YYYY-MM-DD'),
      validator: _dateValidator,
    );
  }

  Future<void> _loadTerms({String preferredTermId = ''}) async {
    if (_academicYearId.isEmpty) return;
    setState(() => _loadingTerms = true);
    try {
      final terms = await BackendApiClient.instance.getTerms(_academicYearId);
      if (!mounted) return;
      setState(() {
        _terms = terms;
        _termId = _initialId(
          preferredTermId,
          terms.map((term) => _text(term['id'])),
        );
      });
    } catch (error) {
      if (!mounted) return;
      _showError(context, 'Terms load failed: ${_cleanError(error)}');
    } finally {
      if (mounted) setState(() => _loadingTerms = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final start = DateTime.parse(_startDateController.text.trim());
    final end = DateTime.parse(_endDateController.text.trim());
    if (end.isBefore(start)) {
      _showError(context, 'End date cannot be before start date.');
      return;
    }
    setState(() => _saving = true);
    try {
      if (widget.args.isEditing) {
        final id = _text(widget.args.exam?['id']);
        if (id.isEmpty) throw Exception('Backend exam ID is missing');
        await BackendApiClient.instance.updateExam(
          id,
          academicYearId: _academicYearId,
          termId: _termId,
          examTypeId: _examTypeId,
          examName: _nameController.text.trim(),
          startDate: _startDateController.text.trim(),
          endDate: _endDateController.text.trim(),
        );
      } else {
        await BackendApiClient.instance.createExam(
          academicYearId: _academicYearId,
          termId: _termId,
          examTypeId: _examTypeId,
          examName: _nameController.text.trim(),
          startDate: _startDateController.text.trim(),
          endDate: _endDateController.text.trim(),
        );
      }
      if (!mounted) return;
      Navigator.pop(
        context,
        AdminExamFormResult(
          widget.args.isEditing ? 'Exam updated' : 'Exam created',
        ),
      );
    } catch (error) {
      _showError(context, 'Exam save failed: ${_cleanError(error)}');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class AdminExamScheduleFormScreen extends StatefulWidget {
  final AdminExamScheduleFormArgs args;

  const AdminExamScheduleFormScreen({super.key, required this.args});

  @override
  State<AdminExamScheduleFormScreen> createState() =>
      _AdminExamScheduleFormScreenState();
}

class _AdminExamScheduleFormScreenState
    extends State<AdminExamScheduleFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _dateController;
  final _startTimeController = TextEditingController(text: '09:00');
  final _endTimeController = TextEditingController(text: '10:00');
  final _maxMarksController = TextEditingController(text: '100');
  final _passMarksController = TextEditingController(text: '35');
  String _examId = '';
  String _gradeId = '';
  String _sectionId = '';
  String _subjectId = '';
  bool _saving = false;

  bool get _ready =>
      widget.args.exams.isNotEmpty &&
      widget.args.grades.isNotEmpty &&
      widget.args.sections.isNotEmpty &&
      widget.args.subjects.isNotEmpty;

  List<SectionModel> get _gradeSections => widget.args.sections
      .where((section) => section.gradeId == _gradeId)
      .toList();

  @override
  void initState() {
    super.initState();
    _dateController = TextEditingController(text: _dateInput(DateTime.now()));
    _examId = _initialId(
      '',
      widget.args.exams.map((exam) => _text(exam['id'])),
    );
    _gradeId = _initialId('', widget.args.grades.map((grade) => grade.id));
    _sectionId = _initialId('', _gradeSections.map((section) => section.id));
    _subjectId = _initialId(
      '',
      widget.args.subjects.map((subject) => _text(subject['id'])),
    );
  }

  @override
  void dispose() {
    _dateController.dispose();
    _startTimeController.dispose();
    _endTimeController.dispose();
    _maxMarksController.dispose();
    _passMarksController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _ExamFormScaffold(
      title: 'Add Exam Schedule',
      subtitle: 'Create a backend exam schedule row for a class and subject',
      saving: _saving,
      saveLabel: 'Save schedule',
      onSave: _ready ? _save : null,
      child: _ready
          ? Form(
              key: _formKey,
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _examId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Exam'),
                    items: widget.args.exams
                        .where((exam) => _text(exam['id']).isNotEmpty)
                        .map(
                          (exam) => DropdownMenuItem(
                            value: _text(exam['id']),
                            child: Text(
                              _text(exam['name'], fallback: 'Exam'),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    validator: (value) => _required(value, 'Select exam.'),
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => _examId = value ?? ''),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _gradeId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Grade'),
                    items: widget.args.grades
                        .map(
                          (grade) => DropdownMenuItem(
                            value: grade.id,
                            child: Text(grade.gradeName),
                          ),
                        )
                        .toList(),
                    validator: (value) => _required(value, 'Select grade.'),
                    onChanged: _saving
                        ? null
                        : (value) => setState(() {
                            _gradeId = value ?? '';
                            _sectionId = _initialId(
                              '',
                              _gradeSections.map((section) => section.id),
                            );
                          }),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _sectionId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Section'),
                    items: _gradeSections
                        .map(
                          (section) => DropdownMenuItem(
                            value: section.id,
                            child: Text(_sectionName(section)),
                          ),
                        )
                        .toList(),
                    validator: (value) => _required(value, 'Select section.'),
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => _sectionId = value ?? ''),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _subjectId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Subject'),
                    items: widget.args.subjects
                        .where((subject) => _text(subject['id']).isNotEmpty)
                        .map(
                          (subject) => DropdownMenuItem(
                            value: _text(subject['id']),
                            child: Text(
                              _subjectName(subject),
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
                  TextFormField(
                    controller: _dateController,
                    enabled: !_saving,
                    keyboardType: TextInputType.datetime,
                    decoration: const InputDecoration(
                      labelText: 'Exam date',
                      helperText: 'YYYY-MM-DD',
                    ),
                    validator: _dateValidator,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _startTimeController,
                          enabled: !_saving,
                          decoration: const InputDecoration(
                            labelText: 'Start time',
                            helperText: 'HH:MM',
                          ),
                          validator: _optionalTimeValidator,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _endTimeController,
                          enabled: !_saving,
                          decoration: const InputDecoration(
                            labelText: 'End time',
                            helperText: 'HH:MM',
                          ),
                          validator: _optionalTimeValidator,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _maxMarksController,
                          enabled: !_saving,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Max marks',
                          ),
                          validator: _positiveIntValidator,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _passMarksController,
                          enabled: !_saving,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Pass marks',
                          ),
                          validator: _nonNegativeIntValidator,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            )
          : const SchoolDeskStatusPanel.empty(
              title: 'Schedule setup required',
              message:
                  'Create exams, grades, sections, and subjects before adding an exam schedule.',
            ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final maxMarks = int.parse(_maxMarksController.text.trim());
    final passMarks = int.parse(_passMarksController.text.trim());
    if (passMarks > maxMarks) {
      _showError(context, 'Pass marks cannot exceed max marks.');
      return;
    }
    setState(() => _saving = true);
    try {
      await BackendApiClient.instance.createRaw('/exams/schedules', {
        'exam_id': _examId,
        'grade_id': _gradeId,
        'section_id': _sectionId,
        'subject_id': _subjectId,
        'exam_date': _dateController.text.trim(),
        'start_time': _startTimeController.text.trim(),
        'end_time': _endTimeController.text.trim(),
        'max_marks': maxMarks,
        'pass_marks': passMarks,
      });
      if (!mounted) return;
      Navigator.pop(context, const AdminExamFormResult('Exam schedule saved'));
    } catch (error) {
      _showError(context, 'Schedule save failed: ${_cleanError(error)}');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class AdminExamMarksEntryScreen extends StatefulWidget {
  final AdminExamMarksEntryArgs args;

  const AdminExamMarksEntryScreen({super.key, required this.args});

  @override
  State<AdminExamMarksEntryScreen> createState() =>
      _AdminExamMarksEntryScreenState();
}

class _AdminExamMarksEntryScreenState extends State<AdminExamMarksEntryScreen> {
  bool _loading = true;
  bool _saving = false;
  String? _error;
  final List<_MarkEntry> _entries = [];

  String get _scheduleId => _text(widget.args.schedule['id']);
  String get _sectionId => _text(widget.args.schedule['sectionId']);
  double get _maxMarks {
    final value = widget.args.schedule['maxMarks'];
    if (value is num) return value.toDouble();
    return double.tryParse(_text(value)) ?? 0;
  }

  String get _title =>
      '${_text(widget.args.schedule['exam'], fallback: 'Exam')}'
      ' · ${_text(widget.args.schedule['subject'], fallback: 'Subject')}';

  String get _subtitle =>
      '${_text(widget.args.schedule['class'], fallback: 'Class')} · '
      '${_text(widget.args.schedule['date'], fallback: 'Date')}';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    for (final entry in _entries) {
      entry.dispose();
    }
    super.dispose();
  }

  Future<void> _loadData() async {
    for (final entry in _entries) {
      entry.dispose();
    }
    _entries.clear();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_scheduleId.isEmpty || _sectionId.isEmpty) {
        throw Exception('Backend schedule or section ID is missing.');
      }
      final api = BackendApiClient.instance;
      final students = await api.getStudents(
        sectionId: _sectionId,
        status: 'active',
        page: 1,
        pageSize: 300,
      );
      final existingMarks = await api.getRawList(
        '/exams/schedules/$_scheduleId/marks',
      );
      final existingByStudent = <String, Map<String, dynamic>>{
        for (final mark in existingMarks)
          if (_text(mark['student_id']).isNotEmpty)
            _text(mark['student_id']): mark,
      };

      final nextEntries = <_MarkEntry>[];
      for (final student in students.data) {
        final enrollments = await api.getStudentEnrollments(student.id);
        final enrollment = _matchingEnrollment(enrollments);
        final existing = existingByStudent[student.id];
        final absent = existing?['is_absent'] == true;
        final exempted = existing?['is_exempted'] == true;
        final marks = existing == null || absent || exempted
            ? ''
            : _markText(existing['marks_obtained']);
        nextEntries.add(
          _MarkEntry(
            student: student,
            enrollmentId: _text(enrollment['id']),
            controller: TextEditingController(text: marks),
            isAbsent: absent,
            isExempted: exempted,
          ),
        );
      }

      if (!mounted) return;
      setState(() {
        _entries.addAll(nextEntries);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _cleanError(error);
        _loading = false;
      });
    }
  }

  Map<String, dynamic> _matchingEnrollment(
    List<Map<String, dynamic>> enrollments,
  ) {
    for (final row in enrollments) {
      if (_text(row['section_id']) == _sectionId) return row;
    }
    return enrollments.isEmpty ? <String, dynamic>{} : enrollments.first;
  }

  @override
  Widget build(BuildContext context) {
    return _ExamFormScaffold(
      title: 'Enter Marks',
      subtitle: _subtitle,
      saving: _saving,
      saveLabel: 'Save marks',
      onSave: _loading || _error != null || _entries.isEmpty ? null : _save,
      child: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: LinearProgressIndicator(minHeight: 2),
      );
    }
    if (_error != null) {
      return Column(
        children: [
          SchoolDeskStatusPanel.empty(
            title: 'Marks load failed',
            message: _error!,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Retry'),
          ),
        ],
      );
    }
    if (_entries.isEmpty) {
      return const SchoolDeskStatusPanel.empty(
        title: 'No students',
        message: 'No active students are enrolled in this schedule section.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          'Maximum marks: ${_maxMarks.toStringAsFixed(_maxMarks.truncateToDouble() == _maxMarks ? 0 : 1)}',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppTheme.muted),
        ),
        const SizedBox(height: 14),
        ..._entries.map(_entryTile),
      ],
    );
  }

  Widget _entryTile(_MarkEntry entry) {
    final grade = _gradeLabel(entry);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  entry.student.fullName.trim().isEmpty
                      ? entry.student.studentCode
                      : entry.student.fullName,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  grade,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: entry.controller,
            enabled: !_saving && !entry.isAbsent && !entry.isExempted,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Marks',
              helperText: entry.enrollmentId.isEmpty
                  ? 'Enrollment missing'
                  : entry.student.studentCode,
              suffixText: _maxMarks > 0
                  ? '/ ${_maxMarks.toStringAsFixed(0)}'
                  : null,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilterChip(
                label: const Text('Absent'),
                selected: entry.isAbsent,
                onSelected: _saving
                    ? null
                    : (selected) => setState(() {
                        entry.isAbsent = selected;
                        if (selected) {
                          entry.isExempted = false;
                          entry.controller.clear();
                        }
                      }),
              ),
              FilterChip(
                label: const Text('Exempted'),
                selected: entry.isExempted,
                onSelected: _saving
                    ? null
                    : (selected) => setState(() {
                        entry.isExempted = selected;
                        if (selected) {
                          entry.isAbsent = false;
                          entry.controller.clear();
                        }
                      }),
              ),
            ],
          ),
          const Divider(height: 22),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final marks = <Map<String, dynamic>>[];
    for (final entry in _entries) {
      if (entry.enrollmentId.isEmpty) continue;
      final rawMarks = entry.isAbsent || entry.isExempted
          ? 0.0
          : double.tryParse(entry.controller.text.trim());
      if (rawMarks == null) {
        _showError(context, 'Enter valid marks for ${entry.student.fullName}.');
        return;
      }
      if (rawMarks < 0 || (_maxMarks > 0 && rawMarks > _maxMarks)) {
        _showError(
          context,
          'Marks for ${entry.student.fullName} must be between 0 and ${_maxMarks.toStringAsFixed(0)}.',
        );
        return;
      }
      marks.add({
        'student_id': entry.student.id,
        'enrollment_id': entry.enrollmentId,
        'marks_obtained': rawMarks,
        'grade_label': _gradeLabel(entry),
        'is_absent': entry.isAbsent,
        'is_exempted': entry.isExempted,
      });
    }
    if (marks.isEmpty) {
      _showError(context, 'No enrolled students are available for saving.');
      return;
    }
    setState(() => _saving = true);
    try {
      await BackendApiClient.instance.createRaw(
        '/exams/schedules/$_scheduleId/marks',
        {'marks': marks},
      );
      if (!mounted) return;
      Navigator.pop(context, const AdminExamFormResult('Marks saved'));
    } catch (error) {
      if (!mounted) return;
      _showError(context, 'Marks save failed: ${_cleanError(error)}');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _gradeLabel(_MarkEntry entry) {
    if (entry.isAbsent) return 'AB';
    if (entry.isExempted) return 'EX';
    final marks = double.tryParse(entry.controller.text.trim());
    if (marks == null || _maxMarks <= 0) return '-';
    final pct = marks / _maxMarks * 100;
    if (pct >= 90) return 'A+';
    if (pct >= 80) return 'A';
    if (pct >= 70) return 'B+';
    if (pct >= 60) return 'B';
    if (pct >= 50) return 'C';
    if (pct >= 35) return 'D';
    return 'F';
  }

  String _markText(Object? value) {
    final parsed = value is num
        ? value.toDouble()
        : double.tryParse(_text(value));
    if (parsed == null) return '';
    return parsed.truncateToDouble() == parsed
        ? parsed.toStringAsFixed(0)
        : parsed.toStringAsFixed(2);
  }
}

class _MarkEntry {
  final StudentModel student;
  final String enrollmentId;
  final TextEditingController controller;
  bool isAbsent;
  bool isExempted;

  _MarkEntry({
    required this.student,
    required this.enrollmentId,
    required this.controller,
    required this.isAbsent,
    required this.isExempted,
  });

  void dispose() {
    controller.dispose();
  }
}

class _ExamFormScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final bool saving;
  final String saveLabel;
  final VoidCallback? onSave;

  const _ExamFormScaffold({
    required this.title,
    required this.subtitle,
    required this.child,
    required this.saving,
    required this.saveLabel,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return SchoolDeskModuleScaffold(
      title: title,
      subtitle: subtitle,
      drawer: AdminDrawer(selectedIndex: 6, onDestinationSelected: (_) {}),
      floatingActionButton: const DashboardFabWidget(role: DashboardRole.admin),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.outlineVariant),
            ),
            child: child,
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: saving ? null : onSave,
            icon: saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_rounded, size: 18),
            label: Text(saving ? 'Saving...' : saveLabel),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: saving ? null : () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
            label: const Text('Back'),
          ),
        ],
      ),
    );
  }
}

String _initialId(String preferred, Iterable<String> options) {
  final values = options.where((value) => value.trim().isNotEmpty).toList();
  if (preferred.trim().isNotEmpty && values.contains(preferred)) {
    return preferred;
  }
  return values.isEmpty ? '' : values.first;
}

String _termName(Map<String, dynamic> term) {
  final name = _text(term['term_name'], fallback: _text(term['name']));
  if (name.isNotEmpty) return name;
  final number = _text(term['term_number']);
  return number.isEmpty ? 'Term' : 'Term $number';
}

String _examTypeName(Map<String, dynamic> type) {
  return _text(type['name'], fallback: _text(type['exam_type']));
}

String _sectionName(SectionModel section) {
  final grade = section.gradeName.trim();
  final sectionName = section.sectionName.trim();
  if (grade.isEmpty) return sectionName;
  if (sectionName.isEmpty) return grade;
  return '$grade $sectionName';
}

String _subjectName(Map<String, dynamic> subject) {
  return _text(subject['subject_name'], fallback: _text(subject['name']));
}

String _dateInput(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

String _dateOnly(String value, {required String fallback}) {
  if (value.trim().isEmpty) return fallback;
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value;
  return _dateInput(parsed);
}

String _text(Object? value, {String fallback = ''}) {
  final text = '${value ?? ''}'.trim();
  if (text.isEmpty || text == 'null') return fallback;
  return text;
}

String? _required(String? value, String message) {
  if (value == null || value.trim().isEmpty) return message;
  return null;
}

String? _dateValidator(String? value) {
  final text = (value ?? '').trim();
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text)) {
    return 'Use YYYY-MM-DD.';
  }
  return DateTime.tryParse(text) == null ? 'Enter a valid date.' : null;
}

String? _optionalTimeValidator(String? value) {
  final text = (value ?? '').trim();
  if (text.isEmpty) return null;
  if (!RegExp(r'^\d{2}:\d{2}$').hasMatch(text)) {
    return 'Use HH:MM.';
  }
  final hour = int.tryParse(text.substring(0, 2)) ?? -1;
  final minute = int.tryParse(text.substring(3, 5)) ?? -1;
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
    return 'Enter a valid time.';
  }
  return null;
}

String? _positiveIntValidator(String? value) {
  final parsed = int.tryParse(value ?? '') ?? 0;
  return parsed <= 0 ? 'Enter a positive number.' : null;
}

String? _nonNegativeIntValidator(String? value) {
  final parsed = int.tryParse(value ?? '') ?? -1;
  return parsed < 0 ? 'Enter zero or a positive number.' : null;
}

void _showError(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), backgroundColor: AppTheme.error),
  );
}

String _cleanError(Object error) {
  final raw = error.toString();
  final server = RegExp(r'ServerException\([^)]*\):\s*(.*)').firstMatch(raw);
  if (server != null) return server.group(1)?.trim() ?? raw;
  final network = RegExp(r'NetworkException\([^)]*\):\s*(.*)').firstMatch(raw);
  if (network != null) return network.group(1)?.trim() ?? raw;
  return raw.replaceFirst('Exception: ', '').trim();
}
