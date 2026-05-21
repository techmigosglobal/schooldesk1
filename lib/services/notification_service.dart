import 'package:flutter/material.dart';

import 'backend_api_client.dart';

class NotificationService extends ChangeNotifier {
  static NotificationService? _instance;

  final BackendApiClient _api = BackendApiClient.instance;
  List<AppNotification> _notifications = [];
  final Map<String, bool> _settings = {};

  List<AppNotification> get notifications => List.unmodifiable(_notifications);
  int get totalUnread => _notifications.where((n) => !n.isRead).length;

  int getBadgeCount(String category) =>
      _notifications.where((n) => n.category == category && !n.isRead).length;

  bool getSetting(String key) => _settings[key] ?? true;

  static Future<NotificationService> getInstance() async {
    _instance ??= NotificationService._();
    await _instance!._load();
    return _instance!;
  }

  NotificationService._();

  Future<void> _load() async {
    final rows = await _api.getNotifications();
    _notifications = rows.map(AppNotification.fromJson).toList();
  }

  Future<void> addNotification(AppNotification notification) async {
    _notifications.insert(0, notification);
    notifyListeners();
  }

  Future<void> markAsRead(String id) async {
    await _api.markNotificationRead(id);
    final idx = _notifications.indexWhere((n) => n.id == id);
    if (idx >= 0) {
      _notifications[idx] = _notifications[idx].copyWith(isRead: true);
      notifyListeners();
    }
  }

  Future<void> markAllAsRead(String role) async {
    final targets = _notifications.where(
      (n) => (n.role == role || n.role == 'all') && !n.isRead,
    );
    for (final notification in targets) {
      await _api.markNotificationRead(notification.id);
    }
    _notifications = _notifications
        .map(
          (n) =>
              n.role == role || n.role == 'all' ? n.copyWith(isRead: true) : n,
        )
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
    return _notifications
        .where((n) => n.role == role || n.role == 'all')
        .toList();
  }

  int getUnreadCountForRole(String role) {
    return _notifications
        .where((n) => (n.role == role || n.role == 'all') && !n.isRead)
        .length;
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
    if (!getSetting('exam_reminders')) return;
    await addNotification(
      AppNotification.transient(
        title: 'Exam Reminder',
        body: '$examName scheduled for $date.',
        category: NotificationCategory.examReminder,
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
}

class NotificationCategory {
  static const String pendingApproval = 'pending_approval';
  static const String feeDue = 'fee_due';
  static const String examReminder = 'exam_reminder';
  static const String general = 'general';
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
    );
  }

  Map<String, dynamic> get routingData => {
    'route': route,
    'reference_type': referenceType,
    'reference_id': referenceId,
    'role': role,
    'category': category,
  };

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final priorityRaw = '${json['priority'] ?? ''}'.toLowerCase();
    final categoryRaw = '${json['category'] ?? ''}'.toLowerCase();
    return AppNotification(
      id: '${json['id']}',
      title: '${json['title'] ?? 'Notification'}',
      body: '${json['body'] ?? json['message'] ?? ''}',
      category: categoryRaw.isEmpty
          ? NotificationCategory.general
          : categoryRaw,
      role: '${json['role'] ?? json['target_role'] ?? 'all'}'.toLowerCase(),
      timestamp:
          DateTime.tryParse('${json['sent_at'] ?? json['created_at'] ?? ''}') ??
          DateTime.now(),
      isRead: json['is_read'] == true || json['isRead'] == true,
      priority: priorityRaw == 'high'
          ? NotificationPriority.high
          : priorityRaw == 'low'
          ? NotificationPriority.low
          : NotificationPriority.medium,
      route: '${json['route'] ?? ''}',
      referenceType: '${json['reference_type'] ?? ''}',
      referenceId: '${json['reference_id'] ?? ''}',
    );
  }
}
