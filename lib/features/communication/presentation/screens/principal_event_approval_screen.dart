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
  Map<String, dynamic>? _selectedPost;
  NotificationService? _notificationService;
  Timer? _pollingTimer;
  bool _loading = true;
  bool _refreshing = false;
  String? _error;
  bool _changed = false;

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

  Future<void> _loadPosts({bool showSpinner = true}) async {
    if (showSpinner) {
      setState(() {
        _loading = true;
        _error = null;
      });
    } else if (mounted) {
      setState(() => _refreshing = true);
    }

    try {
      final pending = await BackendApiClient.instance.getPendingEventPosts();
      Map<String, dynamic>? target;
      if (initialPostId.isNotEmpty) {
        try {
          target = await BackendApiClient.instance.getEventPost(initialPostId);
        } catch (_) {
          target = null;
        }
      }

      final merged = <Map<String, dynamic>>[
        ...pending.map((row) => Map<String, dynamic>.from(row)),
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
        _loading = false;
        _refreshing = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _refreshing = false;
        _error = 'Failed to load event approvals: $e';
      });
    }
  }

  Future<void> _notifyAndReload() async {
    _changed = true;
    await BackendApiClient.instance.invalidateCachedReads();
    try {
      final service = await NotificationService.getInstance();
      await service.refresh();
    } catch (_) {
      // Approval state reload below is the source of truth for this screen.
    }
    await _loadPosts(showSpinner: false);
  }

  Future<void> _approveStatus(String id) async {
    try {
      await BackendApiClient.instance.approveEventPost(id);
      await _notifyAndReload();
    } catch (e) {
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
      } catch (e) {
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
    final dateController = TextEditingController(text: _dateLabel(post['event_date']));
    final mediaItems = EventPostMediaItem.parseList(post['media_urls']);
    final selectedDestinations = _labels(post['destinations']).toSet();

    bool deleted = false;
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
            await BackendApiClient.instance.updateEventPost(
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
          } catch (e) {
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
          } catch (e) {
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
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: saving || deleting
                      ? null
                      : () => saveChanges(setDialogState),
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

    titleController.dispose();
    descriptionController.dispose();
    dateController.dispose();

    if (saved == true) {
      await _notifyAndReload();
      if (!mounted) return;
      final message = deleted
          ? 'Event post deleted.'
          : 'Event post updated. You can approve it when ready.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_changed,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _changed) {
          _changed = false;
          Navigator.of(context).pop(true);
        }
      },
      child: SchoolDeskModuleScaffold(
        title: 'Event Approvals',
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refreshing
                ? null
                : () => _loadPosts(showSpinner: false),
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
      ),
    );
  }

  Widget _buildApprovalBody() {
    final selectedId = _selectedPost?['id']?.toString();
    final pending = _posts
        .where(
          (post) => (post['approval_status'] ?? '').toString() == 'pending',
        )
        .where((post) => post['id']?.toString() != selectedId)
        .toList();

    if (_selectedPost == null && pending.isEmpty) {
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
            'Pending requests',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          if (pending.isEmpty)
            _buildInlineNotice(
              _selectedPost == null
                  ? 'No event approvals pending.'
                  : 'No other event approvals pending.',
            )
          else
            ...pending.map(_buildPostCard),
        ],
      ),
    );
  }

  Widget _buildPostCard(Map<String, dynamic> post, {bool highlighted = false}) {
    final attachments = EventPostMediaItem.parseList(post['media_urls']);
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
            _buildAttachmentSection(attachments),
            _buildDecisionActions(post),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentSection(List<EventPostMediaItem> attachments) {
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
                  onTap: () => _openAttachmentPreview(attachment),
                  borderRadius: BorderRadius.circular(10),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      resolveEventPostMediaUrl(attachment.url),
                      width: 132,
                      height: 96,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _fileTile(attachment),
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
              return _fileTile(attachment);
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _fileTile(EventPostMediaItem attachment) {
    return SizedBox(
      width: 220,
      child: OutlinedButton.icon(
        onPressed: () => _openAttachmentPreview(attachment),
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
    if ((post['approval_status'] ?? '').toString() != 'pending') {
      return const SizedBox.shrink();
    }
    final id = (post['id'] ?? '').toString();
    return Wrap(
      alignment: WrapAlignment.end,
      spacing: 10,
      runSpacing: 10,
      children: [
        OutlinedButton.icon(
          onPressed: id.isEmpty ? null : () => _editPost(post),
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Edit'),
        ),
        OutlinedButton.icon(
          onPressed: id.isEmpty ? null : () => _rejectStatus(id),
          icon: const Icon(Icons.close_rounded),
          label: const Text('Reject'),
        ),
        FilledButton.icon(
          onPressed: id.isEmpty ? null : () => _approveStatus(id),
          icon: const Icon(Icons.check_rounded),
          label: const Text('Approve'),
        ),
      ],
    );
  }

  Future<void> _openAttachmentPreview(EventPostMediaItem attachment) async {
    await openEventPostMediaPreview(context, attachment);
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
    if (raw is List) {
      return raw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    }
    return raw
        .toString()
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
