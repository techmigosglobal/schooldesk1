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
class SchoolFeedPreview extends StatelessWidget {
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
                  color: accentColor.withAlpha(22),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.campaign_rounded, color: accentColor),
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
                    if (showParentVisibility)
                      Text(
                        audienceLabel ?? 'Visible to parents',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: accentColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ),
              if (onAction != null && actionLabel != null)
                TextButton(
                  onPressed: onAction,
                  child: Text(
                    actionLabel!,
                    style: TextStyle(
                      color: accentColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: tokens.spacing.md),
          if (errorMessage != null && posts.isEmpty)
            SchoolFeedStatusNotice(
              accentColor: accentColor,
              isStale: isStale,
              errorMessage: errorMessage,
              onRetry: onRetry,
            )
          else ...[
            if (isStale || errorMessage != null)
              SchoolFeedStatusNotice(
                accentColor: accentColor,
                isStale: isStale,
                errorMessage: errorMessage,
                onRetry: onRetry,
              ),
            if (posts.isEmpty)
              _EmptySchoolFeed(accentColor: accentColor)
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final cardWidth = math.min(
                    310.0,
                    math.max(258.0, constraints.maxWidth * 0.82),
                  );
                  return SizedBox(
                    height: 304,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: posts.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, index) => _SchoolFeedPostCard(
                        post: posts[index],
                        accentColor: accentColor,
                        width: cardWidth,
                      ),
                    ),
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
    final description = _text(post['description'] ?? post['body']);
    final category = _text(post['category']);
    final date = _formatDate(post['date'] ?? post['created_at']);
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
                  height: 156,
                  width: double.infinity,
                  child: media.isEmpty
                      ? _PostPlaceholder(title: title, accentColor: accentColor)
                      : EventPostMediaCarousel(
                          mediaItems: media,
                          height: 156,
                          autoAdvance: false,
                          imageFit: BoxFit.contain,
                          onOpen: () => _openMedia(context, media.first),
                        ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 11, 14, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (category.isNotEmpty)
                              Flexible(
                                child: Text(
                                  category.toUpperCase(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: accentColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            if (date.isNotEmpty) ...[
                              if (category.isNotEmpty) const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  date,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: tokens.textMuted,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: tokens.onSurface,
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                          ),
                        ),
                        if (description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: tokens.textMuted,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(Object? raw) {
    final value = _text(raw);
    if (value.isEmpty) return '';
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;
    return '${parsed.day}/${parsed.month}/${parsed.year}';
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
