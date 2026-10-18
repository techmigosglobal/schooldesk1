import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schooldesk1/core/offline/offline_sync_engine.dart';

void main() {
  test(
    'explicit no-store attendance reads cannot write or fall back to cache',
    () {
      for (final path in [
        '/attendance/context',
        '/attendance/roster',
        '/attendance/sessions',
      ]) {
        for (final headers in [
          {'Cache-Control': 'no-store'},
          {'cache-control': 'private, No-Store'},
          {'CACHE-CONTROL': 'max-age=0, no-store, no-cache'},
        ]) {
          expect(
            OfflineDioInterceptor.isCacheableRead(
              RequestOptions(path: path, method: 'GET', headers: headers),
            ),
            isFalse,
            reason: '$path $headers',
          );
        }
        expect(
          OfflineDioInterceptor.isCacheableRead(
            RequestOptions(path: path, method: 'GET'),
          ),
          isTrue,
          reason: 'Ordinary attendance reads retain their offline contract',
        );
      }
    },
  );
  test('cache policy keeps existing excluded and safe read behavior', () {
    for (final path in [
      '/health',
      '/uploads',
      '/event-posts',
      '/payment-requests',
      '/attendance/staff/qr-token',
      '/auth/login',
    ]) {
      expect(
        OfflineDioInterceptor.isCacheableRead(
          RequestOptions(path: path, method: 'GET'),
        ),
        isFalse,
      );
    }
    expect(
      OfflineDioInterceptor.isCacheableRead(
        RequestOptions(path: '/auth/profile', method: 'GET'),
      ),
      isTrue,
    );
    expect(
      OfflineDioInterceptor.isCacheableRead(
        RequestOptions(path: '/attendance/sessions', method: 'POST'),
      ),
      isFalse,
    );
  });
}
