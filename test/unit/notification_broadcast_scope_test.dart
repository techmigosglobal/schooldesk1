import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/modules/communication/data/api_notification_broadcast_repository.dart';

class _Transport implements HttpClientAdapter {
  final calls = <RequestOptions>[];
  Completer<ResponseBody>? pending;
  final dispatched = Completer<void>();

  ResponseBody response() => ResponseBody.fromString(
    jsonEncode({
      'success': true,
      'data': {'items': [], 'recipient_count': 1},
    }),
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? body,
    Future<void>? cancel,
  ) async {
    calls.add(options);
    if (!dispatched.isCompleted) dispatched.complete();
    return pending?.future ?? response();
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final api = BackendApiClient.instance;
  final auth = api.dio.interceptors.firstWhere(
    (i) => i.runtimeType.toString() == '_AuthInterceptor',
  );
  late _Transport transport;
  late ApiNotificationBroadcastRepository repository;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async => null,
        );
    api.dio.interceptors
      ..clear()
      ..add(auth);
    transport = _Transport();
    api.dio.httpClientAdapter = transport;
    api.setAuthToken('synthetic-notification-token');
    api.setCurrentUserId('principal-a');
    api.setCurrentRole('principal');
    await api.setActiveBranchId('school-a');
    repository = ApiNotificationBroadcastRepository(api);
  });

  Future<Map<String, dynamic>> send({bool all = false}) => repository.send(
    key: 'same-send-identity',
    title: 'School update',
    message: 'Please check the diary.',
    roles: {'parent'},
    all: all,
    userIds: {'parent-a'},
  );

  test(
    'GET and POST freeze expected school scope and preserve idempotency',
    () async {
      await repository.recipients(roles: {'parent'});
      await repository.history();
      await send();
      await send();
      expect(
        transport.calls.every(
          (call) =>
              call.extra['schooldeskExpectedScope'] ==
              'principal-a|school-a|principal',
        ),
        isTrue,
      );
      expect(
        transport.calls.every(
          (call) => call.headers['x-schooldesk-branch-id'] == 'school-a',
        ),
        isTrue,
      );
      final writes = transport.calls
          .where((call) => call.method == 'POST')
          .toList();
      expect(writes.length, 2);
      expect(
        writes.every(
          (call) => call.headers['Idempotency-Key'] == 'same-send-identity',
        ),
        isTrue,
      );
      expect(writes.first.data, writes.last.data);
      expect(writes.first.data['user_ids'], ['parent-a']);
    },
  );

  for (final all in [false, true]) {
    test(
      'stale adapter cannot send ${all ? "all" : "selected"} recipients in another school',
      () async {
        await api.setActiveBranchId('school-b');
        await expectLater(send(all: all), throwsStateError);
        expect(transport.calls, isEmpty);
      },
    );
  }

  test(
    'auth interceptor blocks school change between method and dispatch',
    () async {
      api.dio.interceptors.insert(
        0,
        InterceptorsWrapper(
          onRequest: (options, handler) async {
            await api.setActiveBranchId('school-b');
            handler.next(options);
          },
        ),
      );
      await expectLater(
        send(all: true),
        throwsA(
          isA<DioException>().having(
            (e) => e.type,
            'type',
            DioExceptionType.cancel,
          ),
        ),
      );
      expect(transport.calls, isEmpty);
    },
  );

  test('recipient response from previous account scope is rejected', () async {
    transport.pending = Completer<ResponseBody>();
    final reading = repository.recipients(roles: {'parent'});
    final rejected = expectLater(reading, throwsStateError);
    await transport.dispatched.future;
    api.setCurrentUserId('principal-b');
    transport.pending!.complete(transport.response());
    await rejected;
  });

  test(
    'principal role and authenticated session are required for stale screen sends',
    () async {
      api.setCurrentRole('coordinator');
      await expectLater(send(), throwsStateError);
      expect(transport.calls, isEmpty);
      api.clearAuthToken();
      await expectLater(send(), throwsStateError);
      expect(transport.calls, isEmpty);
    },
  );
}
