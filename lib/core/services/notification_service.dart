import 'package:flutter/material.dart';

import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/services/role_access_service.dart';

class NotificationService extends ChangeNotifier {
  static NotificationService? _instance;

  /// Clears the cached singleton — call this on user logout so the next login
  /// starts with a fresh, empty notification list rather than stale data.
  static void resetInstance() {
    _instance = null;
  }

  final BackendApiClient _api = BackendApiClient.instance;
  List<AppNotification> _notifications = [];
  final Map<String, bool> _settings = {};
  bool _loaded = false;
  Future<void>? _loadFuture;
  int _currentPage = 1;
  bool _hasMore = false;
  bool _loadingMore = false;
  int? _serverUnreadCount;

  List<AppNotification> get notifications => List.unmodifiable(_notifications);
  int get totalUnread =>
      _serverUnreadCount ?? _notifications.where((n) => !n.isRead).length;
  bool get hasMore => _hasMore;
  bool get isLoadingMore => _loadingMore;

  int getBadgeCount(String category) =>
      _notifications.where((n) => n.category == category && !n.isRead).length;

  bool getSetting(String key) => _settings[key] ?? true;

  static Future<NotificationService> getInstance() async {
    _instance ??= NotificationService._();
    // Only load data once — avoids repeated API calls on every getInstance().
    if (!_instance!._loaded) {
      await (_instance!._loadFuture ??= _instance!._load());
    }
    return _instance!;
  }

  NotificationService._();

  Future<void> _load() async {
    try {
      final page = await _api.getNotificationsPage(page: 1);
      _notifications = page.items.map(AppNotification.fromJson).toList();
      _currentPage = page.page;
      _hasMore = page.hasMore;
      try {
        _serverUnreadCount = await _api.getUnreadNotificationsCount();
      } on Object catch (_) {
        _serverUnreadCount = null;
      }
      try {
        final preferences = await _api.getNotificationPreferences();
        _hydrateSettings(preferences);
      } on Object catch (_) {
        // Notification history remains usable if preference hydration is
        // temporarily unavailable; defaults remain enabled until the next load.
        _settings.clear();
      }
      _loaded = true;
    } finally {
      _loadFuture = null;
    }
  }

  /// Force a fresh reload of notifications from the backend.
  Future<void> refresh() async {
    _loaded = false;
    await _load();
    notifyListeners();
  }

  Future<void> loadMore() async {
    if (_loadingMore || !_hasMore) return;
    _loadingMore = true;
    try {
      final page = await _api.getNotificationsPage(page: _currentPage + 1);
      final existingIds = _notifications.map((item) => item.id).toSet();
      _notifications.addAll(
        page.items
            .map(AppNotification.fromJson)
            .where((item) => existingIds.add(item.id)),
      );
      _currentPage = page.page;
      _hasMore = page.hasMore;
      notifyListeners();
    } finally {
      _loadingMore = false;
    }
  }

  Future<void> addNotification(AppNotification notification) async {
    _notifications.insert(0, notification);
    if (!notification.isRead && _serverUnreadCount != null) {
      _serverUnreadCount = _serverUnreadCount! + 1;
    }
    notifyListeners();
  }

  Future<void> markAsRead(String id) async {
    if (!id.startsWith('transient_')) {
      await _api.markNotificationRead(id);
    }
    final idx = _notifications.indexWhere((n) => n.id == id);
    if (idx >= 0) {
      _notifications[idx] = _notifications[idx].copyWith(isRead: true);
      if (_serverUnreadCount != null && _serverUnreadCount! > 0) {
        _serverUnreadCount = _serverUnreadCount! - 1;
      }
      notifyListeners();
    }
  }

  Future<void> markAllAsRead(String role) async {
    final targets = _notifications
        .where((n) => _isVisibleToRole(n, role) && !n.isRead)
        .toList();
    final hasPersistentTargets = targets.any(
      (notification) => !notification.id.startsWith('transient_'),
    );
    if (hasPersistentTargets) await _api.markAllNotificationsRead(role: role);
    _notifications = _notifications
        .map((n) => _isVisibleToRole(n, role) ? n.copyWith(isRead: true) : n)
        .toList();
    try {
      _serverUnreadCount = await _api.getUnreadNotificationsCount();
    } on Object catch (_) {
      _serverUnreadCount = null;
    }
    notifyListeners();
  }

  Future<void> deleteNotification(String id) async {
    if (!id.startsWith('transient_')) await _api.deleteNotification(id);
    _notifications.removeWhere((n) => n.id == id);
    notifyListeners();
  }

  Future<void> updateSetting(String key, bool value) async {
    final previous = _settings[key];
    _settings[key] = value;
    notifyListeners();
    try {
      await _api.updateNotificationPreferences({key: value});
    } on Object catch (_) {
      if (previous == null) {
        _settings.remove(key);
      } else {
        _settings[key] = previous;
      }
      notifyListeners();
      rethrow;
    }
  }

  void _hydrateSettings(Map<String, dynamic> preferences) {
    _settings
      ..clear()
      ..addEntries(
        const ['pending_approvals', 'fee_reminders', 'general_alerts']
            .where((key) => preferences[key] is bool)
            .map((key) => MapEntry(key, preferences[key] as bool)),
      );
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
        category: NotificationCategory.general,
        role: role,
        priority: NotificationPriority.high,
      ),
    );
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
  final String studentPhotoUrl;

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
    this.studentPhotoUrl = '',
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
    String studentPhotoUrl = '',
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
      studentPhotoUrl: studentPhotoUrl,
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
      studentPhotoUrl: studentPhotoUrl,
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
    'student_photo_url': studentPhotoUrl,
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
    final studentPhotoUrl =
        '${json['student_photo_url'] ?? json['studentPhotoUrl'] ?? ''}';

    final sentAtRaw = '${json['sent_at'] ?? json['created_at'] ?? ''}';
    var parsedTimestamp = DateTime.now();
    if (sentAtRaw.trim().isNotEmpty) {
      var normalized = sentAtRaw.trim();
      normalized = normalized.replaceAll(' ', 'T');
      // Only append Z (UTC) when there is truly no timezone indicator.
      // A bare '-' regex like r'-\d{2}:?\d{2}$' also matches the date part
      // of timestamps such as "2024-01-15T10:30:00" — use a stricter pattern
      // that only matches a timezone offset (±HH:MM or ±HHMM at end).
      if (normalized.contains('T') &&
          !normalized.endsWith('Z') &&
          !normalized.contains('+') &&
          !RegExp(
            r'[+-]\d{2}:?\d{2}$',
          ).hasMatch(normalized.substring(normalized.indexOf('T')))) {
        normalized = '${normalized}Z';
      }
      parsedTimestamp =
          DateTime.tryParse(normalized)?.toLocal() ?? DateTime.now();
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
      studentPhotoUrl: studentPhotoUrl,
    );
  }
}
