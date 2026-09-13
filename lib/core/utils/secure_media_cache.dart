import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Small, account-scoped private-media cache.
///
/// FlutterSecureStorage delegates encryption to Android Keystore-backed
/// storage and iOS Keychain storage. It is intentionally limited to recently
/// viewed feed/profile images; operational documents and proofs are never
/// persisted by this class.
class SecureSelectiveMediaCache {
  SecureSelectiveMediaCache._();

  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const int maxBytes = 512 * 1024;
  static const int maxEntries = 12;
  static const String _manifestPrefix = 'schooldesk_media_manifest_';
  static const String _valuePrefix = 'schooldesk_media_value_';

  static bool isCacheablePrivateMedia(String url) {
    final normalized = url.trim().toLowerCase();
    if (normalized.isEmpty ||
        normalized.contains('payment') ||
        normalized.contains('proof') ||
        normalized.contains('document') ||
        normalized.contains('signature') ||
        normalized.contains('help') ||
        normalized.contains('attachment')) {
      return false;
    }
    final uri = Uri.tryParse(normalized);
    final path = uri?.path ?? normalized;
    return path.contains('event-posts/') ||
        path.contains('avatars/') ||
        path.contains('students/') ||
        path.contains('staff/');
  }

  static Future<Uint8List?> read({
    required String accountKey,
    required String stableReference,
  }) async {
    if (accountKey.trim().isEmpty ||
        accountKey == 'anonymous' ||
        !isCacheablePrivateMedia(stableReference)) {
      return null;
    }
    try {
      final value = await _storage.read(
        key: _valueKey(accountKey, stableReference),
      );
      if (value == null || value.isEmpty) return null;
      return Uint8List.fromList(base64Decode(value));
    } on Object {
      return null;
    }
  }

  static Future<void> write({
    required String accountKey,
    required String stableReference,
    required Uint8List bytes,
  }) async {
    if (accountKey.trim().isEmpty ||
        accountKey == 'anonymous' ||
        bytes.isEmpty ||
        bytes.length > maxBytes ||
        !isCacheablePrivateMedia(stableReference)) {
      return;
    }
    try {
      final manifest = await _readManifest(accountKey);
      final entryKey = _valueKey(accountKey, stableReference);
      manifest.removeWhere((entry) => entry['key'] == entryKey);
      manifest.insert(0, {
        'key': entryKey,
        'touched_at': DateTime.now().toUtc().toIso8601String(),
      });
      while (manifest.length > maxEntries) {
        final removed = manifest.removeLast();
        final key = removed['key'];
        if (key is String) await _storage.delete(key: key);
      }
      await _storage.write(key: entryKey, value: base64Encode(bytes));
      await _writeManifest(accountKey, manifest);
    } on Object {
      // Secure caching is an optimization and must never affect media loads.
    }
  }

  static Future<void> clearAccount(String accountKey) async {
    if (accountKey.trim().isEmpty || accountKey == 'anonymous') return;
    try {
      final manifest = await _readManifest(accountKey);
      for (final entry in manifest) {
        final key = entry['key'];
        if (key is String) await _storage.delete(key: key);
      }
      await _storage.delete(key: _manifestKey(accountKey));
    } on Object {
      // Best effort. A subsequent account-scoped read cannot use another
      // account's key because the key contains the full account scope hash.
    }
  }

  static String _manifestKey(String accountKey) {
    return '$_manifestPrefix${_scopeHash(accountKey)}';
  }

  static String _valueKey(String accountKey, String reference) {
    return '$_valuePrefix${_scopeHash('$accountKey|$reference')}';
  }

  static String _scopeHash(String value) {
    // Stable FNV-1a keeps secure-storage key names short and platform-safe.
    var hash = 0x811c9dc5;
    for (final codeUnit in value.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  static Future<List<Map<String, dynamic>>> _readManifest(
    String accountKey,
  ) async {
    final raw = await _storage.read(key: _manifestKey(accountKey));
    if (raw == null || raw.isEmpty) return <Map<String, dynamic>>[];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return <Map<String, dynamic>>[];
    return decoded
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList();
  }

  static Future<void> _writeManifest(
    String accountKey,
    List<Map<String, dynamic>> manifest,
  ) {
    return _storage.write(
      key: _manifestKey(accountKey),
      value: jsonEncode(manifest),
    );
  }
}
