import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:schooldesk1/core/navigation/role_nav_indices.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/services/role_access_service.dart';
import 'package:schooldesk1/core/utils/chat_message_merge.dart';
import 'package:schooldesk1/core/utils/extensions.dart';
import 'package:schooldesk1/core/widgets/teacher_flow_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide UserResponse;
import 'package:schooldesk1/core/services/chat_realtime_service.dart';
import 'package:schooldesk1/core/services/demo_local_api_service.dart';
import 'package:schooldesk1/features/communication/data/chat_models.dart';
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

  // A single channel is enough — replaced whenever the active conversation changes.
  RealtimeChannel? _realtimeChannel;
  String _realtimeConversationId = '';
  int _realtimeRequest = 0;

  bool _loading = true;
  bool _sending = false;
  String? _error;
  String _teacherUserId = '';
  List<Map<String, dynamic>> _conversations = const [];
  List<Map<String, dynamic>> _messages = const [];
  // Optimistic messages appended immediately on send; merged on next load.
  final List<Map<String, dynamic>> _pendingMessages = [];
  Map<String, dynamic>? _selectedConversation;
  // Cursor used for incremental message loading (only fetch new messages).
  DateTime? _messagesCursor;

  @override
  void initState() {
    super.initState();
    _load();
    unawaited(_subscribeRealtime());
  }

  @override
  void dispose() {
    _removeRealtimeChannel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Realtime ──────────────────────────────────────────────────────────────

  Future<void> _subscribeRealtime({String conversationId = ''}) async {
    if (DemoLocalApiService.instance.isActive) return;
    if (_realtimeConversationId == conversationId && _realtimeChannel != null) {
      await ChatRealtimeService.instance.refreshAuth();
      return; // Already subscribed to this scope.
    }
    _removeRealtimeChannel();
    _realtimeConversationId = conversationId;
    final request = ++_realtimeRequest;
    final channel = await ChatRealtimeService.instance.subscribe(
      channelName: 'teacher-chat-$conversationId',
      conversationId: conversationId,
      onUpdate: () {
        if (mounted && !_sending) _loadIncremental();
      },
    );
    if (!mounted || request != _realtimeRequest) {
      if (channel != null) {
        await Supabase.instance.client.removeChannel(channel);
      }
      return;
    }
    _realtimeChannel = channel;
  }

  void _removeRealtimeChannel() {
    final ch = _realtimeChannel;
    if (ch != null) {
      Supabase.instance.client.removeChannel(ch);
      _realtimeChannel = null;
    }
  }

  // ── Data loading ──────────────────────────────────────────────────────────

  /// Full load: profile + all conversations + messages for active conversation.
  /// Used on first load, conversation switch, and successful send.
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
      final bootstrap = await Future.wait<Object>([
        api.getProfile(),
        api.getUnifiedChatConversations(
          teacherId: RoleAccessService.teacherStaffId,
        ),
        api.getUnifiedChatContacts(role: 'teacher'),
      ]);
      final profile = bootstrap[0] as UserResponse;
      final allConversations = bootstrap[1] as List<Map<String, dynamic>>;
      final parentConversations = allConversations
          .where((row) => _text(row['type']) == 'parent_teacher')
          .toList();
      final principalConversations = allConversations
          .where((row) => _text(row['type']) == 'principal_teacher')
          .toList();
      final contacts = bootstrap[2] as List<Map<String, dynamic>>;
      final conversations =
          _mergeConversationsWithContacts(
            parentConversations: parentConversations,
            principalConversations: principalConversations,
            contacts: contacts,
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
      final selected = _selectRetainedConversation(
        _selectedConversation,
        conversations,
      );
      List<Map<String, dynamic>> messages;
      DateTime? cursor;
      if (selected != null && !_isContactPlaceholder(selected)) {
        messages = mergeChatMessagesByIdentity(
          const [],
          await api.getUnifiedChatMessages(
            conversationId: _text(selected['id']),
          ),
        );
        cursor = messages.isNotEmpty
            ? _date(messages.last['sent_at'] ?? messages.last['created_at'])
            : null;
      } else {
        messages = [];
        cursor = null;
      }
      if (!mounted) return;
      final newConversationId = _text(selected?['id']);
      setState(() {
        _teacherUserId = profile.id;
        _conversations = conversations;
        _selectedConversation = selected;
        _messages = messages;
        _pendingMessages.clear();
        _messagesCursor = cursor;
        _loading = false;
      });
      _scrollToBottom();
      unawaited(_subscribeRealtime(conversationId: newConversationId));
      if (selected != null && !_isContactPlaceholder(selected)) {
        unawaited(api.markUnifiedChatConversationRead(newConversationId));
      }
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (!background) _error = error.toString();
      });
    }
  }

  /// Incremental load: fetch only messages newer than the current cursor.
  /// Called by the Realtime callback to avoid resetting the full list.
  Future<void> _loadIncremental() async {
    final selected = _selectedConversation;
    if (selected == null || _isContactPlaceholder(selected)) {
      // No active conversation — still need to refresh conversation list.
      await _load(background: true);
      return;
    }
    try {
      final api = BackendApiClient.instance;
      final convId = _text(selected['id']);
      // Refresh the canonical conversation list once, contacts once, and only
      // the active conversation's new messages.
      final refreshed = await Future.wait<Object>([
        api.getUnifiedChatConversations(
          teacherId: RoleAccessService.teacherStaffId,
        ),
        api.getUnifiedChatContacts(role: 'teacher'),
        api.getUnifiedChatMessages(
          conversationId: convId,
          sentAfter: _messagesCursor,
        ),
      ]);
      final allConversations = refreshed[0] as List<Map<String, dynamic>>;
      final parentConversations = allConversations
          .where((row) => _text(row['type']) == 'parent_teacher')
          .toList();
      final principalConversations = allConversations
          .where((row) => _text(row['type']) == 'principal_teacher')
          .toList();
      final contacts = refreshed[1] as List<Map<String, dynamic>>;
      final conversations =
          _mergeConversationsWithContacts(
            parentConversations: parentConversations,
            principalConversations: principalConversations,
            contacts: contacts,
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
      final newMessages = refreshed[2] as List<Map<String, dynamic>>;
      if (!mounted) return;
      setState(() {
        _conversations = conversations;
        _selectedConversation = _selectRetainedConversation(
          _selectedConversation,
          conversations,
        );
        if (newMessages.isNotEmpty) {
          // Deduplicate pending messages that are now confirmed.
          final confirmedBodies = newMessages
              .map((m) => _text(m['body'] ?? m['message']))
              .toSet();
          _pendingMessages.removeWhere(
            (p) =>
                p['_pending'] == true &&
                confirmedBodies.contains(_text(p['body'] ?? p['message'])),
          );
          _messages = mergeChatMessagesByIdentity(_messages, newMessages);
          _messagesCursor =
              _date(
                newMessages.last['sent_at'] ?? newMessages.last['created_at'],
              ) ??
              _messagesCursor;
        }
      });
      if (newMessages.isNotEmpty) {
        _scrollToBottom();
        unawaited(api.markUnifiedChatConversationRead(convId));
      }
    } on Object catch (_) {
      // Incremental failures are silent — the next Realtime event retries.
    }
  }

  Map<String, dynamic>? _selectRetainedConversation(
    Map<String, dynamic>? selected,
    List<Map<String, dynamic>> conversations,
  ) {
    if (conversations.isEmpty) return null;
    final selectedId = _text(selected?['id']);
    if (selectedId.isEmpty) return null;
    for (final row in conversations) {
      if (_text(row['id']) == selectedId) return row;
    }
    return null;
  }

  void _clearMessages() {
    _messages = const [];
    _pendingMessages.clear();
    _messagesCursor = null;
  }

  // ── Send with optimistic UI ────────────────────────────────────────────────

  Future<void> _send() async {
    final conversation = _selectedConversation;
    final body = _messageController.text.trim();
    if (conversation == null || body.isEmpty || _sending) return;

    // Build an optimistic message shown immediately while the network call runs.
    final optimistic = <String, dynamic>{
      'id': 'pending-${DateTime.now().millisecondsSinceEpoch}',
      'body': body,
      'message': body,
      'sender_user_id': _teacherUserId,
      'sender_id': _teacherUserId,
      'sent_at': DateTime.now().toUtc().toIso8601String(),
      'is_read': false,
      '_pending': true,
    };

    setState(() {
      _sending = true;
      _pendingMessages.add(optimistic);
    });
    _messageController.clear();
    _scrollToBottom();

    try {
      var conversationId = _text(conversation['id']);
      if (_isContactPlaceholder(conversation)) {
        final created = await BackendApiClient.instance
            .createUnifiedChatConversation(
              // Keep the parent-teacher context explicit for contact rows.
              // The fallback is intentionally type: 'parent_teacher'.
              // Principal contacts retain type: 'principal_teacher'.
              type: _text(conversation['type'], fallback: 'parent_teacher'),
              teacherId: RoleAccessService.teacherStaffId,
              parentId: _text(conversation['parent_id']),
              studentId: _text(conversation['student_id']),
              leaderId: _text(conversation['leader_id']),
              title: _conversationTitle(conversation),
            );
        conversationId = _text(created['id']);
      }
      final sent = await BackendApiClient.instance.sendUnifiedChatMessage(
        conversationId: conversationId,
        body: body,
      );
      if (sent['queued'] == true) {
        if (mounted) {
          setState(() {
            optimistic['_offlineQueued'] = true;
          });
        }
        return;
      }
      // Full reload to sync confirmed message, updated conversation list, etc.
      await _load(background: true);
    } on Object catch (error) {
      if (!mounted) return;
      // Remove the optimistic message on failure.
      setState(() {
        _pendingMessages.removeWhere((m) => m == optimistic);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send message: $error'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return TeacherFlowScaffold(
      title: 'Communication',
      subtitle: 'Parent and principal chats in one place',
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
          leading: CircleAvatar(
            backgroundColor: _text(row['type']) == 'principal_teacher'
                ? const Color(0xFFE0E7FF)
                : const Color(0xFFDBEAFE),
            foregroundColor: _text(row['type']) == 'principal_teacher'
                ? const Color(0xFF4F46E5)
                : const Color(0xFF2563EB),
            child: Text(
              _initials(label),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
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
            setState(() {
              _selectedConversation = row;
              _clearMessages();
            });
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
    // Merge confirmed + pending messages for display.
    final displayed = [..._messages, ..._pendingMessages];
    return Column(
      children: [
        ListTile(
          leading: showBackButton
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  tooltip: 'Back to chats',
                  onPressed: () => setState(() {
                    _selectedConversation = null;
                    _clearMessages();
                    unawaited(_subscribeRealtime());
                  }),
                )
              : CircleAvatar(child: Text(_initials(label))),
          title: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            _conversationSubtitle(conversation),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Expanded(
          child: ChatWallpaperBackground(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(vertical: 12),
              itemCount: displayed.length,
              itemBuilder: (context, index) {
                final message = displayed[index];
                final mine =
                    _text(message['sender_user_id'] ?? message['sender_id']) ==
                    _teacherUserId;
                final isPending = message['_pending'] == true;
                final senderName = _text(
                  message['sender_name'],
                  fallback: mine ? 'You' : label,
                );
                final senderRole = _text(
                  message['sender_role'],
                  fallback: mine
                      ? 'Teacher'
                      : _text(conversation['type']) == 'principal_teacher'
                      ? 'School leadership'
                      : 'Parent',
                );
                return Opacity(
                  opacity: isPending ? 0.6 : 1.0,
                  child: ChatBubbleWidget(
                    messageText: _text(message['body'] ?? message['message']),
                    time: isPending
                        ? '...'
                        : _time(
                            _date(message['sent_at'] ?? message['created_at']),
                          ),
                    isMe: mine,
                    isRead: message['is_read'] == true,
                    senderLabel: senderName,
                    senderRoleLabel: senderRole,
                  ),
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
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }
}

List<Map<String, dynamic>> _mergeConversationsWithContacts({
  required List<Map<String, dynamic>> parentConversations,
  required List<Map<String, dynamic>> principalConversations,
  required List<Map<String, dynamic>> contacts,
}) {
  final merged = <String, Map<String, dynamic>>{
    for (final row in [...parentConversations, ...principalConversations])
      _text(row['id']): Map<String, dynamic>.from(row),
  };
  // Enrich parent conversation rows with contact data (parent name, student)
  for (final entry in merged.entries.toList()) {
    final row = entry.value;
    final type = _text(row['type']);
    if (type == 'parent_teacher') {
      final parentId = _text(row['parent_id']);
      final studentId = _text(row['student_id']);
      if (parentId.isNotEmpty) {
        final match = contacts.firstWhere(
          (c) =>
              _text(c['id']) == parentId &&
              (studentId.isEmpty || _text(c['student_id']) == studentId),
          orElse: () => <String, dynamic>{},
        );
        if (match.isNotEmpty) {
          row['parent'] = {
            'id': _text(match['id']),
            'name': _text(match['name'], fallback: 'Parent'),
          };
          row['student'] = {
            'id': _text(match['student_id']),
            'name': _text(match['student_name'], fallback: 'Student'),
          };
          row['section_id'] = _text(match['section_id']);
          row['class_label'] = _text(match['class_label']);
          row['contact_role'] = _text(match['contact_role']);
        }
      }
    }
  }

  for (final contact in contacts) {
    final role = _text(contact['role']).toLowerCase();
    if (role == 'parent') {
      final parentId = _text(contact['id']);
      final studentId = _text(contact['student_id']);
      if (parentId.isEmpty) continue;
      final exists = parentConversations.any(
        (row) =>
            _text(row['parent_id']) == parentId &&
            _text(row['student_id']) == studentId,
      );
      if (exists) continue;
      merged['contact-parent-$parentId-$studentId'] = {
        'id': 'contact-parent-$parentId-$studentId',
        'type': 'parent_teacher',
        'parent_id': parentId,
        'student_id': studentId,
        'section_id': contact['section_id'] ?? '',
        'class_label': contact['class_label'] ?? '',
        'parent': {
          'id': parentId,
          'name': _text(contact['name'], fallback: 'Parent'),
        },
        'student': {
          'id': studentId,
          'name': _text(contact['student_name'], fallback: 'Student'),
        },
        'last_message': '',
        'last_message_at': null,
        'unread_count': 0,
        'is_contact_placeholder': true,
      };
    }

    if (role == 'principal' || role == 'coordinator') {
      final leaderId = _text(contact['id']);
      if (leaderId.isEmpty) continue;
      final exists = principalConversations.any(
        (row) => _text(row['leader_id']) == leaderId,
      );
      if (exists) continue;
      final leaderLabel = role == 'coordinator' ? 'Coordinator' : 'Principal';
      merged['contact-leader-$leaderId'] = {
        'id': 'contact-leader-$leaderId',
        'type': 'principal_teacher',
        'leader_id': leaderId,
        'leader_role': role,
        'leader_name': _text(contact['name'], fallback: leaderLabel),
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
  if (type == 'principal_teacher') {
    return _text(row['leader_name'], fallback: 'School leadership');
  }
  return _name(_map(row['parent']), fallback: 'Parent');
}

String _conversationSubtitle(Map<String, dynamic> row) {
  final type = _text(row['type']);
  if (type == 'principal_teacher') {
    return _isContactPlaceholder(row)
        ? 'School leadership - tap to start direct chat'
        : 'Direct message with school leadership';
  }
  final context = ChatContext.fromMap(row);
  final student = context.studentName.isEmpty
      ? _name(_map(row['student']), fallback: 'Parent contact')
      : context.studentName;
  final classLabel = context.classLabel;
  final classContext = classLabel.isEmpty ? '' : '$classLabel - ';
  final contactRole = _text(row['contact_role']);
  final roleLabel = contactRole == 'class_teacher'
      ? 'Class teacher'
      : contactRole == 'co_teacher'
      ? 'Co-teacher'
      : '';
  if (_isContactPlaceholder(row)) {
    return roleLabel.isNotEmpty
        ? '$classContext$student - $roleLabel - tap to start direct chat'
        : '$classContext$student - Parent contact - tap to start direct chat';
  }
  final base = '$classContext$student - Principal can monitor this chat';
  return roleLabel.isNotEmpty ? '$base — $roleLabel' : base;
}

Map<String, dynamic> _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

String _text(Object? value, {String fallback = ''}) {
  final text = '${value ?? ''}'.trim();
  return text.isEmpty ? fallback : text;
}

String _name(Map<String, dynamic> row, {String fallback = ''}) {
  final full = _text(row['name'] ?? row['full_name']);
  if (full.isNotEmpty) {
    final lower = full.toLowerCase();
    if (lower.contains('principle')) return 'Principal';
    return full;
  }
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
