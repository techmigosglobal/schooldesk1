import 'package:flutter/material.dart';

import 'package:schooldesk1/core/utils/event_post_media_parser.dart';
import 'package:schooldesk1/core/utils/media_url.dart';
import 'package:schooldesk1/core/widgets/event_post_media_preview.dart';
import 'package:schooldesk1/modules/communication/domain/event_post_repository.dart';

const schoolPostPlacements = {
  'PARENTS_HOME': 'Parent Feed',
  'SCHOOL_GALLERY': 'Gallery',
  'TEACHERS_HOME': 'Teacher Home',
  'SCHOOL_LANDING': 'Public Landing Page',
};

/// Shared by the published feed and its paginated existing-post picker.
class SchoolPostFeedTab extends StatefulWidget {
  const SchoolPostFeedTab({
    super.key,
    required this.repository,
    this.onChanged,
    this.onSelect,
  });

  final EventPostRepository repository;
  final VoidCallback? onChanged;
  final ValueChanged<Map<String, dynamic>>? onSelect;

  @override
  State<SchoolPostFeedTab> createState() => SchoolPostFeedTabState();
}

class SchoolPostFeedTabState extends State<SchoolPostFeedTab> {
  final _posts = <Map<String, dynamic>>[];
  String _destination = 'FEED';
  int _page = 0;
  bool _hasMore = false;
  bool _loading = false;
  bool _retryReset = true;
  bool _saving = false;
  bool _stale = false;
  String? _error;
  int _generation = 0;

  bool get _picking => widget.onSelect != null;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() => _load(reset: true);

