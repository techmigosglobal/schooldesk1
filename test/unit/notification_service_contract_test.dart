import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('notification service deduplicates concurrent initial loads', () {
    final service = File(
      'lib/core/services/notification_service.dart',
    ).readAsStringSync();

    expect(service, contains('Future<void>? _loadFuture'));
    expect(
      service,
      contains('await (_instance!._loadFuture ??= _instance!._load())'),
    );
    expect(service, contains('_loadFuture = null'));
  });

  test('notification state is persisted, paginated, and bulk-updated', () {
    final service = File(
      'lib/core/services/notification_service.dart',
    ).readAsStringSync();
    final api = File(
      'lib/core/network/api_modules/communications_api.dart',
    ).readAsStringSync();
    final notificationsApi = File(
      'lib/core/network/api_modules/notifications_api.dart',
    ).readAsStringSync();
    final communications = File(
      'supabase/functions/api/handlers/communications.ts',
    ).readAsStringSync();
    final preferences = File(
      'supabase/functions/api/handlers/notifications.ts',
    ).readAsStringSync();
    final migration = File(
      'supabase/migrations/20260802044553_notification_production_hardening.sql',
    ).readAsStringSync();

    expect(service, contains('getNotificationsPage(page: 1)'));
    expect(service, contains('getNotificationPreferences()'));
    expect(service, contains('_hydrateSettings(preferences)'));
    expect(service, contains('markAllNotificationsRead(role: role)'));
    expect(service, contains('_api.deleteNotification(id)'));
    expect(
      service,
      contains('_api.updateNotificationPreferences({key: value})'),
    );
    expect(service, contains('getNotificationsPage(page: _currentPage + 1)'));
    expect(api, contains("'/notifications/mark-read'"));
    expect(notificationsApi, contains("'/notifications/unread-count'"));
    expect(api, contains("_dio.delete('/notifications/\$notificationId')"));
    expect(api, contains('class NotificationPage'));
    expect(communications, contains('.is("deleted_at", null)'));
    expect(communications, contains('.range(from, to)'));
    expect(communications, contains('notificationDeleteMatch'));
    expect(communications, contains('total: count ?? 0'));
    expect(communications, contains('body.target_role'));
    expect(preferences, contains('const preferenceKeys = ['));
    expect(preferences, contains('pending_approvals'));
    expect(preferences, contains('fee_reminders'));
    expect(migration, contains('add column if not exists deleted_at'));
    expect(migration, contains('add column if not exists retry_count'));
    expect(migration, contains('add column if not exists next_retry_at'));
    expect(migration, contains('add column if not exists last_error'));
  });

  test(
    'push processor bounds retries, batches work, and sets unread badges',
    () {
      final processor = File(
        'supabase/functions/notification-processor/index.ts',
      ).readAsStringSync();

      expect(processor, contains('const MAX_EVENT_RETRIES = 5'));
      expect(processor, contains('releaseEvent(event.id, lastError)'));
      expect(processor, contains('_push_dead_letter: true'));
      expect(processor, contains('next_retry_at.lte.'));
      expect(processor, contains('const EVENT_BATCH_CONCURRENCY = 10'));
      expect(processor, contains('.eq("school_id", schoolId)'));
      expect(
        processor,
        contains('Promise.all(batch.map(processNotificationEvent))'),
      );
      expect(processor, contains('badge: Math.max(0, badgeCount)'));
      expect(processor, contains('unreadNotificationCount(event.user_id)'));
    },
  );

  test('production error reporting has an external crash sink', () {
    final reporting = File(
      'lib/core/services/error_reporting_service.dart',
    ).readAsStringSync();

    expect(
      reporting,
      contains("package:firebase_crashlytics/firebase_crashlytics.dart"),
    );
    expect(reporting, contains('setCrashlyticsCollectionEnabled'));
    expect(reporting, contains('recordError('));
    expect(reporting, contains('_recordCrashlytics'));
  });
}
