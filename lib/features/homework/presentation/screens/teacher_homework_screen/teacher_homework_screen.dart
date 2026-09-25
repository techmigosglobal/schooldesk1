import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import 'package:schooldesk1/routes/app_routes.dart';
import 'package:schooldesk1/core/navigation/role_nav_indices.dart';
import 'package:schooldesk1/core/services/role_access_service.dart';
import 'package:schooldesk1/core/widgets/teacher_flow_ui.dart';
import 'package:schooldesk1/core/widgets/subject_card_widget.dart';
import 'package:schooldesk1/features/homework/presentation/screens/teacher_homework_screen/teacher_homework_form_screens.dart';
import 'package:schooldesk1/core/utils/extensions.dart';
import 'package:schooldesk1/core/utils/image_upload_optimizer.dart';
import 'package:schooldesk1/roles/teacher/data/api_teacher_homework_repository.dart';
import 'package:schooldesk1/roles/teacher/domain/teacher_homework_repository.dart';

import 'package:schooldesk1/core/navigation/schooldesk_navigation.dart';
import 'package:schooldesk1/core/repositories/repository_state.dart';
import 'package:schooldesk1/core/widgets/repository_state_view.dart';

class TeacherHomeworkScreen extends StatefulWidget {
  final TeacherHomeworkRepository? repository;

  const TeacherHomeworkScreen({super.key, this.repository});

  @override
  State<TeacherHomeworkScreen> createState() => _TeacherHomeworkScreenState();
}

