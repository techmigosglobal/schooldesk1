import 'dart:async';
import 'dart:collection';

import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import 'package:schooldesk1/core/network/backend_api_client.dart';

class ErrorReportingService {
  ErrorReportingService._();

  static final ErrorReportingService instance = ErrorReportingService._();

  bool _initialized = false;
  bool _crashlyticsReady = false;
  // Queue-based delivery: errors are never dropped while a send is in-flight.
  // Each payload is enqueued and a single flush loop drains the queue serially.
  final Queue<Map<String, dynamic>> _pendingReports = Queue();
  bool _flushing = false;
  static const String monitoringEndpoint = '/monitoring/error-events';
  static const int _maxQueuedReports = 100;
  static const int _maxMessageChars = 2048;
  static const int _maxStackChars = 12288;
  Timer? _retryTimer;
  int _retryAttempt = 0;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    try {
      if (Firebase.apps.isNotEmpty) {
        await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
          !kDebugMode,
        );
        _crashlyticsReady = true;
      }
    } on Object catch (_) {
      // The backend queue remains the fallback when Firebase is unavailable.
    }
    BackendApiClient.apiErrorReporter = (error) {
      unawaited(recordApiError(error));
    };
  }

  Future<void> recordFlutterError(FlutterErrorDetails details) {
    unawaited(
      _recordCrashlytics(
        error: details.exception,
        stack: details.stack,
        fatal: true,
        reason: details.context?.toDescription(),
        information: [
          if (details.library != null) 'library=${details.library}',
        ],
      ),
    );
    return _submit({
      'source': 'flutter',
      'severity': 'fatal',
      'message': details.exceptionAsString(),
      'error_type': details.exception.runtimeType.toString(),
      'stack_trace': details.stack?.toString() ?? '',
      'metadata': {
        'library': details.library,
        'context': details.context?.toDescription(),
      },
    });
  }

  Future<void> recordPlatformError(Object error, StackTrace stack) {
    unawaited(_recordCrashlytics(error: error, stack: stack, fatal: true));
    return _submit({
      'source': 'flutter',
      'severity': 'fatal',
      'message': error.toString(),
      'error_type': error.runtimeType.toString(),
      'stack_trace': stack.toString(),
    });
  }

  Future<void> recordApiError(DioException error) {
    final path = error.requestOptions.path;
    if (path.contains('/monitoring/error-events')) {
      return Future.value();
    }
    final statusCode = error.response?.statusCode ?? 0;
    final message = _messageForApiError(error);
    final approvalAuditFailure = message.contains(
      'approval_audit_write_failed',
    );
    unawaited(
      _recordCrashlytics(
        error: error,
        stack: error.stackTrace,
        reason: 'API ${error.requestOptions.method} $path',
        information: [
          'status=${error.response?.statusCode ?? 0}',
          'role=${BackendApiClient.instance.currentRoleName}',
        ],
      ),
    );
    return _submit({
      'source': 'api',
      'severity': approvalAuditFailure
          ? 'fatal'
          : statusCode >= 500
          ? 'error'
          : 'warning',
      'message': message,
      'error_type': error.type.name,
      'status_code': statusCode,
      'method': error.requestOptions.method,
      'path': path,
      'request_id': _responseHeader(error, 'x-request-id'),
      'metadata': {
        'response_error_id': _responseHeader(error, 'x-error-id'),
        'approval_audit_failure': approvalAuditFailure,
        'query_keys': error.requestOptions.queryParameters.keys.toList(),
      },
    });
  }

  Future<void> _recordCrashlytics({
    required Object error,
    StackTrace? stack,
    bool fatal = false,
    Object? reason,
    Iterable<Object> information = const [],
  }) async {
    if (!_crashlyticsReady) return;
    try {
      await FirebaseCrashlytics.instance.recordError(
        error,
        stack,
        fatal: fatal,
        reason: reason,
        information: information,
      );
    } on Object catch (_) {
      // Error reporting must never affect the application flow.
    }
  }

  Future<void> _submit(Map<String, dynamic> payload) async {
    // Reporting must not become an unbounded in-memory queue during an outage.
    // Prefer retaining fatal/error reports over older warning-level noise.
    if (_pendingReports.length >= _maxQueuedReports) {
      final warningIndex = _pendingReports.toList().indexWhere(
        (item) => item['severity'] == 'warning' || item['severity'] == 'info',
      );
      if (warningIndex >= 0) {
        _pendingReports.remove(_pendingReports.elementAt(warningIndex));
      } else if (payload['severity'] == 'warning' ||
          payload['severity'] == 'info') {
        return;
      } else {
        _pendingReports.removeFirst();
      }
    }
    _pendingReports.add(_sanitize(payload));
    if (!_flushing) {
      unawaited(_flush());
    }
  }

  Future<void> _flush() async {
    if (_flushing) return;
    _flushing = true;
    try {
      while (_pendingReports.isNotEmpty) {
        if (!BackendApiClient.instance.isAuthenticated) break;
        final payload = _pendingReports.removeFirst();
        try {
          final enriched = {
            ...payload,
            'route_name': PlatformDispatcher.instance.defaultRouteName,
            'app_version': 'schooldesk-flutter',
            'device_info': defaultTargetPlatform.name,
            'occurred_at': DateTime.now().toUtc().toIso8601String(),
            'metadata': {
              ...Map<String, dynamic>.from(payload['metadata'] as Map? ?? {}),
              'role': BackendApiClient.instance.currentRoleName,
              'debug_mode': kDebugMode,
            },
          };
          await BackendApiClient.instance.submitErrorEvent(enriched);
          _retryAttempt = 0;
        } on Object catch (_) {
          _pendingReports.addFirst(payload);
          _scheduleRetry();
          break;
        }
      }
    } finally {
      _flushing = false;
    }
  }

  void _scheduleRetry() {
    if (_retryTimer?.isActive ?? false) return;
    final delay = switch (_retryAttempt) {
      0 => const Duration(seconds: 2),
      1 => const Duration(seconds: 4),
      2 => const Duration(seconds: 8),
      3 => const Duration(seconds: 16),
      _ => const Duration(seconds: 30),
    };
    _retryAttempt++;
    _retryTimer = Timer(delay, () {
      _retryTimer = null;
      unawaited(_flush());
    });
  }

  String _messageForApiError(DioException error) {
    final data = error.response?.data;
    if (data is Map) {
      final message = data['message']?.toString().trim();
      if (message != null && message.isNotEmpty) return message;
      final nested = data['error'];
      if (nested is String && nested.trim().isNotEmpty) return nested.trim();
    }
    return error.message ?? 'API request failed';
  }

  String _responseHeader(DioException error, String name) {
    final values = error.response?.headers[name];
    if (values == null || values.isEmpty) return '';
    return values.first;
  }

  Map<String, dynamic> _sanitize(Map<String, dynamic> payload) {
    final metadata = Map<String, dynamic>.from(
      payload['metadata'] as Map? ?? const <String, dynamic>{},
    );
    return {
      ...payload,
      'message': _redactAndTruncate(payload['message'], _maxMessageChars),
      'error_type': _redactAndTruncate(payload['error_type'], 256),
      'stack_trace': _redactAndTruncate(payload['stack_trace'], _maxStackChars),
      'path': _redactAndTruncate(payload['path'], 512),
      'metadata': metadata.map(
        (key, value) => MapEntry(key, _redactAndTruncate(value, 512)),
      ),
    };
  }

  String _redactAndTruncate(Object? value, int maxChars) {
    var result = value?.toString() ?? '';
    result = result
        .replaceAll(
          RegExp(r'Bearer\s+[A-Za-z0-9._~+\/-]+', caseSensitive: false),
          'Bearer [redacted]',
        )
        .replaceAll(
          RegExp(
            r'(password|token|secret|api[_-]?key)\s*[:=]\s*[^\s,}]+',
            caseSensitive: false,
          ),
          r'$1=[redacted]',
        );
    return result.length <= maxChars
        ? result
        : '${result.substring(0, maxChars)}…';
  }
}
