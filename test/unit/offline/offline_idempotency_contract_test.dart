import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('both application Dio transports use the offline interceptor', () {
    final backend = File(
      'lib/core/network/backend_api_client.dart',
    ).readAsStringSync();
    final retrofit = File(
      'lib/core/network/schooldesk_api.dart',
    ).readAsStringSync();

    expect(backend, contains('OfflineDioInterceptor()'));
    expect(retrofit, contains('OfflineDioInterceptor()'));
  });

  test('homework drafts use the JSON offline write pipeline', () {
    final homework = File(
      'lib/core/network/api_modules/homework_api.dart',
    ).readAsStringSync();
    expect(homework, contains("data: _homeworkPayload("));
    expect(homework, contains("'offlineResourceType': 'homework'"));
    expect(homework, contains('_mergeLocalHomeworkDrafts'));
    expect(homework, contains('_homeworkNeedsOfflineDraft(attachmentUrl)'));
  });

  test('iOS background sync declares its WorkManager task identifier', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    expect(plist, contains('BGTaskSchedulerPermittedIdentifiers'));
    expect(plist, contains('schooldesk-periodic-offline-sync'));
  });

  test('Edge API persists and replays keyed authenticated mutations', () {
    final api = File('supabase/functions/api/index.ts').readAsStringSync();
    final migration = File(
      'supabase/migrations/20260913014816_api_idempotency_keys.sql',
    ).readAsStringSync();

    expect(api, contains('withIdempotency'));
    expect(api, contains('Idempotency-Key'));
    expect(api, contains('requestHash(req)'));
    expect(
      api,
      contains('request with this idempotency key is still processing'),
    );
    expect(api, contains('idempotency key was reused for a different request'));
    expect(api, contains('Idempotency-Replayed'));
    expect(api, contains('Deno.serve((req: Request) => withIdempotency'));

    expect(
      migration,
      contains('create table if not exists public.api_idempotency_keys'),
    );
    expect(
      migration,
      contains('unique index if not exists api_idempotency_keys_user_key_idx'),
    );
    expect(migration, contains('(user_id, school_id, idempotency_key)'));
    expect(
      migration,
      contains(
        'alter table public.api_idempotency_keys force row level security',
      ),
    );
    expect(
      migration,
      contains(
        'grant select, insert, update, delete on public.api_idempotency_keys to service_role',
      ),
    );
  });

  test('queued private uploads keep a durable storage reference', () {
    final engine = File(
      'lib/core/offline/offline_sync_engine.dart',
    ).readAsStringSync();
    expect(engine, contains("preferPath: privateUpload"));
    expect(engine, contains("const ['path', 'file_url', 'url'"));
    expect(engine, contains('signed URL'));
  });

  test('role-scope recovery probes the backend before invalidating cache', () {
    final main = File('lib/main.dart').readAsStringSync();
    expect(main, contains('probeBackend()'));
    expect(main, contains('Do not\n    // invalidate the only local snapshot'));
  });

  test('parent payment history remains cacheable while proof requests do not', () {
    final interceptor = File(
      'lib/core/network/api_modules/client_interceptors.dart',
    ).readAsStringSync();
    expect(interceptor, contains("/fees/payments reads are safe to cache"));
    expect(interceptor, contains("clean.contains('/payment-requests')"));
    expect(interceptor, isNot(contains("clean.contains('/payments') ||")));
  });

  test('authenticated reads are network-first with Drift as fallback', () {
    final interceptor = File(
      'lib/core/network/api_modules/client_interceptors.dart',
    ).readAsStringSync();
    expect(interceptor, contains('CachePolicy.refresh'));
    expect(
      interceptor,
      contains('hitCacheOnErrorExcept: const Nullable<List<int>>(null)'),
    );
    expect(interceptor, contains('Drift owns offline fallback'));
  });

  test('multipart uploads retain one idempotency key across queueing', () {
    final engine = File('lib/core/offline/offline_sync_engine.dart').readAsStringSync();
    expect(engine, contains('_isIdempotentUpload(options)'));
    expect(engine, contains('String? idempotencyKey'));
    expect(engine, contains("idempotencyKey!.trim()"));
  });
}
