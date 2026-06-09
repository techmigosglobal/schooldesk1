import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/services/notification_service.dart';
import 'package:schooldesk1/core/theme/app_theme.dart';
import 'package:schooldesk1/core/widgets/app_navigation.dart';

enum _PrincipalCommunicationView {
  home,
  allChats,
  teacherChats,
  teacherMonitor,
  parentThread,
  teacherDirect,
  announcements,
  composeAnnouncement,
  reports,
  settings,
}

enum _ConversationFilter { all, teachers, parents, groups, unread }

class PrincipalChatCommunicationsScreen extends StatefulWidget {
  const PrincipalChatCommunicationsScreen({super.key});

  @override
  State<PrincipalChatCommunicationsScreen> createState() =>
      _PrincipalChatCommunicationsScreenState();
}

class _PrincipalChatCommunicationsScreenState
    extends State<PrincipalChatCommunicationsScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _messageController = TextEditingController();
  final _announcementTitleController = TextEditingController();
  final _announcementBodyController = TextEditingController();

  bool _loading = true;
  bool _sending = false;
  bool _monitorTeacherChats = true;
  bool _monitorGroupChats = true;
  bool _realTimeAlerts = true;
  String? _error;
  String _query = '';
  String _announcementTarget = 'all';
  _ConversationFilter _filter = _ConversationFilter.all;
  _PrincipalCommunicationView _view = _PrincipalCommunicationView.home;

  UserResponse? _profile;
  NotificationService? _notificationService;
  List<UserAccountModel> _teachers = const [];
  List<UserAccountModel> _parents = const [];
  List<_ParentChatThread> _parentThreads = const [];
  List<_TeacherDirectThread> _teacherThreads = const [];
  List<AnnouncementModel> _announcements = const [];
  _ParentChatThread? _selectedParentThread;
  _TeacherDirectThread? _selectedTeacherThread;
  UserAccountModel? _selectedTeacher;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _announcementTitleController.dispose();
    _announcementBodyController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = BackendApiClient.instance;
      final profile = await api.getProfile();
      final conversations = await api.getRawList('/message-conversations');
      final messages = await api.getRawList('/messages');
      final directMessages = await api.getCommunications();
      final announcements = await api.getAnnouncements();
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
      final notificationService = await NotificationService.getInstance();
      final students = await _loadOptional(
        request: api.getStudents(status: 'active', pageSize: 1000),
        fallback: const PaginatedList<StudentModel>(
          data: [],
          total: 0,
          page: 1,
          pageSize: 1000,
        ),
      );
      final sections = await _loadOptional(
        request: api.getSections(),
        fallback: <SectionModel>[],
      );

      final teacherById = <String, UserAccountModel>{};
      final teacherByLinkedId = <String, UserAccountModel>{};
      for (final teacher in teachers.data.where((user) => user.isActive)) {
        teacherById[teacher.id] = teacher;
        if (teacher.linkedId.trim().isNotEmpty) {
          teacherByLinkedId[teacher.linkedId.trim()] = teacher;
        }
      }

      final parentById = <String, UserAccountModel>{};
      final parentByLinkedId = <String, UserAccountModel>{};
      for (final parent in parents.data.where((user) => user.isActive)) {
        parentById[parent.id] = parent;
        if (parent.linkedId.trim().isNotEmpty) {
          parentByLinkedId[parent.linkedId.trim()] = parent;
        }
      }

      final studentById = {
        for (final student in students.data) student.id: student,
      };
      final sectionById = {for (final section in sections) section.id: section};

      final parentThreads =
          conversations
              .map(
                (row) => _ParentChatThread.fromApi(
                  row,
                  messageRows: messages,
                  principalId: profile.id,
                  teacherById: teacherById,
                  teacherByLinkedId: teacherByLinkedId,
                  parentById: parentById,
                  parentByLinkedId: parentByLinkedId,
                  studentById: studentById,
                  sectionById: sectionById,
                ),
              )
              .where((thread) => thread.id.isNotEmpty)
              .toList()
            ..sort((a, b) => b.lastTimeSort.compareTo(a.lastTimeSort));

      final teacherThreads = _buildTeacherThreads(
        teachers: teachers.data.where((user) => user.isActive).toList(),
        directRows: directMessages,
        principalId: profile.id,
      );

      if (!mounted) return;
      setState(() {
        _profile = profile;
        _notificationService = notificationService;
        _monitorTeacherChats = notificationService.getSetting(
          'principal_monitor_teacher_chats',
        );
        _monitorGroupChats = notificationService.getSetting(
          'principal_monitor_group_chats',
        );
        _realTimeAlerts = notificationService.getSetting(
          'principal_realtime_chat_alerts',
        );
        _teachers = teachers.data.where((user) => user.isActive).toList()
          ..sort((a, b) => _userLabel(a).compareTo(_userLabel(b)));
        _parents = parents.data.where((user) => user.isActive).toList()
          ..sort((a, b) => _userLabel(a).compareTo(_userLabel(b)));
        _parentThreads = parentThreads;
        _teacherThreads = teacherThreads;
        _announcements = announcements
          ..sort(
            (a, b) => _announcementDate(b).compareTo(_announcementDate(a)),
          );
        _selectedParentThread = _reselectParentThread(parentThreads);
        _selectedTeacherThread = _reselectTeacherThread(teacherThreads);
        _selectedTeacher = _reselectTeacher(_teachers);
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

  Future<T> _loadOptional<T>({
    required Future<T> request,
    required T fallback,
  }) async {
    try {
      return await request;
    } catch (_) {
      return fallback;
    }
  }

  List<_TeacherDirectThread> _buildTeacherThreads({
    required List<UserAccountModel> teachers,
    required List<Map<String, dynamic>> directRows,
    required String principalId,
  }) {
    final teachersById = {for (final teacher in teachers) teacher.id: teacher};
    final rowsByTeacherId = <String, List<_DirectMessage>>{};

    for (final row in directRows) {
      final message = _DirectMessage.fromApi(row);
      final teacherId = _teacherCounterpartId(message, teachersById.keys);
      if (teacherId.isEmpty) continue;
      rowsByTeacherId.putIfAbsent(teacherId, () => []).add(message);
    }

    final threads = <_TeacherDirectThread>[];
    for (final teacher in teachers) {
      final rows = rowsByTeacherId[teacher.id] ?? <_DirectMessage>[];
      rows.sort((a, b) => a.timeSort.compareTo(b.timeSort));
      threads.add(
        _TeacherDirectThread(
          teacher: teacher,
          principalId: principalId,
          messages: rows,
        ),
      );
    }

    threads.sort((a, b) {
      final aHasMessages = a.messages.isNotEmpty;
      final bHasMessages = b.messages.isNotEmpty;
      if (aHasMessages != bHasMessages) return aHasMessages ? -1 : 1;
      if (aHasMessages) return b.lastTimeSort.compareTo(a.lastTimeSort);
      return a.teacherLabel.compareTo(b.teacherLabel);
    });
    return threads;
  }

  String _teacherCounterpartId(
    _DirectMessage message,
    Iterable<String> teacherIds,
  ) {
    final teacherIdSet = teacherIds.toSet();
    if (_role(message.senderRole) == 'teacher') return message.senderId;
    if (_role(message.receiverRole) == 'teacher') return message.receiverId;
    if (teacherIdSet.contains(message.senderId)) return message.senderId;
    if (teacherIdSet.contains(message.receiverId)) return message.receiverId;
    return '';
  }

  _ParentChatThread? _reselectParentThread(List<_ParentChatThread> rows) {
    final selectedId = _selectedParentThread?.id ?? '';
    if (selectedId.isEmpty) return _selectedParentThread;
    for (final row in rows) {
      if (row.id == selectedId) return row;
    }
    return rows.isEmpty ? null : rows.first;
  }

  _TeacherDirectThread? _reselectTeacherThread(
    List<_TeacherDirectThread> rows,
  ) {
    final selectedId = _selectedTeacherThread?.teacher.id ?? '';
    if (selectedId.isEmpty) return _selectedTeacherThread;
    for (final row in rows) {
      if (row.teacher.id == selectedId) return row;
    }
    return rows.isEmpty ? null : rows.first;
  }

  UserAccountModel? _reselectTeacher(List<UserAccountModel> rows) {
    final selectedId = _selectedTeacher?.id ?? '';
    if (selectedId.isEmpty) return _selectedTeacher;
    for (final row in rows) {
      if (row.id == selectedId) return row;
    }
    return rows.isEmpty ? null : rows.first;
  }

  List<_ChatListItem> get _allChatItems {
    final rows = <_ChatListItem>[
      for (final thread in _teacherThreads)
        if (thread.messages.isNotEmpty)
          _ChatListItem.teacherDirect(thread)
        else if (_filter == _ConversationFilter.teachers)
          _ChatListItem.teacherDirect(thread),
      for (final thread in _parentThreads) _ChatListItem.parentThread(thread),
    ]..sort((a, b) => b.timeSort.compareTo(a.timeSort));

    final query = _query.trim().toLowerCase();
    return rows.where((row) {
      final matchesFilter = switch (_filter) {
        _ConversationFilter.all => true,
        _ConversationFilter.teachers => row.kind == _ChatListKind.teacher,
        _ConversationFilter.parents =>
          row.kind == _ChatListKind.parent && !row.isGroup,
        _ConversationFilter.groups =>
          row.kind == _ChatListKind.parent && row.isGroup,
        _ConversationFilter.unread => row.unreadCount > 0,
      };
      if (!matchesFilter) return false;
      return query.isEmpty || row.searchText.contains(query);
    }).toList();
  }

  List<UserAccountModel> get _visibleTeachers {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return _teachers;
    return _teachers.where((teacher) {
      return [
        teacher.name,
        teacher.username,
        teacher.email,
        teacher.phone,
      ].join(' ').toLowerCase().contains(query);
    }).toList();
  }

  List<_ParentChatThread> get _visibleTeacherParentThreads {
    final teacher = _selectedTeacher;
    if (teacher == null) return const [];
    final query = _query.trim().toLowerCase();
    return _parentThreads.where((thread) {
      final teacherMatch =
          thread.teacherUser?.id == teacher.id ||
          thread.teacherId == teacher.id ||
          thread.teacherId == teacher.linkedId;
      if (!teacherMatch) return false;
      return query.isEmpty || thread.searchText.contains(query);
    }).toList();
  }

  List<AnnouncementModel> get _visibleAnnouncements {
    final query = _query.trim().toLowerCase();
    return _announcements.where((announcement) {
      if (query.isEmpty) return true;
      return [
        announcement.title,
        announcement.content,
        announcement.targetAudience,
      ].join(' ').toLowerCase().contains(query);
    }).toList();
  }

  int get _totalUnread =>
      _parentThreads.fold<int>(0, (sum, row) => sum + row.unreadCount) +
      _teacherThreads.fold<int>(0, (sum, row) => sum + row.unreadCount);

  int get _todayMessages {
    final today = DateTime.now();
    bool sameDay(DateTime? date) {
      if (date == null) return false;
      final local = date.toLocal();
      return local.year == today.year &&
          local.month == today.month &&
          local.day == today.day;
    }

    final parentCount = _parentThreads.fold<int>(
      0,
      (sum, thread) =>
          sum + thread.messages.where((m) => sameDay(m.sentAt)).length,
    );
    final directCount = _teacherThreads.fold<int>(
      0,
      (sum, thread) =>
          sum + thread.messages.where((m) => sameDay(m.sentAt)).length,
    );
    return parentCount + directCount;
  }

  int get _totalMessages =>
      _parentThreads.fold<int>(0, (sum, row) => sum + row.messages.length) +
      _teacherThreads.fold<int>(0, (sum, row) => sum + row.messages.length);

  bool get _showMessageComposer =>
      _view == _PrincipalCommunicationView.parentThread ||
      _view == _PrincipalCommunicationView.teacherDirect;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF6FAFE),
      drawer: PrincipalDrawer(selectedIndex: 18, onDestinationSelected: (_) {}),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_showMessageComposer) _buildMessageComposer(),
          const PrincipalShellBottomBar(),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFF0B72F0),
          onRefresh: _loadData,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader()),
              if (_loading)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildErrorState(),
                )
              else
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    8,
                    16,
                    _showMessageComposer ? 18 : 92,
                  ),
                  sliver: SliverToBoxAdapter(child: _buildActiveView()),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final title = switch (_view) {
      _PrincipalCommunicationView.home => 'Communication',
      _PrincipalCommunicationView.allChats => 'All Chats',
      _PrincipalCommunicationView.teacherChats => 'Teacher Chats',
      _PrincipalCommunicationView.teacherMonitor =>
        'Chat with $_selectedTeacherName',
      _PrincipalCommunicationView.parentThread =>
        _selectedParentThread?.title ?? 'Group Chat',
      _PrincipalCommunicationView.teacherDirect =>
        _selectedTeacherThread?.teacherLabel ?? 'Teacher Chat',
      _PrincipalCommunicationView.announcements => 'Announcements',
      _PrincipalCommunicationView.composeAnnouncement => 'New Announcement',
      _PrincipalCommunicationView.reports => 'Message Reports',
      _PrincipalCommunicationView.settings => 'Communication Settings',
    };
    final subtitle = switch (_view) {
      _PrincipalCommunicationView.home =>
        'Stay connected with your school community',
      _PrincipalCommunicationView.allChats => 'All conversations',
      _PrincipalCommunicationView.teacherChats =>
        'Monitor teacher to parent chats',
      _PrincipalCommunicationView.teacherMonitor => _selectedTeacherClassLabel,
      _PrincipalCommunicationView.parentThread =>
        _selectedParentThread?.classLabel ?? 'Monitored conversation',
      _PrincipalCommunicationView.teacherDirect =>
        'Direct principal to teacher messages',
      _PrincipalCommunicationView.announcements =>
        'School-wide and class announcements',
      _PrincipalCommunicationView.composeAnnouncement =>
        'Send to school or specific classes',
      _PrincipalCommunicationView.reports => 'Monitor all conversations',
      _PrincipalCommunicationView.settings =>
        'Manage communication preferences',
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
      child: Row(
        children: [
          IconButton(
            tooltip: _view == _PrincipalCommunicationView.home
                ? 'Menu'
                : 'Back',
            icon: Icon(
              _view == _PrincipalCommunicationView.home
                  ? Icons.menu_rounded
                  : Icons.arrow_back_rounded,
            ),
            onPressed: _view == _PrincipalCommunicationView.home
                ? () => _scaffoldKey.currentState?.openDrawer()
                : _goBack,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF0F2133),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF667789),
                  ),
                ),
              ],
            ),
          ),
          if (_view == _PrincipalCommunicationView.composeAnnouncement)
            const SizedBox(width: 48)
          else
            IconButton.filledTonal(
              tooltip: _view == _PrincipalCommunicationView.settings
                  ? 'Export reports'
                  : 'Filter',
              onPressed: _view == _PrincipalCommunicationView.settings
                  ? _exportReports
                  : _openFilterSheet,
              icon: Icon(
                _view == _PrincipalCommunicationView.settings
                    ? Icons.file_download_outlined
                    : Icons.filter_alt_outlined,
                size: 20,
              ),
            ),
          PopupMenuButton<_PrincipalCommunicationView>(
            tooltip: 'Communication menu',
            onSelected: _openView,
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: _PrincipalCommunicationView.allChats,
                child: Text('All Chats'),
              ),
              PopupMenuItem(
                value: _PrincipalCommunicationView.teacherChats,
                child: Text('Teacher Chats'),
              ),
              PopupMenuItem(
                value: _PrincipalCommunicationView.announcements,
                child: Text('Announcements'),
              ),
              PopupMenuItem(
                value: _PrincipalCommunicationView.reports,
                child: Text('Message Reports'),
              ),
              PopupMenuItem(
                value: _PrincipalCommunicationView.settings,
                child: Text('Settings'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActiveView() {
    return switch (_view) {
      _PrincipalCommunicationView.home => _buildHomeView(),
      _PrincipalCommunicationView.allChats => _buildAllChatsView(),
      _PrincipalCommunicationView.teacherChats => _buildTeacherChatsView(),
      _PrincipalCommunicationView.teacherMonitor => _buildTeacherMonitorView(),
      _PrincipalCommunicationView.parentThread => _buildParentThreadView(),
      _PrincipalCommunicationView.teacherDirect => _buildTeacherDirectView(),
      _PrincipalCommunicationView.announcements => _buildAnnouncementsView(),
      _PrincipalCommunicationView.composeAnnouncement =>
        _buildComposeAnnouncementView(),
      _PrincipalCommunicationView.reports => _buildReportsView(),
      _PrincipalCommunicationView.settings => _buildSettingsView(),
    };
  }

  Widget _buildHomeView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildMetricGrid(),
        const SizedBox(height: 18),
        _sectionTitle('Quick Actions'),
        const SizedBox(height: 10),
        _QuickActionTile(
          icon: Icons.chat_bubble_outline_rounded,
          iconColor: const Color(0xFF0B72F0),
          title: 'All Chats',
          subtitle: 'View all conversations',
          onTap: () => _openView(_PrincipalCommunicationView.allChats),
        ),
        _QuickActionTile(
          icon: Icons.person_pin_outlined,
          iconColor: const Color(0xFF7C3AED),
          title: 'Teacher Chats',
          subtitle: 'View teacher to parent chats',
          onTap: () => _openView(_PrincipalCommunicationView.teacherChats),
        ),
        _QuickActionTile(
          icon: Icons.campaign_outlined,
          iconColor: const Color(0xFF16A34A),
          title: 'Announcements',
          subtitle: 'Send school-wide announcements',
          onTap: () => _openView(_PrincipalCommunicationView.announcements),
        ),
        _QuickActionTile(
          icon: Icons.groups_2_outlined,
          iconColor: const Color(0xFFF59E0B),
          title: 'Groups',
          subtitle: 'View and manage groups',
          onTap: () {
            setState(() {
              _filter = _ConversationFilter.groups;
              _view = _PrincipalCommunicationView.allChats;
            });
          },
        ),
        _QuickActionTile(
          icon: Icons.summarize_outlined,
          iconColor: const Color(0xFF3157F6),
          title: 'Message Reports',
          subtitle: 'Monitor all conversations',
          onTap: () => _openView(_PrincipalCommunicationView.reports),
        ),
        _QuickActionTile(
          icon: Icons.settings_outlined,
          iconColor: const Color(0xFF64748B),
          title: 'Communication Settings',
          subtitle: 'Manage monitoring preferences',
          onTap: () => _openView(_PrincipalCommunicationView.settings),
        ),
      ],
    );
  }

  Widget _buildMetricGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.9,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      children: [
        _MetricCard(
          icon: Icons.chat_bubble_outline_rounded,
          label: 'Total Chats',
          value: '${_parentThreads.length + _teacherThreads.length}',
          color: const Color(0xFF0B72F0),
        ),
        _MetricCard(
          icon: Icons.mark_email_unread_outlined,
          label: 'Unread Messages',
          value: '$_totalUnread',
          color: const Color(0xFF16A34A),
        ),
        _MetricCard(
          icon: Icons.co_present_outlined,
          label: 'Teachers',
          value: '${_teachers.length}',
          color: const Color(0xFF3157F6),
        ),
        _MetricCard(
          icon: Icons.family_restroom_outlined,
          label: 'Parents/Guardians',
          value: '${_parents.length}',
          color: const Color(0xFFF97316),
        ),
        _MetricCard(
          icon: Icons.campaign_outlined,
          label: 'Announcements',
          value: '${_announcements.length}',
          color: const Color(0xFFF59E0B),
        ),
        _MetricCard(
          icon: Icons.groups_2_outlined,
          label: 'Groups',
          value: '${_parentThreads.where((row) => row.isGroup).length}',
          color: const Color(0xFF2563EB),
        ),
      ],
    );
  }

  Widget _buildAllChatsView() {
    final rows = _allChatItems;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSearchBox('Search chats'),
        const SizedBox(height: 12),
        _buildConversationFilterChips(),
        const SizedBox(height: 14),
        if (rows.isEmpty)
          _emptyPanel('No conversations found', Icons.forum_outlined)
        else
          for (final row in rows)
            _ConversationTile(
              avatarLabel: row.initials,
              title: row.title,
              subtitle: row.subtitle,
              timeLabel: row.timeLabel,
              unreadCount: row.unreadCount,
              icon: row.kind == _ChatListKind.teacher
                  ? Icons.person_pin_outlined
                  : Icons.groups_2_outlined,
              onTap: () => _openChatItem(row),
            ),
      ],
    );
  }

  Widget _buildTeacherChatsView() {
    final teachers = _visibleTeachers;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSearchBox('Search teacher'),
        const SizedBox(height: 14),
        if (teachers.isEmpty)
          _emptyPanel('No teachers found', Icons.co_present_outlined)
        else
          for (final teacher in teachers)
            _TeacherMonitorTile(
              teacher: teacher,
              activeChats: _threadsForTeacher(teacher).length,
              unread: _threadsForTeacher(
                teacher,
              ).fold<int>(0, (sum, row) => sum + row.unreadCount),
              onTap: () {
                setState(() {
                  _selectedTeacher = teacher;
                  _query = '';
                  _view = _PrincipalCommunicationView.teacherMonitor;
                });
              },
            ),
      ],
    );
  }

  Widget _buildTeacherMonitorView() {
    final rows = _visibleTeacherParentThreads;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSegmentedTabs(const ['All', 'Parents', 'Groups']),
        const SizedBox(height: 12),
        _buildSearchBox('Search in conversation'),
        const SizedBox(height: 14),
        if (rows.isEmpty)
          _emptyPanel('No parent chats for this teacher', Icons.forum_outlined)
        else
          for (final thread in rows)
            _ConversationTile(
              avatarLabel: _initials(thread.parentLabel),
              title: thread.parentLabel,
              subtitle: thread.lastMessage,
              timeLabel: thread.lastTimeLabel,
              unreadCount: thread.unreadCount,
              icon: Icons.family_restroom_outlined,
              onTap: () => _openParentThread(thread),
            ),
      ],
    );
  }

  Widget _buildParentThreadView() {
    final thread = _selectedParentThread;
    if (thread == null) {
      return _emptyPanel('Conversation not selected', Icons.forum_outlined);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (thread.isGroup)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: _softDecoration(color: const Color(0xFFFFF8E1)),
            child: Row(
              children: [
                const Icon(Icons.visibility_outlined, color: Color(0xFFE49A00)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'This group is monitored by you',
                    style: _textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF7A5600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (thread.messages.isEmpty)
          _emptyPanel('No messages in this conversation', Icons.chat_outlined)
        else
          for (final message in thread.messages)
            _MessageBubble(
              title: message.senderLabel,
              body: message.body,
              timeLabel: _timeLabel(message.sentAt),
              mine: _role(message.senderRole) == 'principal',
              unread: !message.isRead,
              onMarkRead: !message.isRead && message.id.isNotEmpty
                  ? () => _markParentMessageRead(message)
                  : null,
            ),
      ],
    );
  }

  Widget _buildTeacherDirectView() {
    final thread = _selectedTeacherThread;
    if (thread == null) {
      return _emptyPanel(
        'Teacher chat not selected',
        Icons.person_pin_outlined,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _softPanel(
          child: Row(
            children: [
              _avatar(_initials(thread.teacherLabel)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      thread.teacherLabel,
                      style: _textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      thread.teacher.email.isEmpty
                          ? 'Teacher account'
                          : thread.teacher.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _textTheme.labelSmall?.copyWith(
                        color: const Color(0xFF667789),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusPill(
                label: '${thread.messages.length} messages',
                color: const Color(0xFF0B72F0),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (thread.messages.isEmpty)
          _emptyPanel('No internal messages yet', Icons.mail_outline_rounded)
        else
          for (final message in thread.messages)
            _MessageBubble(
              title: message.senderLabel,
              body: message.body,
              timeLabel: _timeLabel(message.sentAt),
              mine: !message.isIncomingToPrincipal,
              unread: message.isIncomingToPrincipal && !message.isRead,
              onMarkRead:
                  message.isIncomingToPrincipal &&
                      !message.isRead &&
                      message.id.isNotEmpty
                  ? () => _markDirectMessageRead(message)
                  : null,
            ),
      ],
    );
  }

  Widget _buildAnnouncementsView() {
    final rows = _visibleAnnouncements;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSearchBox('Search announcements'),
        const SizedBox(height: 12),
        _buildSegmentedTabs(const ['All', 'School', 'Class', 'Important']),
        const SizedBox(height: 14),
        if (rows.isEmpty)
          _emptyPanel('No announcements found', Icons.campaign_outlined)
        else
          for (final announcement in rows)
            _AnnouncementTile(announcement: announcement),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: () =>
              _openView(_PrincipalCommunicationView.composeAnnouncement),
          icon: const Icon(Icons.add_rounded),
          label: const Text('New Announcement'),
        ),
      ],
    );
  }

  Widget _buildComposeAnnouncementView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _InputLabel('Title'),
        TextField(
          controller: _announcementTitleController,
          enabled: !_sending,
          decoration: const InputDecoration(hintText: 'Annual Sports Day'),
        ),
        const SizedBox(height: 14),
        _InputLabel('Send To'),
        DropdownButtonFormField<String>(
          value: _announcementTarget,
          decoration: const InputDecoration(),
          items: const [
            DropdownMenuItem(
              value: 'all',
              child: Text('All Students & Parents'),
            ),
            DropdownMenuItem(value: 'students', child: Text('All Students')),
            DropdownMenuItem(value: 'parents', child: Text('All Parents')),
            DropdownMenuItem(value: 'teachers', child: Text('All Teachers')),
          ],
          onChanged: _sending
              ? null
              : (value) => setState(() {
                  _announcementTarget = value ?? _announcementTarget;
                }),
        ),
        const SizedBox(height: 14),
        _InputLabel('Message'),
        TextField(
          controller: _announcementBodyController,
          enabled: !_sending,
          minLines: 7,
          maxLines: 10,
          decoration: const InputDecoration(
            hintText: 'Dear Parents & Students,',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: _sending
              ? null
              : () => _showSnackBar(
                  'Attachment upload is not available in the current backend.',
                ),
          icon: const Icon(Icons.upload_file_rounded),
          label: const Text('Add Attachment'),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _sending ? null : _sendAnnouncement,
          icon: _sending
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send_rounded),
          label: Text(_sending ? 'Sending...' : 'Send Announcement'),
        ),
      ],
    );
  }

  Widget _buildReportsView() {
    final recent = _recentActivities.take(6).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSegmentedTabs(const [
          'Overview',
          'Teachers',
          'Parents',
          'Groups',
        ]),
        const SizedBox(height: 16),
        _sectionTitle('Summary'),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.85,
          children: [
            _MetricCard(
              icon: Icons.chat_bubble_outline_rounded,
              label: 'Total Messages',
              value: '$_totalMessages',
              color: const Color(0xFF0B72F0),
            ),
            _MetricCard(
              icon: Icons.today_outlined,
              label: "Today's Messages",
              value: '$_todayMessages',
              color: const Color(0xFF16A34A),
            ),
            _MetricCard(
              icon: Icons.co_present_outlined,
              label: 'Teachers Active',
              value:
                  '${_teacherThreads.where((t) => t.messages.isNotEmpty).length}',
              color: const Color(0xFF16A34A),
            ),
            _MetricCard(
              icon: Icons.family_restroom_outlined,
              label: 'Parents Engaged',
              value:
                  '${_parentThreads.map((t) => t.parentLabel).toSet().length}',
              color: const Color(0xFFF97316),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _sectionTitle('Recent Activity'),
        const SizedBox(height: 10),
        if (recent.isEmpty)
          _emptyPanel('No recent activity', Icons.history_rounded)
        else
          _softPanel(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final row in recent)
                  _SimpleListRow(
                    icon: Icons.person_outline_rounded,
                    title: row.title,
                    trailing: row.timeLabel,
                  ),
              ],
            ),
          ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: _exportReports,
          icon: const Icon(Icons.file_download_outlined),
          label: const Text('Export Chat Reports'),
        ),
      ],
    );
  }

  Widget _buildSettingsView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle('Monitoring Settings'),
        const SizedBox(height: 10),
        _softPanel(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _SettingsSwitchRow(
                icon: Icons.chat_bubble_outline_rounded,
                title: 'Monitor all teacher chats',
                subtitle: 'View all teacher to parent conversations',
                value: _monitorTeacherChats,
                onChanged: (value) =>
                    _updateSetting('principal_monitor_teacher_chats', value),
              ),
              _SettingsSwitchRow(
                icon: Icons.groups_2_outlined,
                title: 'Monitor group chats',
                subtitle: 'View all group conversations',
                value: _monitorGroupChats,
                onChanged: (value) =>
                    _updateSetting('principal_monitor_group_chats', value),
              ),
              _SettingsSwitchRow(
                icon: Icons.notifications_active_outlined,
                title: 'Real-time notifications',
                subtitle: 'Get notified for new messages',
                value: _realTimeAlerts,
                onChanged: (value) =>
                    _updateSetting('principal_realtime_chat_alerts', value),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _sectionTitle('Notification Preferences'),
        const SizedBox(height: 10),
        _softPanel(
          padding: EdgeInsets.zero,
          child: Column(
            children: const [
              _SimpleListRow(
                icon: Icons.person_pin_outlined,
                title: 'Teacher Messages',
                trailing: 'All messages',
              ),
              _SimpleListRow(
                icon: Icons.groups_2_outlined,
                title: 'Group Messages',
                trailing: 'All messages',
              ),
              _SimpleListRow(
                icon: Icons.campaign_outlined,
                title: 'Announcements',
                trailing: 'Important only',
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _sectionTitle('Data & Privacy'),
        const SizedBox(height: 10),
        _softPanel(
          padding: EdgeInsets.zero,
          child: _SimpleListRow(
            icon: Icons.file_download_outlined,
            title: 'Export Chat Reports',
            trailing: 'Download',
            onTap: _exportReports,
          ),
        ),
      ],
    );
  }

  Widget _buildMessageComposer() {
    return SafeArea(
      top: false,
      bottom: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFDDE7F0))),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                minLines: 1,
                maxLines: 4,
                enabled: !_sending,
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  isDense: true,
                  suffixIcon: IconButton(
                    tooltip: 'Attach',
                    onPressed: _sending
                        ? null
                        : () => _showSnackBar(
                            'Attachments are not available for this backend chat yet.',
                          ),
                    icon: const Icon(Icons.attach_file_rounded, size: 18),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              tooltip: 'Send message',
              onPressed: _sending ? null : _sendActiveMessage,
              icon: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded, size: 20),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConversationFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _filterChip('All', _ConversationFilter.all),
          _filterChip('Teachers', _ConversationFilter.teachers),
          _filterChip('Parents', _ConversationFilter.parents),
          _filterChip('Groups', _ConversationFilter.groups),
          _filterChip('Unread', _ConversationFilter.unread),
        ],
      ),
    );
  }

  Widget _filterChip(String label, _ConversationFilter value) {
    final selected = _filter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _filter = value),
        showCheckmark: false,
        selectedColor: const Color(0xFF0B72F0),
        labelStyle: _textTheme.labelSmall?.copyWith(
          color: selected ? Colors.white : const Color(0xFF334155),
          fontWeight: FontWeight.w900,
        ),
        side: BorderSide(
          color: selected ? const Color(0xFF0B72F0) : const Color(0xFFDDE7F0),
        ),
      ),
    );
  }

  Widget _buildSegmentedTabs(List<String> labels) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(labels[i]),
                selected: i == 0,
                onSelected: (_) {},
                showCheckmark: false,
                selectedColor: const Color(0xFF0B72F0),
                labelStyle: _textTheme.labelSmall?.copyWith(
                  color: i == 0 ? Colors.white : const Color(0xFF334155),
                  fontWeight: FontWeight.w900,
                ),
                side: BorderSide(
                  color: i == 0
                      ? const Color(0xFF0B72F0)
                      : const Color(0xFFDDE7F0),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchBox(String hint) {
    return TextField(
      onChanged: (value) => setState(() => _query = value),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search_rounded),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: _softPanel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                size: 44,
                color: AppTheme.error,
              ),
              const SizedBox(height: 12),
              Text(
                'Communication unavailable',
                style: _textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error ?? 'Unable to load communication data.',
                textAlign: TextAlign.center,
                style: _textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF667789),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyPanel(String title, IconData icon) {
    return _softPanel(
      child: Column(
        children: [
          Icon(icon, size: 42, color: const Color(0xFF94A3B8)),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: _textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: const Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Backend conversations will appear here after messages are available.',
            textAlign: TextAlign.center,
            style: _textTheme.labelSmall?.copyWith(
              color: const Color(0xFF667789),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: _textTheme.titleSmall?.copyWith(
        color: const Color(0xFF0F2133),
        fontWeight: FontWeight.w900,
      ),
    );
  }

  Widget _softPanel({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(14),
  }) {
    return Container(
      padding: padding,
      decoration: _softDecoration(),
      child: child,
    );
  }

  BoxDecoration _softDecoration({Color color = Colors.white}) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: const Color(0xFFDDE7F0)),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF7FA6BD).withAlpha(28),
          blurRadius: 14,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  Widget _avatar(String label, {Color color = const Color(0xFF0B72F0)}) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: color.withAlpha(24),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          label,
          style: _textTheme.labelMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  void _openView(_PrincipalCommunicationView view) {
    setState(() {
      _view = view;
      _query = '';
      _messageController.clear();
    });
  }

  void _openChatItem(_ChatListItem row) {
    if (row.teacherThread != null) {
      _openTeacherDirect(row.teacherThread!);
    } else if (row.parentThread != null) {
      _openParentThread(row.parentThread!);
    }
  }

  void _openTeacherDirect(_TeacherDirectThread thread) {
    setState(() {
      _selectedTeacherThread = thread;
      _view = _PrincipalCommunicationView.teacherDirect;
      _messageController.clear();
    });
  }

  void _openParentThread(_ParentChatThread thread) {
    setState(() {
      _selectedParentThread = thread;
      _view = _PrincipalCommunicationView.parentThread;
      _messageController.clear();
    });
  }

  void _goBack() {
    setState(() {
      _query = '';
      _messageController.clear();
      _view = switch (_view) {
        _PrincipalCommunicationView.teacherMonitor =>
          _PrincipalCommunicationView.teacherChats,
        _PrincipalCommunicationView.parentThread =>
          _selectedTeacher == null
              ? _PrincipalCommunicationView.allChats
              : _PrincipalCommunicationView.teacherMonitor,
        _PrincipalCommunicationView.teacherDirect =>
          _PrincipalCommunicationView.allChats,
        _PrincipalCommunicationView.composeAnnouncement =>
          _PrincipalCommunicationView.announcements,
        _PrincipalCommunicationView.home => _PrincipalCommunicationView.home,
        _ => _PrincipalCommunicationView.home,
      };
    });
  }

  List<_ParentChatThread> _threadsForTeacher(UserAccountModel teacher) {
    return _parentThreads.where((thread) {
      return thread.teacherUser?.id == teacher.id ||
          thread.teacherId == teacher.id ||
          (teacher.linkedId.isNotEmpty && thread.teacherId == teacher.linkedId);
    }).toList();
  }

  Future<void> _sendActiveMessage() async {
    if (_view == _PrincipalCommunicationView.parentThread) {
      await _sendParentThreadMessage();
    } else if (_view == _PrincipalCommunicationView.teacherDirect) {
      await _sendDirectTeacherMessage();
    }
  }

  Future<void> _sendParentThreadMessage() async {
    final thread = _selectedParentThread;
    final profile = _profile;
    final text = _messageController.text.trim();
    if (thread == null || profile == null || text.isEmpty) return;
    setState(() => _sending = true);
    try {
      await BackendApiClient.instance.createRaw('/messages', {
        'conversation_id': thread.id,
        'sender_id': profile.id,
        'sender_role': 'Principal',
        'sender_name': _text(profile.name, fallback: 'Principal'),
        'body': text,
        'message': text,
        'is_read': false,
        'sent_at': DateTime.now().toUtc().toIso8601String(),
      });
      _messageController.clear();
      await _loadData();
      if (!mounted) return;
      setState(() => _sending = false);
    } catch (error) {
      if (!mounted) return;
      setState(() => _sending = false);
      _showSnackBar('Unable to send message: $error');
    }
  }

  Future<void> _sendDirectTeacherMessage() async {
    final thread = _selectedTeacherThread;
    final text = _messageController.text.trim();
    if (thread == null || text.isEmpty) return;
    setState(() => _sending = true);
    try {
      await BackendApiClient.instance.sendCommunication(
        receiverId: thread.teacher.id,
        receiverRole: 'teacher',
        priority: 'medium',
        messageContent: text,
      );
      _messageController.clear();
      await _loadData();
      if (!mounted) return;
      setState(() => _sending = false);
    } catch (error) {
      if (!mounted) return;
      setState(() => _sending = false);
      _showSnackBar('Unable to send message: $error');
    }
  }

  Future<void> _markParentMessageRead(_ChatMessage message) async {
    await BackendApiClient.instance.updateRaw('/messages/${message.id}', {
      'is_read': true,
      'read_at': DateTime.now().toUtc().toIso8601String(),
    });
    await _loadData();
  }

  Future<void> _markDirectMessageRead(_DirectMessage message) async {
    await BackendApiClient.instance.markCommunicationRead(message.id);
    await _loadData();
  }

  Future<void> _sendAnnouncement() async {
    final title = _announcementTitleController.text.trim();
    final body = _announcementBodyController.text.trim();
    if (title.isEmpty || body.isEmpty) {
      _showSnackBar('Title and message are required.');
      return;
    }
    setState(() => _sending = true);
    try {
      await BackendApiClient.instance.createAnnouncement(
        title: title,
        content: body,
        targetAudience: _announcementTarget,
        isUrgent: _announcementTarget == 'teachers',
      );
      _announcementTitleController.clear();
      _announcementBodyController.clear();
      await _loadData();
      if (!mounted) return;
      setState(() {
        _sending = false;
        _view = _PrincipalCommunicationView.announcements;
      });
      _showSnackBar('Announcement sent.');
    } catch (error) {
      if (!mounted) return;
      setState(() => _sending = false);
      _showSnackBar('Unable to send announcement: $error');
    }
  }

  Future<void> _exportReports() async {
    try {
      await BackendApiClient.instance.createReportExport(
        '/reports/exports',
        reportTitle: 'Communication monitoring report',
        reportType: 'communication_monitoring',
        format: 'pdf',
        parameters: {
          'total_messages': _totalMessages,
          'today_messages': _todayMessages,
          'teacher_threads': _teacherThreads.length,
          'parent_threads': _parentThreads.length,
        },
      );
      _showSnackBar('Communication report export queued.');
    } catch (error) {
      _showSnackBar('Unable to queue report export: $error');
    }
  }

  Future<void> _updateSetting(String key, bool value) async {
    await _notificationService?.updateSetting(key, value);
    setState(() {
      if (key == 'principal_monitor_teacher_chats') {
        _monitorTeacherChats = value;
      } else if (key == 'principal_monitor_group_chats') {
        _monitorGroupChats = value;
      } else if (key == 'principal_realtime_chat_alerts') {
        _realTimeAlerts = value;
      }
    });
  }

  Future<void> _openFilterSheet() async {
    var filter = _filter;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Filter Chats',
                    style: _textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final option in _ConversationFilter.values)
                        ChoiceChip(
                          label: Text(_filterLabel(option)),
                          selected: filter == option,
                          onSelected: (_) =>
                              setSheetState(() => filter = option),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: () {
                      setState(() => _filter = filter);
                      Navigator.pop(context);
                    },
                    child: const Text('Apply'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  List<_RecentActivity> get _recentActivities {
    final rows = <_RecentActivity>[];
    for (final thread in _parentThreads) {
      if (thread.messages.isEmpty) continue;
      final last = thread.messages.last;
      rows.add(
        _RecentActivity(
          title: '${last.senderLabel} sent a message',
          timeSort: last.timeSort,
          timeLabel: _timeLabel(last.sentAt),
        ),
      );
    }
    for (final thread in _teacherThreads) {
      if (thread.messages.isEmpty) continue;
      final last = thread.messages.last;
      rows.add(
        _RecentActivity(
          title: '${thread.teacherLabel} direct message',
          timeSort: last.timeSort,
          timeLabel: _timeLabel(last.sentAt),
        ),
      );
    }
    rows.sort((a, b) => b.timeSort.compareTo(a.timeSort));
    return rows;
  }

  TextTheme get _textTheme => Theme.of(context).textTheme;

  String get _selectedTeacherName =>
      _selectedTeacher == null ? 'Teacher' : _userLabel(_selectedTeacher!);

  String get _selectedTeacherClassLabel {
    final rows = _visibleTeacherParentThreads;
    if (rows.isEmpty) return 'Monitor teacher to parent chats';
    final label = rows.first.classLabel;
    return label.isEmpty ? 'Monitor teacher to parent chats' : label;
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFDDE7F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7FA6BD).withAlpha(24),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withAlpha(22),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: const Color(0xFF667789),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: const Color(0xFF0F2133),
                    fontWeight: FontWeight.w900,
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

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFDDE7F0)),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: iconColor.withAlpha(22),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: const Color(0xFF667789),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final String avatarLabel;
  final String title;
  final String subtitle;
  final String timeLabel;
  final int unreadCount;
  final IconData icon;
  final VoidCallback onTap;

  const _ConversationTile({
    required this.avatarLabel,
    required this.title,
    required this.subtitle,
    required this.timeLabel,
    required this.unreadCount,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFDDE7F0)),
            ),
            child: Row(
              children: [
                Stack(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF4FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          avatarLabel,
                          style: const TextStyle(
                            color: Color(0xFF0B72F0),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 17,
                        height: 17,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Icon(
                          icon,
                          size: 12,
                          color: const Color(0xFF0B72F0),
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
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                          ),
                          Text(
                            timeLabel,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: const Color(0xFF667789),
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: const Color(0xFF667789),
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                          if (unreadCount > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0B72F0),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                unreadCount.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TeacherMonitorTile extends StatelessWidget {
  final UserAccountModel teacher;
  final int activeChats;
  final int unread;
  final VoidCallback onTap;

  const _TeacherMonitorTile({
    required this.teacher,
    required this.activeChats,
    required this.unread,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final label = _userLabel(teacher);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFDDE7F0)),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF4FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      _initials(label),
                      style: const TextStyle(
                        color: Color(0xFF0B72F0),
                        fontWeight: FontWeight.w900,
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
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.circle,
                            size: 7,
                            color: Color(0xFF16A34A),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            unread > 0 ? '$unread unread' : 'Active now',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: const Color(0xFF667789),
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$activeChats',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'Active Chats',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: const Color(0xFF667789),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
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

class _AnnouncementTile extends StatelessWidget {
  final AnnouncementModel announcement;

  const _AnnouncementTile({required this.announcement});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFDDE7F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  announcement.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              _StatusPill(
                label: announcement.isUrgent
                    ? 'Important'
                    : _titleCase(announcement.targetAudience),
                color: announcement.isUrgent
                    ? AppTheme.error
                    : const Color(0xFF16A34A),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            announcement.content,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: const Color(0xFF334155),
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _shortDate(_announcementDate(announcement)),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: const Color(0xFF667789),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final String title;
  final String body;
  final String timeLabel;
  final bool mine;
  final bool unread;
  final VoidCallback? onMarkRead;

  const _MessageBubble({
    required this.title,
    required this.body,
    required this.timeLabel,
    required this.mine,
    required this.unread,
    this.onMarkRead,
  });

  @override
  Widget build(BuildContext context) {
    final color = mine ? const Color(0xFFDDF8E8) : const Color(0xFFF1F5F9);
    return Padding(
      padding: EdgeInsets.only(
        left: mine ? 46 : 0,
        right: mine ? 0 : 46,
        bottom: 12,
      ),
      child: Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFDDE7F0)),
          ),
          child: Column(
            crossAxisAlignment: mine
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0F2133),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                body,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF172B3A),
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    timeLabel,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: const Color(0xFF667789),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (mine) ...[
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.done_all_rounded,
                      size: 14,
                      color: Color(0xFF16A34A),
                    ),
                  ],
                ],
              ),
              if (unread && onMarkRead != null) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: onMarkRead,
                  icon: const Icon(Icons.done_all_rounded, size: 16),
                  label: const Text('Mark read'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(22),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _SimpleListRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String trailing;
  final VoidCallback? onTap;

  const _SimpleListRow({
    required this.icon,
    required this.title,
    required this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: const Color(0xFF3157F6)),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w900),
      ),
      trailing: Text(
        trailing,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: const Color(0xFF667789),
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SettingsSwitchRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsSwitchRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      secondary: Icon(icon, color: const Color(0xFF3157F6)),
      title: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w900),
      ),
      subtitle: Text(
        subtitle,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: const Color(0xFF667789),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _InputLabel extends StatelessWidget {
  final String label;

  const _InputLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w900,
          color: const Color(0xFF334155),
        ),
      ),
    );
  }
}

enum _ChatListKind { teacher, parent }

class _ChatListItem {
  final _ChatListKind kind;
  final _TeacherDirectThread? teacherThread;
  final _ParentChatThread? parentThread;

  const _ChatListItem.teacherDirect(_TeacherDirectThread thread)
    : kind = _ChatListKind.teacher,
      teacherThread = thread,
      parentThread = null;

  const _ChatListItem.parentThread(_ParentChatThread thread)
    : kind = _ChatListKind.parent,
      teacherThread = null,
      parentThread = thread;

  String get title => teacherThread?.teacherLabel ?? parentThread?.title ?? '';

  String get subtitle =>
      teacherThread?.lastMessage ?? parentThread?.lastMessage ?? '';

  String get timeLabel =>
      teacherThread?.statusLabel ?? parentThread?.lastTimeLabel ?? '';

  int get unreadCount =>
      teacherThread?.unreadCount ?? parentThread?.unreadCount ?? 0;

  int get timeSort =>
      teacherThread?.lastTimeSort ?? parentThread?.lastTimeSort ?? 0;

  bool get isGroup => parentThread?.isGroup ?? false;

  String get initials => _initials(title);

  String get searchText =>
      teacherThread?.searchText ?? parentThread?.searchText ?? '';
}

class _RecentActivity {
  final String title;
  final int timeSort;
  final String timeLabel;

  const _RecentActivity({
    required this.title,
    required this.timeSort,
    required this.timeLabel,
  });
}

class _ParentChatThread {
  final String id;
  final String teacherId;
  final String teacherLabel;
  final String parentLabel;
  final String studentLabel;
  final String classLabel;
  final String reference;
  final UserAccountModel? teacherUser;
  final List<_ChatMessage> messages;
  final String lastMessage;
  final DateTime? lastTime;
  final int unreadCount;
  final String principalId;

  const _ParentChatThread({
    required this.id,
    required this.teacherId,
    required this.teacherLabel,
    required this.parentLabel,
    required this.studentLabel,
    required this.classLabel,
    required this.reference,
    required this.teacherUser,
    required this.messages,
    required this.lastMessage,
    required this.lastTime,
    required this.unreadCount,
    required this.principalId,
  });

  factory _ParentChatThread.fromApi(
    Map<String, dynamic> row, {
    required List<Map<String, dynamic>> messageRows,
    required String principalId,
    required Map<String, UserAccountModel> teacherById,
    required Map<String, UserAccountModel> teacherByLinkedId,
    required Map<String, UserAccountModel> parentById,
    required Map<String, UserAccountModel> parentByLinkedId,
    required Map<String, StudentModel> studentById,
    required Map<String, SectionModel> sectionById,
  }) {
    final id = _text(row['id'] ?? row['conversation_id']);
    final messages =
        messageRows
            .where((message) => _text(message['conversation_id']) == id)
            .map(_ChatMessage.fromApi)
            .toList()
          ..sort((a, b) => a.timeSort.compareTo(b.timeSort));
    final teacherRef = _text(row['teacher_id'] ?? row['staff_id']);
    final teacherUser =
        teacherById[teacherRef] ?? teacherByLinkedId[teacherRef];
    final parentRef = _text(
      row['parent_id'] ?? row['guardian_id'] ?? row['parent_user_id'],
    );
    final parentUser = parentById[parentRef] ?? parentByLinkedId[parentRef];
    final studentId = _text(row['student_id']);
    final student = studentById[studentId];
    final lastMessage = messages.isNotEmpty
        ? messages.last.body
        : _text(row['last_message'], fallback: 'No messages yet');
    final lastTime = messages.isNotEmpty
        ? messages.last.sentAt
        : _dateTime(row['last_message_time'] ?? row['updated_at']);

    return _ParentChatThread(
      id: id,
      teacherId: teacherRef,
      teacherLabel: teacherUser == null
          ? _fallbackEntityLabel(teacherRef, 'Teacher')
          : _userLabel(teacherUser),
      parentLabel: parentUser == null
          ? _fallbackEntityLabel(parentRef, 'Parent')
          : _userLabel(parentUser),
      studentLabel: _studentLabel(student, row),
      classLabel: _classLabel(student, row, sectionById),
      reference: _referenceLabel(row),
      teacherUser: teacherUser,
      messages: messages,
      lastMessage: lastMessage,
      lastTime: lastTime,
      unreadCount: messages
          .where(
            (message) =>
                !message.isRead && _role(message.senderRole) != 'principal',
          )
          .length,
      principalId: principalId,
    );
  }

  String get title => isGroup ? '$classLabel Parents' : parentLabel;

  bool get isGroup {
    final text = '$reference $classLabel $parentLabel'.toLowerCase();
    return text.contains('group') || text.contains('parents');
  }

  int get lastTimeSort =>
      lastTime?.millisecondsSinceEpoch ?? DateTime(1970).millisecondsSinceEpoch;

  String get lastTimeLabel => lastTime == null ? 'Chat' : _shortDate(lastTime);

  String get searchText => [
    teacherLabel,
    parentLabel,
    studentLabel,
    classLabel,
    reference,
    lastMessage,
    for (final message in messages) message.body,
  ].join(' ').toLowerCase();
}

class _TeacherDirectThread {
  final UserAccountModel teacher;
  final String principalId;
  final List<_DirectMessage> messages;

  const _TeacherDirectThread({
    required this.teacher,
    required this.principalId,
    required this.messages,
  });

  String get teacherLabel => _userLabel(teacher);

  int get unreadCount => messages
      .where(
        (message) =>
            message.receiverId == principalId &&
            _role(message.senderRole) == 'teacher' &&
            !message.isRead,
      )
      .length;

  String get lastMessage =>
      messages.isEmpty ? 'No internal messages yet' : messages.last.body;

  int get lastTimeSort => messages.isEmpty
      ? DateTime(1970).millisecondsSinceEpoch
      : messages.last.timeSort;

  String get statusLabel =>
      messages.isEmpty ? 'Ready' : _shortDate(messages.last.sentAt);

  String get searchText => [
    teacherLabel,
    teacher.username,
    teacher.email,
    teacher.phone,
    for (final message in messages) message.body,
  ].join(' ').toLowerCase();
}

class _ChatMessage {
  final String id;
  final String senderId;
  final String senderRole;
  final String senderName;
  final String body;
  final DateTime? sentAt;
  final bool isRead;

  const _ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderRole,
    required this.senderName,
    required this.body,
    required this.sentAt,
    required this.isRead,
  });

  factory _ChatMessage.fromApi(Map<String, dynamic> row) {
    return _ChatMessage(
      id: _text(row['id'] ?? row['message_id']),
      senderId: _text(row['sender_id']),
      senderRole: _text(row['sender_role'], fallback: 'Message'),
      senderName: _text(row['sender_name']),
      body: _text(row['body'] ?? row['message'] ?? row['message_content']),
      sentAt: _dateTime(row['sent_at'] ?? row['created_at']),
      isRead: _isRead(row['is_read']),
    );
  }

  int get timeSort =>
      sentAt?.millisecondsSinceEpoch ?? DateTime(1970).millisecondsSinceEpoch;

  String get senderLabel =>
      senderName.isEmpty ? _titleCase(senderRole) : senderName;
}

