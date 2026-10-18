import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/theme/app_theme.dart';
import 'package:schooldesk1/modules/communication/domain/notification_broadcast_repository.dart';
import 'package:schooldesk1/features/communication/presentation/screens/principal_send_notification_screen/principal_send_notification_screen.dart';

class _Broadcasts implements NotificationBroadcastRepository {
  int sends = 0;
  bool failRecipients = false, failSend = false;
  Completer<Map<String, dynamic>>? pendingRecipients;
  final keys = <String>[];
  String? get key => keys.lastOrNull;
  @override
  Future<Map<String, dynamic>> recipients({
    required Set<String> roles,
    String search = '',
    int page = 1,
  }) async {
    if (failRecipients) {
      throw Exception('ServerException: private database detail');
    }
    if (pendingRecipients != null) return pendingRecipients!.future;
    return {
      'items': [
        {'id': 'one', 'name': 'QA parent', 'role_name': 'parent'},
      ],
      'total': 1,
    };
  }

  @override
  Future<Map<String, dynamic>> history({int page = 1}) async => {'items': []};
  @override
  Future<Map<String, dynamic>> send({
    required String key,
    required String title,
    required String message,
    required Set<String> roles,
    required bool all,
    required Set<String> userIds,
  }) async {
    keys.add(key);
    sends++;
    if (failSend) throw Exception('ServerException: private database detail');
    return {'recipient_count': 1};
  }
}

Future<void> _open(
  WidgetTester tester,
  _Broadcasts repo, {
  bool dark = false,
  Size size = const Size(900, 1400),
  double textScale = 1,
}) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  BackendApiClient.instance.setCurrentRole('principal');
  BackendApiClient.instance.setCurrentUserId('principal-test');
  await BackendApiClient.instance.setActiveBranchId('school-a');
  tester.view.physicalSize = size;
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
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: PrincipalSendNotificationScreen(repository: repo),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _draft(WidgetTester tester) async {
  await tester.enterText(find.byType(TextFormField).at(0), 'Tomorrow’s update');
  await tester.enterText(
    find.byType(TextFormField).at(1),
    'Please check the school diary.',
  );
}

Future<void> _review(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Review and send'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Review and send'));
  await tester.pumpAndSettle();
}

