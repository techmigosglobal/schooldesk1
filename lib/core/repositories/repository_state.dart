import 'package:schooldesk1/core/utils/result.dart';

enum RepositorySource { remote, cache, localMutation, empty }

enum RepositoryPhase { loading, ready, empty, error }

class RepositoryState<T> {
  static const Object _unset = Object();

  const RepositoryState({
    this.data,
    required this.source,
    this.phase = RepositoryPhase.ready,
    this.isStale = false,
    this.isRefreshing = false,
    this.error,
    this.lastUpdated,
  });

  const RepositoryState.empty()
    : data = null,
      source = RepositorySource.empty,
      phase = RepositoryPhase.empty,
      isStale = false,
      isRefreshing = false,
      error = null,
      lastUpdated = null;

  const RepositoryState.loading({
    this.data,
    this.source = RepositorySource.empty,
    this.isStale = false,
    this.isRefreshing = false,
    this.error,
    this.lastUpdated,
  }) : phase = RepositoryPhase.loading;

  const RepositoryState.error({
    this.data,
    this.source = RepositorySource.empty,
    this.isStale = false,
    this.isRefreshing = false,
    required this.error,
    this.lastUpdated,
  }) : phase = RepositoryPhase.error;

  final T? data;
  final RepositorySource source;
  final RepositoryPhase phase;
  final bool isStale;
  final bool isRefreshing;
  final Object? error;
  final DateTime? lastUpdated;

  bool get hasData => data != null;
  bool get isLoading => phase == RepositoryPhase.loading;
  bool get isError => phase == RepositoryPhase.error || error != null;
  bool get isEmpty {
    if (phase == RepositoryPhase.empty || data == null) return true;
    final value = data;
    return value is Iterable && value.isEmpty;
  }

  bool get isOffline => source == RepositorySource.cache || isStale;

  static RepositoryState<T> fromResult<T>(
    Result<T> result, {
    RepositoryState<T>? previous,
    bool isRefreshing = false,
  }) {
    return result.when(
      success: (data) {
        final empty = data is Iterable && data.isEmpty;
        return RepositoryState<T>(
          data: data,
          source: RepositorySource.remote,
          phase: empty ? RepositoryPhase.empty : RepositoryPhase.ready,
          isRefreshing: isRefreshing,
          lastUpdated: DateTime.now().toUtc(),
        );
      },
      failure: (failure) {
        if (previous?.hasData == true) {
          return RepositoryState<T>(
            data: previous!.data,
            source: RepositorySource.cache,
            phase: RepositoryPhase.ready,
            isStale: true,
            isRefreshing: false,
            error: failure,
            lastUpdated: previous.lastUpdated,
          );
        }
        return RepositoryState<T>.error(error: failure);
      },
    );
  }

  RepositoryState<T> copyWith({
    Object? data = _unset,
    RepositorySource? source,
    bool? isStale,
    bool? isRefreshing,
    Object? error = _unset,
    Object? lastUpdated = _unset,
    RepositoryPhase? phase,
  }) {
    return RepositoryState<T>(
      data: identical(data, _unset) ? this.data : data as T?,
      source: source ?? this.source,
      phase: phase ?? this.phase,
      isStale: isStale ?? this.isStale,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      error: identical(error, _unset) ? this.error : error,
      lastUpdated: identical(lastUpdated, _unset)
          ? this.lastUpdated
          : lastUpdated as DateTime?,
    );
  }
}