class _DirectMessage {
  final String id;
  final String senderId;
  final String senderRole;
  final String receiverId;
  final String receiverRole;
  final String body;
  final DateTime? sentAt;
  final bool isRead;

  const _DirectMessage({
    required this.id,
    required this.senderId,
    required this.senderRole,
    required this.receiverId,
    required this.receiverRole,
    required this.body,
    required this.sentAt,
    required this.isRead,
  });

  factory _DirectMessage.fromApi(Map<String, dynamic> row) {
    return _DirectMessage(
      id: _text(row['id'] ?? row['message_id']),
      senderId: _text(row['sender_id']),
      senderRole: _text(row['sender_role']),
      receiverId: _text(row['receiver_id']),
      receiverRole: _text(row['receiver_role']),
      body: _text(row['message_content'] ?? row['message'] ?? row['body']),
      sentAt: _dateTime(row['sent_at'] ?? row['created_at']),
      isRead: _isRead(row['is_read']),
    );
  }

  bool get isIncomingToPrincipal => _role(receiverRole) == 'principal';

  int get timeSort =>
      sentAt?.millisecondsSinceEpoch ?? DateTime(1970).millisecondsSinceEpoch;

  String get senderLabel =>
      _titleCase(senderRole.isEmpty ? 'Message' : senderRole);
}

