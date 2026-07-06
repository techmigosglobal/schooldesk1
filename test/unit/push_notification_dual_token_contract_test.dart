import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('notification processor reads legacy rows but current writes stay canonical', () {
    final processor = File(
      'supabase/functions/notification-processor/index.ts',
    ).readAsStringSync();
    final communications = File(
      'supabase/functions/api/handlers/communications.ts',
    ).readAsStringSync();
    final healthReminders = File(
      'supabase/functions/api/handlers/health_reminders.ts',
    ).readAsStringSync();
    final birthdays = File(
      'supabase/functions/api/handlers/birthday_alerts.ts',
    ).readAsStringSync();
    final uploads = File(
      'supabase/functions/api/handlers/uploads.ts',
    ).readAsStringSync();
    final principal = File(
      'supabase/functions/api/handlers/principal.ts',
    ).readAsStringSync();
    final migration = File(
      'supabase/migrations/20260705170759_unify_notification_device_tokens.sql',
    ).readAsStringSync();

    expect(processor, contains('notification_device_tokens'));
    expect(processor, contains('activeDeviceTokensForUser'));
    expect(processor, contains('deactivateInvalidToken'));
    expect(communications, contains('path === "/notifications/device-tokens"'));
    expect(communications, contains('svc.from("notification_devices").upsert'));
    expect(
      communications,
      isNot(contains('svc.from("notification_device_tokens").upsert')),
    );
    expect(communications, contains('svc.from("notification_device_tokens").delete'));
    expect(healthReminders, contains('svc.from("notification_events")'));
    expect(healthReminders, contains('event_type: "health_reminder"'));
    expect(birthdays, contains('svc.from("notification_events")'));
    expect(uploads, contains('svc.from("notification_events")'));
    expect(principal, contains('svc.from("notification_events")'));
    expect(migration, contains('insert into public.notification_devices'));
    expect(migration, contains('from public.notification_device_tokens'));
  });
}
