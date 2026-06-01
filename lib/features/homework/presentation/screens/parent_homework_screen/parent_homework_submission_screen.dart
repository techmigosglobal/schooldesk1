import 'package:flutter/material.dart';

import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/theme/app_theme.dart';
import 'package:schooldesk1/core/widgets/dashboard_fab_widget.dart';
import 'package:schooldesk1/core/widgets/erp_components.dart';
import 'package:schooldesk1/core/widgets/erp_module_scaffold.dart';
import 'package:schooldesk1/core/widgets/parent_navigation.dart';

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

  @override
  void dispose() {
    _answerController.dispose();
    _attachmentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ready =
        _text(widget.args.homework['id']).isNotEmpty &&
        widget.args.studentId.trim().isNotEmpty;
    return SchoolDeskModuleScaffold(
      title: 'Submit Homework',
      subtitle: _text(widget.args.homework['title'], fallback: 'Homework'),
      drawer: ParentDrawer(selectedIndex: 3, onDestinationSelected: (_) {}),
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
                      if (answer.isEmpty && attachment.isEmpty) {
                        return 'Enter an answer or attachment URL.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _attachmentController,
                    enabled: !_saving,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      labelText: 'Attachment URL',
                    ),
                  ),
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

  Widget _homeworkContext() {
    final subject = _text(widget.args.homework['subject']);
    final deadline = _text(widget.args.homework['deadline']);
    final instructions = _text(widget.args.homework['instructions']);
    // Backend integration: homework metadata is shown only when the API-backed
    // homework item supplies it. Empty fields are intentionally hidden.
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.outlineVariant),
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
        _text(widget.args.homework['id']),
        studentId: widget.args.studentId,
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
          backgroundColor: AppTheme.error,
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
