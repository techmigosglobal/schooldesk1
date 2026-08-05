import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('event approval notification contracts', () {
    test('principal approvals load target post, attachments, and live refresh', () {
      final source = File(
        'lib/features/communication/presentation/screens/principal_event_approval_screen.dart',
      ).readAsStringSync();
      final mediaPreview = File(
        'lib/core/widgets/event_post_media_preview.dart',
      ).readAsStringSync();

      expect(source, contains('class EventApprovalRouteArgs'));
      expect(source, contains('initialPostId'));
      expect(source, contains('getEventPost'));
      expect(source, contains('getPrincipalEventPosts'));
      expect(source, contains('WidgetsBindingObserver'));
      expect(source, contains('Timer.periodic'));
      expect(source, contains('NotificationService.getInstance'));
      expect(source, contains('_buildAttachmentSection'));
      expect(source, contains('_openAttachmentPreview'));
      expect(source, contains('openEventPostMediaPreview'));
      expect(source, contains('updateEventPost('));
      expect(source, contains('_notifyAndReload(keepPost: editedPost)'));
      expect(
        source,
        contains(
          'try {\n      await BackendApiClient.instance.invalidateCachedReads();',
        ),
      );
      expect(source, contains('if (!dialogContext.mounted) return;'));
      expect(source, isNot(contains('launchUrl(Uri.parse')));
      expect(source, contains('EventPostMediaItem.parseList'));
      expect(source, contains('EventPostMediaPreview'));
      expect(mediaPreview, contains('VideoPlayerController.networkUrl'));
      expect(mediaPreview, contains('PdfPreview('));
      expect(
        source.indexOf('_buildAttachmentSection'),
        lessThan(source.indexOf('_buildDecisionActions')),
      );
    });

    test(
      'teacher event posts refresh from notifications, resume, and polling',
      () {
        final source = File(
          'lib/features/communication/presentation/screens/event_post_screen.dart',
        ).readAsStringSync();

        expect(source, contains('WidgetsBindingObserver'));
        expect(source, contains('Timer.periodic'));
        expect(source, contains('didChangeAppLifecycleState'));
        expect(source, contains('NotificationService.getInstance'));
        expect(source, contains('_loadPosts(showSpinner: false)'));
        expect(source, contains('_loadPosts();'));
        expect(source, contains('updateEventPost('));
        expect(source, contains('deleteEventPost('));
        expect(source, contains('_startEditingPost'));
        expect(source, contains('_deletePost'));
        expect(source, contains('Resubmit'));
        expect(source, contains('Images only.'));
        expect(source, isNot(contains("'mp4'")));
        expect(source, contains('EventPostMediaItem.parseList'));
      },
    );

    test('legacy approval route opens the combined review workspace', () {
      final routes = File('lib/routes/app_routes.dart').readAsStringSync();

      expect(routes, contains('SchoolPostsRouteArgs.fromRoute'));
      expect(routes, contains('TeacherEventPostScreen('));
      expect(routes, contains("fallbackTab: 'review'"));
      expect(routes, contains('ModalRoute.of(context)?.settings.arguments'));
    });
  });
}
