import 'dart:async';

import 'package:flutter/material.dart';

import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/services/notification_service.dart';
import 'package:schooldesk1/core/utils/event_post_media_parser.dart';
import 'package:schooldesk1/core/utils/extensions.dart';
import 'package:schooldesk1/core/widgets/empty_state_widget.dart';
import 'package:schooldesk1/core/widgets/event_post_media_preview.dart';
import 'package:schooldesk1/core/widgets/erp_module_scaffold.dart';

class EventApprovalRouteArgs {
  final String initialPostId;
  final String referenceType;
  final String initialTab;

  const EventApprovalRouteArgs({
    this.initialPostId = '',
    this.referenceType = '',
    this.initialTab = '',
  });

  static EventApprovalRouteArgs fromRoute(Object? raw) {
    if (raw is EventApprovalRouteArgs) return raw;
    if (raw is Map) {
      return EventApprovalRouteArgs(
        initialPostId: (raw['referenceId'] ?? raw['reference_id'] ?? '')
            .toString()
            .trim(),
        referenceType: (raw['referenceType'] ?? raw['reference_type'] ?? '')
            .toString()
            .trim(),
        initialTab: (raw['initialTab'] ?? raw['initial_tab'] ?? '')
            .toString()
            .trim(),
      );
    }
    return const EventApprovalRouteArgs();
  }
}

class PrincipalEventApprovalScreen extends StatefulWidget {
  final EventApprovalRouteArgs args;

  const PrincipalEventApprovalScreen({
    super.key,
    this.args = const EventApprovalRouteArgs(),
  });

  @override
  State<PrincipalEventApprovalScreen> createState() =>
      _PrincipalEventApprovalScreenState();
}

