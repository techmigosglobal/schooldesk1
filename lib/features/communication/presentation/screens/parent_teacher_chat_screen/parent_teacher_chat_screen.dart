import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:schooldesk1/core/navigation/role_nav_indices.dart';
import 'package:schooldesk1/core/utils/chat_message_merge.dart';
import 'package:schooldesk1/core/utils/extensions.dart';
import 'package:schooldesk1/core/widgets/erp_module_scaffold.dart';
import 'package:schooldesk1/core/widgets/parent_navigation.dart';
import 'package:schooldesk1/core/widgets/parent_child_selector.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide UserResponse;
import 'package:schooldesk1/core/services/chat_realtime_service.dart';
import 'package:schooldesk1/core/services/parent_child_selection_service.dart';
import 'package:schooldesk1/core/services/chat_unread_service.dart';
import 'package:schooldesk1/features/communication/data/chat_models.dart';
import 'package:schooldesk1/features/communication/presentation/widgets/chat_shared_widgets.dart';
import 'package:schooldesk1/core/utils/result.dart';
import 'package:schooldesk1/core/repositories/repository_state.dart';
import 'package:schooldesk1/core/widgets/repository_state_view.dart';
import 'package:schooldesk1/roles/parent/data/api_parent_communication_repository.dart';
import 'package:schooldesk1/roles/parent/domain/parent_communication_repository.dart';

class ParentTeacherChatScreen extends StatefulWidget {
  final ParentCommunicationRepository? repository;

  const ParentTeacherChatScreen({super.key, this.repository});

  @override
  State<ParentTeacherChatScreen> createState() =>
      _ParentTeacherChatScreenState();
}

class _ParentTeacherChatScreenState extends State<ParentTeacherChatScreen> {
  ParentCommunicationRepository get _repository =>
      widget.repository ?? ApiParentCommunicationRepository.legacyDefault;

  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  RealtimeChannel? _realtimeChannel;
  String _realtimeConversationId = '';
  int _realtimeRequest = 0;
  bool _incrementalLoading = false;
  bool _incrementalReloadPending = false;

