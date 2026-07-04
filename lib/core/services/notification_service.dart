import 'package:flutter/material.dart';

import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/services/role_access_service.dart';

class NotificationService extends ChangeNotifier {
  static NotificationService? _instance;

  final BackendApiClient _api = BackendApiClient.instance;
  List<AppNotification> _notifications = [];
  final Map<String, bool> _settings = {};
  bool _loaded = false;

  List<AppNotification> get notifications => List.unmodifiable(_notifications);
  int get totalUnread => _notifications.where((n) => !n.isRead).length;

  int getBadgeCount(String category) =>
      _notifications.where((n) => n.category == category && !n.isRead).length;

  bool getSetting(String key) => _settings[key] ?? true;

  static Future<NotificationService> getInstance() async {
    _instance ??= NotificationService._();
    // Only load data once — avoids repeated API calls on every getInstance().
    if (!_instance!._loaded) {
      await _instance!._load();
    }
    return _instance!;
  }

  NotificationService._();

  Future<void> _load() async {
    _loaded = true;
    final rows = await _api.getNotifications();
    _notifications = rows.map(AppNotification.fromJson).toList();
  }

  /// Force a fresh reload of notifications from the backend.
  Future<void> refresh() async {
    _loaded = false;
    await _load();
    notifyListeners();
  }

  Future<void> addNotification(AppNotification notification) async {
    _notifications.insert(0, notification);
    notifyListeners();
  }

  Future<void> markAsRead(String id) async {
    if (!id.startsWith('transient_')) {
      try {
        await _api.markNotificationRead(id);
      } catch (_) {
        // If the backend fails, still mark it locally so the user isn't stuck
      }
    }
    final idx = _notifications.indexWhere((n) => n.id == id);
    if (idx >= 0) {
      _notifications[idx] = _notifications[idx].copyWith(isRead: true);
      notifyListeners();
    }
  }

  Future<void> markAllAsRead(String role) async {
    final targets = _notifications.where(
      (n) => _isVisibleToRole(n, role) && !n.isRead,
    );
    for (final notification in targets) {
      if (!notification.id.startsWith('transient_')) {
        try {
          await _api.markNotificationRead(notification.id);
        } catch (_) {
          // Ignore individual failures to ensure all are marked locally
        }
      }
    }
    _notifications = _notifications
        .map((n) => _isVisibleToRole(n, role) ? n.copyWith(isRead: true) : n)
        .toList();
    notifyListeners();
  }

  Future<void> deleteNotification(String id) async {
    _notifications.removeWhere((n) => n.id == id);
    notifyListeners();
  }

  Future<void> updateSetting(String key, bool value) async {
    _settings[key] = value;
    notifyListeners();
  }

  List<AppNotification> getNotificationsForRole(String role) {
    return _notifications.where((n) => _isVisibleToRole(n, role)).toList();
  }

  int getUnreadCountForRole(String role) {
    return _notifications
        .where((n) => _isVisibleToRole(n, role) && !n.isRead)
        .length;
  }

  bool _isVisibleToRole(AppNotification notification, String role) {
    final normalizedRole = role.trim().toLowerCase();
    final notificationRole = notification.role.trim().toLowerCase();
    if (notificationRole != 'all' && notificationRole != normalizedRole) {
      return false;
    }
    if (normalizedRole == 'teacher' &&
        notification.category == NotificationCategory.birthday) {
      final teacherId = RoleAccessService.teacherStaffId.trim();
      final sectionIds = RoleAccessService.teacherSectionIds;
      final matchesTeacher =
          teacherId.isNotEmpty && notification.teacherId == teacherId;
      final matchesSection =
          notification.sectionId.isNotEmpty &&
          sectionIds.contains(notification.sectionId);
      return matchesTeacher || matchesSection;
    }
    return true;
  }

  Future<void> triggerPendingApprovalAlert({
    required String title,
    required String body,
    required String role,
  }) async {
    if (!getSetting('pending_approvals')) return;
    await addNotification(
      AppNotification.transient(
        title: title,
        body: body,
        category: NotificationCategory.pendingApproval,
        role: role,
        priority: NotificationPriority.high,
      ),
    );
  }

  Future<void> triggerFeeDueAlert({
    required String studentName,
    required String amount,
    required String role,
  }) async {
    if (!getSetting('fee_reminders')) return;
    await addNotification(
      AppNotification.transient(
        title: 'Fee Due Reminder',
        body: '$studentName - Fee of $amount is due soon.',
        category: NotificationCategory.feeDue,
        role: role,
        priority: NotificationPriority.high,
      ),
    );
  }

  Future<void> triggerExamReminder({
    required String examName,
    required String date,
    required String role,
  }) async {
    if (!getSetting('general_alerts')) return;
    await addNotification(
      AppNotification.transient(
        title: 'School Update',
        body: '$examName is scheduled for $date.',
        category: NotificationCategory.general,
        role: role,
        priority: NotificationPriority.medium,
      ),
    );
  }