  Future<void> _load({bool reset = false}) async {
    if (_loading && !reset) return;
    final generation = reset ? ++_generation : _generation;
    final page = reset ? 1 : _page + 1;
    setState(() {
      _loading = true;
      _retryReset = reset;
      _error = null;
      if (reset) _hasMore = false;
    });
    try {
      final result = await widget.repository.loadPublishedPostsPage(
        page: page,
        pageSize: 20,
        destination: _picking ? '' : _destination,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        if (reset) _posts.clear();
        final ids = _posts.map((post) => post['id']).toSet();
        _posts.addAll(result.data.where((post) => ids.add(post['id'])));
        _page = result.page;
        _hasMore = result.hasMore;
        _stale = result.isStale;
      });
    } on Object {
      if (mounted && generation == _generation) {
        setState(() => _error = 'Unable to load posts. Please retry.');
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Set<String> _placements(Map<String, dynamic> post) =>
      (post['destinations'] as List? ?? []).map((item) => '$item').toSet();

  Future<void> _visibility(
    Map<String, dynamic> post, {
    bool adding = false,
  }) async {
    final selected = _placements(post);
    var publicGalleryVisible = post['public_gallery_visible'] == true;
    if (adding &&
        selected.intersection({'PARENTS_HOME', 'SCHOOL_GALLERY'}).isEmpty) {
      selected.add('PARENTS_HOME');
    }
    final hasMedia = EventPostMediaItem.parseList(
      post['media_urls'],
    ).isNotEmpty;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text(adding ? 'Add existing post' : 'Manage visibility'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final entry in schoolPostPlacements.entries)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(entry.value),
                    subtitle: entry.key == 'SCHOOL_GALLERY' && !hasMedia
                        ? const Text(
                            'Add photos or video before placing in Gallery.',
                          )
                        : null,
                    value: selected.contains(entry.key),
                    onChanged:
                        entry.key == 'SCHOOL_GALLERY' &&
                            !hasMedia &&
                            !selected.contains(entry.key)
                        ? null
                        : (value) => update(() {
                            value == true
                                ? selected.add(entry.key)
                                : selected.remove(entry.key);
                          }),
                  ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Public website gallery'),
                  value: publicGalleryVisible,
                  onChanged: !hasMedia && !publicGalleryVisible
                      ? null
                      : (value) =>
                            update(() => publicGalleryVisible = value == true),
                ),
                const Text(
                  'Public Landing Page and Public website gallery are visible to website visitors. Uncheck every option to hide the post; it remains in Manage.',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (saved == true && mounted) {
      await _save(post, selected, publicGalleryVisible: publicGalleryVisible);
    }
  }

  Future<void> _save(
    Map<String, dynamic> post,
    Set<String> placements, {
    bool? publicGalleryVisible,
  }) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await widget.repository.updateVisibility(
        '${post['id']}',
        placements.toList(),
        publicGalleryVisible: publicGalleryVisible,
      );
      if (!mounted) return;
      widget.onChanged?.call();
      await refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post visibility updated.')),
        );
      }
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to update visibility. Please retry.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _remove(Map<String, dynamic> post, String destination) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove from ${schoolPostPlacements[destination]}?'),
        content: const Text(
          'The post will remain in Manage and its other destinations.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _save(post, _placements(post)..remove(destination));
    }
  }

  Future<void> _addExisting() async {
    final post = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Choose an approved post')),
          body: SchoolPostFeedTab(
            repository: widget.repository,
            onSelect: (post) => Navigator.pop(context, post),
          ),
        ),
      ),
    );
    if (post != null && mounted) await _visibility(post, adding: true);
  }

  void _details(Map<String, dynamic> post) {
    final media = EventPostMediaItem.parseList(post['media_urls']);
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: Text('${post['title'] ?? 'School post'}')),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                '${post['title'] ?? 'School post'}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Text('${post['description'] ?? post['body'] ?? ''}'),
              for (final item in media) ...[
                const SizedBox(height: 16),
                EventPostMediaPreview(item: item, height: 240),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _thumbnail(Map<String, dynamic> post) {
    final media = EventPostMediaItem.parseList(post['media_urls']);
    final item = media.firstOrNull;
    final image = item?.isImage == true ? item!.url : item?.thumbnailUrl ?? '';
    final fallback = Icon(
      item?.isVideo == true
          ? Icons.videocam_outlined
          : Icons.photo_library_outlined,
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox.square(
        dimension: 56,
        child: image.isEmpty
            ? fallback
            : Image.network(
                resolveOriginalImageUrl(image),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => fallback,
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (!_picking)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final entry in const {
                      'FEED': 'All',
                      'PARENTS_HOME': 'Parent Feed',
                      'SCHOOL_GALLERY': 'Gallery',
                    }.entries)
                      ChoiceChip(
                        label: Text(entry.value),
                        selected: _destination == entry.key,
                        onSelected: _saving
                            ? null
                            : (_) {
                                setState(() {
                                  _destination = entry.key;
                                  _posts.clear();
                                });
                                refresh();
                              },
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _saving || _stale ? null : _addExisting,
                  icon: const Icon(Icons.add),
                  label: const Text('Add existing post'),
                ),
              ],
            ),
          ),
        if (_saving || _loading) const LinearProgressIndicator(),
        if (_stale)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'Showing saved posts. Refresh when online to manage visibility.',
            ),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(_error!),
                TextButton(
                  onPressed: _loading ? null : () => _load(reset: _retryReset),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: refresh,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: _posts.length + 1,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                if (index == _posts.length) {
                  if (_hasMore) {
                    return Center(
                      child: TextButton(
                        onPressed: _loading ? null : () => _load(),
                        child: const Text('Load more'),
                      ),
                    );
                  }
                  if (_posts.isEmpty && !_loading && _error == null) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('No approved posts here yet.'),
                    );
                  }
                  return const SizedBox(height: 24);
                }
                final post = _posts[index];
                final placements = _placements(post);
                final date = '${post['event_date'] ?? post['created_at'] ?? ''}'
                    .split('T')
                    .first;
                return ListTile(
                  key: ValueKey('feed-post-${post['id']}'),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: _thumbnail(post),
                  title: Text('${post['title'] ?? 'School post'}'),
                  subtitle: Text(
                    [
                      if (date.isNotEmpty) date,
                      placements.isEmpty &&
                              post['public_gallery_visible'] != true
                          ? 'Hidden — available in Manage'
                          : [
                              ...placements.map(
                                (key) => schoolPostPlacements[key] ?? key,
                              ),
                              if (post['public_gallery_visible'] == true)
                                'Public website gallery',
                            ].join(' · '),
                    ].join('\n'),
                  ),
                  onTap: _picking
                      ? () => widget.onSelect!(post)
                      : () => _details(post),
                  trailing: _picking
                      ? const Icon(Icons.add_circle_outline)
                      : PopupMenuButton<String>(
                          tooltip: 'Manage post visibility',
                          enabled: !_saving && !_stale,
                          onSelected: (action) {
                            if (action == 'visibility') {
                              _visibility(post);
                            } else {
                              _remove(post, action);
                            }
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'visibility',
                              child: Text('Manage visibility'),
                            ),
                            for (final destination in [
                              'PARENTS_HOME',
                              'SCHOOL_GALLERY',
                            ])
                              if (placements.contains(destination))
                                PopupMenuItem(
                                  value: destination,
                                  child: Text(
                                    'Remove from ${schoolPostPlacements[destination]}',
                                  ),
                                ),
                          ],
                        ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
