import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:schooldesk1/core/navigation/role_nav_indices.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/utils/extensions.dart';
import 'package:schooldesk1/core/widgets/dashboard_fab_widget.dart';
import 'package:schooldesk1/core/widgets/erp_module_scaffold.dart';
import 'package:schooldesk1/core/widgets/parent_navigation.dart';
import 'package:schooldesk1/features/communication/presentation/widgets/chat_shared_widgets.dart';

class ParentTeacherChatScreen extends StatefulWidget {
  const ParentTeacherChatScreen({super.key});

  @override
  State<ParentTeacherChatScreen> createState() =>
      _ParentTeacherChatScreenState();
}

class _ParentTeacherChatScreenState extends State<ParentTeacherChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _pollingTimer;

  bool _loading = true;
  bool _sending = false;
  String? _error;
  String _parentUserId = '';
  String _selectedStudentId = '';
  _TeacherThread? _selectedThread;
  List<Map<String, dynamic>> _children = const [];
  List<_TeacherThread> _threads = const [];
  List<Map<String, dynamic>> _messages = const [];

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
      final api = BackendApiClient.instance;
      final profile = await api.getProfile();
      final children = (await api.getMyStudents())
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
      final selectedStudent = _selectedStudentId.isNotEmpty
          ? _selectedStudentId
          : children.isNotEmpty
          ? _text(children.first['id'])
          : '';
      final conversations = await api.getUnifiedChatConversations(
        type: 'parent_teacher',
        studentId: selectedStudent,
      );
      final principalConversations = await api.getUnifiedChatConversations(
        type: 'principal_parent',
      );
      final users = await api.getUsers(page: 1, pageSize: 200);
      final teacherRows = await _loadTeacherRows(children, selectedStudent);
      final threads = _mergeThreads(
        parentUserId: profile.id,
        studentId: selectedStudent,
        children: children,
        teacherRows: teacherRows,
        conversations: conversations,
        principalConversations: principalConversations,
        principalContacts: users.data,
      );
      final selected = _selectThread(threads);
      final messages = selected?.conversationId.isNotEmpty == true
          ? await api.getUnifiedChatMessages(
              conversationId: selected!.conversationId,
            )
          : <Map<String, dynamic>>[];
      if (!mounted) return;
      setState(() {
        _parentUserId = profile.id;
        _children = children;
        _selectedStudentId = selectedStudent;
        _threads = threads;
        _selectedThread = selected;
        _messages = messages;
        _loading = false;
      });
      _scrollToBottom();
      if (selected?.conversationId.isNotEmpty == true) {
        unawaited(
          api.markUnifiedChatConversationRead(selected!.conversationId),
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (!background) _error = error.toString();
      });
    }
  }

  Future<List<_TeacherThread>> _loadTeacherRows(
    List<Map<String, dynamic>> children,
    String selectedStudentId,
  ) async {
    final api = BackendApiClient.instance;
    final rows = <_TeacherThread>[];
    for (final child in children) {
      if (selectedStudentId.isNotEmpty &&
          _text(child['id']) != selectedStudentId) {
        continue;
      }
      final sectionId = _text(child['current_section_id']);
      if (sectionId.isEmpty) continue;
      try {
        final slots = await api.getTimetableSlots(sectionId: sectionId);
        for (final slot in slots) {
          final teacherId = _text(slot['staff_id']);
          if (teacherId.isEmpty) continue;
          final staff = _map(slot['staff']);
          final subject = _map(slot['subject']);
          final name = _name(
            staff,
            fallback: _text(slot['teacher_name'], fallback: 'Teacher'),
          );
          rows.add(
            _TeacherThread(
              threadKey: _teacherThreadKey(teacherId, _text(child['id'])),
              teacherId: teacherId,
              teacherName: name,
              subtitle: [
                _text(subject['subject_name'] ?? subject['name']),
                _childClassLabel(child),
              ].where((part) => part.isNotEmpty).join(' - '),
              studentId: _text(child['id']),
              studentName: _childName(child),
            ),
          );
        }
      } catch (_) {
        // A timetable gap should not block existing chat conversations.
      }
    }
    return rows;
  }

  List<_TeacherThread> _mergeThreads({
    required String parentUserId,
    required String studentId,
    required List<Map<String, dynamic>> children,
    required List<_TeacherThread> teacherRows,
    required List<Map<String, dynamic>> conversations,
    required List<Map<String, dynamic>> principalConversations,
    required List<UserAccountModel> principalContacts,
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
        teacherName: 'Principal',
        subtitle: 'School leadership',
        studentId: _text(row['student_id'], fallback: studentId),
        studentName: _childName(
          children.firstWhere(
            (child) => _text(child['id']) == _text(row['student_id']),
            orElse: () => const <String, dynamic>{},
          ),
        ),
        conversationType: 'principal_parent',
        conversationId: id,
        lastMessage: _text(row['last_message']),
        lastMessageAt: _date(row['last_message_at']),
        unreadCount: int.tryParse('${row['unread_count'] ?? 0}') ?? 0,
      );
    }
    for (final user in principalContacts) {
      if (user.roleName.trim().toLowerCase() != 'principal') continue;
      final principalId = user.id.trim();
      if (principalId.isEmpty) continue;
      final alreadyPresent = principalConversations.any(
        (row) => _text(row['created_by']) == principalId,
      );
      if (alreadyPresent) continue;
      byTeacher['principal-contact:$principalId'] = _TeacherThread(
        threadKey: 'principal-contact:$principalId',
        teacherId: '',
        teacherName: 'Principal',
        subtitle: 'School leadership - tap to start direct chat',
        studentId: '',
        studentName: '',
        conversationType: 'principal_parent',
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

  _TeacherThread? _selectThread(List<_TeacherThread> threads) {
    if (threads.isEmpty) return null;
    final selectedId = _selectedThread?.threadKey ?? '';
    return threads.firstWhere(
      (thread) => thread.threadKey == selectedId,
      orElse: () => threads.first,
    );
  }

  Future<void> _send() async {
    final thread = _selectedThread;
    final body = _messageController.text.trim();
    if (thread == null || body.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      var conversationId = thread.conversationId;
      if (conversationId.isEmpty) {
        final created = await BackendApiClient.instance
            .createUnifiedChatConversation(
              type: thread.conversationType,
              teacherId: thread.teacherId,
              parentId: _parentUserId,
              studentId: thread.conversationType == 'parent_teacher'
                  ? thread.studentId
                  : '',
              title: thread.teacherName,
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
    return SchoolDeskModuleScaffold(
      title: 'Teacher Chat',
      subtitle: 'Parent-teacher messages for your selected child',
      drawer: ParentDrawer(
        selectedIndex: ParentNav.chat,
        onDestinationSelected: (_) {},
      ),
      floatingActionButton: const DashboardFabWidget(
        role: DashboardRole.parent,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!));
    return Column(
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
    );
  }

  Widget _childSelector() {
    if (_children.length <= 1) return const SizedBox.shrink();
    return SizedBox(
      height: 54,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          final child = _children[index];
          final id = _text(child['id']);
          return ChoiceChip(
            label: Text(_childName(child)),
            selected: id == _selectedStudentId,
            onSelected: (_) {
              setState(() {
                _selectedStudentId = id;
                _selectedThread = null;
              });
              _load();
            },
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemCount: _children.length,
      ),
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
          leading: CircleAvatar(child: Text(_initials(thread.teacherName))),
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
                _time(thread.lastMessageAt),
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
            setState(() => _selectedThread = thread);
            _load(background: true);
          },
        );
      },
    );
  }

  Widget _chatPane({
    required bool canSend,
    required bool showBackButton,
  }) {
    final thread = _selectedThread;
    if (thread == null) {
      return const Center(child: Text('Select a teacher to start chatting.'));
    }
    return Column(
      children: [
        ListTile(
          leading: showBackButton
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  tooltip: 'Back to chats',
                  onPressed: () => setState(() => _selectedThread = null),
                )
              : CircleAvatar(child: Text(_initials(thread.teacherName))),
          title: Text(thread.teacherName),
          subtitle: Text(
            thread.studentName.isEmpty
                ? thread.subtitle
                : '${thread.studentName} - ${thread.subtitle}',
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
                    _parentUserId;
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
          placeholder: 'Message ${thread.teacherName}',
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

class _TeacherThread {
  const _TeacherThread({
    required this.threadKey,
    required this.teacherId,
    required this.teacherName,
    required this.subtitle,
    required this.studentId,
    required this.studentName,
    this.conversationType = 'parent_teacher',
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
      conversationId: conversationId ?? this.conversationId,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
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
  if (full.isNotEmpty) return full;
  final parts = [
    _text(row['first_name']),
    _text(row['last_name']),
  ].where((part) => part.isNotEmpty).join(' ');
  return parts.isEmpty ? fallback : parts;
}

String _childName(Map<String, dynamic> row) => _name(row, fallback: 'Child');

String _childClassLabel(Map<String, dynamic> row) {
  return [
    _text(row['grade_name'] ?? row['class']),
    _text(row['section_name'] ?? row['section']),
  ].where((part) => part.isNotEmpty).join(' ');
}

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
