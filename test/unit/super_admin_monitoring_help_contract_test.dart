import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('monitoring keeps server-side filters and super-admin protection', () {
    final source = File(
      'supabase/functions/api/handlers/monitoring.ts',
    ).readAsStringSync();
    expect(source, contains('forbidden: super_admin required'));
    expect(source, contains('.contains("context", { status })'));
    expect(source, contains('.range((page - 1) * size, page * size - 1)'));
    expect(source, contains('created_at'));
  });

  test('help tutorials use private, role-checked signed playback', () {
    final handler = File(
      'supabase/functions/api/handlers/help.ts',
    ).readAsStringSync();
    final migration = File(
      'supabase/migrations/20260711104127_super_admin_monitoring_and_help_tutorials.sql',
    ).readAsStringSync();
    final screen = File(
      'lib/features/shared/presentation/screens/help_screen/help_screen.dart',
    ).readAsStringSync();
    expect(handler, contains('createSignedUrl'));
    expect(handler, contains('data.role_name !== currentRole'));
    expect(handler, contains('help-tutorial-videos'));
    expect(migration, contains("'help-tutorial-videos'"));
    expect(migration, contains('false'));
    expect(screen, contains('uploadHelpTutorialVideo'));
    expect(screen, contains('VideoPlayerController.networkUrl'));
    expect(screen, isNot(contains('Video Tutorial URL (Optional)')));
  });
}
