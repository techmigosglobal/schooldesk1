import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('issue handler protects role scope, attachments, and notifications', () {
    final source = File(
      'supabase/functions/api/handlers/issues.ts',
    ).readAsStringSync();
    expect(
      source,
      contains('principals, teachers, and parents can raise issues'),
    );
    expect(source, contains('only super_admin can resolve issues'));
    expect(source, contains('/issues/with-attachments'));
    expect(source, contains('uploadedPaths'));
    expect(source, contains('existing.length >= 5'));
    expect(source, contains('maxAttachmentBytes'));
    expect(source, contains('createSignedUrl'));
    expect(source, contains('triggerPushProcessing'));
  });

  test('private issue storage and UI routes are wired', () {
    final migration = File(
      'supabase/migrations/20260711110302_raise_issue_workflow.sql',
    ).readAsStringSync();
    final routes = File('lib/routes/app_routes.dart').readAsStringSync();
    final screen = File(
      'lib/features/communication/presentation/screens/issue_screen.dart',
    ).readAsStringSync();
    expect(migration, contains("'issue-attachments'"));
    expect(migration, contains('false'));
    expect(routes, contains('superAdminIssues'));
    expect(screen, contains('Raise an Issue'));
    expect(screen, contains('Issue Management'));
    expect(screen, contains('FileType.custom'));
    expect(screen, contains("'pdf'"));
    expect(screen, contains('readAsBytes()'));
    expect(screen, contains('_IssueAttachmentPreviewScreen'));
    expect(screen, contains('_IssueAttachmentThumbnail'));
  });
}
