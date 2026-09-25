import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';

import 'package:schooldesk1/app/providers/app_providers.dart';
import 'package:schooldesk1/core/repositories/repository_state.dart';
import 'package:schooldesk1/core/repositories/repository_state_controller.dart';
import 'package:schooldesk1/core/widgets/repository_state_view.dart';
import 'package:schooldesk1/core/theme/design_tokens.dart';
import 'package:schooldesk1/modules/communication/domain/help_content_repository.dart';
import 'package:schooldesk1/routes/app_routes.dart';
import 'package:schooldesk1/routes/route_access_guard.dart';
import 'package:schooldesk1/routes/schooldesk_screen_registry.dart';

import 'package:schooldesk1/core/navigation/schooldesk_navigation.dart';

class HelpScreen extends ConsumerStatefulWidget {
  const HelpScreen({super.key});

  @override
  ConsumerState<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends ConsumerState<HelpScreen>
    with SingleTickerProviderStateMixin {
  final _roles = const ['principal', 'coordinator', 'teacher', 'parent'];
  final _searchController = TextEditingController();
  late final String _userRole;
  late final bool _isSuperAdmin;
  late final HelpContentRepository _repository;
  late final RepositoryStateController<List<Map<String, dynamic>>>
  _stateController;
  TabController? _tabs;

  RepositoryState<List<Map<String, dynamic>>> get _state =>
      _stateController.state;

  List<Map<String, dynamic>> get _helpItems => _state.data ?? const [];

  @override
  void initState() {
    super.initState();
    _repository = ref.read(helpContentRepositoryProvider);
    _userRole = ref.read(currentRoleNameProvider) ?? 'parent';
    _isSuperAdmin = _userRole == 'super_admin';
    _stateController = RepositoryStateController<List<Map<String, dynamic>>>(
      reader: ({forceRefresh = false}) =>
          _repository.load(_role, forceRefresh: forceRefresh),
    )..addListener(_onStateChanged);
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
    _searchController.dispose();
    _stateController
      ..removeListener(_onStateChanged)
      ..dispose();
    super.dispose();
  }

  void _onStateChanged() {
    if (mounted) setState(() {});
  }

  String get _role => _isSuperAdmin ? _roles[_tabs!.index] : _userRole;

  Future<void> _loadHelpData() async {
    await _stateController.load(forceRefresh: true);
  }

  Future<void> _edit({Map<String, dynamic>? item}) async {
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _HelpEditorDialog(
        item: item,
        targetRole: _role,
        repository: _repository,
      ),
    );
    if (payload == null) return;
    final result = item == null
        ? await _repository.create(payload)
        : await _repository.update({...payload, 'id': item['id']});
    if (result.isFailure) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${result.failureOrNull?.message}')),
        );
      }
      return;
    }
    await _loadHelpData();
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
    final result = await _repository.delete(id);
    if (result.isFailure) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${result.failureOrNull?.message}')),
        );
      }
      return;
    }
    await _loadHelpData();
  }

  Future<void> _play(Map<String, dynamic> item) async {
    final result = await _repository.loadPlaybackUrl('${item['id']}');
    if (result.isSuccess) {
      final url = result.dataOrNull!;
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => _TutorialPlayerDialog(url: url),
      );
      return;
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This tutorial video is unavailable.')),
      );
    }
  }

  Future<void> _openWorkflow(Map<String, dynamic> item) async {
    final route = '${item['action_route'] ?? ''}'.trim();
    if (route.isEmpty) return;
    final isKnownRoute = AppRoutes.routes.containsKey(route);
    final isAllowed = RouteAccessGuard.isRoleAllowedFor(
      routeName: route,
      role: _role,
    );
    if (!isKnownRoute || !isAllowed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This guide action is not available for this role.'),
        ),
      );
      return;
    }
    await SchoolDeskNavigation.push(context, route);
  }

  List<Map<String, dynamic>> get _visibleHelpItems {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _helpItems;
    return _helpItems.where((item) {
      return [
        item['question'],
        item['answer'],
        item['category'],
      ].any((value) => '${value ?? ''}'.toLowerCase().contains(query));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).schoolDesk;
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
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
      body: SchoolDeskRepositoryStateView<List<Map<String, dynamic>>>(
        state: _state,
        onRetry: _loadHelpData,
        loadingMessage: 'Loading help content',
        errorTitle: 'Help content unavailable',
        emptyTitle: 'No support content yet',
        emptyMessage: 'No support content is available for this role yet.',
        data: (_) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search_rounded),
                  hintText: 'Search ${_roleLabel(_role)} guides',
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                        ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${_visibleHelpItems.length} ${_visibleHelpItems.length == 1 ? 'guide' : 'guides'} for ${_roleLabel(_role)}. Open a guide, follow its steps, then use the action button when available.',
                  style: GoogleFonts.dmSans(color: tokens.textMuted),
                ),
              ),
            ),
            Expanded(
              child: _visibleHelpItems.isEmpty
                  ? Center(
                      child: Text(
                        'No guides match your search.',
                        style: GoogleFonts.dmSans(color: tokens.textMuted),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                      itemCount: _visibleHelpItems.length,
                      itemBuilder: (context, index) {
                        final item = _visibleHelpItems[index];
                        final hasVideo =
                            '${item['video_path'] ?? item['video_url'] ?? ''}'
                                .trim()
                                .isNotEmpty;
                        final steps = _workflowSteps(item['workflow_steps']);
                        final route = '${item['action_route'] ?? ''}'.trim();
                        final routeMetadata = SchoolDeskScreenRegistry.byRoute(
                          route,
                        );
                        return Card(
                          margin: const EdgeInsets.only(bottom: 14),
                          child: ExpansionTile(
                            title: Text(
                              '${item['question'] ?? 'Untitled'}',
                              style: GoogleFonts.dmSans(
                                fontWeight: FontWeight.bold,
                              ),
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
                                        onPressed: () =>
                                            _delete('${item['id']}'),
                                        icon: const Icon(
                                          Icons.delete_outline_rounded,
                                        ),
                                      ),
                                    ],
                                  )
                                : null,
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  0,
                                  16,
                                  16,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Divider(),
                                    if ('${item['category'] ?? ''}'
                                        .trim()
                                        .isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 10,
                                        ),
                                        child: Chip(
                                          backgroundColor:
                                              tokens.primaryContainer,
                                          side: BorderSide(
                                            color: tokens.primary.withAlpha(72),
                                          ),
                                          avatar: Icon(
                                            Icons.auto_stories_rounded,
                                            size: 17,
                                            color: tokens.primary,
                                          ),
                                          label: Text(
                                            '${item['category']}',
                                            style: GoogleFonts.dmSans(
                                              color: tokens.onSurface,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                      ),
                                    Text(
                                      '${item['answer'] ?? ''}',
                                      style: GoogleFonts.dmSans(height: 1.5),
                                    ),
                                    if (steps.isNotEmpty) ...[
                                      const SizedBox(height: 14),
                                      Text(
                                        'Step-by-step workflow',
                                        style: GoogleFonts.dmSans(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      ...steps.indexed.map(
                                        (entry) => Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 8,
                                          ),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              CircleAvatar(
                                                radius: 12,
                                                backgroundColor: tokens.primary,
                                                foregroundColor:
                                                    tokens.onPrimary,
                                                child: Text(
                                                  '${entry.$1 + 1}',
                                                  style: GoogleFonts.dmSans(
                                                    fontWeight: FontWeight.w900,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Text(
                                                  entry.$2,
                                                  style: GoogleFonts.dmSans(
                                                    height: 1.4,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                    if (route.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      FilledButton.icon(
                                        onPressed: () => _openWorkflow(item),
                                        style: FilledButton.styleFrom(
                                          backgroundColor: tokens.primary,
                                          foregroundColor: tokens.onPrimary,
                                        ),
                                        icon: const Icon(
                                          Icons.open_in_new_rounded,
                                        ),
                                        label: Text(
                                          'Open ${routeMetadata?.title ?? 'this workflow'}',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ],
                                    if (hasVideo) ...[
                                      const SizedBox(height: 12),
                                      OutlinedButton.icon(
                                        onPressed: () => _play(item),
                                        icon: const Icon(
                                          Icons.play_circle_fill_rounded,
                                        ),
                                        label: const Text(
                                          'Watch video tutorial',
                                        ),
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
            ),
          ],
        ),
      ),
    );
  }
}

List<String> _workflowSteps(Object? value) {
  if (value is! Iterable) return const [];
  return value
      .map((step) => '$step'.trim())
      .where((step) => step.isNotEmpty)
      .toList();
}

String _roleLabel(String role) {
  return switch (role) {
    'principal' => 'Principal',
    'coordinator' => 'Coordinator',
    'teacher' => 'Teacher',
    'parent' => 'Parent',
    _ => 'School user',
  };
}

class _HelpEditorDialog extends StatefulWidget {
  const _HelpEditorDialog({
    required this.targetRole,
    required this.repository,
    this.item,
  });
  final String targetRole;
  final HelpContentRepository repository;
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
  late final _category = TextEditingController(
    text: '${widget.item?['category'] ?? 'General'}',
  );
  late final _steps = TextEditingController(
    text: _workflowSteps(widget.item?['workflow_steps']).join('\n'),
  );
  String? _actionRoute;
  PlatformFile? _file;
  Map<String, dynamic>? _video;
  bool _removeVideo = false;
  bool _uploading = false;
  String? _fileError;

  @override
  void dispose() {
    _question.dispose();
    _answer.dispose();
    _category.dispose();
    _steps.dispose();
    super.dispose();
  }

  List<String> get _availableRoutes {
    return AppRoutes.routes.keys
        .where(
          (route) => RouteAccessGuard.isRoleAllowedFor(
            routeName: route,
            role: widget.targetRole,
          ),
        )
        .toList()
      ..sort();
  }

  String? get _selectedActionRoute {
    final selected = _actionRoute ?? '${widget.item?['action_route'] ?? ''}';
    return _availableRoutes.contains(selected) ? selected : null;
  }

  Future<void> _pick() async {
    final result = await FilePicker.pickFiles(type: FileType.video);
    final file = result.single;
    final isVideo = const [
      'mp4',
      'webm',
      'mov',
    ].contains(file.extension?.toLowerCase());
    setState(() {
      _file = isVideo && (file.lengthSync() ?? 0) <= _maxBytes ? file : null;
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
        final result = await widget.repository.uploadTutorial(
          _file!.path!,
          filename: _file!.name,
          roleName: widget.targetRole,
        );
        if (result.isFailure) {
          if (mounted) {
            setState(
              () => _fileError =
                  '${result.failureOrNull?.message ?? 'Video upload failed.'} Please retry.',
            );
          }
          return;
        }
        _video = result.dataOrNull;
      } finally {
        if (mounted) setState(() => _uploading = false);
      }
    }
    if (!mounted) return;
    Navigator.pop(context, {
      'role_name': widget.targetRole,
      'question': _question.text.trim(),
      'answer': _answer.text.trim(),
      'category': _category.text.trim(),
      'workflow_steps': _steps.text
          .split('\n')
          .map((step) => step.trim())
          .where((step) => step.isNotEmpty)
          .toList(),
      'action_route': _selectedActionRoute,
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
            const SizedBox(height: 12),
            TextFormField(
              controller: _category,
              decoration: const InputDecoration(
                labelText: 'Guide category',
                hintText: 'For example: Attendance or Communication',
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _steps,
              minLines: 3,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: 'Workflow steps',
                hintText: 'One clear step per line',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedActionRoute,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Open-screen action (optional)',
              ),
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('No direct action'),
                ),
                ..._availableRoutes.map(
                  (route) => DropdownMenuItem(
                    value: route,
                    child: Text(
                      SchoolDeskScreenRegistry.byRoute(route)?.title ?? route,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: (route) => setState(() => _actionRoute = route),
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
