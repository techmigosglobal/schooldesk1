import 'package:flutter/material.dart';

import 'package:schooldesk1/core/config/env_config.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
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
      final response = (await BackendApiClient.instance.dio.get(
        '/event-posts/gallery',
      )).data;
      if (!mounted) return;
      final rows = response is List
          ? response
          : (response['data'] as List? ?? const []);
      setState(() {
        _posts = rows
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList();
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
      final role = BackendApiClient.instance.currentRoleName?.toLowerCase() ?? '';
      final canCreate = role == 'teacher' || role == 'principal' || role == 'admin';
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
    final media = _firstMedia(post['media_urls']);
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
                      errorBuilder: (_, _, _) => Container(
                        color: context.appTheme.panelMuted,
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: context.appTheme.onSurfaceVariant,
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
                            eventDate,
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
        final media = _mediaList(post['media_urls']);
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
                    child: Image.network(_assetUrl(url), fit: BoxFit.cover),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

String _firstMedia(dynamic raw) {
  final media = _mediaList(raw);
  return media.isEmpty ? '' : media.first;
}

List<String> _mediaList(dynamic raw) {
  if (raw is List) {
    return raw
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }
  return raw
      .toString()
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
}

String _text(dynamic value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

String _assetUrl(String path) {
  if (path.startsWith('http://') || path.startsWith('https://')) {
    return path;
  }
  return '${EnvConfig.apiOrigin}$path';
}
