import 'dart:developer' as developer;

import 'package:schooldesk1/core/theme/design_tokens.dart';
import 'package:schooldesk1/core/services/push_notification_service.dart';

class NotificationTopicManager {
  static final NotificationTopicManager _instance =
      NotificationTopicManager._internal();

  factory NotificationTopicManager() {
    return _instance;
  }

  NotificationTopicManager._internal();

  // Topic naming convention: role_{role_name}, event_{event_type}
  static const String _rolePrefix = 'role_';
  static const String _eventPrefix = 'event_';

  /// Subscribe user to role-based notification topics
  Future<void> subscribeToRoleTopics(SchoolDeskRole role) async {
    try {
      final topicName = '$_rolePrefix${role.name}';
      await PushNotificationService.instance.subscribeToTopic(topicName);
      developer.log(
        'Subscribed to role topic: $topicName',
        name: 'NotificationTopicManager',
      );
    } on Object catch (e) {
      developer.log(
        'Error subscribing to role topics: $e',
        name: 'NotificationTopicManager',
        level: 1000,
      );
    }
  }

  /// Unsubscribe user from role-based notification topics
  Future<void> unsubscribeFromRoleTopics(SchoolDeskRole role) async {
    try {
      final topicName = '$_rolePrefix${role.name}';
      await PushNotificationService.instance.unsubscribeFromTopic(topicName);
      developer.log(
        'Unsubscribed from role topic: $topicName',
        name: 'NotificationTopicManager',
      );
    } on Object catch (e) {
      developer.log(
        'Error unsubscribing from role topics: $e',
        name: 'NotificationTopicManager',
        level: 1000,
      );
    }
  }

  /// Subscribe user to event-based notification topics
  /// Available events: complaints_escalated, announcements, attendance, fees, academics
  Future<void> subscribeToEventTopic(String eventType) async {
    try {
      final topicName = '$_eventPrefix$eventType';
      await PushNotificationService.instance.subscribeToTopic(topicName);
      developer.log(
        'Subscribed to event topic: $topicName',
        name: 'NotificationTopicManager',
      );
    } on Object catch (e) {
      developer.log(
        'Error subscribing to event topic: $e',
        name: 'NotificationTopicManager',
        level: 1000,
      );
    }
  }

  /// Unsubscribe user from event-based notification topics
  Future<void> unsubscribeFromEventTopic(String eventType) async {
    try {
      final topicName = '$_eventPrefix$eventType';
      await PushNotificationService.instance.unsubscribeFromTopic(topicName);
      developer.log(
        'Unsubscribed from event topic: $topicName',
        name: 'NotificationTopicManager',
      );
    } on Object catch (e) {
      developer.log(
        'Error unsubscribing from event topic: $e',
        name: 'NotificationTopicManager',
        level: 1000,
      );
    }
  }

  /// Subscribe to admin-specific topics (for principal/admin roles)
  Future<void> subscribeToAdminTopics(SchoolDeskRole role) async {
    if (role == SchoolDeskRole.principal || role == SchoolDeskRole.coordinator) {
      try {
        // Subscribe to complaint escalation topic
        await subscribeToEventTopic('complaints_escalated');

        // Subscribe to system alerts
        await subscribeToEventTopic('system_alerts');

        // Subscribe to audit events
        await subscribeToEventTopic('audit_events');

        developer.log(
          'Subscribed to admin topics for role: ${role.name}',
          name: 'NotificationTopicManager',
        );
      } on Object catch (e) {
        developer.log(
          'Error subscribing to admin topics: $e',
          name: 'NotificationTopicManager',
          level: 1000,
        );
      }
    }
  }

  /// Unsubscribe from admin-specific topics
  Future<void> unsubscribeFromAdminTopics(SchoolDeskRole role) async {
    if (role == SchoolDeskRole.principal || role == SchoolDeskRole.coordinator) {
      try {
        await unsubscribeFromEventTopic('complaints_escalated');
        await unsubscribeFromEventTopic('system_alerts');
        await unsubscribeFromEventTopic('audit_events');

        developer.log(
          'Unsubscribed from admin topics for role: ${role.name}',
          name: 'NotificationTopicManager',
        );
      } on Object catch (e) {
        developer.log(
          'Error unsubscribing from admin topics: $e',
          name: 'NotificationTopicManager',
          level: 1000,
        );
      }
    }
  }

