import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

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
  final List<String> _attachmentUrls = [];
  final List<String> _attachmentNames = [];
  bool _saving = false;
  bool _uploading = false;

  String get _homeworkId =>
      _text(widget.args.homework['homework_id'] ?? widget.args.homework['id']);

  @override
  void dispose() {
    _answerController.dispose();
    _attachmentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ready =
        _homeworkId.isNotEmpty && widget.args.studentId.trim().isNotEmpty;
    return SchoolDeskModuleScaffold(
      title: 'Submit Homework',
      subtitle: _text(widget.args.homework['title'], fallback: 'Homework'),
      drawer: ParentDrawer(
        selectedIndex: ParentNav.homework,
        onDestinationSelected: (_) {},
      ),
      floatingActionButton: const DashboardFabWidget(
        role: DashboardRole.parent,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: ListView(
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
                      if (answer.isEmpty &&
                          attachment.isEmpty &&
                          _attachmentUrls.isEmpty) {
                        return 'Enter an answer or add an attachment.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  _attachmentsBlock(),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _saving ? null : _submit,
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

  Widget _attachmentsBlock() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.appTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.appTheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.attach_file_rounded,
                color: context.appTheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Attachments',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _saving || _uploading ? null : _pickAttachments,
                icon: _uploading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.upload_file_rounded, size: 16),
                label: Text(_uploading ? 'Uploading' : 'Add'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _attachmentController,
            enabled: !_saving,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'Attachment URL',
              prefixIcon: Icon(Icons.link_rounded),
            ),
          ),
          if (_attachmentUrls.isNotEmpty) ...[
            const SizedBox(height: 10),
            ..._attachmentUrls.asMap().entries.map((entry) {
              final index = entry.key;
              final name = index < _attachmentNames.length
                  ? _attachmentNames[index]
                  : entry.value.split('/').last;
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  _isPdf(name) ? Icons.picture_as_pdf_rounded : Icons.image,
                  color: context.appTheme.primary,
                ),
                title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: IconButton(
                  tooltip: 'Remove attachment',
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
              );
            }),
          ],
        ],
      ),
    );
  }

  Future<void> _pickAttachments() async {
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
    );
    if (result == null || result.files.isEmpty) return;
    setState(() => _uploading = true);
    try {
      for (final file in result.files) {
        final path = file.path;
        if (path == null || path.trim().isEmpty) continue;
        final url = await BackendApiClient.instance.uploadFile(
          path,
          filename: file.name,
        );
        if (url.trim().isEmpty) continue;
        if (!mounted) return;
        setState(() {
          _attachmentUrls.add(url);
          _attachmentNames.add(file.name);
        });
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Attachment upload failed: ${_cleanError(error)}'),
          backgroundColor: context.appTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Widget _homeworkContext() {
    final subject = _text(widget.args.homework['subject']);
    final deadline = _text(widget.args.homework['deadline']);
    final instructions = _text(widget.args.homework['instructions']);
    // Backend integration: homework metadata is shown only when the API-backed
    // homework item supplies it. Empty fields are intentionally hidden.
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
            _text(widget.args.homework['title'], fallback: 'Homework'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text('Student: ${widget.args.studentName}'),
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
        _homeworkId,
        studentId: widget.args.studentId,
        answerText: _answerController.text.trim(),
        attachmentUrl: _attachmentController.text.trim(),
        attachmentUrls: _attachmentUrls,
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

bool _isPdf(String name) => name.toLowerCase().endsWith('.pdf');

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
