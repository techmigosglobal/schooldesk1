import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/services/notification_service.dart';

class _Feed implements HttpClientAdapter {
  int reads = 0;
  String subject = 'Initial subject';
  Completer<ResponseBody>? pending;
  ResponseBody response(String title) => ResponseBody.fromString(
    jsonEncode({
      'success': true,
      'data': {
        'items': [
          {
            'id': 'one',
            'target_role': 'parent',
            'title': title,
            'type': 'general',
            'is_read': false,
          },
        ],
        'has_more': false,
      },
    }),
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? s,
    Future<void>? f,
  ) async {
    if (o.path == '/notifications') {
      reads++;
      if (pending != null) {
        final p = pending!;
        pending = null;
        return p.future;
      }
      return response(subject);
    }
    return ResponseBody.fromString(
      jsonEncode({
        'success': true,
        'data': o.path.endsWith('unread-count') ? {'count': 1} : {},
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'an inbox update during a refresh forces a follow-up read and newest subject wins',
    () async {
      NotificationService.resetInstance();
      final api = BackendApiClient.instance;
      final feed = _Feed();
      api.dio.interceptors.clear();
      api.dio.httpClientAdapter = feed;
      api.setAuthToken('synthetic');
      api.setCurrentUserId('notification-refresh-test');
      api.setCurrentRole('parent');
      final service = await NotificationService.getInstance();
      final blocked = Completer<ResponseBody>();
      feed.pending = blocked;
      final first = service.refresh();
      for (var i = 0; i < 20 && feed.reads < 2; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      final second = service.refresh();
      feed.subject = 'New subject after update';
      blocked.complete(feed.response('Older in-flight subject'));
      await Future.wait([first, second]);
      expect(feed.reads, 3);
      expect(service.notifications.single.title, 'New subject after update');
      expect(service.totalUnread, 1);
      NotificationService.resetInstance();
    },
  );
}
