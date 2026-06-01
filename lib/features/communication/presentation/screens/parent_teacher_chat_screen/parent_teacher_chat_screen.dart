import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/theme/app_theme.dart';
import 'package:schooldesk1/core/widgets/dashboard_fab_widget.dart';

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

  // Persisted messages per teacher: { teacherId: [messages] }
  Map<String, List<Map<String, dynamic>>> _allMessages = {};
  Map<String, int> _unreadCounts = {};
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
    final ptmSlots = await api.getRawList('/parent-teacher-meetings');
    final timetableRows = <Map<String, dynamic>>[];
    _parentUserId = profile.id;
    _firstStudentId = children.isNotEmpty
        ? '${children.first['id'] ?? ''}'
        : '';
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
      _allMessages = loadedMessages;
      _unreadCounts = loadedUnread;
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
        leading: _activeChatIndex != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: () => setState(() => _activeChatIndex = null),
              )
            : null,
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
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      body: _activeChatIndex != null
          ? _buildChatView()
          : TabBarView(
              controller: _tabController,
              children: [_buildTeacherList(), _buildPTMBooking()],
            ),
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
      itemCount: _teachers.length,
      itemBuilder: (_, i) {
        final t = _teachers[i];
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
                _activeChatIndex = i;
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
    return RefreshIndicator(
      onRefresh: _loadData,
      color: _headerColor,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.infoContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: AppTheme.info,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'PTM slots are set by teachers. Book your preferred slot below.',
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      color: AppTheme.info,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ..._ptmSlots.asMap().entries.map((e) => _ptmSlotCard(e.key, e.value)),
        ],
      ),
    );
  }

  Widget _ptmSlotCard(int index, Map<String, dynamic> slot) {
    final status = slot['status'] as String? ?? 'available';
    final isBooked = status == 'booked' || status == 'Booked';
    final teacherName =
        slot['teacherName'] as String? ?? slot['teacher'] as String? ?? '';
    final subject = slot['subject'] as String? ?? '';
    final room = slot['room'] as String? ?? '';
    final date = slot['date'] as String? ?? '';
    final time = slot['time'] as String? ?? '';
    final bookedBy = slot['bookedBy'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isBooked
              ? _headerColor.withAlpha(80)
              : AppTheme.outlineVariant,
        ),
      ),
      child: Row(
        children: [
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
                  '$subject • $room',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: AppTheme.muted,
                  ),
                ),
                Text(
                  '$date at $time',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: AppTheme.onSurfaceVariant,
                  ),
                ),
                if (isBooked && bookedBy.isNotEmpty)
                  Text(
                    'Booked by: $bookedBy',
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: AppTheme.success,
                    ),
                  ),
              ],
            ),
          ),
          isBooked
              ? Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.successContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        color: AppTheme.success,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Booked',
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.success,
                        ),
                      ),
                    ],
                  ),
                )
              : ElevatedButton(
                  onPressed: () async {
                    setState(() {
                      _ptmSlots[index]['status'] = 'booked';
                      _ptmSlots[index]['bookedBy'] = 'Parent';
                    });
                    final slot = _ptmSlots[index];
                    await BackendApiClient.instance.bookParentTeacherMeeting(
                      '${slot['id']}',
                    );
                    await _savePtmSlots();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('PTM slot booked with $teacherName!'),
                          backgroundColor: AppTheme.success,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _headerColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                  ),
                  child: Text(
                    'Book Slot',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
        ],
      ),
    );
  }
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