class _PrincipalEventApprovalScreenState
    extends State<PrincipalEventApprovalScreen>
    with WidgetsBindingObserver {
  static const List<String> _destinationOptions = <String>[
    'PARENTS_HOME',
    'SCHOOL_GALLERY',
    'SCHOOL_LANDING',
  ];
  final List<Map<String, dynamic>> _posts = [];
  final Set<String> _viewedAttachmentPostIds = <String>{};
  Map<String, dynamic>? _selectedPost;
  NotificationService? _notificationService;
  Timer? _pollingTimer;
  bool _loading = true;
  bool _refreshing = false;
  String? _error;

  String get initialPostId => widget.args.initialPostId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    NotificationService.getInstance().then((service) {
      if (!mounted) return;
      _notificationService = service;
      service.addListener(_onNotificationChanged);
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
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_loadPosts(showSpinner: false));
    }
  }

  void _onNotificationChanged() {
    unawaited(_loadPosts(showSpinner: false));
  }

  Future<void> _loadPosts({
    bool showSpinner = true,
    Map<String, dynamic>? keepPost,
  }) async {
    if (showSpinner) {
      setState(() {
        _loading = true;
        _error = null;
      });
    } else if (mounted) {
      setState(() => _refreshing = true);
    }

    try {
      final posts = await BackendApiClient.instance.getPrincipalEventPosts();
      Map<String, dynamic>? target;
      final keepPostId = keepPost?['id']?.toString().trim() ?? '';
      final targetPostId = initialPostId.isNotEmpty
          ? initialPostId
          : keepPostId;
      if (targetPostId.isNotEmpty) {
        try {
          target = await BackendApiClient.instance.getEventPost(targetPostId);
        } on Object catch (_) {
          target = keepPost;
        }
      }

      final merged = <Map<String, dynamic>>[
        ...posts.map((row) => Map<String, dynamic>.from(row)),
      ];
      if (target != null &&
          !merged.any(
            (post) => post['id']?.toString() == target!['id']?.toString(),
          )) {
        merged.insert(0, target);
      }

      if (!mounted) return;
      setState(() {
        _posts
          ..clear()
          ..addAll(merged);
        _selectedPost = target;
        _viewedAttachmentPostIds.removeWhere(
          (postId) => !_posts.any((post) => post['id']?.toString() == postId),
        );
        _loading = false;
        _refreshing = false;
        _error = null;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _refreshing = false;
        _error = 'Failed to load event approvals: $e';
      });
    }
  }

  Future<void> _notifyAndReload({Map<String, dynamic>? keepPost}) async {
    try {
      await BackendApiClient.instance.invalidateCachedReads();
    } on Object catch (_) {
      // The write already succeeded; do not let cache cleanup blank the screen.
    }
    try {
      final service = await NotificationService.getInstance();
      await service.refresh();
    } on Object catch (_) {
      // Approval state reload below is the source of truth for this screen.
    }
    await _loadPosts(showSpinner: false, keepPost: keepPost);
  }

  Future<void> _approveStatus(String id) async {
    try {
      await BackendApiClient.instance.approveEventPost(id);
      await _notifyAndReload();
    } on Object catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to approve: $e')));
    }
  }

  Future<void> _rejectStatus(String id) async {
    final reasonController = TextEditingController();
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        String? validationError;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Reject Event Post'),
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
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    if (reasonController.text.trim().isEmpty) {
                      setDialogState(
                        () =>
                            validationError = 'A rejection reason is required.',
                      );
                      return;
                    }
                    Navigator.pop(context, true);
                  },
                  child: const Text('Reject'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed == true && reasonController.text.trim().isNotEmpty) {
      try {
        await BackendApiClient.instance.rejectEventPost(
          id,
          reason: reasonController.text.trim(),
        );
        await _notifyAndReload();
      } on Object catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to reject: $e')));
      }
    }
  }

  Future<void> _editPost(Map<String, dynamic> post) async {
    final id = (post['id'] ?? '').toString().trim();
    if (id.isEmpty) return;

    final titleController = TextEditingController(
      text: (post['title'] ?? '').toString(),
    );
    final descriptionController = TextEditingController(
      text: (post['description'] ?? '').toString(),
    );
    final dateController = TextEditingController(
      text: _dateInputText(post['event_date']),
    );
    final mediaItems = EventPostMediaItem.parseList(post['media_urls']);
    final selectedDestinations = _labels(post['destinations']).toSet();

    bool deleted = false;
    Map<String, dynamic>? updatedPost;
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        String? validationError;
        bool saving = false;
        bool deleting = false;

        Future<void> saveChanges(StateSetter setDialogState) async {
          if (titleController.text.trim().isEmpty) {
            setDialogState(() => validationError = 'Title is required.');
            return;
          }
          if (selectedDestinations.isEmpty) {
            setDialogState(
              () => validationError = 'Select at least one destination.',
            );
            return;
          }

          setDialogState(() {
            saving = true;
            validationError = null;
          });

          try {
            final rawDate = dateController.text.trim();
            final eventDate = rawDate.isEmpty
                ? DateTime.now().toIso8601String()
                : '${rawDate}T00:00:00Z';
            updatedPost = await BackendApiClient.instance.updateEventPost(
              id: id,
              title: titleController.text.trim(),
              description: descriptionController.text.trim(),
              eventDate: eventDate,
              mediaUrls: mediaItems.map((item) => item.url).toList(),
              media: mediaItems,
              destinations: selectedDestinations.toList(),
              isSubmit: true,
              sectionId: post['section_id']?.toString(),
            );
            if (dialogContext.mounted) Navigator.of(dialogContext).pop(true);
          } on Object catch (e) {
            if (!dialogContext.mounted) return;
            setDialogState(() {
              saving = false;
              validationError = 'Failed to save changes: $e';
            });
          }
        }

        Future<void> deletePost(StateSetter setDialogState) async {
          final confirmed = await showDialog<bool>(
            context: dialogContext,
            builder: (confirmContext) => AlertDialog(
              title: const Text('Delete Event Post'),
              content: const Text(
                'This will permanently remove the submitted post. Continue?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(confirmContext, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(confirmContext, true),
                  child: const Text('Delete'),
                ),
              ],
            ),
          );
          if (confirmed != true) return;

          setDialogState(() {
            deleting = true;
            validationError = null;
          });

          try {
            await BackendApiClient.instance.deleteEventPost(id);
            deleted = true;
            if (dialogContext.mounted) Navigator.of(dialogContext).pop(true);
          } on Object catch (e) {
            if (!dialogContext.mounted) return;
            setDialogState(() {
              deleting = false;
              validationError = 'Failed to delete post: $e';
            });
          }
        }

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Edit Event Post'),
              content: SizedBox(
                width: 560,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (validationError != null) ...[
                        Text(
                          validationError!,
                          style: TextStyle(color: context.appTheme.error),
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextField(
                        controller: titleController,
                        decoration: const InputDecoration(
                          labelText: 'Title *',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          border: OutlineInputBorder(),
                        ),
                        minLines: 3,
                        maxLines: 5,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: dateController,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Event Date',
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.calendar_today_outlined),
                        ),
                        onTap: () async {
                          final initial = _parseDate(dateController.text);
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: initial ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2035),
                          );
                          if (picked != null) {
                            dateController.text =
                                '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                            setDialogState(() => validationError = null);
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Destinations',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ..._destinationOptions.map(
                        (option) => CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          value: selectedDestinations.contains(option),
                          title: Text(_destinationLabel(option)),
                          onChanged: saving || deleting
                              ? null
                              : (selected) {
                                  setDialogState(() {
                                    if (selected ?? false) {
                                      selectedDestinations.add(option);
                                    } else {
                                      selectedDestinations.remove(option);
                                    }
                                    validationError = null;
                                  });
                                },
                        ),
                      ),
                      if (mediaItems.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Existing attachments stay attached to this post.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving || deleting
                      ? null
                      : () => deletePost(setDialogState),
                  style: TextButton.styleFrom(
                    foregroundColor: context.appTheme.error,
                  ),
                  child: deleting
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Delete'),
                ),
                TextButton(
                  onPressed: saving || deleting
                      ? null
                      : () => Navigator.pop(dialogContext, false),
                  style: TextButton.styleFrom(
                    foregroundColor: context.appTheme.primary,
                  ),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: saving || deleting
                      ? null
                      : () => saveChanges(setDialogState),
                  style: FilledButton.styleFrom(
                    backgroundColor: context.appTheme.primary,
                    foregroundColor: context.appTheme.onPrimary,
                  ),
                  child: saving
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    final editedPost = deleted
        ? null
        : <String, dynamic>{
            ...post,
            if (updatedPost != null) ...updatedPost!,
            'id': id,
            'title': titleController.text.trim(),
            'description': descriptionController.text.trim(),
            'body': descriptionController.text.trim(),
            'event_date': dateController.text.trim().isEmpty
                ? post['event_date']
                : '${dateController.text.trim()}T00:00:00Z',
            'destinations': selectedDestinations.toList(),
            'approval_status': 'pending',
            'status': 'pending',
          };

    titleController.dispose();
    descriptionController.dispose();
    dateController.dispose();

    if (saved == true) {
      if (!deleted && editedPost != null && mounted) {
        setState(() {
          final index = _posts.indexWhere(
            (item) => item['id']?.toString() == id,
          );
          if (index == -1) {
            _posts.insert(0, editedPost);
          } else {
            _posts[index] = editedPost;
          }
          _selectedPost = editedPost;
          _loading = false;
          _refreshing = false;
          _error = null;
        });
      }
      if (!mounted) return;
      await _notifyAndReload(keepPost: editedPost);
      if (!mounted) return;
      final message = deleted
          ? 'Event post deleted.'
          : 'Event post updated. You can approve it when ready.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SchoolDeskModuleScaffold(
      title: 'School Posts',
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: _refreshing ? null : () => _loadPosts(showSpinner: false),
          icon: _refreshing
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh_rounded),
        ),
      ],
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _buildErrorState()
          : _buildApprovalBody(),
    );
  }

  Widget _buildApprovalBody() {
    final selectedId = _selectedPost?['id']?.toString();
    final remainingPosts = _posts
        .where((post) => post['id']?.toString() != selectedId)
        .toList();

    if (_selectedPost == null && remainingPosts.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: () => _loadPosts(showSpinner: false),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          if (_selectedPost != null) ...[
            Text(
              'Opened request',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            _buildPostCard(_selectedPost!, highlighted: true),
            const SizedBox(height: 20),
          ],
          Text(
            _selectedPost == null ? 'All school posts' : 'Other school posts',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          if (remainingPosts.isEmpty)
            _buildInlineNotice(
              _selectedPost == null
                  ? 'No school posts have been created yet.'
                  : 'No other school posts are available.',
            )
          else
            ...remainingPosts.map(_buildPostCard),
        ],
      ),
    );
  }

  Widget _buildPostCard(Map<String, dynamic> post, {bool highlighted = false}) {
    final attachments = EventPostMediaItem.parseList(post['media_urls']);
    final postId = (post['id'] ?? '').toString().trim();
    final status = (post['approval_status'] ?? 'draft').toString();
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
                    (post['title'] ?? 'Untitled event post').toString(),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _statusChip(status),
              ],
            ),
            if ((post['description'] ?? '').toString().trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(post['description'].toString()),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                _metaChip(
                  Icons.calendar_today_outlined,
                  _dateLabel(post['event_date']),
                ),
                if (destinations.isNotEmpty)
                  _metaChip(Icons.place_outlined, destinations.join(', ')),
              ],
            ),
            _buildAttachmentSection(attachments, postId: postId),
            _buildDecisionActions(post),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentSection(
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
            children: attachments.map((attachment) {
              if (attachment.isImage) {
                return InkWell(
                  onTap: () =>
                      _openAttachmentPreview(attachment, postId: postId),
                  borderRadius: BorderRadius.circular(10),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      resolveEventPostMediaUrl(attachment.url),
                      width: 132,
                      height: 96,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _fileTile(attachment, postId: postId),
                    ),
                  ),
                );
              }
              if (attachment.isVideo) {
                return SizedBox(
                  width: 220,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: EventPostMediaPreview(
                      item: attachment,
                      height: 124,
                      compact: true,
                    ),
                  ),
                );
              }
              return _fileTile(attachment, postId: postId);
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _fileTile(EventPostMediaItem attachment, {required String postId}) {
    return SizedBox(
      width: 220,
      child: OutlinedButton.icon(
        onPressed: () => _openAttachmentPreview(attachment, postId: postId),
        icon: Icon(
          attachment.isPdf
              ? Icons.picture_as_pdf_outlined
              : Icons.insert_drive_file_outlined,
          size: 18,
        ),
        label: Text(
          attachment.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildDecisionActions(Map<String, dynamic> post) {
    final id = (post['id'] ?? '').toString();
    final status = (post['approval_status'] ?? '').toString().toLowerCase();
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
          onPressed: id.isEmpty ? null : () => _editPost(post),
          style: OutlinedButton.styleFrom(
            foregroundColor: context.appTheme.primary,
            side: BorderSide(color: context.appTheme.primary),
          ),
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Edit'),
        ),
        OutlinedButton.icon(
          onPressed: id.isEmpty ? null : () => _deletePost(post),
          style: OutlinedButton.styleFrom(
            foregroundColor: context.appTheme.error,
            side: BorderSide(color: context.appTheme.error),
          ),
          icon: const Icon(Icons.delete_outline_rounded),
          label: const Text('Delete'),
        ),
        if (requiresDecision)
          OutlinedButton.icon(
            onPressed: id.isEmpty ? null : () => _rejectStatus(id),
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
                : () => _approveStatus(id),
            style: FilledButton.styleFrom(
              backgroundColor: context.appTheme.primary,
              foregroundColor: context.appTheme.onPrimary,
              disabledForegroundColor: context.appTheme.onSurfaceVariant,
            ),
            icon: const Icon(Icons.check_rounded),
            label: const Text('Approve'),
          ),
        if (requiresDecision && requiresView && !hasViewed)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              'Open an attachment preview before approving.',
              style: TextStyle(
                fontSize: 12,
                color: context.appTheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _deletePost(Map<String, dynamic> post) async {
    final id = (post['id'] ?? '').toString().trim();
    if (id.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete school post?'),
        content: Text(
          '“${(post['title'] ?? 'This post').toString()}” will be removed from every school surface.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: context.appTheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await BackendApiClient.instance.deleteEventPost(id);
      if (!mounted) return;
      setState(() {
        _posts.removeWhere((item) => item['id']?.toString() == id);
        if (_selectedPost?['id']?.toString() == id) _selectedPost = null;
      });
      await _notifyAndReload();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('School post deleted.')));
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to delete post: $error')));
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

  Widget _statusChip(String status) {
    final normalized = status.toLowerCase();
    final color = switch (normalized) {
      'approved' => Colors.green,
      'rejected' => Colors.red,
      'pending' => Colors.orange,
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

  Widget _metaChip(IconData icon, String label) {
    final colors = context.appTheme;
    return Chip(
      avatar: Icon(icon, size: 16, color: colors.onSurfaceVariant),
      label: Text(
        label,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: colors.onSurface,
        ),
      ),
      backgroundColor: colors.surface,
      side: BorderSide(color: colors.outlineVariant),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }

  Widget _buildInlineNotice(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: context.appTheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(message),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: TextStyle(color: context.appTheme.error)),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _loadPosts,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return RefreshIndicator(
      onRefresh: () => _loadPosts(showSpinner: false),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 80),
          const EmptyStateWidget(
            icon: Icons.fact_check_outlined,
            title: 'No event approvals pending',
            description:
                'Teacher event posts that need Principal review will appear here. Pull down or tap refresh to check again.',
          ),
          const SizedBox(height: 18),
          Center(
            child: OutlinedButton.icon(
              onPressed: () => _loadPosts(showSpinner: false),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Refresh'),
            ),
          ),
        ],
      ),
    );
  }

  List<String> _labels(dynamic raw) {
    if (raw == null) return const [];
    if (raw is List) {
      return raw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    }
    final text = raw.toString().trim();
    if (text.isEmpty || text.toLowerCase() == 'null') return const [];
    return text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  String _dateLabel(dynamic value) {
    final text = value?.toString() ?? '';
    if (text.length >= 10) return text.substring(0, 10);
    return text.isEmpty ? 'No date' : text;
  }

  String _dateInputText(dynamic value) {
    final label = _dateLabel(value);
    return label == 'No date' ? '' : label;
  }

  DateTime? _parseDate(String value) {
    if (value.trim().isEmpty) return null;
    return DateTime.tryParse(value.trim());
  }

  String _destinationLabel(String value) {
    switch (value) {
      case 'PARENTS_HOME':
        return 'Parents Home';
      case 'SCHOOL_GALLERY':
        return 'School Gallery';
      case 'SCHOOL_LANDING':
        return 'Public Landing Page';
      default:
        return value;
    }
  }
}
