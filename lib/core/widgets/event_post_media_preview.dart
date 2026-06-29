import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import 'package:schooldesk1/core/config/env_config.dart';
import 'package:schooldesk1/core/utils/event_post_media_parser.dart';
import 'package:schooldesk1/core/utils/extensions.dart';

String resolveEventPostMediaUrl(String url) {
  if (url.isEmpty) return url;
  if (url.startsWith('http://') || url.startsWith('https://')) return url;
  final origin = EnvConfig.apiOrigin.replaceAll(RegExp(r'/+$'), '');
  final path = url.startsWith('/') ? url : '/$url';
  return '$origin$path';
}

class EventPostMediaPreview extends StatelessWidget {
  final EventPostMediaItem item;
  final double height;
  final bool compact;
  final VoidCallback? onImageTap;

  const EventPostMediaPreview({
    super.key,
    required this.item,
    this.height = 200,
    this.compact = false,
    this.onImageTap,
  });

  @override
  Widget build(BuildContext context) {
    final url = resolveEventPostMediaUrl(item.url);
    if (item.isImage) {
      return InkWell(
        onTap: onImageTap,
        child: Image.network(
          url,
          height: height,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallback(
            context,
            Icons.broken_image_outlined,
            'Image unavailable',
          ),
        ),
      );
    }
    if (item.isVideo) {
      return EventPostVideoPreview(url: url, height: height);
    }
    return _fileTile(context, url);
  }

  Widget _fileTile(BuildContext context, String url) {
    final icon = item.isPdf
        ? Icons.picture_as_pdf_outlined
        : Icons.insert_drive_file_outlined;
    return InkWell(
      onTap: () =>
          launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      child: Container(
        height: compact ? 96 : height,
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        color: context.appTheme.panelMuted,
        child: Row(
          children: [
            Icon(icon, size: 30, color: context.appTheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item.displayName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            const Icon(Icons.open_in_new_rounded, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _fallback(BuildContext context, IconData icon, String label) {
    return Container(
      height: height,
      width: double.infinity,
      color: context.appTheme.panelMuted,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: context.appTheme.onSurfaceVariant),
          const SizedBox(height: 6),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

class EventPostVideoPreview extends StatefulWidget {
  final String url;
  final double height;

  const EventPostVideoPreview({
    super.key,
    required this.url,
    this.height = 200,
  });

  @override
  State<EventPostVideoPreview> createState() => _EventPostVideoPreviewState();
}

class _EventPostVideoPreviewState extends State<EventPostVideoPreview> {
  late final VideoPlayerController _controller;
  bool _ready = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize()
          .then((_) {
            if (!mounted) return;
            setState(() => _ready = true);
          })
          .catchError((Object error) {
            if (!mounted) return;
            setState(() => _error = 'Video unavailable');
          });
  }

  @override
  void dispose() {
    if (_controller.value.isInitialized && _controller.value.isPlaying) {
      _controller.pause();
    }
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return _videoShell(context, child: Center(child: Text(_error!)));
    }
    if (!_ready) {
      return _videoShell(
        context,
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    return _videoShell(
      context,
      child: Stack(
        fit: StackFit.expand,
        children: [
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _controller.value.size.width,
              height: _controller.value.size.height,
              child: VideoPlayer(_controller),
            ),
          ),
          Center(
            child: IconButton.filled(
              onPressed: () {
                setState(() {
                  _controller.value.isPlaying
                      ? _controller.pause()
                      : _controller.play();
                });
              },
              icon: Icon(
                _controller.value.isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _videoShell(BuildContext context, {required Widget child}) {
    return Container(
      height: widget.height,
      width: double.infinity,
      color: Colors.black,
      child: child,
    );
  }
}
