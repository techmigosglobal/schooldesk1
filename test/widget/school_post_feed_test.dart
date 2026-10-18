import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/features/communication/presentation/screens/event_post_screen.dart';
import 'package:schooldesk1/core/network/models/backend_models.dart';
import 'package:schooldesk1/core/theme/app_theme.dart';
import 'package:schooldesk1/features/communication/presentation/screens/school_post_feed_tab.dart';
import 'package:schooldesk1/modules/communication/domain/event_post_repository.dart';

class _Posts implements EventPostRepository {
  final rows = List.generate(
    125,
    (i) => <String, dynamic>{
      'id': '$i',
      'title': 'School post $i',
      'body': 'School update',
      'event_date': '2026-10-18',
      'status': 'approved',
      'destinations': ['PARENTS_HOME', 'SCHOOL_GALLERY', 'TEACHERS_HOME'],
      'media_urls': [
        {'url': 'https://example.invalid/video.mp4', 'kind': 'video'},
      ],
    },
  );
  final pages = <int>[];
  bool fail = false;
  String? lastId;
  List<String>? saved;
  @override
  Future<PaginatedList<Map<String, dynamic>>> loadPublishedPostsPage({
    int page = 1,
    int pageSize = 20,
    String destination = 'FEED',
  }) async {
    pages.add(page);
    if (fail) throw StateError('network failed');
    final filtered = rows.where((post) {
      final placements = post['destinations'] as List;
      return destination.isEmpty ||
          (destination == 'FEED'
              ? placements.any(['PARENTS_HOME', 'SCHOOL_GALLERY'].contains)
              : placements.contains(destination));
    }).toList();
    return PaginatedList(
      data: filtered
          .skip((page - 1) * pageSize)
          .take(pageSize)
          .map((e) => Map<String, dynamic>.from(e))
          .toList(),
      total: filtered.length,
      page: page,
      pageSize: pageSize,
    );
  }

