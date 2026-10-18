import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:schooldesk1/modules/communication/domain/chat_workspace_repository.dart';

String chatValue(Object? value) => '${value ?? ''}'.trim();
Map<String, dynamic> chatMap(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : {};
List<Map<String, dynamic>> chatRows(Object? value) => value is List
    ? value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
    : [];
String chatKey(Map<String, dynamic> row) =>
    chatValue(row['_draft_key']).isNotEmpty
    ? chatValue(row['_draft_key'])
    : chatValue(row['id']).isNotEmpty && row['_contact'] != true
    ? 'conversation:${row['id']}'
    : 'contact:${row['type']}:${row['id']}:${row['student_id']}';
String chatPersonName(Object? value) {
  final row = chatMap(value);
  return chatValue(row['name'] ?? row['full_name']).isNotEmpty
      ? chatValue(row['name'] ?? row['full_name'])
      : [
          chatValue(row['first_name']),
          chatValue(row['last_name']),
        ].where((s) => s.isNotEmpty).join(' ');
}

String chatContext(Map<String, dynamic> row) => [
  chatValue(row['student_name'] ?? chatMap(row['student'])['name']),
  chatValue(row['class_label']),
].where((s) => s.isNotEmpty).join(' · ');
String chatName(Map<String, dynamic> row, String role, {bool monitor = false}) {
  String first(List<Object?> values) =>
      values.map(chatValue).firstWhere((s) => s.isNotEmpty, orElse: () => '');
  final parent = first([row['parent_name'], chatPersonName(row['parent'])]);
  final teacher = first([row['teacher_name'], chatPersonName(row['teacher'])]);
  final leader = first([row['leader_name'], chatPersonName(row['leader'])]);
  if (monitor) return '$parent ↔ $teacher';
  if (row['_contact'] == true) return chatPersonName(row);
  return first([
    row['contact_name'],
    row['other_name'],
    if (role == 'parent') teacher,
    if (role == 'teacher') parent,
    if (role != 'parent' && role != 'teacher') ...[teacher, parent],
    leader,
    row['name'],
  ]);
}

String chatPhoto(Map<String, dynamic> row, String role, {bool parent = false}) {
  if (row['_contact'] == true) return chatValue(row['avatar_url']);
  if (parent ||
      (role != 'parent' &&
          chatValue(row['parent_id']).isNotEmpty &&
          (role == 'teacher' ||
              chatValue(row['type']) == 'principal_parent'))) {
    return chatValue(
      row['parent_avatar_url'] ?? chatMap(row['parent'])['avatar_url'],
    );
  }
  return chatValue(
    row['contact_avatar_url'] ??
        row['teacher_avatar_url'] ??
        chatMap(row['teacher'])['avatar_url'] ??
        row['leader_avatar_url'] ??
        chatMap(row['leader'])['avatar_url'] ??
        row['avatar_url'],
  );
}

String chatContactRole(Map<String, dynamic> row, String role) {
  final contactRole = chatValue(row['contact_role']);
  if (contactRole == 'co_teacher') return 'Co-teacher';
  if (contactRole == 'class_teacher') return 'Class teacher';
  final value = chatValue(
    row['role'] ?? row['contact_role'] ?? row['leader_role'],
  );
  if (value.isNotEmpty) return value.replaceAll('_', ' ');
  if (chatValue(row['leader_id']).isNotEmpty) return 'School leadership';
  return role == 'parent'
      ? 'Teacher'
      : chatValue(row['parent_id']).isNotEmpty
      ? 'Parent'
      : 'Teacher';
}

/// Owns account, child and thread generations so obsolete responses never
/// replace the active context. Server identities alone reconcile messages.
class ChatWorkspaceController extends ChangeNotifier {
  ChatWorkspaceController(
    this.repository,
    this.role, {
    this.initialConversationId = '',
    this.initialStudentId = '',
    this.onUnreadRefresh,
  });
  final String initialConversationId, initialStudentId;
  final ChatWorkspaceRepository repository;
  final Future<void> Function()? onUnreadRefresh;
  final String role;
  bool get leadership => role == 'principal' || role == 'coordinator';
  bool loading = true,
      messagesLoading = false,
      olderLoading = false,
      hasOlder = false,
      hasMoreInbox = false;
  bool monitor = false, contactsOpen = false, unreadOnly = false;
  String studentId = '',
      category = 'All',
      search = '',
      classFilter = '',
      teacherFilter = '',
      personFilter = '';
  DateTime? dateFilter;
  Object? error, messageError;
  ChatConnectionStatus connection = ChatConnectionStatus.connecting;
  List<Map<String, dynamic>> children = [],
      contacts = [],
      conversations = [],
      messages = [];
  Map<String, dynamic>? selected;
  String draft = '';
  int messageRevision = 0, ownSendRevision = 0;
  bool threadVisibleAtBottom = true;
  int _scope = 0, _thread = 0, _inboxPage = 1, _inboxGeneration = 0;
  bool _disposed = false, _refreshing = false, _refreshAgain = false;
  String _account = '';
  Map<String, dynamic> _olderCursor = {};
  final List<Map<String, dynamic>> _threadHistory = [];
  final Map<String, String> _drafts = {};
  Timer? _draftTimer, _searchTimer;
  String _lastSearch = '';
  StreamSubscription<void>? _events;
  StreamSubscription<ChatConnectionStatus>? _connections;

  Future<void> start() async {
    _account = repository.accountScope;
    _events = repository.invalidations.listen((_) => refresh());
    _connections = repository.connectionChanges.listen((value) {
      connection = value;
      _emit();
    });
    unawaited(
      repository.watch().catchError((Object e) {
        connection = ChatConnectionStatus.offline;
        _emit();
      }),
    );
    studentId = initialStudentId;
    await initialize();
    if (initialConversationId.isNotEmpty && !_disposed) {
      try {
        final row = await repository.loadConversation(initialConversationId);
        if (_disposed || _account != repository.accountScope) return;
        final linkedChild = chatValue(row['student_id']);
        if (role == 'parent' &&
            linkedChild.isNotEmpty &&
            linkedChild != studentId &&
            children.any((child) => chatValue(child['id']) == linkedChild)) {
          studentId = linkedChild;
          await initialize();
        }
        if (leadership && chatValue(row['type']) == 'parent_teacher') {
          monitor = true;
          await initialize();
        }
        await openThread(row);
      } on Object catch (e) {
        error = e;
        _emit();
      }
    }
  }

  bool _valid(int scope, [int? thread]) =>
      !_disposed &&
      scope == _scope &&
      (thread == null || thread == _thread) &&
      _account == repository.accountScope;
  void _emit() {
    if (!_disposed) notifyListeners();
  }

  void _refreshUnread() {
    if (onUnreadRefresh != null && !_disposed) {
      unawaited(onUnreadRefresh!().catchError((Object _) {}));
    }
  }

  Future<void> initialize() async {
    final scope = ++_scope;
    loading = true;
    error = null;
    _emit();
    try {
      final loaded = role == 'parent'
          ? await repository.loadChildren()
          : <Map<String, dynamic>>[];
      if (!_valid(scope)) return;
      children = loaded;
      if (children.isNotEmpty &&
          !children.any((c) => chatValue(c['id']) == studentId)) {
        studentId = chatValue(children.first['id']);
      }
      await _loadInbox(scope);
    } on Object catch (e) {
      if (_valid(scope)) error = e;
    } finally {
      if (_valid(scope)) {
        loading = false;
        _emit();
      }
    }
  }

  Future<void> _loadInbox(int scope, {bool append = false}) async {
    final generation = ++_inboxGeneration;
    final results = await Future.wait<Object>([
      repository.loadConversations(
        monitor: monitor,
        studentId: studentId,
        search: contactsOpen ? '' : search,
        page: append ? _inboxPage + 1 : 1,
      ),
      repository.loadContacts(studentId: studentId),
    ]);
    if (!_valid(scope) || generation != _inboxGeneration) return;
    var page = chatMap(results[0]);
    var pageNumber = append ? _inboxPage + 1 : 1;
    final rows = append
        ? List<Map<String, dynamic>>.from(conversations)
        : <Map<String, dynamic>>[];
    final seen = rows.map((e) => chatValue(e['id'])).toSet();
    while (true) {
      final batch = chatRows(page['data']);
      final additions = batch
          .where((e) => seen.add(chatValue(e['id'])))
          .toList();
      rows.addAll(additions);
      if (page['has_more'] != true || additions.isEmpty) break;
      pageNumber++;
      page = await repository.loadConversations(
        monitor: monitor,
        studentId: studentId,
        search: contactsOpen ? '' : search,
        page: pageNumber,
      );
      if (!_valid(scope) || generation != _inboxGeneration) return;
    }
    conversations = rows;
    _inboxPage = pageNumber;
    contacts = chatRows(results[1]);
    hasMoreInbox = page['has_more'] == true;
    final contact = selected;
    if (contact != null && contact['_contact'] == true) {
      var match = conversations
          .where((row) => _sameParticipantScope(contact, row))
          .firstOrNull;
      // A direct contact opened from Monitor keeps the monitor inbox intact.
      // Its first queued command must still discover the resulting direct chat.
      if (match == null && (monitor || search.isNotEmpty)) {
        var directPage = 1;
        while (true) {
          final result = await repository.loadConversations(
            monitor: false,
            studentId: chatValue(contact['student_id']),
            page: directPage,
          );
          if (!_valid(scope) || generation != _inboxGeneration) return;
          final batch = chatRows(result['data']);
          match = batch
              .where((row) => _sameParticipantScope(contact, row))
              .firstOrNull;
          if (match != null || result['has_more'] != true || batch.isEmpty) {
            break;
          }
          directPage++;
        }
      }
      if (match != null) {
        selected = {
          ...contact,
          ...match,
          '_contact': false,
          '_draft_key': chatKey(contact),
        };
        unawaited(
          repository
              .watch(conversationId: chatValue(match['id']))
              .catchError((Object _) {}),
        );
      }
    }
    if (selected != null && selected!['_contact'] != true) {
      final canonical = conversations
          .where((row) => chatValue(row['id']) == chatValue(selected!['id']))
          .firstOrNull;
      if (canonical != null) selected = {...selected!, ...canonical};
    }
    error = null;
    _refreshUnread();
  }

  Future<void> refresh() async {
    if (_disposed) return;
    if (_account != repository.accountScope) {
      ++_scope;
      ++_thread;
      selected = null;
      messages = [];
      conversations = [];
      contacts = [];
      children = [];
      _drafts.clear();
      _threadHistory.clear();
      draft = '';
      studentId = '';
      _account = repository.accountScope;
      await initialize();
      return;
    }
    if (_refreshing) {
      _refreshAgain = true;
      return;
    }
    _refreshing = true;
    try {
      do {
        _refreshAgain = false;
        final scope = _scope, thread = _thread;
        await _loadInbox(scope);
        final row = selected;
        if (_valid(scope, thread) && row != null && row['_contact'] != true) {
          await _loadMessages(scope, thread, refresh: true);
          await _loadPending(scope, thread);
        }
        _emit();
      } while (_refreshAgain && !_disposed);
    } on Object catch (e) {
      error = e;
      _emit();
    } finally {
      _refreshing = false;
    }
  }

  Future<void> loadMoreInbox() async {
    if (loading || !hasMoreInbox) return;
    loading = true;
    _emit();
    final scope = _scope;
    try {
      await _loadInbox(scope, append: true);
    } on Object catch (e) {
      if (_valid(scope)) error = e;
    } finally {
      if (_valid(scope)) {
        loading = false;
        _emit();
      }
    }
  }

  Future<void> changeChild(String value) async {
    final scope = ++_scope;
    ++_thread;
    await flushDraft();
    if (!_valid(scope)) return;
    studentId = value;
    selected = null;
    messages = [];
    ++_thread;
    _threadHistory.clear();
    await initialize();
    unawaited(repository.watch());
  }

  Future<void> changeMonitor(bool value) async {
    _threadHistory.clear();
    await closeThread();
    monitor = value;
    contactsOpen = false;
    category = 'All';
    await initialize();
  }

  Future<void> openThread(
    Map<String, dynamic> row, {
    bool nested = false,
  }) async {
    final thread = ++_thread, scope = _scope;
    await flushDraft();
    if (!_valid(scope, thread)) return;
    if (nested && selected != null) {
      _threadHistory.add(Map<String, dynamic>.from(selected!));
    } else {
      _threadHistory.clear();
    }
    selected = Map<String, dynamic>.from(row);
    contactsOpen = false;
    messages = [];
    messageError = null;
    messagesLoading = true;
    hasOlder = false;
    threadVisibleAtBottom = true;
    final key = chatKey(selected!);
    draft = _drafts[key] ?? '';
    _emit();
    unawaited(
      repository
          .watch(
            conversationId: row['_contact'] == true ? '' : chatValue(row['id']),
          )
          .catchError((Object _) {}),
    );
    try {
      final saved = _drafts.containsKey(key)
          ? _drafts[key]!
          : await repository.readDraft(key);
      if (!_valid(scope, thread)) return;
      draft = _drafts[key] ?? saved;
      _drafts[key] = draft;
      _emit();
      if (row['_contact'] != true) await _loadMessages(scope, thread);
      await _loadPending(scope, thread);
    } on Object catch (e) {
      if (_valid(scope, thread)) messageError = e;
    } finally {
      if (_valid(scope, thread)) {
        messagesLoading = false;
        _emit();
      }
    }
  }

  Future<void> _loadMessages(
    int scope,
    int thread, {
    bool refresh = false,
  }) async {
    final id = chatValue(selected?['id']);
    if (id.isEmpty) return;
    final caughtUp = <Map<String, dynamic>>[];
    final canonical = messages
        .where(
          (message) =>
              message['_delivery'] == 'Sent' &&
              chatValue(message['id']).isNotEmpty &&
              !chatValue(message['id']).startsWith('local:'),
        )
        .toList();
    if (refresh && canonical.isNotEmpty) {
      var cursor = <String, dynamic>{
        'sent_at': canonical.last['sent_at'] ?? canonical.last['created_at'],
        'id': canonical.last['id'],
      };
      while (true) {
        final page = await repository.loadMessages(
          conversationId: id,
          mode: 'after',
          cursorSentAt: chatValue(cursor['sent_at']),
          cursorId: chatValue(cursor['id']),
        );
        if (!_valid(scope, thread)) return;
        final batch = chatRows(page['data']);
        caughtUp.addAll(batch);
        if (page['has_more'] != true || batch.isEmpty) break;
        final next = chatMap(page['next_cursor']);
        final newest = batch.last;
        final candidate = next.isNotEmpty
            ? next
            : <String, dynamic>{
                'sent_at': newest['sent_at'] ?? newest['created_at'],
                'id': newest['id'],
              };
        if (candidate['sent_at'] == cursor['sent_at'] &&
            candidate['id'] == cursor['id']) {
          break;
        }
        cursor = candidate;
      }
    }
    final result = await repository.loadMessages(conversationId: id);
    if (!_valid(scope, thread)) return;
    final incoming = _merge(caughtUp, chatRows(result['data']));
    final previousIdentity = messages
        .map(
          (m) => chatValue(m['client_message_id']).isNotEmpty
              ? 'client:${m['client_message_id']}'
              : 'server:${m['id']}',
        )
        .join(';');
    messages = _merge(refresh ? messages : [], incoming);
    final nextIdentity = messages
        .map(
          (m) => chatValue(m['client_message_id']).isNotEmpty
              ? 'client:${m['client_message_id']}'
              : 'server:${m['id']}',
        )
        .join(';');
    if (!refresh) {
      hasOlder = result['has_more'] == true;
      _olderCursor = chatMap(result['next_cursor']);
    }
    if (previousIdentity != nextIdentity) {
      messageRevision++;
    }
    messageError = null;
    _emit();
    if (incoming.isNotEmpty && threadVisibleAtBottom) {
      unawaited(_markRead(id, incoming.last));
    }
  }

  Future<void> _loadPending(int scope, int thread) async {
    final queued = await repository.pendingMessages();
    if (!_valid(scope, thread) || selected == null) return;
    final row = selected!;
    final relevant = queued
        .where((p) {
          final conversation = chatValue(p['conversation_id']);
          if (conversation.isNotEmpty) {
            return conversation == chatValue(row['id']);
          }
          final contact = chatMap(p['contact']);
          if (contact.isNotEmpty) {
            return chatValue(contact['id']) == chatValue(row['id']) &&
                chatValue(contact['student_id']) ==
                    chatValue(row['student_id']);
          }
          final keys = [
            'type',
            'teacher_id',
            'parent_id',
            'student_id',
            'leader_id',
          ];
          return keys.every((key) => chatValue(p[key]) == chatValue(row[key]));
        })
        .map(
          (p) => <String, dynamic>{
            ...p,
            'id': 'local:${p['client_message_id']}',
            'sender_user_id': repository.currentUserId,
            'sent_at': p['created_at'],
            '_send_conversation_id': chatValue(p['conversation_id']),
            '_send_contact': chatValue(p['conversation_id']).isEmpty
                ? {...p}
                : <String, dynamic>{},
            '_delivery':
                ['failed', 'conflict', 'error'].contains(chatValue(p['status']))
                ? 'Failed'
                : 'Queued',
          },
        )
        .toList();
    final confirmed = messages
        .where((m) => m['_delivery'] == 'Sent')
        .map((m) => chatValue(m['client_message_id']))
        .toSet();
    messages = _merge(
      messages,
      relevant
          .where((p) => !confirmed.contains(chatValue(p['client_message_id'])))
          .toList(),
    );
    _emit();
  }

  Future<void> markCurrentRead() async {
    if (selected == null || selected!['_contact'] == true || messages.isEmpty) {
      return;
    }
    final canonical = messages
        .where((message) => message['_delivery'] == 'Sent')
        .toList();
    if (canonical.isNotEmpty) {
      await _markRead(chatValue(selected!['id']), canonical.last);
    }
  }

  Future<void> _markRead(String id, Map<String, dynamic> row) async {
    final scope = _scope, thread = _thread;
    try {
      await repository.markRead(
        conversationId: id,
        throughSentAt: chatValue(row['sent_at'] ?? row['created_at']),
        throughId: chatValue(row['id']),
      );
      if (!_valid(scope, thread)) return;
      _refreshUnread();
      conversations = conversations
          .map((c) => chatValue(c['id']) == id ? {...c, 'unread_count': 0} : c)
          .toList();
      _emit();
    } on Object catch (_) {
      /* Keep unread until acknowledged by the server. */
    }
  }

  Future<void> loadOlder() async {
    if (!hasOlder || olderLoading || selected == null) return;
    final scope = _scope, thread = _thread;
    olderLoading = true;
    _emit();
    try {
      final result = await repository.loadMessages(
        conversationId: chatValue(selected!['id']),
        mode: 'before',
        cursorSentAt: chatValue(_olderCursor['sent_at']),
        cursorId: chatValue(_olderCursor['id']),
      );
      if (!_valid(scope, thread)) return;
      messages = _merge(messages, chatRows(result['data']));
      hasOlder = result['has_more'] == true;
      _olderCursor = chatMap(result['next_cursor']);
    } on Object catch (e) {
      if (_valid(scope, thread)) messageError = e;
    } finally {
      if (_valid(scope, thread)) {
        olderLoading = false;
        _emit();
      }
    }
  }

  void updateDraft(String value) {
    draft = value;
    if (selected == null) return;
    _drafts[chatKey(selected!)] = value;
    _draftTimer?.cancel();
    _draftTimer = Timer(
      const Duration(milliseconds: 300),
      () => unawaited(flushDraft()),
    );
  }

  Future<void> flushDraft() async {
    _draftTimer?.cancel();
    final row = selected;
    if (row == null || _account != repository.accountScope) return;
    final key = chatKey(row);
    final body = _drafts[key] ?? draft;
    try {
      await repository.saveDraft(key, body);
    } on Object catch (_) {
      /* Keep the in-memory draft when local persistence fails. */
    }
  }

  Future<void> send({Map<String, dynamic>? retry}) async {
    final row = selected;
    if (row == null) return;
    final body = retry == null ? draft.trim() : chatValue(retry['body']);
    if (body.isEmpty) return;
    final scope = _scope, thread = _thread, account = _account;
    final id = retry == null ? _uuid() : chatValue(retry['client_message_id']);
    final originalConversation = retry == null
        ? (row['_contact'] == true ? '' : chatValue(row['id']))
        : chatValue(
            retry['_send_conversation_id'] ??
                retry['conversation_id'] ??
                (row['_contact'] == true ? '' : row['id']),
          );
    final originalContact = retry != null && retry['_send_contact'] is Map
        ? chatMap(retry['_send_contact'])
        : row['_contact'] == true
        ? row
        : <String, dynamic>{};
    final pending = <String, dynamic>{
      '_send_conversation_id': originalConversation,
      '_send_contact': originalContact,
      'id': 'local:$id',
      'client_message_id': id,
      'body': body,
      'sender_user_id': repository.currentUserId,
      'sender_name': 'You',
      'sender_role': role,
      'sent_at': retry?['sent_at'] ?? DateTime.now().toUtc().toIso8601String(),
      '_delivery': 'Sending',
    };
    messages = _merge(messages, [pending]);
    if (retry == null) {
      draft = '';
      _drafts[chatKey(row)] = '';
      _draftTimer?.cancel();
    }
    ownSendRevision++;
    messageRevision++;
    _emit();
    try {
      // Keep a durable recovery copy until the command is acknowledged or
      // durably queued by the transport.
      if (retry == null) await repository.saveDraft(chatKey(row), body);
      if (_disposed || account != repository.accountScope) return;
      final result = await repository.sendMessage(
        clientMessageId: id,
        body: body,
        conversationId: originalConversation,
        contact: originalContact,
      );
      if (!_valid(scope, thread)) return;
      if (result['queued'] == true) {
        messages = _merge(messages, [
          {...pending, '_delivery': 'Queued'},
        ]);
      } else {
        final canonical = chatMap(result['message']);
        canonical.putIfAbsent('client_message_id', () => id);
        canonical['_delivery'] = 'Sent';
        messages = _merge(messages, [canonical]);
        final conversation = chatMap(result['conversation']);
        if (conversation.isNotEmpty) {
          selected = {
            ...row,
            ...conversation,
            '_contact': false,
            '_draft_key': chatKey(row),
          };
          unawaited(
            repository
                .watch(conversationId: chatValue(selected!['id']))
                .catchError((Object _) {}),
          );
        }
      }
      if (retry != null && draft.trim() == body) {
        draft = '';
        _drafts[chatKey(row)] = '';
      }
      await flushDraft();
      _refreshUnread();
      _emit();
      unawaited(refresh());
    } on Object {
      if (!_valid(scope, thread)) return;
      messages = _merge(messages, [
        {...pending, '_delivery': 'Failed'},
      ]);
      if (draft.isEmpty) {
        draft = body;
        _drafts[chatKey(row)] = body;
      }
      await flushDraft();
      _emit();
    }
  }

  Future<void> closeThread() async {
    final thread = ++_thread, scope = _scope;
    await flushDraft();
    if (!_valid(scope, thread)) return;
    if (_threadHistory.isNotEmpty) {
      final row = _threadHistory.removeLast();
      await openThread(row, nested: true);
      _threadHistory.clear();
      return;
    }
    selected = null;
    messages = [];
    draft = '';
    ++_thread;
    _emit();
    unawaited(repository.watch().catchError((Object _) {}));
  }

  void updateFilters() {
    _emit();
    if (search != _lastSearch) {
      _lastSearch = search;
      _searchTimer?.cancel();
      if (!contactsOpen) {
        _searchTimer = Timer(const Duration(milliseconds: 300), () async {
          final scope = _scope;
          try {
            await _loadInbox(scope);
            if (_valid(scope)) _emit();
          } on Object catch (e) {
            if (_valid(scope)) {
              error = e;
              _emit();
            }
          }
        });
      }
    }
  }

  List<Map<String, dynamic>> get visibleRows {
    final source = contactsOpen
        ? contacts.map((e) => {...e, '_contact': true}).toList()
        : conversations;
    return source.where((row) {
      final haystack =
          '${chatName(row, role, monitor: monitor && !contactsOpen)} ${chatContext(row)} ${row['last_message']} ${chatContactRole(row, role)}'
              .toLowerCase();
      if (search.isNotEmpty && !haystack.contains(search.toLowerCase())) {
        return false;
      }
      if ((unreadOnly || category == 'Unread') &&
          (int.tryParse('${row['unread_count']}') ?? 0) == 0) {
        return false;
      }
      final contactRole = chatContactRole(row, role).toLowerCase();
      if (category == 'Parents' && !contactRole.contains('parent')) {
        return false;
      }
      if (category == 'Teachers' && !contactRole.contains('teacher')) {
        return false;
      }
      if (category == 'Leadership' &&
          !contactRole.contains('leadership') &&
          !contactRole.contains('principal') &&
          !contactRole.contains('coordinator')) {
        return false;
      }
      if (classFilter.isNotEmpty &&
          chatValue(row['class_label']) != classFilter) {
        return false;
      }
      if (teacherFilter.isNotEmpty &&
          chatValue(row['teacher_id']) != teacherFilter) {
        return false;
      }
      if (personFilter.isNotEmpty &&
          !haystack.contains(personFilter.toLowerCase())) {
        return false;
      }
      final date = DateTime.tryParse(
        chatValue(row['last_message_at']),
      )?.toLocal();
      if (dateFilter != null &&
          (date == null ||
              DateTime(date.year, date.month, date.day) != dateFilter)) {
        return false;
      }
      return true;
    }).toList();
  }

  @override
  void dispose() {
    unawaited(flushDraft());
    _disposed = true;
    ++_scope;
    ++_thread;
    _draftTimer?.cancel();
    _searchTimer?.cancel();
    unawaited(_events?.cancel());
    unawaited(_connections?.cancel());
    super.dispose();
  }
}

List<Map<String, dynamic>> _merge(
  List<Map<String, dynamic>> existing,
  List<Map<String, dynamic>> incoming,
) {
  final result = existing.map((e) => Map<String, dynamic>.from(e)).toList();
  for (final item in incoming) {
    final id = chatValue(item['id']),
        client = chatValue(item['client_message_id']);
    final index = result.indexWhere(
      (e) =>
          (id.isNotEmpty && chatValue(e['id']) == id) ||
          (client.isNotEmpty && chatValue(e['client_message_id']) == client),
    );
    final normalized = {...item};
    if (!normalized.containsKey('_delivery')) {
      normalized['_delivery'] = normalized['is_queued'] == true
          ? 'Queued'
          : 'Sent';
    }
    if (index < 0) {
      result.add(normalized);
    } else {
      result[index] = {...result[index], ...normalized};
    }
  }
  result.sort((a, b) {
    final time = chatValue(
      a['sent_at'] ?? a['created_at'],
    ).compareTo(chatValue(b['sent_at'] ?? b['created_at']));
    return time != 0 ? time : chatValue(a['id']).compareTo(chatValue(b['id']));
  });
  return result;
}

String _uuid() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final text = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${text.substring(0, 8)}-${text.substring(8, 12)}-${text.substring(12, 16)}-${text.substring(16, 20)}-${text.substring(20)}';
}

bool _sameParticipantScope(
  Map<String, dynamic> contact,
  Map<String, dynamic> conversation,
) {
  const keys = ['type', 'teacher_id', 'parent_id', 'student_id', 'leader_id'];
  return keys.every(
    (key) => chatValue(contact[key]) == chatValue(conversation[key]),
  );
}
