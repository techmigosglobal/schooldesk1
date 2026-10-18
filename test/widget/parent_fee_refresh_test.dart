import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:schooldesk1/core/theme/app_theme.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/roles/parent/domain/parent_fee_payment_repository.dart';
import 'package:schooldesk1/features/finance/presentation/screens/parent_hub/parent_fee_hub.dart';

class _Fees implements ParentFeePaymentRepository {
  double balance = 100;
  bool submitted = false;
  int reads = 0;
  Completer<List<Map<String, dynamic>>>? blocked;
  @override
  Future<List<Map<String, dynamic>>> loadChildren({int? refreshNonce}) async =>
      [
        {'id': 'child', 'name': 'QA child'},
      ];
  @override
  Future<List<Map<String, dynamic>>> loadStudentFees(
    String studentId, {
    int? refreshNonce,
  }) async {
    reads++;
    final pending = blocked;
    if (pending != null) {
      blocked = null;
      return pending.future;
    }
    return rows();
  }

  List<Map<String, dynamic>> rows() => [
    {
      'id': 'invoice',
      'fee_type': 'tuition',
      'fee_item_name': 'Tuition',
      'balance': balance,
      'paid_amount': 100 - balance,
      'net_amount': 100,
      'status': balance == 0 ? 'paid' : 'unpaid',
      'due_date': '2026-10-10',
    },
  ];
  @override
  Future<List<Map<String, dynamic>>> loadPaymentRequests({
    String? studentId,
  }) async => submitted
      ? [
          {'invoice_id': 'invoice', 'status': 'submitted'},
        ]
      : [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> mount(WidgetTester tester, _Fees repo) async {
  BackendApiClient.instance.setCurrentRole('parent');
  GoogleFonts.config.allowRuntimeFetching = false;
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(430, 1100);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: ParentFeeHub(repository: repo),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('approved fee clears Pay Now on resume without an app restart', (
    tester,
  ) async {
    final repo = _Fees();
    await mount(tester, repo);
    expect(find.textContaining('Pay Now'), findsWidgets);
    repo.balance = 0;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(repo.reads, 2);
    expect(find.textContaining('Pay Now'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'update arriving during a refresh is rerun and newer balance wins',
    (tester) async {
      final repo = _Fees()..blocked = Completer<List<Map<String, dynamic>>>();
      final pending = repo.blocked!;
      await mount(tester, repo);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      repo.balance = 0;
      pending.complete([
        {
          'id': 'invoice',
          'balance': 100,
          'net_amount': 100,
          'status': 'unpaid',
        },
      ]);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(repo.reads, 2);
      expect(find.textContaining('Pay Now'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'submitted proof remains due and awaiting verification, without a duplicate pay action',
    (tester) async {
      final repo = _Fees()..submitted = true;
      await mount(tester, repo);
      expect(find.text('Awaiting verification'), findsWidgets);
      expect(find.textContaining('Pay Now'), findsNothing);
      expect(find.text('₹100'), findsWidgets);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
