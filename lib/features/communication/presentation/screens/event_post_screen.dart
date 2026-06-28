import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

import 'package:schooldesk1/core/widgets/erp_components.dart';
import 'package:schooldesk1/core/widgets/erp_module_scaffold.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/services/notification_service.dart';
import 'package:schooldesk1/core/utils/event_post_media_parser.dart';
import 'package:schooldesk1/core/utils/extensions.dart';

class TeacherEventPostScreen extends StatefulWidget {
  const TeacherEventPostScreen({super.key});

  @override
  State<TeacherEventPostScreen> createState() => _TeacherEventPostScreenState();
}

class _TeacherEventPostScreenState extends State<TeacherEventPostScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _dateController = TextEditingController();

  bool _destParentHome = true;
  bool _destSchoolGallery = false;
  bool _destSchoolLanding = false;

  // Uploaded file URLs (returned by backend after upload)
  final List<String> _uploadedUrls = [];
  bool _uploading = false;

  bool _loading = false;
  String? _error;
  List<dynamic> _posts = [];

  void _onNotificationChanged() {
    if (_tabController.index == 1) {
      _loadPosts();
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 1) _loadPosts();
    });
    NotificationService.getInstance().then((s) {
      if (mounted) s.addListener(_onNotificationChanged);
    });
  }

  @override
  void dispose() {
    NotificationService.getInstance().then((s) {
      s.removeListener(_onNotificationChanged);
    });
    _tabController.dispose();
    _titleController.dispose();
    _descController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  // ── Pick and upload a file ──────────────────────────────────────────────────

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(imageQuality: 80);
    if (picked.isEmpty) return;
    for (final xfile in picked) {
      await _uploadFile(xfile.path, xfile.name);
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.single.path;
    if (path == null) return;
    await _uploadFile(path, result.files.single.name);
  }

  Future<void> _uploadFile(String path, String name) async {
    setState(() => _uploading = true);
    try {
      final url = await BackendApiClient.instance.uploadFile(
        path,
        filename: name,
      );
      if (url.isNotEmpty && mounted) {
        setState(() => _uploadedUrls.add(url));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  // ── Load + Submit ───────────────────────────────────────────────────────────

  Future<void> _loadPosts() async {
    setState(() => _loading = true);
    try {
      final response = await BackendApiClient.instance.getTeacherEventPosts();
      if (!mounted) return;
      setState(() {
        _posts = response;
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
        const SnackBar(content: Text('Select at least one destination.')),
      );
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await BackendApiClient.instance.createEventPost(
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        eventDate: _dateController.text.trim().isEmpty
            ? DateTime.now().toIso8601String()
            : '${_dateController.text.trim()}T00:00:00Z',
        mediaUrls: _uploadedUrls,
        destinations: destinations,
        isSubmit: isSubmit,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isSubmit ? 'Submitted for approval!' : 'Draft saved!'),
        ),
      );
      _titleController.clear();
      _descController.clear();
      _dateController.clear();
      _uploadedUrls.clear();
      setState(() {
        _loading = false;
        _tabController.animateTo(1);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to submit: $e';
      });
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────

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
              Tab(text: 'My Posts', icon: Icon(Icons.history)),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_buildCreateForm(), _buildStatusList()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
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
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Create Event Post',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_error != null) _ErrorBox(message: _error!),
                  SchoolDeskTextField(
                    controller: _titleController,
                    label: 'Event Title *',
                    hint: 'E.g. Annual Sports Day',
                  ),
                  const SizedBox(height: 14),
                  SchoolDeskTextField(
                    controller: _descController,
                    label: 'Description',
                    hint: 'Enter details...',
                    maxLines: 4,
                  ),
                  const SizedBox(height: 14),
                  // Date picker
                  TextFormField(
                    controller: _dateController,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Event Date',
                      hintText: 'Tap to pick a date',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today_outlined),
                    ),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null && mounted) {
                        _dateController.text =
                            '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                      }
                    },
                  ),
                  const SizedBox(height: 20),
                  // ── Attachment section ──────────────────────────────
                  Text(
                    'Attachments / Images',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _uploading ? null : _pickImage,
                        icon: const Icon(Icons.photo_outlined, size: 18),
                        label: const Text('Pick Images'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _uploading ? null : _pickFile,
                        icon: const Icon(Icons.attach_file_rounded, size: 18),
                        label: const Text('Pick File'),
                      ),
                      if (_uploading)
                        const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  if (_uploadedUrls.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    ..._uploadedUrls.asMap().entries.map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                entry.value.split('/').last,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 16),
                              onPressed: () => setState(
                                () => _uploadedUrls.removeAt(entry.key),
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  // ── Destinations ───────────────────────────────────
                  Text(
                    'Destinations *',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  CheckboxListTile(
                    title: const Text('Parent Home Feed'),
                    value: _destParentHome,
                    dense: true,
                    onChanged: (v) =>
                        setState(() => _destParentHome = v ?? false),
                  ),
                  CheckboxListTile(
                    title: const Text('School Gallery'),
                    value: _destSchoolGallery,
                    dense: true,
                    onChanged: (v) =>
                        setState(() => _destSchoolGallery = v ?? false),
                  ),
                  CheckboxListTile(
                    title: const Text('Public Landing Page'),
                    value: _destSchoolLanding,
                    dense: true,
                    onChanged: (v) =>
                        setState(() => _destSchoolLanding = v ?? false),
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 12,
                    runSpacing: 10,
                    children: [
                      OutlinedButton(
                        onPressed: _loading ? null : () => _submit(false),
                        child: const Text('Save Draft'),
                      ),
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
      return const Center(child: Text('No posts yet.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _posts.length,
      itemBuilder: (context, i) {
        final post = _posts[i];
        final status = post['approval_status'] ?? 'draft';
        final Color statusColor = switch (status) {
          'approved' => Colors.green,
          'rejected' => Colors.red,
          'pending' => Colors.orange,
          _ => Colors.grey,
        };
        final media = _labels(post['media_urls']);
        return Card(
          margin: const EdgeInsets.only(bottom: 14),
          child: ListTile(
            title: Text(
              post['title'] ?? 'No Title',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if ((post['description'] ?? '').isNotEmpty)
                  Text(post['description']),
                if (media.isNotEmpty)
                  Text(
                    '${media.length} attachment${media.length == 1 ? '' : 's'}',
                  ),
                if (status == 'rejected' && post['rejection_reason'] != null)
                  Text(
                    'Reason: ${post['rejection_reason']}',
                    style: const TextStyle(color: Colors.red),
                  ),
              ],
            ),
            trailing: FittedBox(
              fit: BoxFit.scaleDown,
              child: Chip(
                label: Text(
                  status.toUpperCase(),
                  style: const TextStyle(fontSize: 10, color: Colors.white),
                ),
                backgroundColor: statusColor,
                padding: EdgeInsets.zero,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        );
      },
    );
  }

  List<String> _labels(dynamic raw) {
    return parseEventPostMediaUrls(raw);
  }
}

class _ErrorBox extends StatelessWidget {
  final String message;
  const _ErrorBox({required this.message});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: context.appTheme.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(message, style: TextStyle(color: context.appTheme.error)),
    );
  }
}
