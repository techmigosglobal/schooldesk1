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
  List<Map<String, dynamic>> _conversations = const [];
  List<Map<String, dynamic>> _messages = const [];
  List<AnnouncementModel> _notices = const [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
      final schoolNotices = await api.getAnnouncements();
      final conversations = await api.getRawList('/message-conversations');
      final messages = await api.getRawList('/messages');
      final staffId = RoleAccessService.teacherStaffId;
      final visibleConversations = conversations.where((row) {
        final teacherId = teacherFlowText(row['teacher_id'] ?? row['staff_id']);
        return teacherId.isEmpty || teacherId == staffId;
      }).toList();
      if (!mounted) return;
      setState(() {
        _notices = schoolNotices;
        _conversations = visibleConversations;
        _selectedConversationId = _selectedConversationId.isNotEmpty
            ? _selectedConversationId
            : (visibleConversations.isNotEmpty
                  ? teacherFlowText(visibleConversations.first['id'])
                  : '');
        _messages = messages;
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
            timeLabel: '${_notices.length} school notices',
          ),
          const SizedBox(height: 18),
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Chats'),
              Tab(text: 'School Notices'),
            ],
          ),
          SizedBox(
            height: 620,
            child: TabBarView(
              controller: _tabController,
              children: [_buildChats(), _buildNotices()],
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
    return ListView(
      padding: const EdgeInsets.only(top: 14, bottom: 24),
      children: [
        if (_conversations.isEmpty)
          const TeacherFlowCard(
            icon: Icons.forum_rounded,
            title: 'No conversations',
            subtitle:
                'Teacher, admin, principal, and class-parent chats appear here.',
          )
        else ...[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final conversation in _conversations) ...[
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(_conversationLabel(conversation)),
                      selected:
                          teacherFlowText(conversation['id']) ==
                          _selectedConversationId,
                      onSelected: (_) => setState(
                        () => _selectedConversationId = teacherFlowText(
                          conversation['id'],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          ...visibleMessages.map(
            (message) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TeacherFlowCard(
                icon: Icons.chat_bubble_outline_rounded,
                title: teacherFlowTitleCase(
                  teacherFlowText(message['sender_role'], fallback: 'Message'),
                ),
                subtitle: teacherFlowText(
                  message['message'] ?? message['body'],
                  fallback: 'Message',
                ),
                status: teacherFlowText(message['is_read']) == 'true'
                    ? 'Read'
                    : 'Unread',
                body: TeacherFlowActionWrap(
                  actions: [
                    TeacherFlowAction(
                      label: 'Mark Read',
                      icon: Icons.done_all_rounded,
                      onTap: () => _markRead(message),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
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
                onPressed: _sendMessage,
                icon: const Icon(Icons.send_rounded),
              ),
            ],
          ),
        ],
      ],
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

  String _conversationLabel(Map<String, dynamic> row) {
    return teacherFlowText(
      row['title'] ??
          row['name'] ??
          row['parent_name'] ??
          row['conversation_type'],
      fallback: 'Conversation',
    );
  }
}
