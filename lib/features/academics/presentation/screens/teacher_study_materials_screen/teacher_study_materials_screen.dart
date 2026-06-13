import 'package:flutter/material.dart';

import 'package:schooldesk1/core/services/role_access_service.dart';
import 'package:schooldesk1/core/widgets/teacher_flow_ui.dart';
import 'package:schooldesk1/routes/app_routes.dart';

class TeacherStudyMaterialsScreen extends StatefulWidget {
  const TeacherStudyMaterialsScreen({super.key});

  @override
  State<TeacherStudyMaterialsScreen> createState() =>
      _TeacherStudyMaterialsScreenState();
}

class _TeacherStudyMaterialsScreenState
    extends State<TeacherStudyMaterialsScreen> {
  bool _loading = true;
  String _sectionFilter = '';
  String _typeFilter = 'all';
  String _statusFilter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    await RoleAccessService.initialize();
    if (!mounted) return;
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final classes = RoleAccessService.assignedTeacherClasses;
    return TeacherFlowScaffold(
      title: 'Study Materials',
      subtitle: 'Metadata and links for class resources',
      selectedIndex: 21,
      loading: _loading,
      onRefresh: _load,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            Navigator.pushNamed(context, AppRoutes.teacherStudyMaterialForm),
        icon: const Icon(Icons.add_link_rounded),
        label: const Text('Material'),
      ),
      child: TeacherFlowScrollView(
        children: [
          TeacherCurrentClassCard(
            greeting: 'Resource library',
            classLabel: teacherCurrentClassLabel(),
            subject: RoleAccessService.teacherSubject,
            timeLabel: 'Uploads require backend support',
            actions: [
              TeacherFlowAction(
                label: 'Add Link',
                icon: Icons.add_link_rounded,
                filled: true,
                onTap: () => Navigator.pushNamed(
                  context,
                  AppRoutes.teacherStudyMaterialForm,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _filters(classes),
          const SizedBox(height: 18),
          if (!RoleAccessService.hasAssignedClasses)
            const TeacherFlowCard(
              icon: Icons.class_outlined,
              title: 'No classes assigned yet.',
              subtitle:
                  'Study materials can be prepared after Admin/Principal assigns your classes.',
            )
          else
            const TeacherFlowCard(
              icon: Icons.library_books_outlined,
              title: 'No study materials uploaded yet.',
              subtitle:
                  'Use Add Link to prepare metadata. File upload and published library storage need the backend study-materials API.',
              status: 'Backend pending',
            ),
          const SizedBox(height: 12),
          const TeacherFlowCard(
            icon: Icons.cloud_upload_outlined,
            title: 'Upload unavailable',
            subtitle:
                'Required backend: GET/POST /study-materials and a file upload/download endpoint.',
          ),
        ],
      ),
    );
  }

  Widget _filters(List<Map<String, dynamic>> classes) {
    return TeacherFlowCard(
      icon: Icons.filter_list_rounded,
      title: 'Filters',
      subtitle: 'Class, type, and status filters are ready for backend data.',
      body: Column(
        children: [
          if (classes.isNotEmpty)
            DropdownButtonFormField<String>(
              value: _sectionFilter.isEmpty ? 'all' : _sectionFilter,
              decoration: const InputDecoration(labelText: 'Class / Section'),
              items: [
                const DropdownMenuItem(value: 'all', child: Text('All')),
                ...classes.map(
                  (row) => DropdownMenuItem(
                    value: teacherFlowText(row['id'] ?? row['section_id']),
                    child: Text(teacherFlowText(row['label'])),
                  ),
                ),
              ],
              onChanged: (value) =>
                  setState(() => _sectionFilter = value == 'all' ? '' : value!),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _typeFilter,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All')),
                    DropdownMenuItem(value: 'pdf', child: Text('PDF')),
                    DropdownMenuItem(value: 'image', child: Text('Image')),
                    DropdownMenuItem(value: 'link', child: Text('Link')),
                    DropdownMenuItem(value: 'video', child: Text('Video')),
                    DropdownMenuItem(value: 'other', child: Text('Other')),
                  ],
                  onChanged: (value) =>
                      setState(() => _typeFilter = value ?? 'all'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _statusFilter,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All')),
                    DropdownMenuItem(value: 'draft', child: Text('Draft')),
                    DropdownMenuItem(
                      value: 'published',
                      child: Text('Published'),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => _statusFilter = value ?? 'all'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
