import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/backend_api_client.dart';
import '../../services/role_access_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/dashboard_fab_widget.dart';
import '../../widgets/erp_module_scaffold.dart';
import '../../widgets/teacher_navigation.dart';

class TeacherCommunicationScreen extends StatefulWidget {
  const TeacherCommunicationScreen({super.key});

  @override
  State<TeacherCommunicationScreen> createState() =>
      _TeacherCommunicationScreenState();
}

class _TeacherCommunicationScreenState extends State<TeacherCommunicationScreen>
    with SingleTickerProviderStateMixin {
  int _selectedNavIndex = 8;
  late final TabController _tabController;
  final _messageCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  bool _loading = true;
  bool _sending = false;
  String? _error;
  String? _activeConversationId;

  List<Map<String, dynamic>> _schoolNotices = [];
  List<Map<String, dynamic>> _conversations = [];
  List<Map<String, dynamic>> _messages = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
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
      final teacherStaffId = RoleAccessService.teacherStaffId;
      final teacherConversations = conversations
          .where(
            (conversation) =>
                teacherStaffId.isEmpty ||
                _text(conversation['teacher_id']) == teacherStaffId,
          )
          .toList();
      final conversationIds = teacherConversations
          .map((conversation) => _text(conversation['id']))
          .where((id) => id.isNotEmpty)
          .toSet();
      final scopedMessages =
          messages
              .where(
                (message) =>
                    conversationIds.contains(
                      _text(message['conversation_id']),
                    ) &&
                    _text(message['body']).isNotEmpty,
              )
              .toList()
            ..sort(
              (a, b) => _messageTimestamp(a).compareTo(_messageTimestamp(b)),
            );
      teacherConversations.sort(
        (a, b) => _conversationLastTimestamp(
          b,
          scopedMessages,
        ).compareTo(_conversationLastTimestamp(a, scopedMessages)),
      );

      if (!mounted) return;
      setState(() {
        _conversations = teacherConversations;
        _messages = scopedMessages;
        _schoolNotices = schoolNotices
            .map(
              (notice) => {
                'title': notice.title,
                'content': notice.content,
                'date': _formatDate(notice.publishedAt),
                'type': notice.isUrgent ? 'urgent' : 'notice',
                'publishedBy': notice.createdBy,
              },
            )
            .toList();
        if (_activeConversationId != null &&
            !conversationIds.contains(_activeConversationId)) {
          _activeConversationId = null;
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load teacher messages: $e';
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _messageCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeConversation = _activeConversation;
    final drawer = TeacherDrawer(
      selectedIndex: _selectedNavIndex,
      onDestinationSelected: (i) => setState(() => _selectedNavIndex = i),
    );
    return SchoolDeskModuleScaffold(
      title: activeConversation == null ? 'Communication' : 'Parent Chat',
      subtitle: activeConversation == null
          ? 'Chats with parents and school notices'
          : _conversationTitle(activeConversation),
      drawer: drawer,
      floatingActionButton: activeConversation == null
          ? const DashboardFabWidget(role: DashboardRole.teacher)
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      actions: [
        IconButton(
          tooltip: 'Refresh messages',
          icon: const Icon(Icons.refresh_rounded),
          onPressed: _loadData,
        ),
      ],
      bottom: activeConversation == null
          ? TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Chats'),
                Tab(text: 'School Notices'),
              ],
            )
          : null,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return _emptyState(_error!, actionLabel: 'Retry', onAction: _loadData);
    }
    if (_activeConversationId != null) return _buildChatThread();
    return TabBarView(
      controller: _tabController,
      children: [_buildConversationList(), _buildSchoolNotices()],
    );
  }

  Widget _buildConversationList() {
    if (_conversations.isEmpty) {
      return _emptyState(
        'No parent chats yet. Parent conversations appear here when a parent starts a teacher chat.',
        actionLabel: 'Refresh',
        onAction: _loadData,
      );
    }
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _conversations.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final conversation = _conversations[index];
          final conversationId = _text(conversation['id']);
          final messages = _messagesForConversation(conversationId);
          final lastMessage = messages.isEmpty ? null : messages.last;
          final unread = messages
              .where((message) => !_isTeacherMessage(message))
              .where((message) => message['is_read'] != true)
              .length;
          return InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () async {
              setState(() => _activeConversationId = conversationId);
              await _markConversationRead(conversationId);
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => _scrollToBottom(),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: unread > 0
                    ? AppTheme.primaryContainer.withAlpha(55)
                    : AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: unread > 0
                      ? AppTheme.primary.withAlpha(65)
                      : AppTheme.outlineVariant,
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppTheme.accent.withAlpha(25),
                    child: Text(
                      _initials(_conversationTitle(conversation)),
                      style: GoogleFonts.dmSans(
                        color: AppTheme.accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _conversationTitle(conversation),
                                style: GoogleFonts.dmSans(
                                  fontSize: 13,
                                  fontWeight: unread > 0
                                      ? FontWeight.w700
                                      : FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              _messageTime(lastMessage),
                              style: GoogleFonts.dmSans(
                                fontSize: 11,
                                color: AppTheme.muted,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _conversationSubtitle(conversation),
                          style: GoogleFonts.dmSans(
                            fontSize: 11,
                            color: AppTheme.muted,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _lastMessagePreview(conversation, lastMessage),
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            color: unread > 0
                                ? AppTheme.onSurface
                                : AppTheme.onSurfaceVariant,
                            fontWeight: unread > 0
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (unread > 0) ...[
                    const SizedBox(width: 10),
                    Container(
                      width: 22,
                      height: 22,
                      decoration: const BoxDecoration(
                        color: AppTheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '$unread',
                          style: GoogleFonts.dmSans(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildChatThread() {
    final conversation = _activeConversation;
    if (conversation == null || _activeConversationId == null) {
      return _emptyState('This chat is no longer available.');
    }
    final messages = _messagesForConversation(_activeConversationId!);
    return Column(
      children: [
        Container(
          color: AppTheme.surface,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Back to chats',
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => setState(() => _activeConversationId = null),
              ),
              const SizedBox(width: 4),
              CircleAvatar(
                backgroundColor: AppTheme.accent.withAlpha(25),
                child: Text(
                  _initials(_conversationTitle(conversation)),
                  style: GoogleFonts.dmSans(
                    color: AppTheme.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _conversationTitle(conversation),
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      _conversationSubtitle(conversation),
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: AppTheme.muted,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: messages.isEmpty
              ? _emptyState('No messages in this chat yet.')
              : ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (_, index) {
                    final message = messages[index];
                    return _messageBubble(
                      message,
                      isMine: _isTeacherMessage(message),
                    );
                  },
                ),
        ),
        _chatInputBar(),
      ],
    );
  }

  Widget _messageBubble(Map<String, dynamic> message, {required bool isMine}) {
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.76,
        ),
        child: Column(
          crossAxisAlignment: isMine
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMine ? AppTheme.primary : AppTheme.surfaceVariant,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(14),
                  topRight: const Radius.circular(14),
                  bottomLeft: Radius.circular(isMine ? 14 : 4),
                  bottomRight: Radius.circular(isMine ? 4 : 14),
                ),
              ),
              child: Text(
                _text(message['body']),
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  color: isMine ? Colors.white : AppTheme.onSurface,
                ),
              ),
            ),
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _messageTime(message),
                  style: GoogleFonts.dmSans(
                    fontSize: 10,
                    color: AppTheme.muted,
                  ),
                ),
                if (isMine) ...[
                  const SizedBox(width: 4),
                  Icon(
                    message['is_read'] == true
                        ? Icons.done_all_rounded
                        : Icons.done_rounded,
                    size: 14,
                    color: message['is_read'] == true
                        ? AppTheme.info
                        : AppTheme.muted,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chatInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.outlineVariant)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageCtrl,
              enabled: !_sending,
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: AppTheme.surfaceVariant,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            tooltip: 'Send message',
            onPressed: _sending ? null : _sendMessage,
            icon: _sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildSchoolNotices() {
    if (_schoolNotices.isEmpty) {
      return _emptyState(
        'No school notices yet. Circulars from Admin and Principal will appear here.',
        actionLabel: 'Refresh',
        onAction: _loadData,
      );
    }
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _schoolNotices.length,
        itemBuilder: (context, i) {
          final notice = _schoolNotices[i];
          final type = _text(notice['type'], fallback: 'notice');
          final color = type == 'urgent' ? AppTheme.error : AppTheme.secondary;
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withAlpha(45)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: color.withAlpha(20),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        type.toUpperCase(),
                        style: GoogleFonts.dmSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _text(notice['date']),
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: AppTheme.muted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _text(notice['title']),
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _text(notice['content']),
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: AppTheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _emptyState(
    String message, {
    String? actionLabel,
    Future<void> Function()? onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.forum_outlined, size: 44, color: AppTheme.muted),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(fontSize: 13, color: AppTheme.muted),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 14),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel)),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _markConversationRead(String conversationId) async {
    final unread = _messagesForConversation(conversationId)
        .where((message) => !_isTeacherMessage(message))
        .where((message) => message['is_read'] != true)
        .toList();
    for (final message in unread) {
      final id = _text(message['id']);
      if (id.isEmpty) continue;
      await BackendApiClient.instance.updateRaw('/messages/$id', {
        'is_read': true,
      });
      message['is_read'] = true;
    }
    if (mounted) setState(() {});
  }

  Future<void> _sendMessage() async {
    final conversationId = _activeConversationId;
    final body = _messageCtrl.text.trim();
    if (conversationId == null || body.isEmpty) return;
    setState(() => _sending = true);
    try {
      await BackendApiClient.instance.createRaw('/messages', {
        'conversation_id': conversationId,
        'sender_id': RoleAccessService.teacherUserId,
        'sender_role': 'Teacher',
        'sender_name': RoleAccessService.teacherName,
        'body': body,
        'is_read': false,
        'sent_at': DateTime.now().toUtc().toIso8601String(),
      });
      _messageCtrl.clear();
      await _loadData();
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Message send failed: $e')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToBottom() {
    if (!_scrollCtrl.hasClients) return;
    _scrollCtrl.animateTo(
      _scrollCtrl.position.maxScrollExtent,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  Map<String, dynamic>? get _activeConversation {
    final activeId = _activeConversationId;
    if (activeId == null) return null;
    for (final conversation in _conversations) {
      if (_text(conversation['id']) == activeId) return conversation;
    }
    return null;
  }

  List<Map<String, dynamic>> _messagesForConversation(String conversationId) {
    return _messages
        .where((message) => _text(message['conversation_id']) == conversationId)
        .toList();
  }

  bool _isTeacherMessage(Map<String, dynamic> message) {
    final role = _text(message['sender_role']).toLowerCase();
    final senderId = _text(message['sender_id']);
    return role == 'teacher' || senderId == RoleAccessService.teacherUserId;
  }

  String _conversationTitle(Map<String, dynamic> conversation) {
    final title = _text(conversation['title']);
    final student = _text(conversation['student_id']);
    final parent = _text(conversation['parent_id']);
    if (title.isNotEmpty && title != RoleAccessService.teacherName) {
      return title;
    }
    if (student.isNotEmpty) return 'Parent of $student';
    if (parent.isNotEmpty) return 'Parent $parent';
    return 'Parent chat';
  }

  String _conversationSubtitle(Map<String, dynamic> conversation) {
    final parts = [
      _text(conversation['reference_type'], fallback: 'parent-chat'),
      if (_text(conversation['student_id']).isNotEmpty)
        'Student: ${_text(conversation['student_id'])}',
      if (_text(conversation['parent_id']).isNotEmpty)
        'Parent: ${_text(conversation['parent_id'])}',
    ];
    return parts.where((part) => part.trim().isNotEmpty).join(' · ');
  }

  String _lastMessagePreview(
    Map<String, dynamic> conversation,
    Map<String, dynamic>? lastMessage,
  ) {
    if (lastMessage != null) {
      final prefix = _isTeacherMessage(lastMessage) ? 'You: ' : '';
      return '$prefix${_text(lastMessage['body'])}';
    }
    return _text(conversation['last_message'], fallback: 'No messages yet');
  }

  int _conversationLastTimestamp(
    Map<String, dynamic> conversation,
    List<Map<String, dynamic>> messages,
  ) {
    final conversationId = _text(conversation['id']);
    final matches = messages
        .where((message) => _text(message['conversation_id']) == conversationId)
        .toList();
    if (matches.isNotEmpty) return _messageTimestamp(matches.last);
    return _timestamp(conversation['last_message_time']);
  }

  int _messageTimestamp(Map<String, dynamic> message) {
    return _timestamp(message['sent_at'] ?? message['created_at']);
  }

  int _timestamp(dynamic value) {
    return DateTime.tryParse(value?.toString() ?? '')?.millisecondsSinceEpoch ??
        0;
  }

  String _messageTime(Map<String, dynamic>? message) {
    if (message == null) return '';
    final parsed = DateTime.tryParse(
      _text(message['sent_at'], fallback: _text(message['created_at'])),
    );
    if (parsed == null) return '';
    final local = parsed.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  String _formatDate(dynamic value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '');
    if (parsed == null) return '';
    final local = parsed.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
  }

  String _initials(String value) {
    final initials = value
        .split(RegExp(r'\s+'))
        .where((part) => part.trim().isNotEmpty)
        .take(2)
        .map((part) => part.trim()[0].toUpperCase())
        .join();
    return initials.isEmpty ? 'P' : initials;
  }

  String _text(dynamic value, {String fallback = ''}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty || text == 'null' ? fallback : text;
  }
}
