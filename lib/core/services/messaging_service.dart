import 'package:flutter/material.dart';

import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/services/notification_service.dart';

/// Two-way messaging service backed by the API.
class MessagingService extends ChangeNotifier {
  static MessagingService? _instance;

  List<Map<String, dynamic>> _conversations = [];
  final Map<String, List<Map<String, dynamic>>> _messagesByConversation = {};

  List<Map<String, dynamic>> get conversations =>
      List.unmodifiable(_conversations);

  static Future<MessagingService> getInstance() async {
    _instance ??= MessagingService._();
    await _instance!._load();
    return _instance!;
  }

  MessagingService._();

  Future<void> _load() async {
    final api = BackendApiClient.instance;
    final conversations = await api.getRawList('/message-conversations');
    final messages = await api.getRawList('/messages');

    _messagesByConversation
      ..clear()
      ..addEntries(
        conversations.map(
          (c) => MapEntry('${c['id']}', <Map<String, dynamic>>[]),
        ),
      );

    for (final message in messages.map(_mapMessageFromApi)) {
      final conversationId = '${message['conversationId']}';
      _messagesByConversation
          .putIfAbsent(conversationId, () => <Map<String, dynamic>>[])
          .add(message);
    }
    for (final list in _messagesByConversation.values) {
      list.sort(
        (a, b) => (a['timestamp'] as int? ?? 0).compareTo(
          b['timestamp'] as int? ?? 0,
        ),
      );
    }

    _conversations = conversations.map(_mapConversationFromApi).toList();
    _sortConversations();
  }

  Map<String, dynamic> _mapConversationFromApi(Map<String, dynamic> c) {
    final id = '${c['id']}';
    final messages = _messagesByConversation[id] ?? const [];
    final lastMessageTime =
        DateTime.tryParse(
          '${c['last_message_time'] ?? ''}',
        )?.millisecondsSinceEpoch ??
        (messages.isEmpty ? 0 : messages.last['timestamp'] as int? ?? 0);
    return {
      'id': id,
      'homeworkId': c['reference_id'] ?? '',
      'homeworkTitle': c['title'] ?? 'Conversation',
      'subject': c['subject'] ?? 'General',
      'className': c['class'] ?? '',
      'teacherId': c['teacher_id'] ?? '',
      'teacherName': c['teacher_name'] ?? 'Teacher',
      'parentId': c['parent_id'] ?? '',
      'parentName': c['parent_name'] ?? 'Parent',
      'studentName': c['student_name'] ?? 'Student',
      'lastMessage':
          c['last_message'] ??
          (messages.isEmpty ? '' : messages.last['text'] ?? ''),
      'lastMessageTime': lastMessageTime,
      'lastSender': messages.isEmpty ? '' : messages.last['sender'] ?? '',
      'teacherUnread': messages
          .where((m) => m['sender'] == 'parent' && m['read'] == false)
          .length,
      'parentUnread': messages
          .where((m) => m['sender'] == 'teacher' && m['read'] == false)
          .length,
      'createdAt':
          DateTime.tryParse(
            '${c['created_at'] ?? ''}',
          )?.millisecondsSinceEpoch ??
          lastMessageTime,
    };
  }

  Map<String, dynamic> _mapMessageFromApi(Map<String, dynamic> m) {
    return {
      'id': m['id'],
      'conversationId': m['conversation_id'],
      'sender': m['sender_role'],
      'senderName': m['sender_name'] ?? '',
      'text': m['body'] ?? '',
      'timestamp':
          DateTime.tryParse(
            '${m['sent_at'] ?? m['created_at'] ?? ''}',
          )?.millisecondsSinceEpoch ??
          0,
      'read': m['is_read'] == true,
    };
  }

  void _sortConversations() {
    _conversations.sort(
      (a, b) => (b['lastMessageTime'] as int? ?? 0).compareTo(
        a['lastMessageTime'] as int? ?? 0,
      ),
    );
  }

  List<Map<String, dynamic>> getMessages(String conversationId) {
    final msgs = List<Map<String, dynamic>>.from(
      _messagesByConversation[conversationId] ?? const [],
    );
    msgs.sort(
      (a, b) =>
          (a['timestamp'] as int? ?? 0).compareTo(b['timestamp'] as int? ?? 0),
    );
    return msgs;
  }

  List<Map<String, dynamic>> getConversationsForRole(
    String role,
    String userId,
  ) {
    final result = role == 'teacher'
        ? _conversations.where((c) => c['teacherId'] == userId).toList()
        : _conversations.where((c) => c['parentId'] == userId).toList();
    result.sort(
      (a, b) => (b['lastMessageTime'] as int? ?? 0).compareTo(
        a['lastMessageTime'] as int? ?? 0,
      ),
    );
    return result;
  }

  List<Map<String, dynamic>> getAllConversationsForTeacher(String teacherId) {
    return getConversationsForRole('teacher', teacherId);
  }

  int getUnreadCountForRole(String role, String userId) {
    final unreadKey = role == 'teacher' ? 'teacherUnread' : 'parentUnread';
    return getConversationsForRole(
      role,
      userId,
    ).fold(0, (sum, c) => sum + (c[unreadKey] as int? ?? 0));
  }

