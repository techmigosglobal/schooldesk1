import 'package:flutter/material.dart';

import '../../services/backend_api_client.dart';
import '../../theme/app_theme.dart';
import '../../widgets/dashboard_fab_widget.dart';
import '../../widgets/erp_components.dart';
import '../../widgets/erp_module_scaffold.dart';
import '../../widgets/teacher_navigation.dart';

@immutable
class TeacherHomeworkFormArgs {
  final String teacherStaffId;
  final String defaultClassName;
  final String defaultSubject;
  final List<Map<String, dynamic>> assignedClasses;
  final List<Map<String, dynamic>> students;
  final Map<String, dynamic>? homework;

  const TeacherHomeworkFormArgs({
    required this.teacherStaffId,
    required this.defaultClassName,
    required this.defaultSubject,
    required this.assignedClasses,
    required this.students,
    this.homework,
  });

  bool get isEditing => homework != null;
}

@immutable
class TeacherHomeworkSubmissionsArgs {
  final Map<String, dynamic> homework;

  const TeacherHomeworkSubmissionsArgs({required this.homework});
}

@immutable
class TeacherHomeworkResult {
  final String message;

  const TeacherHomeworkResult(this.message);
}

class TeacherHomeworkFormScreen extends StatefulWidget {
  final TeacherHomeworkFormArgs args;

  const TeacherHomeworkFormScreen({super.key, required this.args});

  @override
  State<TeacherHomeworkFormScreen> createState() =>
      _TeacherHomeworkFormScreenState();
}

