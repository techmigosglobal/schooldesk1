import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:schooldesk1/features/shared/data/models/backend_models.dart';

const _defaultPageSize = 20;
const _maxPageSize = 100;

/// The shared operational paging policy used by interactive Flutter lists.
class PagingDefaults {
  const PagingDefaults._();

  static const int pageSize = _defaultPageSize;
  static const int maxPageSize = _maxPageSize;

  static int clampPageSize(int value) => value.clamp(1, maxPageSize).toInt();
}

enum PagedListStatus {
  idle,
  loading,
  refreshing,
  loadingMore,
  data,
  empty,
  stale,
  error,
}

typedef PagedPageLoader<T> =
    Future<PaginatedList<T>> Function({
      required int page,
      required int pageSize,
    });

/// Coordinates first-page loads, append-only loading, stale data, retries and
/// duplicate prevention for server-backed interactive lists.
class PagedListController<T> extends ChangeNotifier {
  PagedListController({
    required PagedPageLoader<T> loadPage,
    String Function(T item)? itemKey,
    int pageSize = _defaultPageSize,
  }) : _loadPage = loadPage,
       _itemKey = itemKey,
       _pageSize = PagingDefaults.clampPageSize(pageSize);

  final PagedPageLoader<T> _loadPage;
  final String Function(T item)? _itemKey;
  final List<T> _items = <T>[];
  int _pageSize;
  int _page = 1;
  int _total = 0;
  bool _hasMore = false;
  bool _busy = false;
  bool _stale = false;
  Object? _error;
  int _generation = 0;
  PagedListStatus _status = PagedListStatus.idle;

  List<T> get items => List.unmodifiable(_items);
  int get page => _page;
  int get total => _total;
  int get pageSize => _pageSize;
  bool get hasMore => _hasMore;
  bool get isBusy => _busy;
  bool get isStale => _stale;
  Object? get error => _error;
  PagedListStatus get status => _status;

  Future<void> load({bool reset = true}) async {
    if (_busy && !reset) return;
    final requestGeneration = ++_generation;
    final requestedPage = reset ? 1 : _page + 1;
    _busy = true;
    _error = null;
    _stale = false;
    _status = reset
        ? (_items.isEmpty
              ? PagedListStatus.loading
              : PagedListStatus.refreshing)
        : PagedListStatus.loadingMore;
    notifyListeners();

    try {
      final result = await _loadPage(page: requestedPage, pageSize: _pageSize);
      if (requestGeneration != _generation) return;

      final seen = _items.map(_keyFor).toSet();
      final additions = result.data.where((item) => seen.add(_keyFor(item)));
      if (reset) {
        _items
          ..clear()
          ..addAll(additions);
      } else {
        _items.addAll(additions);
      }
      _page = result.page;
      _total = result.total;
      _hasMore = result.hasMore && result.data.isNotEmpty;
      _busy = false;
      _status = _items.isEmpty ? PagedListStatus.empty : PagedListStatus.data;
      notifyListeners();
    } on Object catch (error) {
      if (requestGeneration != _generation) return;
      _busy = false;
      _error = error;
      _stale = _items.isNotEmpty;
      _status = _stale ? PagedListStatus.stale : PagedListStatus.error;
      notifyListeners();
    }
  }

  Future<void> refresh() => load();

  Future<void> loadMore() {
    if (_busy || !_hasMore) return Future<void>.value();
    return load(reset: false);
  }

  void setPageSize(int value) {
    final next = PagingDefaults.clampPageSize(value);
    if (next == _pageSize) return;
    _pageSize = next;
    unawaited(refresh());
  }

  String _keyFor(T item) {
    final key = _itemKey?.call(item).trim();
    return key == null || key.isEmpty ? '$item' : key;
  }
}
