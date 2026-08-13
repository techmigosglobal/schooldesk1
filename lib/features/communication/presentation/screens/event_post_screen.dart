import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:schooldesk1/core/widgets/erp_components.dart';
import 'package:schooldesk1/core/widgets/erp_module_scaffold.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/services/notification_service.dart';
import 'package:schooldesk1/core/utils/event_post_media_parser.dart';
import 'package:schooldesk1/core/utils/extensions.dart';
import 'package:schooldesk1/core/utils/image_upload_optimizer.dart';
import 'package:schooldesk1/core/widgets/event_post_media_preview.dart';

class SchoolPostsRouteArgs {
  final String initialTab;
  final String referenceId;
  final String referenceType;

  const SchoolPostsRouteArgs({
    this.initialTab = 'auto',
    this.referenceId = '',
    this.referenceType = '',
  });

  static SchoolPostsRouteArgs fromRoute(Object? raw) {
    if (raw is SchoolPostsRouteArgs) return raw;
    if (raw is Map) {
      return SchoolPostsRouteArgs(
        initialTab: (raw['initialTab'] ?? raw['initial_tab'] ?? 'auto')
            .toString(),
        referenceId: (raw['referenceId'] ?? raw['reference_id'] ?? '')
            .toString()
            .trim(),
        referenceType: (raw['referenceType'] ?? raw['reference_type'] ?? '')
            .toString()
            .trim(),
      );
    }
    if (raw is String && raw.trim().isNotEmpty) {
      return SchoolPostsRouteArgs(initialTab: raw.trim());
    }
    return const SchoolPostsRouteArgs();
  }
}

class TeacherEventPostScreen extends StatefulWidget {
  final bool principalMode;
  final SchoolPostsRouteArgs args;

  const TeacherEventPostScreen({
    super.key,
    this.principalMode = false,
    this.args = const SchoolPostsRouteArgs(),
  });

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
  bool _reviewLoading = false;
  bool _reviewRefreshing = false;
  String? _error;
  String? _reviewError;
  List<dynamic> _posts = [];
  List<Map<String, dynamic>> _reviewPosts = [];
  Map<String, dynamic>? _referencedReviewPost;
  final Set<String> _viewedAttachmentPostIds = <String>{};
  NotificationService? _notificationService;
  Timer? _pollingTimer;
  Timer? _refreshDebounceTimer;
  bool _postsRequestInFlight = false;
  bool _reviewRequestInFlight = false;

  bool get _canPublishDirectly => widget.principalMode;
  String get _postNoun =>
      _canPublishDirectly ? 'School Feed Post' : 'Event Post';
  int get _manageTabIndex => widget.principalMode ? 2 : 1;

  int _initialPrincipalTabIndex(String tab) {
    switch (tab.trim().toLowerCase()) {
      case 'review':
      case 'event_posts':
      case 'event_post':
      case 'approval':
      case 'approvals':
        return 0;
      case 'create':
        return 1;
      case 'manage':
      case 'posts':
        return 2;
      case 'auto':
      default:
        return widget.args.referenceId.isNotEmpty ? 0 : 2;
    }
  }

  void _onNotificationChanged() {
    _scheduleRefresh();
  }

