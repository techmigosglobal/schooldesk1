import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:schooldesk1/app/providers/app_providers.dart';
import 'package:schooldesk1/core/errors/failures.dart';
import 'package:schooldesk1/core/network/models/backend_models.dart';
import 'package:schooldesk1/core/utils/result.dart';
import 'package:schooldesk1/core/widgets/staff_qr_attendance_panel.dart';
import 'package:schooldesk1/modules/attendance/domain/repositories/kiosk_attendance_repository.dart';

void main() {
  testWidgets('kiosk shows explicit online-required retry state', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          kioskAttendanceRepositoryProvider.overrideWithValue(
            _OfflineKioskRepository(),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: StaffQrAttendancePanel(compact: true)),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(
      find.text('Online connection required for live QR tokens and scan logs.'),
      findsOneWidget,
    );
    expect(find.text('Retry connection'), findsOneWidget);
  });
}

class _OfflineKioskRepository implements KioskAttendanceRepository {
  @override
  Future<Result<StaffQrTokenModel>> getToken({String? nonce}) async {
    return const Result.err(NetworkFailure());
  }

  @override
  Future<Result<List<StaffAttendanceModel>>> getRecentScans({
    String? date,
  }) async {
    return const Result.err(NetworkFailure());
  }

  @override
  Future<Result<Uint8List>> exportLogs({String? date}) async {
    return const Result.err(NetworkFailure());
  }
}