  Future<void> triggerCircularAlert({
    required String title,
    required String body,
    required String role,
  }) async {
    if (!getSetting('general_alerts')) return;
    await addNotification(
      AppNotification.transient(
        title: title,
        body: body,
        category: NotificationCategory.general,
        role: role,
        priority: NotificationPriority.medium,
      ),
    );
  }

  Future<void> triggerLeaveStatusAlert({
    required String status,
    required String dates,
    required String role,
  }) async {
    await addNotification(
      AppNotification.transient(
        title: 'Leave Request $status',
        body: 'Your leave request for $dates has been $status.',
        category: NotificationCategory.pendingApproval,
        role: role,
        priority: NotificationPriority.high,
      ),
    );
  }

  Future<void> triggerHealthReminderAlert({
    required String studentName,
    required String condition,
    required String medication,
    required String reminderTime,
    required String role,
    String referenceId = '',
  }) async {
    final title = 'Health Reminder';
    final bodyParts = <String>[
      if (studentName.trim().isNotEmpty) studentName.trim(),
      if (condition.trim().isNotEmpty) condition.trim(),
      if (medication.trim().isNotEmpty) medication.trim(),
      if (reminderTime.trim().isNotEmpty) reminderTime.trim(),
    ];
    final body = bodyParts.isEmpty
        ? 'A parent added a health reminder.'
        : bodyParts.join(' - ');

    await addNotification(
      AppNotification.transient(
        title: title,
        body: body,
        category: NotificationCategory.health,
        role: role,
        priority: NotificationPriority.high,
        referenceType: 'health',
        referenceId: referenceId,
      ),
    );

    try {
      await _api.createRaw('/notifications', {
        'title': title,
        'body': body,
        'category': NotificationCategory.health,
        'notification_type': NotificationCategory.health,
        'target_role': role,
        'priority': 'high',
        'reference_type': 'health',
        if (referenceId.trim().isNotEmpty) 'reference_id': referenceId.trim(),
      });
    } catch (_) {
      // Notification delivery is best-effort.
    }
  }

  Future<void> triggerHomeworkSubmittedAlert({
    required String homeworkId,
    required String homeworkTitle,
    required String studentName,
    bool hasAttachment = false,
  }) async {
    final title = 'Homework Submitted';
    final body = [
      if (studentName.trim().isNotEmpty) studentName.trim(),
      if (homeworkTitle.trim().isNotEmpty) homeworkTitle.trim(),
      if (hasAttachment) 'Attachment included',
    ].join(' - ');

    await addNotification(
      AppNotification.transient(
        title: title,
        body: body.isEmpty ? 'A parent submitted homework.' : body,
        category: NotificationCategory.homework,
        role: 'teacher',
        priority: NotificationPriority.high,
        route: '/teacher-homework-screen/submissions',
        referenceType: 'homework',
        referenceId: homeworkId,
      ),
    );

    try {
      await _api.createRaw('/notifications', {
        'title': title,
        'body': body.isEmpty ? 'A parent submitted homework.' : body,
        'category': NotificationCategory.homework,
        'notification_type': NotificationCategory.homework,
        'target_role': 'teacher',
        'priority': 'high',
        'route': '/teacher-homework-screen/submissions',
        'reference_type': 'homework',
        'reference_id': homeworkId,
        'action': 'submission',
      });
    } catch (_) {
      // Notification delivery is best-effort.
    }
  }

  Future<void> triggerHomeworkFeedbackAlert({
    required String homeworkId,
    required String homeworkTitle,
    required String comment,
    required String studentId,
  }) async {
    final title = 'Homework Feedback';
    final cleanComment = comment.trim();
    final body = cleanComment.isEmpty
        ? 'Teacher added feedback for ${homeworkTitle.trim().isEmpty ? 'homework' : homeworkTitle.trim()}.'
        : cleanComment;

    await addNotification(
      AppNotification.transient(
        title: title,
        body: body,
        category: NotificationCategory.homework,
        role: 'parent',
        priority: NotificationPriority.high,
        route: '/parent-homework-screen/submit',
        referenceType: 'homework',
        referenceId: homeworkId,
      ),
    );

    try {
      await _api.createRaw('/notifications', {
        'title': title,
        'body': body,
        'category': NotificationCategory.homework,
        'notification_type': NotificationCategory.homework,
        'target_role': 'parent',
        'priority': 'high',
        'route': '/parent-homework-screen/submit',
        'reference_type': 'homework',
        'reference_id': homeworkId,
        'action': 'needs_revision',
        if (studentId.trim().isNotEmpty) 'student_id': studentId.trim(),
      });
    } catch (_) {
      // Notification delivery is best-effort.
    }
  }

