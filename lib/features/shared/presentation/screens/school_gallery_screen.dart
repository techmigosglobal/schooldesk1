import 'package:flutter/material.dart';

import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/utils/event_post_media_parser.dart';
import 'package:schooldesk1/core/utils/extensions.dart';
import 'package:schooldesk1/core/widgets/event_post_media_preview.dart';
import 'package:schooldesk1/core/widgets/erp_components.dart';
import 'package:schooldesk1/core/widgets/erp_module_scaffold.dart';
import 'package:schooldesk1/routes/app_routes.dart';

class SchoolGalleryScreen extends StatefulWidget {
  const SchoolGalleryScreen({super.key});

  @override
  State<SchoolGalleryScreen> createState() => _SchoolGalleryScreenState();
}

class _SchoolGalleryScreenState extends State<SchoolGalleryScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _posts = const [];

  @override
  void initState() {
    super.initState();
    _loadGallery();
  }

  Future<void> _loadGallery() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final posts = await BackendApiClient.instance.getGalleryEventPosts();
      if (!mounted) return;
      setState(() {
        _posts = posts;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Unable to load the school gallery.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SchoolDeskModuleScaffold(
      title: 'School Gallery',
      subtitle: 'Approved event posts and photos',
      actions: [
        IconButton(
          tooltip: 'Refresh gallery',
          icon: const Icon(Icons.refresh_rounded),
          onPressed: _loadGallery,
        ),
      ],
      bodyIsScrollable: true,
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const SchoolDeskStatusPanel.loading(message: 'Loading gallery');
    }
    if (_error != null) {
      return SchoolDeskStatusPanel.error(
        title: 'Gallery unavailable',
        message: _error!,
        onAction: _loadGallery,
      );
    }
    if (_posts.isEmpty) {
      final role =
          BackendApiClient.instance.currentRoleName?.toLowerCase() ?? '';
      final actionLabel = role == 'teacher'
          ? 'Create Event Post'
          : role == 'principal'
          ? 'Review Event Approvals'
          : null;
      final actionRoute = role == 'teacher'
          ? AppRoutes.teacherEventPosts
          : role == 'principal'
          ? AppRoutes.principalEventApprovals
          : null;
      return SchoolDeskStatusPanel.empty(
        title: 'No gallery posts yet',
        message: 'Approved school gallery posts will appear here.',
        actionLabel: actionLabel,
        onAction: actionRoute != null
            ? () => Navigator.pushNamed(context, actionRoute)
            : null,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900
            ? 3
            : constraints.maxWidth >= 620
            ? 2
            : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _posts.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: columns == 1 ? 1.25 : 0.88,
          ),
          itemBuilder: (context, index) =>
              _GalleryPostCard(post: _posts[index]),
        );
      },
    );
  }
}

class _GalleryPostCard extends StatelessWidget {
  final Map<String, dynamic> post;

  const _GalleryPostCard({required this.post});

  @override
  Widget build(BuildContext context) {
    final mediaItems = EventPostMediaItem.parseList(post['media_urls']);
    final cover = mediaItems.firstWhere(
      (item) => item.isImage || item.isVideo,
      orElse: () => mediaItems.isEmpty
          ? const EventPostMediaItem(url: '')
          : mediaItems.first,
    );
    final title = _text(post['title'], fallback: 'School event');
    final description = _text(post['description']);
    final eventDate = _text(post['event_date']);

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: context.appTheme.outlineVariant),
      ),
      child: InkWell(
        onTap: () => _showDetails(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: cover.url.isEmpty
                  ? Container(
                      color: context.appTheme.panelMuted,
                      child: Icon(
                        Icons.photo_library_outlined,
                        size: 44,
                        color: context.appTheme.onSurfaceVariant,
                      ),
                    )
                  : EventPostMediaPreview(
                      item: cover,
                      height: double.infinity,
                      compact: true,
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description.isEmpty
                        ? 'Approved school gallery post'
                        : description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (eventDate.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.event_outlined, size: 15),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _formatEventDate(eventDate),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetails(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        final media = EventPostMediaItem.parseList(post['media_urls']);
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          minChildSize: 0.45,
          maxChildSize: 0.92,
          builder: (context, controller) => ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            children: [
              Text(
                _text(post['title'], fallback: 'School event'),
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                _text(post['description'], fallback: 'No description added.'),
              ),
              const SizedBox(height: 16),
              for (final item in media)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: EventPostMediaPreview(item: item, height: 220),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

String _formatEventDate(String raw) {
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return raw;
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${parsed.day} ${months[parsed.month - 1]} ${parsed.year}';
}

String _text(dynamic value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}
