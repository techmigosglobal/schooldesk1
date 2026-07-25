import 'dart:io';

import 'package:test/test.dart';

void main() {
  final migration = File(
    'supabase/migrations/20260724163304_error_event_retention_and_realtime_invalidation.sql',
  ).readAsStringSync();
  final handler = File(
    'supabase/functions/api/handlers/monitoring.ts',
  ).readAsStringSync();
  final api = File(
    'lib/core/network/api_modules/monitoring_api.dart',
  ).readAsStringSync();
  final reporter = File(
    'lib/core/services/error_reporting_service.dart',
  ).readAsStringSync();
  final realtime = File(
    'lib/core/services/realtime_refresh_service.dart',
  ).readAsStringSync();

  test(
    'error event records are bounded, deduplicated, and retained safely',
    () {
      expect(migration, contains('occurrence_count'));
      expect(migration, contains('idx_error_events_school_fingerprint'));
      expect(migration, contains('left(coalesce(p_stack_trace, \'\'), 12288)'));
      expect(migration, contains("where e.status = 'resolved'"));
      expect(migration, contains("e.severity <> 'fatal'"));
      expect(migration, contains("'enforce-error-event-retention'"));
      expect(migration, contains('error_event_daily_summaries'));
    },
  );

  test(
    'only the service-backed API can mutate retention policy or clear events',
    () {
      expect(handler, contains('isSuperAdmin(user)'));
      expect(handler, contains('CLEAR RESOLVED ERROR EVENTS'));
      expect(handler, contains('DELETE RESOLVED ERROR EVENT'));
      expect(
        handler,
        contains('Only resolved error events can be permanently deleted'),
      );
      expect(handler, contains('cleanup_resolved_error_events'));
      expect(handler, contains('recordActivity(svc'));
      expect(api, contains('getErrorRetentionMetrics'));
      expect(api, contains('previewResolvedErrorCleanup'));
      expect(api, contains('clearResolvedErrorEvents'));
      expect(api, contains('deleteResolvedErrorEvent'));
    },
  );

  test('client telemetry redacts and bounds reports before sending', () {
    expect(reporter, contains('_maxQueuedReports = 100'));
    expect(reporter, contains('_redactAndTruncate'));
    expect(reporter, contains('Bearer [redacted]'));
    expect(reporter, contains('_maxStackChars'));
  });

  test(
    'realtime delivers invalidation signals, never raw operational tables',
    () {
      expect(migration, contains('realtime_invalidation_events'));
      expect(migration, contains('trg_realtime_attendance_sessions'));
      expect(migration, contains('trg_realtime_fee_invoices'));
      expect(migration, contains('trg_realtime_notification_logs'));
      expect(migration, contains('recipient_user_id = auth.uid()'));
      expect(migration, contains('school_id = public.auth_school_id()'));
      expect(realtime, contains("table: 'realtime_invalidation_events'"));
      expect(realtime, isNot(contains("table: 'fee_invoices'")));
      expect(realtime, isNot(contains("table: 'student_attendances'")));
    },
  );

  test('critical user-facing modules retain their API-refresh realtime fallback', () {
    for (final path in [
      'lib/features/finance/presentation/screens/parent_hub/parent_fee_hub.dart',
      'lib/features/attendance/presentation/screens/parent_attendance_screen/parent_attendance_screen.dart',
      'lib/features/attendance/presentation/screens/teacher_attendance_screen/teacher_attendance_screen.dart',
      'lib/features/dashboard/presentation/screens/parent_dashboard_screen/parent_dashboard_screen.dart',
      'lib/features/dashboard/presentation/screens/principal_dashboard_screen/principal_dashboard_screen.dart',
      'lib/features/communication/presentation/screens/notification_center_screen/notification_center_screen.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(source, contains('RealtimeRefreshService.instance.subscribe'));
      expect(source, contains('dispose()'));
    }
  });
}