class _TeacherHomeworkScreenState extends State<TeacherHomeworkScreen>
    with SingleTickerProviderStateMixin {
  TeacherHomeworkRepository get _repository =>
      widget.repository ?? ApiTeacherHomeworkRepository.legacyDefault;

  late final TabController _tabController;

  RepositoryState<Object> _state = const RepositoryState.loading();
  List<Map<String, dynamic>> _homework = const [];
  Map<String, int> _submissionCounts = const {};
  bool _skippedToday = false;
  String _reminderStatus = 'pending';
  String _selectedSectionId = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadHomework();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadHomework({bool forceRefresh = false}) async {
    final previous = _state.data;
    setState(() {
      _state = RepositoryState.loading(
        data: previous,
        source: previous == null
            ? RepositorySource.empty
            : RepositorySource.cache,
        isStale: previous != null,
        isRefreshing: previous != null,
      );
    });
    try {
      await RoleAccessService.initialize();
      if (_selectedSectionId.isEmpty) {
        final assigned = RoleAccessService.assignedTeacherClasses;
        _selectedSectionId = assigned.isNotEmpty
            ? teacherFlowText(
                assigned.first['section_id'] ?? assigned.first['id'],
              )
            : RoleAccessService.teacherClassId;
      }
      final homeworkResult = await _repository.loadHomework(
        sectionId: _selectedSectionId,
      );
      if (homeworkResult.isFailure) {
        throw StateError(
          homeworkResult.failureOrNull?.message ?? 'Unable to load Dairy',
        );
      }
      final rows = homeworkResult.dataOrNull!;
      final reminder = await _loadReminderStatus();
      final counts = <String, int>{};
      for (final row in rows.take(12)) {
        final id = _homeworkId(row);
        if (id.isEmpty) continue;
        try {
          final submissionsResult = await _repository.loadSubmissions(id);
          if (submissionsResult.isFailure) continue;
          final submissions = submissionsResult.dataOrNull!;
          counts[id] = teacherFlowList(
            submissions['submissions'] ?? submissions['data'],
          ).length;
        } on Object {
          // Submission counts are supplementary. Keep legacy assignments
          // visible when one submission record cannot be read.
          counts[id] = 0;
        }
      }
      if (!mounted) return;
      setState(() {
        _homework = rows;
        _submissionCounts = counts;
        _reminderStatus = teacherFlowText(
          reminder['status'],
          fallback: _isHomeworkSubmittedTodayFromRows(rows)
              ? 'assigned'
              : 'pending',
        ).toLowerCase();
        _skippedToday = _reminderStatus == 'skipped';
        _state = const RepositoryState(
          data: Object(),
          source: RepositorySource.remote,
        );
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _state = previous == null
            ? RepositoryState.error(error: error)
            : RepositoryState(
                data: previous,
                source: RepositorySource.cache,
                isStale: true,
                error: error,
              );
      });
    }
  }

  Future<Map<String, dynamic>> _loadReminderStatus() async {
    try {
      final result = await _repository.loadReminderStatus(
        sectionId: _selectedSectionId,
      );
      return result.dataOrNull ?? const {};
    } on Object catch (_) {
      return const {};
    }
  }

  Future<void> _skipToday() async {
    try {
      final result = await _repository.skipReminder(
        sectionId: _selectedSectionId,
        reason: 'Teacher skipped homework assignment for today',
      );
      if (result.isFailure) {
        throw StateError(
          result.failureOrNull?.message ?? 'Unable to skip Dairy reminder',
        );
      }
      final reminder = result.dataOrNull!;
      if (!mounted) return;
      setState(() {
        _reminderStatus = teacherFlowText(
          reminder['status'],
          fallback: 'skipped',
        ).toLowerCase();
        _skippedToday = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dairy reminder skipped for today')),
      );
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to skip homework reminder: $error')),
      );
    }
  }

  Future<void> _openSubmissions(Map<String, dynamic> homework) async {
    await SchoolDeskNavigation.push(
      context,
      AppRoutes.teacherHomeworkSubmissions,
      arguments: TeacherHomeworkSubmissionsArgs(homework: homework),
    );
    await _loadHomework(forceRefresh: true);
  }

  Future<void> _deleteHomework(Map<String, dynamic> row) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Dairy'),
        content: Text(
          'Are you sure you want to delete "${teacherFlowText(row['title'], fallback: 'Dairy')}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: context.appTheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final id = _homeworkId(row);
      if (id.isEmpty) {
        throw Exception('Dairy record is missing its server id.');
      }
      final result = await _repository.deleteHomework(id);
      if (result.isFailure) {
        throw StateError(
          result.failureOrNull?.message ?? 'Unable to delete Dairy',
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dairy deleted successfully')),
      );
      await _loadHomework(forceRefresh: true);
    } on Object catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return TeacherFlowScaffold(
      title: 'Dairy / Assignments',
      subtitle: 'Assignments, dairy sharing, and submission review',
      selectedIndex: TeacherNav.diary,
      loading: _state.isLoading && !_state.hasData,
      error: _state.hasData ? null : _state.error?.toString(),
      onRefresh: _loadHomework,
      child: SchoolDeskRepositoryStateView<Object>(
        state: _state,
        onRetry: _loadHomework,
        data: (_) => Column(
          children: [
            // ── Tab Bar ──────────────────────────────────────────────
            Container(
              color: Colors.white,
              child: TabBar(
                controller: _tabController,
                labelColor: teacherFlowAccent,
                unselectedLabelColor: teacherFlowMuted,
                indicatorColor: teacherFlowAccent,
                indicatorWeight: 3,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
                tabs: [
                  const Tab(
                    icon: Icon(Icons.add_task_rounded, size: 20),
                    text: 'Assign Dairy',
                  ),
                  Tab(
                    icon: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(Icons.rate_review_rounded, size: 20),
                        if (_totalSubmissions > 0)
                          Positioned(
                            top: -4,
                            right: -6,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                color: Colors.orange,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '$_totalSubmissions',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    text: 'Review',
                  ),
                ],
              ),
            ),
            // ── Tab Views ────────────────────────────────────────────
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _AssignHomeworkTab(
                    homework: _homework,
                    submissionCounts: _submissionCounts,
                    skippedToday: _skippedToday,
                    isHomeworkAssignedToday: _isHomeworkSubmittedToday(),
                    dailyLockedByOther: _isHomeworkClaimedByOther(),
                    onSkipToday: _skipToday,
                    onSectionChanged: (sectionId) {
                      setState(() => _selectedSectionId = sectionId);
                    },
                    onDelete: _deleteHomework,
                    isDueSoon: _isDueSoon,
                    homeworkId: _homeworkId,
                    repository: _repository,
                    onHomeworkCreated: () => _loadHomework(forceRefresh: true),
                  ),
                  _ReviewTab(
                    homework: _homework,
                    submissionCounts: _submissionCounts,
                    onOpenSubmissions: _openSubmissions,
                    isDueSoon: _isDueSoon,
                    homeworkId: _homeworkId,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  int get _totalSubmissions =>
      _submissionCounts.values.fold<int>(0, (a, b) => a + b);

  bool _isDueSoon(Map<String, dynamic> row) {
    final due = DateTime.tryParse(
      teacherFlowDateOnly(row['submission_date'] ?? row['due_date']),
    );
    if (due == null) return false;
    final now = DateTime.now();
    return due.difference(DateTime(now.year, now.month, now.day)).inDays <= 2;
  }

  String _homeworkId(Map<String, dynamic> row) =>
      teacherFlowText(row['homework_id'] ?? row['id']);

  bool _isHomeworkSubmittedToday() {
    if (_reminderStatus == 'assigned') return true;
    if (_reminderStatus == 'skipped') return false;
    return _isHomeworkSubmittedTodayFromRows(_homework);
  }

  bool _isHomeworkSubmittedTodayFromRows(List<Map<String, dynamic>> rows) {
    final today = DateTime.now();
    for (final row in rows) {
      final dateStr =
          row['created_at'] ?? row['homework_date'] ?? row['due_date'];
      final date = DateTime.tryParse(teacherFlowDateOnly(dateStr));
      if (date != null &&
          date.year == today.year &&
          date.month == today.month &&
          date.day == today.day) {
        return true;
      }
    }
    return false;
  }

  bool _isHomeworkClaimedByOther() {
    final staffId = RoleAccessService.teacherStaffId;
    final assignedSectionIds = RoleAccessService.assignedTeacherClasses
        .map((row) => teacherFlowText(row['section_id'] ?? row['id']))
        .where((id) => id.isNotEmpty)
        .toSet();
    final today = DateTime.now();
    return _homework.any((row) {
      if (teacherFlowText(row['section_id']) != _selectedSectionId ||
          !assignedSectionIds.contains(_selectedSectionId)) {
        return false;
      }
      final claim = row['daily_claim'];
      if (claim is! Map) return false;
      final date = DateTime.tryParse(
        teacherFlowDateOnly(row['assigned_date'] ?? row['created_at']),
      );
      return date != null &&
          date.year == today.year &&
          date.month == today.month &&
          date.day == today.day &&
          teacherFlowText(claim['status']) == 'claimed' &&
          teacherFlowText(claim['claimed_by_staff_id']) != staffId;
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 1: Assign Homework (inline form)
// ─────────────────────────────────────────────────────────────────────────────
class _AssignHomeworkTab extends StatefulWidget {
  final List<Map<String, dynamic>> homework;
  final Map<String, int> submissionCounts;
  final bool skippedToday;
  final bool isHomeworkAssignedToday;
  final bool dailyLockedByOther;
  final VoidCallback onSkipToday;
  final ValueChanged<String> onSectionChanged;
  final void Function(Map<String, dynamic>) onDelete;
  final bool Function(Map<String, dynamic>) isDueSoon;
  final String Function(Map<String, dynamic>) homeworkId;
  final TeacherHomeworkRepository repository;
  final VoidCallback onHomeworkCreated;

  const _AssignHomeworkTab({
    required this.homework,
    required this.submissionCounts,
    required this.skippedToday,
    required this.isHomeworkAssignedToday,
    required this.dailyLockedByOther,
    required this.onSkipToday,
    required this.onSectionChanged,
    required this.onDelete,
    required this.isDueSoon,
    required this.homeworkId,
    required this.repository,
    required this.onHomeworkCreated,
  });

  @override
  State<_AssignHomeworkTab> createState() => _AssignHomeworkTabState();
}

class _AssignHomeworkTabState extends State<_AssignHomeworkTab> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _dueDateController = TextEditingController();

  final Set<String> _selectedSubjects = {};
  String _homeworkType = 'Dairy';
  bool _saving = false;
  bool _uploading = false;
  String? _formError;
  String _selectedSectionId = '';

  // Attachments: can be multiple files (images or PDFs)
  final List<_AttachmentItem> _attachments = [];

  static const List<String> _workTypes = [
    'Dairy',
    'Classwork',
    'Project',
    'Revision',
    'Bring Materials',
    'Exam Reminder',
  ];

  List<String> get _subjectOptions {
    final classes = RoleAccessService.teacherAssignedClasses;
    final targetClassId = _selectedSectionId.isNotEmpty
        ? _selectedSectionId
        : RoleAccessService.teacherClassId;
    if (classes.isNotEmpty) {
      final row = classes.firstWhere(
        (c) => teacherFlowText(c['section_id'] ?? c['id']) == targetClassId,
        orElse: () => classes.first,
      );
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
    }
    final def = RoleAccessService.teacherSubject;
    return def.isNotEmpty ? [def] : ['General'];
  }

  @override
  void initState() {
    super.initState();
    // Default due date: 3 days from now
    _dueDateController.text = teacherFlowDate(
      DateTime.now().add(const Duration(days: 3)),
    );
    // Default subject — pre-select first
    final opts = _subjectOptions;
    if (opts.isNotEmpty) _selectedSubjects.add(opts.first);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _dueDateController.dispose();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
    );
    if (result.isEmpty) return;

    for (final file in result) {
      final path = file.path ?? '';
      final fileBytes = await file.readAsBytes();
      final mimeType = ImageUploadOptimizer.mimeTypeForFilename(file.name);
      final isImage = ImageUploadOptimizer.isImage(file.name, mimeType);
      final optimized = isImage
          ? (fileBytes.isNotEmpty
                ? ImageUploadOptimizer.fromBytes(
                    fileBytes,
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
      if (path.trim().isEmpty && fileBytes.isEmpty) continue;
      await _uploadFile(
        path,
        optimized?.filename ?? file.name,
        fileBytes: optimized?.bytes ?? fileBytes,
        mimeType: optimized?.mimeType ?? mimeType,
      );
    }
  }

  Future<void> _uploadFile(
    String path,
    String name, {
    Uint8List? fileBytes,
    String? mimeType,
  }) async {
    setState(() {
      _uploading = true;
      _formError = null;
    });
    try {
      final result = await widget.repository.uploadFile(
        path,
        filename: name,
        fileBytes: fileBytes,
        mimeType: mimeType,
      );
      if (result.isFailure) {
        throw StateError(result.failureOrNull?.message ?? 'Unable to upload');
      }
      final url = result.dataOrNull!;
      if (url.isEmpty) throw Exception('Upload completed but no URL returned.');
      if (!mounted) return;
      setState(() {
        _attachments.add(_AttachmentItem(name: name, url: url));
        _uploading = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _formError = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _removeAttachment(int index) {
    setState(() => _attachments.removeAt(index));
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (_selectedSubjects.isEmpty) {
      setState(() => _formError = 'Please select at least one subject.');
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _formError = null;
    });
    try {
      await RoleAccessService.initialize();
      final staffId = RoleAccessService.teacherStaffId;
      final sectionId = _selectedSectionId.isNotEmpty
          ? _selectedSectionId
          : RoleAccessService.teacherClassId;
      final className = _classLabelForSection(sectionId);
      final attachmentUrl = _attachments.map((a) => a.url).join(',');
      final saveAsDraft = widget.repository.isOffline;

      final result = await widget.repository.createHomework(
        title: _titleController.text.trim(),
        subject: _selectedSubjects.join(', '),
        className: className,
        sectionId: sectionId,
        teacherId: staffId,
        description: '$_homeworkType: ${_descriptionController.text.trim()}',
        dueDate: _dueDateController.text.trim(),
        studentId: '',
        status: saveAsDraft ? 'draft' : 'pending',
        attachmentUrl: attachmentUrl,
      );
      if (result.isFailure) {
        throw StateError(
          result.failureOrNull?.message ?? 'Unable to save Dairy',
        );
      }
      if (!mounted) return;
      // Reset form
      _titleController.clear();
      _descriptionController.clear();
      _attachments.clear();
      _dueDateController.text = teacherFlowDate(
        DateTime.now().add(const Duration(days: 3)),
      );
      setState(() {
        _saving = false;
        _homeworkType = 'Dairy';
        _selectedSubjects.clear();
        final opts = _subjectOptions;
        if (opts.isNotEmpty) _selectedSubjects.add(opts.first);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            saveAsDraft
                ? '✅ Dairy saved offline as a draft and queued for sync.'
                : '✅ Dairy assigned successfully!',
          ),
          backgroundColor: const Color(0xFF0F9F8E),
        ),
      );
      widget.onHomeworkCreated();
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _formError = error.toString();
      });
    }
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 3)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _dueDateController.text = teacherFlowDate(picked);
      });
    }
  }

  String _classLabelForSection(String sectionId) {
    final rows = RoleAccessService.assignedTeacherClasses;
    for (final row in rows) {
      if (teacherFlowText(row['section_id'] ?? row['id']) == sectionId) {
        return teacherFlowText(
          row['label'] ?? row['section_name'],
          fallback: RoleAccessService.teacherClassName,
        );
      }
    }
    return RoleAccessService.teacherClassName;
  }

  @override
  Widget build(BuildContext context) {
    final subjects = _subjectOptions;
    final assignedSections = RoleAccessService.assignedTeacherClasses;
    final selectedSectionId = _selectedSectionId.isNotEmpty
        ? _selectedSectionId
        : RoleAccessService.teacherClassId;

    return TeacherFlowScrollView(
      children: [
        // ── Class Info ───────────────────────────────────────────
        TeacherCurrentClassCard(
          greeting: 'Assign Dairy',
          classLabel: _classLabelForSection(selectedSectionId),
          subject: subjects.join(', '),
          timeLabel: 'Create dairy for your class',
          actions: const [],
        ),
        if (assignedSections.length > 1) ...[
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: selectedSectionId.isEmpty ? null : selectedSectionId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Class / Section',
              prefixIcon: Icon(Icons.class_rounded),
            ),
            items: assignedSections
                .map(
                  (row) => DropdownMenuItem<String>(
                    value: teacherFlowText(row['section_id'] ?? row['id']),
                    child: Text(
                      teacherFlowText(
                        row['label'] ?? row['section_name'],
                        fallback: 'Class / Section',
                      ),
                    ),
                  ),
                )
                .where((item) => item.value?.isNotEmpty == true)
                .toList(),
            onChanged: widget.dailyLockedByOther
                ? null
                : (value) {
                    if (value == null || value == _selectedSectionId) return;
                    setState(() {
                      _selectedSectionId = value;
                      _selectedSubjects
                        ..clear()
                        ..add(_subjectOptions.first);
                    });
                    widget.onSectionChanged(value);
                  },
          ),
        ],

        // ── Pending reminder banner ──────────────────────────────
        if (!widget.isHomeworkAssignedToday && !widget.skippedToday)
          Padding(
            padding: const EdgeInsets.only(top: 18),
            child: TeacherFlowCard(
              icon: Icons.notification_important_rounded,
              title: 'Dairy Pending for Today',
              subtitle: 'You have not assigned dairy yet.',
              status: 'Action required',
              statusColor: Colors.orange,
              body: TeacherFlowActionWrap(
                actions: [
                  TeacherFlowAction(
                    label: 'Skip Today',
                    icon: Icons.close_rounded,
                    onTap: widget.onSkipToday,
                  ),
                ],
              ),
            ),
          ),

        const SizedBox(height: 20),

        // ── Inline Assignment Form ───────────────────────────────
        if (widget.dailyLockedByOther)
          const TeacherFlowCard(
            icon: Icons.lock_rounded,
            title: 'Dairy locked for today',
            subtitle:
                'The other assigned teacher has already shared today\'s dairy. A principal must reopen it before changes are allowed.',
            status: 'Read only',
            statusColor: Colors.orange,
          ),
        if (widget.dailyLockedByOther) const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F9F8E).withOpacity(0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3FAF5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.add_task_rounded,
                        color: Color(0xFF0F9F8E),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'New Assignment',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF183037),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Subject Cards ──────────────────────────────
                SubjectCardGrid(
                  label: 'Subjects',
                  subjects: subjects,
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
                const SizedBox(height: 16),

                // ── Homework Type ─────────────────────────────────
                const _FormLabel(label: 'Type', icon: Icons.category_rounded),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _homeworkType,
                  isExpanded: true,
                  decoration: _inputDecoration(hint: 'Select type'),
                  items: _workTypes
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: _saving
                      ? null
                      : (v) => setState(() => _homeworkType = v ?? 'Dairy'),
                ),
                const SizedBox(height: 16),

                // ── Title ─────────────────────────────────────────
                const _FormLabel(label: 'Title', icon: Icons.title_rounded),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _titleController,
                  enabled: !_saving,
                  decoration: _inputDecoration(hint: 'e.g. Chapter 5 Exercise'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Enter a title' : null,
                ),
                const SizedBox(height: 16),

                // ── Instructions ──────────────────────────────────
                const _FormLabel(
                  label: 'Instructions / Description',
                  icon: Icons.notes_rounded,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _descriptionController,
                  enabled: !_saving,
                  minLines: 4,
                  maxLines: 8,
                  decoration: _inputDecoration(
                    hint: 'Write what students need to do...',
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Enter instructions'
                      : null,
                ),
                const SizedBox(height: 16),

                // ── Due Date ──────────────────────────────────────
                const _FormLabel(label: 'Due Date', icon: Icons.event_rounded),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _dueDateController,
                  enabled: !_saving,
                  readOnly: true,
                  onTap: _pickDueDate,
                  decoration: _inputDecoration(hint: 'Tap to pick due date')
                      .copyWith(
                        suffixIcon: const Icon(
                          Icons.calendar_today_rounded,
                          size: 18,
                        ),
                      ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Pick a due date'
                      : null,
                ),
                const SizedBox(height: 20),

                // ── Attachments ───────────────────────────────────
                const _FormLabel(
                  label: 'Attachments (Images / PDF)',
                  icon: Icons.attach_file_rounded,
                ),
                const SizedBox(height: 8),

                // Attachment list
                if (_attachments.isNotEmpty) ...[
                  ...List.generate(_attachments.length, (i) {
                    final att = _attachments[i];
                    final isPdf = att.name.toLowerCase().endsWith('.pdf');
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4FAFB),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFD0EDEA)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isPdf
                                ? Icons.picture_as_pdf_rounded
                                : Icons.image_rounded,
                            color: isPdf ? Colors.red : const Color(0xFF0F9F8E),
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              att.name,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF183037),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            onPressed: _saving
                                ? null
                                : () => _removeAttachment(i),
                            icon: const Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: Colors.red,
                            ),
                            tooltip: 'Remove',
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                ],

                // Pick files button
                OutlinedButton.icon(
                  onPressed: (_saving || _uploading) ? null : _pickFiles,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0F9F8E),
                    side: const BorderSide(color: Color(0xFF0F9F8E)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: _uploading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF0F9F8E),
                          ),
                        )
                      : const Icon(Icons.upload_file_rounded),
                  label: Text(
                    _uploading ? 'Uploading...' : 'Attach Image or PDF',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),

                // Error message
                if (_formError != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline_rounded,
                          color: Colors.red.shade600,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _formError!,
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 20),

                // ── Submit Button ─────────────────────────────────
                FilledButton.icon(
                  onPressed:
                      (_saving || _uploading || widget.dailyLockedByOther)
                      ? null
                      : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0F9F8E),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded),
                  label: Text(
                    _saving ? 'Assigning...' : 'Assign Dairy',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        // ── Previous Homework List ───────────────────────────────
        const TeacherFlowSectionHeader(title: 'Previously Assigned'),
        const SizedBox(height: 10),
        if (widget.homework.isEmpty)
          const TeacherFlowCard(
            icon: Icons.assignment_late_rounded,
            title: 'No dairy yet',
            subtitle: 'Assignments you create appear here.',
          )
        else
          ...widget.homework.map((row) {
            final title = teacherFlowText(row['title'], fallback: 'Dairy');
            final subject = teacherFlowText(
              row['subject'] ?? row['subject_id'],
              fallback: RoleAccessService.teacherSubject,
            );
            final due = teacherFlowDateOnly(
              row['submission_date'] ?? row['due_date'],
            );
            final createdRaw = teacherFlowText(row['created_at']);
            final createdDate = teacherFlowDateOnly(createdRaw);
            final createdTime = teacherFlowTimeOnly(createdRaw);
            final attachmentsRaw = teacherFlowText(row['attachment_url']);
            final attachments = attachmentsRaw.isNotEmpty
                ? attachmentsRaw.split(',')
                : <String>[];

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TeacherFlowCard(
                icon: Icons.assignment_rounded,
                title: title,
                subtitle: teacherFlowText(
                  row['description'] ?? row['instructions'],
                  fallback: subject,
                ),
                status: due.isEmpty ? 'Open' : 'Due $due',
                statusColor: widget.isDueSoon(row)
                    ? Colors.orange
                    : teacherFlowAccent,
                body: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (createdRaw.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.access_time_rounded,
                              size: 14,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Assigned: $createdDate at $createdTime',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (attachments.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: attachments.map((url) {
                            final isPdf = url.toLowerCase().contains('.pdf');
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isPdf
                                        ? Icons.picture_as_pdf_rounded
                                        : Icons.image_rounded,
                                    size: 14,
                                    color: isPdf
                                        ? Colors.red
                                        : teacherFlowAccent,
                                  ),
                                  const SizedBox(width: 4),
                                  const Text(
                                    'Attachment',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    TeacherFlowActionWrap(
                      actions: [
                        TeacherFlowAction(
                          label: 'Delete',
                          icon: Icons.delete_rounded,
                          onTap: () => widget.onDelete(row),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  InputDecoration _inputDecoration({required String hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF9DB5BC), fontSize: 14),
      filled: true,
      fillColor: const Color(0xFFF4FAFB),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFD0EDEA)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFD0EDEA)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF0F9F8E), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.red),
      ),
    );
  }
}

class _FormLabel extends StatelessWidget {
  final String label;
  final IconData icon;

  const _FormLabel({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF0F9F8E)),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF183037),
          ),
        ),
      ],
    );
  }
}

