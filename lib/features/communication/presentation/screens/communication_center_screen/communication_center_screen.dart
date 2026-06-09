import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/theme/app_theme.dart';
import 'package:schooldesk1/core/widgets/app_navigation.dart';
import 'package:schooldesk1/core/widgets/dashboard_fab_widget.dart';
import 'package:schooldesk1/core/widgets/erp_module_scaffold.dart';

class CommunicationCenterScreen extends StatefulWidget {
  const CommunicationCenterScreen({super.key});

  @override
  State<CommunicationCenterScreen> createState() =>
      _CommunicationCenterScreenState();
}

class _CommunicationCenterScreenState extends State<CommunicationCenterScreen>
    with SingleTickerProviderStateMixin {
  int _selectedDrawerIndex = 8;
  late TabController _tabController;
  List<Map<String, dynamic>> _circulars = [];
  List<Map<String, dynamic>> _notices = [];
  List<Map<String, dynamic>> _alerts = [];
  List<Map<String, dynamic>> _messages = [];
  List<UserAccountModel> _messageRecipients = [];
  UserResponse? _profile;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final api = BackendApiClient.instance;
      final rows = await api.getAnnouncements();
      final notices = await api.getRawList('/notices');
      final alerts = await api.getNotifications();
      final profile = await api.getProfile();
      final messages = await api.getCommunications();
      final teachers = await api.getUsers(
        role: 'Teacher',
        status: 'active',
        pageSize: 500,
      );
      final parents = await api.getUsers(
        role: 'Parent',
        status: 'active',
        pageSize: 500,
      );
      final recipients =
          [
              ...teachers.data,
              ...parents.data,
            ].where((user) => user.isActive && user.id != profile.id).toList()
            ..sort((a, b) => _userLabel(a).compareTo(_userLabel(b)));
      messages.sort((a, b) => _messageTime(b).compareTo(_messageTime(a)));
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _circulars = rows
            .map(
              (a) => {
                'id': a.id,
                'title': a.title,
                'type': 'Circular',
                'audience': a.targetAudience,
                'date': a.publishedAt.split('T').first,
                'status': 'published',
                'urgent': a.isUrgent,
                'content': a.content,
              },
            )
            .toList();
        _notices = notices;
        _alerts = alerts;
        _messages = messages;
        _messageRecipients = recipients;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _createCircular(Map<String, dynamic> circular) async {
    await BackendApiClient.instance.createAnnouncement(
      title: (circular['title'] ?? '').toString(),
      content: (circular['content'] ?? '').toString(),
      targetAudience: (circular['audience'] ?? 'all').toString(),
      isUrgent: circular['urgent'] == true,
    );
    await _loadData();
  }

  String _noticeTitle(Map<String, dynamic> notice) {
    return '${notice['title'] ?? 'Notice'}';
  }

  String _noticeType(Map<String, dynamic> notice) {
    final explicit = '${notice['type'] ?? ''}'.trim();
    if (explicit.isNotEmpty) return explicit;
    final haystack =
        '${notice['title'] ?? ''} ${notice['content'] ?? ''} ${notice['target_audience'] ?? ''}'
            .toLowerCase();
    if (haystack.contains('holiday')) return 'Holiday';
    if (haystack.contains('health')) return 'Health';
    if (haystack.contains('discipline')) return 'Discipline';
    if (haystack.contains('transport')) return 'Transport';
    if (haystack.contains('academic') ||
        haystack.contains('exam') ||
        haystack.contains('homework')) {
      return 'Academic';
    }
    return 'General';
  }

  String _noticeDate(Map<String, dynamic> notice) {
    return '${notice['published_at'] ?? notice['created_at'] ?? notice['date'] ?? ''}'
        .split('T')
        .first;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final drawer = PrincipalDrawer(
      selectedIndex: _selectedDrawerIndex,
      onDestinationSelected: (i) => setState(() => _selectedDrawerIndex = i),
    );
    if (_loading) {
      return SchoolDeskModuleScaffold(
        title: 'Communication Center',
        subtitle: 'Create circulars, review notices, and monitor urgent alerts',
        drawer: drawer,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return SchoolDeskModuleScaffold(
        title: 'Communication Center',
        subtitle: 'Create circulars, review notices, and monitor urgent alerts',
        drawer: drawer,
        body: Center(child: Text(_error!)),
      );
    }
    return SchoolDeskModuleScaffold(
      title: 'Communication Center',
      subtitle: 'Create circulars, review notices, and monitor urgent alerts',
      drawer: drawer,
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const DashboardFabWidget(role: DashboardRole.principal),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            onPressed: () => _showCreateCircularSheet(),
            icon: const Icon(Icons.add_rounded),
            label: const Text('New Circular'),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      bottom: TabBar(
        controller: _tabController,
        tabs: const [
          Tab(text: 'Circulars'),
          Tab(text: 'Notice Board'),
          Tab(text: 'Alerts'),
          Tab(text: 'Messages'),
        ],
      ),
      body: MediaQuery.of(context).size.width >= 840
          ? _buildTabletLayout(context)
          : _buildPhoneLayout(context),
    );
  }

  Widget _buildPhoneLayout(BuildContext context) {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildCircularsTab(),
        _buildNoticeBoardTab(),
        _buildAlertsTab(),
        _buildMessagesTab(),
      ],
    );
  }

  Widget _buildTabletLayout(BuildContext context) {
    return _buildPhoneLayout(context);
  }

  Widget _buildCircularsTab() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _circulars.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _buildCircularCard(_circulars[i]),
    );
  }

  Widget _buildCircularCard(Map<String, dynamic> c) {
    final isUrgent = c['urgent'] as bool;
    final isDraft = c['status'] == 'draft';

    Color typeColor;
    switch (c['type']) {
      case 'Urgent Alert':
        typeColor = AppTheme.error;
        break;
      case 'Academic':
        typeColor = AppTheme.info;
        break;
      case 'Meeting':
        typeColor = AppTheme.secondary;
        break;
      case 'Finance':
        typeColor = AppTheme.warning;
        break;
      default:
        typeColor = AppTheme.muted;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isUrgent ? AppTheme.errorContainer : AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUrgent
              ? AppTheme.error.withAlpha(100)
              : AppTheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: typeColor.withAlpha(20),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  c['type'],
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: typeColor,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              if (isDraft)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'DRAFT',
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.muted,
                    ),
                  ),
                ),
              const Spacer(),
              Text(
                c['date'],
                style: GoogleFonts.dmSans(fontSize: 11, color: AppTheme.muted),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            c['title'],
            style: GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isUrgent ? AppTheme.error : AppTheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'To: ${c['audience']}',
            style: GoogleFonts.dmSans(fontSize: 12, color: AppTheme.muted),
          ),
          const SizedBox(height: 8),
          Text(
            c['content'],
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: AppTheme.onSurfaceVariant,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (isDraft)
                TextButton.icon(
                  onPressed: () async {
                    await _createCircular(c);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Circular published through backend'),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.send_rounded, size: 14),
                  label: const Text('Publish'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.success,
                  ),
                )
              else
                Row(
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 14,
                      color: AppTheme.success,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Published',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: AppTheme.success,
                      ),
                    ),
                  ],
                ),
              const Spacer(),
              IconButton(
                onPressed: () => _showCircularDetail(c),
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                color: AppTheme.muted,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNoticeBoardTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Notice Board',
              style: GoogleFonts.dmSans(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextButton.icon(
              onPressed: () => _showAddNoticeDialog(),
              icon: const Icon(Icons.add_rounded, size: 14),
              label: const Text('Add Notice'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_notices.isEmpty)
          Text(
            'No notices available from backend.',
            style: GoogleFonts.dmSans(fontSize: 12, color: AppTheme.muted),
          )
        else
          ..._notices.asMap().entries.map(
            (e) => _buildNoticeItem(e.value, e.key),
          ),
      ],
    );
  }

  Widget _buildNoticeItem(Map<String, dynamic> n, int index) {
    final noticeType = _noticeType(n);
    Color typeColor;
    switch (noticeType) {
      case 'Holiday':
        typeColor = AppTheme.secondary;
        break;
      case 'Academic':
        typeColor = AppTheme.info;
        break;
      case 'Health':
        typeColor = AppTheme.success;
        break;
      case 'Discipline':
        typeColor = AppTheme.error;
        break;
      default:
        typeColor = AppTheme.muted;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: typeColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _noticeTitle(n),
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: typeColor.withAlpha(20),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        noticeType,
                        style: GoogleFonts.dmSans(
                          fontSize: 10,
                          color: typeColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _noticeDate(n),
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: AppTheme.muted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(
              Icons.more_vert_rounded,
              size: 16,
              color: AppTheme.muted,
            ),
            onSelected: (v) {
              if (v == 'delete') {
                _deleteNotice(n);
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'delete',
                child: Text('Remove Notice'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAddNoticeDialog() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _NoticeEditorPage(onSubmit: _addNotice),
      ),
    );
  }

  Widget _buildAlertsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Backend Alerts',
          style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        if (_alerts.isEmpty)
          Text(
            'Backend notification records will appear here.',
            style: GoogleFonts.dmSans(fontSize: 12, color: AppTheme.muted),
          )
        else
          ..._alerts.map(
            (alert) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildScheduledAlert(
                '${alert['title'] ?? alert['type'] ?? 'Alert'}',
                '${alert['body'] ?? alert['message'] ?? alert['content'] ?? ''}',
                '${alert['created_at'] ?? alert['scheduled_at'] ?? ''}'
                    .split('T')
                    .first,
                Icons.notifications_active_outlined,
                alert['is_urgent'] == true ? AppTheme.error : AppTheme.info,
              ),
            ),
          ),
        const SizedBox(height: 20),
        Text(
          'Send Urgent Alert Now',
          style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.errorContainer,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.error.withAlpha(60)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: AppTheme.error,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Emergency / Urgent Broadcast',
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.error,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Use this to send an immediate alert to all parents and staff.',
                style: GoogleFonts.dmSans(fontSize: 12, color: AppTheme.muted),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showUrgentAlertDialog(),
                  icon: const Icon(Icons.send_rounded, size: 16),
                  label: const Text('Send Urgent Alert'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.error,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMessagesTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Direct Messages',
                style: GoogleFonts.dmSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: _messageRecipients.isEmpty
                  ? null
                  : () => _openMessageComposer(),
              icon: const Icon(Icons.edit_square, size: 16),
              label: const Text('New Message'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_messageRecipients.isEmpty)
          Text(
            'No active Teacher or Parent user accounts are available for one-to-one messages.',
            style: GoogleFonts.dmSans(fontSize: 12, color: AppTheme.muted),
          ),
        const SizedBox(height: 12),
        if (_messages.isEmpty)
          Text(
            'No direct messages available from backend.',
            style: GoogleFonts.dmSans(fontSize: 12, color: AppTheme.muted),
          )
        else
          ..._messages.map(
            (message) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildMessageCard(message),
            ),
          ),
      ],
    );
  }

  Widget _buildMessageCard(Map<String, dynamic> message) {
    final incoming = _isIncomingMessage(message);
    final unread = incoming && !_messageRead(message);
    final counterpart = _messageCounterpart(message);
    final replyRecipient = _messageRecipient(message);
    final role = _messageCounterpartRole(message);
    final content =
        '${message['message_content'] ?? message['message'] ?? message['body'] ?? ''}'
            .trim();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: unread ? AppTheme.infoContainer : AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: unread ? AppTheme.info.withAlpha(70) : AppTheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                incoming
                    ? Icons.call_received_rounded
                    : Icons.call_made_rounded,
                size: 16,
                color: incoming ? AppTheme.info : AppTheme.success,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${incoming ? 'From' : 'To'} $counterpart',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                role,
                style: GoogleFonts.dmSans(fontSize: 11, color: AppTheme.muted),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content.isEmpty ? 'Message' : content,
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: AppTheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                _messageDate(message),
                style: GoogleFonts.dmSans(fontSize: 11, color: AppTheme.muted),
              ),
              const Spacer(),
              if (unread)
                TextButton.icon(
                  onPressed: () => _markDirectMessageRead(message),
                  icon: const Icon(Icons.done_all_rounded, size: 14),
                  label: const Text('Mark Read'),
                ),
              TextButton.icon(
                onPressed: replyRecipient == null
                    ? null
                    : () => _openMessageComposer(
                        initialRecipient: replyRecipient,
                      ),
                icon: const Icon(Icons.reply_rounded, size: 14),
                label: const Text('Reply'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openMessageComposer({
    UserAccountModel? initialRecipient,
  }) async {
    if (_messageRecipients.isEmpty) return;
    final sent = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _PrincipalMessagePage(
          recipients: _messageRecipients,
          initialRecipient: initialRecipient,
          onSubmit: _sendDirectMessage,
        ),
      ),
    );
    if (sent == true) {
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Direct message sent')));
    }
  }

  Future<void> _sendDirectMessage(
    UserAccountModel recipient,
    String content,
  ) async {
    await BackendApiClient.instance.sendCommunication(
      receiverId: recipient.id,
      receiverRole: _userRole(recipient),
      messageContent: content,
    );
  }

  Future<void> _markDirectMessageRead(Map<String, dynamic> message) async {
    final id = '${message['id'] ?? message['message_id'] ?? ''}'.trim();
    if (id.isEmpty) return;
    await BackendApiClient.instance.markCommunicationRead(id);
    await _loadData();
  }

  bool _isIncomingMessage(Map<String, dynamic> message) {
    return '${message['receiver_id'] ?? ''}' == _profile?.id;
  }

  bool _messageRead(Map<String, dynamic> message) {
    final value = message['is_read'];
    if (value is bool) return value;
    if (value is num) return value != 0;
    return '${value ?? ''}'.toLowerCase() == 'true';
  }

  String _messageCounterpart(Map<String, dynamic> message) {
    final recipient = _messageRecipient(message);
    if (recipient != null) return _userLabel(recipient);
    final id = _isIncomingMessage(message)
        ? '${message['sender_id'] ?? ''}'
        : '${message['receiver_id'] ?? ''}';
    return id.trim().isEmpty ? 'User' : id;
  }

  String _messageCounterpartRole(Map<String, dynamic> message) {
    final role = _isIncomingMessage(message)
        ? '${message['sender_role'] ?? ''}'
        : '${message['receiver_role'] ?? ''}';
    final cleanRole = role.trim();
    if (cleanRole.isEmpty) return 'User';
    return cleanRole[0].toUpperCase() + cleanRole.substring(1).toLowerCase();
  }

  UserAccountModel? _messageRecipient(Map<String, dynamic> message) {
    final id = _isIncomingMessage(message)
        ? '${message['sender_id'] ?? ''}'
        : '${message['receiver_id'] ?? ''}';
    for (final user in _messageRecipients) {
      if (user.id == id) return user;
    }
    return null;
  }

  DateTime _messageTime(Map<String, dynamic> message) {
    return DateTime.tryParse(
          '${message['sent_at'] ?? message['created_at'] ?? ''}',
        ) ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _messageDate(Map<String, dynamic> message) {
    final value = _messageTime(message);
    if (value.millisecondsSinceEpoch == 0) return '';
    return DateFormat('d MMM yyyy, h:mm a').format(value.toLocal());
  }

  static String _userRole(UserAccountModel user) {
    final role = user.roleName.trim();
    return role.isEmpty ? user.linkedType.trim().toLowerCase() : role;
  }

  static String _userLabel(UserAccountModel user) {
    final name = user.name.trim();
    if (name.isNotEmpty) return name;
    final username = user.username.trim();
    if (username.isNotEmpty) return username;
    final email = user.email.trim();
    return email.isEmpty ? user.id : email;
  }

  Future<bool> _addNotice(String title, String type) async {
    try {
      await BackendApiClient.instance.createRaw('/notices', {
        'title': title,
        'content': '$type: $title',
        'target_audience': 'all',
        'is_urgent': type == 'Discipline',
        'is_active': true,
      });
      await _loadData();
      if (!mounted) return true;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Notice saved to board')));
      return true;
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Notice save failed: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
      return false;
    }
  }

  Future<void> _deleteNotice(Map<String, dynamic> notice) async {
    final id = '${notice['id'] ?? ''}';
    if (id.isEmpty) return;
    try {
      await BackendApiClient.instance.deleteRaw('/notices/$id');
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Notice removed')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Notice remove failed: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  Widget _buildScheduledAlert(
    String title,
    String desc,
    String date,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withAlpha(25),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  desc,
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: AppTheme.muted,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                date,
                style: GoogleFonts.dmSans(fontSize: 11, color: AppTheme.muted),
              ),
              const Icon(
                Icons.schedule_rounded,
                size: 14,
                color: AppTheme.muted,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showCircularDetail(Map<String, dynamic> c) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (_, ctrl) => SingleChildScrollView(
          controller: ctrl,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.outline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                c['type'],
                style: GoogleFonts.dmSans(fontSize: 12, color: AppTheme.muted),
              ),
              Text(
                c['title'],
                style: GoogleFonts.dmSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'To: ${c['audience']} · ${c['date']}',
                style: GoogleFonts.dmSans(fontSize: 13, color: AppTheme.muted),
              ),
              const SizedBox(height: 16),
              Text(
                c['content'],
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  color: AppTheme.onSurfaceVariant,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateCircularSheet() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _CircularEditorPage(
          circularCount: _circulars.length,
          onSubmit: _createCircular,
        ),
      ),
    );
  }

  void _showUrgentAlertDialog() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _UrgentAlertPage(onSubmit: _sendUrgentAlert),
      ),
    );
  }

  Future<bool> _sendUrgentAlert(String message) async {
    try {
      await BackendApiClient.instance.createAnnouncement(
        title: 'Urgent Alert',
        content: message,
        targetAudience: 'all',
        isUrgent: true,
      );
      await _loadData();
      if (!mounted) return true;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Urgent alert sent to all parents and staff'),
        ),
      );
      return true;
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Urgent alert failed: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
      return false;
    }
  }
}

