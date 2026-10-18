import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:schooldesk1/core/theme/app_theme.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/utils/result.dart';
import 'package:schooldesk1/features/dashboard/presentation/screens/parent_dashboard_screen/parent_dashboard_screen.dart';
import 'package:schooldesk1/roles/parent/domain/parent_dashboard_repository.dart';
import 'package:schooldesk1/roles/parent/domain/parent_dashboard_snapshot.dart';

class _Dashboard implements ParentDashboardRepository {
  final String? status;
  final bool finalized;
  const _Dashboard(this.status, this.finalized);
  @override
  Future<Result<ParentDashboardSnapshot>> load({
    bool forceRefresh = false,
    bool includeFeedPosts = true,
  }) async => Result.ok(
    ParentDashboardSnapshot(
      dashboard: {
        'school_name': 'ArishVille PreSchool',
        'children': [
          {
            'id': 'child-one',
            'name': 'QA child',
            'attendance_pct': null,
            'attendance_today': {'status': status, 'is_finalized': finalized},
            'homework_due': 0,
            'pending_fee_balance': 0,
            'unread_messages': 0,
          },
        ],
      },
      feed: null,
    ),
  );
}

void main() {
  setUp(() {
    BackendApiClient.instance.setCurrentRole('parent');
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
  });
  for (final brightness in Brightness.values) {
    testWidgets(
      'parent dashboard ${brightness.name} uses a readable themed surface and today status',
      (tester) async {
        tester.view.physicalSize = const Size(430, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: brightness == Brightness.dark
                  ? AppTheme.darkTheme
                  : AppTheme.lightTheme,
              home: RepaintBoundary(
                key: const Key('capture'),
                child: const ParentDashboardScreen(
                  dashboardRepository: _Dashboard('present', true),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        expect(find.text('Present'), findsOneWidget);
        expect(find.text('Settings'), findsOneWidget);
        expect(find.text('Profile'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  testWidgets('unsubmitted attendance is distinguished from absence', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const ParentDashboardScreen(
            dashboardRepository: _Dashboard('absent', false),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Not submitted'), findsOneWidget);
    expect(find.text('Absent'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
