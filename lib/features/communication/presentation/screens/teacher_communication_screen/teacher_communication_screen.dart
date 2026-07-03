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
      final parentConversations = await api.getUnifiedChatConversations(
        type: 'parent_teacher',
        teacherId: RoleAccessService.teacherStaffId,
      );
      final principalConversations = await api.getUnifiedChatConversations(
        type: 'principal_teacher',
        teacherId: RoleAccessService.teacherStaffId,
      );
      final users = await api.getUsers(page: 1, pageSize: 200);
      final conversations = _mergeConversationsWithContacts(
        parentConversations: parentConversations,
        principalConversations: principalConversations,
        userContacts: users.data,
      )..sort((a, b) {
          final leftPlaceholder = _isContactPlaceholder(a);
          final rightPlaceholder = _isContactPlaceholder(b);
          if (leftPlaceholder != rightPlaceholder) {
            return leftPlaceholder ? 1 : -1;
          }
          final timeCompare = _sortTime(b).compareTo(_sortTime(a));
          if (timeCompare != 0) return timeCompare;
          return _conversationTitle(a).compareTo(_conversationTitle(b));
        });
      final selected = _selectConversation(conversations);
      final messages = selected == null
          ? <Map<String, dynamic>>[]
          : _isContactPlaceholder(selected)
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
      if (selected != null && !_isContactPlaceholder(selected)) {
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
      var conversationId = _text(conversation['id']);
      if (_isContactPlaceholder(conversation)) {
        final created = await BackendApiClient.instance
            .createUnifiedChatConversation(
              type: _text(conversation['type'], fallback: 'parent_teacher'),
              teacherId: RoleAccessService.teacherStaffId,
              parentId: _text(conversation['parent_id']),
              title: _conversationTitle(conversation),
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
          final chat = _chatPane(showBackButton: !wide);
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
          title: 'No chat contacts yet',
          subtitle:
              'Parents and school leadership contacts for direct chat appear here.',
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
        final label = _conversationTitle(row);
        final unread = int.tryParse('${row['unread_count'] ?? 0}') ?? 0;
        return ListTile(
          selected: selected,
          leading: CircleAvatar(child: Text(_initials(label))),
          title: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            _text(row['last_message']).isEmpty
                ? _conversationSubtitle(row)
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

  Widget _chatPane({required bool showBackButton}) {
    final conversation = _selectedConversation;
    if (conversation == null) {
      return const Center(child: Text('Select a chat contact.'));
    }
    final label = _conversationTitle(conversation);
    return Column(
      children: [
        ListTile(
          leading: showBackButton
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  tooltip: 'Back to chats',
                  onPressed: () => setState(() => _selectedConversation = null),
                )
              : CircleAvatar(child: Text(_initials(label))),
          title: Text(label),
          subtitle: Text(_conversationSubtitle(conversation)),
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

List<Map<String, dynamic>> _mergeConversationsWithContacts({
  required List<Map<String, dynamic>> parentConversations,
  required List<Map<String, dynamic>> principalConversations,
  required List<UserAccountModel> userContacts,
}) {
  final merged = <String, Map<String, dynamic>>{
    for (final row in [...parentConversations, ...principalConversations])
      _text(row['id']): Map<String, dynamic>.from(row),
  };

  for (final user in userContacts) {
    final role = user.roleName.trim().toLowerCase();
    if (role == 'parent') {
      final parentId = user.id.trim();
      if (parentId.isEmpty) continue;
      final exists = parentConversations.any(
        (row) => _text(row['parent_id']) == parentId,
      );
      if (exists) continue;
      merged['contact-parent-$parentId'] = {
        'id': 'contact-parent-$parentId',
        'type': 'parent_teacher',
        'parent_id': parentId,
        'parent': {
          'id': parentId,
          'name': user.name,
          'username': user.username,
        },
        'last_message': '',
        'last_message_at': null,
        'unread_count': 0,
        'is_contact_placeholder': true,
      };
    }

    if (role == 'principal') {
      final principalId = user.id.trim();
      if (principalId.isEmpty) continue;
      final exists = principalConversations.any(
        (row) => _text(row['created_by']) == principalId,
      );
      if (exists) continue;
      merged['contact-principal-$principalId'] = {
        'id': 'contact-principal-$principalId',
        'type': 'principal_teacher',
        'principal_id': principalId,
        'last_message': '',
        'last_message_at': null,
        'unread_count': 0,
        'is_contact_placeholder': true,
      };
    }
  }

  return merged.values.toList();
}

bool _isContactPlaceholder(Map<String, dynamic> row) =>
    row['is_contact_placeholder'] == true;

String _conversationTitle(Map<String, dynamic> row) {
  final type = _text(row['type']);
  if (type == 'principal_teacher') return 'Principal';
  return _name(_map(row['parent']), fallback: 'Parent');
}

String _conversationSubtitle(Map<String, dynamic> row) {
  final type = _text(row['type']);
  if (type == 'principal_teacher') {
    return _isContactPlaceholder(row)
        ? 'School leadership - tap to start direct chat'
        : 'Direct message with school leadership';
  }
  final student = _name(_map(row['student']), fallback: 'Parent contact');
  return _isContactPlaceholder(row)
      ? 'Parent contact - tap to start direct chat'
      : '$student - Principal can monitor this chat';
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
