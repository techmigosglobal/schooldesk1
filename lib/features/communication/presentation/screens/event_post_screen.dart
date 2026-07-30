import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:schooldesk1/core/widgets/erp_components.dart';
import 'package:schooldesk1/core/widgets/erp_module_scaffold.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/services/notification_service.dart';
import 'package:schooldesk1/core/utils/event_post_media_parser.dart';
import 'package:schooldesk1/core/utils/extensions.dart';
import 'package:schooldesk1/core/widgets/event_post_media_preview.dart';

class TeacherEventPostScreen extends StatefulWidget {
  final bool principalMode;

  const TeacherEventPostScreen({super.key, this.principalMode = false});

  @override
  State<TeacherEventPostScreen> createState() => _TeacherEventPostScreenState();
}

class _TeacherEventPostScreenState extends State<TeacherEventPostScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _dateController = TextEditingController();

  bool _destParentHome = true;
  bool _destSchoolGallery = false;
  bool _destSchoolLanding = false;

  // Uploaded file URLs (returned by backend after upload)
  final List<String> _uploadedUrls = [];
  final List<EventPostMediaItem> _uploadedMedia = [];
  String? _editingPostId;
  bool _editingRejectedPost = false;
  bool _uploading = false;

  bool _loading = false;
  String? _error;
  List<dynamic> _posts = [];
  NotificationService? _notificationService;
  Timer? _pollingTimer;

  bool get _canPublishDirectly => widget.principalMode;
  String get _postNoun =>
      _canPublishDirectly ? 'School Feed Post' : 'Event Post';

  void _onNotificationChanged() {
    unawaited(_loadPosts(showSpinner: false));
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 1) _loadPosts(showSpinner: false);
    });
    NotificationService.getInstance().then((s) {
      if (!mounted) return;
      _notificationService = s;
      s.addListener(_onNotificationChanged);
    });
    _pollingTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted && !_loading) {
        unawaited(_loadPosts(showSpinner: false));
      }
    });
    _loadPosts();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollingTimer?.cancel();
    _notificationService?.removeListener(_onNotificationChanged);
    _tabController.dispose();
    _titleController.dispose();
    _descController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_loadPosts(showSpinner: false));
    }
  }

  // ── Pick and upload images ──────────────────────────────────────────────────

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(
      imageQuality: 80,
      maxWidth: 2048,
      maxHeight: 2048,
    );
    if (picked.isEmpty) return;
    for (final xfile in picked) {
      await _uploadFile(xfile.path, xfile.name, mimeType: xfile.mimeType);
    }
  }

  Future<void> _pickVideo() async {
    final video = await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (video == null) return;
    await _uploadFile(video.path, video.name, mimeType: video.mimeType);
  }

  Future<void> _uploadFile(String path, String name, {String? mimeType}) async {
    setState(() => _uploading = true);
    try {
      final url = await BackendApiClient.instance.uploadFile(
        path,
        filename: name,
        mimeType: mimeType,
      );
      if (url.isNotEmpty && mounted) {
        final item = EventPostMediaItem.fromUrl(url, mimeType: mimeType ?? '');
        setState(() {
          _uploadedUrls.add(url);
          _uploadedMedia.add(
            EventPostMediaItem(
              url: url,
              name: name,
              mimeType: mimeType ?? '',
              kind: item.kind,
            ),
          );
        });
      }
    } on Object catch (e) {
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

  Future<void> _loadPosts({bool showSpinner = true}) async {
    if (showSpinner) {
      setState(() => _loading = true);
    }
    try {
      final response = _canPublishDirectly
          ? await BackendApiClient.instance.getPrincipalEventPosts()
          : await BackendApiClient.instance.getTeacherEventPosts();
      if (!mounted) return;
      setState(() {
        _posts = response;
        _loading = false;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        if (showSpinner) _loading = false;
        _error = 'Failed to load posts: $e';
      });
    }
  }

  Future<void> _submit(bool isSubmit) async {
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
    final landingOnly = destinations.length == 1 && _destSchoolLanding;
    if (!landingOnly && _titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter an event title.')));
      return;
    }
    if (_destSchoolLanding && _uploadedMedia.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add at least one image for the landing-page slider.'),
        ),
      );
      return;
    }
    if (_destSchoolLanding && _uploadedMedia.any((item) => !item.isImage)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Landing-page posts can contain images only. Remove the video or choose another destination.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final eventDate = _dateController.text.trim().isEmpty
          ? DateTime.now().toIso8601String()
          : '${_dateController.text.trim()}T00:00:00Z';
      if (_editingPostId == null) {
        await BackendApiClient.instance.createEventPost(
          title: _titleController.text.trim(),
          description: _descController.text.trim(),
          eventDate: eventDate,
          mediaUrls: _uploadedUrls,
          media: _uploadedMedia,
          destinations: destinations,
          isSubmit: isSubmit,
        );
      } else {
        await BackendApiClient.instance.updateEventPost(
          id: _editingPostId!,
          title: _titleController.text.trim(),
          description: _descController.text.trim(),
          eventDate: eventDate,
          mediaUrls: _uploadedUrls,
          media: _uploadedMedia,
          destinations: destinations,
          isSubmit: isSubmit,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isSubmit
                ? _canPublishDirectly
                      ? 'Published to the school feed!'
                      : 'Submitted for approval!'
                : 'Draft saved!',
          ),
        ),
      );
      _clearForm();
      try {
        await BackendApiClient.instance.invalidateCachedReads();
      } on Object catch (_) {
        // The write succeeded; cache cleanup should not turn it into an error.
      }
      unawaited(
        NotificationService.getInstance().then((service) => service.refresh()),
      );
      setState(() {
        _loading = false;
        _tabController.animateTo(1);
      });
      unawaited(_loadPosts(showSpinner: false));
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to submit: $e';
      });
    }
  }

  void _clearForm() {
    _titleController.clear();
    _descController.clear();
    _dateController.clear();
    _uploadedUrls.clear();
    _uploadedMedia.clear();
    _editingPostId = null;
    _editingRejectedPost = false;
    _destParentHome = true;
    _destSchoolGallery = false;
    _destSchoolLanding = false;
  }

  void _startEditingPost(Map<String, dynamic> post) {
    final id = (post['id'] ?? '').toString().trim();
    if (id.isEmpty) return;

    final media = EventPostMediaItem.parseList(post['media_urls']);
    final destinations = _labels(post['destinations']).toSet();
    setState(() {
      _editingPostId = id;
      _editingRejectedPost =
          (post['approval_status'] ?? '').toString() == 'rejected';
      _titleController.text = (post['title'] ?? '').toString();
      _descController.text = (post['description'] ?? '').toString();
      _dateController.text = _dateInputText(post['event_date']);
      _uploadedUrls
        ..clear()
        ..addAll(media.map((item) => item.url));
      _uploadedMedia
        ..clear()
        ..addAll(media);
      _destParentHome =
          destinations.isEmpty ||
          destinations.contains('PARENTS_HOME') ||
          destinations.contains('Parent Home Feed');
      _destSchoolGallery =
          destinations.contains('SCHOOL_GALLERY') ||
          destinations.contains('School Gallery');
      _destSchoolLanding =
          destinations.contains('SCHOOL_LANDING') ||
          destinations.contains('Landing Page') ||
          destinations.contains('Public Landing Page');
      _error = null;
      _tabController.animateTo(0);
    });
  }

  Future<void> _deletePost(Map<String, dynamic> post) async {
    final id = (post['id'] ?? '').toString().trim();
    if (id.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Event Post'),
        content: const Text('This will permanently remove this event post.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _loading = true);
    try {
      await BackendApiClient.instance.deleteEventPost(id);
      try {
        await BackendApiClient.instance.invalidateCachedReads();
      } on Object catch (_) {
        // The delete succeeded; keep the UI refresh path alive.
      }
      unawaited(
        NotificationService.getInstance().then((service) => service.refresh()),
      );
      if (!mounted) return;
      setState(() {
        _posts = _posts
            .where((item) => (item['id'] ?? '').toString() != id)
            .toList();
        _loading = false;
        if (_editingPostId == id) _clearForm();
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Event post deleted.')));
      unawaited(_loadPosts(showSpinner: false));
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to delete post: $e';
      });
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return SchoolDeskModuleScaffold(
      title: _canPublishDirectly ? 'School Feed Posts' : 'Event Posts',
      body: Column(
        children: [
          TabBar(
            controller: _tabController,
            labelColor: context.appTheme.primary,
            unselectedLabelColor: context.appTheme.onSurface.withOpacity(0.6),
            tabs: [
              const Tab(text: 'Create Post', icon: Icon(Icons.add_box)),
              Tab(
                text: _canPublishDirectly ? 'School Posts' : 'My Posts',
                icon: const Icon(Icons.history),
              ),
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
                    _editingPostId == null
                        ? 'Create $_postNoun'
                        : _editingRejectedPost
                        ? 'Edit Rejected Event Post'
                        : 'Edit Draft Event Post',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_error != null) _ErrorBox(message: _error!),
                  SchoolDeskTextField(
                    controller: _titleController,
                    label:
                        _destSchoolLanding &&
                            !_destParentHome &&
                            !_destSchoolGallery
                        ? 'Event Title (optional for landing image)'
                        : 'Event Title *',
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
                    'Photos & Videos',
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
                        onPressed: _uploading ? null : _pickVideo,
                        icon: const Icon(Icons.videocam_outlined, size: 18),
                        label: const Text('Pick Video'),
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
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _uploadedUrls.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final url = entry.value;
                        final media = _uploadedMedia.firstWhere(
                          (m) => m.url == url,
                          orElse: () => EventPostMediaItem.fromUrl(url),
                        );
                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: SizedBox(
                                width: 96,
                                height: 96,
                                child: EventPostMediaPreview(
                                  item: media,
                                  height: 96,
                                  compact: true,
                                ),
                              ),
                            ),
                            Positioned(
                              top: -8,
                              right: -8,
                              child: InkWell(
                                onTap: () => setState(() {
                                  _uploadedUrls.removeAt(idx);
                                  // Remove the matching media item by URL so
                                  // the two lists stay in sync even if they
                                  // diverge in length (e.g. failed upload).
                                  _uploadedMedia.removeWhere(
                                    (m) => m.url == url,
                                  );
                                }),
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: const BoxDecoration(
                                    color: Colors.black87,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close_rounded,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
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
                    title: const Text('Landing Page (pre-login auto slider)'),
                    subtitle: const Text(
                      'Images only. The description is optional and is not shown on the slider.',
                    ),
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
                        child: Text(
                          _canPublishDirectly
                              ? 'Publish to School Feed'
                              : _editingRejectedPost
                              ? 'Resubmit'
                              : 'Submit for Approval',
                        ),
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
        final mediaItems = EventPostMediaItem.parseList(post['media_urls']);
        return Card(
          margin: const EdgeInsets.only(bottom: 14),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        post['title'] ?? 'No Title',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Chip(
                      label: Text(
                        status.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                        ),
                      ),
                      backgroundColor: statusColor,
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ],
                ),
                if ((post['description'] ?? '').isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(post['description']),
                ],
                if (mediaItems.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    '${media.length} attachment${media.length == 1 ? '' : 's'}',
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 96,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: mediaItems.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) => SizedBox(
                        width: 132,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: EventPostMediaPreview(
                            item: mediaItems[index],
                            height: 96,
                            compact: true,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                if (status == 'rejected' && post['rejection_reason'] != null)
                  Text(
                    'Reason: ${post['rejection_reason']}',
                    style: const TextStyle(color: Colors.red),
                  ),
                if (status == 'draft' || status == 'rejected') ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () =>
                            _startEditingPost(Map<String, dynamic>.from(post)),
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Edit'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () =>
                            _deletePost(Map<String, dynamic>.from(post)),
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('Delete'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: context.appTheme.error,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  List<String> _labels(dynamic raw) {
    return parseEventPostMediaUrls(raw);
  }

  String _dateInputText(dynamic raw) {
    final text = (raw ?? '').toString().trim();
    if (text.isEmpty) return '';
    final parsed = DateTime.tryParse(text);
    if (parsed == null) return text.split('T').first;
    return [
      parsed.year.toString().padLeft(4, '0'),
      parsed.month.toString().padLeft(2, '0'),
      parsed.day.toString().padLeft(2, '0'),
    ].join('-');
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
