import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

typedef TestRouteHandler =
    FutureOr<Map<String, dynamic>> Function(RequestOptions options);

class TestBackendAdapter implements HttpClientAdapter {
  final Map<String, Map<String, dynamic>> routes = {};
  final Map<String, TestRouteHandler> handlers = {};
  final List<RequestOptions> seenRequests = <RequestOptions>[];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    seenRequests.add(options);
    final key = '${options.method.toUpperCase()} ${options.path}';
    final handler = handlers[key];
    final payload = handler != null ? await handler(options) : routes[key];
    if (payload == null) {
      return ResponseBody.fromString(
        jsonEncode({'success': false, 'error': 'Missing fake route $key'}),
        404,
        headers: {
          Headers.contentTypeHeader: <String>[Headers.jsonContentType],
        },
      );
    }
    final responseBody = Map<String, dynamic>.from(payload);
    final statusCode = responseBody.remove('__status') as int? ?? 200;
    return ResponseBody.fromString(
      jsonEncode(responseBody),
      statusCode,
      headers: {
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }
}

Future<File> createTestProofImage() async {
  const pngBase64 =
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9WmF0X0AAAAASUVORK5CYII=';
  final bytes = base64Decode(pngBase64);
  final directory = Directory.systemTemp.createTempSync('fees-proof-');
  final file = File('${directory.path}/proof.png');
  file.writeAsBytesSync(bytes);
  return file;
}

Map<String, String> formDataFields(FormData data) {
  return <String, String>{
    for (final field in data.fields) field.key: field.value,
  };
}

FormData expectFormData(Object? value) {
  expect(value, isA<FormData>());
  return value as FormData;
}
