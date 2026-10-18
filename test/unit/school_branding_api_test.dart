import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/utils/media_url.dart';
import 'package:schooldesk1/core/config/env_config.dart';

class _Adapter implements HttpClientAdapter {
  String logo = 'https://example.invalid/old.png';
  String school = 'branch-a';
  int reads = 0;
  bool failUpload = false;
  Completer<void>? pending;
  Completer<void>? entered;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    var status = 200;
    Map<String, dynamic> data;
    if (options.method == 'POST') {
      if (failUpload) {
        status = 500;
        data = {'success': false, 'error': 'School logo could not be saved'};
      } else {
        logo = 'https://example.invalid/new.png';
        data = {
          'success': true,
          'data': {'logo_url': logo},
        };
      }
    } else {
      reads++;
      final row = {'id': school, 'logo_url': logo};
      entered?.complete();
      entered = null;
      await pending?.future;
      data = {'success': true, 'data': row};
    }
    return ResponseBody.fromString(
      jsonEncode(data),
      status,
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
  late BackendApiClient api;
  late _Adapter adapter;
  setUp(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async => null,
        );
    api = BackendApiClient.instance;
    adapter = _Adapter();
    api.dio.options.baseUrl = 'http://127.0.0.1:54321/functions/v1/api';
    api.dio.interceptors.clear();
    api.dio.httpClientAdapter = adapter;
    api.setCurrentUserId('qa-branding');
    api.setCurrentRole('principal');
    await api.setActiveBranchId('branch-a');
    await api.invalidateCachedReads();
  });
  test(
    'upload invalidates school cache; failed persistence does not report success',
    () async {
      expect((await api.getCurrentSchool())['logo_url'], contains('old.png'));
      await api.uploadCurrentSchoolLogo(
        '',
        fileBytes: Uint8List.fromList([1]),
        fileName: 'logo.png',
        mimeType: 'image/png',
      );
      expect((await api.getCurrentSchool())['logo_url'], contains('new.png'));
      expect(adapter.reads, 2);
      adapter.failUpload = true;
      await expectLater(
        api.uploadCurrentSchoolLogo(
          '',
          fileBytes: Uint8List.fromList([1]),
          fileName: 'logo.png',
        ),
        throwsA(isA<Exception>()),
      );
    },
  );
  test(
    'profile save replaces branding and branch switches discard cached school',
    () async {
      await api.getCurrentSchool();
      adapter.logo = 'https://example.invalid/profile.png';
      await api.updateCurrentSchool({'name': 'Updated'});
      expect(
        (await api.getCurrentSchool())['logo_url'],
        contains('profile.png'),
      );
      adapter.school = 'branch-b';
      await api.setActiveBranchId('branch-b');
      expect((await api.getCurrentSchool())['id'], 'branch-b');
    },
  );
  test(
    'an old branch response cannot repopulate the new branch cache',
    () async {
      adapter.pending = Completer<void>();
      adapter.entered = Completer<void>();
      final entered = adapter.entered!.future;
      final obsolete = api.getCurrentSchool(forceRefresh: true);
      final rejected = expectLater(obsolete, throwsA(isA<Exception>()));
      await entered;
      await api.setActiveBranchId('branch-b');
      adapter.school = 'branch-b';
      adapter.pending!.complete();
      await rejected;
      adapter.pending = null;
      expect((await api.getCurrentSchool())['id'], 'branch-b');
    },
  );
  test('school logos reuse internal, legacy and original URL normalization', () {
    final internal = resolveOriginalImageUrl(
      'http://supabase-kong:8000/storage/v1/object/public/school-assets/logo.png',
    );
    if (EnvConfig.apiOrigin.isNotEmpty) {
      expect(internal, startsWith(EnvConfig.apiOrigin));
      expect(internal, isNot(contains('supabase-kong')));
    }
    final transformed = resolveOriginalImageUrl(
      'https://example.invalid/storage/v1/render/image/public/school-assets/logo.png?width=64',
    );
    expect(transformed, contains('/storage/v1/object/public/'));
    expect(transformed, isNot(contains('width=')));
  });
}
