import 'package:flutter/foundation.dart';

import 'package:schooldesk1/core/repositories/repository_state.dart';
import 'package:schooldesk1/core/utils/result.dart';

typedef RepositoryReader<T> =
    Future<Result<T>> Function({
      bool forceRefresh,
    });

/// Keeps one typed repository snapshot while a refresh is running.
///
/// A refresh never discards usable cached data. A failed refresh becomes a
/// stale cache state with an actionable error instead of a blank screen.
class RepositoryStateController<T> extends ChangeNotifier {
  RepositoryStateController({required this.reader});

  final RepositoryReader<T> reader;
  RepositoryState<T> _state = RepositoryState<T>.empty();

  RepositoryState<T> get state => _state;

  Future<void> load({bool forceRefresh = false}) async {
    final previous = _state;
    _state = RepositoryState<T>.loading(
      data: previous.data,
      source: previous.source,
      isStale: previous.isStale,
      isRefreshing: previous.hasData,
      lastUpdated: previous.lastUpdated,
    );
    notifyListeners();

    final result = await reader(forceRefresh: forceRefresh);
    _state = RepositoryState.fromResult(
      result,
      previous: previous.hasData ? previous : null,
    );
    notifyListeners();
  }
}
