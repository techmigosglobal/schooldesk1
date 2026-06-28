import 'package:flutter/material.dart';

import 'package:schooldesk1/core/widgets/erp_module_scaffold.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/utils/extensions.dart';
import 'package:schooldesk1/core/widgets/empty_state_widget.dart';
import 'package:schooldesk1/core/utils/event_post_media_parser.dart';
import 'package:url_launcher/url_launcher.dart';

class PrincipalEventApprovalScreen extends StatefulWidget {
  const PrincipalEventApprovalScreen({super.key});

  @override
  State<PrincipalEventApprovalScreen> createState() =>
      _PrincipalEventApprovalScreenState();
}

class _PrincipalEventApprovalScreenState
    extends State<PrincipalEventApprovalScreen> {
  List<dynamic> _posts = [];
  bool _loading = true;
  String? _error;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  Future<void> _loadPosts() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final posts = await BackendApiClient.instance.getPendingEventPosts();
      if (!mounted) return;
      setState(() {
        _posts = posts;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load event posts: $e';
      });
    }
  }

  Future<void> _approveStatus(String id) async {
    try {
      await BackendApiClient.instance.approveEventPost(id);
      _changed = true;
      await _loadPosts();
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
        return StatefulBuilder(
          builder: (context, setDialogState) {
            String? validationError;
            return AlertDialog(
              title: const Text('Reject Event Post'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Please provide a reason for rejection. This will be visible to the teacher.',
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
        _changed = true;
        await _loadPosts();
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
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(
                child: Text(
                  _error!,
                  style: TextStyle(color: context.appTheme.error),
                ),
              )
            : _posts.isEmpty
            ? _buildEmptyState()
            : ListView.builder(
                padding: const EdgeInsets.all(24.0),
                itemCount: _posts.length,
                itemBuilder: (context, index) {
                  final post = _posts[index];
                  final destinations = _labels(post['destinations']);
                  final mediaUrls = parseEventPostMediaUrls(post['media_urls']);
                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: ListTile(
                      title: Text(post['title'] ?? 'No Title'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if ((post['description'] ?? '').isNotEmpty)
                            Text('${post['description']}\n'),
                          Text(
                            'Destinations: ${destinations.isEmpty ? 'None' : destinations.join(', ')}',
                          ),
                          if (mediaUrls.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: mediaUrls.map((url) {
                                final isImage = _isImage(url);
                                if (isImage) {
                                  return GestureDetector(
                                    onTap: () => launchUrl(Uri.parse(url)),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        url,
                                        height: 150,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                                      ),
                                    ),
                                  );
                                }
                                return OutlinedButton.icon(
                                  onPressed: () => launchUrl(Uri.parse(url)),
                                  icon: const Icon(Icons.attachment, size: 16),
                                  label: const Text('View Attachment'),
                                );
                              }).toList(),
                            ),
                          ],
                        ],
                      ),
                      trailing: post['approval_status'] == 'pending'
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.check,
                                    color: Colors.green,
                                  ),
                                  onPressed: () => _approveStatus(post['id']),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.close,
                                    color: Colors.red,
                                  ),
                                  onPressed: () => _rejectStatus(post['id']),
                                ),
                              ],
                            )
                          : null,
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return RefreshIndicator(
      onRefresh: _loadPosts,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 80),
          const EmptyStateWidget(
            icon: Icons.fact_check_outlined,
            title: 'No event approvals pending',
            description:
                'Teacher and staff event posts that need Principal review will appear here. Pull down or tap refresh to check again.',
          ),
          const SizedBox(height: 18),
          Center(
            child: OutlinedButton.icon(
              onPressed: _loadPosts,
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

  bool _isImage(String url) {
    final lower = url.toLowerCase();
    return lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.webp');
  }
}
