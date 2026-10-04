import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:schooldesk1/core/theme/design_tokens.dart';
import 'package:schooldesk1/core/utils/event_post_media_parser.dart';
import 'package:schooldesk1/core/widgets/event_post_media_preview.dart';

/// A bounded preview of the school feed used by dashboards that need to show
/// the same posts without copying the parent feed's carousel implementation.
///
/// The card deliberately keeps media and copy in separate, constrained areas.
/// That prevents a long screen or an unusually sized source image from
/// stretching the post beyond a useful dashboard size.
class SchoolFeedPreview extends StatefulWidget {
  final List<Map<String, dynamic>> posts;
  final Color accentColor;
  final bool showParentVisibility;
  final String? audienceLabel;
  final bool isStale;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final String? actionLabel;
  final VoidCallback? onAction;

  const SchoolFeedPreview({
    super.key,
    required this.posts,
    required this.accentColor,
    this.showParentVisibility = false,
    this.audienceLabel,
    this.isStale = false,
    this.errorMessage,
    this.onRetry,
    this.actionLabel,
    this.onAction,
  });

  @override
  State<SchoolFeedPreview> createState() => _SchoolFeedPreviewState();
}

class _SchoolFeedPreviewState extends State<SchoolFeedPreview> {
  late final PageController _pageController;
  Timer? _timer;
  int _currentPage = 0;
  bool _paused = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.92);
    _scheduleNext();
  }

  @override
  void didUpdateWidget(SchoolFeedPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_currentPage >= widget.posts.length && widget.posts.isNotEmpty) {
      _currentPage = widget.posts.length - 1;
      if (_pageController.hasClients) _pageController.jumpToPage(_currentPage);
    }
    if (oldWidget.posts.length != widget.posts.length) _scheduleNext();
  }

  void _scheduleNext() {
    _timer?.cancel();
    if (_paused || widget.posts.length <= 1) return;
    _timer = Timer(const Duration(seconds: 5), () {
      if (!mounted || _paused || widget.posts.length <= 1) return;
      final next = (_currentPage + 1) % widget.posts.length;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeInOut,
      );
    });
  }

  void _togglePause() {
    setState(() => _paused = !_paused);
    _scheduleNext();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;

    return Container(
      padding: EdgeInsets.all(tokens.spacing.md),
      decoration: BoxDecoration(
        color: tokens.panel,
        borderRadius: BorderRadius.circular(tokens.radius.card),
        border: Border.all(color: tokens.panelBorder),
        boxShadow: tokens.elevation.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: widget.accentColor.withAlpha(22),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.campaign_rounded, color: widget.accentColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'School Feed',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: tokens.onSurface,
                      ),
                    ),
                    if (widget.showParentVisibility)
                      Text(
                        widget.audienceLabel ?? 'Visible to parents',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: widget.accentColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ),
              if (widget.onAction != null && widget.actionLabel != null)
                TextButton(
                  onPressed: widget.onAction,
                  child: Text(
                    widget.actionLabel!,
                    style: TextStyle(
                      color: widget.accentColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: tokens.spacing.md),
          if (widget.errorMessage != null && widget.posts.isEmpty)
            SchoolFeedStatusNotice(
              accentColor: widget.accentColor,
              isStale: widget.isStale,
              errorMessage: widget.errorMessage,
              onRetry: widget.onRetry,
            )
          else ...[
            if (widget.isStale || widget.errorMessage != null)
              SchoolFeedStatusNotice(
                accentColor: widget.accentColor,
                isStale: widget.isStale,
                errorMessage: widget.errorMessage,
                onRetry: widget.onRetry,
              ),
            if (widget.posts.isEmpty)
              _EmptySchoolFeed(accentColor: widget.accentColor)
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final cardWidth = math.min(
                    310.0,
                    math.max(258.0, constraints.maxWidth * 0.82),
                  );
                  return Column(
                    children: [
                      SizedBox(
                        height: 304,
                        child: PageView.builder(
                          controller: _pageController,
                          itemCount: widget.posts.length,
                          onPageChanged: (index) {
                            setState(() => _currentPage = index);
                            _scheduleNext();
                          },
                          itemBuilder: (context, index) => Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: _SchoolFeedPostCard(
                              post: widget.posts[index],
                              accentColor: widget.accentColor,
                              width: cardWidth,
                            ),
                          ),
                        ),
                      ),
                      if (widget.posts.length > 1) ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ...List.generate(
                              math.min(widget.posts.length, 8),
                              (index) => AnimatedContainer(
                                duration: const Duration(milliseconds: 220),
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                ),
                                width: index == _currentPage ? 18 : 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: index == _currentPage
                                      ? widget.accentColor
                                      : widget.accentColor.withAlpha(60),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            InkWell(
                              onTap: _togglePause,
                              borderRadius: BorderRadius.circular(20),
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Icon(
                                  _paused
                                      ? Icons.play_arrow_rounded
                                      : Icons.pause_rounded,
                                  size: 16,
                                  color: widget.accentColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  );
                },
              ),
          ],
        ],
      ),
    );
  }
}

