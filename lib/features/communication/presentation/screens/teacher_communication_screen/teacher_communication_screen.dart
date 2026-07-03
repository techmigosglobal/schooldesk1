import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:schooldesk1/core/navigation/role_nav_indices.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/services/role_access_service.dart';
import 'package:schooldesk1/core/utils/extensions.dart';
import 'package:schooldesk1/core/widgets/teacher_flow_ui.dart';
import 'package:schooldesk1/features/communication/presentation/widgets/chat_shared_widgets.dart';

class TeacherCommunicationScreen extends StatefulWidget {
  const TeacherCommunicationScreen({super.key});

  @override
  State<TeacherCommunicationScreen> createState() =>
      _TeacherCommunicationScreenState();
}

class _TeacherCommunicationScreenState
    extends State<TeacherCommunicationScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _pollingTimer;

  bool _loading = true;
  bool _sending = false;
  String? _error;
  String _teacherUserId = '';
  List<Map<String, dynamic>> _conversations = const [];
  List<Map<String, dynamic>> _messages = const [];
  Map<String, dynamic>? _selectedConversation;

  @override
  void initState() {
    super.initState();
    _load();
    _pollingTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted && !_sending) _load(background: true);
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _messageController.dispose();
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
      await RoleAccessService.initialize();
      final api = BackendApiClient.instance;
      final profile = await api.getProfile();
      final conversations = await api.getUnifiedChatConversations(
        type: 'parent_teacher',
        teacherId: RoleAccessService.teacherStaffId,
      );
      final principalConversations = await api.getUnifiedChatConversations(
        type: 'principal_teacher',
        teacherId: RoleAccessService.teacherStaffId,
      );
      conversations.addAll(principalConversations);
      conversations.sort((a, b) => _sortTime(b).compareTo(_sortTime(a)));
      final selected = _selectConversation(conversations);
      final messages = selected == null
          ? <Map<String, dynamic>>[]
          : await api.getUnifiedChatMessages(
              conversationId: _text(selected['id']),
            );
      if (!mounted) return;
      setState(() {
        _teacherUserId = profile.id;
        _conversations = conversations;
        _selectedConversation = selected;
        _messages = messages;
        _loading = false;
      });
      _scrollToBottom();
      if (selected != null) {
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
    List<Map<String, dynamic>> conversations,
  ) {
    if (conversations.isEmpty) return null;
    final selectedId = _text(_selectedConversation?['id']);
    return conversations.firstWhere(
      (row) => _text(row['id']) == selectedId,
      orElse: () => conversations.first,
    );
  }

  Future<void> _send() async {
    final conversation = _selectedConversation;
    final body = _messageController.text.trim();
    if (conversation == null || body.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await BackendApiClient.instance.sendUnifiedChatMessage(
        conversationId: _text(conversation['id']),
        body: body,
      );
      _messageController.clear();
      await _load();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TeacherFlowScaffold(
      title: 'Parent Messages',
      subtitle: 'WhatsApp-style parent conversations monitored by principal',
      selectedIndex: TeacherNav.communication,
      loading: _loading,
      error: _error,
      onRefresh: _load,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 780;
          final list = _conversationList();
          final chat = _chatPane();
          if (wide) {
            return Row(
              children: [
                SizedBox(width: 340, child: list),
                VerticalDivider(
                  width: 1,
                  color: context.appTheme.outlineVariant,
                ),
                Expanded(child: chat),
              ],
            );
          }
          return _selectedConversation == null ? list : chat;
        },
      ),
    );
  }

  Widget _conversationList() {
    if (_conversations.isEmpty) {
      return const Center(
        child: TeacherFlowCard(
          icon: Icons.forum_rounded,
          title: 'No parent chats yet',
          subtitle:
              'Parent conversations for your assigned students appear here.',
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemCount: _conversations.length,
      separatorBuilder: (_, __) =>
          Divider(height: 1, color: context.appTheme.outlineVariant),
      itemBuilder: (context, index) {
        final row = _conversations[index];
        final selected =
            _text(row['id']) == _text(_selectedConversation?['id']);
        final parent = _map(row['parent']);
        final student = _map(row['student']);
        final isPrincipal = _text(row['type']) == 'principal_teacher';
        final label = isPrincipal
            ? 'Principal'
            : _name(parent, fallback: 'Parent');
        final unread = int.tryParse('${row['unread_count'] ?? 0}') ?? 0;
        return ListTile(
          selected: selected,
          leading: CircleAvatar(child: Text(_initials(label))),
          title: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            _text(row['last_message']).isEmpty
                ? (isPrincipal
                      ? 'School leadership'
                      : _name(student, fallback: 'Student'))
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
                    color: teacherFlowAccent,
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
            _load(background: true);
          },
        );
      },
    );
  }

  Widget _chatPane() {
    final conversation = _selectedConversation;
    if (conversation == null) {
      return const Center(child: Text('Select a parent conversation.'));
    }
    final parent = _map(conversation['parent']);
    final student = _map(conversation['student']);
    final isPrincipal = _text(conversation['type']) == 'principal_teacher';
    final label = isPrincipal ? 'Principal' : _name(parent, fallback: 'Parent');
    return Column(
      children: [
        ListTile(
          leading: CircleAvatar(child: Text(_initials(label))),
          title: Text(label),
          subtitle: Text(
            isPrincipal
                ? 'Direct message with school leadership'
                : '${_name(student, fallback: 'Student')} - Principal can monitor this chat',
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
                    _teacherUserId;
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
        ChatInputBar(
          controller: _messageController,
          isSending: _sending,
          onAttach: () {},
          onSend: _send,
          placeholder: 'Message $label',
        ),
      ],
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
  if (words.isEmpty) return 'P';
  return words.take(2).map((w) => w[0].toUpperCase()).join();
}

DateTime? _date(Object? value) => DateTime.tryParse(_text(value));

int _sortTime(Map<String, dynamic> row) =>
    _date(row['last_message_at'])?.millisecondsSinceEpoch ?? 0;

String _time(DateTime? value) {
  if (value == null) return '';
  return DateFormat('h:mm a').format(value.toLocal());
}