  RepositoryState<Object> _state = const RepositoryState.loading();
  bool _sending = false;
  String _parentUserId = '';
  String _selectedStudentId = '';
  _TeacherThread? _selectedThread;
  List<Map<String, dynamic>> _children = const [];
  List<_TeacherThread> _threads = const [];
  List<Map<String, dynamic>> _messages = const [];
  final List<Map<String, dynamic>> _pendingMessages = [];
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
    if (_realtimeConversationId == conversationId && _realtimeChannel != null) {
      await ChatRealtimeService.instance.refreshAuth();
      return;
    }
    _removeRealtimeChannel();
    _realtimeConversationId = conversationId;
    final request = ++_realtimeRequest;
    final channel = await ChatRealtimeService.instance.subscribe(
      channelName: 'parent-chat-$conversationId',
      conversationId: conversationId,
      onUpdate: () {
        _requestIncrementalLoad();
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

  /// Realtime can emit a conversation update and a message update for one
  /// send. Serialize the follow-up reads so both events share one cursor
  /// instead of racing and replacing each other's message list.
  void _requestIncrementalLoad() {
    if (!mounted || _sending) return;
    if (_incrementalLoading) {
      _incrementalReloadPending = true;
      return;
    }
    _incrementalLoading = true;
    unawaited(() async {
      try {
        await _loadIncremental();
      } finally {
        _incrementalLoading = false;
        final retry = _incrementalReloadPending;
        _incrementalReloadPending = false;
        if (retry && mounted && !_sending) _requestIncrementalLoad();
      }
    }());
  }

  // ── Data loading ──────────────────────────────────────────────────────────

  Future<void> _load({bool background = false}) async {
    if (!background) {
      final previous = _state.data;
      setState(() {
        _state = RepositoryState.loading(
          data: previous,
          source: previous == null
              ? RepositorySource.empty
              : RepositorySource.cache,
          isStale: previous != null,
          isRefreshing: previous != null,
        );
      });
    }
    try {
      final profileResult = await _repository.loadProfile();
      final childrenResult = await _repository.loadChildren();
      _throwIfFailed(profileResult, 'Unable to load profile');
      _throwIfFailed(childrenResult, 'Unable to load linked students');
      final profile = profileResult.dataOrNull!;
      final children = childrenResult.dataOrNull!;
      final savedChildIndex = await ParentChildSelectionService.indexFor(
        children,
        fallback: 0,
      );
      final selectedStudent =
          _selectedStudentId.isNotEmpty &&
              children.any((child) => _text(child['id']) == _selectedStudentId)
          ? _selectedStudentId
          : children.isEmpty
          ? ''
          : _text(children[savedChildIndex]['id']);
      final conversationsResult = await _repository.loadConversations(
        studentId: selectedStudent,
      );
      final contactsResult = await _repository.loadContacts(
        studentId: selectedStudent,
      );
      _throwIfFailed(conversationsResult, 'Unable to load conversations');
      _throwIfFailed(contactsResult, 'Unable to load contacts');
      final allConversations = conversationsResult.dataOrNull!;
      final conversations = allConversations
          .where((row) => _text(row['type']) == 'parent_teacher')
          .toList();
      final principalConversations = allConversations
          .where((row) => _text(row['type']) == 'principal_parent')
          .toList();
      final contacts = contactsResult.dataOrNull!;
      final teacherRows = contacts
          .where((c) => _text(c['role']) == 'teacher')
          .map((c) {
            final teacherId = _text(c['id']);
            final studentId = _text(c['student_id'], fallback: selectedStudent);
            return _TeacherThread(
              threadKey: _teacherThreadKey(teacherId, studentId),
              teacherId: teacherId,
              teacherName: _text(c['name']),
              subtitle: _contactSubtitle(c),
              studentId: studentId,
              studentName: _text(c['student_name']),
            );
          })
          .toList();
      final principalContacts = contacts
          .where(
            (c) =>
                _text(c['role']) == 'principal' ||
                _text(c['role']) == 'coordinator',
          )
          .map((c) => Map<String, dynamic>.from(c))
          .toList();
      final threads = _mergeThreads(
        parentUserId: profile.id,
        studentId: selectedStudent,
        children: children,
        teacherRows: teacherRows,
        conversations: conversations,
        principalConversations: principalConversations,
        principalContacts: principalContacts,
      );
      final selected = _selectRetainedThread(_selectedThread, threads);
      List<Map<String, dynamic>> messages;
      DateTime? cursor;
      if (selected?.conversationId.isNotEmpty == true) {
        final messagesResult = await _repository.loadMessages(
          conversationId: selected!.conversationId,
        );
        _throwIfFailed(messagesResult, 'Unable to load messages');
        messages = mergeChatMessagesByIdentity(
          const [],
          messagesResult.dataOrNull!,
        );
        cursor = messages.isNotEmpty
            ? _date(messages.last['sent_at'] ?? messages.last['created_at'])
            : null;
      } else {
        messages = [];
        cursor = null;
      }
      if (!mounted) return;
      final newConversationId = selected?.conversationId ?? '';
      setState(() {
        _parentUserId = profile.id;
        _children = children;
        _selectedStudentId = selectedStudent;
        _threads = threads;
        _selectedThread = selected;
        _messages = messages;
        _pendingMessages.clear();
        _messagesCursor = cursor;
        _state = const RepositoryState(
          data: Object(),
          source: RepositorySource.remote,
        );
      });
      _scrollToBottom();
      unawaited(_subscribeRealtime(conversationId: newConversationId));
      if (newConversationId.isNotEmpty) {
        unawaited(_markConversationRead(newConversationId));
      }
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        if (!background) _state = RepositoryState.error(error: error);
      });
    }
  }

