import 'dart:async';
import 'package:schooldesk1/core/navigation/schooldesk_navigation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:schooldesk1/core/services/chat_unread_service.dart';
import 'package:schooldesk1/core/utils/media_url.dart';
import 'package:schooldesk1/modules/communication/data/api_chat_workspace_repository.dart';
import 'package:schooldesk1/modules/communication/domain/chat_workspace_repository.dart';
import 'package:schooldesk1/routes/app_routes.dart';
import 'chat_workspace_controller.dart';

class ChatWorkspaceScreen extends StatefulWidget {
  const ChatWorkspaceScreen({
    super.key,
    required this.role,
    this.repository,
    this.initialConversationId = '',
    this.initialStudentId = '',
  });
  final String role;
  final String initialConversationId, initialStudentId;
  final ChatWorkspaceRepository? repository;
  @override
  State<ChatWorkspaceScreen> createState() => _ChatWorkspaceScreenState();
}

class _ChatWorkspaceScreenState extends State<ChatWorkspaceScreen>
    with WidgetsBindingObserver {
  late ChatWorkspaceRepository _repository;
  late ChatWorkspaceController _controller;
  final _composer = TextEditingController(), _search = TextEditingController();
  final _messages = ScrollController(), _inbox = ScrollController();
  int _revision = 0, _ownRevision = 0;
  String _selectedKey = '';
  bool _newMessages = false;
  final _avatarRefreshes = <String>{};
  Color get _paper => Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF111B28)
      : const Color(0xFFFEFEFD);
  Color get _wall => Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF0B1420)
      : const Color(0xFFF0F4F7);
  Color get _ink => Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFFE8F1FA)
      : const Color(0xFF09213E);
  Color get _muted => Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFFA9B8CC)
      : const Color(0xFF65738B);
  Color get _line => Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF2C3A4B)
      : const Color(0xFFE2E8F0);
  Color get _blue => Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF6CB7FF)
      : const Color(0xFF0069BE);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _repository = widget.repository ?? ApiChatWorkspaceRepository.legacyDefault;
    _controller = ChatWorkspaceController(
      _repository,
      widget.role,
      initialConversationId: widget.initialConversationId,
      initialStudentId: widget.initialStudentId,
      onUnreadRefresh: widget.repository == null
          ? () => ChatUnreadService.instance.refresh(role: widget.role)
          : null,
    )..addListener(_changed);
    _messages.addListener(_onMessageScroll);
    unawaited(_controller.start());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_repository.refreshConnection());
      unawaited(_controller.refresh());
    } else {
      unawaited(_controller.flushDraft());
    }
  }

  void _onMessageScroll() {
    if (!_messages.hasClients) return;
    final near = _messages.position.extentAfter <= 100;
    final was = _controller.threadVisibleAtBottom;
    _controller.threadVisibleAtBottom = near;
    if (near && !was) {
      unawaited(_controller.markCurrentRead());
      if (_newMessages && mounted) setState(() => _newMessages = false);
    }
  }

  void _changed() {
    if (!mounted) return;
    final nearBottom =
        !_messages.hasClients || _messages.position.extentAfter <= 100;
    final key = _controller.selected == null
        ? ''
        : chatKey(_controller.selected!);
    final switched = key != _selectedKey;
    final ownSend = _ownRevision != _controller.ownSendRevision;
    final changed = _revision != _controller.messageRevision;
    if (_composer.text != _controller.draft) {
      _composer.value = TextEditingValue(
        text: _controller.draft,
        selection: TextSelection.collapsed(offset: _controller.draft.length),
      );
    }
    _selectedKey = key;
    _revision = _controller.messageRevision;
    _ownRevision = _controller.ownSendRevision;
    if (switched) _newMessages = false;
    setState(() {});
    if (switched || (changed && (nearBottom || ownSend))) {
      _scrollBottom();
    } else if (changed) {
      setState(() => _newMessages = true);
    }
  }

  void _scrollBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_messages.hasClients) return;
      _messages.animateTo(
        _messages.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
      if (_newMessages) setState(() => _newMessages = false);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_changed);
    _controller.dispose();
    if (widget.repository == null) unawaited(_repository.dispose());
    _composer.dispose();
    _search.dispose();
    _messages.dispose();
    _inbox.dispose();
    super.dispose();
  }

  void _home() {
    final route = switch (widget.role) {
      'parent' => AppRoutes.parentDashboard,
      'teacher' => AppRoutes.teacherDashboard,
      'coordinator' => AppRoutes.coordinatorDashboard,
      _ => AppRoutes.principalDashboard,
    };
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      if (router.canPop()) {
        router.pop();
      } else {
        router.go(route);
      }
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  void _go(String route) {
    unawaited(SchoolDeskNavigation.push(context, route));
  }

  Future<void> _back() async {
    if (MediaQuery.viewInsetsOf(context).bottom > 0) {
      FocusManager.instance.primaryFocus?.unfocus();
      return;
    }
    if (_controller.selected != null) {
      await _controller.closeThread();
      return;
    }
    if (_controller.contactsOpen) {
      setState(() => _controller.contactsOpen = false);
      return;
    }
    _home();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    return Theme(
      data: Theme.of(context).copyWith(
        scaffoldBackgroundColor: _paper,
        dividerColor: _line,
        colorScheme: Theme.of(context).colorScheme.copyWith(
          primary: _blue,
          surface: _paper,
          onSurface: _ink,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 840,
              inThread = c.selected != null;
          return PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) unawaited(_back());
            },
            child: Scaffold(
              body: SafeArea(
                child: wide
                    ? Row(
                        children: [
                          SizedBox(width: 370, child: _inboxPane()),
                          VerticalDivider(width: 1, color: _line),
                          Expanded(
                            child: inThread ? _threadPane() : _emptyThread(),
                          ),
                        ],
                      )
                    : inThread
                    ? _threadPane()
                    : _inboxPane(),
              ),
              bottomNavigationBar: !wide && inThread
                  ? null
                  : NavigationBar(
                      height: 72,
                      backgroundColor: _paper,
                      indicatorColor: Colors.transparent,
                      selectedIndex: 0,
                      onDestinationSelected: (index) {
                        switch (index) {
                          case 0:
                            _home();
                          case 1:
                            _go(AppRoutes.globalSearch);
                          case 2:
                            _go(
                              '${AppRoutes.notificationCenter}?role=${widget.role}',
                            );
                          case 3:
                            _go(
                              '${AppRoutes.settingsScreen}?role=${widget.role}',
                            );
                        }
                      },
                      destinations: const [
                        NavigationDestination(
                          icon: Icon(Icons.home_outlined),
                          selectedIcon: Icon(Icons.home_rounded),
                          label: 'Home',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.search_rounded),
                          label: 'Search',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.notifications_none_rounded),
                          label: 'Notifications',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.settings_outlined),
                          label: 'Settings',
                        ),
                      ],
                    ),
            ),
          );
        },
      ),
    );
  }

  Widget _inboxPane() {
    final c = _controller, rows = _controller.visibleRows;
    final school =
        [...c.children, ...c.contacts, ...c.conversations]
            .map((e) => chatValue(e['school_name']))
            .where((e) => e.isNotEmpty)
            .firstOrNull ??
        'Your school';
    final classes =
        {...c.contacts, ...c.conversations}
            .map((e) => chatValue(e['class_label']))
            .where((e) => e.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: 'Back to dashboard',
                    onPressed: _home,
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  Expanded(
                    child: Text(
                      c.contactsOpen ? 'New message' : _roleLabel(widget.role),
                      style: TextStyle(
                        color: _blue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (c.contactsOpen)
                    IconButton(
                      tooltip: 'Close contacts',
                      onPressed: () => setState(() => c.contactsOpen = false),
                      icon: const Icon(Icons.close),
                    ),
                ],
              ),
              if (!c.contactsOpen) ...[
                Text(
                  'Messages',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(school, style: TextStyle(fontSize: 15, color: _muted)),
              ],
              if (c.leadership && !c.contactsOpen)
                Padding(
                  padding: const EdgeInsets.only(top: 18),
                  child: SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: false, label: Text('Direct')),
                        ButtonSegment(value: true, label: Text('Monitor')),
                      ],
                      selected: {c.monitor},
                      showSelectedIcon: false,
                      onSelectionChanged: (value) =>
                          unawaited(c.changeMonitor(value.first)),
                    ),
                  ),
                ),
              if (widget.role == 'parent' && c.children.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: _chips(
                    c.children
                        .map(
                          (row) => ChoiceChip(
                            label: Text(
                              chatContext({
                                ...row,
                                'student_name':
                                    row['name'] ?? row['student_name'],
                              }),
                            ),
                            selected: c.studentId == chatValue(row['id']),
                            onSelected: (_) =>
                                unawaited(c.changeChild(chatValue(row['id']))),
                          ),
                        )
                        .toList(),
                  ),
                ),
              const SizedBox(height: 14),
              TextField(
                controller: _search,
                onChanged: (value) {
                  c.search = value;
                  c.updateFilters();
                },
                decoration: InputDecoration(
                  hintText: c.contactsOpen
                      ? 'Search your school team'
                      : c.monitor
                      ? 'Search parent, teacher or child'
                      : widget.role == 'teacher'
                      ? 'Search parent, child or class'
                      : 'Search conversations',
                  hintStyle: TextStyle(color: _muted, fontSize: 14),
                  prefixIcon: Icon(Icons.search_rounded, color: _muted),
                  filled: true,
                  fillColor: _wall,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              if (widget.role == 'teacher' && classes.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: _chips([
                    ChoiceChip(
                      label: const Text('All assigned'),
                      selected: c.classFilter.isEmpty,
                      onSelected: (_) {
                        c.classFilter = '';
                        c.updateFilters();
                      },
                    ),
                    for (final label in classes)
                      ChoiceChip(
                        label: Text(label),
                        selected: c.classFilter == label,
                        onSelected: (_) {
                          c.classFilter = label;
                          c.updateFilters();
                        },
                      ),
                  ]),
                ),
              if (!c.contactsOpen)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: c.monitor
                      ? Row(
                          children: [
                            Expanded(
                              child: _chips([
                                ActionChip(
                                  label: Text(
                                    c.classFilter.isEmpty
                                        ? 'All classes'
                                        : c.classFilter,
                                  ),
                                  avatar: const Icon(
                                    Icons.expand_more,
                                    size: 18,
                                  ),
                                  onPressed: _showFilters,
                                ),
                                FilterChip(
                                  label: const Text('Unread'),
                                  selected: c.unreadOnly,
                                  onSelected: (value) {
                                    c.unreadOnly = value;
                                    c.updateFilters();
                                  },
                                ),
                              ]),
                            ),
                            IconButton(
                              tooltip: 'Filter conversations',
                              onPressed: _showFilters,
                              icon: const Icon(Icons.tune_rounded),
                            ),
                          ],
                        )
                      : _chips([
                          for (final category
                              in widget.role == 'parent'
                                  ? ['All', 'Unread', 'School team']
                                  : c.leadership
                                  ? ['All', 'Teachers', 'Parents', 'Unread']
                                  : ['All', 'Unread', 'Parents', 'Leadership'])
                            ChoiceChip(
                              label: Text(category),
                              selected: c.category == category,
                              onSelected: (_) {
                                if (category == 'School team') {
                                  c.contactsOpen = true;
                                  c.search = '';
                                  _search.clear();
                                } else {
                                  c.category = category;
                                }
                                c.updateFilters();
                              },
                            ),
                        ]),
                ),
            ],
          ),
        ),
        if (c.error != null && rows.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            color: _wall,
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 18, color: _muted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'A conversation could not be loaded. Your accessible chats are below.',
                    style: TextStyle(color: _muted, fontSize: 12),
                  ),
                ),
                IconButton(
                  tooltip: 'Retry loading conversations',
                  onPressed: () => unawaited(c.refresh()),
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
          ),
        if (c.connection != ChatConnectionStatus.connected) _connectionStrip(),
        if (c.loading && c.conversations.isEmpty && c.contacts.isEmpty)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (c.error != null && rows.isEmpty)
          Expanded(
            child: _error(
              'Messages could not be loaded.',
              () => unawaited(c.initialize()),
            ),
          )
        else
          Expanded(
            child: Stack(
              children: [
                RefreshIndicator(
                  onRefresh: c.refresh,
                  child: ListView.separated(
                    key: PageStorageKey(
                      'chat-inbox-${widget.role}-${c.monitor}-${c.contactsOpen}',
                    ),
                    controller: _inbox,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 90),
                    itemCount: rows.isEmpty
                        ? 1
                        : rows.length +
                              (c.hasMoreInbox && !c.contactsOpen ? 1 : 0),
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      indent: 20,
                      endIndent: 20,
                      color: _line,
                    ),
                    itemBuilder: (context, index) {
                      if (rows.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.all(36),
                          child: Text(
                            c.contactsOpen
                                ? 'No contacts match this selection.'
                                : 'No conversations yet. Start a message with your school team.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: _muted),
                          ),
                        );
                      }
                      if (index == rows.length) {
                        return TextButton(
                          onPressed: c.loading
                              ? null
                              : () => unawaited(c.loadMoreInbox()),
                          child: Text(
                            c.loading ? 'Loading…' : 'Load more conversations',
                          ),
                        );
                      }
                      return _conversationTile(rows[index]);
                    },
                  ),
                ),
                if (!c.monitor && !c.contactsOpen)
                  Positioned(
                    right: 18,
                    bottom: 18,
                    child: FloatingActionButton(
                      tooltip: 'New message',
                      backgroundColor: _blue,
                      foregroundColor:
                          Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF09213E)
                          : Colors.white,
                      onPressed: () {
                        c.search = '';
                        _search.clear();
                        setState(() => c.contactsOpen = true);
                      },
                      child: const Icon(Icons.edit_outlined),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _chips(List<Widget> children) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        for (final child in children)
          Padding(padding: const EdgeInsets.only(right: 8), child: child),
      ],
    ),
  );
  Widget _connectionStrip() {
    final state = _controller.connection;
    final label = switch (state) {
      ChatConnectionStatus.offline => 'Offline · messages will be queued',
      ChatConnectionStatus.reconnecting => 'Reconnecting…',
      ChatConnectionStatus.connecting => 'Connecting…',
      _ => '',
    };
    return Container(
      width: double.infinity,
      color: _wall,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Text(label, style: TextStyle(color: _muted, fontSize: 12)),
    );
  }

  Widget _conversationTile(Map<String, dynamic> row) {
    final c = _controller, monitor = c.monitor && !c.contactsOpen;
    final name = chatName(row, widget.role, monitor: monitor);
    final unread = int.tryParse('${row['unread_count']}') ?? 0;
    final contextLabel = chatContext(row);
    final role = chatContactRole(row, widget.role);
    return InkWell(
      onTap: () {
        FocusManager.instance.primaryFocus?.unfocus();
        unawaited(c.openThread(row));
      },
      child: Container(
        color: c.selected != null && chatKey(c.selected!) == chatKey(row)
            ? _blue.withValues(alpha: 0.07)
            : null,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 17),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (monitor)
              SizedBox(
                width: 68,
                height: 48,
                child: Stack(
                  children: [
                    _avatar(
                      chatValue(
                        row['parent_name'] ?? chatMap(row['parent'])['name'],
                      ),
                      chatPhoto(row, widget.role, parent: true),
                      radius: 23,
                    ),
                    Positioned(
                      left: 25,
                      child: _avatar(
                        chatValue(
                          row['teacher_name'] ??
                              chatMap(row['teacher'])['name'],
                        ),
                        chatPhoto(row, widget.role),
                        radius: 23,
                      ),
                    ),
                  ],
                ),
              )
            else
              _avatar(name, chatPhoto(row, widget.role)),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name.isEmpty ? 'School contact' : name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    monitor
                        ? contextLabel
                        : [
                            role,
                            contextLabel,
                          ].where((s) => s.isNotEmpty).join(' · '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: _muted, fontSize: 13),
                  ),
                  if (chatValue(row['last_message']).isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Text(
                        chatValue(row['last_message']),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: _muted, fontSize: 13),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _time(row['last_message_at']),
                  style: TextStyle(fontSize: 11, color: _muted),
                ),
                if (unread > 0)
                  Container(
                    margin: const EdgeInsets.only(top: 9),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _blue,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$unread',
                      style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? _ink
                            : Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                if (c.contactsOpen) Icon(Icons.chevron_right, color: _muted),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyThread() => ColoredBox(
    color: _wall,
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.forum_outlined, size: 48, color: _muted),
          const SizedBox(height: 16),
          Text(
            'Choose a conversation',
            style: TextStyle(
              color: _ink,
              fontSize: 21,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your school conversations, in context.',
            style: TextStyle(color: _muted),
          ),
        ],
      ),
    ),
  );
  Widget _threadPane() {
    final c = _controller, row = c.selected!;
    final monitor =
        c.monitor &&
        row['_contact'] != true &&
        chatValue(row['type']) == 'parent_teacher';
    final name = chatName(row, widget.role, monitor: monitor),
        contextLabel = chatContext(row);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 10, 16, 12),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Back to conversations',
                onPressed: () => unawaited(_back()),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              if (monitor) ...[
                SizedBox(
                  width: 62,
                  height: 46,
                  child: Stack(
                    children: [
                      _avatar(
                        chatName(row, 'teacher'),
                        chatPhoto(row, widget.role, parent: true),
                        radius: 22,
                      ),
                      Positioned(
                        left: 22,
                        child: _avatar(
                          chatName(row, 'parent'),
                          chatPhoto(row, widget.role),
                          radius: 22,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
              ],
              if (!monitor) ...[
                _avatar(name, chatPhoto(row, widget.role), radius: 23),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      monitor && contextLabel.isNotEmpty
                          ? contextLabel
                          : name.isEmpty
                          ? 'School contact'
                          : name,
                      style: TextStyle(
                        color: _ink,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      monitor ? name : chatContactRole(row, widget.role),
                      style: TextStyle(color: _muted, fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!monitor && contextLabel.isNotEmpty)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              contextLabel,
              style: TextStyle(color: _blue, fontWeight: FontWeight.w600),
            ),
          ),
        if (monitor)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _directFromMonitor(row, 'parent'),
                    icon: const Icon(Icons.person_outline, size: 18),
                    label: const Text('Message parent'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _directFromMonitor(row, 'teacher'),
                    icon: const Icon(Icons.person_outline, size: 18),
                    label: const Text('Message teacher'),
                  ),
                ),
              ],
            ),
          ),
        if (chatValue(row['type']) == 'parent_teacher')
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            color: monitor ? _blue.withValues(alpha: 0.08) : _paper,
            child: Row(
              children: [
                Icon(
                  monitor ? Icons.visibility_outlined : Icons.info_outline,
                  size: 18,
                  color: _muted,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    monitor
                        ? 'School oversight · You can view and reply to this conversation.'
                        : 'School leadership can review this conversation.',
                    style: TextStyle(color: _muted, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        if (c.connection != ChatConnectionStatus.connected) _connectionStrip(),
        Expanded(
          child: ColoredBox(
            color: _wall,
            child: Stack(
              children: [
                if (c.messagesLoading)
                  const Center(child: CircularProgressIndicator())
                else if (c.messageError != null && c.messages.isEmpty)
                  _error(
                    'This conversation could not be loaded.',
                    () => unawaited(c.openThread(row)),
                  )
                else
                  ListView.builder(
                    key: ValueKey(_selectedKey),
                    controller: _messages,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    itemCount: c.messages.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return c.hasOlder
                            ? Center(
                                child: TextButton(
                                  onPressed: c.olderLoading ? null : _loadOlder,
                                  child: Text(
                                    c.olderLoading
                                        ? 'Loading…'
                                        : 'Load older messages',
                                  ),
                                ),
                              )
                            : c.messages.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.only(top: 30),
                                child: Text(
                                  'Start the conversation.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: _muted),
                                ),
                              )
                            : const SizedBox.shrink();
                      }
                      final message = c.messages[index - 1];
                      final previous = index > 1 ? c.messages[index - 2] : null;
                      final date = _day(
                        message['sent_at'] ?? message['created_at'],
                      );
                      return Column(
                        children: [
                          if (previous == null ||
                              date !=
                                  _day(
                                    previous['sent_at'] ??
                                        previous['created_at'],
                                  ))
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              child: Text(
                                date,
                                style: TextStyle(fontSize: 12, color: _muted),
                              ),
                            ),
                          _bubble(message, monitor: monitor),
                        ],
                      );
                    },
                  ),
                if (_newMessages)
                  Positioned(
                    bottom: 12,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: FilledButton.icon(
                        onPressed: _scrollBottom,
                        icon: const Icon(Icons.arrow_downward, size: 16),
                        label: const Text('New messages'),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: _paper,
            border: Border(top: BorderSide(color: _line)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('chat-composer'),
                    controller: _composer,
                    minLines: 1,
                    maxLines: 5,
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: c.updateDraft,
                    decoration: InputDecoration(
                      hintText: monitor
                          ? 'Reply to this conversation…'
                          : 'Message ${name.split(' ').firstOrNull ?? 'contact'}…',
                      filled: true,
                      fillColor: _wall,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 13,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide(color: _line),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filled(
                  tooltip: 'Send message',
                  onPressed: () => unawaited(c.send()),
                  style: IconButton.styleFrom(
                    backgroundColor: _blue,
                    foregroundColor:
                        Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF09213E)
                        : Colors.white,
                    minimumSize: const Size(48, 48),
                  ),
                  icon: const Icon(Icons.send_rounded),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _loadOlder() async {
    final before = _messages.hasClients
        ? _messages.position.maxScrollExtent
        : 0.0;
    final offset = _messages.hasClients ? _messages.offset : 0.0;
    await _controller.loadOlder();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _messages.hasClients) {
        _messages.jumpTo(offset + _messages.position.maxScrollExtent - before);
      }
    });
  }

  Widget _bubble(Map<String, dynamic> message, {required bool monitor}) {
    final mine =
        chatValue(message['sender_user_id'] ?? message['sender_id']) ==
        _repository.currentUserId;
    final status = chatValue(message['_delivery']);
    final sender = chatValue(message['sender_name']);
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (monitor && !mine) ...[
                _avatar(
                  sender,
                  chatValue(message['sender_avatar_url']),
                  radius: 17,
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Column(
                  crossAxisAlignment: mine
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    if (monitor)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: Text(
                          '${mine ? 'You' : sender} · ${_roleLabel(chatValue(message['sender_role']))}',
                          style: TextStyle(color: _muted, fontSize: 11),
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 13,
                      ),
                      decoration: BoxDecoration(
                        color: mine ? const Color(0xFF00878B) : _paper,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(20),
                          topRight: const Radius.circular(20),
                          bottomLeft: Radius.circular(mine ? 20 : 5),
                          bottomRight: Radius.circular(mine ? 5 : 20),
                        ),
                        border: mine
                            ? null
                            : Border.all(color: _line.withValues(alpha: 0.7)),
                      ),
                      child: SelectableText(
                        chatValue(message['body'] ?? message['message']),
                        style: TextStyle(
                          color: mine ? Colors.white : _ink,
                          fontSize: 16,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${_time(message['sent_at'] ?? message['created_at'])}${mine ? '  ${message['recipient_read'] == true && status == 'Sent' ? 'Read' : status}' : ''}',
                          style: TextStyle(
                            color: status == 'Failed'
                                ? Theme.of(context).colorScheme.error
                                : _muted,
                            fontSize: 11,
                          ),
                        ),
                        if (mine && status == 'Failed')
                          TextButton(
                            onPressed: () =>
                                unawaited(_controller.send(retry: message)),
                            child: const Text('Retry'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _avatar(String name, String url, {double radius = 25}) {
    final letters = name
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .take(2)
        .map((e) => e[0].toUpperCase())
        .join();
    final palette = [
      const Color(0xFFC8E2FF),
      const Color(0xFFFFD4DE),
      const Color(0xFFBEF0E6),
      const Color(0xFFE0D4FF),
    ];
    return CircleAvatar(
      radius: radius,
      backgroundColor: palette[name.hashCode.abs() % palette.length],
      foregroundColor: const Color(0xFF153653),
      child: url.isEmpty
          ? Text(
              letters.isEmpty ? '?' : letters,
              style: TextStyle(
                fontSize: radius * 0.65,
                fontWeight: FontWeight.w600,
              ),
            )
          : ClipOval(
              child: Image.network(
                resolveOriginalImageUrl(url),
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                errorBuilder: (_, error, ___) {
                  if (error is NetworkImageLoadException &&
                      (error.statusCode == 401 || error.statusCode == 403)) {
                    final key =
                        '${_repository.accountScope}:${Uri.tryParse(url)?.path ?? url}';
                    if (_avatarRefreshes.add(key)) {
                      scheduleMicrotask(() => unawaited(_controller.refresh()));
                    }
                  }
                  return Center(child: Text(letters.isEmpty ? '?' : letters));
                },
              ),
            ),
    );
  }

  Widget _error(String label, VoidCallback retry) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_outlined, color: _muted, size: 35),
          const SizedBox(height: 12),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(color: _ink),
          ),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: retry, child: const Text('Try again')),
        ],
      ),
    ),
  );
  void _directFromMonitor(Map<String, dynamic> row, String role) {
    final id = chatValue(
      row['${role}_id'] ?? row['${role}_user_id'] ?? chatMap(row[role])['id'],
    );
    final candidates = _controller.contacts.where(
      (c) =>
          chatValue(c['id']) == id &&
          (role != 'parent' ||
              chatValue(c['student_id']) == chatValue(row['student_id'])),
    );
    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This contact is currently unavailable.')),
      );
      return;
    }
    unawaited(
      _controller.openThread({
        ...candidates.first,
        '_contact': true,
      }, nested: true),
    );
  }

  Future<void> _showFilters() async {
    final c = _controller;
    final personController = TextEditingController(text: c.personFilter);
    var className = c.classFilter,
        teacher = c.teacherFilter,
        person = c.personFilter,
        unread = c.unreadOnly;
    DateTime? date = c.dateFilter;
    final classes =
        c.conversations
            .map((e) => chatValue(e['class_label']))
            .where((e) => e.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final teachers = <String, String>{
      for (final row in c.conversations)
        if (chatValue(row['teacher_id']).isNotEmpty)
          chatValue(row['teacher_id']): chatValue(
            row['teacher_name'] ?? chatMap(row['teacher'])['name'],
          ),
    };
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: _paper,
      builder: (sheet) => StatefulBuilder(
        builder: (sheet, setSheet) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              0,
              20,
              20 + MediaQuery.viewInsetsOf(sheet).bottom,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Filter conversations',
                          style: TextStyle(
                            color: _ink,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close filters',
                        onPressed: () => Navigator.of(sheet).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: classes.contains(className) ? className : '',
                    decoration: const InputDecoration(labelText: 'Class'),
                    items: [
                      const DropdownMenuItem(
                        value: '',
                        child: Text('All classes'),
                      ),
                      for (final value in classes)
                        DropdownMenuItem(value: value, child: Text(value)),
                    ],
                    onChanged: (value) =>
                        setSheet(() => className = value ?? ''),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: teachers.containsKey(teacher) ? teacher : '',
                    decoration: const InputDecoration(labelText: 'Teacher'),
                    items: [
                      const DropdownMenuItem(
                        value: '',
                        child: Text('Any teacher'),
                      ),
                      for (final entry in teachers.entries)
                        DropdownMenuItem(
                          value: entry.key,
                          child: Text(entry.value),
                        ),
                    ],
                    onChanged: (value) => setSheet(() => teacher = value ?? ''),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: personController,
                    decoration: const InputDecoration(
                      labelText: 'Parent or child',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    onChanged: (value) => person = value,
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today_outlined),
                    title: const Text('Date'),
                    subtitle: Text(
                      date == null
                          ? 'Any date'
                          : DateFormat.yMMMd().format(date!),
                    ),
                    onTap: () async {
                      final chosen = await showDatePicker(
                        context: sheet,
                        initialDate: date ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                      );
                      if (chosen != null) setSheet(() => date = chosen);
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Unread only'),
                    value: unread,
                    onChanged: (value) => setSheet(() => unread = value),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => setSheet(() {
                            className = '';
                            teacher = '';
                            person = '';
                            personController.clear();
                            date = null;
                            unread = false;
                          }),
                          child: const Text('Reset'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            c.classFilter = className;
                            c.teacherFilter = teacher;
                            c.personFilter = person;
                            c.dateFilter = date;
                            c.unreadOnly = unread;
                            c.updateFilters();
                            Navigator.of(sheet).pop();
                          },
                          child: const Text('Apply filters'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    personController.dispose();
  }
}

String _roleLabel(String role) => switch (role) {
  'principal' => 'Principal',
  'coordinator' => 'Coordinator',
  'teacher' => 'Teacher',
  'co_teacher' => 'Co-teacher',
  'parent' => 'Parent',
  _ => role.replaceAll('_', ' '),
};
String _time(Object? input) {
  final value = DateTime.tryParse(chatValue(input))?.toLocal();
  if (value == null) return '';
  return DateFormat('HH:mm').format(value);
}

String _day(Object? input) {
  final value = DateTime.tryParse(chatValue(input))?.toLocal();
  if (value == null) return '';
  final now = DateTime.now();
  if (value.year == now.year &&
      value.month == now.month &&
      value.day == now.day) {
    return 'Today';
  }
  return DateFormat.yMMMd().format(value);
}
