import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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

  bool get _canManagePosts =>
      (BackendApiClient.instance.currentRoleName ?? '').toLowerCase() ==
      'principal';

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
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Unable to load the school gallery: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SchoolDeskModuleScaffold(
      title: 'School Gallery',
      subtitle: 'Approved event posts and photos',
      actions: [
        if (_canManagePosts)
          Tooltip(
            message: 'Manage school posts',
            child: TextButton.icon(
              onPressed: _openPostManager,
              icon: const Icon(Icons.edit_note_outlined, size: 18),
              label: const Text('Manage posts'),
            ),
          ),
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
          : const {'principal', 'coordinator'}.contains(role)
          ? 'Review School Posts Approval'
          : null;
      final actionRoute = role == 'teacher'
          ? AppRoutes.teacherEventPosts
          : const {'principal', 'coordinator'}.contains(role)
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
            childAspectRatio: columns == 1 ? 1.35 : 0.82,
          ),
          itemBuilder: (context, index) => _GalleryPostCard(
            post: _posts[index],
            canManage: _canManagePosts,
            onEdit: () => _openPostManager(_posts[index]),
            onDelete: () => _deletePost(_posts[index]),
          ),
        );
      },
    );
  }

  Future<void> _openPostManager([Map<String, dynamic>? post]) async {
    final id = (post?['id'] ?? '').toString().trim();
    await Navigator.pushNamed(
      context,
      AppRoutes.principalEventApprovals,
      arguments: {
        if (id.isNotEmpty) 'referenceId': id,
        'referenceType': 'event_post',
      },
    );
    if (mounted) await _loadGallery();
  }

  Future<void> _deletePost(Map<String, dynamic> post) async {
    final id = (post['id'] ?? '').toString().trim();
    if (id.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete school post?'),
        content: Text(
          '"${_text(post['title'], fallback: 'This post')}" will be removed from the gallery and every other school surface.',
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
      try {
        await BackendApiClient.instance.invalidateCachedReads();
      } on Object catch (_) {}
      await _loadGallery();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('School post deleted.')));
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to delete post: $error')));
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Gallery post card — media-first, identical feel to the parent home feed card
// ─────────────────────────────────────────────────────────────────────────────

class _GalleryPostCard extends StatelessWidget {
  final Map<String, dynamic> post;
  final bool canManage;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _GalleryPostCard({
    required this.post,
    this.canManage = false,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final mediaItems = EventPostMediaItem.parseList(post['media_urls']);
    final title = _text(post['title'], fallback: 'School event');
    final eventDate = _text(post['event_date']);
    final category = _text(post['category']);
    final gradient = _gradientFor(title);

    return GestureDetector(
      onTap: () => _showDetails(context),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Full-bleed media or gradient placeholder ──────────────────
            if (mediaItems.isNotEmpty)
              _GalleryMediaCover(
                mediaItems: mediaItems,
                gradient: gradient,
                onTap: () => _showDetails(context),
              )
            else
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: gradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.photo_library_outlined,
                    color: Colors.white.withOpacity(0.8),
                    size: 48,
                  ),
                ),
              ),

            // ── Bottom gradient scrim so text is always legible ───────────
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Colors.transparent,
                        Colors.black45,
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0.0, 0.45, 1.0],
                    ),
                  ),
                ),
              ),
            ),

            // ── Category chip (top-left) ───────────────────────────────────
            if (category.isNotEmpty)
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    category.toUpperCase(),
                    style: GoogleFonts.dmSans(
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      color: gradient[0],
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),

            // ── Date chip (top-right) ─────────────────────────────────────
            if (eventDate.isNotEmpty)
              Positioned(
                top: 10,
                right: canManage ? 48 : 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _formatEventDate(eventDate),
                    style: GoogleFonts.dmSans(
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

            // ── Title + media counter overlaid at the bottom ──────────────
            Positioned(
              bottom: 10,
              left: 12,
              right: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      shadows: const [
                        Shadow(
                          color: Colors.black54,
                          blurRadius: 4,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                  if (mediaItems.length > 1) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${mediaItems.length} photos',
                        style: GoogleFonts.dmSans(
                          fontSize: 9,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // ── Principal manage menu ─────────────────────────────────────
            if (canManage)
              Positioned(
                top: 6,
                right: 6,
                child: Material(
                  color: Colors.white.withOpacity(0.92),
                  borderRadius: BorderRadius.circular(20),
                  child: PopupMenuButton<String>(
                    tooltip: 'Manage school post',
                    icon: const Icon(Icons.more_horiz_rounded, size: 20),
                    onSelected: (action) {
                      if (action == 'edit') {
                        onEdit?.call();
                      } else if (action == 'delete') {
                        onDelete?.call();
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          leading: Icon(Icons.edit_outlined),
                          title: Text('Edit post'),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          leading: Icon(
                            Icons.delete_outline_rounded,
                            color: Color(0xFFB42318),
                          ),
                          title: Text('Delete post'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showDetails(BuildContext context) {
    final mediaItems = EventPostMediaItem.parseList(post['media_urls']);
    final title = _text(post['title'], fallback: 'School event');
    final description = _text(post['description']);
    final eventDate = _text(post['event_date']);
    final gradient = _gradientFor(title);

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              // ── Media carousel ─────────────────────────────────────────
              if (mediaItems.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    height: 260,
                    child: _GalleryMediaCarousel(
                      mediaItems: mediaItems,
                      gradient: gradient,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // ── Meta row ───────────────────────────────────────────────
              if (eventDate.isNotEmpty)
                Row(
                  children: [
                    Icon(
                      Icons.event_outlined,
                      size: 14,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _formatEventDate(eventDate),
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 12),

              // ── Title ──────────────────────────────────────────────────
              Text(
                title,
                style: GoogleFonts.dmSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 12),

              // ── Description ────────────────────────────────────────────
              Text(
                description.isEmpty ? 'No description added.' : description,
                style: GoogleFonts.dmSans(
                  fontSize: 15,
                  height: 1.6,
                  color: const Color(0xFF334155),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Full-bleed cover — shows first media item (image or video thumbnail)
// ─────────────────────────────────────────────────────────────────────────────

class _GalleryMediaCover extends StatelessWidget {
  final List<EventPostMediaItem> mediaItems;
  final List<Color> gradient;
  final VoidCallback onTap;

  const _GalleryMediaCover({
    required this.mediaItems,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cover = mediaItems.firstWhere(
      (item) => item.isImage || item.isVideo,
      orElse: () => mediaItems.first,
    );
    if (cover.url.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      );
    }
    return EventPostMediaPreview(
      item: cover,
      height: double.infinity,
      compact: true,
      // The cover is part of the post card, so tapping it must open the post
      // detail screen just like tapping the title or photo-count label.
      onImageTap: onTap,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Media carousel used in the detail view
// ─────────────────────────────────────────────────────────────────────────────

class _GalleryMediaCarousel extends StatefulWidget {
  final List<EventPostMediaItem> mediaItems;
  final List<Color> gradient;

  const _GalleryMediaCarousel({
    required this.mediaItems,
    required this.gradient,
  });

  @override
  State<_GalleryMediaCarousel> createState() => _GalleryMediaCarouselState();
}

class _GalleryMediaCarouselState extends State<_GalleryMediaCarousel> {
  late final PageController _controller;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: _controller,
          itemCount: widget.mediaItems.length,
          onPageChanged: (i) => setState(() => _currentIndex = i),
          itemBuilder: (context, index) {
            final item = widget.mediaItems[index];
            if (item.isVideo) {
              return EventPostVideoPreview(
                url: resolveEventPostMediaUrl(item.url),
                height: 260,
                autoPlay: index == _currentIndex,
              );
            }
            return EventPostMediaPreview(item: item, height: 260);
          },
        ),
        if (widget.mediaItems.length > 1)
          Positioned(
            bottom: 8,
            right: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_currentIndex + 1}/${widget.mediaItems.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

const List<List<Color>> _gradients = [
  [Color(0xFFFE7A36), Color(0xFFF35F30)],
  [Color(0xFF2196F3), Color(0xFF1976D2)],
  [Color(0xFF9C27B0), Color(0xFF7B1FA2)],
  [Color(0xFF4CAF50), Color(0xFF388E3C)],
  [Color(0xFFFF9800), Color(0xFFF57C00)],
  [Color(0xFFE91E63), Color(0xFFC2185B)],
];

List<Color> _gradientFor(String title) {
  return _gradients[title.hashCode.abs() % _gradients.length];
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
