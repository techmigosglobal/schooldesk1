import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('school feed auto-slides each post media item before moving posts', () {
    final source = File(
      'lib/features/dashboard/presentation/screens/parent_dashboard_screen/parent_dashboard_screen.dart',
    ).readAsStringSync();

    expect(source, contains('class _PostMediaCarousel'));
    expect(source, contains('_displayDurationForCurrentPost'));
    expect(source, contains('item.isVideo ? 8 : 3'));
    expect(
      source,
      contains(r"'${_currentIndex + 1}/${widget.mediaItems.length}'"),
    );
  });

  test('feed videos autoplay muted and provide an unmute control', () {
    final source = File(
      'lib/core/widgets/event_post_media_preview.dart',
    ).readAsStringSync();

    expect(source, contains('this.autoPlay = false'));
    expect(source, contains('this.muted = true'));
    expect(source, contains("tooltip: _muted ? 'Unmute video' : 'Mute video'"));
  });

  test('feed cards are media-first while details retain post copy', () {
    final source = File(
      'lib/features/dashboard/presentation/screens/parent_dashboard_screen/parent_dashboard_screen.dart',
    ).readAsStringSync();
    final cardSource = source.substring(source.indexOf('class _PostCard'));

    expect(cardSource, contains('_PostMediaCarousel('));
    expect(cardSource, isNot(contains("'Read More'")));
    expect(cardSource, isNot(contains('No description available.')));
    expect(source, contains('void _showPostDetailsBottomSheet('));
    expect(source, contains('Text(\n                      description,'));
  });

  test('principal has a direct school-feed publishing route', () {
    final routes = File('lib/routes/app_routes.dart').readAsStringSync();
    final guard = File('lib/routes/route_access_guard.dart').readAsStringSync();
    final handler = File(
      'supabase/functions/api/handlers/uploads.ts',
    ).readAsStringSync();

    expect(routes, contains('principalEventPosts'));
    expect(routes, contains('TeacherEventPostScreen('));
    expect(routes, contains('principalMode: true'));
    expect(routes, contains('_schoolPostsArgs(context)'));
    expect(guard, contains("AppRoutes.principalEventPosts: {'principal'}"));
    expect(
      handler,
      contains('const directPublish = isPrincipal && body.is_submit === true'),
    );
    expect(handler, contains('status: directPublish'));
  });

  test('event-post lists avoid ambiguous user relationship embeds', () {
    final handler = File(
      'supabase/functions/api/handlers/uploads.ts',
    ).readAsStringSync();

    expect(handler, contains('async function eventPostRows('));
    expect(handler, contains('select("id, name, username")'));
    expect(handler, contains('await eventPostRows(svc,'));
    expect(handler, isNot(contains('created_by:users(name)')));
  });

  test('signed-in teachers and parents own their username and password', () {
    final profile = File(
      'lib/features/profile/presentation/screens/profile_management_screen/profile_management_screen.dart',
    ).readAsStringSync();
    final settings = File(
      'lib/features/profile/presentation/screens/settings_screen/settings_screen.dart',
    ).readAsStringSync();
    final authHandler = File(
      'supabase/functions/api/handlers/auth.ts',
    ).readAsStringSync();

    expect(profile, contains("'username': username"));
    expect(profile, contains("'Use this username when you sign in."));
    expect(settings, contains('Change Password'));
    expect(authHandler, contains('current_password required'));
    expect(authHandler, contains('password: profileText(current_password)'));
    expect(authHandler, contains('updateOwnUsernameAlias'));
  });
}
