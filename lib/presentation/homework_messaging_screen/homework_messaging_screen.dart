import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/messaging_service.dart';
import '../../widgets/parent_navigation.dart';
import '../../widgets/teacher_navigation.dart';

class HomeworkMessagingScreen extends StatefulWidget {
  final String role; // 'teacher' or 'parent'
  final String userId;
  final String userName;

  const HomeworkMessagingScreen({
    super.key,
    required this.role,
    required this.userId,
    required this.userName,
  });

  @override
  State<HomeworkMessagingScreen> createState() =>
      _HomeworkMessagingScreenState();
}

class _HomeworkMessagingScreenState extends State<HomeworkMessagingScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  MessagingService? _service;
  bool _loading = true;
  List<Map<String, dynamic>> _conversations = [];
  String? _activeConvId;
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _sending = false;
  List<Map<String, dynamic>> _activeMessages = [];
  int _totalUnread = 0;

  static const Color _teacherColor = Color(0xFF1A5276);
  static const Color _parentColor = Color(0xFF1A6B4A);

  Color get _primaryColor =>
      widget.role == 'teacher' ? _teacherColor : _parentColor;

  int get _navIndex => widget.role == 'teacher' ? 9 : 5;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final svc = await MessagingService.getInstance();
    svc.addListener(_onServiceChanged);
    if (!mounted) return;
    setState(() {
      _service = svc;
      _conversations = _getConversations(svc);
      _totalUnread = svc.getUnreadCountForRole(widget.role, widget.userId);
      _loading = false;
    });
  }

  List<Map<String, dynamic>> _getConversations(MessagingService svc) {
    if (widget.role == 'teacher') {
      return svc.getAllConversationsForTeacher(widget.userId);
    } else {
      return svc.getConversationsForRole('parent', widget.userId);
    }
  }

  void _onServiceChanged() {
    if (!mounted) return;
    setState(() {
      _conversations = _getConversations(_service!);
      _totalUnread = _service!.getUnreadCountForRole(
        widget.role,
        widget.userId,
      );
      if (_activeConvId != null) {
        _activeMessages = _service!.getMessages(_activeConvId!);
      }
    });
    _scrollToBottom();
  }

  @override
  void dispose() {
    _service?.removeListener(_onServiceChanged);
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _openConversation(String convId) async {
    setState(() {
      _activeConvId = convId;
      _activeMessages = _service!.getMessages(convId);
    });
    await _service!.markConversationRead(convId, widget.role);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _activeConvId == null || _sending) return;
    setState(() => _sending = true);
    _msgCtrl.clear();
    await _service!.sendMessage(
      conversationId: _activeConvId!,
      sender: widget.role,
      senderName: widget.userName,
      text: text,
    );
    setState(() => _sending = false);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 700;

    Widget drawer = widget.role == 'teacher'
        ? TeacherDrawer(selectedIndex: _navIndex, onDestinationSelected: (_) {})
        : ParentDrawer(selectedIndex: _navIndex, onDestinationSelected: (_) {});

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: _primaryColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded, color: Colors.white),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                _activeConvId != null && !isWide
                    ? _getActiveConvTitle()
                    : 'Homework Feedback',
                style: GoogleFonts.dmSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (_totalUnread > 0 && (_activeConvId == null || isWide))
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(50),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withAlpha(80)),
                ),
                child: Text(
                  '$_totalUnread unread',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
        actions: [
          if (_activeConvId != null && !isWide)
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => setState(() => _activeConvId = null),
            ),
          if (widget.role == 'teacher')
            IconButton(
              icon: const Icon(Icons.add_comment_outlined, color: Colors.white),
              tooltip: 'New Feedback Thread',
              onPressed: _showNewConversationDialog,
            ),
        ],
      ),
      drawer: drawer,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : isWide
          ? _buildWideLayout()
          : _buildNarrowLayout(),
    );
  }

  String _getActiveConvTitle() {
    final conv = _conversations.firstWhere(
      (c) => c['id'] == _activeConvId,
      orElse: () => {},
    );
    return conv['homeworkTitle'] as String? ?? 'Feedback';
  }

  Widget _buildWideLayout() {
    return Row(
      children: [
        SizedBox(width: 320, child: _buildConversationList()),
        const VerticalDivider(width: 1),
        Expanded(
          child: _activeConvId == null
              ? _buildEmptyState()
              : _buildChatView(_activeConvId!),
        ),
      ],
    );
  }

  Widget _buildNarrowLayout() {
    if (_activeConvId != null) {
      return _buildChatView(_activeConvId!);
    }
    return _buildConversationList();
  }

  Widget _buildConversationList() {
    final unreadKey = widget.role == 'teacher'
        ? 'teacherUnread'
        : 'parentUnread';
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            decoration: BoxDecoration(
              color: _primaryColor.withAlpha(15),
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Icon(Icons.forum_outlined, color: _primaryColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Conversations',
                  style: GoogleFonts.dmSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _primaryColor,
                  ),
                ),
                const Spacer(),
                if (_totalUnread > 0)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.shade600,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$_totalUnread',
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: _primaryColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_conversations.length}',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _conversations.isEmpty
                ? _buildNoConversations()
                : ListView.separated(
                    itemCount: _conversations.length,
                    separatorBuilder: (_, __) =>
                        Divider(height: 1, color: Colors.grey.shade100),
                    itemBuilder: (context, i) {
                      final conv = _conversations[i];
                      final unread = conv[unreadKey] as int? ?? 0;
                      final isActive = _activeConvId == conv['id'];
                      return _buildConvTile(conv, unread, isActive);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildConvTile(Map<String, dynamic> conv, int unread, bool isActive) {
    final time = _formatTime(conv['lastMessageTime'] as int? ?? 0);
    final subjectColor = _subjectColor(conv['subject'] as String? ?? '');

    return InkWell(
      onTap: () => _openConversation(conv['id'] as String),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        color: isActive ? _primaryColor.withAlpha(15) : Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: subjectColor.withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      (conv['subject'] as String? ?? 'S').substring(0, 1),
                      style: GoogleFonts.dmSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: subjectColor,
                      ),
                    ),
                  ),
                ),
                if (unread > 0)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: Colors.red.shade600,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: Center(
                        child: Text(
                          '$unread',
                          style: GoogleFonts.dmSans(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
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
                          conv['homeworkTitle'] as String? ?? '',
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            fontWeight: unread > 0
                                ? FontWeight.w700
                                : FontWeight.w600,
                            color: const Color(0xFF1A1A2E),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        time,
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          color: unread > 0
                              ? Colors.red.shade600
                              : Colors.grey.shade500,
                          fontWeight: unread > 0
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: subjectColor.withAlpha(20),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${conv['subject']} · ${conv['className']}',
                          style: GoogleFonts.dmSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: subjectColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          conv['lastMessage'] as String? ?? '',
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            color: unread > 0
                                ? const Color(0xFF1A1A2E)
                                : Colors.grey.shade600,
                            fontWeight: unread > 0
                                ? FontWeight.w500
                                : FontWeight.w400,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.role == 'teacher'
                        ? '👤 ${conv['studentName']} · ${conv['parentName']}'
                        : '👩‍🏫 ${conv['teacherName']}',
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatView(String convId) {
    final conv = _conversations.firstWhere(
      (c) => c['id'] == convId,
      orElse: () => {},
    );
    if (conv.isEmpty) return _buildEmptyState();

    return Column(
      children: [
        _buildChatHeader(conv),
        Expanded(
          child: _activeMessages.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        size: 48,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No messages yet.\nStart the conversation!',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  itemCount: _activeMessages.length,
                  itemBuilder: (context, i) {
                    final msg = _activeMessages[i];
                    final isMe = msg['sender'] == widget.role;
                    final showDateSep =
                        i == 0 ||
                        !_isSameDay(
                          _activeMessages[i - 1]['timestamp'] as int? ?? 0,
                          msg['timestamp'] as int? ?? 0,
                        );
                    return Column(
                      children: [
                        if (showDateSep)
                          _buildDateSeparator(msg['timestamp'] as int? ?? 0),
                        _buildMessageBubble(msg, isMe),
                      ],
                    );
                  },
                ),
        ),
        _buildInputBar(),
      ],
    );
  }

  bool _isSameDay(int ts1, int ts2) {
    final d1 = DateTime.fromMillisecondsSinceEpoch(ts1);
    final d2 = DateTime.fromMillisecondsSinceEpoch(ts2);
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  }

  Widget _buildDateSeparator(int timestamp) {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    String label;
    if (_isSameDay(timestamp, now.millisecondsSinceEpoch)) {
      label = 'Today';
    } else if (_isSameDay(
      timestamp,
      now.subtract(const Duration(days: 1)).millisecondsSinceEpoch,
    )) {
      label = 'Yesterday';
    } else {
      label = '${dt.day}/${dt.month}/${dt.year}';
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(child: Divider(color: Colors.grey.shade200)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                label,
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          Expanded(child: Divider(color: Colors.grey.shade200)),
        ],
      ),
    );
  }

  Widget _buildChatHeader(Map<String, dynamic> conv) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _subjectColor(
                conv['subject'] as String? ?? '',
              ).withAlpha(25),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                (conv['subject'] as String? ?? 'S').substring(0, 1),
                style: GoogleFonts.dmSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _subjectColor(conv['subject'] as String? ?? ''),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  conv['homeworkTitle'] as String? ?? '',
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1A1A2E),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  widget.role == 'teacher'
                      ? '${conv['studentName']} · ${conv['parentName']}'
                      : '${conv['teacherName']} · ${conv['subject']}',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _subjectColor(
                conv['subject'] as String? ?? '',
              ).withAlpha(20),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              conv['className'] as String? ?? '',
              style: GoogleFonts.dmSans(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _subjectColor(conv['subject'] as String? ?? ''),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg, bool isMe) {
    final time = _formatTime(msg['timestamp'] as int? ?? 0);
    final isRead = msg['read'] as bool? ?? false;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: _primaryColor.withAlpha(20),
              child: Text(
                (msg['senderName'] as String? ?? 'U').substring(0, 1),
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _primaryColor,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMe
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (!isMe)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4, left: 4),
                    child: Text(
                      msg['senderName'] as String? ?? '',
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isMe ? _primaryColor : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isMe ? 16 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 16),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(10),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    msg['text'] as String? ?? '',
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      color: isMe ? Colors.white : const Color(0xFF1A1A2E),
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      time,
                      style: GoogleFonts.dmSans(
                        fontSize: 10,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 4),
                      Icon(
                        isRead ? Icons.done_all : Icons.done,
                        size: 12,
                        color: isRead ? _primaryColor : Colors.grey.shade400,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (isMe) const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF5F6FA),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: TextField(
                controller: _msgCtrl,
                maxLines: 3,
                minLines: 1,
                textInputAction: TextInputAction.newline,
                style: GoogleFonts.dmSans(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Type your message…',
                  hintStyle: GoogleFonts.dmSans(
                    fontSize: 14,
                    color: Colors.grey.shade400,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _sendMessage,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _sending ? Colors.grey.shade300 : _primaryColor,
                shape: BoxShape.circle,
              ),
              child: _sending
                  ? const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                    )
                  : const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: _primaryColor.withAlpha(15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.forum_outlined, size: 40, color: _primaryColor),
          ),
          const SizedBox(height: 16),
          Text(
            'Select a conversation',
            style: GoogleFonts.dmSans(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose a homework thread to view\nfeedback and responses.',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              fontSize: 13,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoConversations() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 48,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 12),
          Text(
            widget.role == 'teacher'
                ? 'No feedback threads yet.\nTap + to start one.'
                : 'No messages from teachers yet.',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showNewConversationDialog() async {
    final convId = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => _NewFeedbackThreadInputPage(
          primaryColor: _primaryColor,
          onSubmit: _createConversation,
        ),
      ),
    );
    if (convId != null && mounted) {
      _openConversation(convId);
    }
  }

  Future<String> _createConversation({
    required String homeworkTitle,
    required String subject,
    required String className,
    required String parentName,
    required String studentName,
  }) async {
    final conv = await _service!.createConversation(
      homeworkId: 'hw_${DateTime.now().millisecondsSinceEpoch}',
      homeworkTitle: homeworkTitle,
      subject: subject,
      className: className,
      teacherId: widget.userId,
      teacherName: widget.userName,
      parentId: 'parent_${DateTime.now().millisecondsSinceEpoch}',
      parentName: parentName,
      studentName: studentName,
    );
    return conv['id'] as String;
  }

  String _formatTime(int timestamp) {
    if (timestamp == 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) {
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }
    if (diff.inDays == 1) return 'Yesterday';
    return '${dt.day}/${dt.month}';
  }

  Color _subjectColor(String subject) {
    switch (subject.toLowerCase()) {
      case 'mathematics':
      case 'maths':
        return const Color(0xFF1B4F72);
      case 'english':
        return const Color(0xFF6C3483);
      case 'science':
        return const Color(0xFF1A6B4A);
      case 'social studies':
      case 'social':
        return const Color(0xFFD4850A);
      case 'hindi':
        return const Color(0xFFB03A2E);
      default:
        return const Color(0xFF2E4057);
    }
  }
}

class _NewFeedbackThreadInputPage extends StatefulWidget {
  const _NewFeedbackThreadInputPage({
    required this.primaryColor,
    required this.onSubmit,
  });

  final Color primaryColor;
  final Future<String> Function({
    required String homeworkTitle,
    required String subject,
    required String className,
    required String parentName,
    required String studentName,
  })
  onSubmit;

  @override
  State<_NewFeedbackThreadInputPage> createState() =>
      _NewFeedbackThreadInputPageState();
}

class _NewFeedbackThreadInputPageState
    extends State<_NewFeedbackThreadInputPage> {
  final _formKey = GlobalKey<FormState>();
  final _homeworkCtrl = TextEditingController();
  final _subjectCtrl = TextEditingController();
  final _classCtrl = TextEditingController();
  final _studentCtrl = TextEditingController();
  final _parentCtrl = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _homeworkCtrl.dispose();
    _subjectCtrl.dispose();
    _classCtrl.dispose();
    _studentCtrl.dispose();
    _parentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final convId = await widget.onSubmit(
        homeworkTitle: _homeworkCtrl.text.trim(),
        subject: _subjectCtrl.text.trim(),
        className: _classCtrl.text.trim(),
        parentName: _parentCtrl.text.trim(),
        studentName: _studentCtrl.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context, convId);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Unable to create feedback thread: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Feedback Thread')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _field(
              _homeworkCtrl,
              'Homework Title',
              Icons.assignment_outlined,
              required: true,
            ),
            const SizedBox(height: 12),
            _field(
              _subjectCtrl,
              'Subject',
              Icons.book_outlined,
              required: true,
            ),
            const SizedBox(height: 12),
            _field(_classCtrl, 'Class (e.g. 10-A)', Icons.class_outlined),
            const SizedBox(height: 12),
            _field(_studentCtrl, 'Student Name', Icons.person_outlined),
            const SizedBox(height: 12),
            _field(_parentCtrl, 'Parent Name', Icons.family_restroom_outlined),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'This creates the thread through the existing messaging service. Backend persistence is limited to that service contract.',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: const Color(0xFF9A3412),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: GoogleFonts.dmSans(color: Colors.red, fontSize: 13),
              ),
            ],
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    bool required = false,
  }) {
    return TextFormField(
      controller: ctrl,
      enabled: !_saving,
      style: GoogleFonts.dmSans(fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.dmSans(fontSize: 13),
        prefixIcon: Icon(icon, size: 18, color: Colors.grey.shade500),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
      ),
      validator: required
          ? (value) => value == null || value.trim().isEmpty ? 'Required' : null
          : null,
    );
  }
}