class _NoticeEditorPage extends StatefulWidget {
  const _NoticeEditorPage({required this.onSubmit});

  final Future<bool> Function(String title, String type) onSubmit;

  @override
  State<_NoticeEditorPage> createState() => _NoticeEditorPageState();
}

class _NoticeEditorPageState extends State<_NoticeEditorPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  String _type = 'General';
  bool _saving = false;
  String? _error;

  static const _types = [
    'General',
    'Academic',
    'Holiday',
    'Health',
    'Discipline',
    'Transport',
  ];

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final saved = await widget.onSubmit(_titleCtrl.text.trim(), _type);
    if (!mounted) return;
    if (saved) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _saving = false;
      _error =
          'Notice was not saved. Please check the backend error and retry.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Notice')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              TextFormField(
                controller: _titleCtrl,
                enabled: !_saving,
                decoration: const InputDecoration(labelText: 'Notice Title'),
                textInputAction: TextInputAction.done,
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Notice title is required'
                    : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'Type'),
                items: _types
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _type = value ?? _type),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: const TextStyle(color: AppTheme.error)),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _saving ? null : _submit,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_rounded),
                label: Text(_saving ? 'Saving...' : 'Add Notice'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CircularEditorPage extends StatefulWidget {
  const _CircularEditorPage({
    required this.circularCount,
    required this.onSubmit,
  });

  final int circularCount;
  final Future<void> Function(Map<String, dynamic> circular) onSubmit;

  @override
  State<_CircularEditorPage> createState() => _CircularEditorPageState();
}

class _CircularEditorPageState extends State<_CircularEditorPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  String _type = 'Announcement';
  String _audience = 'All';
  bool _urgent = false;
  bool _saving = false;
  String? _error;

  static const _types = [
    'Announcement',
    'Academic',
    'Meeting',
    'Finance',
    'Urgent Alert',
    'General',
  ];

  static const _audiences = [
    'All',
    'All Students & Parents',
    'All Parents',
    'All Students',
    'All Staff',
    'Classes 1-5',
    'Classes 6-10',
  ];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final newCircular = {
      'id': 'ci${widget.circularCount + 1}',
      'title': _titleCtrl.text.trim(),
      'type': _type,
      'audience': _audience,
      'date': DateFormat('d MMM yyyy').format(DateTime.now()),
      'status': 'published',
      'urgent': _urgent,
      'content': _contentCtrl.text.trim(),
    };
    try {
      await widget.onSubmit(newCircular);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Circular published through backend')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Circular publish failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Circular')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              TextFormField(
                controller: _titleCtrl,
                enabled: !_saving,
                decoration: const InputDecoration(labelText: 'Title'),
                textInputAction: TextInputAction.next,
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Title is required'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _contentCtrl,
                enabled: !_saving,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Content / Message',
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Message is required'
                    : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'Type'),
                items: _types
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _type = value ?? _type),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _audience,
                decoration: const InputDecoration(labelText: 'Audience'),
                items: _audiences
                    .map((a) => DropdownMenuItem(value: a, child: Text(a)))
                    .toList(),
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _audience = value ?? _audience),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _urgent,
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _urgent = value),
                title: Text(
                  'Mark as Urgent',
                  style: GoogleFonts.dmSans(fontSize: 13),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: const TextStyle(color: AppTheme.error)),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _saving ? null : _submit,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(_saving ? 'Publishing...' : 'Publish Now'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UrgentAlertPage extends StatefulWidget {
  const _UrgentAlertPage({required this.onSubmit});

  final Future<bool> Function(String message) onSubmit;

  @override
  State<_UrgentAlertPage> createState() => _UrgentAlertPageState();
}

class _PrincipalMessagePage extends StatefulWidget {
  const _PrincipalMessagePage({
    required this.recipients,
    required this.onSubmit,
    this.initialRecipient,
  });

  final List<UserAccountModel> recipients;
  final UserAccountModel? initialRecipient;
  final Future<void> Function(UserAccountModel recipient, String content)
  onSubmit;

  @override
  State<_PrincipalMessagePage> createState() => _PrincipalMessagePageState();
}

class _PrincipalMessagePageState extends State<_PrincipalMessagePage> {
  final _formKey = GlobalKey<FormState>();
  final _messageCtrl = TextEditingController();
  UserAccountModel? _recipient;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _recipient =
        widget.initialRecipient ??
        (widget.recipients.isEmpty ? null : widget.recipients.first);
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _recipient == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSubmit(_recipient!, _messageCtrl.text.trim());
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Message send failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Direct Message')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              DropdownButtonFormField<UserAccountModel>(
                initialValue: _recipient,
                decoration: const InputDecoration(
                  labelText: 'Recipient',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
                items: widget.recipients
                    .map(
                      (user) => DropdownMenuItem<UserAccountModel>(
                        value: user,
                        child: Text(
                          _recipientLabel(user),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _recipient = value),
                validator: (value) =>
                    value == null ? 'Recipient is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _messageCtrl,
                enabled: !_saving,
                maxLines: 6,
                minLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Message',
                  prefixIcon: Icon(Icons.message_outlined),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Message is required'
                    : null,
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: const TextStyle(color: AppTheme.error)),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _saving ? null : _submit,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(_saving ? 'Sending...' : 'Send Message'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _recipientLabel(UserAccountModel user) {
    final name = user.name.trim().isNotEmpty
        ? user.name.trim()
        : user.username.trim().isNotEmpty
        ? user.username.trim()
        : user.email.trim().isNotEmpty
        ? user.email.trim()
        : user.id;
    final role = user.roleName.trim().isEmpty ? 'User' : user.roleName.trim();
    return '$name - $role';
  }
}

class _UrgentAlertPageState extends State<_UrgentAlertPage> {
  final _formKey = GlobalKey<FormState>();
  final _messageCtrl = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final saved = await widget.onSubmit(_messageCtrl.text.trim());
    if (!mounted) return;
    if (saved) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _saving = false;
      _error =
          'Urgent alert was not sent. Please retry after checking backend.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Send Urgent Alert')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'This will send an immediate notification to all parents and staff.',
                style: GoogleFonts.dmSans(fontSize: 13, color: AppTheme.muted),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _messageCtrl,
                enabled: !_saving,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Alert Message',
                  hintText: 'e.g. School closed tomorrow due to...',
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Alert message is required'
                    : null,
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: const TextStyle(color: AppTheme.error)),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
                onPressed: _saving ? null : _submit,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(_saving ? 'Sending...' : 'Send Alert'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
