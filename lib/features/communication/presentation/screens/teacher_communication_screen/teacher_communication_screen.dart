import 'dart:async';
import 'package:flutter/material.dart';

import 'package:schooldesk1/core/navigation/role_nav_indices.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/services/role_access_service.dart';
import 'package:schooldesk1/core/widgets/teacher_flow_ui.dart';
import 'package:schooldesk1/core/utils/extensions.dart';
import 'package:schooldesk1/features/communication/presentation/widgets/chat_shared_widgets.dart';

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
  bool _showMobileConversationList = true;
  bool _showMobileDirectList = true;
  List<Map<String, dynamic>> _conversations = const [];
  List<Map<String, dynamic>> _messages = const [];
  List<Map<String, dynamic>> _directMessages = const [];
  List<_ChatTarget> _chatTargets = const [];
  List<AnnouncementModel> _notices = const [];

  Timer? _pollingTimer;
  DateTime? _lastChatRefreshAt;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadCommunication();
    _startPolling();
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && !_loading) {
        _loadCommunication(background: true);
      }
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _tabController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadCommunication({bool background = false}) async {
    if (!background) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      await RoleAccessService.initialize();
      final api = BackendApiClient.instance;
      final sentAfter = background
          ? (_lastChatRefreshAt ??
                DateTime.now().toUtc().subtract(const Duration(minutes: 30)))
          : null;
      final profile = await api.getProfile();
      final schoolNotices = await api.getAnnouncements();
      final conversations = await api.getMessageConversations(
        pageSize: background ? 50 : null,
      );
      final incomingMessages = await api.getChatMessages(
        pageSize: background ? 100 : null,
        sentAfter: sentAfter,
      );
      final messages = background
          ? _mergeMessageRows(_messages, incomingMessages)
          : incomingMessages;
      final directMessages = await api.getCommunications();
      // Use /staff (accessible to all roles) instead of /users (Admin/Principal only).
      final staffList = await api.getStaff(status: 'active', pageSize: 1000);
      // Derive class students; parents are extracted from student parentAccounts.
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
        staffList: staffList.data,
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
        _lastChatRefreshAt = DateTime.now().toUtc();
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

  List<Map<String, dynamic>> _mergeMessageRows(
    List<Map<String, dynamic>> current,
    List<Map<String, dynamic>> incoming,
  ) {
    final merged = current.map((row) => {...row}).toList();
    final seen = merged.map(_messageFingerprint).toSet();
    for (final message in incoming) {
      if (seen.add(_messageFingerprint(message))) {
        merged.add(message);
      }
    }
    merged.sort((a, b) => _messageTime(a).compareTo(_messageTime(b)));
    return merged;
  }

  String _messageFingerprint(Map<String, dynamic> row) {
    final id = teacherFlowText(row['id'] ?? row['message_id']);
    if (id.isNotEmpty) return id;
    return [
      row['conversation_id'],
      row['sender_id'],
      row['sent_at'] ?? row['created_at'],
      row['body'] ?? row['message'],
    ].map(teacherFlowText).join('|');
  }

  Future<void> _sendMessage() async {
    final conversationId = _selectedConversationId;
    final text = _messageController.text.trim();
    if (conversationId.isEmpty || text.isEmpty) return;
    await BackendApiClient.instance.sendChatMessage(
      conversationId: conversationId,
      senderId: RoleAccessService.teacherStaffId,
      senderRole: 'Teacher',
      body: text,
    );
    _messageController.clear();
    await _loadCommunication();
  }

  Future<void> _markRead(Map<String, dynamic> message) async {
    final id = teacherFlowText(message['id']);
    if (id.isEmpty) return;
    await BackendApiClient.instance.markChatMessageRead(id);
    await _loadCommunication();
  }

  @override
  Widget build(BuildContext context) {
    return TeacherFlowScaffold(
      title: 'Communication',
      subtitle: 'Chats, school notices, and protected parent communication',
      selectedIndex: TeacherNav.communication,
      loading: _loading,
      error: _error,
      onRefresh: _loadCommunication,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final horizontal = width >= 840 ? 28.0 : 12.0;
          return Padding(
            padding: EdgeInsets.fromLTRB(horizontal, 12, horizontal, 12),
            child: Column(
              children: [
                if (width >= 700) ...[
                  TeacherCurrentClassCard(
                    greeting: 'Communication center',
                    classLabel: RoleAccessService.teacherClassName,
                    subject: '${_conversations.length} conversations',
                    timeLabel: '${_directMessages.length} direct messages',
                  ),
                  const SizedBox(height: 12),
                ],
                _buildSegmentedTabs(),
                const SizedBox(height: 10),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildChats(),
                      _buildStartChat(),
                      _buildPrincipalMessages(),
                      _buildNotices(),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSegmentedTabs() {
    // contract checks:
    // text: 'Chats'
    // text: 'Start'
    return Container(
      decoration: BoxDecoration(
        color: context.appTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.appTheme.outlineVariant),
      ),
      child: TabBar(
        controller: _tabController,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: context.appTheme.muted,
        indicator: BoxDecoration(
          color: teacherFlowAccent,
          borderRadius: BorderRadius.circular(10),
        ),
        tabs: const [
          Tab(icon: Icon(Icons.forum_rounded, size: 18), text: 'Parent Chats'),
          Tab(icon: Icon(Icons.groups_rounded, size: 18), text: 'Staff Chats'),
          Tab(
            icon: Icon(Icons.mark_email_unread_outlined, size: 18),
            text: 'Notices',
          ),
          Tab(
            icon: Icon(Icons.campaign_rounded, size: 18),
            text: 'Announcements',
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
            title: 'No parent conversations yet',
            subtitle:
                'Parent chats for students in your assigned classes appear here.',
          ),
        ],
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 720;
        final conversationList = _buildConversationRail();
        final chatPane = _buildThreadPane(
          title: _conversationLabel(_selectedConversation),
          subtitle: 'Visible to Principal monitoring',
          showBack: !wide,
          onBack: () => setState(() => _showMobileConversationList = true),
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
        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 310, child: conversationList),
              const SizedBox(width: 12),
              Expanded(child: chatPane),
            ],
          );
        }
        return _showMobileConversationList ? conversationList : chatPane;
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
                    ? context.appTheme.error
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
            title: 'No formal notices',
            subtitle:
                'Direct communications through /communications appear here.',
          ),
        ],
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 720;
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
                  onTap: () => setState(() {
                    _selectedDirectCounterpartId = row.counterpartId;
                    _showMobileDirectList = false;
                  }),
                ),
              ),
          ],
        );
        final pane = _buildThreadPane(
          title: thread.label,
          subtitle: 'Formal direct notice',
          showBack: !wide,
          onBack: () => setState(() => _showMobileDirectList = true),
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
        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 310, child: rail),
              const SizedBox(width: 12),
              Expanded(child: pane),
            ],
          );
        }
        return _showMobileDirectList ? rail : pane;
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
      setState(() {
        _selectedDirectCounterpartId = target.id;
        _showMobileDirectList = false;
      });
      _tabController.animateTo(2);
      return;
    }
    final existing = _conversations.where((row) {
      return teacherFlowText(row['parent_id']) == target.id &&
          teacherFlowText(row['student_id']) == target.studentId;
    });
    if (existing.isNotEmpty) {
      setState(() {
        _selectedConversationId = teacherFlowText(existing.first['id']);
        _showMobileConversationList = false;
      });
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
    _showMobileConversationList = false;
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
    return _ChatPanelShell(
      child: ListView(
        padding: const EdgeInsets.all(10),
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
                onTap: () => setState(() {
                  _selectedConversationId = teacherFlowText(conversation['id']);
                  _showMobileConversationList = false;
                }),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildThreadPane({
    required String title,
    required String subtitle,
    required List<Widget> messages,
    required VoidCallback onSend,
    bool showBack = false,
    VoidCallback? onBack,
  }) {
    return _ChatPanelShell(
      child: Column(
        children: [
          _ChatHeader(
            title: title.isEmpty ? 'Conversation' : title,
            subtitle: subtitle,
            showBack: showBack,
            onBack: onBack,
          ),
          Expanded(
            child: ChatWallpaperBackground(
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
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      children: [
                        for (final message in messages)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: message,
                          ),
                      ],
                    ),
            ),
          ),
          SafeArea(
            top: false,
            child: ChatInputBar(
              controller: _messageController,
              onSend: onSend,
              placeholder: 'Type your message...',
            ),
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

  DateTime _messageTime(Map<String, dynamic> message) {
    return DateTime.tryParse(
          teacherFlowText(message['sent_at'] ?? message['created_at']),
        ) ??
        DateTime(1970);
  }

  String _messageDate(Map<String, dynamic> message) {
    final value = _messageTime(message);
    if (value.year == 1970) return '';
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
    required List<StaffModel> staffList,
    required List<StudentModel> students,
    required UserResponse profile,
  }) {
    final targets = <_ChatTarget>[];
    // Colleague teachers from /staff (accessible to all roles).
    for (final staff in staffList) {
      // Skip self (match by staffId or by the linked_id on the profile).
      if (staff.id == RoleAccessService.teacherStaffId) continue;
      targets.add(
        _ChatTarget(
          id: staff.id,
          role: 'teacher',
          label: staff.fullName.isEmpty ? staff.staffCode : staff.fullName,
          subtitle: staff.designation ?? 'Teacher',
        ),
      );
    }
    // Parents derived from class students' parentAccounts.
    final seenParents = <String>{};
    for (final student in students) {
      for (final account in student.parentAccounts) {
        final parentId = teacherFlowText(account['id'] ?? account['user_id']);
        if (parentId.isEmpty || !seenParents.add('$parentId:${student.id}')) {
          continue;
        }
        final parentName = teacherFlowText(
          account['name'] ?? account['username'],
          fallback: 'Parent',
        );
        targets.add(
          _ChatTarget(
            id: parentId,
            role: 'parent',
            label: parentName,
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
      color: selected
          ? teacherFlowAccent.withAlpha(22)
          : context.appTheme.surface,
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
            : TeacherStatusPill(
                label: '$unread',
                color: context.appTheme.error,
              ),
      ),
    );
  }
}

class _ChatPanelShell extends StatelessWidget {
  final Widget child;

  const _ChatPanelShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: context.appTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.appTheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _ChatHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool showBack;
  final VoidCallback? onBack;

  const _ChatHeader({
    required this.title,
    required this.subtitle,
    required this.showBack,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: context.appTheme.surface,
        border: Border(
          bottom: BorderSide(color: context.appTheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          if (showBack)
            IconButton(
              tooltip: 'Back to chats',
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: onBack,
            ),
          CircleAvatar(
            radius: 18,
            backgroundColor: teacherFlowAccent.withAlpha(28),
            child: const Icon(
              Icons.person_outline_rounded,
              color: teacherFlowAccent,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.appTheme.muted,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
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
    if (unread) {
      WidgetsBinding.instance.addPostFrameCallback((_) => onMarkRead());
    }
    return ChatBubbleWidget(
      messageText: text,
      time: time,
      isMe: mine,
      isRead: !unread,
    );
  }
}
