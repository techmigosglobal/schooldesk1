import 'package:flutter/material.dart';

import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/services/role_access_service.dart';
import 'package:schooldesk1/core/theme/app_theme.dart';
import 'package:schooldesk1/core/widgets/teacher_flow_ui.dart';

class TeacherCommunicationScreen extends StatefulWidget {
  const TeacherCommunicationScreen({super.key});

  @override
  State<TeacherCommunicationScreen> createState() =>
      _TeacherCommunicationScreenState();
}

class _TeacherCommunicationScreenState extends State<TeacherCommunicationScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _messageController = TextEditingController();
  bool _loading = true;
  String? _error;
  String _selectedConversationId = '';
  String _selectedDirectCounterpartId = '';
  String _teacherUserId = '';
  List<Map<String, dynamic>> _conversations = const [];
  List<Map<String, dynamic>> _messages = const [];
  List<Map<String, dynamic>> _directMessages = const [];
  List<_ChatTarget> _chatTargets = const [];
  List<AnnouncementModel> _notices = const [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadCommunication();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadCommunication() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await RoleAccessService.initialize();
      final api = BackendApiClient.instance;
      final profile = await api.getProfile();
      final schoolNotices = await api.getAnnouncements();
      final conversations = await api.getRawList('/message-conversations');
      final messages = await api.getRawList('/messages');
      final directMessages = await api.getCommunications();
      final teachers = await api.getUsers(
        role: 'Teacher',
        status: 'active',
        pageSize: 1000,
      );
      final parents = await api.getUsers(
        role: 'Parent',
        status: 'active',
        pageSize: 1000,
      );
      final classStudents = RoleAccessService.teacherClassId.isEmpty
          ? <StudentModel>[]
          : (await api.getStudents(
              sectionId: RoleAccessService.teacherClassId,
              status: 'active',
              pageSize: 200,
            )).data;
      directMessages.sort(
        (a, b) => _directMessageTime(b).compareTo(_directMessageTime(a)),
      );
      final staffId = RoleAccessService.teacherStaffId;
      final chatTargets = _buildChatTargets(
        teachers: teachers.data,
        parents: parents.data,
        students: classStudents,
        profile: profile,
      );
      final visibleConversations = conversations.where((row) {
        final teacherId = teacherFlowText(row['teacher_id'] ?? row['staff_id']);
        return teacherId.isEmpty || teacherId == staffId;
      }).toList();
      if (!mounted) return;
      setState(() {
        _teacherUserId = profile.id;
        _notices = schoolNotices;
        _conversations = visibleConversations;
        _selectedConversationId = _selectedConversationId.isNotEmpty
            ? _selectedConversationId
            : (visibleConversations.isNotEmpty
                  ? teacherFlowText(visibleConversations.first['id'])
                  : '');
        _selectedDirectCounterpartId = _selectedDirectCounterpartId.isNotEmpty
            ? _selectedDirectCounterpartId
            : (_directThreads(
                    directMessages,
                    chatTargets: chatTargets,
                  ).isNotEmpty
                  ? _directThreads(
                      directMessages,
                      chatTargets: chatTargets,
                    ).first.counterpartId
                  : '');
        _messages = messages;
        _directMessages = directMessages;
        _chatTargets = chatTargets;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _sendMessage() async {
    final conversationId = _selectedConversationId;
    final text = _messageController.text.trim();
    if (conversationId.isEmpty || text.isEmpty) return;
    await BackendApiClient.instance.createRaw('/messages', {
      'conversation_id': conversationId,
      'sender_id': RoleAccessService.teacherStaffId,
      'sender_role': 'Teacher',
      'message': text,
      'body': text,
    });
    _messageController.clear();
    await _loadCommunication();
  }

  Future<void> _markRead(Map<String, dynamic> message) async {
    final id = teacherFlowText(message['id']);
    if (id.isEmpty) return;
    await BackendApiClient.instance.updateRaw('/messages/$id', {
      'is_read': true,
      'read_at': DateTime.now().toIso8601String(),
    });
    await _loadCommunication();
  }

  @override
  Widget build(BuildContext context) {
    return TeacherFlowScaffold(
      title: 'Communication',
      subtitle: 'Chats, school notices, and protected parent communication',
      selectedIndex: 8,
      loading: _loading,
      error: _error,
      onRefresh: _loadCommunication,
      child: TeacherFlowScrollView(
        children: [
          TeacherCurrentClassCard(
            greeting: 'Communication center',
            classLabel: RoleAccessService.teacherClassName,
            subject: '${_conversations.length} conversations',
            timeLabel: '${_directMessages.length} direct messages',
          ),
          const SizedBox(height: 18),
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Chats'),
              Tab(text: 'Direct'),
              Tab(text: 'Start Chat'),
              Tab(text: 'School Notices'),
            ],
          ),
          SizedBox(
            height: 620,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildChats(),
                _buildPrincipalMessages(),
                _buildStartChat(),
                _buildNotices(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChats() {
    final visibleMessages = _messages
        .where(
          (message) =>
              teacherFlowText(message['conversation_id']) ==
              _selectedConversationId,
        )
        .toList();
    if (_conversations.isEmpty) {
      return ListView(
        padding: const EdgeInsets.only(top: 14, bottom: 24),
        children: [
          TeacherFlowCard(
            icon: Icons.forum_rounded,
            title: 'No conversations',
            subtitle:
                'Teacher, admin, principal, and class-parent chats appear here.',
          ),
        ],
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 680;
        final conversationList = _buildConversationRail();
        final chatPane = _buildThreadPane(
          title: _conversationLabel(_selectedConversation),
          subtitle: 'Visible to Principal monitoring',
          messages: [
            for (final message in visibleMessages)
              _ChatBubble(
                text: teacherFlowText(
                  message['message'] ?? message['body'],
                  fallback: 'Message',
                ),
                mine: _messageIsMine(message),
                label: teacherFlowTitleCase(
                  teacherFlowText(message['sender_role'], fallback: 'Message'),
                ),
                time: _messageDate(message),
                unread: !_messageIsMine(message) && !_messageRead(message),
                onMarkRead: () => _markRead(message),
              ),
          ],
          onSend: _sendMessage,
        );
        return wide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 250, child: conversationList),
                  const SizedBox(width: 14),
                  Expanded(child: chatPane),
                ],
              )
            : ListView(
                padding: const EdgeInsets.only(top: 14, bottom: 24),
                children: [
                  conversationList,
                  const SizedBox(height: 12),
                  chatPane,
                ],
              );
      },
    );
  }

  Widget _buildNotices() {
    return ListView(
      padding: const EdgeInsets.only(top: 14, bottom: 24),
      children: [
        if (_notices.isEmpty)
          const TeacherFlowCard(
            icon: Icons.campaign_rounded,
            title: 'No school notices',
            subtitle:
                'Admin and principal notices visible to teachers appear here.',
          )
        else
          ..._notices.map(
            (notice) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TeacherFlowCard(
                icon: Icons.campaign_rounded,
                title: notice.title,
                subtitle: notice.content,
                status: notice.isUrgent ? 'Urgent' : 'Notice',
                statusColor: notice.isUrgent
                    ? AppTheme.error
                    : teacherFlowAccent,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPrincipalMessages() {
    final threads = _directThreads(_directMessages, chatTargets: _chatTargets);
    final selected = threads.where(
      (thread) => thread.counterpartId == _selectedDirectCounterpartId,
    );
    final thread = selected.isEmpty && threads.isNotEmpty
        ? threads.first
        : selected.isEmpty
        ? null
        : selected.first;
    if (threads.isEmpty || thread == null) {
      return ListView(
        padding: const EdgeInsets.only(top: 14, bottom: 24),
        children: [
          TeacherFlowCard(
            icon: Icons.mark_email_unread_outlined,
            title: 'No direct messages',
            subtitle: 'Principal direct messages from backend appear here.',
          ),
        ],
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 680;
        final rail = ListView(
          padding: const EdgeInsets.only(top: 14, bottom: 24),
          children: [
            for (final row in threads)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _ThreadTile(
                  title: row.label,
                  subtitle: row.lastMessage,
                  selected: row.counterpartId == thread.counterpartId,
                  unread: row.unreadCount,
                  onTap: () => setState(
                    () => _selectedDirectCounterpartId = row.counterpartId,
                  ),
                ),
              ),
          ],
        );
        final pane = _buildThreadPane(
          title: thread.label,
          subtitle: 'Direct school communication',
          messages: [
            for (final message in thread.messages)
              _ChatBubble(
                text: teacherFlowText(
                  message['message_content'] ??
                      message['message'] ??
                      message['body'],
                  fallback: 'Message',
                ),
                mine: !_directMessageIncoming(message),
                label: teacherFlowTitleCase(
                  _directMessageIncoming(message)
                      ? teacherFlowText(
                          message['sender_role'],
                          fallback: 'Principal',
                        )
                      : 'Teacher',
                ),
                time: _directMessageDate(message),
                unread:
                    _directMessageIncoming(message) &&
                    !_directMessageRead(message),
                onMarkRead: () => _markDirectMessageRead(message),
              ),
          ],
          onSend: () => _sendDirectMessage(thread),
        );
        return wide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 250, child: rail),
                  const SizedBox(width: 14),
                  Expanded(child: pane),
                ],
              )
            : ListView(
                padding: const EdgeInsets.only(top: 14, bottom: 24),
                children: [
                  SizedBox(height: 190, child: rail),
                  pane,
                ],
              );
      },
    );
  }

  Future<void> _markDirectMessageRead(Map<String, dynamic> message) async {
    final id = teacherFlowText(message['id'] ?? message['message_id']);
    if (id.isEmpty) return;
    await BackendApiClient.instance.markCommunicationRead(id);
    await _loadCommunication();
  }

  Future<void> _sendDirectMessage(_DirectThread thread) async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    await BackendApiClient.instance.sendCommunication(
      receiverId: thread.counterpartId,
      receiverRole: thread.role,
      messageContent: text,
    );
    _messageController.clear();
    await _loadCommunication();
  }

  Widget _buildStartChat() {
    final teachers = _chatTargets.where((target) => target.role == 'teacher');
    final parents = _chatTargets.where((target) => target.role == 'parent');
    return ListView(
      padding: const EdgeInsets.only(top: 14, bottom: 24),
      children: [
        const TeacherFlowSectionHeader(title: 'Teachers'),
        const SizedBox(height: 10),
        if (teachers.isEmpty)
          const TeacherFlowCard(
            icon: Icons.groups_outlined,
            title: 'No teacher targets',
            subtitle: 'Active teacher accounts will appear here.',
          )
        else
          for (final target in teachers)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _targetCard(target),
            ),
        const SizedBox(height: 12),
        const TeacherFlowSectionHeader(title: 'Class Parents'),
        const SizedBox(height: 10),
        if (parents.isEmpty)
          const TeacherFlowCard(
            icon: Icons.family_restroom_outlined,
            title: 'No class parent accounts',
            subtitle:
                'Parents linked to students in your assigned class appear here.',
          )
        else
          for (final target in parents)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _targetCard(target),
            ),
      ],
    );
  }

  Widget _targetCard(_ChatTarget target) {
    return TeacherFlowCard(
      icon: target.role == 'teacher'
          ? Icons.co_present_rounded
          : Icons.family_restroom_rounded,
      title: target.label,
      subtitle: target.subtitle,
      status: target.role == 'teacher' ? 'Teacher' : 'Parent',
      body: TeacherFlowActionWrap(
        actions: [
          TeacherFlowAction(
            label: 'Open Chat',
            icon: Icons.chat_rounded,
            filled: true,
            onTap: () => _openTargetChat(target),
          ),
        ],
      ),
    );
  }

  Future<void> _openTargetChat(_ChatTarget target) async {
    if (target.role == 'teacher') {
      setState(() => _selectedDirectCounterpartId = target.id);
      _tabController.animateTo(1);
      return;
    }
    final existing = _conversations.where((row) {
      return teacherFlowText(row['parent_id']) == target.id &&
          teacherFlowText(row['student_id']) == target.studentId;
    });
    if (existing.isNotEmpty) {
      setState(
        () => _selectedConversationId = teacherFlowText(existing.first['id']),
      );
      _tabController.animateTo(0);
      return;
    }
    final saved = await BackendApiClient.instance
        .createRaw('/message-conversations', {
          'teacher_id': RoleAccessService.teacherStaffId,
          'parent_id': target.id,
          'student_id': target.studentId,
          'title': 'Class chat - ${target.studentName}',
          'reference_type': 'class_parent',
          'reference_id': target.studentId,
          'last_message': '',
          'last_message_time': DateTime.now().toUtc().toIso8601String(),
        });
    _selectedConversationId = teacherFlowText(saved['id']);
    await _loadCommunication();
    _tabController.animateTo(0);
  }

  bool _directMessageIncoming(Map<String, dynamic> message) {
    final receiverId = teacherFlowText(message['receiver_id']);
    return receiverId == _teacherUserId ||
        receiverId == RoleAccessService.teacherStaffId;
  }

  bool _directMessageRead(Map<String, dynamic> message) {
    final value = message['is_read'];
    if (value is bool) return value;
    if (value is num) return value != 0;
    return teacherFlowText(value).toLowerCase() == 'true';
  }

  DateTime _directMessageTime(Map<String, dynamic> message) {
    return DateTime.tryParse(
          teacherFlowText(message['sent_at'] ?? message['created_at']),
        ) ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _directMessageDate(Map<String, dynamic> message) {
    final sentAt = _directMessageTime(message);
    if (sentAt.millisecondsSinceEpoch == 0) return 'Direct';
    return '${sentAt.day.toString().padLeft(2, '0')}/${sentAt.month.toString().padLeft(2, '0')}';
  }

  String _conversationLabel(Map<String, dynamic> row) {
    return teacherFlowText(
      row['title'] ??
          row['name'] ??
          row['parent_name'] ??
          row['conversation_type'],
      fallback: 'Conversation',
    );
  }

  Map<String, dynamic> get _selectedConversation {
    for (final row in _conversations) {
      if (teacherFlowText(row['id']) == _selectedConversationId) return row;
    }
    return _conversations.isEmpty ? const {} : _conversations.first;
  }

  Widget _buildConversationRail() {
    return ListView(
      padding: const EdgeInsets.only(top: 14, bottom: 24),
      children: [
        for (final conversation in _conversations)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _ThreadTile(
              title: _conversationLabel(conversation),
              subtitle: _conversationSubtitle(conversation),
              selected:
                  teacherFlowText(conversation['id']) ==
                  _selectedConversationId,
              unread: _unreadConversationCount(
                teacherFlowText(conversation['id']),
              ),
              onTap: () => setState(
                () => _selectedConversationId = teacherFlowText(
                  conversation['id'],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildThreadPane({
    required String title,
    required String subtitle,
    required List<Widget> messages,
    required VoidCallback onSend,
  }) {
    return TeacherFlowCard(
      icon: Icons.chat_bubble_outline_rounded,
      title: title.isEmpty ? 'Conversation' : title,
      subtitle: subtitle,
      body: Column(
        children: [
          Container(
            height: 430,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: messages.isEmpty
                ? const Center(
                    child: Text(
                      'No messages yet',
                      style: TextStyle(
                        color: teacherFlowMuted,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  )
                : ListView(
                    reverse: false,
                    children: [
                      for (final message in messages)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: message,
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  minLines: 1,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Message',
                    prefixIcon: Icon(Icons.message_rounded),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filled(
                tooltip: 'Send message',
                onPressed: onSend,
                icon: const Icon(Icons.send_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _conversationSubtitle(Map<String, dynamic> row) {
    final student = teacherFlowText(row['student_name']);
    final parent = teacherFlowText(row['parent_name'] ?? row['parent_id']);
    return [parent, student].where((part) => part.isNotEmpty).join(' · ');
  }

  int _unreadConversationCount(String conversationId) {
    return _messages.where((message) {
      return teacherFlowText(message['conversation_id']) == conversationId &&
          !_messageIsMine(message) &&
          !_messageRead(message);
    }).length;
  }

  bool _messageIsMine(Map<String, dynamic> message) {
    final senderRole = teacherFlowText(message['sender_role']).toLowerCase();
    final senderId = teacherFlowText(message['sender_id']);
    return senderRole == 'teacher' ||
        senderId == RoleAccessService.teacherStaffId;
  }

  bool _messageRead(Map<String, dynamic> message) {
    final value = message['is_read'];
    if (value is bool) return value;
    if (value is num) return value != 0;
    return teacherFlowText(value).toLowerCase() == 'true';
  }

  String _messageDate(Map<String, dynamic> message) {
    final value = DateTime.tryParse(
      teacherFlowText(message['sent_at'] ?? message['created_at']),
    );
    if (value == null) return '';
    return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }

  List<_DirectThread> _directThreads(
    List<Map<String, dynamic>> rows, {
    List<_ChatTarget> chatTargets = const [],
  }) {
    final grouped = <String, _DirectThread>{};
    final targetById = {for (final target in chatTargets) target.id: target};
    for (final target in chatTargets.where(
      (target) => target.role == 'teacher',
    )) {
      grouped[target.id] = _DirectThread(
        counterpartId: target.id,
        role: target.role,
        label: target.label,
      );
    }
    for (final row in rows) {
      final incoming = _directMessageIncoming(row);
      final counterpartId = incoming
          ? teacherFlowText(row['sender_id'])
          : teacherFlowText(row['receiver_id']);
      if (counterpartId.isEmpty) continue;
      final role = incoming
          ? teacherFlowText(row['sender_role'], fallback: 'Principal')
          : teacherFlowText(row['receiver_role'], fallback: 'Principal');
      final target = targetById[counterpartId];
      final thread = grouped.putIfAbsent(
        counterpartId,
        () => _DirectThread(
          counterpartId: counterpartId,
          role: role,
          label: target?.label,
        ),
      );
      thread.messages.add(row);
    }
    final threads = grouped.values.toList();
    for (final thread in threads) {
      thread.messages.sort(
        (a, b) => _directMessageTime(a).compareTo(_directMessageTime(b)),
      );
    }
    threads.sort((a, b) => b.lastTime.compareTo(a.lastTime));
    return threads;
  }

  List<_ChatTarget> _buildChatTargets({
    required List<UserAccountModel> teachers,
    required List<UserAccountModel> parents,
    required List<StudentModel> students,
    required UserResponse profile,
  }) {
    final targets = <_ChatTarget>[];
    for (final teacher in teachers) {
      if (teacher.id == profile.id ||
          teacher.linkedId == RoleAccessService.teacherStaffId) {
        continue;
      }
      targets.add(
        _ChatTarget(
          id: teacher.id,
          role: 'teacher',
          label: _userLabel(teacher),
          subtitle: teacher.email.isEmpty ? 'Teacher account' : teacher.email,
        ),
      );
    }
    final parentById = {for (final parent in parents) parent.id: parent};
    final seenParents = <String>{};
    for (final student in students) {
      for (final account in student.parentAccounts) {
        final parentId = teacherFlowText(account['id'] ?? account['user_id']);
        if (parentId.isEmpty || !seenParents.add('$parentId:${student.id}')) {
          continue;
        }
        final parent = parentById[parentId];
        targets.add(
          _ChatTarget(
            id: parentId,
            role: 'parent',
            label: parent == null
                ? teacherFlowText(
                    account['name'] ?? account['username'],
                    fallback: 'Parent',
                  )
                : _userLabel(parent),
            subtitle: 'Parent of ${student.fullName}',
            studentId: student.id,
            studentName: student.fullName,
          ),
        );
      }
    }
    targets.sort((a, b) => a.label.compareTo(b.label));
    return targets;
  }

  String _userLabel(UserAccountModel user) {
    final name = user.name.trim();
    if (name.isNotEmpty) return name;
    final username = user.username.trim();
    if (username.isNotEmpty) return username;
    final email = user.email.trim();
    return email.isEmpty ? 'User' : email;
  }
}

class _DirectThread {
  final String counterpartId;
  final String role;
  final String? displayLabel;
  final List<Map<String, dynamic>> messages = [];

  _DirectThread({
    required this.counterpartId,
    required this.role,
    String? label,
  }) : displayLabel = label;

  String get label => displayLabel ?? teacherFlowTitleCase(role);

  String get lastMessage => messages.isEmpty
      ? 'No messages'
      : teacherFlowText(
          messages.last['message_content'] ??
              messages.last['message'] ??
              messages.last['body'],
          fallback: 'Message',
        );

  int get unreadCount => messages.where((row) {
    final receiverId = teacherFlowText(row['receiver_id']);
    final read = row['is_read'];
    final isRead = read is bool
        ? read
        : read is num
        ? read != 0
        : teacherFlowText(read).toLowerCase() == 'true';
    return receiverId == RoleAccessService.teacherUserId && !isRead;
  }).length;

  DateTime get lastTime => messages.isEmpty
      ? DateTime.fromMillisecondsSinceEpoch(0)
      : DateTime.tryParse(
              teacherFlowText(
                messages.last['sent_at'] ?? messages.last['created_at'],
              ),
            ) ??
            DateTime.fromMillisecondsSinceEpoch(0);
}

class _ChatTarget {
  final String id;
  final String role;
  final String label;
  final String subtitle;
  final String studentId;
  final String studentName;

  const _ChatTarget({
    required this.id,
    required this.role,
    required this.label,
    required this.subtitle,
    this.studentId = '',
    this.studentName = '',
  });
}

class _ThreadTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final int unread;
  final VoidCallback onTap;

  const _ThreadTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.unread,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? teacherFlowAccent.withAlpha(22) : Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        leading: CircleAvatar(
          backgroundColor: teacherFlowAccent.withAlpha(26),
          child: const Icon(
            Icons.person_outline_rounded,
            color: teacherFlowAccent,
          ),
        ),
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(
          subtitle.isEmpty ? 'Conversation' : subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: unread <= 0
            ? null
            : TeacherStatusPill(label: '$unread', color: AppTheme.error),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final String text;
  final bool mine;
  final String label;
  final String time;
  final bool unread;
  final VoidCallback onMarkRead;

  const _ChatBubble({
    required this.text,
    required this.mine,
    required this.label,
    required this.time,
    required this.unread,
    required this.onMarkRead,
  });

  @override
  Widget build(BuildContext context) {
    final color = mine ? teacherFlowAccent : const Color(0xFFF2F7F8);
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
            border: mine ? null : Border.all(color: const Color(0xFFDDECEF)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 9, 12, 8),
            child: Column(
              crossAxisAlignment: mine
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: mine ? Colors.white70 : teacherFlowMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  text,
                  style: TextStyle(
                    color: mine ? Colors.white : teacherFlowInk,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      time,
                      style: TextStyle(
                        color: mine ? Colors.white70 : teacherFlowMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (unread) ...[
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: onMarkRead,
                        child: const Icon(
                          Icons.done_all_rounded,
                          size: 15,
                          color: AppTheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