  @override
  Future<void> updateVisibility(
    String id,
    List<String> destinations, {
    bool? publicGalleryVisible,
  }) async {
    if (fail) throw StateError('network failed');
    lastId = id;
    saved = destinations;
    final row = rows.firstWhere((post) => post['id'] == id);
    row['destinations'] = destinations;
    if (publicGalleryVisible != null) {
      row['public_gallery_visible'] = publicGalleryVisible;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> loadPosts({
    required bool principalMode,
  }) async => rows.take(20).toList();
  @override
  Future<List<Map<String, dynamic>>> loadPendingPosts() async => [];
  @override
  Future<void> invalidateCachedReads() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _openFeed(
  WidgetTester tester,
  _Posts repo, {
  bool dark = false,
  GlobalKey? capture,
}) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  tester.view.physicalSize = const Size(360, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(1.4)),
        child: child!,
      ),
      home: RepaintBoundary(
        key: capture,
        child: Scaffold(
          appBar: AppBar(title: const Text('School Posts · Feed')),
          body: SchoolPostFeedTab(repository: repo),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> menu(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Manage post visibility').first);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  testWidgets(
    'School Posts preserves Review Create Manage and opens the fourth Feed tab',
    (tester) async {
      GoogleFonts.config.allowRuntimeFetching = false;
      SharedPreferences.setMockInitialValues({});
      BackendApiClient.instance.setCurrentRole('principal');
      tester.view.physicalSize = const Size(360, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(1.4)),
              child: child!,
            ),
            home: TeacherEventPostScreen(
              principalMode: true,
              args: const SchoolPostsRouteArgs(initialTab: 'feed'),
              repository: _Posts(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      final tabs = tester.widget<TabBar>(find.byType(TabBar));
      expect(tabs.tabs.length, 4);
      expect(tabs.isScrollable, isTrue);
      expect(tabs.controller!.index, 3);
      expect(find.text('Add existing post'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
  for (final dark in [false, true]) {
    testWidgets(
      'feed list supports narrow ${dark ? 'dark' : 'light'} layout and destination removal',
      (tester) async {
        final repo = _Posts();
        final capture = GlobalKey();
        await _openFeed(tester, repo, dark: dark, capture: capture);
        expect(find.text('School post 0'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.runAsync(() async {
          final image =
              await (capture.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          Directory(
            '/tmp/schooldesk-feed-evidence',
          ).createSync(recursive: true);
          File(
            '/tmp/schooldesk-feed-evidence/feed-${dark ? 'dark' : 'light'}.png',
          ).writeAsBytesSync(bytes!.buffer.asUint8List());
          image.dispose();
        });
        await menu(tester);
        await tester.tap(find.text('Remove from Gallery'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Remove').last);
        await tester.pumpAndSettle();
        expect(repo.saved, ['PARENTS_HOME', 'TEACHERS_HOME']);
        expect(repo.rows.first['status'], 'approved');
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'hide everywhere remains restorable through the approved-post picker',
    (tester) async {
      final repo = _Posts();
      await _openFeed(tester, repo);
      await menu(tester);
      await tester.tap(find.text('Manage visibility'));
      await tester.pumpAndSettle();
      for (final title in ['Parent Feed', 'Gallery', 'Teacher Home']) {
        await tester.tap(find.widgetWithText(CheckboxListTile, title));
        await tester.pump();
      }
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(repo.saved, isEmpty);
      expect(find.text('School post 0'), findsNothing);
      await tester.tap(find.text('Add existing post'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('School post 0'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(repo.saved, ['PARENTS_HOME']);
      expect(repo.rows.first['status'], 'approved');
      expect(find.text('School post 0'), findsOneWidget);
    },
  );
  testWidgets(
    'public gallery stays independent of app destinations and can be explicitly hidden',
    (tester) async {
      final repo = _Posts();
      repo.rows.first['public_gallery_visible'] = true;
      await _openFeed(tester, repo);
      await menu(tester);
      await tester.tap(find.text('Remove from Gallery'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove').last);
      await tester.pumpAndSettle();
      expect(repo.rows.first['public_gallery_visible'], isTrue);
      await menu(tester);
      await tester.tap(find.text('Manage visibility'));
      await tester.pumpAndSettle();
      for (final title in [
        'Parent Feed',
        'Teacher Home',
        'Public website gallery',
      ]) {
        await tester.ensureVisible(
          find.widgetWithText(CheckboxListTile, title),
        );
        await tester.tap(find.widgetWithText(CheckboxListTile, title));
        await tester.pump();
      }
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(repo.rows.first['public_gallery_visible'], isFalse);
      expect(repo.saved, isEmpty);
      expect(repo.rows.first['status'], 'approved');
    },
  );
  testWidgets('failed visibility save keeps rows and reports failure', (
    tester,
  ) async {
    final repo = _Posts();
    await _openFeed(tester, repo);
    repo.fail = true;
    await menu(tester);
    await tester.tap(find.text('Remove from Gallery'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove').last);
    await tester.pumpAndSettle();
    expect(repo.saved, isNull);
    expect(find.text('School post 0'), findsOneWidget);
    expect(
      find.text('Unable to update visibility. Please retry.'),
      findsOneWidget,
    );
  });
  testWidgets(
    'pagination reaches posts beyond 100 and retries a failed filter reset',
    (tester) async {
      final repo = _Posts();
      await _openFeed(tester, repo);
      for (var page = 2; page <= 7; page++) {
        await tester.scrollUntilVisible(
          find.text('Load more'),
          600,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.tap(find.text('Load more'));
        await tester.pumpAndSettle();
      }
      expect(repo.pages, [1, 2, 3, 4, 5, 6, 7]);
      await tester.scrollUntilVisible(
        find.text('School post 124'),
        400,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('School post 124'), findsOneWidget);
      repo.fail = true;
      await tester.tap(find.widgetWithText(ChoiceChip, 'Gallery'));
      await tester.pumpAndSettle();
      repo.fail = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(repo.pages.last, 1);
      expect(find.text('School post 0'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
