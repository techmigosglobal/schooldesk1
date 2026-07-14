import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';

import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/theme/design_tokens.dart';
import 'package:schooldesk1/core/desktop/desktop_responsive_breakpoints.dart';
import 'package:schooldesk1/core/widgets/desktop_screen_wrapper.dart';

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen>
    with SingleTickerProviderStateMixin {
  final _api = BackendApiClient.instance;
  final _roles = const ['principal', 'teacher', 'parent'];
  List<Map<String, dynamic>> _helpItems = const [];
  late final String _userRole;
  late final bool _isSuperAdmin;
  TabController? _tabs;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _userRole = _api.currentRoleName?.trim().toLowerCase() ?? 'parent';
    _isSuperAdmin = _userRole == 'super_admin';
    if (_isSuperAdmin) {
      _tabs = TabController(length: _roles.length, vsync: this)
        ..addListener(() {
          if (!_tabs!.indexIsChanging) _loadHelpData();
        });
    }
    _loadHelpData();
  }

  @override
  void dispose() {
    _tabs?.dispose();
    super.dispose();
  }

  String get _role => _isSuperAdmin ? _roles[_tabs!.index] : _userRole;

  Future<void> _loadHelpData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _api.getHelpContent(_role);
      if (mounted) setState(() => _helpItems = items);
    } on Object {
      if (mounted) _error = 'Help content is unavailable right now.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit({Map<String, dynamic>? item}) async {
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _HelpEditorDialog(item: item, targetRole: _role),
    );
    if (payload == null) return;
    setState(() => _loading = true);
    try {
      if (item == null) {
        await _api.createHelpContent(payload);
      } else {
        await _api.updateHelpContent({...payload, 'id': item['id']});
      }
      await _loadHelpData();
    } on Object {
      if (mounted) {
        setState(
          () => _error = 'Unable to save the help tutorial. Please retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Help Item'),
        content: const Text('Delete this question and its tutorial reference?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _api.deleteHelpContent(id);
      await _loadHelpData();
    } on Object {
      if (mounted) setState(() => _error = 'Unable to delete the help item.');
    }
  }

  Future<void> _play(Map<String, dynamic> item) async {
    try {
      final url = await _api.getHelpTutorialPlaybackUrl('${item['id']}');
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => _TutorialPlayerDialog(url: url),
      );
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This tutorial video is unavailable.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {


  final isDesktop = DesktopBreakpoints.isDesktopWidth(


        MediaQuery.sizeOf(context).width,


      );


      if (isDesktop) {


        return DesktopScreenWrapper(


          breadcrumbs: ['Help'],


          title: 'Help & Tutorials',


          actions: const [],


          child: Card(


            elevation: 0,


            child: Padding(


              padding: const EdgeInsets.all(32),


              child: Center(


                child: Column(


                  mainAxisSize: MainAxisSize.min,


                  children: [


                    Icon(Icons.desktop_windows_rounded, size: 48, color: Theme.of(context).colorScheme.primary),


                    const SizedBox(height: 16),


                    Text('Help & Tutorials', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),


                    const SizedBox(height: 8),


                    Text('Desktop view coming soon', style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.5))),


                  ],


                ),


              ),


            ),


          ),


        );


      }

    final tokens = Theme.of(context).schoolDesk;
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      appBar: AppBar(
        title: const Text('How to use the application'),
        bottom: _isSuperAdmin
            ? TabBar(
                controller: _tabs,
                tabs: _roles.map((r) => Tab(text: r.toUpperCase())).toList(),
              )
            : null,
      ),
      floatingActionButton: _isSuperAdmin
          ? FloatingActionButton.extended(
              onPressed: () => _edit(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Q&A'),
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.help_outline_rounded, size: 42),
                    const SizedBox(height: 12),
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _loadHelpData,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          : _helpItems.isEmpty
          ? Center(
              child: Text(
                'No support content is available for this role yet.',
                style: GoogleFonts.dmSans(color: tokens.textMuted),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(18),
              itemCount: _helpItems.length,
              itemBuilder: (context, index) {
                final item = _helpItems[index];
                final hasVideo =
                    '${item['video_path'] ?? item['video_url'] ?? ''}'
                        .trim()
                        .isNotEmpty;
                return Card(
                  margin: const EdgeInsets.only(bottom: 14),
                  child: ExpansionTile(
                    title: Text(
                      '${item['question'] ?? 'Untitled'}',
                      style: GoogleFonts.dmSans(fontWeight: FontWeight.bold),
                    ),
                    trailing: _isSuperAdmin
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Edit',
                                onPressed: () => _edit(item: item),
                                icon: const Icon(Icons.edit_rounded),
                              ),
                              IconButton(
                                tooltip: 'Delete',
                                onPressed: () => _delete('${item['id']}'),
                                icon: const Icon(Icons.delete_outline_rounded),
                              ),
                            ],
                          )
                        : null,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Divider(),
                            Text(
                              '${item['answer'] ?? ''}',
                              style: GoogleFonts.dmSans(height: 1.5),
                            ),
                            if (hasVideo) ...[
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: () => _play(item),
                                icon: const Icon(
                                  Icons.play_circle_fill_rounded,
                                ),
                                label: const Text('Watch video tutorial'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class _HelpEditorDialog extends StatefulWidget {
  const _HelpEditorDialog({required this.targetRole, this.item});
  final String targetRole;
  final Map<String, dynamic>? item;
  @override
  State<_HelpEditorDialog> createState() => _HelpEditorDialogState();
}

class _HelpEditorDialogState extends State<_HelpEditorDialog> {
  static const _maxBytes = 250 * 1024 * 1024;
  final _form = GlobalKey<FormState>();
  late final _question = TextEditingController(
    text: '${widget.item?['question'] ?? ''}',
  );
  late final _answer = TextEditingController(
    text: '${widget.item?['answer'] ?? ''}',
  );
  PlatformFile? _file;
  Map<String, dynamic>? _video;
  bool _removeVideo = false;
  bool _uploading = false;
  String? _fileError;

  @override
  void dispose() {
    _question.dispose();
    _answer.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final result = await FilePicker.pickFiles(
      type: FileType.video,
      withData: false,
    );
    final file = result?.files.single;
    if (file == null) return;
    final isVideo = const [
      'mp4',
      'webm',
      'mov',
    ].contains(file.extension?.toLowerCase());
    setState(() {
      _file = isVideo && file.size <= _maxBytes ? file : null;
      _fileError = _file == null
          ? 'Select an MP4, WebM, or MOV video up to 250 MB.'
          : null;
      _video = null;
      _removeVideo = false;
    });
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate() || _uploading) return;
    if (_file != null && _video == null) {
      if (_file!.path == null) {
        setState(
          () => _fileError = 'This device did not provide a video path.',
        );
        return;
      }
      setState(() => _uploading = true);
      try {
        _video = await BackendApiClient.instance.uploadHelpTutorialVideo(
          _file!.path!,
          filename: _file!.name,
          roleName: widget.targetRole,
        );
      } on Object {
        if (mounted) {
          setState(() => _fileError = 'Video upload failed. Please retry.');
        }
        return;
      } finally {
        if (mounted) setState(() => _uploading = false);
      }
    }
    if (!mounted) return;
    Navigator.pop(context, {
      'role_name': widget.targetRole,
      'question': _question.text.trim(),
      'answer': _answer.text.trim(),
      'video_url': _removeVideo ? null : widget.item?['video_url'],
      'video_path': _removeVideo
          ? null
          : (_video?['video_path'] ?? widget.item?['video_path']),
      'video_file_name': _removeVideo
          ? null
          : (_video?['video_file_name'] ?? widget.item?['video_file_name']),
      'video_mime_type': _removeVideo
          ? null
          : (_video?['video_mime_type'] ?? widget.item?['video_mime_type']),
      'video_size': _removeVideo
          ? null
          : (_video?['video_size'] ?? widget.item?['video_size']),
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.item == null ? 'Add Help & Tutorial' : 'Edit Help & Tutorial',
    ),
    content: Form(
      key: _form,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _question,
              decoration: const InputDecoration(labelText: 'Question / Title'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _answer,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Answer / Explanation',
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Video tutorial (optional)',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _file?.name ??
                  '${widget.item?['video_file_name'] ?? 'No video uploaded'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (_fileError != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  _fileError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _uploading ? null : _pick,
              icon: const Icon(Icons.upload_file_rounded),
              label: Text(
                _file == null ? 'Choose video file' : 'Replace video',
              ),
            ),
            if (_file != null ||
                '${widget.item?['video_path'] ?? widget.item?['video_url'] ?? ''}'
                    .isNotEmpty)
              TextButton.icon(
                onPressed: _uploading
                    ? null
                    : () => setState(() {
                        _file = null;
                        _video = null;
                        _removeVideo = true;
                      }),
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Remove video'),
              ),
            if (_uploading)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: LinearProgressIndicator(),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _uploading ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _uploading ? null : _save,
        child: Text(_uploading ? 'Uploading…' : 'Save'),
      ),
    ],
  );
}

class _TutorialPlayerDialog extends StatefulWidget {
  const _TutorialPlayerDialog({required this.url});
  final String url;
  @override
  State<_TutorialPlayerDialog> createState() => _TutorialPlayerDialogState();
}

class _TutorialPlayerDialogState extends State<_TutorialPlayerDialog> {
  late final VideoPlayerController _controller;
  String? _error;
  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize()
          .then((_) {
            if (mounted) setState(() {});
          })
          .catchError((_) {
            if (mounted) setState(() => _error = 'Video could not be loaded.');
          });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.62;
    return AlertDialog(
      contentPadding: const EdgeInsets.all(12),
      content: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 560, maxHeight: maxHeight),
        child: _error != null
            ? SingleChildScrollView(child: Text(_error!))
            : !_controller.value.isInitialized
            ? const SizedBox(
                height: 180,
                child: Center(child: CircularProgressIndicator()),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: AspectRatio(
                      aspectRatio: _controller.value.aspectRatio,
                      child: VideoPlayer(_controller),
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          _controller.value.isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                        ),
                        onPressed: () => setState(
                          () => _controller.value.isPlaying
                              ? _controller.pause()
                              : _controller.play(),
                        ),
                      ),
                      Expanded(
                        child: VideoProgressIndicator(
                          _controller,
                          allowScrubbing: true,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