String _filterLabel(_ConversationFilter filter) {
  return switch (filter) {
    _ConversationFilter.all => 'All',
    _ConversationFilter.teachers => 'Teachers',
    _ConversationFilter.parents => 'Parents',
    _ConversationFilter.groups => 'Groups',
    _ConversationFilter.unread => 'Unread',
  };
}

String _text(Object? value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

String _role(Object? value) => _text(value).toLowerCase();

bool _isRead(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  return _text(value).toLowerCase() == 'true';
}

DateTime? _dateTime(Object? value) {
  final text = _text(value);
  if (text.isEmpty) return null;
  return DateTime.tryParse(text);
}

DateTime _announcementDate(AnnouncementModel announcement) {
  return DateTime.tryParse(announcement.publishedAt) ?? DateTime(1970);
}

String _timeLabel(DateTime? value) {
  if (value == null) return '';
  return DateFormat('h:mm a').format(value.toLocal());
}

String _shortDate(DateTime? value) {
  if (value == null) return 'Direct';
  final local = value.toLocal();
  final now = DateTime.now();
  if (local.year == now.year &&
      local.month == now.month &&
      local.day == now.day) {
    return DateFormat('h:mm a').format(local);
  }
  return DateFormat('dd MMM').format(local);
}

String _titleCase(String value) {
  final clean = value.trim();
  if (clean.isEmpty) return 'Message';
  return clean
      .split(RegExp(r'[_\s-]+'))
      .where((part) => part.isNotEmpty)
      .map(
        (part) => '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
      )
      .join(' ');
}

String _userLabel(UserAccountModel user) {
  final name = _text(user.name);
  if (name.isNotEmpty) return name;
  final username = _text(user.username);
  if (username.isNotEmpty) return username;
  final email = _text(user.email);
  if (email.isNotEmpty) return email;
  return _fallbackEntityLabel(user.id, 'User');
}

String _fallbackEntityLabel(String id, String fallback) {
  if (id.trim().isEmpty) return fallback;
  if (id.length <= 8) return '$fallback $id';
  return '$fallback ${id.substring(0, 8)}';
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

String _studentLabel(StudentModel? student, Map<String, dynamic> row) {
  if (student != null && student.fullName.trim().isNotEmpty) {
    return student.fullName.trim();
  }
  return _text(
    row['student_name'] ?? row['child_name'] ?? row['student_id'],
    fallback: 'Student',
  );
}

String _classLabel(
  StudentModel? student,
  Map<String, dynamic> row,
  Map<String, SectionModel> sectionById,
) {
  final rowClass = _text(row['class_name'] ?? row['class'] ?? row['section']);
  if (rowClass.isNotEmpty) return rowClass;

  final currentSection = student?.currentSection ?? const <String, dynamic>{};
  final sectionId = _text(
    row['section_id'] ?? student?.currentSectionId ?? currentSection['id'],
  );
  final section = sectionById[sectionId];
  if (section != null) {
    final grade = _text(section.gradeName);
    final name = _text(section.sectionName);
    return [grade, name].where((part) => part.isNotEmpty).join(' ');
  }

  final grade = currentSection['grade'];
  final gradeName = _text(
    currentSection['grade_name'] ??
        currentSection['class_name'] ??
        (grade is Map ? grade['grade_name'] ?? grade['name'] : null),
  );
  final sectionName = _text(currentSection['section_name']);
  final label = [
    gradeName,
    sectionName,
  ].where((part) => part.isNotEmpty).join(' ');
  return label.isEmpty ? 'Class not linked' : label;
}

String _referenceLabel(Map<String, dynamic> row) {
  final type = _titleCase(_text(row['reference_type'], fallback: 'Chat'));
  final title = _text(row['title']);
  if (title.isEmpty) return type;
  return '$type - $title';
}
