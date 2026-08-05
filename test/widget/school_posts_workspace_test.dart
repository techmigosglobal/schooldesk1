import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/theme/app_theme.dart';
import 'package:schooldesk1/features/communication/presentation/screens/event_post_screen.dart';

import '../support/finance_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestBackendAdapter adapter;

  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    adapter = TestBackendAdapter();
    BackendApiClient.instance.dio.httpClientAdapter = adapter;
    BackendApiClient.instance.setAuthToken('principal-school-posts-test');
    BackendApiClient.instance.setCurrentRole('principal');
    adapter.routes['GET /event-posts'] = {
      'success': true,
      'data': [
        {
          'id': 'published-1',
          'title': 'Published post',
          'description': 'Already live on the school feed',
          'approval_status': 'approved',
          'destinations': ['PARENTS_HOME'],
          'media_urls': <String>[],
        },
      ],
    };
    adapter.routes['GET /notifications'] = {
      'success': true,
      'data': <Map<String, dynamic>>[],
    };
  });

  tearDown(() {
    BackendApiClient.instance.clearAuthToken();
  });

  testWidgets('principal school posts opens Review when pending posts exist', (
    tester,
  ) async {
    adapter.routes['GET /event-posts/pending'] = {
      'success': true,
      'data': [_pendingPost('pending-1', 'Annual day needs review')],
    };

    await _pumpSchoolPosts(tester);

    expect(find.text('Pending review'), findsOneWidget);
    expect(find.text('Annual day needs review'), findsOneWidget);
    expect(find.text('Approve'), findsOneWidget);
  });

  testWidgets('principal school posts opens Manage when no review is pending', (
    tester,
  ) async {
    adapter.routes['GET /event-posts/pending'] = {
      'success': true,
      'data': <Map<String, dynamic>>[],
    };

    await _pumpSchoolPosts(tester);

    expect(find.text('Published post'), findsOneWidget);
    expect(find.text('No school posts are waiting for review.'), findsNothing);
  });

  testWidgets('principal school posts deep link prioritizes referenced post', (
    tester,
  ) async {
    adapter.routes['GET /event-posts/pending'] = {
      'success': true,
      'data': [_pendingPost('pending-1', 'Other pending post')],
    };
    adapter.routes['GET /event-posts/post-123'] = {
      'success': true,
      'data': _pendingPost('post-123', 'Referenced school post'),
    };

    await _pumpSchoolPosts(
      tester,
      args: const SchoolPostsRouteArgs(
        initialTab: 'review',
        referenceId: 'post-123',
        referenceType: 'event_post',
      ),
    );

    expect(find.text('Opened request'), findsOneWidget);
    expect(find.text('Referenced school post'), findsOneWidget);
    expect(find.text('Other pending posts'), findsOneWidget);
  });
}

Future<void> _pumpSchoolPosts(
  WidgetTester tester, {
  SchoolPostsRouteArgs args = const SchoolPostsRouteArgs(),
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: TeacherEventPostScreen(principalMode: true, args: args),
    ),
  );
  await tester.pumpAndSettle();
}

Map<String, dynamic> _pendingPost(String id, String title) {
  return {
    'id': id,
    'title': title,
    'description': 'Review this school post before it goes live.',
    'approval_status': 'pending',
    'status': 'pending',
    'event_date': '2026-08-05T00:00:00Z',
    'destinations': ['PARENTS_HOME'],
    'media_urls': <String>[],
  };
}
