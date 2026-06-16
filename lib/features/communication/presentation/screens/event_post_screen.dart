import 'package:flutter/material.dart';

import 'package:schooldesk1/core/widgets/erp_components.dart';
import 'package:schooldesk1/core/widgets/erp_module_scaffold.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/utils/extensions.dart';

class TeacherEventPostScreen extends StatefulWidget {
  const TeacherEventPostScreen({super.key});

  @override
  State<TeacherEventPostScreen> createState() => _TeacherEventPostScreenState();
}

class _TeacherEventPostScreenState extends State<TeacherEventPostScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _dateController = TextEditingController();
  final _mediaUrlController = TextEditingController();
  
  bool _destParentHome = true;
  bool _destSchoolGallery = false;
  bool _destSchoolLanding = false;

  bool _loading = false;
  String? _error;
  List<dynamic> _posts = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 1) {
        _loadPosts();
      }
    });
  }

  Future<void> _loadPosts() async {
    setState(() => _loading = true);
    try {
      final response = (await BackendApiClient.instance.dio.get('/api/v1/event-posts/teacher')).data;
      if (!mounted) return;
      setState(() {
        _posts = response is List ? response : (response['data'] as List? ?? []);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load posts: $e';
      });
    }
  }

  Future<void> _submit(bool isSubmit) async {
    if (_titleController.text.trim().isEmpty) return;
    
    final destinations = <String>[];
    if (_destParentHome) destinations.add('PARENTS_HOME');
    if (_destSchoolGallery) destinations.add('SCHOOL_GALLERY');
    if (_destSchoolLanding) destinations.add('SCHOOL_LANDING');

    if (destinations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one destination.')),
      );
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await BackendApiClient.instance.dio.post('/api/v1/event-posts', data: {
        'title': _titleController.text.trim(),
        'description': _descController.text.trim(),
        'event_date': _dateController.text.trim().isEmpty ? DateTime.now().toIso8601String() : '${_dateController.text.trim()}T00:00:00Z',
        'media_urls': _mediaUrlController.text.trim(),
        'destinations': destinations,
        'is_submit': isSubmit,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isSubmit ? 'Event Post submitted for approval!' : 'Draft saved!')),
      );
      _titleController.clear();
      _descController.clear();
      _dateController.clear();
      _mediaUrlController.clear();
      setState(() {
        _loading = false;
        _tabController.animateTo(1);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to create event post: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SchoolDeskModuleScaffold(
      title: 'Event Posts',
      body: Column(
        children: [
          TabBar(
            controller: _tabController,
            labelColor: context.appTheme.primary,
            unselectedLabelColor: context.appTheme.onSurface.withOpacity(0.6),
            tabs: const [
              Tab(text: 'Create Post', icon: Icon(Icons.add_box)),
              Tab(text: 'Post Status', icon: Icon(Icons.history)),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildCreateForm(),
                _buildStatusList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: context.appTheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Create New Event Post',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 24),
                  if (_error != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: context.appTheme.error.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _error!,
                        style: TextStyle(color: context.appTheme.error),
                      ),
                    ),
                  SchoolDeskTextField(
                    controller: _titleController,
                    label: 'Event Title',
                    hint: 'E.g. Annual Sports Day',
                  ),
                  const SizedBox(height: 16),
                  SchoolDeskTextField(
                    controller: _descController,
                    label: 'Description',
                    hint: 'Enter details...',
                    maxLines: 4,
                  ),
                  const SizedBox(height: 16),
                  SchoolDeskTextField(
                    controller: _dateController,
                    label: 'Event Date (YYYY-MM-DD)',
                    hint: 'Optional',
                  ),
                  const SizedBox(height: 16),
                  SchoolDeskTextField(
                    controller: _mediaUrlController,
                    label: 'Media URL (Image/Video attachment)',
                    hint: 'https://...',
                  ),
                  const SizedBox(height: 24),
                  Text('Destinations', style: Theme.of(context).textTheme.titleMedium),
                  CheckboxListTile(
                    title: const Text('Parent Home Feed'),
                    value: _destParentHome,
                    onChanged: (val) => setState(() => _destParentHome = val ?? false),
                  ),
                  CheckboxListTile(
                    title: const Text('School Gallery'),
                    value: _destSchoolGallery,
                    onChanged: (val) => setState(() => _destSchoolGallery = val ?? false),
                  ),
                  CheckboxListTile(
                    title: const Text('Public Landing Page'),
                    value: _destSchoolLanding,
                    onChanged: (val) => setState(() => _destSchoolLanding = val ?? false),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: _loading ? null : () => _submit(false),
                        child: const Text('Save Draft'),
                      ),
                      const SizedBox(width: 16),
                      FilledButton(
                        onPressed: _loading ? null : () => _submit(true),
                        child: const Text('Submit for Approval'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusList() {
    if (_loading && _posts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_posts.isEmpty) {
      return const Center(child: Text('No posts found.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(24.0),
      itemCount: _posts.length,
      itemBuilder: (context, index) {
        final post = _posts[index];
        final status = post['approval_status'] ?? 'draft';
        Color statusColor = Colors.grey;
        if (status == 'approved') statusColor = Colors.green;
        if (status == 'rejected') statusColor = Colors.red;
        if (status == 'pending') statusColor = Colors.orange;

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: ListTile(
            title: Text(post['title'] ?? 'No Title'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(post['description'] ?? ''),
                if (status == 'rejected' && post['rejection_reason'] != null)
                  Text('Reason: ${post['rejection_reason']}', style: const TextStyle(color: Colors.red)),
              ],
            ),
            trailing: Chip(
              label: Text(status.toUpperCase(), style: const TextStyle(fontSize: 10, color: Colors.white)),
              backgroundColor: statusColor,
            ),
          ),
        );
      },
    );
  }
}
