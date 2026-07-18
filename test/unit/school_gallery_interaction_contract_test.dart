import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('gallery cover taps open the post detail screen', () {
    final source = File(
      'lib/features/shared/presentation/screens/school_gallery_screen.dart',
    ).readAsStringSync();

    expect(source, contains('onTap: () => _showDetails(context)'));
    expect(source, contains('final VoidCallback onTap;'));
    expect(source, contains('onImageTap: onTap'));
  });

  test('school-assets explicitly allows event-post video MIME types', () {
    final migration = File(
      'supabase/migrations/20260718042130_allow_event_post_videos_in_school_assets.sql',
    ).readAsStringSync();

    expect(migration, contains("where id = 'school-assets'"));
    expect(migration, contains("'video/mp4'"));
    expect(migration, contains("'video/quicktime'"));
    expect(migration, contains("'video/x-m4v'"));
    expect(migration, contains("'video/webm'"));
  });
}