  Future<void> triggerInvoiceGeneratedAlert({
    required int invoiceCount,
    required String classLabel,
    required String termLabel,
  }) async {
    if (!getSetting('fee_reminders')) return;
    // Notify parents about new invoices
    await addNotification(
      AppNotification.transient(
        title: 'New Fee Invoices Generated',
        body:
            '$invoiceCount invoice(s) generated for $classLabel — $termLabel. Please check "My Fees" for details.',
        category: NotificationCategory.feeDue,
        role: 'parent',
        priority: NotificationPriority.high,
      ),
    );
    // Also create a backend notification so parents see it on next login
    try {
      await _api.createRaw('/notifications', {
        'title': 'New Fee Invoices Generated',
        'body':
            '$invoiceCount invoice(s) generated for $classLabel — $termLabel. Please check "My Fees" for payment details and due dates.',
        'category': NotificationCategory.feeDue,
        'target_role': 'parent',
        'priority': 'high',
        'reference_type': 'fee_invoice',
      });
    } catch (_) {
      // Notification delivery is best-effort
    }
  }
}

class NotificationCategory {
  static const String pendingApproval = 'pending_approval';
  static const String feeDue = 'fee_due';
  static const String event = 'event';
  static const String health = 'health';
  static const String homework = 'homework';
  static const String birthday = 'birthday';
  static const String general = 'general';
  static const String healthAlert = 'health_alert';
}

enum NotificationPriority { low, medium, high }

class AppNotification {
  final String id;
  final String title;
  final String body;
  final String category;
  final String role;
  final DateTime timestamp;
  final bool isRead;
  final NotificationPriority priority;
  final String route;
  final String referenceType;
  final String referenceId;
  final String studentId;
  final String sectionId;
  final String teacherId;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.role,
    required this.timestamp,
    required this.isRead,
    required this.priority,
    this.route = '',
    this.referenceType = '',
    this.referenceId = '',
    this.studentId = '',
    this.sectionId = '',
    this.teacherId = '',
  });

  factory AppNotification.transient({
    required String title,
    required String body,
    required String category,
    required String role,
    required NotificationPriority priority,
    String route = '',
    String referenceType = '',
    String referenceId = '',
    String studentId = '',
    String sectionId = '',
    String teacherId = '',
  }) {
    return AppNotification(
      id: 'transient_${DateTime.now().microsecondsSinceEpoch}',
      title: title,
      body: body,
      category: category,
      role: role,
      timestamp: DateTime.now(),
      isRead: false,
      priority: priority,
      route: route,
      referenceType: referenceType,
      referenceId: referenceId,
      studentId: studentId,
      sectionId: sectionId,
      teacherId: teacherId,
    );
  }

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      title: title,
      body: body,
      category: category,
      role: role,
      timestamp: timestamp,
      isRead: isRead ?? this.isRead,
      priority: priority,
      route: route,
      referenceType: referenceType,
      referenceId: referenceId,
      studentId: studentId,
      sectionId: sectionId,
      teacherId: teacherId,
    );
  }

  Map<String, dynamic> get routingData => {
    'route': route,
    'reference_type': referenceType,
    'reference_id': referenceId,
    'role': role,
    'category': category,
    'student_id': studentId,
    'section_id': sectionId,
    'teacher_id': teacherId,
  };

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final priorityRaw = '${json['priority'] ?? ''}'.toLowerCase();
    final categoryRaw =
        '${json['category'] ?? json['type'] ?? json['notification_type'] ?? ''}'
            .toLowerCase();
    final referenceType =
        '${json['reference_type'] ?? json['referenceType'] ?? ''}';
    final referenceId = '${json['reference_id'] ?? json['referenceId'] ?? ''}';
    final studentId = '${json['student_id'] ?? json['studentId'] ?? ''}';
    final sectionId = '${json['section_id'] ?? json['sectionId'] ?? ''}';
    final teacherId = '${json['teacher_id'] ?? json['teacherId'] ?? ''}';

    final sentAtRaw = '${json['sent_at'] ?? json['created_at'] ?? ''}';
    var parsedTimestamp = DateTime.now();
    if (sentAtRaw.trim().isNotEmpty) {
      var normalized = sentAtRaw.trim();
      normalized = normalized.replaceAll(' ', 'T');
      if (normalized.contains('T') &&
          !normalized.endsWith('Z') &&
          !normalized.contains('+') &&
          !RegExp(r'-\d{2}:?\d{2}$').hasMatch(normalized)) {
        normalized = '${normalized}Z';
      }
      parsedTimestamp = DateTime.tryParse(normalized)?.toLocal() ?? DateTime.now();
    }

    return AppNotification(
      id: '${json['id']}',
      title: '${json['title'] ?? 'Notification'}',
      body: '${json['body'] ?? json['message'] ?? ''}',
      category: categoryRaw.isEmpty
          ? NotificationCategory.general
          : categoryRaw,
      role: '${json['role'] ?? json['target_role'] ?? 'all'}'.toLowerCase(),
      timestamp: parsedTimestamp,
      isRead: json['is_read'] == true || json['isRead'] == true,
      priority: priorityRaw == 'high'
          ? NotificationPriority.high
          : priorityRaw == 'low'
          ? NotificationPriority.low
          : NotificationPriority.medium,
      route: '${json['route'] ?? ''}',
      referenceType: referenceType,
      referenceId: referenceId,
      studentId: studentId,
      sectionId: sectionId,
      teacherId: teacherId,
    );
  }
}