  Future<void> _loadIncremental() async {
    final thread = _selectedThread;
    if (thread == null || thread.conversationId.isEmpty) {
      await _load(background: true);
      return;
    }
    try {
      final convId = thread.conversationId;
      final selectedStudent = _selectedStudentId;
      final conversationsResult = await _repository.loadConversations(
        studentId: selectedStudent,
      );
      final contactsResult = await _repository.loadContacts(
        studentId: selectedStudent,
      );
      final messagesResult = await _repository.loadMessages(
        conversationId: convId,
        sentAfter: _messagesCursor,
      );
      _throwIfFailed(conversationsResult, 'Unable to refresh conversations');
      _throwIfFailed(contactsResult, 'Unable to refresh contacts');
      _throwIfFailed(messagesResult, 'Unable to refresh messages');
      final allConversations = conversationsResult.dataOrNull!;
      final conversations = allConversations
          .where((row) => _text(row['type']) == 'parent_teacher')
          .toList();
      final principalConversations = allConversations
          .where((row) => _text(row['type']) == 'principal_parent')
          .toList();
      final contacts = contactsResult.dataOrNull!;
      final teacherRows = contacts
          .where((c) => _text(c['role']) == 'teacher')
          .map((c) {
            final teacherId = _text(c['id']);
            final studentId = _text(c['student_id'], fallback: selectedStudent);
            return _TeacherThread(
              threadKey: _teacherThreadKey(teacherId, studentId),
              teacherId: teacherId,
              teacherName: _text(c['name']),
              subtitle: _contactSubtitle(c),
              studentId: studentId,
              studentName: _text(c['student_name']),
            );
          })
          .toList();
      final principalContacts = contacts
          .where(
            (c) =>
                _text(c['role']) == 'principal' ||
                _text(c['role']) == 'coordinator',
          )
          .map((c) => Map<String, dynamic>.from(c))
          .toList();
      final threads = _mergeThreads(
        parentUserId: _parentUserId,
        studentId: selectedStudent,
        children: _children,
        teacherRows: teacherRows,
        conversations: conversations,
        principalConversations: principalConversations,
        principalContacts: principalContacts,
      );
      final newMessages = messagesResult.dataOrNull!;
      if (!mounted) return;
      setState(() {
        _threads = threads;
        _selectedThread = _selectRetainedThread(_selectedThread, threads);
        if (newMessages.isNotEmpty) {
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
        unawaited(_markConversationRead(convId));
      }
    } on Object catch (_) {
      // Silent — next Realtime event retries.
    }
  }

  List<_TeacherThread> _mergeThreads({
    required String parentUserId,
    required String studentId,
    required List<Map<String, dynamic>> children,
    required List<_TeacherThread> teacherRows,
    required List<Map<String, dynamic>> conversations,
    required List<Map<String, dynamic>> principalConversations,
    required List<Map<String, dynamic>> principalContacts,
  }) {
    final byTeacher = <String, _TeacherThread>{
      for (final row in teacherRows) row.threadKey: row,
    };
    for (final row in conversations) {
      final teacherId = _text(row['teacher_id']);
      final rowStudentId = _text(row['student_id'], fallback: studentId);
      if (teacherId.isEmpty) continue;
      final teacher = _map(row['teacher']);
      final student = _map(row['student']);
      final threadKey = _teacherThreadKey(teacherId, rowStudentId);
      final existing = byTeacher[threadKey];
      byTeacher[threadKey] =
          (existing ??
                  _TeacherThread(
                    threadKey: threadKey,
                    teacherId: teacherId,
                    teacherName: _name(teacher, fallback: 'Teacher'),
                    subtitle: 'Class communication',
                    studentId: rowStudentId,
                    studentName: _name(student, fallback: 'Student'),
                  ))
              .copyWith(
                conversationId: _text(row['id']),
                lastMessage: _text(row['last_message']),
                lastMessageAt: _date(row['last_message_at']),
                unreadCount: int.tryParse('${row['unread_count'] ?? 0}') ?? 0,
              );
    }
    for (final row in principalConversations) {
      final id = _text(row['id']);
      if (id.isEmpty) continue;
      byTeacher['principal:$id'] = _TeacherThread(
        threadKey: 'principal:$id',
        teacherId: 'principal:$id',
        teacherName: _name(_map(row['leader']), fallback: 'School leadership'),
        subtitle: _text(row['class_label'], fallback: 'School leadership'),
        studentId: _text(row['student_id'], fallback: studentId),
        studentName: _childName(
          children.firstWhere(
            (child) => _text(child['id']) == _text(row['student_id']),
            orElse: () => const <String, dynamic>{},
          ),
        ),
        conversationType: 'principal_parent',
        leaderId: _text(row['leader_id']),
        conversationId: id,
        lastMessage: _text(row['last_message']),
        lastMessageAt: _date(row['last_message_at']),
        unreadCount: int.tryParse('${row['unread_count'] ?? 0}') ?? 0,
      );
    }
    for (final user in principalContacts) {
      final leaderId = _text(user['id']);
      if (leaderId.isEmpty) continue;
      final alreadyPresent = principalConversations.any(
        (row) => _text(row['leader_id']) == leaderId,
      );
      if (alreadyPresent) continue;
      final leaderLabel = _text(user['role']).toLowerCase() == 'coordinator'
          ? 'Coordinator'
          : 'Principal';
      byTeacher['leader-contact:$leaderId'] = _TeacherThread(
        threadKey: 'leader-contact:$leaderId',
        teacherId: '',
        teacherName: _text(user['name'], fallback: leaderLabel),
        subtitle:
            '${_text(user['class_label'], fallback: 'School leadership')} - tap to start direct chat',
        studentId: _text(user['student_id'], fallback: studentId),
        studentName: _text(user['student_name']),
        conversationType: 'principal_parent',
        leaderId: leaderId,
      );
    }
    final threads = byTeacher.values.toList()
      ..sort((a, b) {
        if (a.conversationId.isEmpty != b.conversationId.isEmpty) {
          return a.conversationId.isEmpty ? 1 : -1;
        }
        final at = a.lastMessageAt?.millisecondsSinceEpoch ?? 0;
        final bt = b.lastMessageAt?.millisecondsSinceEpoch ?? 0;
        if (at != bt) return bt.compareTo(at);
        return a.teacherName.compareTo(b.teacherName);
      });
    return threads;
  }

  _TeacherThread? _selectRetainedThread(
    _TeacherThread? selected,
    List<_TeacherThread> threads,
  ) {
    if (threads.isEmpty) return null;
    final selectedId = selected?.threadKey ?? '';
    if (selectedId.isNotEmpty) {
      for (final thread in threads) {
        if (thread.threadKey == selectedId) return thread;
      }
    }

    // Leadership contact rows use a local placeholder key until the first
    // message creates a server conversation with a different ID.
    if (selected?.conversationType == 'principal_parent' &&
        selected?.leaderId.isNotEmpty == true) {
      for (final thread in threads) {
        if (thread.conversationType == 'principal_parent' &&
            thread.leaderId == selected!.leaderId) {
          return thread;
        }
      }
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
    final thread = _selectedThread;
    final body = _messageController.text.trim();
    if (thread == null || body.isEmpty || _sending) return;

    final optimistic = <String, dynamic>{
      'id': 'pending-${DateTime.now().millisecondsSinceEpoch}',
      'body': body,
      'message': body,
      'sender_user_id': _parentUserId,
      'sender_id': _parentUserId,
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
      var conversationId = thread.conversationId;
      if (conversationId.isEmpty) {
        final createdResult = await _repository.createConversation(
          type: thread.conversationType,
          teacherId: thread.teacherId,
          parentId: _parentUserId,
          studentId: thread.studentId,
          leaderId: thread.leaderId,
          title: thread.teacherName,
        );
        _throwIfFailed(createdResult, 'Unable to create conversation');
        conversationId = _text(createdResult.dataOrNull!['id']);
      }
      final sentResult = await _repository.sendMessage(
        conversationId: conversationId,
        body: body,
      );
      _throwIfFailed(sentResult, 'Unable to send message');
      final sent = sentResult.dataOrNull!;
      if (sent['queued'] == true) {
        if (mounted) {
          setState(() {
            optimistic['_offlineQueued'] = true;
          });
        }
        return;
      }
      _acceptSentMessage(
        sent: sent,
        optimistic: optimistic,
        conversationId: conversationId,
        body: body,
      );
    } on Object catch (error) {
      if (!mounted) return;
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

  void _acceptSentMessage({
    required Map<String, dynamic> sent,
    required Map<String, dynamic> optimistic,
    required String conversationId,
    required String body,
  }) {
    if (!mounted) return;
    final canonical = <String, dynamic>{...optimistic, ...sent}
      ..remove('_pending')
      ..remove('_offlineQueued')
      ..remove('queued');
    final sentAt = _date(canonical['sent_at'] ?? canonical['created_at']);
    final selected = _selectedThread;
    setState(() {
      _pendingMessages.removeWhere((message) => message == optimistic);
      _messages = mergeChatMessagesByIdentity(_messages, [canonical]);
      _messagesCursor = sentAt ?? _messagesCursor;
      if (selected != null) {
        final updated = selected.copyWith(
          conversationId: conversationId,
          lastMessage: body,
          lastMessageAt: sentAt ?? DateTime.now().toUtc(),
          unreadCount: 0,
        );
        _selectedThread = updated;
        _threads = _threads
            .map(
              (thread) =>
                  thread.threadKey == selected.threadKey ? updated : thread,
            )
            .toList();
      }
    });
    _scrollToBottom();
    unawaited(_loadIncremental());
  }

  Future<void> _markConversationRead(String conversationId) async {
    await _repository.markConversationRead(conversationId);
    unawaited(ChatUnreadService.instance.refresh(role: 'parent'));
  }

  void _throwIfFailed<T>(Result<T> result, String fallback) {
    if (result.isFailure) {
      throw StateError(result.failureOrNull?.message ?? fallback);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _selectedThread == null,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || !mounted || _selectedThread == null) return;
        setState(() {
          _selectedThread = null;
          _clearMessages();
        });
        unawaited(_subscribeRealtime());
      },
      child: SchoolDeskModuleScaffold(
        title: 'Communication',
        subtitle: 'Parent-teacher messages for your selected child',
        drawer: ParentDrawer(
          selectedIndex: ParentNav.chat,
          onDestinationSelected: (_) {},
        ),
        onBackRequested: _selectedThread == null
            ? null
            : _backToConversationList,
        body: _body(),
      ),
    );
  }

  void _backToConversationList() {
    setState(() {
      _selectedThread = null;
      _clearMessages();
    });
    unawaited(_subscribeRealtime());
  }

  Widget _body() {
    return SchoolDeskRepositoryStateView<Object>(
      state: _state,
      onRetry: _load,
      data: (_) => Column(
        children: [
          _childSelector(),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 760;
                final list = _conversationList();
                final chat = _chatPane(canSend: true, showBackButton: !wide);
                if (wide) {
                  return Row(
                    children: [
                      SizedBox(width: 330, child: list),
                      VerticalDivider(
                        width: 1,
                        color: context.appTheme.outlineVariant,
                      ),
                      Expanded(child: chat),
                    ],
                  );
                }
                return _selectedThread == null ? list : chat;
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _childSelector() {
    if (_children.length <= 1) return const SizedBox.shrink();
    final selectedIndex = _children.indexWhere(
      (child) => _text(child['id']) == _selectedStudentId,
    );
    return ParentChildSelector(
      children: _children,
      selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      onSelected: (index) {
        setState(() {
          _selectedStudentId = _text(_children[index]['id']);
          _selectedThread = null;
          _clearMessages();
        });
        unawaited(ParentChildSelectionService.saveIndex(_children, index));
        _load();
      },
    );
  }

  Widget _conversationList() {
    if (_threads.isEmpty) {
      return const Center(child: Text('No teachers are linked yet.'));
    }
    return ListView.separated(
      itemCount: _threads.length,
      separatorBuilder: (_, __) =>
          Divider(height: 1, color: context.appTheme.outlineVariant),
      itemBuilder: (context, index) {
        final thread = _threads[index];
        final selected = thread.threadKey == _selectedThread?.threadKey;
        return ListTile(
          selected: selected,
          leading: CircleAvatar(
            backgroundColor: const Color(0xFFDCFCE7),
            foregroundColor: const Color(0xFF16A34A),
            child: Text(
              _initials(thread.teacherName),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          title: Text(
            thread.teacherName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            thread.lastMessage.isEmpty ? thread.subtitle : thread.lastMessage,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                chatPreviewDateTime(thread.lastMessageAt),
                style: const TextStyle(fontSize: 11),
              ),
              if (thread.unreadCount > 0)
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
                    '${thread.unreadCount}',
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
            ],
          ),
          onTap: () {
            setState(() {
              _selectedThread = thread;
              _clearMessages();
            });
            _load(background: true);
          },
        );
      },
    );
  }

  Widget _chatPane({required bool canSend, required bool showBackButton}) {
    final thread = _selectedThread;
    if (thread == null) {
      return const Center(child: Text('Select a teacher to start chatting.'));
    }
    final displayed = [..._messages, ..._pendingMessages];
    return Column(
      children: [
        ListTile(
          leading: showBackButton
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  tooltip: 'Back to chats',
                  onPressed: () => setState(() {
                    _selectedThread = null;
                    _clearMessages();
                    unawaited(_subscribeRealtime());
                  }),
                )
              : CircleAvatar(
                  backgroundColor: const Color(0xFFDCFCE7),
                  foregroundColor: const Color(0xFF16A34A),
                  child: Text(
                    _initials(thread.teacherName),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
          title: Text(
            thread.teacherName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            thread.studentName.isEmpty
                ? thread.subtitle
                : '${thread.studentName} - ${thread.subtitle}',
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
                    _parentUserId;
                final isPending = message['_pending'] == true;
                final senderName = _text(
                  message['sender_name'],
                  fallback: mine ? 'You' : thread.teacherName,
                );
                final senderRole = _text(
                  message['sender_role'],
                  fallback: mine ? 'Parent' : 'Teacher',
                );
                final sentAt = _date(
                  message['sent_at'] ?? message['created_at'],
                );
                final dateLabel = isPending
                    ? null
                    : chatDateDividerLabel(sentAt);
                final previousAt = index == 0
                    ? null
                    : _date(
                        displayed[index - 1]['sent_at'] ??
                            displayed[index - 1]['created_at'],
                      );
                final previousLabel = chatDateDividerLabel(previousAt);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (dateLabel != null && dateLabel != previousLabel)
                      ChatDateSeparator(dateText: dateLabel),
                    Opacity(
                      opacity: isPending ? 0.6 : 1.0,
                      child: ChatBubbleWidget(
                        messageText: _text(
                          message['body'] ?? message['message'],
                        ),
                        time: isPending ? '...' : _time(sentAt),
                        isMe: mine,
                        isRead: message['is_read'] == true,
                        senderLabel: senderName,
                        senderRoleLabel: senderRole,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        ChatInputBar(
          controller: _messageController,
          isSending: _sending,
          onSend: _send,
          placeholder: 'Message ${thread.teacherName}',
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

class _TeacherThread {
  const _TeacherThread({
    required this.threadKey,
    required this.teacherId,
    required this.teacherName,
    required this.subtitle,
    required this.studentId,
    required this.studentName,
    this.conversationType = 'parent_teacher',
    this.leaderId = '',
    this.conversationId = '',
    this.lastMessage = '',
    this.lastMessageAt,
    this.unreadCount = 0,
  });

  final String threadKey;
  final String teacherId;
  final String teacherName;
  final String subtitle;
  final String studentId;
  final String studentName;
  final String conversationType;
  final String leaderId;
  final String conversationId;
  final String lastMessage;
  final DateTime? lastMessageAt;
  final int unreadCount;

  _TeacherThread copyWith({
    String? conversationId,
    String? lastMessage,
    DateTime? lastMessageAt,
    int? unreadCount,
  }) {
    return _TeacherThread(
      threadKey: threadKey,
      teacherId: teacherId,
      teacherName: teacherName,
      subtitle: subtitle,
      studentId: studentId,
      studentName: studentName,
      conversationType: conversationType,
      leaderId: leaderId,
      conversationId: conversationId ?? this.conversationId,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}

String _contactSubtitle(Map<String, dynamic> row) {
  final context = ChatContext.fromMap(row);
  final contactRole = _text(row['contact_role']);
  final role = contactRole == 'co_teacher' ? 'Co-teacher' : 'Teacher';
  final classLabel = context.classLabel;
  return classLabel.isEmpty ? role : '$classLabel - $role';
}

String _teacherThreadKey(String teacherId, String studentId) =>
    '$teacherId::$studentId';

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

String _childName(Map<String, dynamic> row) => _name(row, fallback: 'Child');

String _initials(String value) {
  final words = value.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return 'T';
  return words.take(2).map((w) => w[0].toUpperCase()).join();
}

DateTime? _date(Object? value) => DateTime.tryParse(_text(value));

String _time(DateTime? value) {
  if (value == null) return '';
  return DateFormat('h:mm a').format(value.toLocal());
}
