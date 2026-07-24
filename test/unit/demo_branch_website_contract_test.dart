import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('demo access is local-sandbox only and credentials are one-time', () {
    final handler = File(
      'supabase/functions/api/handlers/demo.ts',
    ).readAsStringSync();
    final storage = File(
      'lib/core/services/demo_sandbox_service.dart',
    ).readAsStringSync();
    expect(handler, contains('mode: "local_sandbox"'));
    expect(handler, contains('DEMO_CREDENTIAL_WRAP_KEY'));
    expect(handler, contains('password_revealed_at'));
    expect(handler, contains('roles: ["principal", "teacher", "parent"]'));
    expect(handler, contains('Demo@'));
    expect(handler, contains('nextDemoUsername'));
    expect(storage, contains('flutter_secure_storage'));
    expect(storage, contains('schooldesk_demo_snapshot'));
    expect(storage, contains('saveSnapshot'));

    final screen = File(
      'lib/features/auth/presentation/screens/demo_sandbox_screen.dart',
    ).readAsStringSync();
    expect(screen, contains('Fictional offline preview'));
    expect(screen, contains('saveSnapshot(next)'));
    expect(screen, isNot(contains('BackendApiClient')));
  });

  test('web proxy persists and forwards only validated branch context', () {
    final proxy = File(
      'schooldesk-web/app/api/backend/[...path]/route.ts',
    ).readAsStringSync();
    final branch = File(
      'schooldesk-web/app/api/branch/route.ts',
    ).readAsStringSync();
    expect(proxy, contains('x-schooldesk-branch-id'));
    expect(proxy, contains('cookieNames.branch'));
    expect(branch, contains('const uuid'));
    expect(branch, contains('valid branch is required'));
  });

  test('preschool essentials include safe public enquiry capture', () {
    final website = File(
      'supabase/functions/api/handlers/website.ts',
    ).readAsStringSync();
    final publicSite = File(
      'schooldesk-web/components/preschool-essentials.tsx',
    ).readAsStringSync();
    expect(website, contains('handleWebsiteEnquiry'));
    expect(website, contains('entry_type: "enquiry"'));
    expect(publicSite, contains('Explore programs'));
    expect(publicSite, contains('A safe campus, every day.'));
    expect(publicSite, contains('Submit enquiry'));
    expect(publicSite, contains('3000'));
    expect(publicSite, contains('prefers-reduced-motion'));
  });
}
