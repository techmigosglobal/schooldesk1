import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:schooldesk1/core/navigation/role_nav_indices.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/utils/chat_message_merge.dart';
import 'package:schooldesk1/core/utils/extensions.dart';
import 'package:schooldesk1/core/widgets/app_navigation.dart';
import 'package:schooldesk1/core/widgets/dashboard_fab_widget.dart';
import 'package:schooldesk1/core/widgets/erp_module_scaffold.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:schooldesk1/core/services/chat_realtime_service.dart';
import 'package:schooldesk1/core/services/demo_local_api_service.dart';
import 'package:schooldesk1/features/communication/data/chat_models.dart';
import 'package:schooldesk1/features/communication/presentation/widgets/chat_shared_widgets.dart';

class PrincipalChatCommunicationsScreen extends StatefulWidget {
  const PrincipalChatCommunicationsScreen({super.key});

  @override
  State<PrincipalChatCommunicationsScreen> createState() =>
      _PrincipalChatCommunicationsScreenState();
}

class _PrincipalChatCommunicationsScreenState
    extends State<PrincipalChatCommunicationsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _messageController = TextEditingController();
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  RealtimeChannel? _realtimeChannel;
  String _realtimeConversationId = '';
  int _realtimeRequest = 0;

  bool _loading = true;
  bool _sending = false;
  bool _unreadOnly = false;
  String? _error;
  String _principalUserId = '';
  String _teacherFilter = '';
  String _parentFilter = '';
  String _studentFilter = '';
  String _monitorClassFilter = '';
  String _directRoleFilter = 'teacher';
  String _directClassFilter = '';
  DateTime? _dateFilter;
  List<Map<String, dynamic>> _monitorConversations = const [];
  List<Map<String, dynamic>> _directConversations = const [];
  List<Map<String, dynamic>> _monitorMessages = const [];
  List<Map<String, dynamic>> _directMessages = const [];
  final List<Map<String, dynamic>> _pendingMessages = [];
  Map<String, dynamic>? _selectedMonitorConversation;
  Map<String, dynamic>? _selectedDirectConversation;
  DateTime? _messagesCursor;

  String get _leadershipRole =>
      BackendApiClient.instance.currentRoleName?.trim().toLowerCase() ==
          'coordinator'
      ? 'coordinator'
      : 'principal';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
    unawaited(_subscribeRealtime());
  }

  @override
  void dispose() {
    _removeRealtimeChannel();
    _tabController.dispose();
    _messageController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Realtime ──────────────────────────────────────────────────────────────

  Future<void> _subscribeRealtime({String conversationId = ''}) async {
    if (DemoLocalApiService.instance.isActive) return;
    if (_realtimeConversationId == conversationId && _realtimeChannel != null) {
      await ChatRealtimeService.instance.refreshAuth();
      return;
    }
    _removeRealtimeChannel();
    _realtimeConversationId = conversationId;
    final request = ++_realtimeRequest;
    final channel = await ChatRealtimeService.instance.subscribe(
      channelName: 'principal-chat-$conversationId',
      conversationId: conversationId,
      onUpdate: () {
        if (mounted && !_sending) _loadIncremental();
      },
    );
    if (!mounted || request != _realtimeRequest) {
      if (channel != null) {
        await Supabase.instance.client.removeChannel(channel);
      }
      return;
    }
    _realtimeChannel = channel;
  }

  void _removeRealtimeChannel() {
    final ch = _realtimeChannel;
    if (ch != null) {
      Supabase.instance.client.removeChannel(ch);
      _realtimeChannel = null;
    }
  }

  // ── Data loading ──────────────────────────────────────────────────────────

  Future<void> _load({bool background = false}) async {
    if (!background) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final api = BackendApiClient.instance;
      final results = await Future.wait<Object>([
        api.getProfile(),
        _safeChatRows(() => api.getUnifiedChatConversations(monitor: true)),
        _safeChatRows(() => api.getUnifiedChatContacts(role: _leadershipRole)),
      ]);
      final profile = results[0] as dynamic;
      final allConversations = results[1] as List<Map<String, dynamic>>;
      final monitor = allConversations
          .where((row) => _text(row['type']) == 'parent_teacher')
          .toList();
      final directTeacher = allConversations
          .where((row) => _text(row['type']) == 'principal_teacher')
          .toList();
      final directParent = allConversations
          .where((row) => _text(row['type']) == 'principal_parent')
          .toList();
      final contacts = results[2] as List<Map<String, dynamic>>;
      final teacherContacts = contacts
          .where((row) => _text(row['role']).toLowerCase() == 'teacher')
          .toList();
      final parentContacts = contacts
          .where((row) => _text(row['role']).toLowerCase() == 'parent')
          .toList();
      final direct =
          _mergeDirectConversationsWithContacts(
            directTeacher: directTeacher,
            directParent: directParent,
            teacherContacts: teacherContacts,
            parentContacts: parentContacts,
          )..sort((a, b) {
            final leftPlaceholder = _isContactPlaceholder(a);
            final rightPlaceholder = _isContactPlaceholder(b);
            if (leftPlaceholder != rightPlaceholder) {
              return leftPlaceholder ? 1 : -1;
            }
            final timeCompare = _sortTime(b).compareTo(_sortTime(a));
            if (timeCompare != 0) return timeCompare;
            return _directTitle(a).compareTo(_directTitle(b));
          });
      monitor.sort((a, b) => _sortTime(b).compareTo(_sortTime(a)));
      final selectedMonitor = _selectRetainedConversation(
        _selectedMonitorConversation,
        _filteredMonitor(monitor),
      );
      final selectedDirect = _selectRetainedConversation(
        _selectedDirectConversation,
        direct,
      );
      final monitorMode = _tabController.index == 0;
      final selected = monitorMode ? selectedMonitor : selectedDirect;
      List<Map<String, dynamic>> messages;
      DateTime? cursor;
      if (selected != null && !_isContactPlaceholder(selected)) {
        messages = mergeChatMessagesByIdentity(
          const [],
          await _safeChatRows(
            () => api.getUnifiedChatMessages(
              conversationId: _text(selected['id']),
            ),
          ),
        );
        cursor = messages.isNotEmpty
            ? _date(messages.last['sent_at'] ?? messages.last['created_at'])
            : null;
      } else {
        messages = [];
        cursor = null;
      }
      if (!mounted) return;
      final newConvId = _text(selected?['id']);
      setState(() {
        _principalUserId = profile.id;
        _monitorConversations = monitor;
        _directConversations = direct;
        _selectedMonitorConversation = selectedMonitor;
        _selectedDirectConversation = selectedDirect;
        _pendingMessages.clear();
        _messagesCursor = cursor;
        if (monitorMode) {
          _monitorMessages = messages;
        } else {
          _directMessages = messages;
        }
        _loading = false;
      });
      _scrollToBottom();
      unawaited(_subscribeRealtime(conversationId: newConvId));
      if (selected != null &&
          _canSendIn(selected) &&
          !_isContactPlaceholder(selected)) {
        unawaited(_markConversationRead(selected, monitorMode));
      }
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (!background) _error = error.toString();
      });
    }
  }

  Future<void> _loadIncremental() async {
    final monitorMode = _tabController.index == 0;
    final selected = _selectedFor(monitorMode);
    if (selected == null || _isContactPlaceholder(selected)) {
      await _load(background: true);
      return;
    }
    try {
      final api = BackendApiClient.instance;
      final convId = _text(selected['id']);
      // Refresh conversation lists for unread count updates.
      final results = await Future.wait<Object>([
        _safeChatRows(() => api.getUnifiedChatConversations(monitor: true)),
        _safeChatRows(() => api.getUnifiedChatContacts(role: _leadershipRole)),
      ]);
      final allConversations = results[0] as List<Map<String, dynamic>>;
      final monitor = allConversations
          .where((row) => _text(row['type']) == 'parent_teacher')
          .toList();
      final directTeacher = allConversations
          .where((row) => _text(row['type']) == 'principal_teacher')
          .toList();
      final directParent = allConversations
          .where((row) => _text(row['type']) == 'principal_parent')
          .toList();
      final contacts = results[1] as List<Map<String, dynamic>>;
      final teacherContacts = contacts
          .where((row) => _text(row['role']).toLowerCase() == 'teacher')
          .toList();
      final parentContacts = contacts
          .where((row) => _text(row['role']).toLowerCase() == 'parent')
          .toList();
      final direct = _mergeDirectConversationsWithContacts(
        directTeacher: directTeacher,
        directParent: directParent,
        teacherContacts: teacherContacts,
        parentContacts: parentContacts,
      );
      monitor.sort((a, b) => _sortTime(b).compareTo(_sortTime(a)));
      final newMessages = await _safeChatRows(
        () => api.getUnifiedChatMessages(
          conversationId: convId,
          sentAfter: _messagesCursor,
        ),
      );
      if (!mounted) return;
      setState(() {
        _monitorConversations = monitor;
        _directConversations = direct;
        _selectedMonitorConversation = _selectRetainedConversation(
          _selectedMonitorConversation,
          _filteredMonitor(monitor),
        );
        _selectedDirectConversation = _selectRetainedConversation(
          _selectedDirectConversation,
          direct,
        );
        if (newMessages.isNotEmpty) {
          final confirmedBodies = newMessages
              .map((m) => _text(m['body'] ?? m['message']))
              .toSet();
          _pendingMessages.removeWhere(
            (p) =>
                p['_pending'] == true &&
                confirmedBodies.contains(_text(p['body'] ?? p['message'])),
          );
          final current = _messagesFor(monitorMode);
          final updated = mergeChatMessagesByIdentity(current, newMessages);
          if (monitorMode) {
            _monitorMessages = updated;
          } else {
            _directMessages = updated;
          }
          _messagesCursor =
              _date(
                newMessages.last['sent_at'] ?? newMessages.last['created_at'],
              ) ??
              _messagesCursor;
        }
      });
      if (newMessages.isNotEmpty) {
        _scrollToBottom();
        if (_canSendIn(selected)) {
          unawaited(
            BackendApiClient.instance.markUnifiedChatConversationRead(convId),
          );
        }
      }
    } on Object catch (_) {
      // Silent — next Realtime event retries.
    }
  }

  Future<List<Map<String, dynamic>>> _safeChatRows(
    Future<List<Map<String, dynamic>>> Function() load,
  ) async {
    try {
      return await load();
    } on Object catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }

  Map<String, dynamic>? _selectRetainedConversation(
    Map<String, dynamic>? selected,
    List<Map<String, dynamic>> source,
  ) {
    final selectedId = _text(selected?['id']);
    if (selectedId.isEmpty) return null;
    for (final row in source) {
      if (_text(row['id']) == selectedId) return row;
    }
    return null;
  }

  Map<String, dynamic>? _selectedFor(bool monitorMode) =>
      monitorMode ? _selectedMonitorConversation : _selectedDirectConversation;

  List<Map<String, dynamic>> _messagesFor(bool monitorMode) =>
      monitorMode ? _monitorMessages : _directMessages;

  void _selectFor(bool monitorMode, Map<String, dynamic>? row) {
    if (monitorMode) {
      _selectedMonitorConversation = row;
    } else {
      _selectedDirectConversation = row;
    }
  }

  void _clearMessagesFor(bool monitorMode) {
    if (monitorMode) {
      _monitorMessages = const [];
    } else {
      _directMessages = const [];
    }
    _pendingMessages.clear();
    _messagesCursor = null;
  }

  void _zeroUnreadFor(bool monitorMode, String conversationId) {
    List<Map<String, dynamic>> updateRows(List<Map<String, dynamic>> rows) {
      return rows
          .map(
            (row) => _text(row['id']) == conversationId
                ? {...row, 'unread_count': 0, 'unread_for_current_user': 0}
                : row,
          )
          .toList();
    }

    if (monitorMode) {
      _monitorConversations = updateRows(_monitorConversations);
      if (_text(_selectedMonitorConversation?['id']) == conversationId) {
        _selectedMonitorConversation = {
          ...?_selectedMonitorConversation,
          'unread_count': 0,
          'unread_for_current_user': 0,
        };
      }
    } else {
      _directConversations = updateRows(_directConversations);
      if (_text(_selectedDirectConversation?['id']) == conversationId) {
        _selectedDirectConversation = {
          ...?_selectedDirectConversation,
          'unread_count': 0,
          'unread_for_current_user': 0,
        };
      }
    }
  }

  Future<void> _markConversationRead(
    Map<String, dynamic> conversation,
    bool monitorMode,
  ) async {
    if (_isContactPlaceholder(conversation)) return;
    final conversationId = _text(conversation['id']);
    if (conversationId.isEmpty) return;
    try {
      await BackendApiClient.instance.markUnifiedChatConversationRead(
        conversationId,
      );
    } on Object catch (_) {
      // Keep the UI responsive; the next refresh can retry.
    }
    if (!mounted) return;
    setState(() => _zeroUnreadFor(monitorMode, conversationId));
  }

  List<Map<String, dynamic>> _filteredMonitor([
    List<Map<String, dynamic>>? source,
  ]) {
    final query = _searchController.text.trim().toLowerCase();
    return (source ?? _monitorConversations).where((row) {
      final teacher = _name(
        _map(row['teacher']),
        fallback: _text(row['teacher_id']),
      );
      final parent = _name(
        _map(row['parent']),
        fallback: _text(row['parent_id']),
      );
      final student = _name(
        _map(row['student']),
        fallback: _text(row['student_id']),
      );
      final haystack = '$teacher $parent $student ${_text(row['last_message'])}'
          .toLowerCase();
      if (query.isNotEmpty && !haystack.contains(query)) return false;
      if (_teacherFilter.isNotEmpty &&
          _text(row['teacher_id']) != _teacherFilter) {
        return false;
      }
      if (_parentFilter.isNotEmpty &&
          _text(row['parent_id']) != _parentFilter) {
        return false;
      }
      if (_studentFilter.isNotEmpty &&
          _text(row['student_id']) != _studentFilter) {
        return false;
      }
      if (_monitorClassFilter.isNotEmpty &&
          _text(row['class_label']) != _monitorClassFilter) {
        return false;
      }
      if (_unreadOnly &&
          (int.tryParse('${row['unread_count'] ?? 0}') ?? 0) == 0) {
        return false;
      }
      if (_dateFilter != null) {
        final last = _date(row['last_message_at']);
        if (last == null ||
            last.year != _dateFilter!.year ||
            last.month != _dateFilter!.month ||
            last.day != _dateFilter!.day) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  // ── Send with optimistic UI ────────────────────────────────────────────────

  Future<void> _send() async {
    final monitorMode = _tabController.index == 0;
    final conversation = _selectedFor(monitorMode);
    final body = _messageController.text.trim();
    if (conversation == null || body.isEmpty || !_canSendIn(conversation)) {
      return;
    }

    final optimistic = <String, dynamic>{
      'id': 'pending-${DateTime.now().millisecondsSinceEpoch}',
      'body': body,
      'message': body,
      'sender_user_id': _principalUserId,
      'sender_id': _principalUserId,
      'sent_at': DateTime.now().toUtc().toIso8601String(),
      'is_read': false,
      '_pending': true,
    };

    setState(() {
      _sending = true;
      _pendingMessages.add(optimistic);
    });
    _messageController.clear();
    _scrollToBottom();

    try {
      var conversationId = _text(conversation['id']);
      if (_isContactPlaceholder(conversation)) {
        final created = await BackendApiClient.instance
            .createUnifiedChatConversation(
              type: _text(conversation['type'], fallback: 'principal_teacher'),
              teacherId: _text(conversation['teacher_id']),
              parentId: _text(conversation['parent_id']),
              studentId: _text(conversation['student_id']),
              title: _directTitle(conversation),
            );
        conversationId = _text(created['id']);
      }
      await BackendApiClient.instance.sendUnifiedChatMessage(
        conversationId: conversationId,
        body: body,
      );
      await _load(background: true);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _pendingMessages.removeWhere((m) => m == optimistic);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send message: $error'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _startDirect(Map<String, dynamic> source, String target) async {
    final teacherId = target == 'teacher' ? _text(source['teacher_id']) : '';
    final parentId = target == 'parent' ? _text(source['parent_id']) : '';
    if (teacherId.isEmpty && parentId.isEmpty) return;
    final created = await BackendApiClient.instance
        .createUnifiedChatConversation(
          type: target == 'teacher' ? 'principal_teacher' : 'principal_parent',
          teacherId: teacherId,
          parentId: parentId,
          studentId: _text(source['student_id']),
          title: target == 'teacher'
              ? _name(_map(source['teacher']), fallback: 'Teacher')
              : _name(_map(source['parent']), fallback: 'Parent'),
        );
    setState(() {
      _tabController.index = 1;
      _selectedDirectConversation = created;
      _directMessages = const [];
      _pendingMessages.clear();
      _messagesCursor = null;
    });
    await _load();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 840;
    final hasSelection = _tabController.index == 0
        ? _selectedMonitorConversation != null
        : _selectedDirectConversation != null;
    return SchoolDeskModuleScaffold(
      title: 'Messages',
      subtitle: 'Monitor parent-teacher chats and message staff or parents',
      drawer: PrincipalDrawer(
        selectedIndex: PrincipalNav.messages,
        onDestinationSelected: (_) {},
      ),
      floatingActionButton: (!isWide && hasSelection)
          ? null
          : DashboardFabWidget(
              role: _leadershipRole == 'coordinator'
                  ? DashboardRole.coordinator
                  : DashboardRole.principal,
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      bottom: TabBar(
        controller: _tabController,
        onTap: (_) {
          setState(() {});
          _load(background: true);
        },
        tabs: const [
          Tab(icon: Icon(Icons.visibility_rounded), text: 'Monitor'),
          Tab(icon: Icon(Icons.chat_rounded), text: 'Direct'),
        ],
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    return TabBarView(
      controller: _tabController,
      children: [
        _workspace(_filteredMonitor(), monitorMode: true),
        _workspace(_filteredDirect(), monitorMode: false),
      ],
    );
  }

  Widget _workspace(
    List<Map<String, dynamic>> conversations, {
    required bool monitorMode,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 840;
        final list = Column(
          children: [
            if (monitorMode) _filters() else _directFilters(),
            Expanded(child: _conversationList(conversations, monitorMode)),
          ],
        );
        final chat = _chatPane(monitorMode: monitorMode, showBackButton: !wide);
        if (wide) {
          return Row(
            children: [
              SizedBox(width: 380, child: list),
              VerticalDivider(width: 1, color: context.appTheme.outlineVariant),
              Expanded(child: chat),
            ],
          );
        }
        return _selectedFor(monitorMode) == null ? list : chat;
      },
    );
  }

  Widget _filters() {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search_rounded),
              labelText: 'Search teacher, parent, student, message',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 46),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _filterMenu(
                    label: 'Teacher',
                    value: _teacherFilter,
                    options: {
                      for (final row in _monitorConversations)
                        _text(row['teacher_id']): _name(
                          _map(row['teacher']),
                          fallback: 'Teacher',
                        ),
                    },
                    onChanged: (value) =>
                        setState(() => _teacherFilter = value),
                  ),
                  const SizedBox(width: 8),
                  _filterMenu(
                    label: 'Parent',
                    value: _parentFilter,
                    options: {
                      for (final row in _monitorConversations)
                        _text(row['parent_id']): _name(
                          _map(row['parent']),
                          fallback: 'Parent',
                        ),
                    },
                    onChanged: (value) => setState(() => _parentFilter = value),
                  ),
                  const SizedBox(width: 8),
                  _filterMenu(
                    label: 'Student',
                    value: _studentFilter,
                    options: {
                      for (final row in _monitorConversations)
                        _text(row['student_id']): _name(
                          _map(row['student']),
                          fallback: 'Student',
                        ),
                    },
                    onChanged: (value) =>
                        setState(() => _studentFilter = value),
                  ),
                  const SizedBox(width: 8),
                  _filterMenu(
                    label: 'Class',
                    value: _monitorClassFilter,
                    options: {
                      for (final row in _monitorConversations)
                        _text(row['class_label']): _text(
                          row['class_label'],
                          fallback: 'Class',
                        ),
                    },
                    onChanged: (value) =>
                        setState(() => _monitorClassFilter = value),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('Unread'),
                    selected: _unreadOnly,
                    backgroundColor: context.appTheme.surface,
                    selectedColor: context.appTheme.primaryContainer,
                    checkmarkColor: context.appTheme.primary,
                    side: BorderSide(color: context.appTheme.outlineVariant),
                    labelStyle: TextStyle(
                      color: _unreadOnly
                          ? context.appTheme.primary
                          : context.appTheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                    onSelected: (value) => setState(() => _unreadOnly = value),
                  ),
                  const SizedBox(width: 8),
                  ActionChip(
                    avatar: Icon(
                      Icons.calendar_month_rounded,
                      size: 18,
                      color: context.appTheme.primary,
                    ),
                    label: Text(
                      _dateFilter == null
                          ? 'Date'
                          : DateFormat('dd MMM').format(_dateFilter!),
                    ),
                    backgroundColor: context.appTheme.surface,
                    side: BorderSide(color: context.appTheme.outlineVariant),
                    labelStyle: TextStyle(
                      color: context.appTheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _dateFilter ?? DateTime.now(),
                        firstDate: DateTime.now().subtract(
                          const Duration(days: 365),
                        ),
                        lastDate: DateTime.now().add(const Duration(days: 30)),
                      );
                      if (picked != null) setState(() => _dateFilter = picked);
                    },
                  ),
                  if (_dateFilter != null) ...[
                    const SizedBox(width: 8),
                    ActionChip(
                      label: const Text('Clear date'),
                      backgroundColor: context.appTheme.surface,
                      side: BorderSide(color: context.appTheme.outlineVariant),
                      labelStyle: TextStyle(
                        color: context.appTheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                      onPressed: () => setState(() => _dateFilter = null),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _filteredDirect() {
    return _directConversations.where((row) {
      if (_directRoleLabel(row).toLowerCase() != _directRoleFilter) {
        return false;
      }
      if (_directClassFilter.isEmpty) return true;
      final sections = _classSectionsFor(row).toSet();
      return sections.contains(_directClassFilter);
    }).toList();
  }

  Widget _directFilters() {
    final theme = context.appTheme;
    final teacherCount = _directConversations
        .where((row) => _directRoleLabel(row) == 'Teacher')
        .length;
    final parentCount = _directConversations
        .where((row) => _directRoleLabel(row) == 'Parent')
        .length;
    final classOptions = <String>{
      for (final row in _directConversations) ..._classSectionsFor(row),
    }.toList()..sort();
    return Padding(
      padding: const EdgeInsets.all(10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _directRoleChip(
              label: 'Teachers ($teacherCount)',
              icon: Icons.badge_outlined,
              selected: _directRoleFilter == 'teacher',
              theme: theme,
              onSelected: () => setState(() => _directRoleFilter = 'teacher'),
            ),
            const SizedBox(width: 8),
            _directRoleChip(
              label: 'Parents ($parentCount)',
              icon: Icons.family_restroom_rounded,
              selected: _directRoleFilter == 'parent',
              theme: theme,
              onSelected: () => setState(() => _directRoleFilter = 'parent'),
            ),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              tooltip: 'Filter contacts by class',
              onSelected: (value) => setState(() => _directClassFilter = value),
              itemBuilder: (_) => [
                const PopupMenuItem(value: '', child: Text('All classes')),
                ...classOptions.map(
                  (value) => PopupMenuItem(value: value, child: Text(value)),
                ),
              ],
              child: Chip(
                avatar: Icon(
                  Icons.class_rounded,
                  size: 18,
                  color: _directClassFilter.isEmpty
                      ? theme.onSurfaceVariant
                      : theme.primary,
                ),
                label: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 160),
                  child: Text(
                    _directClassFilter.isEmpty
                        ? 'All classes'
                        : _directClassFilter,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                backgroundColor: _directClassFilter.isEmpty
                    ? theme.surface
                    : theme.primaryContainer,
                side: BorderSide(
                  color: _directClassFilter.isEmpty
                      ? theme.outlineVariant
                      : theme.primary,
                ),
                labelStyle: TextStyle(
                  color: _directClassFilter.isEmpty
                      ? theme.onSurface
                      : theme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _directRoleChip({
    required String label,
    required IconData icon,
    required bool selected,
    required dynamic theme,
    required VoidCallback onSelected,
  }) {
    return ChoiceChip(
      avatar: Icon(
        icon,
        size: 18,
        color: selected ? theme.primary : theme.onSurfaceVariant,
      ),
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      backgroundColor: theme.surface,
      selectedColor: theme.primaryContainer,
      side: BorderSide(color: selected ? theme.primary : theme.outlineVariant),
      checkmarkColor: theme.primary,
      labelStyle: TextStyle(
        color: selected ? theme.primary : theme.onSurface,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _filterMenu({
    required String label,
    required String value,
    required Map<String, String> options,
    required ValueChanged<String> onChanged,
  }) {
    final cleanOptions = Map<String, String>.fromEntries(
      options.entries.where((entry) => entry.key.isNotEmpty),
    );
    return PopupMenuButton<String>(
      tooltip: label,
      onSelected: onChanged,
      itemBuilder: (context) => [
        const PopupMenuItem(value: '', child: Text('All')),
        ...cleanOptions.entries.map(
          (entry) => PopupMenuItem(value: entry.key, child: Text(entry.value)),
        ),
      ],
      child: Chip(
        avatar: Icon(
          Icons.filter_list_rounded,
          size: 18,
          color: context.appTheme.primary,
        ),
        label: Text(
          value.isEmpty ? label : cleanOptions[value] ?? label,
          style: TextStyle(
            color: value.isEmpty
                ? context.appTheme.onSurface
                : context.appTheme.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: value.isEmpty
            ? context.appTheme.surface
            : context.appTheme.primaryContainer,
        side: BorderSide(
          color: value.isEmpty
              ? context.appTheme.outlineVariant
              : context.appTheme.primary,
        ),
        deleteIconColor: context.appTheme.primary,
        onDeleted: value.isEmpty ? null : () => onChanged(''),
      ),
    );
  }

  Widget _conversationList(
    List<Map<String, dynamic>> conversations,
    bool monitorMode,
  ) {
    if (conversations.isEmpty) {
      return Center(
        child: Text(
          monitorMode
              ? 'No parent-teacher chats found.'
              : 'No direct chats yet.',
        ),
      );
    }
    return ListView.separated(
      itemCount: conversations.length,
      separatorBuilder: (_, __) =>
          Divider(height: 1, color: context.appTheme.outlineVariant),
      itemBuilder: (context, index) {
        final row = conversations[index];
        final selected =
            _text(row['id']) == _text(_selectedFor(monitorMode)?['id']);
        final title = monitorMode ? _monitorTitle(row) : _directTitle(row);
        final subtitle = monitorMode
            ? _studentLine(row)
            : _isContactPlaceholder(row)
            ? _text(row['type'], fallback: 'direct') == 'principal_teacher'
                  ? _directContactHint(row, 'Teacher contact')
                  : _directContactHint(row, 'Parent contact')
            : _text(row['last_message'], fallback: 'Direct conversation');
        final unread = int.tryParse('${row['unread_count'] ?? 0}') ?? 0;
        return ListTile(
          selected: selected,
          leading: CircleAvatar(
            backgroundColor: monitorMode
                ? const Color(0xFFF5F3FF)
                : _directRoleLabel(row) == 'Teacher'
                ? const Color(0xFFDCFCE7)
                : const Color(0xFFDBEAFE),
            foregroundColor: monitorMode
                ? const Color(0xFF7C3AED)
                : _directRoleLabel(row) == 'Teacher'
                ? const Color(0xFF16A34A)
                : const Color(0xFF2563EB),
            child: Text(
              _initials(title),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          title: Text(
            monitorMode ? title : '${_directRoleLabel(row)}: $title',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            monitorMode
                ? '${_studentLine(row)} - ${_text(row['last_message']).isEmpty ? 'Parent-teacher chat' : _text(row['last_message'])}'
                : _text(row['last_message']).isEmpty
                ? subtitle
                : _text(row['last_message']),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _time(_date(row['last_message_at'])),
                style: const TextStyle(fontSize: 11),
              ),
              if (unread > 0)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: context.appTheme.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$unread',
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
            ],
          ),
          onTap: () async {
            final conversationId = _text(row['id']);
            setState(() {
              _selectFor(monitorMode, {
                ...row,
                'unread_count': 0,
                'unread_for_current_user': 0,
              });
              _zeroUnreadFor(monitorMode, conversationId);
              _clearMessagesFor(monitorMode);
            });
            unawaited(_subscribeRealtime(conversationId: conversationId));
            if (!_isContactPlaceholder(row)) {
              await _markConversationRead(row, monitorMode);
              await _load(background: true);
            }
          },
        );
      },
    );
  }

  Widget _chatPane({required bool monitorMode, required bool showBackButton}) {
    final conversation = _selectedFor(monitorMode);
    if (conversation == null) {
      return const Center(child: Text('Select a conversation.'));
    }
    final canSend = _canSendIn(conversation);
    final baseMessages = _messagesFor(monitorMode);
    final displayed = canSend
        ? [...baseMessages, ..._pendingMessages]
        : baseMessages;
    return Column(
      children: [
        ListTile(
          leading: showBackButton
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  tooltip: 'Back to chats',
                  onPressed: () => setState(() {
                    _selectFor(monitorMode, null);
                    _clearMessagesFor(monitorMode);
                    unawaited(_subscribeRealtime());
                  }),
                )
              : CircleAvatar(
                  child: Text(
                    _initials(
                      monitorMode
                          ? _monitorTitle(conversation)
                          : _directTitle(conversation),
                    ),
                  ),
                ),
          title: Text(
            monitorMode
                ? _monitorTitle(conversation)
                : _directTitle(conversation),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            monitorMode
                ? 'Class and student context · replies stay in this thread'
                : 'Chatting with ${_directRoleLabel(conversation)}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: monitorMode
              ? PopupMenuButton<String>(
                  tooltip: 'Start a separate direct chat',
                  onSelected: (target) => _startDirect(conversation, target),
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'teacher',
                      child: ListTile(
                        leading: Icon(Icons.school_rounded),
                        title: Text('Message teacher separately'),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'parent',
                      child: ListTile(
                        leading: Icon(Icons.family_restroom_rounded),
                        title: Text('Message parent separately'),
                      ),
                    ),
                  ],
                )
              : null,
        ),
        if (monitorMode)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: context.appTheme.warningContainer,
            child: Text(
              'You are viewing the original class conversation. Replies are visible to the teacher and parent.',
              style: TextStyle(color: context.appTheme.onSurface),
            ),
          ),
        Expanded(
          child: ChatWallpaperBackground(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(vertical: 12),
              itemCount: displayed.length,
              itemBuilder: (context, index) {
                final message = displayed[index];
                final isPending = message['_pending'] == true;
                final senderRole = _messageRole(message, conversation);
                final senderName = _messageSenderName(message, conversation);
                final mine =
                    _text(message['sender_user_id'] ?? message['sender_id']) ==
                    _principalUserId;
                return Opacity(
                  opacity: isPending ? 0.6 : 1.0,
                  child: ChatBubbleWidget(
                    messageText: _text(message['body'] ?? message['message']),
                    time: isPending
                        ? '...'
                        : _time(
                            _date(message['sent_at'] ?? message['created_at']),
                          ),
                    isMe: mine,
                    isRead: message['is_read'] == true,
                    senderLabel: senderName,
                    senderRoleLabel: _roleTitle(senderRole),
                  ),
                );
              },
            ),
          ),
        ),
        if (canSend)
          ChatInputBar(
            controller: _messageController,
            isSending: _sending,
            onSend: _send,
            placeholder: monitorMode
                ? 'Reply in this class chat'
                : 'Type a direct message',
          ),
      ],
    );
  }

  bool _canSendIn(Map<String, dynamic> conversation) {
    if (_text(conversation['type']) == 'parent_teacher') return true;
    final owner = _text(
      conversation['leader_id'] ?? conversation['created_by'],
    );
    return owner.isEmpty || owner == _principalUserId;
  }

  List<Map<String, dynamic>> _mergeDirectConversationsWithContacts({
    required List<Map<String, dynamic>> directTeacher,
    required List<Map<String, dynamic>> directParent,
    required List<dynamic> teacherContacts,
    required List<dynamic> parentContacts,
  }) {
    final uniqueRows = <String, Map<String, dynamic>>{};
    for (final row in directTeacher.where(_canSendIn)) {
      final key = 'teacher_${_text(row['teacher_id'])}';
      final existing = uniqueRows[key];
      if (existing == null || _sortTime(row) > _sortTime(existing)) {
        uniqueRows[key] = Map<String, dynamic>.from(row);
      }
    }
    for (final row in directParent.where(_canSendIn)) {
      final key =
          'parent_${_text(row['parent_id'])}_${_text(row['student_id'])}';
      final existing = uniqueRows[key];
      if (existing == null || _sortTime(row) > _sortTime(existing)) {
        uniqueRows[key] = Map<String, dynamic>.from(row);
      }
    }
    final rows = uniqueRows.values.toList();
    final existingTeacherIds = rows
        .where((row) => _text(row['type']) == 'principal_teacher')
        .map((row) => _text(row['teacher_id']))
        .where((id) => id.isNotEmpty)
        .toSet();
    final existingParentKeys = rows
        .where((row) => _text(row['type']) == 'principal_parent')
        .map((row) => '${_text(row['parent_id'])}_${_text(row['student_id'])}')
        .where((id) => id != '_')
        .toSet();

    for (final contact in teacherContacts) {
      final id = _contactId(contact);
      if (id.isEmpty || existingTeacherIds.contains(id)) continue;
      final name = _contactName(contact);
      rows.add({
        'id': 'contact-teacher-$id',
        'type': 'principal_teacher',
        'teacher_id': id,
        'parent_id': '',
        'student_id': '',
        'last_message': '',
        'last_message_at': '',
        'unread_count': 0,
        'teacher': {
          'id': id,
          'first_name': _contactFirstName(contact),
          'last_name': _contactLastName(contact),
          'name': name,
        },
        'class_sections': contact is Map
            ? contact['class_sections'] ?? const []
            : const [],
        'is_contact_placeholder': true,
      });
    }

    for (final contact in parentContacts) {
      final id = _contactId(contact);
      final studentId = contact is Map ? _text(contact['student_id']) : '';
      final parentKey = '${id}_$studentId';
      if (id.isEmpty ||
          studentId.isEmpty ||
          existingParentKeys.contains(parentKey)) {
        continue;
      }
      final name = _contactName(contact);
      rows.add({
        'id': 'contact-parent-$id-$studentId',
        'type': 'principal_parent',
        'teacher_id': '',
        'parent_id': id,
        'student_id': studentId,
        'section_id': contact is Map ? contact['section_id'] ?? '' : '',
        'class_label': contact is Map ? contact['class_label'] ?? '' : '',
        'last_message': '',
        'last_message_at': '',
        'unread_count': 0,
        'parent': {'id': id, 'name': name, 'full_name': name},
        'student': {
          'id': studentId,
          'name': contact is Map
              ? _text(contact['student_name'], fallback: 'Student')
              : 'Student',
        },
        'class_sections': contact is Map
            ? contact['class_sections'] ?? const []
            : const [],
        'is_contact_placeholder': true,
      });
    }
    return rows;
  }

  bool _isContactPlaceholder(Map<String, dynamic> row) =>
      row['is_contact_placeholder'] == true;

  String _contactId(dynamic contact) {
    if (contact is Map) return _text(contact['id']);
    try {
      return _text(contact.id);
    } on Object catch (_) {
      return '';
    }
  }

  String _contactName(dynamic contact) {
    if (contact is Map) {
      return _text(
        contact['name'] ?? contact['full_name'],
        fallback: [
          _text(contact['first_name']),
          _text(contact['last_name']),
        ].where((part) => part.isNotEmpty).join(' '),
      );
    }
    try {
      return _text(contact.name, fallback: _text(contact.username));
    } on Object catch (_) {
      return [
        _contactFirstName(contact),
        _contactLastName(contact),
      ].where((part) => part.isNotEmpty).join(' ');
    }
  }

  String _contactFirstName(dynamic contact) {
    if (contact is Map) return _text(contact['first_name']);
    try {
      return _text(contact.firstName);
    } on Object catch (_) {
      return '';
    }
  }

  String _contactLastName(dynamic contact) {
    if (contact is Map) return _text(contact['last_name']);
    try {
      return _text(contact.lastName);
    } on Object catch (_) {
      return '';
    }
  }

  String _monitorTitle(Map<String, dynamic> row) {
    final people = [
      _name(_map(row['teacher']), fallback: 'Teacher'),
      _name(_map(row['parent']), fallback: 'Parent'),
    ].join(' / ');
    final context = ChatContext.fromMap(row).displayLabel;
    return context.isEmpty ? people : '$people · $context';
  }

  String _directTitle(Map<String, dynamic> row) {
    final type = _text(row['type']);
    if (type == 'principal_teacher') {
      return _name(_map(row['teacher']), fallback: 'Teacher');
    }
    final parent = _name(_map(row['parent']), fallback: 'Parent');
    final student = _studentLine(row);
    return student == 'Student' ? parent : '$parent · $student';
  }

  String _directRoleLabel(Map<String, dynamic> row) {
    return _text(row['type']) == 'principal_teacher' ? 'Teacher' : 'Parent';
  }

  List<String> _classSectionsFor(Map<String, dynamic> row) {
    final raw = row['class_sections'];
    final values = raw is Iterable
        ? raw.map(_text).where((value) => value.isNotEmpty).toSet().toList()
        : <String>[];
    final classLabel = ChatContext.fromMap(row).classLabel;
    if (classLabel.isNotEmpty) values.add(classLabel);
    return values.toSet().toList()..sort();
  }

  String _directContactHint(Map<String, dynamic> row, String roleLabel) {
    final classes = _classSectionsFor(row);
    final classLabel = _text(row['class_label']);
    final classDetail = classLabel.isNotEmpty
        ? ' · $classLabel'
        : classes.isEmpty
        ? ''
        : ' · ${classes.join(', ')}';
    final student = _text(row['student_name']);
    final studentDetail = student.isEmpty ? '' : ' · $student';
    return '$roleLabel$classDetail$studentDetail · tap to start direct chat';
  }

  String _messageRole(
    Map<String, dynamic> message,
    Map<String, dynamic> conversation,
  ) {
    final senderId = _text(message['sender_user_id'] ?? message['sender_id']);
    if (senderId == _principalUserId) return _leadershipRole;
    final role = _text(message['sender_role']).toLowerCase();
    if (role.contains('teacher')) return 'teacher';
    if (role.contains('parent')) return 'parent';
    if (senderId == _text(conversation['parent_id'])) return 'parent';
    return 'teacher';
  }

  String _messageSenderName(
    Map<String, dynamic> message,
    Map<String, dynamic> conversation,
  ) {
    final explicit = _text(message['sender_name']);
    if (explicit.isNotEmpty && !explicit.contains('@')) return explicit;
    final role = _messageRole(message, conversation);
    if (role == 'parent') {
      return _name(_map(conversation['parent']), fallback: 'Parent');
    }
    return _name(_map(conversation['teacher']), fallback: 'Teacher');
  }

  String _roleTitle(String role) {
    return switch (role) {
      'teacher' => 'Teacher',
      'parent' => 'Parent',
      'principal' => 'Principal',
      'coordinator' => 'Coordinator',
      _ => 'Sender',
    };
  }

  String _studentLine(Map<String, dynamic> row) {
    final context = ChatContext.fromMap(row);
    if (context.displayLabel.isNotEmpty) return context.displayLabel;
    final student = _map(row['student']);
    return _name(
      student,
      fallback: _text(
        row['student_name'],
        fallback: _text(row['student_id'], fallback: 'Student'),
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }
}

Map<String, dynamic> _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

String _text(Object? value, {String fallback = ''}) {
  final text = '${value ?? ''}'.trim();
  return text.isEmpty ? fallback : text;
}

String _name(Map<String, dynamic> row, {String fallback = ''}) {
  final full = _text(row['name'] ?? row['full_name']);
  if (full.isNotEmpty) return full;
  final parts = [
    _text(row['first_name']),
    _text(row['last_name']),
  ].where((part) => part.isNotEmpty).join(' ');
  return parts.isEmpty ? fallback : parts;
}

String _initials(String value) {
  final words = value.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return 'C';
  return words.take(2).map((w) => w[0].toUpperCase()).join();
}

DateTime? _date(Object? value) => DateTime.tryParse(_text(value));

int _sortTime(Map<String, dynamic> row) =>
    _date(row['last_message_at'])?.millisecondsSinceEpoch ?? 0;

String _time(DateTime? value) {
  if (value == null) return '';
  return DateFormat('h:mm a').format(value.toLocal());
}