  int getTotalUnreadForRole(String role) {
    final unreadKey = role == 'teacher' ? 'teacherUnread' : 'parentUnread';
    return _conversations.fold(
      0,
      (sum, c) => sum + (c[unreadKey] as int? ?? 0),
    );
  }

  Future<void> sendMessage({
    required String conversationId,
    required String sender,
    required String senderName,
    required String text,
  }) async {
    final now = DateTime.now().toUtc();
    final api = BackendApiClient.instance;
    final saved = await api.createRaw('/messages', {
      'conversation_id': conversationId,
      'sender_id': senderName,
      'sender_role': sender,
      'sender_name': senderName,
      'body': text,
      'is_read': false,
      'sent_at': now.toIso8601String(),
    });

    _messagesByConversation
        .putIfAbsent(conversationId, () => <Map<String, dynamic>>[])
        .add(_mapMessageFromApi(saved));

    final convIdx = _conversations.indexWhere((c) => c['id'] == conversationId);
    if (convIdx != -1) {
      final conv = Map<String, dynamic>.from(_conversations[convIdx]);
      conv['lastMessage'] = text;
      conv['lastMessageTime'] = now.millisecondsSinceEpoch;
      conv['lastSender'] = sender;
      if (sender == 'teacher') {
        conv['parentUnread'] = (conv['parentUnread'] as int? ?? 0) + 1;
      } else {
        conv['teacherUnread'] = (conv['teacherUnread'] as int? ?? 0) + 1;
      }
      _conversations[convIdx] = conv;
      await api.updateRaw('/message-conversations/$conversationId', {
        'teacher_id': conv['teacherId'],
        'parent_id': conv['parentId'],
        'student_id': conv['studentId'] ?? '',
        'title': conv['homeworkTitle'],
        'reference_type': 'homework',
        'reference_id': conv['homeworkId'],
        'last_message': text,
        'last_message_time': now.toIso8601String(),
      });
      _sortConversations();
      await _triggerNotification(conv, sender, text);
    }
    notifyListeners();
  }

  Future<void> _triggerNotification(
    Map<String, dynamic> conv,
    String sender,
    String text,
  ) async {
    try {
      final notifService = await NotificationService.getInstance();
      final targetRole = sender == 'teacher' ? 'parent' : 'teacher';
      await notifService.addNotification(
        AppNotification(
          id: 'msg_notif_${DateTime.now().millisecondsSinceEpoch}',
          title: sender == 'teacher'
              ? 'Homework Feedback: ${conv['homeworkTitle']}'
              : 'Parent Reply: ${conv['studentName']}',
          body: sender == 'teacher'
              ? '${conv['teacherName']}: $text'
              : '${conv['parentName']}: $text',
          category: NotificationCategory.general,
          role: targetRole,
          timestamp: DateTime.now(),
          isRead: false,
          priority: NotificationPriority.medium,
        ),
      );
    } catch (_) {}
  }

  Future<void> markConversationRead(String conversationId, String role) async {
    final otherSender = role == 'teacher' ? 'parent' : 'teacher';
    final messages = getMessages(conversationId);
    for (final message in messages) {
      if (message['sender'] == otherSender && message['read'] == false) {
        await BackendApiClient.instance
            .updateRaw('/messages/${message['id']}', {
              'conversation_id': conversationId,
              'sender_id': message['senderName'],
              'sender_role': message['sender'],
              'sender_name': message['senderName'],
              'body': message['text'],
              'is_read': true,
              'sent_at': DateTime.fromMillisecondsSinceEpoch(
                message['timestamp'] as int? ?? 0,
              ).toUtc().toIso8601String(),
            });
        message['read'] = true;
      }
    }
    _messagesByConversation[conversationId] = messages;
    final convIdx = _conversations.indexWhere((c) => c['id'] == conversationId);
    if (convIdx != -1) {
      final conv = Map<String, dynamic>.from(_conversations[convIdx]);
      conv[role == 'teacher' ? 'teacherUnread' : 'parentUnread'] = 0;
      _conversations[convIdx] = conv;
    }
    notifyListeners();
  }

  Future<Map<String, dynamic>> createConversation({
    required String homeworkId,
    required String homeworkTitle,
    required String subject,
    required String className,
    required String teacherId,
    required String teacherName,
    required String parentId,
    required String parentName,
    required String studentName,
  }) async {
    final now = DateTime.now().toUtc();
    final saved = await BackendApiClient.instance
        .createRaw('/message-conversations', {
          'reference_type': 'homework',
          'reference_id': homeworkId,
          'teacher_id': teacherId,
          'parent_id': parentId,
          'title': homeworkTitle,
          'last_message': '',
          'last_message_time': now.toIso8601String(),
        });
    final conv = {
      ..._mapConversationFromApi(saved),
      'homeworkId': homeworkId,
      'homeworkTitle': homeworkTitle,
      'subject': subject,
      'className': className,
      'teacherId': teacherId,
      'teacherName': teacherName,
      'parentId': parentId,
      'parentName': parentName,
      'studentName': studentName,
      'createdAt': now.millisecondsSinceEpoch,
    };
    _conversations.insert(0, conv);
    _messagesByConversation['${conv['id']}'] = [];
    _sortConversations();
    notifyListeners();
    return conv;
  }
}
