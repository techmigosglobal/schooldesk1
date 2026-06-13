import 'package:flutter/material.dart';

import 'package:schooldesk1/core/services/role_access_service.dart';
import 'package:schooldesk1/core/widgets/teacher_flow_ui.dart';

class TeacherStudyMaterialFormScreen extends StatefulWidget {
  const TeacherStudyMaterialFormScreen({super.key});

  @override
  State<TeacherStudyMaterialFormScreen> createState() =>
      _TeacherStudyMaterialFormScreenState();
}

class _TeacherStudyMaterialFormScreenState
    extends State<TeacherStudyMaterialFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _topicController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _linkController = TextEditingController();

  String _sectionId = '';
  String _materialType = 'link';
  String _visibility = 'both';
  String _status = 'draft';
  bool _notify = false;

  @override
  void initState() {
    super.initState();
    _sectionId = RoleAccessService.teacherClassId;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _topicController.dispose();
    _descriptionController.dispose();
    _linkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final classes = RoleAccessService.assignedTeacherClasses;
    return TeacherFlowScaffold(
      title: 'Study Material',
      subtitle: 'Prepare link metadata for class resources',
      selectedIndex: 21,
      child: TeacherFlowScrollView(
        children: [
          const TeacherFlowCard(
            icon: Icons.cloud_upload_outlined,
            title: 'File upload unavailable',
            subtitle:
                'This form saves no files until the backend adds /study-materials upload and download endpoints.',
          ),
          const SizedBox(height: 14),
          Form(
            key: _formKey,
            child: TeacherFlowCard(
              icon: Icons.library_add_rounded,
              title: 'Material details',
              subtitle: 'Title, class, type, link, visibility, and status',
              body: Column(
                children: [
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(labelText: 'Title'),
                    validator: (value) => teacherFlowText(value).isEmpty
                        ? 'Title required'
                        : null,
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: _sectionId.isEmpty ? null : _sectionId,
                    decoration: const InputDecoration(
                      labelText: 'Class / Section',
                    ),
                    items: classes
                        .map(
                          (row) => DropdownMenuItem(
                            value: teacherFlowText(
                              row['id'] ?? row['section_id'],
                            ),
                            child: Text(teacherFlowText(row['label'])),
                          ),
                        )
                        .toList(),
                    validator: (value) => teacherFlowText(value).isEmpty
                        ? 'Class required'
                        : null,
                    onChanged: (value) =>
                        setState(() => _sectionId = value ?? ''),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _materialType,
                          decoration: const InputDecoration(labelText: 'Type'),
                          items: const [
                            DropdownMenuItem(value: 'pdf', child: Text('PDF')),
                            DropdownMenuItem(
                              value: 'image',
                              child: Text('Image'),
                            ),
                            DropdownMenuItem(
                              value: 'link',
                              child: Text('Link'),
                            ),
                            DropdownMenuItem(
                              value: 'video',
                              child: Text('Video'),
                            ),
                            DropdownMenuItem(
                              value: 'other',
                              child: Text('Other'),
                            ),
                          ],
                          onChanged: (value) =>
                              setState(() => _materialType = value ?? 'link'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _status,
                          decoration: const InputDecoration(
                            labelText: 'Status',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'draft',
                              child: Text('Draft'),
                            ),
                            DropdownMenuItem(
                              value: 'published',
                              child: Text('Publish'),
                            ),
                          ],
                          onChanged: (value) =>
                              setState(() => _status = value ?? 'draft'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _topicController,
                    decoration: const InputDecoration(
                      labelText: 'Chapter / Topic',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _linkController,
                    decoration: const InputDecoration(labelText: 'Link URL'),
                    validator: _validateLink,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _descriptionController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: 'Description'),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: _visibility,
                    decoration: const InputDecoration(labelText: 'Visibility'),
                    items: const [
                      DropdownMenuItem(
                        value: 'students',
                        child: Text('Students'),
                      ),
                      DropdownMenuItem(
                        value: 'parents',
                        child: Text('Parents'),
                      ),
                      DropdownMenuItem(value: 'both', child: Text('Both')),
                    ],
                    onChanged: (value) =>
                        setState(() => _visibility = value ?? 'both'),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Notify parents/students'),
                    value: _notify,
                    onChanged: (value) => setState(() => _notify = value),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _submit,
                      icon: const Icon(Icons.save_rounded),
                      label: const Text('Validate Material'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? _validateLink(String? value) {
    final text = teacherFlowText(value);
    if (text.isEmpty) return 'Either file or link required';
    final uri = Uri.tryParse(text);
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
      return 'Enter a valid URL';
    }
    return null;
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Study material metadata validated. Backend storage is not connected yet.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
