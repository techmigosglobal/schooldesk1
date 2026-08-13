part of '../backend_api_client.dart';

final Map<BackendApiClient, Map<String, Future<Response<dynamic>>>>
_inFlightGetsByClient = {};
final Map<BackendApiClient, Map<String, _RecentGetResponse>>
_recentGetResponsesByClient = {};

extension BackendRequestCoalescing on BackendApiClient {
  void _clearCoalescedGets() {
    _inFlightGetsByClient[this]?.clear();
    _recentGetResponsesByClient[this]?.clear();
  }

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
      return dio.get<dynamic>(
        path,
        queryParameters: queryParameters,
        options: options,
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

    final request = dio.get<dynamic>(
      path,
      queryParameters: queryParameters,
      options: options,
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
