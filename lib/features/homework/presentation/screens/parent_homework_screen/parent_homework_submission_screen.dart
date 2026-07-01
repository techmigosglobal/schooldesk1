import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';

import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/navigation/role_nav_indices.dart';
import 'package:schooldesk1/core/widgets/dashboard_fab_widget.dart';
import 'package:schooldesk1/core/widgets/erp_components.dart';
import 'package:schooldesk1/core/widgets/erp_module_scaffold.dart';
import 'package:schooldesk1/core/widgets/parent_navigation.dart';
import 'package:schooldesk1/core/utils/extensions.dart';

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
  final _formKey = GlobalKey<FormState>();
  final _answerController = TextEditingController();
  final _attachmentController = TextEditingController();
  
  bool _saving = false;
  bool _loading = false;
  Map<String, dynamic> _homework = {};
  String _studentId = '';
  String _studentName = '';

  String? _attachmentName;
  bool _uploadingAttachment = false;

  @override
  void initState() {
    super.initState();
    _homework = Map<String, dynamic>.from(widget.args.homework);
    _studentId = widget.args.studentId;
    _studentName = widget.args.studentName;

    // Check if we need to load homework details dynamically
    final hwId = _text(_homework['id'] ?? _homework['reference_id'] ?? _homework['homework_id']);
    if (hwId.isNotEmpty && (_studentId.isEmpty || _homework.length <= 1)) {
      _fetchHomeworkAndStudent(hwId);
    }
  }

  Future<void> _fetchHomeworkAndStudent(String homeworkId) async {
    setState(() => _loading = true);
    try {
      final children = await BackendApiClient.instance.getMyStudents();
      for (final child in children) {
        final sId = (child['id'] ?? '').toString();
        if (sId.isEmpty) continue;
        final list = await BackendApiClient.instance.getHomework(studentId: sId);
        final found = list.firstWhere(
          (h) => h['id']?.toString() == homeworkId,
          orElse: () => <String, dynamic>{},
        );
        if (found.isNotEmpty) {
          setState(() {
            _homework = {
              'id': found['id'],
              'title': found['title'] ?? '',
              'subject': found['subject'] ?? found['subject_name'] ?? '',
              'class': found['class'] ?? found['class_name'] ?? '',
              'deadline': found['deadline'] ?? '',
              'instructions': found['description'] ?? found['instructions'] ?? '',
              'teacher': found['teacher_name'] ?? found['created_by_name'] ?? found['created_by'] ?? '',
              'student_id': sId,
            };
            _studentId = sId;
            _studentName = '${child['first_name'] ?? ''} ${child['last_name'] ?? ''}'.trim();
            _loading = false;
          });
          return;
        }
      }
      setState(() => _loading = false);
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _pickAttachment() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
      withData: false,
    );
    final file = result?.files.single;
    final path = file?.path;
    if (file == null || path == null || path.trim().isEmpty) return;

    setState(() {
      _uploadingAttachment = true;
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
        url = (data['url'] ?? data['data']?['url'] ?? '').toString();
      }
      if (url.isEmpty) {
        throw Exception('Upload completed but no file URL was returned.');
      }
      if (!mounted) return;
      setState(() {
        _attachmentName = file.name;
        _attachmentController.text = url;
        _uploadingAttachment = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _uploadingAttachment = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('File upload failed: $error'),
          backgroundColor: context.appTheme.error,
        ),
      );
    }
  }

  @override
  void dispose() {
    _answerController.dispose();
    _attachmentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ready = _text(_homework['id']).isNotEmpty && _studentId.trim().isNotEmpty;
    
    return SchoolDeskModuleScaffold(
      title: 'Submit Homework',
      subtitle: _text(_homework['title'], fallback: 'Homework'),
      drawer: ParentDrawer(
        selectedIndex: ParentNav.homework,
        onDestinationSelected: (_) {},
      ),
      floatingActionButton: const DashboardFabWidget(
        role: DashboardRole.parent,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (ready)
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _homeworkContext(),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _answerController,
                          enabled: !_saving,
                          minLines: 5,
                          maxLines: 8,
                          decoration: const InputDecoration(
                            labelText: 'Answer / completion note',
                            alignLabelWithHint: true,
                          ),
                          validator: (value) {
                            final answer = (value ?? '').trim();
                            final attachment = _attachmentController.text.trim();
                            if (answer.isEmpty && attachment.isEmpty) {
                              return 'Enter an answer or pick an attachment file.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Attachment (PDF or Image)',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: context.appTheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: context.appTheme.outlineVariant),
                            borderRadius: BorderRadius.circular(8),
                            color: context.appTheme.surface,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: _uploadingAttachment
                                    ? Row(
                                        children: [
                                          const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          ),
                                          const SizedBox(width: 12),
                                          Text('Uploading file...', style: TextStyle(color: context.appTheme.onSurface)),
                                        ],
                                      )
                                    : Text(
                                        _attachmentName ??
                                            (_attachmentController.text.isNotEmpty
                                                ? 'Attachment linked'
                                                : 'No file selected'),
                                        style: TextStyle(
                                          color: _attachmentController.text.isNotEmpty
                                              ? context.appTheme.onSurface
                                              : context.appTheme.muted,
                                        ),
                                      ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                onPressed: _saving || _uploadingAttachment ? null : _pickAttachment,
                                icon: const Icon(Icons.attach_file_rounded, size: 16),
                                label: const Text('Choose File'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: _saving || _uploadingAttachment ? null : _submit,
                          icon: _saving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.upload_file_rounded, size: 18),
                          label: Text(_saving ? 'Submitting...' : 'Submit Homework'),
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
                    title: 'Homework selection required',
                    message:
                        'Open this screen from a linked child homework item before submitting.',
                  ),
                const SizedBox(height: 84),
              ],
            ),
    );
  }

  Widget _homeworkContext() {
    final subject = _text(_homework['subject']);
    final deadline = _text(_homework['deadline']);
    final instructions = _text(_homework['instructions']);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.appTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.appTheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _text(_homework['title'], fallback: 'Homework'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text('Student: $_studentName'),
          if (subject.isNotEmpty) Text('Subject: $subject'),
          if (deadline.isNotEmpty) Text('Due: $deadline'),
          if (instructions.isNotEmpty) ...[
            const Divider(height: 18),
            Text(instructions),
          ],
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await BackendApiClient.instance.submitHomework(
        _text(_homework['id']),
        studentId: _studentId,
        answerText: _answerController.text.trim(),
        attachmentUrl: _attachmentController.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(
        context,
        const ParentHomeworkSubmissionResult('Homework submitted successfully'),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Homework submit failed: ${_cleanError(error)}'),
          backgroundColor: context.appTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

String _text(dynamic value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

String _cleanError(Object error) {
  final raw = error.toString();
  final marker = raw.indexOf('message:');
  if (marker >= 0) return raw.substring(marker + 8).trim();
  return raw.replaceFirst('Exception:', '').trim();
}
