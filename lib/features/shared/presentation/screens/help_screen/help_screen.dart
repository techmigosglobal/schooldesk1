import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/theme/design_tokens.dart';

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen>
    with SingleTickerProviderStateMixin {
  final _api = BackendApiClient.instance;
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _helpItems = [];
  late String _userRole;
  bool _isSuperAdmin = false;

  TabController? _tabController;
  final List<String> _roles = ['principal', 'teacher', 'parent'];

  @override
  void initState() {
    super.initState();
    _userRole = _api.currentRoleName?.trim().toLowerCase() ?? 'parent';
    _isSuperAdmin = _userRole == 'super_admin';
    if (_isSuperAdmin) {
      _tabController = TabController(length: _roles.length, vsync: this);
      _tabController!.addListener(_handleTabChange);
    }
    _loadHelpData();
  }

  @override
  void dispose() {
    _tabController?.removeListener(_handleTabChange);
    _tabController?.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (_tabController!.indexIsChanging) return;
    _loadHelpData();
  }

  String get _currentQueryRole {
    if (_isSuperAdmin) {
      return _roles[_tabController!.index];
    }
    return _userRole;
  }

  Future<void> _loadHelpData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _api.getHelpContent(_currentQueryRole);
      setState(() {
        _helpItems = items;
        _loading = false;
      });
    } on Object catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _deleteItem(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Help Item'),
        content: const Text(
          'Are you sure you want to delete this question/tutorial?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _loading = true);
    try {
      await _api.deleteHelpContent(id);
      await _loadHelpData();
    } on Object catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _openAddEditDialog({Map<String, dynamic>? item}) {
    final questionCtrl = TextEditingController(text: item?['question'] ?? '');
    final answerCtrl = TextEditingController(text: item?['answer'] ?? '');
    final videoUrlCtrl = TextEditingController(text: item?['video_url'] ?? '');
    final formKey = GlobalKey<FormState>();

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          item == null ? 'Add Help & Tutorial' : 'Edit Help & Tutorial',
        ),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: questionCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Question / Title',
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: answerCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Answer / Explanation',
                  ),
                  maxLines: 4,
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: videoUrlCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Video Tutorial URL (Optional)',
                    hintText: 'e.g. https://youtube.com/...',
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(context);
              setState(() => _loading = true);
              try {
                final payload = {
                  'role_name': _currentQueryRole,
                  'question': questionCtrl.text.trim(),
                  'answer': answerCtrl.text.trim(),
                  'video_url': videoUrlCtrl.text.trim().isEmpty
                      ? null
                      : videoUrlCtrl.text.trim(),
                  if (item != null) 'id': item['id'],
                };
                if (item == null) {
                  await _api.createHelpContent(payload);
                } else {
                  await _api.updateHelpContent(payload);
                }
                await _loadHelpData();
              } on Object catch (e) {
                setState(() {
                  _error = e.toString();
                  _loading = false;
                });
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _playVideo(String url) {
    showDialog<void>(
      context: context,
      builder: (context) => _MockVideoPlayerDialog(videoUrl: url),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;

    final scaffold = Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      appBar: AppBar(
        title: const Text('How to use the application'),
        bottom: _isSuperAdmin
            ? TabBar(
                controller: _tabController,
                tabs: _roles.map((r) => Tab(text: r.toUpperCase())).toList(),
              )
            : null,
      ),
      floatingActionButton: _isSuperAdmin
          ? FloatingActionButton.extended(
              onPressed: () => _openAddEditDialog(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Q&A'),
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Error: $_error',
                      style: const TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
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
                'No support content available for this role yet.',
                style: GoogleFonts.dmSans(color: tokens.textMuted),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(18),
              itemCount: _helpItems.length,
              itemBuilder: (context, index) {
                final item = _helpItems[index];
                final hasVideo =
                    item['video_url'] != null &&
                    item['video_url'].toString().trim().isNotEmpty;

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ExpansionTile(
                    shape: const Border(),
                    title: Text(
                      item['question'] ?? 'No Title',
                      style: GoogleFonts.dmSans(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    trailing: _isSuperAdmin
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.edit_rounded,
                                  color: Colors.blue,
                                  size: 20,
                                ),
                                onPressed: () => _openAddEditDialog(item: item),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_rounded,
                                  color: Colors.red,
                                  size: 20,
                                ),
                                onPressed: () => _deleteItem(item['id']),
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
                            const SizedBox(height: 6),
                            Text(
                              item['answer'] ?? '',
                              style: GoogleFonts.dmSans(
                                fontSize: 14,
                                height: 1.5,
                                color: const Color(0xFF475569),
                              ),
                            ),
                            if (hasVideo) ...[
                              const SizedBox(height: 14),
                              InkWell(
                                onTap: () => _playVideo(item['video_url']),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEEF2F6),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: const Color(0xFFCBD5E1),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.play_circle_fill_rounded,
                                        color: Color(0xFF1565C0),
                                        size: 24,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          'Watch Video Tutorial',
                                          style: GoogleFonts.dmSans(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: const Color(0xFF1E293B),
                                          ),
                                        ),
                                      ),
                                      const Icon(
                                        Icons.arrow_forward_ios_rounded,
                                        size: 12,
                                        color: Color(0xFF64748B),
                                      ),
                                    ],
                                  ),
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
    );

    return scaffold;
  }
}

class _MockVideoPlayerDialog extends StatefulWidget {
  final String videoUrl;
  const _MockVideoPlayerDialog({required this.videoUrl});

  @override
  State<_MockVideoPlayerDialog> createState() => _MockVideoPlayerDialogState();
}

class _MockVideoPlayerDialogState extends State<_MockVideoPlayerDialog> {
  double _progress = 0.0;
  bool _isPlaying = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      if (_isPlaying) {
        setState(() {
          _progress += 0.01;
          if (_progress >= 1.0) {
            _progress = 0.0;
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF0F172A),
      contentPadding: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: SizedBox(
        width: 320,
        height: 240,
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.video_library_rounded,
                    color: Colors.white24,
                    size: 48,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Playing Tutorial...',
                    style: GoogleFonts.dmSans(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      widget.videoUrl,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                        color: Colors.white30,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                color: Colors.black54,
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LinearProgressIndicator(
                      value: _progress,
                      backgroundColor: Colors.white12,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            _isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          onPressed: () {
                            setState(() => _isPlaying = !_isPlaying);
                          },
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            'Close',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                      ],
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
}
