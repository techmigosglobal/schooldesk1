import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:schooldesk1/core/navigation/role_nav_indices.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/utils/extensions.dart';
import 'package:schooldesk1/core/widgets/app_navigation.dart';
import 'package:schooldesk1/core/widgets/dashboard_fab_widget.dart';
import 'package:schooldesk1/core/widgets/erp_module_scaffold.dart';
import 'package:schooldesk1/features/communication/presentation/widgets/chat_shared_widgets.dart';

class PrincipalChatCommunicationsScreen extends StatefulWidget {
  const PrincipalChatCommunicationsScreen({super.key});

  @override
  State<PrincipalChatCommunicationsScreen> createState() =>
      _PrincipalChatCommunicationsScreenState();
}

class _PrincipalChatCommunicationsScreenState
    extends State<PrincipalChatCommunicationsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _messageController = TextEditingController();
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _pollingTimer;

  bool _loading = true;
  bool _sending = false;
  bool _unreadOnly = false;
  String? _error;
  String _principalUserId = '';
  String _teacherFilter = '';
  String _parentFilter = '';
  String _studentFilter = '';
  DateTime? _dateFilter;
  List<Map<String, dynamic>> _monitorConversations = const [];
  List<Map<String, dynamic>> _directConversations = const [];
  List<Map<String, dynamic>> _messages = const [];
  Map<String, dynamic>? _selectedConversation;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
    _pollingTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted && !_sending) _load(background: true);
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _tabController.dispose();
    _messageController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load({bool background = false}) async {
    if (!background) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final api = BackendApiClient.instance;
      final profile = await api.getProfile();
      final monitor = await api.getUnifiedChatConversations(
        type: 'parent_teacher',
        monitor: true,
      );
      final directTeacher = await api.getUnifiedChatConversations(
        type: 'principal_teacher',
        monitor: true,
      );
      final directParent = await api.getUnifiedChatConversations(
        type: 'principal_parent',
        monitor: true,
      );
      final teacherContacts = await api.getStaff(page: 1, pageSize: 200);
      final parentContacts = await api.getUsers(
        role: 'Parent',
        page: 1,
        pageSize: 200,
      );
      final direct = _mergeDirectConversationsWithContacts(
        directTeacher: directTeacher,
        directParent: directParent,
        teacherContacts: teacherContacts.data,
        parentContacts: parentContacts.data,
      )..sort((a, b) {
          final leftPlaceholder = _isContactPlaceholder(a);
          final rightPlaceholder = _isContactPlaceholder(b);
          if (leftPlaceholder != rightPlaceholder) {
            return leftPlaceholder ? 1 : -1;
          }
          final timeCompare = _sortTime(b).compareTo(_sortTime(a));
          if (timeCompare != 0) return timeCompare;
          return _directTitle(a).compareTo(_directTitle(b));
        });
      monitor.sort((a, b) => _sortTime(b).compareTo(_sortTime(a)));
      final selected = _selectConversation(monitor, direct);
      final messages = selected == null
          ? <Map<String, dynamic>>[]
          : _isContactPlaceholder(selected)
          ? <Map<String, dynamic>>[]
          : await api.getUnifiedChatMessages(
              conversationId: _text(selected['id']),
            );
      if (!mounted) return;
      setState(() {
        _principalUserId = profile.id;
        _monitorConversations = monitor;
        _directConversations = direct;
        _selectedConversation = selected;
        _messages = messages;
        _loading = false;
      });
      _scrollToBottom();
      if (selected != null &&
          _canSendIn(selected) &&
          !_isContactPlaceholder(selected)) {
        unawaited(api.markUnifiedChatConversationRead(_text(selected['id'])));
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (!background) _error = error.toString();
      });
    }
  }

  Map<String, dynamic>? _selectConversation(
    List<Map<String, dynamic>> monitor,
    List<Map<String, dynamic>> direct,
  ) {
    final source = _tabController.index == 0
        ? _filteredMonitor(monitor)
        : direct;
    if (source.isEmpty) return null;
    final selectedId = _text(_selectedConversation?['id']);
    return source.firstWhere(
      (row) => _text(row['id']) == selectedId,
      orElse: () => source.first,
    );
  }

  List<Map<String, dynamic>> _filteredMonitor([
    List<Map<String, dynamic>>? source,
  ]) {
    final query = _searchController.text.trim().toLowerCase();
    return (source ?? _monitorConversations).where((row) {
      final teacher = _name(
        _map(row['teacher']),
        fallback: _text(row['teacher_id']),
      );
      final parent = _name(
        _map(row['parent']),
        fallback: _text(row['parent_id']),
      );
      final student = _name(
        _map(row['student']),
        fallback: _text(row['student_id']),
      );
      final haystack = '$teacher $parent $student ${_text(row['last_message'])}'
          .toLowerCase();
      if (query.isNotEmpty && !haystack.contains(query)) return false;
      if (_teacherFilter.isNotEmpty &&
          _text(row['teacher_id']) != _teacherFilter) {
        return false;
      }
      if (_parentFilter.isNotEmpty &&
          _text(row['parent_id']) != _parentFilter) {
        return false;
      }
      if (_studentFilter.isNotEmpty &&
          _text(row['student_id']) != _studentFilter) {
        return false;
      }
      if (_unreadOnly &&
          (int.tryParse('${row['unread_count'] ?? 0}') ?? 0) == 0) {
        return false;
      }
      if (_dateFilter != null) {
        final last = _date(row['last_message_at']);
        if (last == null ||
            last.year != _dateFilter!.year ||
            last.month != _dateFilter!.month ||
            last.day != _dateFilter!.day) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  Future<void> _send() async {
    final conversation = _selectedConversation;
    final body = _messageController.text.trim();
    if (conversation == null || body.isEmpty || !_canSendIn(conversation)) {
      return;
    }
    setState(() => _sending = true);
    try {
      var conversationId = _text(conversation['id']);
      if (_isContactPlaceholder(conversation)) {
        final created = await BackendApiClient.instance
            .createUnifiedChatConversation(
              type: _text(conversation['type'], fallback: 'principal_teacher'),
              teacherId: _text(conversation['teacher_id']),
              parentId: _text(conversation['parent_id']),
              studentId: _text(conversation['student_id']),
              title: _directTitle(conversation),
            );
        conversationId = _text(created['id']);
      }
      await BackendApiClient.instance.sendUnifiedChatMessage(
        conversationId: conversationId,
        body: body,
      );
      _messageController.clear();
      await _load();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _startDirect(Map<String, dynamic> source, String target) async {
    final teacherId = target == 'teacher' ? _text(source['teacher_id']) : '';
    final parentId = target == 'parent' ? _text(source['parent_id']) : '';
    if (teacherId.isEmpty && parentId.isEmpty) return;
    final created = await BackendApiClient.instance
        .createUnifiedChatConversation(
          type: target == 'teacher' ? 'principal_teacher' : 'principal_parent',
          teacherId: teacherId,
          parentId: parentId,
          studentId: _text(source['student_id']),
          title: target == 'teacher'
              ? _name(_map(source['teacher']), fallback: 'Teacher')
              : _name(_map(source['parent']), fallback: 'Parent'),
        );
    setState(() {
      _tabController.index = 1;
      _selectedConversation = created;
    });
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return SchoolDeskModuleScaffold(
      title: 'Communications',
      subtitle: 'Monitor parent-teacher chats and message staff or parents',
      drawer: PrincipalDrawer(
        selectedIndex: PrincipalNav.messages,
        onDestinationSelected: (_) {},
      ),
      floatingActionButton: const DashboardFabWidget(
        role: DashboardRole.principal,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      bottom: TabBar(
        controller: _tabController,
        onTap: (_) {
          setState(() => _selectedConversation = null);
          _load(background: true);
        },
        tabs: const [
          Tab(icon: Icon(Icons.visibility_rounded), text: 'Monitor'),
          Tab(icon: Icon(Icons.chat_rounded), text: 'Direct'),
        ],
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!));
    return TabBarView(
      controller: _tabController,
      children: [
        _workspace(_filteredMonitor(), monitorMode: true),
        _workspace(_directConversations, monitorMode: false),
      ],
    );
  }

  Widget _workspace(
    List<Map<String, dynamic>> conversations, {
    required bool monitorMode,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 840;
        final list = Column(
          children: [
            if (monitorMode) _filters(),
            Expanded(child: _conversationList(conversations, monitorMode)),
          ],
        );
        final chat = _chatPane(
          monitorMode: monitorMode,
          showBackButton: !wide,
        );
        if (wide) {
          return Row(
            children: [
              SizedBox(width: 380, child: list),
              VerticalDivider(width: 1, color: context.appTheme.outlineVariant),
              Expanded(child: chat),
            ],
          );
        }
        return _selectedConversation == null ? list : chat;
      },
    );
  }

  Widget _filters() {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search_rounded),
              labelText: 'Search teacher, parent, student, message',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _filterMenu(
                label: 'Teacher',
                value: _teacherFilter,
                options: {
                  for (final row in _monitorConversations)
                    _text(row['teacher_id']): _name(
                      _map(row['teacher']),
                      fallback: 'Teacher',
                    ),
                },
                onChanged: (value) => setState(() => _teacherFilter = value),
              ),
              _filterMenu(
                label: 'Parent',
                value: _parentFilter,
                options: {
                  for (final row in _monitorConversations)
                    _text(row['parent_id']): _name(
                      _map(row['parent']),
                      fallback: 'Parent',
                    ),
                },
                onChanged: (value) => setState(() => _parentFilter = value),
              ),
              _filterMenu(
                label: 'Student',
                value: _studentFilter,
                options: {
                  for (final row in _monitorConversations)
                    _text(row['student_id']): _name(
                      _map(row['student']),
                      fallback: 'Student',
                    ),
                },
                onChanged: (value) => setState(() => _studentFilter = value),
              ),
              FilterChip(
                label: const Text('Unread'),
                selected: _unreadOnly,
                onSelected: (value) => setState(() => _unreadOnly = value),
              ),
              ActionChip(
                avatar: const Icon(Icons.calendar_month_rounded, size: 18),
                label: Text(
                  _dateFilter == null
                      ? 'Date'
                      : DateFormat('dd MMM').format(_dateFilter!),
                ),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _dateFilter ?? DateTime.now(),
                    firstDate: DateTime.now().subtract(
                      const Duration(days: 365),
                    ),
                    lastDate: DateTime.now().add(const Duration(days: 30)),
                  );
                  if (picked != null) setState(() => _dateFilter = picked);
                },
              ),
              if (_dateFilter != null)
                ActionChip(
                  label: const Text('Clear date'),
                  onPressed: () => setState(() => _dateFilter = null),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filterMenu({
    required String label,
    required String value,
    required Map<String, String> options,
    required ValueChanged<String> onChanged,
  }) {
    final cleanOptions = Map<String, String>.fromEntries(
      options.entries.where((entry) => entry.key.isNotEmpty),
    );
    return PopupMenuButton<String>(
      tooltip: label,
      onSelected: onChanged,
      itemBuilder: (context) => [
        const PopupMenuItem(value: '', child: Text('All')),
        ...cleanOptions.entries.map(
          (entry) => PopupMenuItem(value: entry.key, child: Text(entry.value)),
        ),
      ],
      child: Chip(
        avatar: const Icon(Icons.filter_list_rounded, size: 18),
        label: Text(value.isEmpty ? label : cleanOptions[value] ?? label),
        onDeleted: value.isEmpty ? null : () => onChanged(''),
      ),
    );
  }

  Widget _conversationList(
    List<Map<String, dynamic>> conversations,
    bool monitorMode,
  ) {
    if (conversations.isEmpty) {
      return Center(
        child: Text(
          monitorMode
              ? 'No parent-teacher chats found.'
              : 'No direct chats yet.',
        ),
      );
    }
    return ListView.separated(
      itemCount: conversations.length,
      separatorBuilder: (_, __) =>
          Divider(height: 1, color: context.appTheme.outlineVariant),
      itemBuilder: (context, index) {
        final row = conversations[index];
        final selected =
            _text(row['id']) == _text(_selectedConversation?['id']);
        final title = monitorMode ? _monitorTitle(row) : _directTitle(row);
        final subtitle = monitorMode
            ? _studentLine(row)
            : _isContactPlaceholder(row)
            ? _text(
                row['type'],
                fallback: 'direct',
              ) ==
                    'principal_teacher'
                ? 'Teacher contact - tap to start direct chat'
                : 'Parent contact - tap to start direct chat'
            : _text(row['last_message'], fallback: 'Direct conversation');
        final unread = int.tryParse('${row['unread_count'] ?? 0}') ?? 0;
        return ListTile(
          selected: selected,
          leading: CircleAvatar(child: Text(_initials(title))),
          title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            _text(row['last_message']).isEmpty
                ? subtitle
                : _text(row['last_message']),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _time(_date(row['last_message_at'])),
                style: const TextStyle(fontSize: 11),
              ),
              if (unread > 0)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: context.appTheme.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$unread',
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
            ],
          ),
          onTap: () {
            setState(() => _selectedConversation = row);
            if (!_isContactPlaceholder(row)) {
              _load(background: true);
            }
          },
        );
      },
    );
  }

  Widget _chatPane({
    required bool monitorMode,
    required bool showBackButton,
  }) {
    final conversation = _selectedConversation;
    if (conversation == null) {
      return const Center(child: Text('Select a conversation.'));
    }
    final canSend = _canSendIn(conversation);
    return Column(
      children: [
        ListTile(
          leading: showBackButton
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  tooltip: 'Back to chats',
                  onPressed: () => setState(() => _selectedConversation = null),
                )
              : CircleAvatar(
                  child: Text(
                    _initials(
                      monitorMode
                          ? _monitorTitle(conversation)
                          : _directTitle(conversation),
                    ),
                  ),
                ),
          title: Text(
            monitorMode
                ? _monitorTitle(conversation)
                : _directTitle(conversation),
          ),
          subtitle: Text(
            monitorMode
                ? 'Principal monitoring view - read only'
                : 'Principal direct message',
          ),
          trailing: monitorMode
              ? Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.school_rounded, size: 18),
                      label: const Text('Message teacher'),
                      onPressed: () => _startDirect(conversation, 'teacher'),
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.family_restroom_rounded, size: 18),
                      label: const Text('Message parent'),
                      onPressed: () => _startDirect(conversation, 'parent'),
                    ),
                  ],
                )
              : null,
        ),
        if (monitorMode)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: context.appTheme.warningContainer,
            child: Text(
              'Read-only oversight. Principal replies are sent through separate direct chats.',
              style: TextStyle(color: context.appTheme.onSurface),
            ),
          ),
        Expanded(
          child: ChatWallpaperBackground(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(vertical: 12),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final mine =
                    _text(message['sender_user_id'] ?? message['sender_id']) ==
                    _principalUserId;
                return ChatBubbleWidget(
                  messageText: _text(message['body'] ?? message['message']),
                  time: _time(
                    _date(message['sent_at'] ?? message['created_at']),
                  ),
                  isMe: mine,
                  isRead: message['is_read'] == true,
                );
              },
            ),
          ),
        ),
        if (canSend)
          ChatInputBar(
            controller: _messageController,
            isSending: _sending,
            onSend: _send,
            placeholder: 'Type a direct message',
          ),
      ],
    );
  }

  bool _canSendIn(Map<String, dynamic> conversation) =>
      _text(conversation['type']) != 'parent_teacher';

  List<Map<String, dynamic>> _mergeDirectConversationsWithContacts({
    required List<Map<String, dynamic>> directTeacher,
    required List<Map<String, dynamic>> directParent,
    required List<dynamic> teacherContacts,
    required List<dynamic> parentContacts,
  }) {
    final rows = <Map<String, dynamic>>[
      ...directTeacher.map((row) => Map<String, dynamic>.from(row)),
      ...directParent.map((row) => Map<String, dynamic>.from(row)),
    ];
    final existingTeacherIds = rows
        .where((row) => _text(row['type']) == 'principal_teacher')
        .map((row) => _text(row['teacher_id']))
        .where((id) => id.isNotEmpty)
        .toSet();
    final existingParentIds = rows
        .where((row) => _text(row['type']) == 'principal_parent')
        .map((row) => _text(row['parent_id']))
        .where((id) => id.isNotEmpty)
        .toSet();

    for (final contact in teacherContacts) {
      final id = _text(contact.id);
      if (id.isEmpty || existingTeacherIds.contains(id)) continue;
      rows.add({
        'id': 'contact-teacher-$id',
        'type': 'principal_teacher',
        'teacher_id': id,
        'parent_id': '',
        'student_id': '',
        'last_message': '',
        'last_message_at': '',
        'unread_count': 0,
        'teacher': {
          'id': id,
          'first_name': _text(contact.firstName),
          'last_name': _text(contact.lastName),
          'name': '${_text(contact.firstName)} ${_text(contact.lastName)}'
              .trim(),
        },
        'is_contact_placeholder': true,
      });
    }

    for (final contact in parentContacts) {
      final id = _text(contact.id);
      if (id.isEmpty || existingParentIds.contains(id)) continue;
      rows.add({
        'id': 'contact-parent-$id',
        'type': 'principal_parent',
        'teacher_id': '',
        'parent_id': id,
        'student_id': '',
        'last_message': '',
        'last_message_at': '',
        'unread_count': 0,
        'parent': {
          'id': id,
          'name': _text(contact.name, fallback: _text(contact.username)),
          'full_name': _text(contact.name, fallback: _text(contact.username)),
        },
        'is_contact_placeholder': true,
      });
    }
    return rows;
  }

  bool _isContactPlaceholder(Map<String, dynamic> row) =>
      row['is_contact_placeholder'] == true;

  String _monitorTitle(Map<String, dynamic> row) {
    return [
      _name(_map(row['teacher']), fallback: 'Teacher'),
      _name(_map(row['parent']), fallback: 'Parent'),
    ].join(' / ');
  }

  String _directTitle(Map<String, dynamic> row) {
    final type = _text(row['type']);
    if (type == 'principal_teacher') {
      return _name(_map(row['teacher']), fallback: 'Teacher');
    }
    return _name(_map(row['parent']), fallback: 'Parent');
  }

  String _studentLine(Map<String, dynamic> row) {
    final student = _map(row['student']);
    return _name(
      student,
      fallback: _text(row['student_id'], fallback: 'Student'),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }
}

Map<String, dynamic> _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

String _text(Object? value, {String fallback = ''}) {
  final text = '${value ?? ''}'.trim();
  return text.isEmpty ? fallback : text;
}

String _name(Map<String, dynamic> row, {String fallback = ''}) {
  final full = _text(row['name'] ?? row['full_name']);
  if (full.isNotEmpty) return full;
  final parts = [
    _text(row['first_name']),
    _text(row['last_name']),
  ].where((part) => part.isNotEmpty).join(' ');
  return parts.isEmpty ? fallback : parts;
}

String _initials(String value) {
  final words = value.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return 'C';
  return words.take(2).map((w) => w[0].toUpperCase()).join();
}

DateTime? _date(Object? value) => DateTime.tryParse(_text(value));

int _sortTime(Map<String, dynamic> row) =>
    _date(row['last_message_at'])?.millisecondsSinceEpoch ?? 0;

String _time(DateTime? value) {
  if (value == null) return '';
  return DateFormat('h:mm a').format(value.toLocal());
}
