import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/theme/app_theme.dart';
import 'package:schooldesk1/core/utils/result.dart';
import 'package:schooldesk1/roles/parent/domain/parent_attendance_repository.dart';
import 'package:schooldesk1/roles/parent/domain/parent_attendance_snapshot.dart';
import 'package:schooldesk1/features/attendance/presentation/screens/parent_attendance_screen/parent_attendance_screen.dart';

class _Attendance implements ParentAttendanceRepository {
  bool cached = true;
  int reads = 0;
  @override
  Future<Result<List<Map<String, dynamic>>>> getChildren({
    bool forceRefresh = false,
  }) async => Result.ok([
    {'id': 'child', 'name': 'QA child'},
  ]);
  @override
  Future<Result<ParentAttendanceSnapshot>> loadChild({
    required String studentId,
    bool forceRefresh = false,
  }) async {
    reads++;
    return Result.ok(
      ParentAttendanceSnapshot(
        summary: {'present': 3},
        records: [],
        leaveRequests: [],
        fromCache: cached,
      ),
    );
  }
}

void main() {
  testWidgets(
    'attendance saved-data status clears after a successful resume refresh',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      GoogleFonts.config.allowRuntimeFetching = false;
      BackendApiClient.instance.setCurrentRole('parent');
      tester.view.physicalSize = const Size(900, 1500);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = _Attendance();
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: ParentAttendanceScreen(repository: repo),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.textContaining('Showing saved data'), findsOneWidget);
      repo.cached = false;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(repo.reads, 2);
      expect(find.textContaining('Showing saved data'), findsNothing);
      expect(find.text('Retry'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
