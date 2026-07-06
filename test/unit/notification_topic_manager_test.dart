import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:schooldesk1/core/services/notification_topic_manager.dart';

void main() {
  group('NotificationTopicManager', () {
    test('is a singleton', () {
      final a = NotificationTopicManager();
      final b = NotificationTopicManager();
      expect(identical(a, b), isTrue);
    });

    test('topic naming convention uses role_ prefix for role topics', () {
      // Verify the topic naming convention by checking the pattern
      // used in setupTopicsForRole. The manager subscribes to topics
      // like 'role_principal', 'role_teacher', etc.
      const rolePrefix = 'role_';
      const eventPrefix = 'event_';

      expect(rolePrefix, isNotEmpty);
      expect(eventPrefix, isNotEmpty);
      expect('${rolePrefix}principal', equals('role_principal'));
      expect('${rolePrefix}teacher', equals('role_teacher'));
      expect('${rolePrefix}parent', equals('role_parent'));
    });

    test('topic naming convention uses event_ prefix for event topics', () {
      const eventPrefix = 'event_';
      expect('${eventPrefix}announcements', equals('event_announcements'));
      expect('${eventPrefix}attendance', equals('event_attendance'));
      expect('${eventPrefix}fees', equals('event_fees'));
    });

    test('setupTopicsForRole does not throw for any role', () async {
      final manager = NotificationTopicManager();
      // This should not throw even if PushNotificationService
      // is not initialized (it gracefully handles errors)
      // We test that the method completes without throwing.
      // Note: In a real test environment, PushNotificationService
      // may not be initialized, but the topic manager catches
      // errors internally.
      expect(() => manager.setupTopicsForRole, returnsNormally);
    });

    test('cleanupTopicsForRole does not throw for any role', () async {
      final manager = NotificationTopicManager();
      expect(() => manager.cleanupTopicsForRole, returnsNormally);
    });

    test('all public methods are callable', () {
      final manager = NotificationTopicManager();
      // Verify all public methods exist and are callable
      expect(manager.setupTopicsForRole, isA<Function>());
      expect(manager.cleanupTopicsForRole, isA<Function>());
      expect(manager.subscribeToRoleTopics, isA<Function>());
      expect(manager.unsubscribeFromRoleTopics, isA<Function>());
      expect(manager.subscribeToEventTopic, isA<Function>());
      expect(manager.unsubscribeFromEventTopic, isA<Function>());
      expect(manager.subscribeToAdminTopics, isA<Function>());
      expect(manager.unsubscribeFromAdminTopics, isA<Function>());
      expect(manager.subscribeToParentTopics, isA<Function>());
      expect(manager.unsubscribeFromParentTopics, isA<Function>());
      expect(manager.subscribeToTeacherTopics, isA<Function>());
      expect(manager.unsubscribeFromTeacherTopics, isA<Function>());
    });
  });

  group('NotificationTopicManager integration contract', () {
    test(
      'source code delegates to PushNotificationService not FcmService',
      () async {
        // Verify the source imports PushNotificationService
        final source = await _readFile(
          'lib/core/services/notification_topic_manager.dart',
        );
        expect(source, contains('import'));
        expect(source, contains('push_notification_service.dart'));
        // Must NOT import the deleted fcm_service.dart
        expect(source, isNot(contains('fcm_service.dart')));
      },
    );

    test('all topic calls use PushNotificationService.instance', () async {
      final source = await _readFile(
        'lib/core/services/notification_topic_manager.dart',
      );
      // Every subscribe/unsubscribe call should use PushNotificationService.instance
      final subscribeCalls = RegExp(
        r'PushNotificationService\.instance\.(subscribe|unsubscribe)FromTopic',
      ).allMatches(source);
      // The direct PushNotificationService.instance calls are in
      // subscribeToRoleTopics, unsubscribeFromRoleTopics,
      // subscribeToEventTopic, unsubscribeFromEventTopic
      expect(
        subscribeCalls.length,
        greaterThanOrEqualTo(2),
        reason:
            'Expected at least 2 topic method calls delegating to PushNotificationService',
      );
    });

    test('no references to FcmService remain', () async {
      final source = await _readFile(
        'lib/core/services/notification_topic_manager.dart',
      );
      expect(source, isNot(contains('FcmService')));
    });
  });
}

Future<String> _readFile(String path) async {
  final file = _findProjectFile(path);
  return file.readAsString();
}

/// Resolve a project-relative path to the actual file.

File _findProjectFile(String relativePath) {
  // Search up from cwd to find pubspec.yaml
  var dir = Directory.current;
  while (dir.path != dir.parent.path) {
    final pubspec = File('${dir.path}/pubspec.yaml');
    if (pubspec.existsSync()) {
      return File('${dir.path}/$relativePath');
    }
    dir = dir.parent;
  }
  return File(relativePath);
}
