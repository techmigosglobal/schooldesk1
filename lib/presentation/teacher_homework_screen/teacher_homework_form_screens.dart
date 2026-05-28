import 'package:flutter/material.dart';

import '../../services/backend_api_client.dart';
import '../../theme/app_theme.dart';
import '../../widgets/teacher_flow_ui.dart';

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
  final _descriptionController = TextEditingController();
  final _dueDateController = TextEditingController();
  String _sectionId = '';
  String _studentId = '';
  String _homeworkType = 'Homework';
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final homework = widget.args.homework;
    _titleController.text = teacherFlowText(homework?['title']);
    _subjectController.text = teacherFlowText(
      homework?['subject'] ?? homework?['subject_id'],
      fallback: widget.args.defaultSubject,
    );
    _descriptionController.text = teacherFlowText(
      homework?['description'] ?? homework?['instructions'],
    );
    _dueDateController.text = teacherFlowDateOnly(
      homework?['submission_date'] ?? homework?['due_date'],
    );
    if (_dueDateController.text.isEmpty) {
      _dueDateController.text = teacherFlowDate(
        DateTime.now().add(const Duration(days: 3)),
      );
    }
    _sectionId = _initialId(
      teacherFlowText(homework?['section_id']),
      _classOptions.map((row) => teacherFlowText(row['id'])),
    );
    _studentId = _initialId(teacherFlowText(homework?['student_id']), [
      '',
      ...widget.args.students.map((row) => teacherFlowText(row['id'])),
    ]);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subjectController.dispose();
    _descriptionController.dispose();
    _dueDateController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _classOptions {
    final rows = widget.args.assignedClasses
        .where((row) => teacherFlowText(row['id']).isNotEmpty)
        .toList();
    if (rows.isNotEmpty) return rows;
    return [
      {'id': '', 'label': widget.args.defaultClassName},
    ];
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (widget.args.teacherStaffId.trim().isEmpty) {
      setState(() => _error = 'Teacher staff profile is missing.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final homeworkId = teacherFlowText(widget.args.homework?['id']);
      if (homeworkId.isEmpty) {
        await BackendApiClient.instance.createHomework(
          title: _titleController.text.trim(),
          subject: _subjectController.text.trim(),
          className: widget.args.defaultClassName,
          sectionId: _sectionId,
          teacherId: widget.args.teacherStaffId,
          description: '$_homeworkType: ${_descriptionController.text.trim()}',
          dueDate: _dueDateController.text.trim(),
          studentId: _studentId,
        );
      } else {
        await BackendApiClient.instance.updateHomework(
          homeworkId,
          title: _titleController.text.trim(),
          subject: _subjectController.text.trim(),
          className: widget.args.defaultClassName,
          sectionId: _sectionId,
          teacherId: widget.args.teacherStaffId,
          description: '$_homeworkType: ${_descriptionController.text.trim()}',
          dueDate: _dueDateController.text.trim(),
          studentId: _studentId,
        );
      }
      if (mounted) {
        Navigator.pop(
          context,
          TeacherHomeworkResult(
            widget.args.isEditing ? 'Homework updated' : 'Homework shared',
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return TeacherFlowScaffold(
      title: widget.args.isEditing ? 'Edit Homework' : 'Assign Homework',
      subtitle: 'Minimal typing flow with class defaults',
      selectedIndex: 3,
      child: TeacherFlowScrollView(
        children: [
          TeacherCurrentClassCard(
            greeting: 'Homework details',
            classLabel: widget.args.defaultClassName,
            subject: widget.args.defaultSubject,
            timeLabel: 'Parents and students are notified after save',
          ),
          const SizedBox(height: 18),
          Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    prefixIcon: Icon(Icons.title_rounded),
                  ),
                  validator: (value) =>
                      _required(value, 'Enter a homework title.'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _sectionId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Class',
                    prefixIcon: Icon(Icons.class_rounded),
                  ),
                  items: _classOptions
                      .map(
                        (row) => DropdownMenuItem(
                          value: teacherFlowText(row['id']),
                          child: Text(_classLabel(row)),
                        ),
                      )
                      .toList(),
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _sectionId = value ?? ''),
                  validator: (value) =>
                      _required(value, 'Select a class section.'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _subjectController,
                  decoration: const InputDecoration(
                    labelText: 'Subject',
                    prefixIcon: Icon(Icons.menu_book_rounded),
                  ),
                  validator: (value) => _required(value, 'Enter subject.'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _homeworkType,
                  decoration: const InputDecoration(
                    labelText: 'Work type',
                    prefixIcon: Icon(Icons.category_rounded),
                  ),
                  items:
                      const [
                            'Homework',
                            'Classwork',
                            'Project',
                            'Revision',
                            'Bring Materials',
                            'Exam Reminder',
                          ]
                          .map(
                            (type) => DropdownMenuItem(
                              value: type,
                              child: Text(type),
                            ),
                          )
                          .toList(),
                  onChanged: _saving
                      ? null
                      : (value) =>
                            setState(() => _homeworkType = value ?? 'Homework'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _studentId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Student scope',
                    prefixIcon: Icon(Icons.groups_rounded),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: '',
                      child: Text('Full class'),
                    ),
                    ...widget.args.students.map(
                      (student) => DropdownMenuItem(
                        value: teacherFlowText(student['id']),
                        child: Text(
                          teacherFlowText(student['name'], fallback: 'Student'),
                        ),
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
                  decoration: const InputDecoration(
                    labelText: 'Due date',
                    hintText: 'YYYY-MM-DD',
                    prefixIcon: Icon(Icons.event_rounded),
                  ),
                  validator: (value) => _required(value, 'Enter due date.'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  minLines: 4,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Instructions',
                    alignLabelWithHint: true,
                    prefixIcon: Icon(Icons.notes_rounded),
                  ),
                  validator: (value) => _required(value, 'Enter instructions.'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: AppTheme.error)),
                ],
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _saving ? null : _submit,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                  label: Text(
                    _saving
                        ? 'Saving...'
                        : widget.args.isEditing
                        ? 'Save Homework'
                        : 'Share Homework',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _initialId(String current, Iterable<String> allowed) {
    if (allowed.contains(current)) return current;
    return allowed.isNotEmpty ? allowed.first : '';
  }

  String? _required(String? value, String message) {
    return (value ?? '').trim().isEmpty ? message : null;
  }

  String _classLabel(Map<String, dynamic> row) {
    final label = teacherFlowText(row['label']);
    if (label.isNotEmpty) return label;
    final grade = teacherFlowText(row['grade_name']);
    final section = teacherFlowText(row['section_name']);
    return [grade, section].where((part) => part.isNotEmpty).join(' ');
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
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _submissions = const [];

  @override
  void initState() {
    super.initState();
    _loadSubmissions();
  }

  Future<void> _loadSubmissions() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final homeworkId = teacherFlowText(widget.args.homework['id']);
      final payload = await BackendApiClient.instance.getHomeworkSubmissions(
        homeworkId,
      );
      if (!mounted) return;
      setState(() {
        _submissions = teacherFlowList(
          payload['submissions'] ?? payload['data'],
        );
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _review(Map<String, dynamic> submission, String status) async {
    final homeworkId = teacherFlowText(widget.args.homework['id']);
    final submissionId = teacherFlowText(submission['id']);
    await BackendApiClient.instance.reviewHomeworkSubmission(
      homeworkId,
      submissionId,
      status: status,
      remarks: status == 'approved' ? 'Reviewed by teacher' : 'Needs revision',
    );
    await _loadSubmissions();
  }

  @override
  Widget build(BuildContext context) {
    final title = teacherFlowText(
      widget.args.homework['title'],
      fallback: 'Homework',
    );
    return TeacherFlowScaffold(
      title: 'Submissions',
      subtitle: title,
      selectedIndex: 3,
      loading: _loading,
      error: _error,
      onRefresh: _loadSubmissions,
      child: TeacherFlowScrollView(
        children: [
          TeacherCurrentClassCard(
            greeting: 'Review queue',
            classLabel: title,
            subject: '${_submissions.length} submissions',
            timeLabel: 'Approve or request revision',
          ),
          const SizedBox(height: 18),
          if (_submissions.isEmpty)
            const TeacherFlowCard(
              icon: Icons.inbox_rounded,
              title: 'No submissions yet',
              subtitle: 'Student submissions will appear here.',
            )
          else
            ..._submissions.map(
              (submission) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TeacherFlowCard(
                  icon: Icons.file_present_rounded,
                  title: teacherFlowText(
                    submission['student_name'] ?? submission['student_id'],
                    fallback: 'Student',
                  ),
                  subtitle: teacherFlowText(
                    submission['answer_text'] ?? submission['remarks'],
                    fallback: 'No answer text',
                  ),
                  status: teacherFlowTitleCase(
                    teacherFlowText(
                      submission['status'],
                      fallback: 'submitted',
                    ),
                  ),
                  body: TeacherFlowActionWrap(
                    actions: [
                      TeacherFlowAction(
                        label: 'Approve',
                        icon: Icons.check_rounded,
                        filled: true,
                        onTap: () => _review(submission, 'approved'),
                      ),
                      TeacherFlowAction(
                        label: 'Needs Revision',
                        icon: Icons.replay_rounded,
                        onTap: () => _review(submission, 'revision_requested'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
