import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:dio/dio.dart';

import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/config/env_config.dart';

/// Shared media loader used by feed, gallery, and document previews.
///
/// Public Storage media is persisted on disk. In-flight requests are shared so
/// rebuilds of a carousel cannot start duplicate downloads. Signed/private
/// URLs are intentionally kept out of the persistent cache because their
/// authorization lifetime is short and the content may be sensitive.
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

    if (_isPublicStorageUrl(url)) {
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

    try {
      final response = await BackendApiClient.instance.dio.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = Uint8List.fromList(response.data ?? const <int>[]);
      if (bytes.isNotEmpty) _remember(key, bytes);
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
    return path.contains('/storage/v1/object/public/') &&
        !path.contains('/storage/v1/object/sign/');
  }

  static String _cacheKey(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme) return value;
    final query = <String, String>{};
    for (final entry in uri.queryParameters.entries) {
      // Signed URLs rotate their token. Transform dimensions are part of the
      // representation and must remain in the cache key.
      if (entry.key.toLowerCase() != 'token') query[entry.key] = entry.value;
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
