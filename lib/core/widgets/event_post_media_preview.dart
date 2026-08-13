import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import 'package:video_player/video_player.dart';

import 'package:schooldesk1/core/utils/attachment_url_resolver.dart';
import 'package:schooldesk1/core/utils/event_post_media_parser.dart';
import 'package:schooldesk1/core/utils/extensions.dart';
import 'package:schooldesk1/core/utils/media_cache.dart';
import 'package:schooldesk1/core/utils/media_url.dart';

String resolveEventPostMediaUrl(String url) {
  if (url.isEmpty) return url;
  if (url.startsWith('assets/')) return url;
  return resolveAttachmentUrl(url)?.toString() ?? url;
}

class EventPostMediaPreview extends StatelessWidget {
  final EventPostMediaItem item;
  final double height;
  final bool compact;
  final BoxFit imageFit;
  final VoidCallback? onImageTap;

  const EventPostMediaPreview({
    super.key,
    required this.item,
    this.height = 200,
    this.compact = false,
    this.imageFit = BoxFit.cover,
    this.onImageTap,
  });

  @override
  Widget build(BuildContext context) {
    final url = resolveEventPostMediaUrl(item.url);
    if (item.isImage) {
      return InkWell(
        onTap: onImageTap ?? () => openEventPostMediaPreview(context, item),
        child: EventPostImagePreview(
          url,
          height: height,
          fit: imageFit,
          fallbackBuilder: () => _fallback(
            context,
            Icons.broken_image_outlined,
            'Image unavailable',
          ),
        ),
      );
    }
    if (item.isVideo) {
      return EventPostVideoPreview(
        url: url,
        height: height,
        loadOnInit: false,
        onTap: onImageTap ?? () => openEventPostMediaPreview(context, item),
      );
    }
    return _fileTile(context, url);
  }

  Widget _fileTile(BuildContext context, String url) {
    final icon = item.isPdf
        ? Icons.picture_as_pdf_outlined
        : Icons.insert_drive_file_outlined;
    return InkWell(
      onTap: () => openEventPostMediaPreview(context, item),
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
            const Icon(Icons.visibility_rounded, size: 18),
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

Future<void> openEventPostMediaPreview(
  BuildContext context,
  EventPostMediaItem item,
) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => EventPostMediaPreviewScreen(item: item),
    ),
  );
}

class EventPostMediaPreviewScreen extends StatelessWidget {
  final EventPostMediaItem item;

  const EventPostMediaPreviewScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final title = item.displayName.isEmpty ? 'Attachment' : item.displayName;
    final url = resolveEventPostMediaUrl(item.url);
    return Scaffold(
      appBar: AppBar(
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: SafeArea(child: _body(context, url)),
    );
  }

  Widget _body(BuildContext context, String url) {
    if (item.isImage) {
      return Center(
        child: InteractiveViewer(
          child: EventPostImagePreview(
            url,
            thumbnail: false,
            fit: BoxFit.contain,
            fallbackBuilder: () => _message(
              context,
              Icons.broken_image_outlined,
              'Image preview is not available.',
            ),
          ),
        ),
      );
    }
    if (item.isVideo) {
      return Center(child: EventPostVideoPreview(url: url, height: 320));
    }
    if (item.isPdf) {
      return EventPostPdfPreview(url: url, name: item.displayName);
    }
    return _message(
      context,
      Icons.insert_drive_file_outlined,
      'This attachment is available in the app.',
      subtitle: item.displayName,
    );
  }

  Widget _message(
    BuildContext context,
    IconData icon,
    String message, {
    String subtitle = '',
  }) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: context.appTheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            if (subtitle.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: context.appTheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class EventPostImagePreview extends StatelessWidget {
  final String url;
  final double? height;
  final BoxFit fit;
  final Widget Function()? fallbackBuilder;
  final bool thumbnail;

  const EventPostImagePreview(
    this.url, {
    super.key,
    this.height,
    this.fit = BoxFit.cover,
    this.fallbackBuilder,
    this.thumbnail = true,
  });

  @override
  Widget build(BuildContext context) {
    final requestUrl = resolveOriginalImageUrl(url);
    return FutureBuilder<Uint8List>(
      future: MediaCache.load(requestUrl),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return SizedBox(
            height: height,
            width: double.infinity,
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return fallbackBuilder?.call() ??
              SizedBox(height: height, child: const Icon(Icons.broken_image));
        }
        return Image.memory(
          snapshot.data!,
          height: height,
          width: double.infinity,
          fit: fit,
          cacheWidth: thumbnail ? 1200 : null,
          cacheHeight: thumbnail ? 1200 : null,
        );
      },
    );
  }
}

class EventPostPdfPreview extends StatelessWidget {
  final String url;
  final String name;

  const EventPostPdfPreview({super.key, required this.url, required this.name});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: _downloadPdfBytes(url),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Unable to load PDF preview.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
          );
        }
        final bytes = snapshot.data!;
        return PdfPreview(
          build: (_) async => bytes,
          pdfFileName: name.isEmpty ? 'event-post-attachment.pdf' : name,
          canChangePageFormat: false,
          canChangeOrientation: false,
          canDebug: false,
          allowPrinting: false,
          allowSharing: false,
        );
      },
    );
  }

  Future<Uint8List> _downloadPdfBytes(String url) async {
    // MediaCache preserves the legacy BackendApiClient.instance.dio.get<List<int>>
    // path for authenticated/legacy attachments while adding disk caching.
    return MediaCache.load(url);
  }
}

