import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/widgets/admin_navigation.dart';
import 'package:schooldesk1/core/widgets/dashboard_fab_widget.dart';
import 'package:schooldesk1/core/widgets/erp_module_scaffold.dart';
import 'package:schooldesk1/core/utils/extensions.dart';
import 'package:schooldesk1/features/communication/presentation/widgets/chat_shared_widgets.dart';

class AdminCommunicationScreen extends StatefulWidget {
  const AdminCommunicationScreen({super.key});

  @override
  State<AdminCommunicationScreen> createState() =>
      _AdminCommunicationScreenState();
}

class _AdminCommunicationScreenState extends State<AdminCommunicationScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _searchController = TextEditingController();
  final _chatInputController = TextEditingController();

  bool _loading = true;
  String? _error;
  String _audienceFilter = 'All';
  String _statusFilter = 'All';

  List<Map<String, dynamic>> _notices = [];
  List<UserAccountModel> _chatTargets = [];
  List<Map<String, dynamic>> _directMessages = [];
  String? _selectedTargetId;
  bool _sendingChat = false;
  Timer? _pollingTimer;
  UserResponse? _profile;

  static const _audienceOptions = [
    'All',
    'Everyone',
    'Parents',
    'Teachers',
    'Students',
    'Admin',
    'Principal',
  ];

  static const _statusOptions = ['All', 'Normal', 'Urgent'];

  List<Map<String, dynamic>> get _templates => [
    {
      'name': 'Fee Reminder',
      'audience': 'Parents',
      'icon': Icons.account_balance_wallet_rounded,
      'color': context.appTheme.warning,
    },
    {
      'name': 'Holiday Notice',
      'audience': 'Everyone',
      'icon': Icons.beach_access_rounded,
      'color': context.appTheme.success,
    },
    {
      'name': 'Exam Notice',
      'audience': 'Students',
      'icon': Icons.quiz_rounded,
      'color': context.appTheme.primary,
    },
    {
      'name': 'Staff Meeting',
      'audience': 'Teachers',
      'icon': Icons.groups_rounded,
      'color': context.appTheme.secondary,
    },
    {
      'name': 'Principal Update',
      'audience': 'Principal',
      'icon': Icons.admin_panel_settings_rounded,
      'color': context.appTheme.info,
    },
    {
      'name': 'Emergency Alert',
      'audience': 'Everyone',
      'icon': Icons.warning_rounded,
      'color': context.appTheme.error,
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _searchController.addListener(() => setState(() {}));
    _loadData();
    _startPolling();
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted && !_sendingChat && !_loading) {
        _loadData(background: true);
      }
    });
  }

  Future<void> _loadData({bool background = false}) async {
    if (!background) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final api = BackendApiClient.instance;
      final stored = await api.getAnnouncements();
      stored.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));

      final profile = await api.getProfile();
      final directMessages = await api.getCommunications();
      final usersResponse = await api.getUsers(pageSize: 1000);
      final users = usersResponse.data
          .where((u) => u.isActive && u.id != profile.id)
          .toList();

      if (!mounted) return;
      setState(() {
        _profile = profile;
        _directMessages = directMessages;
        _chatTargets = users;
        _notices = stored
            .map(
              (notice) => {
                'id': notice.id,
                'title': notice.title,
                'body': notice.content,
                'audience': notice.targetAudience,
                'audienceLabel': _audienceLabel(notice.targetAudience),
                'date': notice.publishedAt,
                'dateLabel': _formatDate(notice.publishedAt),
                'status': 'Published',
                'urgent': notice.isUrgent,
                'publishedBy': notice.createdBy,
              },
            )
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (!background) {
          _error = 'Unable to load communication records: $e';
        }
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _tabController.dispose();
    _searchController.dispose();
    _chatInputController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredNotices {
    final query = _searchController.text.trim().toLowerCase();
    return _notices.where((notice) {
      final audience = _audienceLabel(_text(notice['audience']));
      final matchesAudience =
          _audienceFilter == 'All' || audience == _audienceFilter;
      final urgent = notice['urgent'] == true;
      final matchesStatus =
          _statusFilter == 'All' ||
          (_statusFilter == 'Urgent' && urgent) ||
          (_statusFilter == 'Normal' && !urgent);
      final haystack = [
        notice['title'],
        notice['body'],
        audience,
        notice['publishedBy'],
      ].map((value) => _text(value).toLowerCase()).join(' ');
      final matchesQuery = query.isEmpty || haystack.contains(query);
      return matchesAudience && matchesStatus && matchesQuery;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final drawer = AdminDrawer(selectedIndex: 7, onDestinationSelected: (_) {});
    return SchoolDeskModuleScaffold(
      title: 'Communication Management',
      subtitle: 'Publish role-wise notices and review delivery history',
      drawer: drawer,
      floatingActionButton: const DashboardFabWidget(role: DashboardRole.admin),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      actions: [
        IconButton(
          tooltip: 'Refresh communication',
          icon: const Icon(Icons.refresh_rounded),
          onPressed: _loadData,
        ),
        IconButton(
          tooltip: 'Compose notice',
          icon: const Icon(Icons.add_rounded),
          onPressed: () => _openComposePage(),
        ),
      ],
      bottom: TabBar(
        controller: _tabController,
        tabs: const [
          Tab(text: 'Notices'),
          Tab(text: 'Templates'),
          Tab(text: 'History'),
          Tab(text: 'Chats'),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return _emptyState(_error!, actionLabel: 'Retry', onAction: _loadData);
    }
    return TabBarView(
      controller: _tabController,
      children: [
        _buildNotices(),
        _buildTemplates(),
        _buildSentHistory(),
        _buildChatsTab(),
      ],
    );
  }

  Widget _buildNotices() {
    final filtered = _filteredNotices;
    return RefreshIndicator(
      onRefresh: _loadData,
      color: context.appTheme.primary,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _buildFilters(),
          const SizedBox(height: 12),
          if (filtered.isEmpty)
            SizedBox(
              height: 360,
              child: _emptyState('No notices match the selected filters.'),
            )
          else
            ...filtered.map(_noticeCard),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 680;
        final search = TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            labelText: 'Search notices',
            prefixIcon: Icon(Icons.search_rounded),
          ),
        );
        final audience = DropdownButtonFormField<String>(
          initialValue: _audienceFilter,
          decoration: const InputDecoration(labelText: 'Audience'),
          items: _audienceOptions
              .map(
                (value) => DropdownMenuItem(value: value, child: Text(value)),
              )
              .toList(),
          onChanged: (value) =>
              setState(() => _audienceFilter = value ?? _audienceFilter),
        );
        final status = DropdownButtonFormField<String>(
          initialValue: _statusFilter,
          decoration: const InputDecoration(labelText: 'Status'),
          items: _statusOptions
              .map(
                (value) => DropdownMenuItem(value: value, child: Text(value)),
              )
              .toList(),
          onChanged: (value) =>
              setState(() => _statusFilter = value ?? _statusFilter),
        );
        if (wide) {
          return Row(
            children: [
              Expanded(flex: 2, child: search),
              const SizedBox(width: 10),
              Expanded(child: audience),
              const SizedBox(width: 10),
              Expanded(child: status),
            ],
          );
        }
        return Column(
          children: [
            search,
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: audience),
                const SizedBox(width: 10),
                Expanded(child: status),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _noticeCard(Map<String, dynamic> notice) {
    final isUrgent = notice['urgent'] == true;
    final color = isUrgent ? context.appTheme.error : context.appTheme.success;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.appTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isUrgent
              ? context.appTheme.errorContainer
              : context.appTheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (isUrgent) _pill('URGENT', context.appTheme.error),
              if (isUrgent) const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _text(notice['title']),
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _pill(_text(notice['status'], fallback: 'Published'), color),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _meta(Icons.group_rounded, _text(notice['audienceLabel'])),
              _meta(Icons.schedule_rounded, _text(notice['dateLabel'])),
              if (_text(notice['publishedBy']).isNotEmpty)
                _meta(Icons.person_rounded, _text(notice['publishedBy'])),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _text(notice['body']),
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: context.appTheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: () => _deleteNotice(notice),
              icon: const Icon(Icons.delete_outline_rounded, size: 16),
              label: const Text('Delete'),
              style: OutlinedButton.styleFrom(
                foregroundColor: context.appTheme.error,
                side: BorderSide(color: context.appTheme.error),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplates() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final count = width >= 980
            ? 4
            : width >= 680
            ? 3
            : 2;
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: count,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: width < 420 ? 1.1 : 1.35,
          ),
          itemCount: _templates.length,
          itemBuilder: (_, i) {
            final template = _templates[i];
            final color = template['color'] as Color;
            return InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _openComposePage(
                templateName: _text(template['name']),
                audience: _text(template['audience'], fallback: 'Everyone'),
              ),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: color.withAlpha(15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withAlpha(60)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(template['icon'] as IconData, color: color, size: 30),
                    const SizedBox(height: 8),
                    Text(
                      _text(template['name']),
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _text(template['audience']),
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: context.appTheme.muted,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSentHistory() {
    final sent = _filteredNotices;
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _buildFilters(),
          const SizedBox(height: 12),
          if (sent.isEmpty)
            SizedBox(height: 360, child: _emptyState('No sent notices found.'))
          else
            ...sent.map(
              (notice) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.appTheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: context.appTheme.outlineVariant),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      color: context.appTheme.success,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _text(notice['title']),
                            style: GoogleFonts.dmSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${_text(notice['audienceLabel'])} · ${_text(notice['dateLabel'])}',
                            style: GoogleFonts.dmSans(
                              fontSize: 11,
                              color: context.appTheme.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _deleteNotice(Map<String, dynamic> notice) async {
    final id = _text(notice['id']);
    if (id.isEmpty) return;
    await BackendApiClient.instance.deleteRaw('/notices/$id');
    await _loadData();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Notice deleted'),
        backgroundColor: context.appTheme.success,
      ),
    );
  }

  Future<void> _openComposePage({
    String? templateName,
    String? audience,
  }) async {
    final sent = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _AdminComposeNoticePage(
          templateName: templateName,
          initialAudience: audience,
          onSubmit:
              ({
                required String title,
                required String body,
                required String audience,
                required bool isUrgent,
              }) async {
                await BackendApiClient.instance.createAnnouncement(
                  title: title,
                  content: body,
                  targetAudience: _audienceValue(audience),
                  isUrgent: isUrgent,
                );
              },
        ),
      ),
    );
    if (sent != true || !mounted) return;
    await _loadData();
  }

  Widget _pill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(22),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: GoogleFonts.dmSans(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _meta(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: context.appTheme.muted),
        const SizedBox(width: 3),
        Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 11,
            color: context.appTheme.muted,
          ),
        ),
      ],
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
            Icon(
              Icons.campaign_outlined,
              size: 44,
              color: context.appTheme.muted,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: context.appTheme.muted,
              ),
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

  String _audienceLabel(String value) {
    switch (_audienceValue(value)) {
      case 'parents':
        return 'Parents';
      case 'teachers':
        return 'Teachers';
      case 'students':
        return 'Students';
      case 'admin':
        return 'Admin';
      case 'principal':
        return 'Principal';
      default:
        return 'Everyone';
    }
  }

  String _audienceValue(String label) {
    switch (label.trim().toLowerCase()) {
      case 'parents':
      case 'all parents':
        return 'parents';
      case 'teachers':
      case 'all teachers':
      case 'staff':
        return 'teachers';
      case 'students':
        return 'students';
      case 'admin':
      case 'admins':
        return 'admin';
      case 'principal':
      case 'principals':
        return 'principal';
      default:
        return 'all';
    }
  }

  String _formatDate(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;
    final local = parsed.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
  }

  Widget _buildChatsTab() {
    if (_selectedTargetId != null) {
      return _buildActiveChatView();
    }
    return _buildChatThreadsList();
  }

  Widget _buildActiveChatView() {
    final counterpartId = _selectedTargetId!;
    final userById = {for (final u in _chatTargets) u.id: u};
    final counterpart = userById[counterpartId];
    if (counterpart == null) {
      return const Center(child: Text('User not found'));
    }

    // Find the thread messages
    final thread = _directThreads.firstWhere(
      (t) => t.counterpart.id == counterpartId,
      orElse: () => _AdminDirectThread(
        counterpart: counterpart,
        messages: [],
        currentUserId: _profile?.id ?? '',
      ),
    );

    // Mark messages as read
    for (final message in thread.messages) {
      final isRead =
          message['is_read'] == true ||
          message['is_read'] == 1 ||
          message['is_read']?.toString().toLowerCase() == 'true';
      if (message['receiver_id'] == _profile?.id &&
          !isRead &&
          message['id'] != null) {
        BackendApiClient.instance.markCommunicationRead(
          message['id'].toString(),
        );
      }
    }

    final displayLabel = counterpart.name.isNotEmpty
        ? counterpart.name
        : (counterpart.username.isNotEmpty ? counterpart.username : 'User');
    final roleLabel = counterpart.roleName.isNotEmpty
        ? counterpart.roleName
        : (counterpart.linkedType.isNotEmpty ? counterpart.linkedType : 'User');

    return Column(
      children: [
        // Chat sub-header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          color: context.appTheme.surface,
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => setState(() => _selectedTargetId = null),
              ),
              CircleAvatar(
                backgroundColor: context.appTheme.primary.withAlpha(20),
                child: Text(
                  _initials(displayLabel),
                  style: TextStyle(
                    color: context.appTheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayLabel,
                      style: GoogleFonts.ibmPlexSans(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      roleLabel,
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 11,
                        color: context.appTheme.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // Chat body
        Expanded(
          child: ChatWallpaperBackground(
            child: thread.messages.isEmpty
                ? Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: context.appTheme.surface.withAlpha(200),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'No messages yet. Send a message to start.',
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 13,
                          color: context.appTheme.muted,
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    itemCount: thread.messages.length,
                    itemBuilder: (_, index) {
                      final message = thread.messages[index];
                      final isMe = message['sender_id'] == _profile?.id;
                      final body =
                          (message['body'] ?? message['message_content'] ?? '')
                              .toString();
                      final timeStr = _messageTime(message);
                      final isRead =
                          message['is_read'] == true ||
                          message['is_read'] == 1 ||
                          message['is_read']?.toString().toLowerCase() ==
                              'true';

                      // Date separator check
                      final Widget? dateSep = _getDateSeparatorIfNeeded(
                        thread.messages,
                        index,
                      );

                      final bubble = ChatBubbleWidget(
                        messageText: body,
                        time: timeStr,
                        isMe: isMe,
                        isRead: isRead,
                      );

                      if (dateSep != null) {
                        return Column(children: [dateSep, bubble]);
                      }

                      return bubble;
                    },
                  ),
          ),
        ),
        // Input bar
        ChatInputBar(
          controller: _chatInputController,
          placeholder: 'Message $displayLabel...',
          isSending: _sendingChat,
          onSend: () => _sendAdminChatMessage(
            counterpartId,
            counterpart.roleName.isNotEmpty
                ? counterpart.roleName
                : (counterpart.linkedType.isNotEmpty
                      ? counterpart.linkedType
                      : 'parent'),
          ),
          onAttach: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Attachments not supported for this chat yet.'),
            ),
          ),
        ),
      ],
    );
  }

  Widget? _getDateSeparatorIfNeeded(
    List<Map<String, dynamic>> messages,
    int index,
  ) {
    final currentMsg = messages[index];
    final currentSentAt = DateTime.tryParse(
      currentMsg['sent_at']?.toString() ??
          currentMsg['created_at']?.toString() ??
          '',
    )?.toLocal();
    if (currentSentAt == null) return null;

    if (index == 0) {
      return ChatDateSeparator(dateText: _formatDateSeparator(currentSentAt));
    }

    final prevMsg = messages[index - 1];
    final prevSentAt = DateTime.tryParse(
      prevMsg['sent_at']?.toString() ?? prevMsg['created_at']?.toString() ?? '',
    )?.toLocal();
    if (prevSentAt == null) {
      return ChatDateSeparator(dateText: _formatDateSeparator(currentSentAt));
    }

    final currentDayStr = DateFormat('yyyy-MM-dd').format(currentSentAt);
    final prevDayStr = DateFormat('yyyy-MM-dd').format(prevSentAt);

    if (currentDayStr != prevDayStr) {
      return ChatDateSeparator(dateText: _formatDateSeparator(currentSentAt));
    }

    return null;
  }

  String _formatDateSeparator(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final checkDate = DateTime(date.year, date.month, date.day);
    if (checkDate == today) {
      return 'Today';
    } else if (checkDate == yesterday) {
      return 'Yesterday';
    } else {
      return DateFormat('MMMM dd, yyyy').format(date);
    }
  }

  Future<void> _sendAdminChatMessage(
    String receiverId,
    String receiverRole,
  ) async {
    final text = _chatInputController.text.trim();
    if (text.isEmpty) return;
    setState(() => _sendingChat = true);
    try {
      await BackendApiClient.instance.sendCommunication(
        receiverId: receiverId,
        receiverRole: receiverRole,
        messageContent: text,
      );
      _chatInputController.clear();
      await _loadData(background: true);
      if (!mounted) return;
      setState(() => _sendingChat = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _sendingChat = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send message: $e'),
          backgroundColor: context.appTheme.error,
        ),
      );
    }
  }

  String _messageTime(Map<String, dynamic> message) {
    final timeStr =
        message['sent_at']?.toString() ??
        message['created_at']?.toString() ??
        '';
    final dt = DateTime.tryParse(timeStr)?.toLocal();
    if (dt == null) return '';
    return DateFormat('h:mm a').format(dt);
  }

  Widget _buildChatThreadsList() {
    final threads = _directThreads;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // Search bar
        TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            labelText: 'Search chats or start new chat',
            prefixIcon: Icon(Icons.search_rounded),
          ),
        ),
        const SizedBox(height: 14),
        if (threads.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                'No conversations found.',
                style: GoogleFonts.ibmPlexSans(color: context.appTheme.muted),
              ),
            ),
          )
        else
          ...threads.map((thread) {
            final unread = thread.unreadCount;
            final hasUnread = unread > 0;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(
                  color: hasUnread
                      ? context.appTheme.primary.withAlpha(80)
                      : context.appTheme.outlineVariant,
                  width: hasUnread ? 1.5 : 1,
                ),
              ),
              child: ListTile(
                onTap: () =>
                    setState(() => _selectedTargetId = thread.counterpart.id),
                leading: CircleAvatar(
                  backgroundColor: context.appTheme.primary.withAlpha(20),
                  child: Text(
                    _initials(thread.label),
                    style: TextStyle(
                      color: context.appTheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        thread.label,
                        style: GoogleFonts.ibmPlexSans(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      _roleLabel(
                        thread.counterpart.roleName.isNotEmpty
                            ? thread.counterpart.roleName
                            : thread.counterpart.linkedType,
                      ),
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: _roleColor(
                          thread.counterpart.roleName.isNotEmpty
                              ? thread.counterpart.roleName
                              : thread.counterpart.linkedType,
                        ),
                      ),
                    ),
                  ],
                ),
                subtitle: Row(
                  children: [
                    Expanded(
                      child: Text(
                        thread.subtitle,
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 12,
                          color: hasUnread
                              ? context.appTheme.onSurface
                              : context.appTheme.muted,
                          fontWeight: hasUnread
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (thread.messages.isNotEmpty)
                      Text(
                        _shortDate(
                          DateTime.tryParse(
                            thread.messages.last['sent_at']?.toString() ?? '',
                          ),
                        ),
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 10,
                          color: context.appTheme.muted,
                        ),
                      ),
                  ],
                ),
                trailing: unread <= 0
                    ? null
                    : Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: context.appTheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$unread',
                          style: GoogleFonts.ibmPlexSans(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
              ),
            );
          }),
      ],
    );
  }

  List<_AdminDirectThread> get _directThreads {
    final grouped = <String, _AdminDirectThread>{};
    final userById = {for (final u in _chatTargets) u.id: u};
    final myId = _profile?.id ?? '';

    for (final message in _directMessages) {
      final senderId = message['sender_id']?.toString() ?? '';
      final receiverId = message['receiver_id']?.toString() ?? '';
      if (senderId.isEmpty || receiverId.isEmpty) continue;

      final counterpartId = (senderId == myId) ? receiverId : senderId;
      if (counterpartId == myId) continue;

      final counterpartUser = userById[counterpartId];
      if (counterpartUser == null) continue;

      final thread = grouped.putIfAbsent(
        counterpartId,
        () => _AdminDirectThread(
          counterpart: counterpartUser,
          messages: [],
          currentUserId: myId,
        ),
      );
      thread.messages.add(message);
    }

    final query = _searchController.text.trim().toLowerCase();
    for (final user in _chatTargets) {
      if (grouped.containsKey(user.id)) continue;

      final name = user.name.toLowerCase();
      final role = user.roleName.isNotEmpty
          ? user.roleName.toLowerCase()
          : user.linkedType.toLowerCase();
      final email = user.email.toLowerCase();
      if (query.isEmpty ||
          name.contains(query) ||
          role.contains(query) ||
          email.contains(query)) {
        grouped[user.id] = _AdminDirectThread(
          counterpart: user,
          messages: [],
          currentUserId: myId,
        );
      }
    }

    final threads = grouped.values.toList();
    for (final thread in threads) {
      thread.messages.sort((a, b) {
        final aTime =
            DateTime.tryParse(a['sent_at']?.toString() ?? '') ?? DateTime(1970);
        final bTime =
            DateTime.tryParse(b['sent_at']?.toString() ?? '') ?? DateTime(1970);
        return aTime.compareTo(bTime);
      });
    }

    threads.sort((a, b) {
      final aHas = a.messages.isNotEmpty;
      final bHas = b.messages.isNotEmpty;
      if (aHas != bHas) {
        return aHas ? -1 : 1;
      }
      if (aHas) {
        final aTime =
            DateTime.tryParse(a.messages.last['sent_at']?.toString() ?? '') ??
            DateTime(1970);
        final bTime =
            DateTime.tryParse(b.messages.last['sent_at']?.toString() ?? '') ??
            DateTime(1970);
        return bTime.compareTo(aTime);
      }
      final aName = a.counterpart.name;
      final bName = b.counterpart.name;
      return aName.compareTo(bName);
    });

    if (query.isNotEmpty) {
      return threads.where((thread) {
        final name = thread.counterpart.name.toLowerCase();
        final role = thread.counterpart.roleName.isNotEmpty
            ? thread.counterpart.roleName.toLowerCase()
            : thread.counterpart.linkedType.toLowerCase();
        final email = thread.counterpart.email.toLowerCase();
        final matches =
            name.contains(query) ||
            role.contains(query) ||
            email.contains(query);
        if (matches) return true;
        return thread.messages.any(
          (msg) =>
              (msg['body']?.toString() ??
                      msg['message_content']?.toString() ??
                      '')
                  .toLowerCase()
                  .contains(query),
        );
      }).toList();
    }

    return threads;
  }

  String _roleLabel(String role) {
    switch (role.toLowerCase()) {
      case 'parent':
        return 'Parent';
      case 'teacher':
        return 'Teacher';
      case 'principal':
        return 'Principal';
      case 'admin':
        return 'Admin';
      default:
        return role;
    }
  }

  Color _roleColor(String role) {
    switch (role.toLowerCase()) {
      case 'parent':
        return Colors.green;
      case 'teacher':
        return Colors.blue;
      case 'principal':
        return Colors.orange;
      case 'admin':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _shortDate(DateTime? value) {
    if (value == null) return '';
    final local = value.toLocal();
    final now = DateTime.now();
    if (local.year == now.year &&
        local.month == now.month &&
        local.day == now.day) {
      return DateFormat('h:mm a').format(local);
    }
    return DateFormat('dd MMM').format(local);
  }

  String _initials(String label) {
    final parts = label
        .split(RegExp(r'\s+'))
        .where((part) => part.trim().isNotEmpty)
        .take(2)
        .map((part) => part.trim()[0].toUpperCase())
        .join();
    return parts.isEmpty ? 'C' : parts;
  }

  String _text(dynamic value, {String fallback = ''}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty || text == 'null' ? fallback : text;
  }
}

class _AdminDirectThread {
  final UserAccountModel counterpart;
  final List<Map<String, dynamic>> messages;
  final String currentUserId;

  _AdminDirectThread({
    required this.counterpart,
    required this.messages,
    required this.currentUserId,
  });

  String get label {
    final name = counterpart.name.trim();
    if (name.isNotEmpty) return name;
    final username = counterpart.username.trim();
    if (username.isNotEmpty) return username;
    return 'User ${counterpart.id.substring(0, 8)}';
  }

  String get subtitle => messages.isEmpty
      ? 'Start conversation'
      : (messages.last['body'] ?? messages.last['message_content'] ?? '')
            .toString();

  int get unreadCount {
    return messages.where((msg) {
      final isRead =
          msg['is_read'] == true ||
          msg['is_read'] == 1 ||
          msg['is_read']?.toString().toLowerCase() == 'true';
      return msg['receiver_id'] == currentUserId && !isRead;
    }).length;
  }
}

class _AdminComposeNoticePage extends StatefulWidget {
  const _AdminComposeNoticePage({
    required this.onSubmit,
    this.templateName,
    this.initialAudience,
  });

  final String? templateName;
  final String? initialAudience;
  final Future<void> Function({
    required String title,
    required String body,
    required String audience,
    required bool isUrgent,
  })
  onSubmit;

  @override
  State<_AdminComposeNoticePage> createState() =>
      _AdminComposeNoticePageState();
}

class _AdminComposeNoticePageState extends State<_AdminComposeNoticePage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  final _bodyCtrl = TextEditingController();
  late String _audience;
  bool _isUrgent = false;
  bool _saving = false;
  String? _error;

  static const _audiences = [
    'Everyone',
    'Parents',
    'Teachers',
    'Students',
    'Admin',
    'Principal',
  ];

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(
      text: widget.templateName != null ? '${widget.templateName}: ' : '',
    );
    _audience = _audiences.contains(widget.initialAudience)
        ? widget.initialAudience!
        : 'Everyone';
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSubmit(
        title: _titleCtrl.text.trim(),
        body: _bodyCtrl.text.trim(),
        audience: _audience,
        isUrgent: _isUrgent,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Notice published'),
          backgroundColor: context.appTheme.success,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Notice publish failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Compose Notice')),
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
                controller: _bodyCtrl,
                enabled: !_saving,
                maxLines: 5,
                decoration: const InputDecoration(labelText: 'Message body'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Message body is required'
                    : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _audience,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Audience'),
                items: _audiences
                    .map(
                      (value) =>
                          DropdownMenuItem(value: value, child: Text(value)),
                    )
                    .toList(),
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _audience = value ?? _audience),
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _isUrgent,
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _isUrgent = value ?? false),
                title: Text(
                  'Mark as urgent',
                  style: GoogleFonts.dmSans(fontSize: 13),
                ),
              ),
              if (_error != null) ...[
                SizedBox(height: 16),
                Text(_error!, style: TextStyle(color: context.appTheme.error)),
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