class _TeacherHomeworkFormScreenState extends State<TeacherHomeworkFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _subjectController = TextEditingController();
  final _instructionsController = TextEditingController();
  final _dueDateController = TextEditingController();
  String _sectionId = '';
  String _studentId = '';
  bool _saving = false;

  List<Map<String, dynamic>> get _classOptions {
    final rows = widget.args.assignedClasses
        .where((row) => _text(row['id']).isNotEmpty)
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
    if (rows.isNotEmpty) return rows;
    return [
      {'id': '', 'label': widget.args.defaultClassName},
    ];
  }

  @override
  void initState() {
    super.initState();
    final homework = widget.args.homework;
    _titleController.text = _text(homework?['title']);
    _subjectController.text = _text(
      homework?['subject'],
      fallback: widget.args.defaultSubject,
    );
    _instructionsController.text = _text(homework?['instructions']);
    _dueDateController.text = _dateOnly(
      _text(homework?['dueDate']),
      fallback: _dateInput(DateTime.now().add(const Duration(days: 3))),
    );
    _sectionId = _initialId(
      _text(homework?['section_id']),
      _classOptions.map((row) => _text(row['id'])),
    );
    _studentId = _initialId(_text(homework?['student_id']), [
      '',
      ...widget.args.students.map((row) => _text(row['id'])),
    ]);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subjectController.dispose();
    _instructionsController.dispose();
    _dueDateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ready = widget.args.teacherStaffId.trim().isNotEmpty;
    return SchoolDeskModuleScaffold(
      title: widget.args.isEditing ? 'Edit Homework' : 'New Homework',
      subtitle: 'Create class work with backend-linked class and student scope',
      drawer: TeacherDrawer(selectedIndex: 3, onDestinationSelected: (_) {}),
      floatingActionButton: const DashboardFabWidget(
        role: DashboardRole.teacher,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (ready)
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _titleController,
                    enabled: !_saving,
                    decoration: const InputDecoration(labelText: 'Title'),
                    validator: (value) => _required(value, 'Enter a title.'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _sectionId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Class'),
                    items: _classOptions
                        .map(
                          (row) => DropdownMenuItem(
                            value: _text(row['id']),
                            child: Text(_classLabel(row)),
                          ),
                        )
                        .toList(),
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => _sectionId = value ?? ''),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _subjectController,
                    enabled: !_saving,
                    decoration: const InputDecoration(labelText: 'Subject'),
                    validator: (value) => _required(value, 'Enter subject.'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _studentId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Student scope',
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: '',
                        child: Text('Entire class'),
                      ),
                      ...widget.args.students
                          .where((student) => _text(student['id']).isNotEmpty)
                          .map(
                            (student) => DropdownMenuItem(
                              value: _text(student['id']),
                              child: Text(_studentLabel(student)),
                            ),
                          ),
                    ],
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => _studentId = value ?? ''),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _dueDateController,
                    enabled: !_saving,
                    keyboardType: TextInputType.datetime,
                    decoration: const InputDecoration(
                      labelText: 'Due date',
                      helperText: 'YYYY-MM-DD',
                    ),
                    validator: _dateValidator,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _instructionsController,
                    enabled: !_saving,
                    minLines: 4,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      labelText: 'Instructions',
                      alignLabelWithHint: true,
                    ),
                    validator: (value) =>
                        _required(value, 'Enter homework instructions.'),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded, size: 18),
                    label: Text(_saving ? 'Saving...' : _saveLabel),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_rounded, size: 18),
                    label: const Text('Back to Homework'),
                  ),
                ],
              ),
            )
          else
            const SchoolDeskStatusPanel.empty(
              title: 'Teacher profile required',
              message:
                  'A linked teacher staff profile is required before homework can be assigned.',
            ),
          const SizedBox(height: 84),
        ],
      ),
    );
  }

  String get _saveLabel =>
      widget.args.isEditing ? 'Save homework' : 'Post homework';

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final homework = widget.args.homework;
      final sectionLabel = _classLabel(
        _classOptions.firstWhere(
          (row) => _text(row['id']) == _sectionId,
          orElse: () => {'label': widget.args.defaultClassName},
        ),
      );
      final dueDate = DateTime.parse(
        _dueDateController.text.trim(),
      ).toUtc().toIso8601String();
      if (homework == null) {
        await BackendApiClient.instance.createHomework(
          title: _titleController.text.trim(),
          subject: _subjectController.text.trim(),
          className: sectionLabel,
          sectionId: _sectionId,
          teacherId: widget.args.teacherStaffId,
          studentId: _studentId,
          description: _instructionsController.text.trim(),
          dueDate: dueDate,
        );
      } else {
        await BackendApiClient.instance.updateHomework(
          _text(homework['id']),
          title: _titleController.text.trim(),
          subject: _subjectController.text.trim(),
          className: sectionLabel,
          sectionId: _sectionId,
          teacherId: widget.args.teacherStaffId,
          studentId: _studentId,
          description: _instructionsController.text.trim(),
          dueDate: dueDate,
          status: _text(homework['status']) == 'completed'
              ? 'completed'
              : 'pending',
        );
      }
      if (!mounted) return;
      Navigator.pop(
        context,
        TeacherHomeworkResult(
          widget.args.isEditing
              ? 'Homework updated successfully'
              : 'Homework posted successfully',
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Homework save failed: ${_cleanError(error)}'),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class TeacherHomeworkSubmissionsScreen extends StatefulWidget {
  final TeacherHomeworkSubmissionsArgs args;

  const TeacherHomeworkSubmissionsScreen({super.key, required this.args});

  @override
  State<TeacherHomeworkSubmissionsScreen> createState() =>
      _TeacherHomeworkSubmissionsScreenState();
}

class _TeacherHomeworkSubmissionsScreenState
    extends State<TeacherHomeworkSubmissionsScreen> {
  final _gradeController = TextEditingController();
  final _remarksController = TextEditingController();
  Map<String, dynamic>? _response;
  String _reviewingId = '';
  String _reviewStatus = 'reviewed';
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSubmissions();
  }

  @override
  void dispose() {
    _gradeController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SchoolDeskModuleScaffold(
      title: 'Homework Submissions',
      subtitle: _text(widget.args.homework['title'], fallback: 'Homework'),
      drawer: TeacherDrawer(selectedIndex: 3, onDestinationSelected: (_) {}),
      floatingActionButton: const DashboardFabWidget(
        role: DashboardRole.teacher,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _loadSubmissions,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    final submissions = _submissions;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _summaryCard(),
        const SizedBox(height: 12),
        if (submissions.isEmpty)
          const SchoolDeskStatusPanel.empty(
            title: 'No submissions yet',
            message:
                'Student submissions will appear here after parents submit homework.',
          )
        else
          ...submissions.map(_submissionCard),
        const SizedBox(height: 84),
      ],
    );
  }

  Widget _summaryCard() {
    final summary = Map<String, dynamic>.from(
      _response?['summary'] as Map? ?? {},
    );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Row(
        children: [
          _summaryMetric('Submitted', _intText(summary['submitted'])),
          _summaryMetric('Pending', _intText(summary['pending'])),
          _summaryMetric('Total', _intText(summary['total'])),
        ],
      ),
    );
  }

  Widget _summaryMetric(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: AppTheme.muted)),
        ],
      ),
    );
  }

  Widget _submissionCard(Map<String, dynamic> row) {
    final id = _text(row['id']);
    final isReviewing = _reviewingId == id;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _studentName(row),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              _statusChip(_text(row['status'], fallback: 'submitted')),
            ],
          ),
          const SizedBox(height: 8),
          Text(_text(row['answer_text'], fallback: 'No written answer.')),
          if (_text(row['attachment_url']).isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              _text(row['attachment_url']),
              style: const TextStyle(color: AppTheme.primary),
            ),
          ],
          if (_text(row['grade']).isNotEmpty ||
              _text(row['remarks']).isNotEmpty) ...[
            const Divider(height: 18),
            Text('Grade: ${_text(row['grade'], fallback: '-')}'),
            Text('Remarks: ${_text(row['remarks'], fallback: '-')}'),
          ],
          const SizedBox(height: 10),
          if (isReviewing) _reviewForm(row) else _reviewButton(row),
        ],
      ),
    );
  }

  Widget _statusChip(String status) {
    final color = status == 'reviewed'
        ? AppTheme.success
        : status == 'needs_revision'
        ? AppTheme.warning
        : AppTheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(24),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.replaceAll('_', ' '),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _reviewButton(Map<String, dynamic> row) {
    return OutlinedButton.icon(
      onPressed: _saving
          ? null
          : () {
              setState(() {
                _reviewingId = _text(row['id']);
                _reviewStatus = _text(row['status']) == 'needs_revision'
                    ? 'needs_revision'
                    : 'reviewed';
                _gradeController.text = _text(row['grade']);
                _remarksController.text = _text(row['remarks']);
              });
            },
      icon: const Icon(Icons.rate_review_outlined, size: 18),
      label: const Text('Review submission'),
    );
  }

  Widget _reviewForm(Map<String, dynamic> row) {
    return Column(
      children: [
        DropdownButtonFormField<String>(
          initialValue: _reviewStatus,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Review status'),
          items: const [
            DropdownMenuItem(value: 'reviewed', child: Text('Reviewed')),
            DropdownMenuItem(
              value: 'needs_revision',
              child: Text('Needs revision'),
            ),
          ],
          onChanged: _saving
              ? null
              : (value) => setState(() => _reviewStatus = value ?? 'reviewed'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _gradeController,
          enabled: !_saving,
          decoration: const InputDecoration(labelText: 'Grade'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _remarksController,
          enabled: !_saving,
          minLines: 3,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Remarks',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _saving ? null : () => _saveReview(row),
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_rounded, size: 18),
                label: Text(_saving ? 'Saving...' : 'Save review'),
              ),
            ),
            const SizedBox(width: 10),
            OutlinedButton(
              onPressed: _saving
                  ? null
                  : () => setState(() {
                      _reviewingId = '';
                      _gradeController.clear();
                      _remarksController.clear();
                    }),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ],
    );
  }

  List<Map<String, dynamic>> get _submissions {
    final rows = _response?['submissions'];
    if (rows is! List) return const [];
    return rows
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  Future<void> _loadSubmissions() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await BackendApiClient.instance.getHomeworkSubmissions(
        _text(widget.args.homework['id']),
      );
      if (!mounted) return;
      setState(() {
        _response = response;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load homework submissions.';
        _loading = false;
      });
    }
  }

  Future<void> _saveReview(Map<String, dynamic> row) async {
    if (_reviewStatus == 'needs_revision' &&
        _remarksController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Remarks are required for revision.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await BackendApiClient.instance.reviewHomeworkSubmission(
        _text(widget.args.homework['id']),
        _text(row['id']),
        status: _reviewStatus,
        grade: _gradeController.text.trim(),
        remarks: _remarksController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _reviewingId = '';
        _gradeController.clear();
        _remarksController.clear();
      });
      await _loadSubmissions();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Review failed: ${_cleanError(error)}'),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

String? _required(String? value, String message) {
  if ((value ?? '').trim().isEmpty) return message;
  return null;
}

String? _dateValidator(String? value) {
  final text = (value ?? '').trim();
  if (text.isEmpty) return 'Enter due date.';
  final parsed = DateTime.tryParse(text);
  if (parsed == null || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text)) {
    return 'Use YYYY-MM-DD.';
  }
  return null;
}

String _dateInput(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

String _dateOnly(String value, {required String fallback}) {
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return fallback;
  return _dateInput(parsed);
}

String _initialId(String preferred, Iterable<String> options) {
  final values = options.map((value) => value.trim()).toSet();
  if (values.contains(preferred.trim())) return preferred.trim();
  return values.isEmpty ? '' : values.first;
}

String _classLabel(Map<String, dynamic> row) {
  final label = _text(row['label']);
  if (label.isNotEmpty) return label;
  final grade = _text(row['grade_name'], fallback: _text(row['grade']));
  final section = _text(row['section_name'], fallback: _text(row['name']));
  final combined = [grade, section].where((part) => part.isNotEmpty).join(' ');
  return combined.isEmpty ? 'Assigned class' : combined;
}

String _studentLabel(Map<String, dynamic> row) {
  final name = _text(row['name']);
  if (name.isNotEmpty) return name;
  final first = _text(row['first_name']);
  final last = _text(row['last_name']);
  final combined = '$first $last'.trim();
  return combined.isEmpty ? 'Student' : combined;
}

String _studentName(Map<String, dynamic> row) {
  final student = row['student'];
  if (student is Map) return _studentLabel(Map<String, dynamic>.from(student));
  return _text(row['student_name'], fallback: _text(row['student_id']));
}

String _text(dynamic value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

String _intText(dynamic value) {
  if (value is num) return value.round().toString();
  return int.tryParse(value?.toString() ?? '')?.toString() ?? '0';
}

String _cleanError(Object error) {
  final raw = error.toString();
  final marker = raw.indexOf('message:');
  if (marker >= 0) return raw.substring(marker + 8).trim();
  return raw.replaceFirst('Exception:', '').trim();
}