class _SchoolFeedPostCard extends StatelessWidget {
  final Map<String, dynamic> post;
  final Color accentColor;
  final double width;

  const _SchoolFeedPostCard({
    required this.post,
    required this.accentColor,
    required this.width,
  });

  String _text(Object? value) => value?.toString().trim() ?? '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;
    final title = _text(post['title']).isEmpty
        ? 'School Post'
        : _text(post['title']);
    final media = EventPostMediaItem.parseList(
      post['media'] ??
          post['media_urls'] ??
          post['mediaUrls'] ??
          post['media_url'] ??
          post['mediaUrl'] ??
          post['attachments'],
    );

    return SizedBox(
      width: width,
      child: Material(
        color: tokens.panel,
        borderRadius: BorderRadius.circular(tokens.radius.control + 2),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: media.isEmpty ? null : () => _openMedia(context, media.first),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: tokens.panelBorder),
              borderRadius: BorderRadius.circular(tokens.radius.control + 2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 260,
                  width: double.infinity,
                  child: media.isEmpty
                      ? _PostPlaceholder(title: title, accentColor: accentColor)
                      : EventPostMediaCarousel(
                          mediaItems: media,
                          height: 260,
                          autoAdvance: false,
                          imageFit: BoxFit.contain,
                          onOpen: () => _openMedia(context, media.first),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openMedia(BuildContext context, EventPostMediaItem item) {
    openEventPostMediaPreview(context, item);
  }
}

class SchoolFeedStatusNotice extends StatelessWidget {
  final Color accentColor;
  final bool isStale;
  final String? errorMessage;
  final VoidCallback? onRetry;

  const SchoolFeedStatusNotice({
    super.key,
    required this.accentColor,
    this.isStale = false,
    this.errorMessage,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final hasError = errorMessage != null;
    final message = hasError
        ? (isStale
              ? 'Unable to refresh. Showing the last available school feed.'
              : 'School feed is temporarily unavailable.')
        : 'Showing the last available school feed while offline.';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: (hasError ? Colors.deepOrange : accentColor).withAlpha(18),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: (hasError ? Colors.deepOrange : accentColor).withAlpha(60),
        ),
      ),
      child: Row(
        children: [
          Icon(
            hasError ? Icons.cloud_off_rounded : Icons.cloud_queue_rounded,
            size: 18,
            color: hasError ? Colors.deepOrange : accentColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _PostPlaceholder extends StatelessWidget {
  final String title;
  final Color accentColor;

  const _PostPlaceholder({required this.title, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    final shade = Color.lerp(accentColor, Colors.black, 0.28)!;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accentColor, shade],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.campaign_rounded,
          size: 42,
          color: Colors.white.withAlpha(225),
        ),
      ),
    );
  }
}

class _EmptySchoolFeed extends StatelessWidget {
  final Color accentColor;

  const _EmptySchoolFeed({required this.accentColor});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;
    return Container(
      height: 132,
      width: double.infinity,
      decoration: BoxDecoration(
        color: accentColor.withAlpha(10),
        borderRadius: BorderRadius.circular(tokens.radius.control),
        border: Border.all(color: accentColor.withAlpha(36)),
      ),
      child: Center(
        child: Text(
          'No school posts yet',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: tokens.textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
