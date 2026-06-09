import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/theme/app_theme.dart';
import 'package:schooldesk1/core/widgets/dashboard_fab_widget.dart';
import 'package:schooldesk1/core/widgets/erp_components.dart';
import 'package:schooldesk1/routes/app_routes.dart';

class ParentTeacherChatScreen extends StatefulWidget {
  const ParentTeacherChatScreen({super.key});

  @override
  State<ParentTeacherChatScreen> createState() =>
      _ParentTeacherChatScreenState();
}

class _ParentTeacherChatScreenState extends State<ParentTeacherChatScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  static const _headerColor = Color(0xFF1A6B4A);
  bool _loading = true;
  String _parentUserId = '';
  String _firstStudentId = '';

  // Chat pagination
  static const int _chatPageSize = 20;
  int _chatPage = 0;
  bool _chatLoadingMore = false;
  bool _chatHasMore = false;
  List<Map<String, dynamic>> _displayedMessages = [];
  final ScrollController _chatScrollCtrl = ScrollController();

  List<Map<String, dynamic>> _teachers = [];
  List<Map<String, dynamic>> _children = [];
  int _activeChildIndex = 0;
  bool _classTeacherOnly = false;

  // Persisted messages per teacher: { teacherId: [messages] }
  Map<String, List<Map<String, dynamic>>> _allMessages = {};
  Map<String, int> _unreadCounts = {};
  List<Map<String, dynamic>> _directMessages = [];
  List<Map<String, dynamic>> _ptmSlots = [];

  int? _activeChatIndex;
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _sendingMessage = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _chatScrollCtrl.addListener(_onChatScroll);
    _loadData();
  }

  void _onChatScroll() {
    // Load older messages when scrolled to top
    if (_chatScrollCtrl.position.pixels <= 100) {
      _loadOlderMessages();
    }
  }

  void _loadOlderMessages() {
    if (_chatLoadingMore || !_chatHasMore || _activeChatIndex == null) return;
    final teacher = _teachers[_activeChatIndex!];
    final tid = teacher['id'] as String;
    final allMsgs = _allMessages[tid] ?? [];
    final start = allMsgs.length - (_chatPage + 1) * _chatPageSize;
    if (start <= 0) {
      setState(() => _chatHasMore = false);
      return;
    }
    setState(() => _chatLoadingMore = true);
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      final loadFrom = start.clamp(0, allMsgs.length);
      final loadTo = (start + _chatPageSize).clamp(0, allMsgs.length);
      final olderMsgs = allMsgs.sublist(loadFrom, loadTo);
      final prevScrollExtent = _chatScrollCtrl.hasClients
          ? _chatScrollCtrl.position.maxScrollExtent
          : 0.0;
      setState(() {
        _displayedMessages = [...olderMsgs, ..._displayedMessages];
        _chatPage++;
        _chatLoadingMore = false;
        _chatHasMore = loadFrom > 0;
      });
      // Maintain scroll position after prepending
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_chatScrollCtrl.hasClients) {
          final newExtent = _chatScrollCtrl.position.maxScrollExtent;
          _chatScrollCtrl.jumpTo(newExtent - prevScrollExtent);
        }
      });
    });
  }

  void _initChatPagination(String teacherId) {
    final allMsgs = _allMessages[teacherId] ?? [];
    _chatPage = 0;
    _chatLoadingMore = false;
    final start = (allMsgs.length - _chatPageSize).clamp(0, allMsgs.length);
    _displayedMessages = allMsgs.sublist(start);
    _chatHasMore = start > 0;
  }

  Future<void> _loadData() async {
    final api = BackendApiClient.instance;
    final profile = await api.getProfile();
    final children = await api.getMyStudents();
    final conversations = await api.getRawList('/message-conversations');
    final messages = await api.getRawList('/messages');
    final directMessages = await api.getCommunications();
    final ptmSlots = await api.getRawList('/parent-teacher-meetings');
    final timetableRows = <Map<String, dynamic>>[];
    _parentUserId = profile.id;
    _firstStudentId = children.isNotEmpty
        ? '${children.first['id'] ?? ''}'
        : '';
    directMessages.sort(
      (a, b) => _directMessageTime(b).compareTo(_directMessageTime(a)),
    );
    for (final child in children) {
      final sectionId = '${child['current_section_id'] ?? ''}'.trim();
      if (sectionId.isEmpty) continue;
      try {
        final slots = await api.getTimetableSlots(sectionId: sectionId);
        timetableRows.addAll(
          slots.map(
            (slot) => {
              ...slot,
              '_child_class': _childClassLabel(child),
              '_child_section_id': sectionId,
              '_child_student_id': '${child['id'] ?? ''}',
            },
          ),
        );
      } catch (_) {
        // Keep chat usable even if a child's timetable is not configured yet.
      }
    }

    final Map<String, List<Map<String, dynamic>>> loadedMessages = {};
    final Map<String, int> loadedUnread = {};
    final Map<String, Map<String, dynamic>> teacherRows = {};

    for (final conversation in conversations) {
      if ('${conversation['parent_id']}' != _parentUserId) continue;
      final teacherId = '${conversation['teacher_id'] ?? ''}';
      if (teacherId.isEmpty) continue;
      teacherRows[teacherId] = _teacherRowFromConversation(conversation);
      loadedMessages[teacherId] =
          messages
              .where(
                (message) => message['conversation_id'] == conversation['id'],
              )
              .map(_messageFromApi)
              .toList()
            ..sort(
              (a, b) =>
                  (a['timestamp'] as int).compareTo(b['timestamp'] as int),
            );
      loadedUnread[teacherId] = loadedMessages[teacherId]!
          .where(
            (message) =>
                message['sender'] == 'teacher' && message['read'] == false,
          )
          .length;
    }

    for (final slot in ptmSlots) {
      final teacherId = '${slot['teacher_id'] ?? ''}';
      if (teacherId.isEmpty) continue;
      teacherRows.putIfAbsent(teacherId, () => _teacherRowFromPtm(slot));
    }
    for (final slot in timetableRows) {
      final teacherId = '${slot['staff_id'] ?? ''}';
      if (teacherId.isEmpty) continue;
      teacherRows.putIfAbsent(teacherId, () => _teacherRowFromTimetable(slot));
      loadedMessages.putIfAbsent(teacherId, () => <Map<String, dynamic>>[]);
      loadedUnread.putIfAbsent(teacherId, () => 0);
    }

    setState(() {
      _teachers = teacherRows.values.toList();
      _children = children
          .whereType<Map>()
          .map((child) => Map<String, dynamic>.from(child))
          .toList();
      if (_activeChildIndex >= _children.length) _activeChildIndex = 0;
      _allMessages = loadedMessages;
      _unreadCounts = loadedUnread;
      _directMessages = directMessages;
      _ptmSlots = ptmSlots.map(_ptmSlotFromApi).toList();
      _loading = false;
    });
  }

  Map<String, dynamic> _teacherRowFromConversation(
    Map<String, dynamic> conversation,
  ) {
    final title = '${conversation['title'] ?? 'Teacher'}';
    final teacherId = '${conversation['teacher_id'] ?? ''}';
    return {
      'id': teacherId,
      'conversation_id': conversation['id'],
      'name': title.isEmpty ? teacherId : title,
      'subject': conversation['reference_type'] ?? 'Class communication',
      'class': conversation['student_id'] ?? '',
      'initials': _initials(title.isEmpty ? teacherId : title),
      'online': false,
      'color': _headerColor,
    };
  }

  Map<String, dynamic> _teacherRowFromPtm(Map<String, dynamic> slot) {
    final teacher = slot['teacher'];
    final teacherId = '${slot['teacher_id'] ?? ''}';
    final name = teacher is Map
        ? '${teacher['first_name'] ?? ''} ${teacher['last_name'] ?? ''}'.trim()
        : teacherId;
    return {
      'id': teacherId,
      'conversation_id': '',
      'student_id': '${slot['_child_student_id'] ?? ''}',
      'name': name.isEmpty ? teacherId : name,
      'subject': teacher is Map ? teacher['designation'] ?? '' : '',
      'class': _sectionLabel(slot['section']),
      'initials': _initials(name.isEmpty ? teacherId : name),
      'online': false,
      'color': _headerColor,
    };
  }

  Map<String, dynamic> _teacherRowFromTimetable(Map<String, dynamic> slot) {
    final staff = slot['staff'];
    final subject = slot['subject'];
    final teacherId = '${slot['staff_id'] ?? ''}';
    final name = staff is Map
        ? '${staff['first_name'] ?? ''} ${staff['last_name'] ?? ''}'.trim()
        : teacherId;
    final subjectName = subject is Map
        ? '${subject['subject_name'] ?? subject['name'] ?? ''}'.trim()
        : '';
    final classLabel = '${slot['_child_class'] ?? ''}'.trim();
    return {
      'id': teacherId,
      'conversation_id': '',
      'name': name.isEmpty ? teacherId : name,
      'subject': subjectName.isEmpty ? 'Class communication' : subjectName,
      'class': classLabel,
      'initials': _initials(name.isEmpty ? teacherId : name),
      'online': false,
      'color': _headerColor,
    };
  }

  String _childClassLabel(Map<String, dynamic> child) {
    final grade = '${child['grade_name'] ?? child['class'] ?? ''}'.trim();
    final section = '${child['section_name'] ?? child['section'] ?? ''}'.trim();
    return [grade, section].where((part) => part.isNotEmpty).join(' ');
  }

  Map<String, dynamic> _messageFromApi(Map<String, dynamic> message) {
    final sentAt =
        DateTime.tryParse(
          '${message['sent_at'] ?? message['created_at'] ?? ''}',
        ) ??
        DateTime.now();
    final role = '${message['sender_role'] ?? ''}'.toLowerCase();
    return {
      'id': message['id'],
      'conversation_id': message['conversation_id'],
      'sender_id': message['sender_id'],
      'sender_name': message['sender_name'],
      'sender': role == 'teacher' ? 'teacher' : 'parent',
      'text': message['body'] ?? '',
      'time':
          '${sentAt.hour.toString().padLeft(2, '0')}:${sentAt.minute.toString().padLeft(2, '0')}',
      'timestamp': sentAt.millisecondsSinceEpoch,
      'read': message['is_read'] == true,
      'type': 'text',
    };
  }

  Map<String, dynamic> _ptmSlotFromApi(Map<String, dynamic> slot) {
    final teacher = slot['teacher'];
    final event = slot['event'];
    final slotDate = DateTime.tryParse('${slot['slot_date'] ?? ''}');
    return {
      'id': slot['id'],
      'event_id': slot['event_id'],
      'section_id': slot['section_id'],
      'teacher_id': slot['teacher_id'],
      'guardian_id': slot['guardian_id'],
      'student_id': slot['student_id'],
      'teacherName': teacher is Map
          ? '${teacher['first_name'] ?? ''} ${teacher['last_name'] ?? ''}'
                .trim()
          : slot['teacher_id'] ?? '',
      'subject': teacher is Map ? teacher['designation'] ?? '' : '',
      'room': event is Map ? event['location'] ?? '' : '',
      'date': slotDate == null ? '' : _formatDate(slotDate),
      'slotDate': slotDate?.toUtc().toIso8601String(),
      'time': slot['slot_time'] ?? '',
      'durationMin': slot['duration_min'] ?? slot['duration'] ?? 15,
      'status': slot['status'] ?? 'available',
      'bookedBy': slot['status'] == 'booked' ? 'Parent' : '',
    };
  }

  String _sectionLabel(dynamic section) {
    if (section is! Map) return '';
    final grade = section['grade_name']?.toString().trim() ?? '';
    final name = section['section_name']?.toString().trim() ?? '';
    return [grade, name].where((part) => part.isNotEmpty).join(' ');
  }

  String _initials(String value) {
    final initials = value
        .split(RegExp(r'\s+'))
        .where((part) => part.trim().isNotEmpty)
        .take(2)
        .map((part) => part.trim()[0].toUpperCase())
        .join();
    return initials.isEmpty ? 'T' : initials;
  }

  String _formatDate(DateTime value) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${value.day} ${months[value.month - 1]} ${value.year}';
  }

  Future<void> _markAsRead(String teacherId) async {
    final msgs = _allMessages[teacherId] ?? [];
    bool changed = false;
    for (var msg in msgs) {
      if (msg['sender'] == 'teacher' && msg['read'] == false) {
        msg['read'] = true;
        changed = true;
      }
    }
    if (changed) {
      _unreadCounts[teacherId] = 0;
      for (final msg in msgs.where((msg) => msg['sender'] == 'teacher')) {
        final id = msg['id']?.toString() ?? '';
        if (id.isNotEmpty) {
          await BackendApiClient.instance.updateRaw('/messages/$id', {
            'is_read': true,
          });
        }
      }
      setState(() {});
    }
  }

  Future<void> _savePtmSlots() async {
    await _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    _chatScrollCtrl.dispose();
    super.dispose();
  }

  String _lastMessage(String teacherId) {
    final msgs = _allMessages[teacherId] ?? [];
    if (msgs.isEmpty) return 'No messages yet';
    final last = msgs.last;
    return last['text'] as String? ?? '';
  }

  String _lastTime(String teacherId) {
    final msgs = _allMessages[teacherId] ?? [];
    if (msgs.isEmpty) return '';
    return msgs.last['time'] as String? ?? '';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: _headerColor,
        flexibleSpace: const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0B6B43), Color(0xFF087346)],
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: _activeChatIndex != null
              ? () => setState(() => _activeChatIndex = null)
              : () async {
                  if (!await Navigator.maybePop(context) && context.mounted) {
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      AppRoutes.parentDashboard,
                      (route) => false,
                    );
                  }
                },
        ),
        title: _activeChatIndex != null
            ? Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(30),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        _teachers[_activeChatIndex!]['initials'] as String,
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _teachers[_activeChatIndex!]['name'] as String,
                        style: GoogleFonts.dmSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        (_teachers[_activeChatIndex!]['online'] as bool)
                            ? '● Online'
                            : '○ Offline',
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          color:
                              (_teachers[_activeChatIndex!]['online'] as bool)
                              ? Colors.greenAccent
                              : Colors.white60,
                        ),
                      ),
                    ],
                  ),
                ],
              )
            : Text(
                'Teacher Chat / PTM',
                style: GoogleFonts.dmSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
        actions: _activeChatIndex != null
            ? [
                IconButton(
                  icon: const Icon(
                    Icons.info_outline_rounded,
                    color: Colors.white,
                  ),
                  onPressed: () => _showTeacherInfo(_activeChatIndex!),
                ),
              ]
            : null,
        bottom: _activeChatIndex == null
            ? TabBar(
                controller: _tabController,
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white60,
                labelStyle: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                tabs: const [
                  Tab(text: 'Messages'),
                  Tab(text: 'PTM Booking'),
                ],
              )
            : null,
      ),
      floatingActionButton: const DashboardFabWidget(
        role: DashboardRole.parent,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: _buildParentBottomNavigation(),
      body: _activeChatIndex != null
          ? _buildChatView()
          : TabBarView(
              controller: _tabController,
              children: [_buildTeacherList(), _buildPTMBooking()],
            ),
    );
  }

  Widget _buildParentBottomNavigation() {
    return SchoolDeskBottomNavigationBar(
      items: [
        SchoolDeskBottomNavItem(
          label: 'Home',
          icon: Icons.home_outlined,
          activeIcon: Icons.home_rounded,
          selected: false,
          onTap: () => Navigator.pushNamedAndRemoveUntil(
            context,
            AppRoutes.parentDashboard,
            (route) => false,
          ),
        ),
        SchoolDeskBottomNavItem(
          label: 'Search',
          icon: Icons.search_rounded,
          activeIcon: Icons.manage_search_rounded,
          selected: false,
          onTap: () => Navigator.pushNamed(context, AppRoutes.globalSearch),
        ),
        SchoolDeskBottomNavItem(
          label: 'Notifications',
          icon: Icons.notifications_none_rounded,
          activeIcon: Icons.notifications_rounded,
          selected: false,
          onTap: () => Navigator.pushNamed(
            context,
            AppRoutes.notificationCenter,
            arguments: 'parent',
          ),
        ),
        SchoolDeskBottomNavItem(
          label: 'Profile',
          icon: Icons.account_circle_outlined,
          activeIcon: Icons.account_circle_rounded,
          selected: false,
          onTap: () => Navigator.pushNamed(
            context,
            AppRoutes.profileScreen,
            arguments: 'parent',
          ),
        ),
      ],
    );
  }

  Widget _buildTeacherList() {
    if (_teachers.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadData,
        color: _headerColor,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _buildParentDirectMessagesSection(),
            const SizedBox(height: 24),
            const SizedBox(height: 120),
            const Icon(Icons.forum_outlined, size: 48, color: AppTheme.muted),
            const SizedBox(height: 12),
            Text(
              'No teacher conversations yet',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Teachers appear here from your child timetable, PTM slots, or an existing chat.',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(fontSize: 12, color: AppTheme.muted),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _teachers.length + 1,
      itemBuilder: (_, i) {
        if (i == 0) return _buildParentDirectMessagesSection();
        final t = _teachers[i - 1];
        final tid = t['id'] as String;
        final unread = _unreadCounts[tid] ?? 0;
        final lastMsg = _lastMessage(tid);
        final lastTime = _lastTime(tid);
        final isOnline = t['online'] as bool;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: unread > 0
                  ? _headerColor.withAlpha(60)
                  : AppTheme.outlineVariant,
            ),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 8,
            ),
            leading: Stack(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: (t['color'] as Color).withAlpha(20),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      t['initials'] as String,
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: t['color'] as Color,
                      ),
                    ),
                  ),
                ),
                if (isOnline)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.surface, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            title: Text(
              t['name'] as String,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${t['subject']} — ${t['class']}',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: AppTheme.muted,
                  ),
                ),
                Text(
                  lastMsg,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: unread > 0
                        ? AppTheme.onSurface
                        : AppTheme.onSurfaceVariant,
                    fontWeight: unread > 0
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  lastTime,
                  style: GoogleFonts.dmSans(
                    fontSize: 10,
                    color: AppTheme.muted,
                  ),
                ),
                if (unread > 0) ...[
                  const SizedBox(height: 4),
                  Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      color: _headerColor,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '$unread',
                        style: GoogleFonts.dmSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            onTap: () async {
              setState(() {
                _activeChatIndex = i - 1;
                _initChatPagination(t['id'] as String);
              });
              await _markAsRead(t['id'] as String);
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => _scrollToBottom(),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildParentDirectMessagesSection() {
    if (_directMessages.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Principal Messages',
          style: GoogleFonts.dmSans(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppTheme.onSurface,
          ),
        ),
        const SizedBox(height: 10),
        ..._directMessages.map(
          (message) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _buildParentDirectMessageCard(message),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildParentDirectMessageCard(Map<String, dynamic> message) {
    final incoming = _directMessageIncoming(message);
    final unread = incoming && !_directMessageRead(message);
    final counterpartRole = incoming
        ? '${message['sender_role'] ?? 'Principal'}'
        : '${message['receiver_role'] ?? 'Principal'}';
    final counterpartId = incoming
        ? '${message['sender_id'] ?? ''}'
        : '${message['receiver_id'] ?? ''}';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: unread ? AppTheme.infoContainer : AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
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
                  '${incoming ? 'From' : 'To'} ${_titleCase(counterpartRole)}',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                _directMessageDate(message),
                style: GoogleFonts.dmSans(fontSize: 11, color: AppTheme.muted),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${message['message_content'] ?? message['message'] ?? message['body'] ?? 'Message'}',
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: AppTheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (unread)
                TextButton.icon(
                  onPressed: () => _markDirectMessageRead(message),
                  icon: const Icon(Icons.done_all_rounded, size: 14),
                  label: const Text('Mark Read'),
                ),
              const Spacer(),
              TextButton.icon(
                onPressed: counterpartId.trim().isEmpty
                    ? null
                    : () => _replyDirectMessage(
                        receiverId: counterpartId.trim(),
                        receiverRole: counterpartRole.trim(),
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

  Future<void> _markDirectMessageRead(Map<String, dynamic> message) async {
    final id = '${message['id'] ?? message['message_id'] ?? ''}'.trim();
    if (id.isEmpty) return;
    await BackendApiClient.instance.markCommunicationRead(id);
    await _loadData();
  }

  Future<void> _replyDirectMessage({
    required String receiverId,
    required String receiverRole,
  }) async {
    final controller = TextEditingController();
    final content = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reply'),
        content: TextField(
          controller: controller,
          minLines: 3,
          maxLines: 5,
          decoration: const InputDecoration(labelText: 'Message'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            icon: const Icon(Icons.send_rounded),
            label: const Text('Send'),
          ),
        ],
      ),
    );
    controller.dispose();
    final text = content?.trim() ?? '';
    if (text.isEmpty) return;
    await BackendApiClient.instance.sendCommunication(
      receiverId: receiverId,
      receiverRole: receiverRole,
      messageContent: text,
    );
    await _loadData();
  }

  bool _directMessageIncoming(Map<String, dynamic> message) {
    return '${message['receiver_id'] ?? ''}' == _parentUserId;
  }

  bool _directMessageRead(Map<String, dynamic> message) {
    final value = message['is_read'];
    if (value is bool) return value;
    if (value is num) return value != 0;
    return '${value ?? ''}'.toLowerCase() == 'true';
  }

  DateTime _directMessageTime(Map<String, dynamic> message) {
    return DateTime.tryParse(
          '${message['sent_at'] ?? message['created_at'] ?? ''}',
        ) ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _directMessageDate(Map<String, dynamic> message) {
    final sentAt = _directMessageTime(message);
    if (sentAt.millisecondsSinceEpoch == 0) return '';
    return '${sentAt.day.toString().padLeft(2, '0')}/${sentAt.month.toString().padLeft(2, '0')}';
  }

  String _titleCase(String value) {
    final clean = value.trim();
    if (clean.isEmpty) return 'Principal';
    return clean[0].toUpperCase() + clean.substring(1).toLowerCase();
  }

  void _scrollToBottom() {
    if (_chatScrollCtrl.hasClients) {
      _chatScrollCtrl.animateTo(
        _chatScrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Widget _buildChatView() {
    final teacher = _teachers[_activeChatIndex!];
    final tid = teacher['id'] as String;

    return Column(
      children: [
        if (_chatHasMore || _chatLoadingMore)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: _chatLoadingMore
                ? const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : TextButton.icon(
                    onPressed: _loadOlderMessages,
                    icon: const Icon(Icons.expand_less_rounded, size: 16),
                    label: Text(
                      'Load older messages',
                      style: GoogleFonts.dmSans(fontSize: 12),
                    ),
                  ),
          ),
        Expanded(
          child: ListView.builder(
            controller: _chatScrollCtrl,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: _displayedMessages.length,
            itemBuilder: (_, i) {
              final msg = _displayedMessages[i];
              final isParent = msg['sender'] == 'parent';
              final msgType = msg['type'] as String? ?? 'text';
              return _buildMessageBubble(msg, isParent, msgType);
            },
          ),
        ),
        _buildInputBar(tid),
      ],
    );
  }

  Widget _buildMessageBubble(
    Map<String, dynamic> msg,
    bool isParent,
    String type,
  ) {
    final isRead = msg['read'] as bool? ?? false;
    return Align(
      alignment: isParent ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        child: Column(
          crossAxisAlignment: isParent
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Container(
              padding: type == 'image'
                  ? const EdgeInsets.all(4)
                  : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isParent ? _headerColor : AppTheme.surfaceVariant,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(14),
                  topRight: const Radius.circular(14),
                  bottomLeft: Radius.circular(isParent ? 14 : 4),
                  bottomRight: Radius.circular(isParent ? 4 : 14),
                ),
              ),
              child: type == 'file'
                  ? _buildFileAttachment(msg, isParent)
                  : type == 'image'
                  ? _buildImageAttachment(msg)
                  : Text(
                      msg['text'] as String? ?? '',
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        color: isParent ? Colors.white : AppTheme.onSurface,
                      ),
                    ),
            ),
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  msg['time'] as String? ?? '',
                  style: GoogleFonts.dmSans(
                    fontSize: 10,
                    color: AppTheme.muted,
                  ),
                ),
                if (isParent) ...[
                  const SizedBox(width: 4),
                  Icon(
                    isRead ? Icons.done_all_rounded : Icons.done_rounded,
                    size: 14,
                    color: isRead ? Colors.blue : AppTheme.muted,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileAttachment(Map<String, dynamic> msg, bool isParent) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isParent
                ? Colors.white.withAlpha(30)
                : _headerColor.withAlpha(20),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.insert_drive_file_rounded,
            size: 20,
            color: isParent ? Colors.white : _headerColor,
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                msg['fileName'] as String? ?? 'Document',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isParent ? Colors.white : AppTheme.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                msg['fileSize'] as String? ?? '',
                style: GoogleFonts.dmSans(
                  fontSize: 10,
                  color: isParent ? Colors.white60 : AppTheme.muted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildImageAttachment(Map<String, dynamic> msg) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 180,
        height: 120,
        color: AppTheme.surfaceVariant,
        child: const Center(
          child: Icon(Icons.image_rounded, size: 40, color: AppTheme.muted),
        ),
      ),
    );
  }

  Widget _buildInputBar(String teacherId) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.outlineVariant)),
      ),
      child: Row(
        children: [
          // Attachment button
          GestureDetector(
            onTap: () => _showAttachmentOptions(teacherId),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppTheme.surfaceVariant,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.attach_file_rounded,
                size: 20,
                color: AppTheme.muted,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _msgCtrl,
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                hintStyle: GoogleFonts.dmSans(
                  fontSize: 13,
                  color: AppTheme.muted,
                ),
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
          GestureDetector(
            onTap: _sendingMessage ? null : () => _sendMessage(teacherId),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _sendingMessage ? AppTheme.muted : _headerColor,
                shape: BoxShape.circle,
              ),
              child: _sendingMessage
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
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

  Future<void> _sendMessage(String teacherId) async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;

    setState(() => _sendingMessage = true);
    _msgCtrl.clear();

    final now = DateTime.now();
    final conversationId = await _conversationIdForTeacher(teacherId);
    await BackendApiClient.instance.createRaw('/messages', {
      'conversation_id': conversationId,
      'sender_id': _parentUserId,
      'sender_role': 'Parent',
      'sender_name': 'Parent',
      'body': text,
      'is_read': false,
      'sent_at': now.toUtc().toIso8601String(),
    });
    await _loadData();
    final index = _teachers.indexWhere((teacher) => teacher['id'] == teacherId);
    if (index >= 0) {
      _activeChatIndex = index;
      _initChatPagination(teacherId);
    }

    setState(() => _sendingMessage = false);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  Future<String> _conversationIdForTeacher(String teacherId) async {
    final teacher = _teachers.firstWhere(
      (row) => row['id'] == teacherId,
      orElse: () => const {},
    );
    final existing = teacher['conversation_id']?.toString() ?? '';
    if (existing.isNotEmpty) return existing;
    final created = await BackendApiClient.instance
        .createRaw('/message-conversations', {
          'reference_type': 'parent-chat',
          'reference_id': '',
          'teacher_id': teacherId,
          'parent_id': _parentUserId,
          'student_id': teacher['student_id'] ?? _firstStudentId,
          'title': teacher['name'] ?? 'Teacher conversation',
          'last_message': '',
          'last_message_time': DateTime.now().toUtc().toIso8601String(),
        });
    return created['id'].toString();
  }

  void _showAttachmentOptions(String teacherId) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const _AttachmentBackendGapPage()),
    );
  }

  void _showTeacherInfo(int index) {
    final t = _teachers[index];
    // Read-only profile details remain a bottom sheet because no user input is collected.
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: (t['color'] as Color).withAlpha(20),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text(
                  t['initials'] as String,
                  style: GoogleFonts.dmSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: t['color'] as Color,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              t['name'] as String,
              style: GoogleFonts.dmSans(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              '${t['subject']} • Class ${t['class']}',
              style: GoogleFonts.dmSans(fontSize: 14, color: AppTheme.muted),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: (t['online'] as bool)
                    ? AppTheme.successContainer
                    : AppTheme.surfaceVariant,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                (t['online'] as bool) ? '● Online' : '○ Offline',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: (t['online'] as bool)
                      ? AppTheme.success
                      : AppTheme.muted,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildPTMBooking() {
    final selectedSlots = _selectedChildPtmSlots();
    final availableSlots = selectedSlots
        .where((slot) => !_isPtmSlotBooked(slot))
        .where(
          (slot) =>
              !_classTeacherOnly ||
              _ptmTeacherSubtitle(slot).toLowerCase().contains('class teacher'),
        )
        .toList();
    final bookedSlots = selectedSlots.where(_isPtmSlotBooked).toList();
    return RefreshIndicator(
      onRefresh: _loadData,
      color: _headerColor,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 96),
        children: [
          if (_children.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: _PtmChildSelector(
                label: _activeChildSelectorLabel(),
                children: _children,
                activeIndex: _activeChildIndex,
                onChanged: (index) => setState(() => _activeChildIndex = index),
              ),
            ),
          const SizedBox(height: 20),
          _PtmTeacherFilter(
            classTeacherOnly: _classTeacherOnly,
            onChanged: (classTeacherOnly) =>
                setState(() => _classTeacherOnly = classTeacherOnly),
          ),
          const SizedBox(height: 22),
          Text(
            'Available PTM Slots',
            style: GoogleFonts.dmSans(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppTheme.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          if (availableSlots.isEmpty)
            _PtmEmptyCard(
              icon: Icons.event_available_outlined,
              text: _classTeacherOnly
                  ? 'No class teacher slots available'
                  : 'No available PTM slots',
            )
          else
            for (final slot in availableSlots) ...[
              _ptmSlotCard(slot),
              const SizedBox(height: 12),
            ],
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Booking History',
                  style: GoogleFonts.dmSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.onSurface,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Refresh bookings',
                icon: const Icon(Icons.refresh_rounded),
                onPressed: _loadData,
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (bookedSlots.isEmpty) ...[
            _PtmEmptyCard(
              icon: Icons.event_busy_outlined,
              text: 'No more PTM bookings',
            ),
          ] else
            for (final slot in bookedSlots) ...[
              _ptmHistoryCard(slot),
              const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }

  Widget _ptmSlotCard(Map<String, dynamic> slot) {
    final teacherName =
        slot['teacherName'] as String? ?? slot['teacher'] as String? ?? '';
    final subject = _ptmTeacherSubtitle(slot);
    final date = slot['date'] as String? ?? '';
    final time = slot['time'] as String? ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.outlineVariant),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F0F172A),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _PtmInitialsAvatar(name: teacherName),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  teacherName,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subject,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: AppTheme.muted,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _PtmMetaChip(
                      icon: Icons.calendar_today_rounded,
                      text: date,
                    ),
                    _PtmMetaChip(icon: Icons.access_time_rounded, text: time),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: () => _bookPtmSlot(slot),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0057FF),
                  side: const BorderSide(color: Color(0xFF0057FF)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'Book',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _durationLabel(slot),
                style: GoogleFonts.dmSans(fontSize: 11, color: AppTheme.muted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _ptmHistoryCard(Map<String, dynamic> slot) {
    final teacherName =
        slot['teacherName'] as String? ?? slot['teacher'] as String? ?? '';
    final subject = _ptmTeacherSubtitle(slot);
    final date = slot['date'] as String? ?? '';
    final time = slot['time'] as String? ?? '';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Row(
        children: [
          _PtmInitialsAvatar(name: teacherName),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  teacherName,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.onSurface,
                  ),
                ),
                Text(
                  subject,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: AppTheme.muted,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _PtmMetaChip(
                      icon: Icons.calendar_today_rounded,
                      text: date,
                    ),
                    _PtmMetaChip(icon: Icons.access_time_rounded, text: time),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Icon(Icons.chevron_right_rounded, color: AppTheme.muted),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.successContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Confirmed',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.success,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _bookPtmSlot(Map<String, dynamic> slot) async {
    final id = '${slot['id'] ?? ''}'.trim();
    if (id.isEmpty) return;
    final teacherName =
        slot['teacherName'] as String? ?? slot['teacher'] as String? ?? '';
    final index = _ptmSlots.indexWhere((row) => '${row['id']}' == id);
    if (index >= 0) {
      setState(() {
        _ptmSlots[index]['status'] = 'booked';
        _ptmSlots[index]['bookedBy'] = 'Parent';
      });
    }
    try {
      await BackendApiClient.instance.bookParentTeacherMeeting(id);
      await _savePtmSlots();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PTM slot booked with $teacherName!'),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      await _savePtmSlots();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to book this PTM slot. Please try again.'),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  List<Map<String, dynamic>> _selectedChildPtmSlots() {
    final studentId = _activeStudentId();
    if (studentId.isEmpty) return List<Map<String, dynamic>>.from(_ptmSlots);
    return _ptmSlots
        .where((slot) {
          final slotStudentId = '${slot['student_id'] ?? ''}'.trim();
          return slotStudentId.isEmpty || slotStudentId == studentId;
        })
        .map((slot) => Map<String, dynamic>.from(slot))
        .toList();
  }

  String _activeStudentId() {
    if (_children.isEmpty) return _firstStudentId;
    return '${_children[_activeChildIndex]['id'] ?? ''}'.trim();
  }

  String _activeChildSelectorLabel() {
    if (_children.isEmpty) return 'Student';
    final child = _children[_activeChildIndex];
    final name = '${child['name'] ?? child['full_name'] ?? ''}'.trim();
    final firstName = '${child['first_name'] ?? ''}'.trim();
    final lastName = '${child['last_name'] ?? ''}'.trim();
    final fullName = name.isNotEmpty
        ? name
        : [firstName, lastName].where((part) => part.isNotEmpty).join(' ');
    final grade =
        '${child['class'] ?? child['grade_name'] ?? child['class_name'] ?? ''}'
            .trim();
    final label = fullName.isEmpty ? 'Student' : fullName;
    return grade.isEmpty ? label : '$label ($grade)';
  }

  bool _isPtmSlotBooked(Map<String, dynamic> slot) {
    final status = '${slot['status'] ?? ''}'.toLowerCase().trim();
    return status == 'booked' || status == 'confirmed';
  }

  String _ptmTeacherSubtitle(Map<String, dynamic> slot) {
    final subject = '${slot['subject'] ?? ''}'.trim();
    return subject.isEmpty ? 'Teacher' : subject;
  }

  String _durationLabel(Map<String, dynamic> slot) {
    final raw = slot['durationMin'];
    final minutes = raw is num ? raw.toInt() : int.tryParse('$raw') ?? 15;
    return '$minutes mins';
  }
}

class _PtmChildSelector extends StatelessWidget {
  final String label;
  final List<Map<String, dynamic>> children;
  final int activeIndex;
  final ValueChanged<int> onChanged;

  const _PtmChildSelector({
    required this.label,
    required this.children,
    required this.activeIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final child = Container(
      constraints: const BoxConstraints(minHeight: 42),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A6B4A),
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [
          BoxShadow(
            color: Color(0x180F172A),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 6),
          const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Colors.white,
            size: 20,
          ),
        ],
      ),
    );
    if (children.length <= 1) return child;
    return PopupMenuButton<int>(
      tooltip: 'Select child',
      onSelected: onChanged,
      itemBuilder: (context) => [
        for (var index = 0; index < children.length; index++)
          PopupMenuItem(
            value: index,
            child: Text(_ptmChildLabel(children[index])),
          ),
      ],
      child: child,
    );
  }
}

class _PtmTeacherFilter extends StatelessWidget {
  final bool classTeacherOnly;
  final ValueChanged<bool> onChanged;

  const _PtmTeacherFilter({
    required this.classTeacherOnly,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 10,
      children: [
        _PtmFilterPill(
          label: 'All Teachers',
          selected: !classTeacherOnly,
          onTap: () => onChanged(false),
        ),
        _PtmFilterPill(
          label: 'Class Teacher',
          selected: classTeacherOnly,
          onTap: () => onChanged(true),
        ),
      ],
    );
  }
}

class _PtmFilterPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PtmFilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: label == 'All Teachers' ? 120 : 132,
        constraints: const BoxConstraints(minHeight: 38, minWidth: 118),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1A6B4A) : AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? const Color(0xFF1A6B4A) : AppTheme.outlineVariant,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: selected ? Colors.white : AppTheme.onSurface,
          ),
        ),
      ),
    );
  }
}

class _PtmInitialsAvatar extends StatelessWidget {
  final String name;

  const _PtmInitialsAvatar({required this.name});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 28,
      backgroundColor: const Color(0xFFDCFCE7),
      foregroundColor: const Color(0xFF1A6B4A),
      child: Text(
        _ptmInitials(name),
        style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _PtmMetaChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _PtmMetaChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppTheme.onSurfaceVariant),
          const SizedBox(width: 5),
          Text(
            text.isEmpty ? 'Not set' : text,
            style: GoogleFonts.dmSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _PtmEmptyCard extends StatelessWidget {
  final IconData icon;
  final String text;

  const _PtmEmptyCard({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppTheme.muted),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _ptmChildLabel(Map<String, dynamic> child) {
  final explicit = '${child['name'] ?? child['full_name'] ?? ''}'.trim();
  final first = '${child['first_name'] ?? ''}'.trim();
  final last = '${child['last_name'] ?? ''}'.trim();
  final name = explicit.isNotEmpty
      ? explicit
      : [first, last].where((part) => part.isNotEmpty).join(' ');
  final grade =
      '${child['class'] ?? child['grade_name'] ?? child['class_name'] ?? ''}'
          .trim();
  final label = name.isEmpty ? 'Student' : name;
  return grade.isEmpty ? label : '$label ($grade)';
}

String _ptmInitials(String value) {
  final parts = value
      .split(RegExp(r'\s+'))
      .where((part) => part.trim().isNotEmpty)
      .take(2)
      .map((part) => part.trim()[0].toUpperCase())
      .join();
  return parts.isEmpty ? 'T' : parts;
}

class _AttachmentBackendGapPage extends StatelessWidget {
  const _AttachmentBackendGapPage();

  @override
  Widget build(BuildContext context) {
    final options = [
      (Icons.image_rounded, 'Photo'),
      (Icons.camera_alt_rounded, 'Camera'),
      (Icons.insert_drive_file_rounded, 'Document'),
      (Icons.picture_as_pdf_rounded, 'PDF'),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Share Attachment')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.warningContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Attachment upload is blocked because this screen does not have a real file picker or upload endpoint wired yet. No synthetic file message was sent.',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: AppTheme.warning,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 16),
          ...options.map(
            (option) => ListTile(
              leading: Icon(option.$1, color: AppTheme.muted),
              title: Text(option.$2, style: GoogleFonts.dmSans()),
              subtitle: Text(
                'Unavailable until real upload support is connected',
                style: GoogleFonts.dmSans(fontSize: 12),
              ),
              enabled: false,
            ),
          ),
        ],
      ),
    );
  }
}
