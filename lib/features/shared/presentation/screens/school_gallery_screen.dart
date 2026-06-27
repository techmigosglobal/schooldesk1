import 'package:flutter/material.dart';

import 'package:schooldesk1/core/config/env_config.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/utils/event_post_media_parser.dart';
import 'package:schooldesk1/core/utils/extensions.dart';
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
      final canCreate = role == 'teacher' || role == 'principal';
      return SchoolDeskStatusPanel.empty(
        title: 'No gallery posts yet',
        message: 'Approved school gallery posts will appear here.',
        actionLabel: canCreate ? 'Create Event Post' : null,
        onAction: canCreate
            ? () => Navigator.pushNamed(context, AppRoutes.teacherEventPosts)
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
    final media = firstEventPostMediaUrl(post['media_urls']);
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
              child: media.isEmpty
                  ? Container(
                      color: context.appTheme.panelMuted,
                      child: Icon(
                        Icons.photo_library_outlined,
                        size: 44,
                        color: context.appTheme.onSurfaceVariant,
                      ),
                    )
                  : Image.network(
                      _assetUrl(media),
                      fit: BoxFit.cover,
                      width: double.infinity,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          color: context.appTheme.panelMuted,
                          child: Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                  : null,
                              strokeWidth: 2,
                            ),
                          ),
                        );
                      },
                      errorBuilder: (_, __, ___) => Container(
                        color: context.appTheme.panelMuted,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.broken_image_outlined,
                              color: context.appTheme.onSurfaceVariant,
                              size: 32,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Image unavailable',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: context.appTheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
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
        final media = parseEventPostMediaUrls(post['media_urls']);
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
              for (final url in media)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _isImageUrl(url)
                        ? Image.network(
                            _assetUrl(url),
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return SizedBox(
                                height: 200,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    value: progress.expectedTotalBytes != null
                                        ? progress.cumulativeBytesLoaded /
                                              progress.expectedTotalBytes!
                                        : null,
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (_, __, ___) => const SizedBox(
                              height: 120,
                              child: Center(
                                child: Icon(Icons.broken_image_outlined),
                              ),
                            ),
                          )
                        : ListTile(
                            leading: const Icon(Icons.attach_file_rounded),
                            title: Text(
                              url.split('/').last,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
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
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${parsed.day} ${months[parsed.month - 1]} ${parsed.year}';
}

String _text(dynamic value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

String _assetUrl(String path) {
  if (path.startsWith('http://') || path.startsWith('https://')) {
    return path;
  }
  final origin = EnvConfig.apiOrigin.replaceAll(RegExp(r'/+$'), '');
  final p = path.startsWith('/') ? path : '/$path';
  return '$origin$p';
}

bool _isImageUrl(String url) {
  final lower = url.toLowerCase().split('?').first;
  return lower.endsWith('.jpg') ||
      lower.endsWith('.jpeg') ||
      lower.endsWith('.png') ||
      lower.endsWith('.webp') ||
      lower.endsWith('.gif') ||
      lower.endsWith('.heic');
}