  /// Subscribe to parent-specific topics
  Future<void> subscribeToParentTopics(SchoolDeskRole role) async {
    if (role == SchoolDeskRole.parent) {
      try {
        // Subscribe to child-related events
        await subscribeToEventTopic('child_attendance');
        await subscribeToEventTopic('child_academics');
        await subscribeToEventTopic('fees');

        developer.log(
          'Subscribed to parent topics',
          name: 'NotificationTopicManager',
        );
      } on Object catch (e) {
        developer.log(
          'Error subscribing to parent topics: $e',
          name: 'NotificationTopicManager',
          level: 1000,
        );
      }
    }
  }

  /// Unsubscribe from parent-specific topics
  Future<void> unsubscribeFromParentTopics(SchoolDeskRole role) async {
    if (role == SchoolDeskRole.parent) {
      try {
        await unsubscribeFromEventTopic('child_attendance');
        await unsubscribeFromEventTopic('child_academics');
        await unsubscribeFromEventTopic('fees');

        developer.log(
          'Unsubscribed from parent topics',
          name: 'NotificationTopicManager',
        );
      } on Object catch (e) {
        developer.log(
          'Error unsubscribing from parent topics: $e',
          name: 'NotificationTopicManager',
          level: 1000,
        );
      }
    }
  }

  /// Subscribe to teacher-specific topics
  Future<void> subscribeToTeacherTopics(SchoolDeskRole role) async {
    if (role == SchoolDeskRole.teacher) {
      try {
        await subscribeToEventTopic('timetable_updates');
        await subscribeToEventTopic('assignments');
        await subscribeToEventTopic('class_announcements');

        developer.log(
          'Subscribed to teacher topics',
          name: 'NotificationTopicManager',
        );
      } on Object catch (e) {
        developer.log(
          'Error subscribing to teacher topics: $e',
          name: 'NotificationTopicManager',
          level: 1000,
        );
      }
    }
  }

  /// Unsubscribe from teacher-specific topics
  Future<void> unsubscribeFromTeacherTopics(SchoolDeskRole role) async {
    if (role == SchoolDeskRole.teacher) {
      try {
        await unsubscribeFromEventTopic('timetable_updates');
        await unsubscribeFromEventTopic('assignments');
        await unsubscribeFromEventTopic('class_announcements');

        developer.log(
          'Unsubscribed from teacher topics',
          name: 'NotificationTopicManager',
        );
      } on Object catch (e) {
        developer.log(
          'Error unsubscribing from teacher topics: $e',
          name: 'NotificationTopicManager',
          level: 1000,
        );
      }
    }
  }

  /// Set up all appropriate topic subscriptions based on user role
  Future<void> setupTopicsForRole(SchoolDeskRole role) async {
    try {
      // Subscribe to role-based topic
      await subscribeToRoleTopics(role);

      // Subscribe to role-specific topics
      switch (role) {
        case SchoolDeskRole.principal:
        case SchoolDeskRole.coordinator:
          await subscribeToAdminTopics(role);
          break;
        case SchoolDeskRole.parent:
          await subscribeToParentTopics(role);
          break;
        case SchoolDeskRole.teacher:
          await subscribeToTeacherTopics(role);
          break;
        case SchoolDeskRole.student:
          // Students get general announcements and academics
          await subscribeToEventTopic('announcements');
          await subscribeToEventTopic('academics');
          break;
      }

      developer.log(
        'Setup notification topics for role: ${role.name}',
        name: 'NotificationTopicManager',
      );
    } on Object catch (e) {
      developer.log(
        'Error setting up topics for role: $e',
        name: 'NotificationTopicManager',
        level: 1000,
      );
    }
  }

  /// Clean up all topic subscriptions on logout
  Future<void> cleanupTopicsForRole(SchoolDeskRole role) async {
    try {
      // Unsubscribe from role-based topic
      await unsubscribeFromRoleTopics(role);

      // Unsubscribe from role-specific topics
      switch (role) {
        case SchoolDeskRole.principal:
        case SchoolDeskRole.coordinator:
          await unsubscribeFromAdminTopics(role);
          break;
        case SchoolDeskRole.parent:
          await unsubscribeFromParentTopics(role);
          break;
        case SchoolDeskRole.teacher:
          await unsubscribeFromTeacherTopics(role);
          break;
        case SchoolDeskRole.student:
          await unsubscribeFromEventTopic('announcements');
          await unsubscribeFromEventTopic('academics');
          break;
      }

      developer.log(
        'Cleaned up notification topics for role: ${role.name}',
        name: 'NotificationTopicManager',
      );
    } on Object catch (e) {
      developer.log(
        'Error cleaning up topics for role: $e',
        name: 'NotificationTopicManager',
        level: 1000,
      );
    }
  }
}
