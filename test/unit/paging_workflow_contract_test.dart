import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('interactive communication resources expose bounded page contracts', () {
    final handler = File(
      'supabase/functions/api/handlers/communications.ts',
    ).readAsStringSync();
    final client = File(
      'lib/core/network/api_modules/communications_api.dart',
    ).readAsStringSync();

    expect(
      handler,
      contains('path === "/chat/conversations" && method === "GET"'),
    );
    expect(handler, contains('path === "/diary" || path === "/diary-entries"'));
    expect(handler, contains('has_more: page * pageSize < total'));
    expect(
      handler,
      contains('message_conversations").select("*", { count: "exact" }'),
    );
    expect(handler, contains('messages").select("*", { count: "exact" }'));
    expect(handler, contains('announcements").select("*", { count: "exact" }'));
    expect(client, contains('getUnifiedChatConversationsPage'));
    expect(client, contains('getUnifiedChatMessagesPage'));
    expect(client, contains("'page_size': pageSize"));
  });

  test('homework list scope is paged and does not materialize attachments', () {
    final handler = File(
      'supabase/functions/api/handlers/homework.ts',
    ).readAsStringSync();
    final client = File(
      'lib/core/network/api_modules/homework_api.dart',
    ).readAsStringSync();

    expect(handler, contains('const pageSize = Math.min('));
    expect(handler, contains('data->>section_id'));
    expect(handler, contains('const pageRows = rows.slice'));
    expect(handler, contains('attachment_urls: _attachmentUrls'));
    expect(handler, contains('has_more: page * pageSize < total'));
    expect(client, contains("'page': page"));
    expect(client, contains("'page_size': pageSize"));
  });

  test('issues, events, and document queues use stable server pagination', () {
    final issues = File(
      'supabase/functions/api/handlers/issues.ts',
    ).readAsStringSync();
    final uploads = File(
      'supabase/functions/api/handlers/uploads.ts',
    ).readAsStringSync();

    expect(issues, isNot(contains('select("*, issue_attachments(*)",')));
    expect(issues, contains('page_size: pageSize'));
    expect(issues, contains('.order("id", { ascending: false })'));
    expect(uploads, contains('function listPaging'));
    expect(uploads, contains('path === "/event-posts/pending"'));
    expect(
      uploads,
      contains('path === "/documents/requests" && method === "GET"'),
    );
    expect(uploads, contains('return ok(listEnvelope('));
    expect(uploads, contains('.range(paging.from, paging.to)'));
  });

  test('academic reference lists enforce the shared server maximum', () {
    final handler = File(
      'supabase/functions/api/handlers/academics.ts',
    ).readAsStringSync();
    final rawApi = File(
      'lib/core/network/api_modules/tables_raw_api.dart',
    ).readAsStringSync();

    expect(handler, contains('Math.min('));
    expect(handler, contains('100,'));
    expect(handler, contains('function pagedResponse'));
    expect(handler, contains('range(pagination.from, pagination.to)'));
    expect(rawApi, contains("payload['items'] ?? payload['data']"));
  });

  test(
    'approval feed remains the single bounded queue with decision metadata',
    () {
      final handler = File(
        'supabase/functions/api/handlers/approvals.ts',
      ).readAsStringSync();
      final api = File(
        'lib/core/network/api_modules/approval_requests_api.dart',
      ).readAsStringSync();

      expect(
        handler,
        contains('path === "/approvals/feed" && method === "GET"'),
      );
      expect(handler, contains('counts_by_type'));
      expect(handler, contains('pending_count'));
      expect(handler, contains('expected_status'));
      expect(handler, contains('limit(100)'));
      expect(api, contains('getApprovalFeed'));
      expect(api, contains('PaginatedList<Map<String, dynamic>>'));
    },
  );
}
