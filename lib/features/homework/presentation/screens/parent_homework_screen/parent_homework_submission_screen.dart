import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:schooldesk1/core/navigation/role_nav_indices.dart';
import 'package:schooldesk1/core/repositories/repository_state.dart';
import 'package:schooldesk1/core/widgets/dashboard_fab_widget.dart';
import 'package:schooldesk1/core/widgets/erp_components.dart';
import 'package:schooldesk1/core/widgets/erp_module_scaffold.dart';
import 'package:schooldesk1/core/widgets/parent_navigation.dart';
import 'package:schooldesk1/core/widgets/repository_state_view.dart';
import 'package:schooldesk1/core/widgets/event_post_media_preview.dart';
import 'package:schooldesk1/core/utils/event_post_media_parser.dart';
import 'package:schooldesk1/core/utils/extensions.dart';
import 'package:schooldesk1/core/utils/image_upload_optimizer.dart';
import 'package:schooldesk1/core/widgets/subject_card_widget.dart';
import 'package:schooldesk1/core/utils/result.dart';
import 'package:schooldesk1/roles/parent/data/api_parent_homework_repository.dart';
import 'package:schooldesk1/roles/parent/domain/parent_homework_repository.dart';

@immutable
class ParentHomeworkSubmissionArgs {
  final Map<String, dynamic> homework;
  final String studentId;
  final String studentName;
  const ParentHomeworkSubmissionArgs({
    required this.homework,
    required this.studentId,
    required this.studentName,
  });
}

@immutable
class ParentHomeworkSubmissionResult {
  final String message;
  const ParentHomeworkSubmissionResult(this.message);
}

class ParentHomeworkSubmissionScreen extends StatefulWidget {
  final ParentHomeworkSubmissionArgs args;
  const ParentHomeworkSubmissionScreen({super.key, required this.args});
  @override
  State<ParentHomeworkSubmissionScreen> createState() =>
      _ParentHomeworkSubmissionScreenState();
}