double _contrast(Color foreground, Color background) {
  final a = foreground.computeLuminance(), b = background.computeLuminance();
  return a > b ? (a + .05) / (b + .05) : (b + .05) / (a + .05);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async => null,
        );
  });

  for (final dark in [false, true]) {
    testWidgets(
      '${dark ? 'dark' : 'light'} principal confirms recipients before sending',
      (tester) async {
        final repo = _Broadcasts();
        await _open(tester, repo, dark: dark);
        await _draft(tester);
        await tester.tap(find.byType(CheckboxListTile).first);
        await tester.pump();
        await _review(tester);
        expect(repo.sends, 0);
        expect(find.text('Send notification?'), findsOneWidget);
        await tester.tap(find.text('Send').last);
        await tester.pumpAndSettle();
        expect(repo.sends, 1);
        expect(repo.key, matches(RegExp(r'^[a-f0-9-]{36}$')));
        expect(find.textContaining('saved for 1 recipients'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      },
    );

    test(
      '${dark ? 'dark' : 'light'} controls retain readable state colors',
      () {
        GoogleFonts.config.allowRuntimeFetching = false;
        final theme = dark ? AppTheme.darkTheme : AppTheme.lightTheme;
        final scheme = theme.colorScheme;
        expect(
          _contrast(scheme.onPrimaryContainer, scheme.primaryContainer),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          _contrast(scheme.onSecondaryContainer, scheme.secondaryContainer),
          greaterThanOrEqualTo(4.5),
        );
        for (final states in <Set<WidgetState>>[
          {},
          {WidgetState.selected},
          {WidgetState.selected, WidgetState.focused},
          {WidgetState.disabled},
          {WidgetState.selected, WidgetState.disabled},
        ]) {
          final style = theme.segmentedButtonTheme.style!;
          expect(
            _contrast(
              style.foregroundColor!.resolve(states)!,
              style.backgroundColor!.resolve(states)!,
            ),
            greaterThanOrEqualTo(4.5),
          );
          final chip = theme.chipTheme;
          final text = WidgetStateProperty.resolveAs(chip.labelStyle!, states);
          final background = states.contains(WidgetState.disabled)
              ? chip.disabledColor!
              : states.contains(WidgetState.selected)
              ? chip.selectedColor!
              : chip.backgroundColor!;
          expect(_contrast(text.color!, background), greaterThanOrEqualTo(4.5));
        }
        for (final selected in [false, true]) {
          final states = selected ? {WidgetState.selected} : <WidgetState>{};
          expect(
            _contrast(
              theme.switchTheme.thumbColor!.resolve(states)!,
              theme.switchTheme.trackColor!.resolve(states)!,
            ),
            greaterThanOrEqualTo(3),
          );
        }
        expect(
          _contrast(
            WidgetStateProperty.resolveAs(
              theme.inputDecorationTheme.labelStyle!,
              <WidgetState>{},
            ).color!,
            theme.inputDecorationTheme.fillColor!,
          ),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          _contrast(
            theme.inputDecorationTheme.errorStyle!.color!,
            theme.scaffoldBackgroundColor,
          ),
          greaterThanOrEqualTo(4.5),
        );
      },
    );

    testWidgets(
      '${dark ? 'dark' : 'light'} narrow enlarged composer supports validation and history',
      (tester) async {
        await _open(
          tester,
          _Broadcasts(),
          dark: dark,
          size: const Size(360, 1000),
          textScale: 1.6,
        );
        await _review(tester);
        expect(find.text('Enter a title'), findsOneWidget);
        expect(find.text('Enter a message'), findsOneWidget);
        await tester.ensureVisible(find.text('Recipient roles'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.widgetWithText(FilterChip, 'Teachers / co-teachers'),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byType(SwitchListTile));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(SwitchListTile));
        await tester.pumpAndSettle();
        expect(find.text('1 recipients selected'), findsOneWidget);
        await tester.ensureVisible(find.text('Sent history'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Sent history'));
        await tester.pumpAndSettle();
        expect(find.text('No notifications sent yet.'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'failed recipient refresh blocks send until explicit retry succeeds',
    (tester) async {
      final repo = _Broadcasts();
      await _open(tester, repo);
      await _draft(tester);
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      repo.failRecipients = true;
      await tester.tap(find.byTooltip('Refresh'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Recipients could not be loaded'),
        findsOneWidget,
      );
      expect(find.textContaining('ServerException'), findsNothing);
      await _review(tester);
      expect(find.text('Send notification?'), findsNothing);
      expect(repo.sends, 0);
      repo.failRecipients = false;
      await tester.ensureVisible(find.text('Retry recipients'));
      await tester.tap(find.text('Retry recipients'));
      await tester.pumpAndSettle();
      await _review(tester);
      expect(find.text('Send notification?'), findsOneWidget);
      await tester.tap(find.text('Send').last);
      await tester.pumpAndSettle();
      expect(repo.sends, 1);
    },
  );

  testWidgets('recipient load disables send and recovers after loading', (
    tester,
  ) async {
    final repo = _Broadcasts()
      ..pendingRecipients = Completer<Map<String, dynamic>>();
    await _open(tester, repo);
    final send = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Review and send'),
    );
    expect(send.onPressed, isNull);
    repo.pendingRecipients!.complete({'items': [], 'total': 0});
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Review and send'),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets(
    'send retry keeps draft and idempotency key without exposing server detail',
    (tester) async {
      final repo = _Broadcasts()..failSend = true;
      await _open(tester, repo);
      await _draft(tester);
      await tester.tap(find.byType(CheckboxListTile).first);
      await _review(tester);
      await tester.tap(find.text('Send').last);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('We could not confirm sending'),
        findsOneWidget,
      );
      expect(find.textContaining('ServerException'), findsNothing);
      expect(find.text('Tomorrow’s update'), findsOneWidget);
      repo.failSend = false;
      await _review(tester);
      await tester.tap(find.text('Send').last);
      await tester.pumpAndSettle();
      expect(repo.sends, 2);
      expect(repo.keys.first, repo.keys.last);
    },
  );
  for (final all in [false, true]) {
    testWidgets(
      'branch switch cancels ${all ? "all roles" : "selected people"} confirmation and resets recipients',
      (tester) async {
        final repo = _Broadcasts();
        await _open(tester, repo);
        await _draft(tester);
        await tester.tap(
          all
              ? find.byType(SwitchListTile)
              : find.byType(CheckboxListTile).first,
        );
        await tester.pumpAndSettle();
        await _review(tester);
        expect(find.text('Send notification?'), findsOneWidget);
        final next = Completer<Map<String, dynamic>>();
        repo.pendingRecipients = next;
        await BackendApiClient.instance.setActiveBranchId('school-b');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('Send notification?'), findsNothing);
        expect(repo.sends, 0);
        expect(find.text('Tomorrow’s update'), findsOneWidget);
        expect(find.text('0 recipients selected'), findsOneWidget);
        expect(
          tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
          isFalse,
        );
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Review and send'),
              )
              .onPressed,
          isNull,
        );
        next.complete({
          'items': [
            {'id': 'new', 'name': 'New school parent', 'role_name': 'parent'},
          ],
          'total': 1,
        });
        await tester.pumpAndSettle();
        expect(find.text('New school parent'), findsOneWidget);
        expect(find.text('QA parent'), findsNothing);
      },
    );
  }

  testWidgets(
    'scope change discards old in-flight recipients and account change clears private draft',
    (tester) async {
      final previous = Completer<Map<String, dynamic>>();
      final repo = _Broadcasts()..pendingRecipients = previous;
      await _open(tester, repo);
      await _draft(tester);
      final next = Completer<Map<String, dynamic>>();
      repo.pendingRecipients = next;
      BackendApiClient.instance.setCurrentUserId('different-principal');
      await tester.pump();
      previous.complete({
        'items': [
          {'id': 'old', 'name': 'Old account person', 'role_name': 'parent'},
        ],
        'total': 1,
      });
      await tester.pump();
      expect(find.text('Old account person'), findsNothing);
      expect(find.text('Tomorrow’s update'), findsNothing);
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).first)
            .controller!
            .text,
        isEmpty,
      );
      next.complete({'items': [], 'total': 0});
      await tester.pumpAndSettle();
      expect(find.text('0 recipients selected'), findsOneWidget);
    },
  );
}
