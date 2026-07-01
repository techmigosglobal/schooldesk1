import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/navigation/role_nav_indices.dart';
import 'package:schooldesk1/core/services/notification_service.dart';
import 'package:schooldesk1/core/services/role_access_service.dart';
import 'package:schooldesk1/core/utils/attachment_url_resolver.dart';
import 'package:schooldesk1/core/widgets/teacher_flow_ui.dart';
import 'package:schooldesk1/core/utils/extensions.dart';

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
  String _attachmentUrl = '';
  String _attachmentName = '';
  String _teacherStaffId = '';
  String _defaultClassName = '';
  String _defaultSubject = '';
  List<Map<String, dynamic>> _assignedClasses = const [];
  List<Map<String, dynamic>> _students = const [];
  bool _loadingContext = true;
  bool _uploadingAttachment = false;
  bool _saving = false;
  String? _error;

  bool get _missingRequiredContext =>
      _teacherStaffId.trim().isEmpty || _assignedClasses.isEmpty;

  String get _homeworkRecordId {
    final homework = widget.args.homework;
    return teacherFlowText(homework?['homework_id'] ?? homework?['id']);
  }

  @override
  void initState() {
    super.initState();
    _teacherStaffId = widget.args.teacherStaffId;
    _defaultClassName = widget.args.defaultClassName;
    _defaultSubject = widget.args.defaultSubject;
    _assignedClasses = widget.args.assignedClasses;
    _students = widget.args.students;
    final homework = widget.args.homework;
    _titleController.text = teacherFlowText(homework?['title']);
    _subjectController.text = teacherFlowText(
      homework?['subject'] ?? homework?['subject_id'],
      fallback: _defaultSubject,
    );
    _descriptionController.text = teacherFlowText(
      homework?['description'] ?? homework?['instructions'],
    );
    _attachmentUrl = teacherFlowText(homework?['attachment_url']);
    _attachmentName = _attachmentUrl.split('/').last;
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
      ..._students.map((row) => teacherFlowText(row['id'])),
    ]);
    _loadMissingContext();
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
    final rows = _assignedClasses
        .where((row) => teacherFlowText(row['id']).isNotEmpty)
        .toList();
    if (rows.isNotEmpty) return rows;
    return [
      {'id': '', 'label': _defaultClassName},
    ];
  }

  Future<void> _pickAttachment() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const [
        'pdf',
        'doc',
        'docx',
        'jpg',
        'jpeg',
        'png',
        'webp',
      ],
      withData: false,
    );
    final file = result?.files.single;
    final path = file?.path;
    if (file == null || path == null || path.trim().isEmpty) return;

    setState(() {
      _uploadingAttachment = true;
      _error = null;
    });
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(path, filename: file.name),
      });
      final response = await BackendApiClient.instance.dio.post(
        '/uploads',
        data: formData,
      );
      final data = response.data;
      var url = '';
      if (data is Map) {
        url = teacherFlowText(data['url']);
        final nested = data['data'];
        if (url.isEmpty && nested is Map) {
          url = teacherFlowText(nested['url']);
        }
      }
      if (url.isEmpty) {
        throw Exception('Upload completed but no file URL was returned.');
      }
      if (!mounted) return;
      setState(() {
        _attachmentUrl = url;
        _attachmentName = file.name;
        _uploadingAttachment = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _uploadingAttachment = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (_teacherStaffId.trim().isEmpty) {
      setState(() => _error = 'Teacher staff profile is missing.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final homeworkId = _homeworkRecordId;
      if (homeworkId.isEmpty) {
        await BackendApiClient.instance.createHomework(
          title: _titleController.text.trim(),
          subject: _subjectController.text.trim(),
          className: _selectedClassLabel,
          sectionId: _sectionId,
          teacherId: _teacherStaffId,
          description: '$_homeworkType: ${_descriptionController.text.trim()}',
          dueDate: _dueDateController.text.trim(),
          studentId: _studentId,
          attachmentUrl: _attachmentUrl,
        );
        await _writeDiaryEntry();
      } else {
        await BackendApiClient.instance.updateHomework(
          homeworkId,
          title: _titleController.text.trim(),
          subject: _subjectController.text.trim(),
          className: _selectedClassLabel,
          sectionId: _sectionId,
          teacherId: _teacherStaffId,
          description: '$_homeworkType: ${_descriptionController.text.trim()}',
          dueDate: _dueDateController.text.trim(),
          studentId: _studentId,
          attachmentUrl: _attachmentUrl,
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
    if (_loadingContext) {
      return TeacherFlowScaffold(
        title: widget.args.isEditing ? 'Edit Homework' : 'Assign Homework',
        subtitle: 'Loading teacher homework context',
        selectedIndex: TeacherNav.diary,
        loading: true,
        child: const SizedBox.shrink(),
      );
    }
    if (_missingRequiredContext) {
      return _TeacherModuleEntryError(
        title: widget.args.isEditing ? 'Edit Homework' : 'Assign Homework',
        selectedIndex: TeacherNav.diary,
      );
    }

    return TeacherFlowScaffold(
      title: widget.args.isEditing ? 'Edit Homework' : 'Assign Homework',
      subtitle: 'Minimal typing flow with class defaults',
      selectedIndex: TeacherNav.diary,
      child: TeacherFlowScrollView(
        children: [
          TeacherCurrentClassCard(
            greeting: 'Homework details',
            classLabel: _defaultClassName,
            subject: _defaultSubject,
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
                  onChanged: (_saving || _classOptions.length <= 1)
                      ? null
                      : (value) => setState(() => _sectionId = value ?? ''),
                  validator: (value) =>
                      _required(value, 'Select a class section.'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _subjectOptions.contains(_subjectController.text)
                      ? _subjectController.text
                      : (_subjectOptions.isNotEmpty
                            ? _subjectOptions.first
                            : ''),
                  decoration: const InputDecoration(
                    labelText: 'Subject',
                    prefixIcon: Icon(Icons.menu_book_rounded),
                  ),
                  items: _subjectOptions
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: _saving
                      ? null
                      : (value) => setState(
                          () => _subjectController.text = value ?? '',
                        ),
                  validator: (value) => _required(value, 'Select subject.'),
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
                    ..._students.map(
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
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: (_saving || _uploadingAttachment)
                      ? null
                      : _pickAttachment,
                  icon: _uploadingAttachment
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.attach_file_rounded),
                  label: Text(
                    _attachmentUrl.isEmpty
                        ? 'Pick attachment'
                        : 'Attachment: ${_attachmentName.isEmpty ? 'Uploaded file' : _attachmentName}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_attachmentUrl.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'attachment_url: $_attachmentUrl',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                if (_error != null) ...[
                  SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(color: context.appTheme.error),
                  ),
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

  String get _selectedClassLabel {
    final match = _classOptions.where(
      (row) => teacherFlowText(row['id']) == _sectionId,
    );
    if (match.isNotEmpty) return _classLabel(match.first);
    return _defaultClassName;
  }

  List<String> get _subjectOptions {
    final match = _classOptions.where(
      (row) => teacherFlowText(row['id']) == _sectionId,
    );
    if (match.isEmpty) return [_defaultSubject];

    final row = match.first;
    final subjects = row['subjects'];
    if (subjects is List && subjects.isNotEmpty) {
      final list = subjects
          .map((e) {
            if (e is Map) {
              return teacherFlowText(
                e['subject_name'] ?? e['name'] ?? e['subject_id'] ?? e['id'],
              );
            }
            return teacherFlowText(e);
          })
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList();
      if (list.isNotEmpty) return list;
    }
    return [_defaultSubject];
  }

  Future<void> _loadMissingContext() async {
    try {
      await RoleAccessService.initialize();
      final classTeacherClasses = RoleAccessService.teacherClassTeacherClasses;
      final assignedClasses = classTeacherClasses.isNotEmpty
          ? classTeacherClasses
          : RoleAccessService.teacherAssignedClasses;
      if (!mounted) return;
      setState(() {
        _teacherStaffId = _teacherStaffId.isEmpty
            ? RoleAccessService.teacherStaffId
            : _teacherStaffId;
        _defaultClassName =
            _defaultClassName == 'Not assigned' || _defaultClassName.isEmpty
            ? RoleAccessService.teacherClassName
            : _defaultClassName;
        _defaultSubject =
            _defaultSubject == 'General' || _defaultSubject.isEmpty
            ? RoleAccessService.teacherSubject
            : _defaultSubject;
        _assignedClasses = _assignedClasses.isEmpty
            ? assignedClasses
            : _assignedClasses;
        _students = _students.isEmpty
            ? RoleAccessService.teacherClassStudents
            : _students;
        _sectionId = _initialId(
          _sectionId,
          _classOptions.map((row) => teacherFlowText(row['id'])),
        );
        _studentId = _initialId(
          teacherFlowText(widget.args.homework?['student_id']),
          ['', ..._students.map((row) => teacherFlowText(row['id']))],
        );
        if (_subjectController.text.trim().isEmpty ||
            _subjectController.text == 'General') {
          _subjectController.text = _defaultSubject;
        }
        _loadingContext = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingContext = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _writeDiaryEntry() async {
    await BackendApiClient.instance.createRaw('/diary-entries', {
      'section_id': _sectionId,
      'teacher_id': _teacherStaffId,
      'staff_id': _teacherStaffId,
      'date': DateTime.now().toUtc().toIso8601String(),
      'entry_date': teacherFlowDate(DateTime.now()),
      'entry_type': 'homework',
      'type': 'homework',
      'class': _selectedClassLabel,
      'subject': _subjectController.text.trim(),
      'title': 'Homework assigned',
      'homework': _descriptionController.text.trim(),
      'notes':
          'Due ${_dueDateController.text.trim()} · ${_studentId.isEmpty ? 'Full class' : 'Individual student'}',
      'content':
          '$_homeworkType: ${_descriptionController.text.trim()}\nDue: ${_dueDateController.text.trim()}',
      'created_by': 'Teacher',
    });
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
    if (_homeworkId.isEmpty) {
      _loading = false;
      _error = 'Please open this screen from the related Teacher module.';
    } else {
      _loadSubmissions();
    }
  }

  Future<void> _loadSubmissions() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final homeworkId = _homeworkId;
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
    final comment = await _askForFeedback(
      defaultComment: status == 'approved'
          ? 'Reviewed by teacher'
          : 'Needs revision',
    );
    if (comment == null) return;
    final homeworkId = _homeworkId;
    final submissionId = teacherFlowText(
      submission['id'] ?? submission['submission_id'],
    );
    await BackendApiClient.instance.reviewHomeworkSubmission(
      homeworkId,
      submissionId,
      status: status,
      remarks: comment,
    );
    final notificationService = await NotificationService.getInstance();
    await notificationService.triggerHomeworkFeedbackAlert(
      homeworkId: homeworkId,
      homeworkTitle: teacherFlowText(
        widget.args.homework['title'],
        fallback: 'Homework',
      ),
      comment: comment,
      studentId: teacherFlowText(submission['student_id']),
    );
    await _loadSubmissions();
  }

  Future<String?> _askForFeedback({required String defaultComment}) {
    final controller = TextEditingController(text: defaultComment);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Homework Feedback'),
        content: TextField(
          controller: controller,
          minLines: 3,
          maxLines: 5,
          decoration: const InputDecoration(
            labelText: 'Comment for parent',
            alignLabelWithHint: true,
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              Navigator.pop(
                context,
                value.isEmpty ? defaultComment : value,
              );
            },
            child: const Text('Send Feedback'),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  @override
  Widget build(BuildContext context) {
    if (_homeworkId.isEmpty) {
      return const _TeacherModuleEntryError(
        title: 'Submissions',
        selectedIndex: TeacherNav.diary,
      );
    }

    final title = teacherFlowText(
      widget.args.homework['title'],
      fallback: 'Homework',
    );
    return TeacherFlowScaffold(
      title: 'Submissions',
      subtitle: title,
      selectedIndex: TeacherNav.diary,
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
                  body: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if ('${submission['attachment_url'] ?? submission['attachmentUrl'] ?? ''}'
                          .isNotEmpty) ...[
                        OutlinedButton.icon(
                          onPressed: () => _openSubmissionAttachment(
                            '${submission['attachment_url'] ?? submission['attachmentUrl']}',
                          ),
                          icon: const Icon(Icons.attach_file_rounded, size: 14),
                          label: const Text('View Submitted Attachment'),
                        ),
                        const SizedBox(height: 10),
                      ],
                      TeacherFlowActionWrap(
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
                            onTap: () =>
                                _review(submission, 'revision_requested'),
                          ),
                        ],
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

  Future<void> _openSubmissionAttachment(String attachment) async {
    final uri = resolveAttachmentUrl(attachment);
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Attachment is not available.')),
      );
      return;
    }
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open attachment.')),
      );
    }
  }

  String get _homeworkId {
    return teacherFlowText(
      widget.args.homework['id'] ?? widget.args.homework['homework_id'],
    );
  }
}

class _TeacherModuleEntryError extends StatelessWidget {
  final String title;
  final int selectedIndex;

  const _TeacherModuleEntryError({
    required this.title,
    required this.selectedIndex,
  });

  @override
  Widget build(BuildContext context) {
    return TeacherFlowScaffold(
      title: title,
      subtitle: 'Teacher module context required',
      selectedIndex: selectedIndex,
      child: TeacherFlowScrollView(
        children: [
          TeacherFlowCard(
            icon: Icons.info_outline_rounded,
            title: 'Open from Teacher module',
            subtitle:
                'Please open this screen from the related Teacher module.',
            body: TeacherFlowActionWrap(
              actions: [
                TeacherFlowAction(
                  label: 'Back',
                  icon: Icons.arrow_back_rounded,
                  onTap: () => Navigator.maybePop(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