class _ParentHomeworkSubmissionScreenState
    extends State<ParentHomeworkSubmissionScreen> {
  ParentHomeworkRepository get _repository =>
      ApiParentHomeworkRepository.legacyDefault;

  final _formKey = GlobalKey<FormState>();
  final _answerController = TextEditingController();
  final List<String> _attachmentUrls = [];
  final List<String> _attachmentNames = [];
  bool _saving = false;
  bool _uploading = false;
  late Map<String, dynamic> _homeworkDetails;
  late RepositoryState<Map<String, dynamic>> _detailState;

  static const _accentColor = Color(0xFF1A6B4A);

  String get _homeworkId =>
      _hwText(_homeworkDetails['homework_id'] ?? _homeworkDetails['id']);
  String get _submissionStatus =>
      _hwText(_homeworkDetails['submission_status']);
  String get _parentComment => _hwText(
    _homeworkDetails['parent_comment'] ?? _homeworkDetails['remarks'],
  );
  String get _teacherFeedback => _hwText(_homeworkDetails['teacher_feedback']);
  bool get _hasFeedback =>
      _submissionStatus == 'reviewed' || _submissionStatus == 'needs_revision';
  bool get _needsRevision => _submissionStatus == 'needs_revision';
  bool get _isApproved => _submissionStatus == 'reviewed';

  List<String> get _homeworkAttachments {
    final attachments = _homeworkDetails['attachments'];
    if (attachments is List) {
      return attachments
          .map((e) => e?.toString().trim() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
    }
    final url = _hwText(
      _homeworkDetails['attachment_url'] ?? _homeworkDetails['attachmentUrl'],
    );
    if (url.isEmpty) return [];
    return url
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _homeworkDetails = Map<String, dynamic>.from(widget.args.homework);
    _detailState = RepositoryState(
      data: _homeworkDetails,
      source: RepositorySource.cache,
    );

    // Set initial text if details already has remarks
    final initialRemarks = _parentComment.isNotEmpty
        ? _parentComment
        : _hwText(
            _homeworkDetails['answer_text'] ?? _homeworkDetails['remarks'],
          );
    if (initialRemarks.isNotEmpty) {
      _answerController.text = initialRemarks;
    }

    // Always trigger refresh if title is empty (from notification click)
    final isFromNotification = _hwText(_homeworkDetails['title']).isEmpty;
    if (isFromNotification || _homeworkDetails['submission_status'] == null) {
      _loadDetails();
    }
  }

  Future<void> _loadDetails() async {
    if (!mounted) return;
    final previous = _detailState.data;
    setState(() {
      _detailState = RepositoryState.loading(
        data: previous,
        source: RepositorySource.cache,
        isStale: previous != null,
        isRefreshing: previous != null,
      );
    });
    try {
      final studentId = widget.args.studentId.trim();
      if (studentId.isEmpty) {
        throw Exception('Student link not found');
      }

      // 1. Fetch child's homework list
      final childRowsResult = await _repository.loadHomework(studentId);
      _throwIfFailed(childRowsResult, 'Unable to load homework');
      final childRows = childRowsResult.dataOrNull!;
      final rawHw = childRows.firstWhere(
        (row) => _hwText(row['id'] ?? row['homework_id']) == _homeworkId,
        orElse: () => throw Exception('Dairy item not found'),
      );

      // 2. Fetch submission state
      final responseResult = await _repository.loadSubmissions(
        _homeworkId,
        studentId: studentId,
      );
      _throwIfFailed(responseResult, 'Unable to load submission');
      final response = responseResult.dataOrNull!;
      final submissions = response['submissions'];
      Map<String, dynamic> sub = {};
      if (submissions is List && submissions.isNotEmpty) {
        sub = Map<String, dynamic>.from(submissions.first as Map);
      }

      // 3. Construct mapped details
      final submissionStatus = _hwText(sub['status']);
      final suppliedParentComment = _hwText(sub['parent_comment']);
      final parentComment = suppliedParentComment.isNotEmpty
          ? suppliedParentComment
          : _hwText(sub['remarks']);
      final teacherFeedback = _hwText(sub['teacher_feedback']);

      final fromUrl = _hwText(
        rawHw['attachment_url'] ?? rawHw['attachmentUrl'],
      ).split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      final fromList = (rawHw['attachment_urls'] is List)
          ? (rawHw['attachment_urls'] as List)
                .map((e) => e?.toString().trim() ?? '')
                .where((s) => s.isNotEmpty)
                .toList()
          : <String>[];
      final allAttachments = {...fromUrl, ...fromList}.toList();

      final mappedHw = {
        ...rawHw,
        'homework_id': _homeworkId,
        'title': rawHw['title'] ?? '',
        'subject': rawHw['subject'] ?? rawHw['subject_name'] ?? '',
        'class': rawHw['class'] ?? rawHw['class_name'] ?? '',
        'deadline': rawHw['due_date'] ?? rawHw['deadline'] ?? '',
        'instructions': rawHw['description'] ?? rawHw['instructions'] ?? '',
        'submission_id': _hwText(sub['id']),
        'submission_status': submissionStatus,
        'parent_comment': parentComment,
        'teacher_feedback': teacherFeedback,
        'submission_attachment_url': _hwText(sub['attachment_url']),
        'submission_attachment_urls': sub['attachment_urls'] ?? const [],
        'attachments': allAttachments,
      };

      if (!mounted) return;
      setState(() {
        _homeworkDetails = mappedHw;
        if (parentComment.isNotEmpty) {
          _answerController.text = parentComment;
        }

        // Also populate existing submission files to attachments block
        final submissionFiles = sub['attachment_urls'] as List?;
        if (submissionFiles != null) {
          _attachmentUrls.clear();
          _attachmentNames.clear();
          for (final fileUrl in submissionFiles) {
            final fUrl = _hwText(fileUrl);
            if (fUrl.isNotEmpty) {
              _attachmentUrls.add(fUrl);
              _attachmentNames.add(fUrl.split('/').last);
            }
          }
        }

        _detailState = RepositoryState(
          data: mappedHw,
          source: RepositorySource.remote,
          lastUpdated: DateTime.now().toUtc(),
        );
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        final message =
            'Failed to load details: ${e.toString().replaceAll("Exception:", "").trim()}';
        _detailState = previous == null
            ? RepositoryState.error(error: StateError(message))
            : RepositoryState(
                data: previous,
                source: RepositorySource.cache,
                isStale: true,
                error: StateError(message),
                lastUpdated: _detailState.lastUpdated,
              );
      });
    }
  }

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ready =
        _homeworkId.isNotEmpty && widget.args.studentId.trim().isNotEmpty;
    return SchoolDeskModuleScaffold(
      title: 'Submit Dairy',
      subtitle: _hwText(_homeworkDetails['title'], fallback: 'Dairy'),
      drawer: ParentDrawer(
        selectedIndex: ParentNav.homework,
        onDestinationSelected: (_) {},
      ),
      floatingActionButton: const DashboardFabWidget(
        role: DashboardRole.parent,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: SchoolDeskRepositoryStateView<Map<String, dynamic>>(
        state: _detailState,
        onRetry: _loadDetails,
        loadingMessage: 'Loading homework details…',
        emptyTitle: 'Homework unavailable',
        emptyMessage: 'Homework details are not available for this request.',
        data: (_) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (ready)
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _homeworkContextCard(),
                    const SizedBox(height: 14),
                    if (_hasFeedback && _parentComment.isNotEmpty) ...[
                      _parentCommentCard(),
                      const SizedBox(height: 14),
                    ],
                    if (_hasFeedback) ...[
                      _feedbackCard(),
                      const SizedBox(height: 14),
                    ],
                    if (!_isApproved) ...[
                      _sectionHeader(
                        icon: Icons.edit_note_rounded,
                        label: _needsRevision
                            ? 'Resubmit Your Answer'
                            : 'Your Answer',
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _answerController,
                        enabled: !_saving,
                        minLines: 5,
                        maxLines: 8,
                        style: GoogleFonts.dmSans(fontSize: 14),
                        decoration: InputDecoration(
                          hintText:
                              'Write your answer or completion note here...',
                          hintStyle: GoogleFonts.dmSans(
                            fontSize: 13,
                            color: context.appTheme.muted,
                          ),
                          filled: true,
                          fillColor: context.appTheme.surface,
                          alignLabelWithHint: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: context.appTheme.outlineVariant,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: context.appTheme.outlineVariant,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: _accentColor,
                              width: 1.5,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if ((value ?? '').trim().isEmpty &&
                              _attachmentUrls.isEmpty) {
                            return 'Enter an answer or add an attachment.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      _attachmentsBlock(),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _saving ? null : _submit,
                          style: FilledButton.styleFrom(
                            backgroundColor: _accentColor,
                            padding: const EdgeInsets.symmetric(
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: _saving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.upload_file_rounded,
                                  size: 18,
                                ),
                          label: Text(
                            _saving
                                ? 'Submitting...'
                                : _needsRevision
                                ? 'Resubmit Dairy'
                                : 'Submit Dairy',
                            style: GoogleFonts.dmSans(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _saving
                              ? null
                              : () => Navigator.pop(context),
                          icon: const Icon(
                            Icons.arrow_back_rounded,
                            size: 18,
                          ),
                          label: Text(
                            'Back to Dairy',
                            style: GoogleFonts.dmSans(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: context.appTheme.successContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle_rounded,
                              color: context.appTheme.success,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'This homework has been approved by your teacher.',
                                style: GoogleFonts.dmSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: context.appTheme.success,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(
                            Icons.arrow_back_rounded,
                            size: 18,
                          ),
                          label: Text(
                            'Back to Dairy',
                            style: GoogleFonts.dmSans(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              )
            else
              const SchoolDeskStatusPanel.empty(
                title: 'Dairy selection required',
                message:
                    'Open this screen from a linked child dairy item before submitting.',
              ),
            const SizedBox(height: 84),
          ],
        ),
      ),
    );
  }

  Widget _homeworkContextCard() {
    final subject = _hwText(_homeworkDetails['subject']);
    final deadline = _hwText(_homeworkDetails['deadline']);
    final instructions = _hwText(_homeworkDetails['instructions']);
    final attachments = _homeworkAttachments;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.appTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.appTheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE3FAF5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.assignment_rounded,
                  color: _accentColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _hwText(_homeworkDetails['title'], fallback: 'Dairy'),
                  style: GoogleFonts.dmSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _infoRow(
            Icons.person_outline_rounded,
            'Student: ${widget.args.studentName}',
          ),
          if (subject.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  Icons.menu_book_rounded,
                  size: 14,
                  color: context.appTheme.muted,
                ),
                const SizedBox(width: 6),
                Text(
                  'Subjects:',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: context.appTheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            SubjectChips(subjectString: subject),
          ],
          if (deadline.isNotEmpty)
            _infoRow(Icons.event_rounded, 'Due: $deadline'),
          if (instructions.isNotEmpty) ...[
            const Divider(height: 18),
            Text(
              'Instructions',
              style: GoogleFonts.dmSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: context.appTheme.muted,
              ),
            ),
            const SizedBox(height: 4),
            Text(instructions, style: GoogleFonts.dmSans(fontSize: 13)),
          ],
          if (attachments.isNotEmpty) ...[
            const Divider(height: 18),
            Text(
              'Teacher Attachments',
              style: GoogleFonts.dmSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: context.appTheme.muted,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: attachments.map((url) {
                final item = EventPostMediaItem.fromUrl(url);
                return OutlinedButton.icon(
                  onPressed: () => openEventPostMediaPreview(context, item),
                  icon: Icon(
                    item.isPdf
                        ? Icons.picture_as_pdf_rounded
                        : Icons.image_rounded,
                    size: 14,
                    color: item.isPdf ? Colors.red : _accentColor,
                  ),
                  label: Text(
                    item.isPdf ? 'View PDF' : 'View Image',
                    style: GoogleFonts.dmSans(fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _accentColor,
                    side: const BorderSide(color: _accentColor),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _feedbackCard() {
    final isRevision = _needsRevision;
    final color = isRevision
        ? context.appTheme.warning
        : context.appTheme.success;
    final bgColor = isRevision
        ? context.appTheme.warning.withAlpha(15)
        : context.appTheme.success.withAlpha(15);
    final borderColor = isRevision
        ? context.appTheme.warning.withAlpha(80)
        : context.appTheme.success.withAlpha(80);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isRevision
                    ? Icons.replay_rounded
                    : Icons.check_circle_outline_rounded,
                color: color,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                "Teacher Feedback — ${isRevision ? 'Needs Revision' : 'Approved'}",
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          if (_teacherFeedback.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              _teacherFeedback,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: context.appTheme.onSurface,
              ),
            ),
          ],
          if (isRevision) ...[
            const SizedBox(height: 8),
            Text(
              "Please update your submission and resubmit below.",
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: context.appTheme.muted,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _parentCommentCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.appTheme.primary.withAlpha(12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.appTheme.primary.withAlpha(65)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.person_outline_rounded,
                color: context.appTheme.primary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Your Submitted Comment',
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: context.appTheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _parentComment,
            style: GoogleFonts.dmSans(
              fontSize: 13,
              color: context.appTheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _attachmentsBlock() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.appTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.appTheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.attach_file_rounded,
                color: _accentColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Attachments (Images / PDF)",
                  style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _saving || _uploading ? null : _pickAttachments,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _accentColor,
                  side: const BorderSide(color: _accentColor),
                ),
                icon: _uploading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.upload_file_rounded, size: 16),
                label: Text(
                  _uploading ? "Uploading..." : "Add",
                  style: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          if (_attachmentUrls.isNotEmpty) ...[
            const SizedBox(height: 10),
            ..._attachmentUrls.asMap().entries.map((entry) {
              final index = entry.key;
              final name = index < _attachmentNames.length
                  ? _attachmentNames[index]
                  : entry.value.split("/").last;
              final item = EventPostMediaItem.fromUrl(entry.value);
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  item.isPdf
                      ? Icons.picture_as_pdf_rounded
                      : Icons.image_rounded,
                  color: item.isPdf ? Colors.red : _accentColor,
                ),
                title: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(fontSize: 13),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: "Preview",
                      icon: const Icon(Icons.visibility_rounded, size: 18),
                      onPressed: () => openEventPostMediaPreview(context, item),
                    ),
                    IconButton(
                      tooltip: "Remove",
                      onPressed: _saving
                          ? null
                          : () {
                              setState(() {
                                _attachmentUrls.removeAt(index);
                                if (index < _attachmentNames.length) {
                                  _attachmentNames.removeAt(index);
                                }
                              });
                            },
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              );
            }),
          ] else
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                "No attachments yet. Tap Add to upload images or PDFs.",
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: context.appTheme.muted,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _sectionHeader({required IconData icon, required String label}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: _accentColor),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF183037),
          ),
        ),
      ],
    );
  }

  Widget _infoRow(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: context.appTheme.muted),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: context.appTheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAttachments() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ["pdf", "jpg", "jpeg", "png", "webp"],
    );
    if (result.isEmpty) return;
    setState(() => _uploading = true);
    try {
      for (final file in result) {
        final path = file.path ?? '';
        final fileBytes = await file.readAsBytes();
        final mimeType = ImageUploadOptimizer.mimeTypeForFilename(file.name);
        final optimized = ImageUploadOptimizer.isImage(file.name, mimeType)
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
        final uploadResult = await _repository.uploadFile(
          path,
          filename: optimized?.filename ?? file.name,
          fileBytes: optimized?.bytes ?? fileBytes,
          mimeType: optimized?.mimeType ?? mimeType,
        );
        _throwIfFailed(uploadResult, 'Unable to upload attachment');
        final url = uploadResult.dataOrNull!;
        if (url.trim().isEmpty) continue;
        if (!mounted) return;
        setState(() {
          _attachmentUrls.add(url);
          _attachmentNames.add(optimized?.filename ?? file.name);
        });
      }
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Upload failed: ${_cleanErr(error)}"),
          backgroundColor: context.appTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final result = await _repository.submitHomework(
        homeworkId: _homeworkId,
        studentId: widget.args.studentId,
        answerText: _answerController.text.trim(),
        attachmentUrls: _attachmentUrls,
      );
      _throwIfFailed(result, 'Unable to submit homework');
      if (!mounted) return;
      Navigator.pop(
        context,
        ParentHomeworkSubmissionResult(
          _needsRevision
              ? "Dairy resubmitted successfully"
              : "Dairy submitted successfully",
        ),
      );
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Submit failed: ${_cleanErr(error)}"),
          backgroundColor: context.appTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _throwIfFailed<T>(Result<T> result, String fallback) {
    if (result.isFailure) {
      throw StateError(result.failureOrNull?.message ?? fallback);
    }
  }
}

String _hwText(dynamic value, {String fallback = ""}) {
  final t = value?.toString().trim() ?? "";
  return t.isEmpty ? fallback : t;
}

String _cleanErr(Object error) {
  final raw = error.toString();
  final idx = raw.indexOf("message:");
  if (idx >= 0) return raw.substring(idx + 8).trim();
  return raw.replaceFirst("Exception:", "").trim();
}
