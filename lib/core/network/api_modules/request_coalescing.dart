part of '../backend_api_client.dart';

final Map<BackendApiClient, Map<String, Future<Response<dynamic>>>>
_inFlightGetsByClient = {};
final Map<BackendApiClient, Map<String, _RecentGetResponse>>
_recentGetResponsesByClient = {};
final Map<BackendApiClient, _GetConcurrencyGate> _getGatesByClient = {};

extension BackendRequestCoalescing on BackendApiClient {
  void _clearCoalescedGets() {
    _inFlightGetsByClient[this]?.clear();
    _recentGetResponsesByClient[this]?.clear();
  }

  _GetConcurrencyGate get _getConcurrencyGate =>
      _getGatesByClient.putIfAbsent(this, _GetConcurrencyGate.new);

  /// Coalesces identical GETs while a request is in flight and for a very
  /// short completion window. Different query parameters keep refresh
  /// semantics, and explicit no-store requests never reuse a response.
  Future<Response<dynamic>> _get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    final query = queryParameters == null || queryParameters.isEmpty
        ? ''
        : (queryParameters.entries.toList()
                ..sort((a, b) => a.key.compareTo(b.key)))
              .map((entry) => '${entry.key}=${entry.value}')
              .join('&');
    final key =
        '${currentUserId ?? ''}|${activeBranchId ?? ''}|$path?$query|'
        '${options?.responseType}';
    final inFlight = _inFlightGetsByClient.putIfAbsent(this, () => {});
    final recentResponses = _recentGetResponsesByClient.putIfAbsent(
      this,
      () => {},
    );
    final noStore =
        options?.headers?['Cache-Control']?.toString().toLowerCase().contains(
          'no-store',
        ) ==
        true;
    // A caller asking for an intentional refresh must never inherit a request
    // or response that was started for a normal navigation read.
    if (noStore) {
      return _getConcurrencyGate.run(
        () => dio.get<dynamic>(
          path,
          queryParameters: queryParameters,
          options: options,
        ),
      );
    }
    final existing = inFlight[key];
    if (existing != null) return existing;
    final recent = recentResponses[key];
    if (recent != null &&
        DateTime.now().difference(recent.completedAt) <=
            const Duration(milliseconds: 750)) {
      return Future<Response<dynamic>>.value(recent.response);
    }

    final request = _getConcurrencyGate.run(
      () => dio.get<dynamic>(
        path,
        queryParameters: queryParameters,
        options: options,
      ),
    );
    inFlight[key] = request;
    request.then<void>(
      (response) {
        if (identical(inFlight[key], request)) {
          recentResponses[key] = _RecentGetResponse(
            response: response,
            completedAt: DateTime.now(),
          );
          if (recentResponses.length > 128) {
            recentResponses.remove(recentResponses.keys.first);
          }
          inFlight.remove(key);
        }
      },
      onError: (Object _, StackTrace __) {
        if (identical(inFlight[key], request)) inFlight.remove(key);
      },
    );
    return request;
  }
}

class _RecentGetResponse {
  const _RecentGetResponse({required this.response, required this.completedAt});

  final Response<dynamic> response;
  final DateTime completedAt;
}

/// Keeps bursty dashboard/bootstrap reads below the worker budget of the
/// local Docker Edge runtime. The queue is shared by all GET callers on one
/// API client, while writes retain their existing behavior.
class _GetConcurrencyGate {
  // Keep a small bounded burst for independent role-scope reads without
  // allowing a dashboard bootstrap to flood the local Edge worker.
  static const int _maxConcurrent = 4;

  final List<_QueuedGet<dynamic>> _queue = <_QueuedGet<dynamic>>[];
  int _running = 0;

  Future<T> run<T>(Future<T> Function() operation) {
    final completer = Completer<T>();
    _queue.add(_QueuedGet<T>(operation, completer));
    _drain();
    return completer.future;
  }

  void _drain() {
    while (_running < _maxConcurrent && _queue.isNotEmpty) {
      final queued = _queue.removeAt(0);
      _running++;
      Future<dynamic>.sync(queued.operation)
          .then<void>(
            (value) {
              if (!queued.completer.isCompleted) {
                queued.completer.complete(value);
              }
            },
            onError: (Object error, StackTrace stackTrace) {
              if (!queued.completer.isCompleted) {
                queued.completer.completeError(error, stackTrace);
              }
            },
          )
          .whenComplete(() {
            _running--;
            _drain();
          });
    }
  }
}

class _QueuedGet<T> {
  _QueuedGet(this.operation, this.completer);

  final Future<T> Function() operation;
  final Completer<T> completer;
}
