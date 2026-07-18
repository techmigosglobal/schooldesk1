import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:video_player/video_player.dart';

import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/utils/attachment_url_resolver.dart';
import 'package:schooldesk1/core/utils/event_post_media_parser.dart';
import 'package:schooldesk1/core/utils/extensions.dart';

String resolveEventPostMediaUrl(String url) {
  if (url.isEmpty) return url;
  return resolveAttachmentUrl(url)?.toString() ?? url;
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
        onTap: onImageTap ?? () => openEventPostMediaPreview(context, item),
        child: EventPostImagePreview(
          url,
          height: height,
          fit: BoxFit.cover,
          fallbackBuilder: () => _fallback(
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

  const EventPostImagePreview(
    this.url, {
    super.key,
    this.height,
    this.fit = BoxFit.cover,
    this.fallbackBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: _downloadMediaBytes(url),
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
    return _downloadMediaBytes(url);
  }
}

/// Small bounded in-memory cache so the same attachment isn't re-downloaded
/// on every rebuild (e.g. dashboard carousels/auto-refresh) or every time a
/// user revisits a screen in the same session.
class _MediaByteCache {
  static const int _maxEntries = 40;
  static final Map<String, Uint8List> _bytes = {};

  static Uint8List? get(String url) => _bytes[url];

  static void put(String url, Uint8List bytes) {
    if (_bytes.length >= _maxEntries && !_bytes.containsKey(url)) {
      _bytes.remove(_bytes.keys.first);
    }
    _bytes[url] = bytes;
  }
}

Future<Uint8List> _downloadMediaBytes(String url) async {
  final cached = _MediaByteCache.get(url);
  if (cached != null) return cached;
  final response = await BackendApiClient.instance.dio.get<List<int>>(
    url,
    options: Options(responseType: ResponseType.bytes),
  );
  final bytes = Uint8List.fromList(response.data ?? const []);
  if (bytes.isNotEmpty) {
    _MediaByteCache.put(url, bytes);
  }
  return bytes;
}

class EventPostVideoPreview extends StatefulWidget {
  final String url;
  final double height;
  final bool autoPlay;
  final bool muted;

  const EventPostVideoPreview({
    super.key,
    required this.url,
    this.height = 200,
    this.autoPlay = false,
    this.muted = true,
  });

  @override
  State<EventPostVideoPreview> createState() => _EventPostVideoPreviewState();
}

class _EventPostVideoPreviewState extends State<EventPostVideoPreview> {
  late final VideoPlayerController _controller;
  bool _ready = false;
  late bool _muted;
  String? _error;

  @override
  void initState() {
    super.initState();
    _muted = widget.muted;
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize()
          .then((_) {
            if (!mounted) return;
            _controller
              ..setLooping(true)
              ..setVolume(_muted ? 0 : 1);
            if (widget.autoPlay) _controller.play();
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
  void didUpdateWidget(EventPostVideoPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_ready || oldWidget.autoPlay == widget.autoPlay) return;
    if (widget.autoPlay) {
      _controller.play();
    } else if (_controller.value.isPlaying) {
      _controller.pause();
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
              tooltip: _controller.value.isPlaying
                  ? 'Pause video'
                  : 'Play video',
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
          Positioned(
            top: 8,
            right: 8,
            child: IconButton.filledTonal(
              tooltip: _muted ? 'Unmute video' : 'Mute video',
              onPressed: () {
                setState(() {
                  _muted = !_muted;
                  _controller.setVolume(_muted ? 0 : 1);
                });
              },
              icon: Icon(
                _muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                size: 20,
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
