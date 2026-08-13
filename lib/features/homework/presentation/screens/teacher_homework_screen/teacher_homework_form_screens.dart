import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/navigation/role_nav_indices.dart';
import 'package:schooldesk1/core/services/role_access_service.dart';
import 'package:schooldesk1/core/utils/event_post_media_parser.dart';
import 'package:schooldesk1/core/widgets/teacher_flow_ui.dart';
import 'package:schooldesk1/core/widgets/subject_card_widget.dart';
import 'package:schooldesk1/core/widgets/event_post_media_preview.dart';
import 'package:schooldesk1/core/utils/extensions.dart';
import 'package:schooldesk1/core/utils/image_upload_optimizer.dart';

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
  final _descriptionController = TextEditingController();
  final _dueDateController = TextEditingController();
  final Set<String> _selectedSubjects = {};
  String _sectionId = '';
  String _studentId = '';
  String _homeworkType = 'Dairy';
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
    // Parse subject(s) — could be comma-separated
    final rawSubject = teacherFlowText(
      homework?['subject'] ?? homework?['subject_id'],
      fallback: _defaultSubject,
    );
    _selectedSubjects.addAll(
      rawSubject.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty),
    );
    if (_selectedSubjects.isEmpty && _defaultSubject.isNotEmpty) {
      _selectedSubjects.add(_defaultSubject);
    }
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
      withData: true,
    );
    final file = result?.files.single;
    final path = file?.path ?? '';
    if (file == null || (path.trim().isEmpty && file.bytes == null)) return;

    setState(() {
      _uploadingAttachment = true;
      _error = null;
    });
    try {
      final mimeType = ImageUploadOptimizer.mimeTypeForFilename(file.name);
      final optimized = ImageUploadOptimizer.isImage(file.name, mimeType)
          ? (file.bytes != null
                ? ImageUploadOptimizer.fromBytes(
                    file.bytes!,
                    filename: file.name,
                    mimeType: mimeType,
                    preset: ImageUploadPreset.content,
                  )
                : await ImageUploadOptimizer.fromPath(
                    path,
                    filename: file.name,
                    mimeType: mimeType,
                    preset: ImageUploadPreset.content,
                  ))
          : null;
      final url = await BackendApiClient.instance.uploadFile(
        path,
        filename: optimized?.filename ?? file.name,
        fileBytes: optimized?.bytes ?? file.bytes,
        mimeType: optimized?.mimeType ?? mimeType,
      );
      if (url.isEmpty) {
        throw Exception('Upload completed but no file URL was returned.');
      }
      if (!mounted) return;
      setState(() {
        _attachmentUrl = url;
        _attachmentName = file.name;
        _uploadingAttachment = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _uploadingAttachment = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (_selectedSubjects.isEmpty) {
      setState(() => _error = 'Please select at least one subject.');
      return;
    }
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
          subject: _selectedSubjects.join(', '),
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
          subject: _selectedSubjects.join(', '),
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
            widget.args.isEditing ? 'Dairy updated' : 'Dairy shared',
          ),
        );
      }
    } on Object catch (error) {
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
        title: widget.args.isEditing ? 'Edit Dairy' : 'Assign Dairy',
        subtitle: 'Loading teacher dairy context',
        selectedIndex: TeacherNav.diary,
        loading: true,
        child: const SizedBox.shrink(),
      );
    }
    if (_missingRequiredContext) {
      return _TeacherModuleEntryError(
        title: widget.args.isEditing ? 'Edit Dairy' : 'Assign Dairy',
        selectedIndex: TeacherNav.diary,
      );
    }

    return TeacherFlowScaffold(
      title: widget.args.isEditing ? 'Edit Dairy' : 'Assign Dairy',
      subtitle: 'Minimal typing flow with class defaults',
      selectedIndex: TeacherNav.diary,
      child: TeacherFlowScrollView(
        children: [
          TeacherCurrentClassCard(
            greeting: 'Dairy details',
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
                      _required(value, 'Enter a dairy title.'),
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
                SubjectCardGrid(
                  label: 'Subjects',
                  subjects: _subjectOptions,
                  selectedSubjects: _selectedSubjects,
                  enabled: !_saving,
                  onToggle: (subject) {
                    setState(() {
                      if (_selectedSubjects.contains(subject)) {
                        _selectedSubjects.remove(subject);
                      } else {
                        _selectedSubjects.add(subject);
                      }
                    });
                  },
                ),
                if (_selectedSubjects.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                      'Please select at least one subject',
                      style: TextStyle(fontSize: 12, color: Colors.red),
                    ),
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
                            'Dairy',
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
                            setState(() => _homeworkType = value ?? 'Dairy'),
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
                    child: Builder(
                      builder: (context) {
                        final rawItem = EventPostMediaItem.fromUrl(
                          _attachmentUrl,
                        );
                        final item = _attachmentName.isNotEmpty
                            ? EventPostMediaItem(
                                url: rawItem.url,
                                name: _attachmentName,
                                kind: rawItem.kind,
                              )
                            : rawItem;
                        return EventPostMediaPreview(
                          item: item,
                          height: 140,
                          compact: true,
                        );
                      },
                    ),
                  ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
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
                        ? 'Save Dairy'
                        : 'Share Dairy',
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
        if (_selectedSubjects.isEmpty ||
            _selectedSubjects.contains('General')) {
          _selectedSubjects.clear();
          if (_defaultSubject.isNotEmpty) {
            _selectedSubjects.add(_defaultSubject);
          }
        }
        _loadingContext = false;
      });
    } on Object catch (error) {
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
      'subject': _selectedSubjects.join(', '),
      'title': 'Dairy assigned',
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

  String get _homeworkId => teacherFlowText(
    widget.args.homework['homework_id'] ?? widget.args.homework['id'],
  );

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
      final payload = await BackendApiClient.instance.getHomeworkSubmissions(
        _homeworkId,
      );
      if (!mounted) return;
      setState(() {
        _submissions = teacherFlowList(
          payload['submissions'] ?? payload['data'],
        );
        _loading = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _review(Map<String, dynamic> submission) async {
    final comment = await _askForFeedback();
    if (comment == null) return;
    final submissionId = teacherFlowText(
      submission['id'] ?? submission['submission_id'],
    );
    if (submissionId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This submission cannot be marked done yet.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    try {
      await BackendApiClient.instance.reviewHomeworkSubmission(
        _homeworkId,
        submissionId,
        status: 'reviewed',
        remarks: comment,
      );
      await _loadSubmissions();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Dairy marked done and feedback sent to parent'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not send review: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<String?> _askForFeedback() {
    return showDialog<String>(
      context: context,
      builder: (ctx) => const _HomeworkFeedbackDialog(),
    );
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
      fallback: 'Dairy',
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
            timeLabel: 'Add feedback before marking done',
          ),
          const SizedBox(height: 18),
          if (_submissions.isEmpty)
            const TeacherFlowCard(
              icon: Icons.inbox_rounded,
              title: 'No submissions yet',
              subtitle: 'Student submissions will appear here.',
            )
          else
            ..._submissions.map((submission) => _submissionCard(submission)),
        ],
      ),
    );
  }

  Widget _submissionCard(Map<String, dynamic> submission) {
    final attachments = _submissionAttachmentUrls(submission);
    final studentName = teacherFlowText(
      submission['student_name'] ?? submission['student_id'],
      fallback: 'Student',
    );
    final rawAnswer = teacherFlowText(
      submission['parent_comment'] ??
          submission['answer_text'] ??
          submission['remarks'],
      fallback: '',
    );
    final teacherFeedback = teacherFlowText(submission['teacher_feedback']);
    final answerText =
        (rawAnswer == teacherFeedback && teacherFeedback.isNotEmpty)
        ? ''
        : rawAnswer;
    final status = teacherFlowText(
      submission['status'],
      fallback: 'submitted',
    ).toLowerCase();
    final submittedRaw = teacherFlowText(
      submission['submitted_at'] ?? submission['created_at'],
    );
    final submittedDate = submittedRaw.isNotEmpty
        ? (() {
            final dt = DateTime.tryParse(submittedRaw);
            if (dt == null) return '';
            final local = dt.toLocal();
            return '${local.day}/${local.month}/${local.year} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
          })()
        : '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TeacherFlowCard(
        icon: Icons.file_present_rounded,
        title: studentName,
        subtitle: answerText.isEmpty ? 'No written answer' : answerText,
        status: status == 'reviewed' ? 'Done' : teacherFlowTitleCase(status),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (submittedDate.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(
                      Icons.access_time_rounded,
                      size: 13,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Submitted: $submittedDate',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            if (attachments.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Attachments (${attachments.length}):',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 6),
              ...attachments.map((url) {
                final item = EventPostMediaItem.fromUrl(url);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: OutlinedButton.icon(
                    onPressed: () => openEventPostMediaPreview(context, item),
                    icon: Icon(
                      item.isPdf
                          ? Icons.picture_as_pdf_rounded
                          : Icons.image_rounded,
                      size: 18,
                    ),
                    label: Text(
                      item.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                );
              }),
            ],
            const SizedBox(height: 4),
            TeacherFlowActionWrap(
              actions: [
                if (status != 'reviewed')
                  TeacherFlowAction(
                    label: 'Done',
                    icon: Icons.check_rounded,
                    filled: true,
                    onTap: () => _review(submission),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<String> _submissionAttachmentUrls(Map<String, dynamic> submission) {
    final urls = <String>[];
    void addUnique(String url) {
      if (url.isNotEmpty && !urls.contains(url)) urls.add(url);
    }

    final single = teacherFlowText(submission['attachment_url']);
    addUnique(single);
    final multi = submission['attachment_urls'];
    if (multi is List) {
      for (final url in multi.map(teacherFlowText)) {
        addUnique(url);
      }
    }
    return urls;
  }
}

class _HomeworkFeedbackDialog extends StatefulWidget {
  const _HomeworkFeedbackDialog();

  @override
  State<_HomeworkFeedbackDialog> createState() =>
      _HomeworkFeedbackDialogState();
}

class _HomeworkFeedbackDialogState extends State<_HomeworkFeedbackDialog> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const accent = Colors.green;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.check_circle_rounded, color: accent, size: 22),
          SizedBox(width: 8),
          Text(
            'Complete Dairy Review',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 320),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Feedback for the parent is required before marking this dairy done.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _controller,
                minLines: 3,
                maxLines: 5,
                autofocus: true,
                decoration: InputDecoration(
                  hintText:
                      'Share clear feedback about the student submission.',
                  errorText: _error,
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: accent),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: accent, width: 1.5),
                  ),
                ),
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final value = _controller.text.trim();
            if (value.isEmpty) {
              setState(() => _error = 'Feedback is required.');
              return;
            }
            Navigator.pop(context, value);
          },
          style: FilledButton.styleFrom(backgroundColor: accent),
          child: const Text('Done & Notify Parent'),
        ),
      ],
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