class EventPostVideoPreview extends StatefulWidget {
  final String url;
  final double height;
  final bool autoPlay;
  final bool muted;
  final bool showFullscreen;
  final bool loadOnInit;
  final VoidCallback? onTap;

  const EventPostVideoPreview({
    super.key,
    required this.url,
    this.height = 200,
    this.autoPlay = false,
    this.muted = true,
    this.showFullscreen = true,
    this.loadOnInit = true,
    this.onTap,
  });

  @override
  State<EventPostVideoPreview> createState() => _EventPostVideoPreviewState();
}

class _EventPostVideoPreviewState extends State<EventPostVideoPreview> {
  VideoPlayerController? _controller;
  bool _ready = false;
  bool _loading = false;
  late bool _muted;
  String? _error;

  @override
  void initState() {
    super.initState();
    _muted = widget.muted;
    if (widget.loadOnInit) unawaited(_startVideo());
  }

  Future<void> _startVideo() async {
    if (_controller != null || _loading) return;
    setState(() => _loading = true);
    final controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _controller = controller;
    try {
      await controller.initialize();
      if (!mounted) return;
      await controller.setLooping(true);
      await controller.setVolume(_muted ? 0 : 1);
      if (widget.autoPlay) await controller.play();
      setState(() {
        _loading = false;
        _ready = true;
      });
    } on Object catch (_) {
      await controller.dispose();
      _controller = null;
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Video unavailable';
        });
      }
    }
  }

  @override
  void dispose() {
    final controller = _controller;
    if (controller != null &&
        controller.value.isInitialized &&
        controller.value.isPlaying) {
      controller.pause();
    }
    controller?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(EventPostVideoPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_ready || oldWidget.autoPlay == widget.autoPlay) return;
    final controller = _controller;
    if (controller == null) return;
    if (widget.autoPlay) {
      controller.play();
    } else if (controller.value.isPlaying) {
      controller.pause();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return _videoShell(context, child: Center(child: Text(_error!)));
    }
    if (!_ready) {
      return _videoShell(
        context,
        child: InkWell(
          onTap: widget.onTap ?? _startVideo,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const Center(
                child: Icon(
                  Icons.video_library_rounded,
                  color: Colors.white70,
                  size: 46,
                ),
              ),
              Center(
                child: IconButton.filled(
                  tooltip: 'Open video',
                  onPressed: widget.onTap ?? _startVideo,
                  icon: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.play_arrow_rounded),
                ),
              ),
            ],
          ),
        ),
      );
    }
    final controller = _controller!;
    return _videoShell(
      context,
      child: Stack(
        fit: StackFit.expand,
        children: [
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: controller.value.size.width,
              height: controller.value.size.height,
              child: VideoPlayer(controller),
            ),
          ),
          Center(
            child: IconButton.filled(
              tooltip: controller.value.isPlaying
                  ? 'Pause video'
                  : 'Play video',
              onPressed: () {
                setState(() {
                  controller.value.isPlaying
                      ? controller.pause()
                      : controller.play();
                });
              },
              icon: Icon(
                controller.value.isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
              ),
            ),
          ),
          Positioned(
            right: 8,
            bottom: 42,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton.filledTonal(
                  tooltip: _muted ? 'Unmute video' : 'Mute video',
                  onPressed: () {
                    setState(() {
                      _muted = !_muted;
                      controller.setVolume(_muted ? 0 : 1);
                    });
                  },
                  icon: Icon(
                    _muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                    size: 20,
                  ),
                ),
                if (widget.showFullscreen) ...[
                  const SizedBox(width: 6),
                  IconButton.filledTonal(
                    tooltip: 'Full screen',
                    onPressed: _openFullscreen,
                    icon: const Icon(Icons.fullscreen_rounded, size: 20),
                  ),
                ],
              ],
            ),
          ),
          Positioned(
            right: 8,
            bottom: 6,
            left: 8,
            child: _VideoSeekBar(controller: controller),
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

  Future<void> _openFullscreen() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            _FullscreenEventPostVideo(url: widget.url, muted: _muted),
      ),
    );
  }
}

class _VideoSeekBar extends StatelessWidget {
  final VideoPlayerController controller;

  const _VideoSeekBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final position = value.position > value.duration
            ? value.duration
            : value.position;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(145),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Text(
                _videoTime(position),
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: VideoProgressIndicator(
                  controller,
                  allowScrubbing: true,
                  colors: const VideoProgressColors(
                    playedColor: Colors.white,
                    bufferedColor: Color(0x99FFFFFF),
                    backgroundColor: Color(0x55FFFFFF),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                _videoTime(value.duration),
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
            ],
          ),
        );
      },
    );
  }
}

String _videoTime(Duration value) {
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  final minutes = twoDigits(value.inMinutes.remainder(60));
  final seconds = twoDigits(value.inSeconds.remainder(60));
  return value.inHours > 0
      ? '${value.inHours}:$minutes:$seconds'
      : '$minutes:$seconds';
}

class _FullscreenEventPostVideo extends StatefulWidget {
  final String url;
  final bool muted;

  const _FullscreenEventPostVideo({required this.url, required this.muted});

  @override
  State<_FullscreenEventPostVideo> createState() =>
      _FullscreenEventPostVideoState();
}

class _FullscreenEventPostVideoState extends State<_FullscreenEventPostVideo> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: EventPostVideoPreview(
              url: widget.url,
              height: double.infinity,
              autoPlay: true,
              muted: widget.muted,
              showFullscreen: false,
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: IconButton.filledTonal(
                tooltip: 'Exit full screen',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