  void _scheduleRefresh() {
    _refreshDebounceTimer?.cancel();
    _refreshDebounceTimer = Timer(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      unawaited(_loadPosts(showSpinner: false));
      if (widget.principalMode) {
        unawaited(_loadReviewPosts(showSpinner: false));
      }
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(
      length: widget.principalMode ? 3 : 2,
      initialIndex: widget.principalMode
          ? _initialPrincipalTabIndex(widget.args.initialTab)
          : 0,
      vsync: this,
    );
    _tabController.addListener(() {
      if (_tabController.index == _manageTabIndex) {
        _loadPosts(showSpinner: false);
      }
      if (widget.principalMode && _tabController.index == 0) {
        _loadReviewPosts(showSpinner: false);
      }
    });
    NotificationService.getInstance().then((s) {
      if (!mounted) return;
      _notificationService = s;
      s.addListener(_onNotificationChanged);
    });
    _pollingTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted && !_loading) {
        _scheduleRefresh();
      }
    });
    _loadPosts();
    if (widget.principalMode) {
      _loadReviewPosts();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollingTimer?.cancel();
    _refreshDebounceTimer?.cancel();
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
      _scheduleRefresh();
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
      final optimized = await ImageUploadOptimizer.fromXFile(
        xfile,
        preset: ImageUploadPreset.content,
      );
      await _uploadFile(
        xfile.path,
        optimized.filename,
        mimeType: optimized.mimeType,
        fileBytes: optimized.bytes,
      );
    }
  }

  Future<void> _pickVideo() async {
    final video = await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (video == null) return;
    await _uploadFile(video.path, video.name, mimeType: video.mimeType);
  }

  Future<void> _uploadFile(
    String path,
    String name, {
    String? mimeType,
    Uint8List? fileBytes,
  }) async {
    setState(() => _uploading = true);
    try {
      final url = await BackendApiClient.instance.uploadFile(
        path,
        filename: name,
        fileBytes: fileBytes,
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
    if (_postsRequestInFlight) return;
    _postsRequestInFlight = true;
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
    } finally {
      _postsRequestInFlight = false;
    }
  }

  Future<void> _loadReviewPosts({bool showSpinner = true}) async {
    if (!widget.principalMode) return;
    if (_reviewRequestInFlight) return;
    _reviewRequestInFlight = true;
    if (showSpinner) {
      setState(() {
        _reviewLoading = true;
        _reviewError = null;
      });
    } else if (mounted) {
      setState(() => _reviewRefreshing = true);
    }
    try {
      final pending = await BackendApiClient.instance.getPendingEventPosts();
      Map<String, dynamic>? referenced;
      final referenceId = widget.args.referenceId.trim();
      if (referenceId.isNotEmpty) {
        try {
          referenced = await BackendApiClient.instance.getEventPost(
            referenceId,
          );
        } on Object catch (_) {}
      }
      final rows = pending
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
      if (referenced != null &&
          !rows.any((row) => row['id']?.toString() == referenceId)) {
        rows.insert(0, referenced);
      }
      if (!mounted) return;
      setState(() {
        _reviewPosts = rows;
        _referencedReviewPost = referenced;
        _reviewLoading = false;
        _reviewRefreshing = false;
        _reviewError = null;
        _viewedAttachmentPostIds.removeWhere(
          (postId) => !rows.any((post) => post['id']?.toString() == postId),
        );
      });
      _resolvePrincipalInitialTab(rows.length);
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _reviewLoading = false;
        _reviewRefreshing = false;
        _reviewError = 'Failed to load school post approvals: $e';
      });
    } finally {
      _reviewRequestInFlight = false;
    }
  }

  void _resolvePrincipalInitialTab(int pendingCount) {
    if (!widget.principalMode) return;
    final initialTab = widget.args.initialTab.trim().toLowerCase();
    if (widget.args.referenceId.isNotEmpty || initialTab != 'auto') return;
    final targetIndex = pendingCount > 0 ? 0 : 2;
    if (_tabController.index == targetIndex) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _tabController.animateTo(targetIndex);
    });
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
        _tabController.animateTo(_manageTabIndex);
      });
      unawaited(_loadPosts(showSpinner: false));
      if (widget.principalMode) {
        unawaited(_loadReviewPosts(showSpinner: false));
      }
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
      _tabController.animateTo(widget.principalMode ? 1 : 0);
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
      if (widget.principalMode) {
        unawaited(_loadReviewPosts(showSpinner: false));
      }
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
    if (widget.principalMode) return _buildPrincipalWorkspace();
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

  Widget _buildPrincipalWorkspace() {
    return SchoolDeskModuleScaffold(
      title: 'School Posts',
      actions: [
        IconButton(
          tooltip: 'Refresh school posts',
          onPressed: (_loading || _reviewRefreshing)
              ? null
              : () {
                  _loadPosts(showSpinner: false);
                  _loadReviewPosts(showSpinner: false);
                },
          icon: _reviewRefreshing
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh_rounded),
        ),
      ],
      body: Column(
        children: [
          TabBar(
            controller: _tabController,
            labelColor: context.appTheme.primary,
            unselectedLabelColor: context.appTheme.onSurface.withOpacity(0.6),
            tabs: [
              Tab(
                text: 'Review',
                icon: Badge(
                  isLabelVisible: _reviewPosts.isNotEmpty,
                  label: Text(_reviewPosts.length.toString()),
                  child: const Icon(Icons.fact_check_rounded),
                ),
              ),
              const Tab(text: 'Create', icon: Icon(Icons.add_box)),
              const Tab(text: 'Manage', icon: Icon(Icons.history)),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildReviewList(),
                _buildCreateForm(),
                _buildStatusList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewList() {
    if (_reviewLoading && _reviewPosts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_reviewError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _reviewError!,
                textAlign: TextAlign.center,
                style: TextStyle(color: context.appTheme.error),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _loadReviewPosts,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    if (_reviewPosts.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('No school posts are waiting for review.'),
        ),
      );
    }
    final referencedId = widget.args.referenceId.trim();
    Map<String, dynamic>? referenced = _referencedReviewPost;
    if (referencedId.isNotEmpty) {
      for (final post in _reviewPosts) {
        if (post['id']?.toString() == referencedId) {
          referenced = post;
          break;
        }
      }
    }
    final referencedPostId = referenced?['id']?.toString();
    final remaining = referencedPostId == null
        ? _reviewPosts
        : _reviewPosts
              .where((post) => post['id']?.toString() != referencedPostId)
              .toList();

    return RefreshIndicator(
      onRefresh: () => _loadReviewPosts(showSpinner: false),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          if (referenced != null) ...[
            Text(
              'Opened request',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            _buildReviewPostCard(referenced, highlighted: true),
            const SizedBox(height: 20),
          ],
          Text(
            referenced == null ? 'Pending review' : 'Other pending posts',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          if (remaining.isEmpty)
            const Text('No other school posts are waiting for review.')
          else
            ...remaining.map(_buildReviewPostCard),
        ],
      ),
    );
  }

  Widget _buildReviewPostCard(
    Map<String, dynamic> post, {
    bool highlighted = false,
  }) {
    final attachments = EventPostMediaItem.parseList(post['media_urls']);
    final postId = (post['id'] ?? '').toString().trim();
    final status = (post['approval_status'] ?? post['status'] ?? 'pending')
        .toString();
    final destinations = _labels(post['destinations']);
    return Card(
      elevation: highlighted ? 1 : 0,
      color: highlighted
          ? context.appTheme.primary.withOpacity(0.06)
          : context.appTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: highlighted
              ? context.appTheme.primary.withOpacity(0.35)
              : context.appTheme.outlineVariant,
        ),
      ),
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    (post['title'] ?? 'Untitled school post').toString(),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _reviewStatusChip(status),
              ],
            ),
            if ((post['description'] ?? post['body'] ?? '')
                .toString()
                .trim()
                .isNotEmpty) ...[
              const SizedBox(height: 10),
              Text((post['description'] ?? post['body']).toString()),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                _reviewMetaChip(
                  Icons.calendar_today_outlined,
                  _dateInputText(post['event_date']).isEmpty
                      ? 'No date'
                      : _dateInputText(post['event_date']),
                ),
                if (destinations.isNotEmpty)
                  _reviewMetaChip(
                    Icons.place_outlined,
                    destinations.join(', '),
                  ),
              ],
            ),
            _buildReviewAttachmentSection(attachments, postId: postId),
            _buildReviewActions(post),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewAttachmentSection(
    List<EventPostMediaItem> attachments, {
    required String postId,
  }) {
    if (attachments.isEmpty) return const SizedBox(height: 14);
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Attachments',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: attachments
                .map(
                  (attachment) => SizedBox(
                    width: attachment.isVideo ? 220 : 132,
                    child: InkWell(
                      onTap: () =>
                          _openAttachmentPreview(attachment, postId: postId),
                      borderRadius: BorderRadius.circular(10),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: EventPostMediaPreview(
                          item: attachment,
                          height: attachment.isVideo ? 124 : 96,
                          compact: true,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewActions(Map<String, dynamic> post) {
    final id = (post['id'] ?? '').toString();
    final status = (post['approval_status'] ?? post['status'] ?? '')
        .toString()
        .toLowerCase();
    final requiresDecision = status == 'pending' || status == 'submitted';
    final attachments = EventPostMediaItem.parseList(post['media_urls']);
    final requiresView = attachments.isNotEmpty;
    final hasViewed = !requiresView || _viewedAttachmentPostIds.contains(id);
    return Wrap(
      alignment: WrapAlignment.end,
      spacing: 10,
      runSpacing: 10,
      children: [
        OutlinedButton.icon(
          onPressed: id.isEmpty
              ? null
              : () => _startEditingPost(Map<String, dynamic>.from(post)),
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Edit'),
        ),
        OutlinedButton.icon(
          onPressed: id.isEmpty
              ? null
              : () => _deletePost(Map<String, dynamic>.from(post)),
          style: OutlinedButton.styleFrom(
            foregroundColor: context.appTheme.error,
            side: BorderSide(color: context.appTheme.error),
          ),
          icon: const Icon(Icons.delete_outline_rounded),
          label: const Text('Delete'),
        ),
        if (requiresDecision)
          OutlinedButton.icon(
            onPressed: id.isEmpty ? null : () => _rejectReviewPost(id),
            style: OutlinedButton.styleFrom(
              foregroundColor: context.appTheme.error,
              side: BorderSide(color: context.appTheme.error),
            ),
            icon: const Icon(Icons.close_rounded),
            label: const Text('Reject'),
          ),
        if (requiresDecision)
          FilledButton.icon(
            onPressed: id.isEmpty || !hasViewed
                ? null
                : () => _approveReviewPost(id),
            icon: const Icon(Icons.check_rounded),
            label: const Text('Approve'),
          ),
        if (requiresDecision && requiresView && !hasViewed)
          Text(
            'Open an attachment preview before approving.',
            style: TextStyle(
              fontSize: 12,
              color: context.appTheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }

  Future<void> _approveReviewPost(String id) async {
    try {
      await BackendApiClient.instance.approveEventPost(id);
      await _loadReviewPosts(showSpinner: false);
      await _loadPosts(showSpinner: false);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('School post approved.')));
    } on Object catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to approve: $e')));
    }
  }

  Future<void> _rejectReviewPost(String id) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        String? validationError;
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Reject School Post'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Add a reason for the teacher before rejecting this request.',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonController,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Rejection Reason *',
                    border: const OutlineInputBorder(),
                    errorText: validationError,
                  ),
                  maxLines: 3,
                  onChanged: (_) {
                    if (validationError != null) {
                      setDialogState(() => validationError = null);
                    }
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  if (reasonController.text.trim().isEmpty) {
                    setDialogState(
                      () => validationError = 'A rejection reason is required.',
                    );
                    return;
                  }
                  Navigator.pop(dialogContext, true);
                },
                child: const Text('Reject'),
              ),
            ],
          ),
        );
      },
    );
    final reason = reasonController.text.trim();
    reasonController.dispose();
    if (confirmed != true || reason.isEmpty) return;
    try {
      await BackendApiClient.instance.rejectEventPost(id, reason: reason);
      await _loadReviewPosts(showSpinner: false);
      await _loadPosts(showSpinner: false);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('School post rejected.')));
    } on Object catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to reject: $e')));
    }
  }

  Future<void> _openAttachmentPreview(
    EventPostMediaItem attachment, {
    required String postId,
  }) async {
    await openEventPostMediaPreview(context, attachment);
    if (postId.isNotEmpty && mounted) {
      setState(() => _viewedAttachmentPostIds.add(postId));
    }
  }

  Widget _reviewStatusChip(String status) {
    final normalized = status.toLowerCase();
    final color = switch (normalized) {
      'approved' => Colors.green,
      'rejected' => Colors.red,
      'pending' || 'submitted' => Colors.orange,
      _ => Colors.grey,
    };
    return Chip(
      label: Text(
        normalized.toUpperCase(),
        style: const TextStyle(color: Colors.white, fontSize: 11),
      ),
      backgroundColor: color,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: EdgeInsets.zero,
    );
  }

  Widget _reviewMetaChip(IconData icon, String label) {
    return Chip(
      avatar: Icon(icon, size: 16, color: context.appTheme.onSurfaceVariant),
      label: Text(
        label,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: context.appTheme.onSurface,
        ),
      ),
      backgroundColor: context.appTheme.surface,
      side: BorderSide(color: context.appTheme.outlineVariant),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
