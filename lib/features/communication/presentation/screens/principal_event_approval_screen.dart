import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

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
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        OutlinedButton.icon(
          onPressed: id.isEmpty ? null : () => _rejectStatus(id),
          icon: const Icon(Icons.close_rounded),
          label: const Text('Reject'),
        ),
        const SizedBox(width: 10),
        FilledButton.icon(
          onPressed: id.isEmpty ? null : () => _approveStatus(id),
          icon: const Icon(Icons.check_rounded),
          label: const Text('Approve'),
        ),
      ],
    );
  }

  Future<void> _openAttachmentPreview(EventPostMediaItem attachment) async {
    final url = resolveEventPostMediaUrl(attachment.url);
    if (attachment.isImage) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(dialogContext),
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
              Flexible(
                child: InteractiveViewer(
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Unable to load image preview.'),
                    ),
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => launchUrl(Uri.parse(url)),
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('Open'),
              ),
            ],
          ),
        ),
      );
      return;
    }
    if (attachment.isPdf) {
      try {
        final bytes = await _downloadAttachmentBytes(url);
        await Printing.layoutPdf(
          name: attachment.displayName,
          onLayout: (_) async => bytes,
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Unable to preview PDF: $e')));
      }
      return;
    }
    await launchUrl(Uri.parse(url));
  }

  Future<Uint8List> _downloadAttachmentBytes(String url) async {
    final response = await BackendApiClient.instance.dio.get<List<int>>(
      url,
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(response.data ?? const []);
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
}
