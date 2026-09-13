import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:dio/dio.dart';

import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/config/env_config.dart';
import 'package:schooldesk1/core/utils/secure_media_cache.dart';

/// Shared media loader used by feed, gallery, and document previews.
///
/// Public media is persisted on disk. Small private feed/profile media is
/// persisted only in the account-scoped secure cache; signed URLs themselves
/// are never persisted. Documents, proofs, signatures, help videos, and
/// attachments remain memory/network-only.
class MediaCache {
  MediaCache._();

  static final BaseCacheManager _disk = DefaultCacheManager();
  static final Map<String, Future<Uint8List>> _inFlight = {};
  static final Map<String, Uint8List> _memory = <String, Uint8List>{};
  static const int _maxMemoryEntries = 24;
  static const int _maxMemoryBytes = 8 * 1024 * 1024;
  static int _memoryBytes = 0;

  static Future<Uint8List> load(String url) {
    final key = _cacheKey(url);
    final memory = _memory[key];
    if (memory != null) return Future<Uint8List>.value(memory);

    final running = _inFlight[key];
    if (running != null) return running;

    final future = _load(url, key);
    _inFlight[key] = future;
    future.then<void>(
      (_) => _inFlight.remove(key),
      onError: (Object _, StackTrace __) => _inFlight.remove(key),
    );
    return future;
  }

  static Future<Uint8List> _load(String url, String key) async {
    if (url.startsWith('assets/')) {
      final bytes = (await rootBundle.load(url)).buffer.asUint8List();
      _remember(key, bytes);
      return bytes;
    }

    if (_isPublicStorageUrl(url) && _platformCacheAvailable) {
      try {
        final file = await _disk.getSingleFile(url, key: key);
        final bytes = await file.readAsBytes();
        if (bytes.isNotEmpty) {
          _remember(key, bytes);
          return bytes;
        }
      } on Object catch (_) {
        // Fall through to Dio for legacy URLs or a temporarily unavailable
        // cache service. The caller still receives the same error semantics.
      }
    }

    final accountKey = BackendApiClient.instance.offlineAccountKey;
    final privateMediaCandidate =
        !_isPublicStorageUrl(url) &&
        SecureSelectiveMediaCache.isCacheablePrivateMedia(key);
    if (privateMediaCandidate) {
      final secure = await SecureSelectiveMediaCache.read(
        accountKey: accountKey,
        stableReference: key,
      );
      if (secure != null && secure.isNotEmpty) {
        _remember(key, secure);
        return secure;
      }
    }

    try {
      final response = await BackendApiClient.instance.dio.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = Uint8List.fromList(response.data ?? const <int>[]);
      if (bytes.isNotEmpty) {
        _remember(key, bytes);
        if (privateMediaCandidate) {
          await SecureSelectiveMediaCache.write(
            accountKey: accountKey,
            stableReference: key,
            bytes: bytes,
          );
        }
      }
      return bytes;
    } on DioException catch (error, stackTrace) {
      // Media is optional decoration for a screen. A disconnected device or
      // an expired signed URL should resolve to the existing placeholder, not
      // become an unhandled Future error that takes down the current route.
      if (EnvConfig.enableLogging) {
        developer.log(
          '[MEDIA] unavailable: $url (${error.type})',
          name: 'MediaCache',
          stackTrace: stackTrace,
        );
      }
      return Uint8List(0);
    }
  }

  static bool _isPublicStorageUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme) return false;
    final path = uri.path;
    if (path.contains('/storage/v1/object/sign/') ||
        uri.queryParameters.keys.any(
          (key) => key.toLowerCase().startsWith('x-amz-'),
        )) {
      return false;
    }
    return path.contains('/storage/v1/object/public/') ||
        (!uri.host.contains('supabase.co') &&
            !uri.host.contains('r2.cloudflarestorage.com'));
  }

  static bool get _platformCacheAvailable {
    try {
      ServicesBinding.instance;
      return true;
    } on Object {
      return false;
    }
  }

  static String _cacheKey(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme) return value;
    final query = <String, String>{};
    for (final entry in uri.queryParameters.entries) {
      // Signed URLs rotate their token/signature. Transform dimensions are
      // part of the representation and must remain in the cache key.
      final normalizedKey = entry.key.toLowerCase();
      if (normalizedKey == 'token' || normalizedKey.startsWith('x-amz-')) {
        continue;
      }
      query[entry.key] = entry.value;
    }
    return uri.replace(queryParameters: query, fragment: '').toString();
  }

  static void _remember(String key, Uint8List bytes) {
    if (bytes.isEmpty || bytes.length > _maxMemoryBytes) return;
    final previous = _memory.remove(key);
    if (previous != null) _memoryBytes -= previous.length;
    while (_memory.length >= _maxMemoryEntries ||
        _memoryBytes + bytes.length > _maxMemoryBytes) {
      if (_memory.isEmpty) break;
      final oldest = _memory.keys.first;
      final removed = _memory.remove(oldest);
      if (removed != null) _memoryBytes -= removed.length;
    }
    _memory[key] = bytes;
    _memoryBytes += bytes.length;
  }
}
