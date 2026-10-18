import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:schooldesk1/core/errors/failures.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/theme/app_theme.dart';
import 'package:schooldesk1/core/utils/result.dart';
import 'package:schooldesk1/core/widgets/school_brand_logo.dart';
import 'package:schooldesk1/features/dashboard/presentation/screens/principal_dashboard_screen/principal_dashboard_screen.dart';
import 'package:schooldesk1/roles/principal/domain/leadership_dashboard_repository.dart';
import 'package:schooldesk1/roles/principal/domain/leadership_dashboard_snapshot.dart';
import 'package:schooldesk1/routes/app_routes.dart';

class _EmptyReads implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    jsonEncode({
      'success': true,
      'data': {'items': [], 'branches': [], 'date': '2026-10-18'},
    }),
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
  @override
  void close({bool force = false}) {}
}

class _Dashboard implements LeadershipDashboardRepository {
  int loads = 0;
  bool fail = false;
  String logo = '';
  @override
  Future<Result<LeadershipDashboardCriticalSnapshot>> loadCritical({
    required String role,
  }) async {
    loads++;
    return Result.ok(
      LeadershipDashboardCriticalSnapshot(
        dashboard: {
          'metrics': {'active_unassigned_students': 2},
        },
        school: {
          'id': 'school-a',
          'name': 'Arishville',
          'school_type': 'Preschool',
          'principal_name': 'Principal',
          'logo_url': logo,
        },
        profile: UserResponse.fromJson({'name': 'Shilpa', 'id': 'qa'}),
      ),
    );
  }

  @override
  Future<Result<LeadershipDashboardOptionalSnapshot>> loadOptional({
    required String role,
    required Map<String, dynamic> dashboard,
  }) async {
    if (fail)
      return const Result.err(ServerFailure(message: 'Guidance unavailable'));
    return const Result.ok(
      LeadershipDashboardOptionalSnapshot(
        academicYears: [],
        grades: [],
        sections: [],
        subjects: [],
        staff: PaginatedList<StaffModel>(
          data: [],
          total: 0,
          page: 1,
          pageSize: 1,
        ),
        students: PaginatedList<StudentModel>(
          data: [],
          total: 0,
          page: 1,
          pageSize: 1,
        ),
        feeStructures: [],
        notifications: [],
        staffAttendanceSummary: {},
        attentionCounts: {'event': 2, 'leave': 3, 'account': 1, 'fee': 0},
      ),
    );
  }
}

Future<void> _open(
  WidgetTester tester,
  _Dashboard repository, {
  bool dark = false,
  GlobalKey? capture,
}) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  SharedPreferences.setMockInitialValues({});
  BackendApiClient.instance.dio.interceptors.clear();
  BackendApiClient.instance.dio.httpClientAdapter = _EmptyReads();
  BackendApiClient.instance.setCurrentRole('principal');
  tester.view.physicalSize = const Size(360, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(1.3)),
          child: child!,
        ),
        routes: {
          AppRoutes.principalSchoolProfile: (context) =>
              Scaffold(appBar: AppBar(title: const Text('School Profile'))),
        },
        home: RepaintBoundary(
          key: capture,
          child: PrincipalDashboardScreen(dashboardRepository: repository),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  setUpAll(() async {
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  testWidgets(
    'logo contains the full image and missing/broken images retain a fallback',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const SchoolBrandLogo(imageUrl: '', size: 56),
        ),
      );
      expect(find.byIcon(Icons.account_balance_rounded), findsOneWidget);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const SchoolBrandLogo(
            imageUrl: 'https://example.invalid/logo.png',
            size: 56,
          ),
        ),
      );
      expect(tester.widget<Image>(find.byType(Image)).fit, BoxFit.contain);
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.account_balance_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  for (final dark in [false, true]) {
    testWidgets(
      'all missing setup and action groups appear in ${dark ? 'dark' : 'light'} dashboard',
      (tester) async {
        final repository = _Dashboard();
        final capture = GlobalKey();
        await _open(tester, repository, dark: dark, capture: capture);
        await tester.scrollUntilVisible(
          find.text('Needs attention'),
          500,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('2 · School posts awaiting review'), findsOneWidget);
        expect(find.text('3 · Staff leave requests'), findsOneWidget);
        expect(find.text('0 · Fee requests'), findsNothing);
        await tester.scrollUntilVisible(
          find.text('School Setup Progress'),
          450,
          scrollable: find.byType(Scrollable).first,
        );
        expect(
          find.text('2 student(s) need a class assignment'),
          findsOneWidget,
        );
        expect(find.text('Select the current academic year'), findsOneWidget);
        expect(
          find.text('Create classes for the current academic year'),
          findsOneWidget,
        );
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
            '/tmp/schooldesk-feed-evidence/setup-${dark ? 'dark' : 'light'}.png',
          ).writeAsBytesSync(bytes!.buffer.asUint8List());
          image.dispose();
        });
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  testWidgets('returning from the profile refreshes dashboard branding', (
    tester,
  ) async {
    final repository = _Dashboard();
    await _open(tester, repository);
    await tester.scrollUntilVisible(
      find.text('Recommended: add your school logo'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    final initial = repository.loads;
    await tester.tap(find.text('Recommended: add your school logo'));
    await tester.pumpAndSettle();
    repository.logo = 'https://example.invalid/saved-logo.png';
    await tester.pageBack();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(repository.loads, greaterThan(initial));
    expect(find.text('Recommended: add your school logo'), findsNothing);
    await tester.scrollUntilVisible(
      find.byType(SchoolBrandLogo),
      -500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<SchoolBrandLogo>(find.byType(SchoolBrandLogo)).imageUrl,
      contains('saved-logo.png'),
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
    'failed guidance never becomes a zero-count or missing-setup claim',
    (tester) async {
      final repository = _Dashboard()..fail = true;
      await _open(tester, repository);
      await tester.scrollUntilVisible(
        find.text('School guidance unavailable'),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Needs attention'), findsNothing);
      expect(find.text('School Setup Progress'), findsNothing);
      expect(find.text('Recommended: add your school logo'), findsNothing);
      expect(find.text('Retry'), findsWidgets);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