class _AttachmentItem {
  final String name;
  final String url;

  const _AttachmentItem({required this.name, required this.url});
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 2: Review
// ─────────────────────────────────────────────────────────────────────────────
class _ReviewTab extends StatelessWidget {
  final List<Map<String, dynamic>> homework;
  final Map<String, int> submissionCounts;
  final void Function(Map<String, dynamic>) onOpenSubmissions;
  final bool Function(Map<String, dynamic>) isDueSoon;
  final String Function(Map<String, dynamic>) homeworkId;

  const _ReviewTab({
    required this.homework,
    required this.submissionCounts,
    required this.onOpenSubmissions,
    required this.isDueSoon,
    required this.homeworkId,
  });

  int get _totalSubmissions =>
      submissionCounts.values.fold<int>(0, (a, b) => a + b);

  @override
  Widget build(BuildContext context) {
    return TeacherFlowScrollView(
      children: [
        TeacherCurrentClassCard(
          greeting: 'Review Submissions',
          classLabel: RoleAccessService.teacherClassName,
          subject: RoleAccessService.teacherSubject,
          timeLabel: 'Grade and review student dairy submissions',
          actions: const [],
        ),
        const SizedBox(height: 18),
        TeacherFlowMetricGrid(
          metrics: [
            TeacherFlowMetric(
              label: 'Total Submissions',
              value: '$_totalSubmissions',
              icon: Icons.upload_file_rounded,
              color: Colors.indigo,
              tone: const Color(0xFFEAF0FF),
            ),
            TeacherFlowMetric(
              label: 'Dairy Items',
              value: '${homework.length}',
              icon: Icons.assignment_rounded,
              color: teacherFlowAccent,
              tone: const Color(0xFFE3FAF5),
            ),
          ],
        ),
        const SizedBox(height: 18),
        const TeacherFlowSectionHeader(title: 'Dairy to Review'),
        const SizedBox(height: 10),
        if (homework.isEmpty)
          const TeacherFlowCard(
            icon: Icons.rate_review_rounded,
            title: 'No submissions yet',
            subtitle:
                'Student submissions will appear here once dairy is assigned.',
          )
        else
          ...homework.map((row) {
            final id = homeworkId(row);
            final count = submissionCounts[id] ?? 0;
            final title = teacherFlowText(row['title'], fallback: 'Dairy');
            final subject = teacherFlowText(
              row['subject'] ?? row['subject_id'],
              fallback: RoleAccessService.teacherSubject,
            );
            final due = teacherFlowDateOnly(
              row['submission_date'] ?? row['due_date'],
            );
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TeacherFlowCard(
                icon: Icons.rate_review_rounded,
                title: title,
                subtitle: teacherFlowText(
                  row['description'] ?? row['instructions'],
                  fallback: subject,
                ),
                status: due.isEmpty ? 'Open' : 'Due $due',
                statusColor: isDueSoon(row) ? Colors.orange : teacherFlowAccent,
                body: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: count > 0
                              ? const Color(0xFFEAF0FF)
                              : const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.people_rounded,
                              size: 14,
                              color: count > 0
                                  ? Colors.indigo
                                  : teacherFlowMuted,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              count == 0
                                  ? 'No submissions'
                                  : '$count submission${count == 1 ? '' : 's'}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: count > 0
                                    ? Colors.indigo
                                    : teacherFlowMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    TeacherFlowActionWrap(
                      actions: [
                        TeacherFlowAction(
                          label: count > 0 ? 'Review Now' : 'View',
                          icon: count > 0
                              ? Icons.rate_review_rounded
                              : Icons.visibility_rounded,
                          filled: count > 0,
                          onTap: () => onOpenSubmissions(row),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}
