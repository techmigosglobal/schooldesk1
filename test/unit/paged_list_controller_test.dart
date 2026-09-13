import 'package:flutter_test/flutter_test.dart';
import 'package:schooldesk1/core/paging/paged_list_controller.dart';
import 'package:schooldesk1/features/shared/data/models/backend_models.dart';

void main() {
  test('pages append in order and suppress duplicate rows', () async {
    final controller = PagedListController<Map<String, dynamic>>(
      pageSize: 2,
      itemKey: (row) => '${row['id']}',
      loadPage: ({required page, required pageSize}) async {
        final rows =
            <int, List<Map<String, dynamic>>>{
              1: [
                {'id': 'a'},
                {'id': 'b'},
              ],
              2: [
                {'id': 'b'},
                {'id': 'c'},
              ],
              3: [
                {'id': 'd'},
              ],
            }[page] ??
            const <Map<String, dynamic>>[];
        return PaginatedList<Map<String, dynamic>>(
          data: rows,
          total: 5,
          page: page,
          pageSize: pageSize,
        );
      },
    );

    await controller.load();
    expect(controller.items.map((row) => row['id']), ['a', 'b']);
    expect(controller.hasMore, isTrue);
    await controller.loadMore();
    expect(controller.items.map((row) => row['id']), ['a', 'b', 'c']);
    await controller.loadMore();
    expect(controller.items.map((row) => row['id']), ['a', 'b', 'c', 'd']);
    expect(controller.hasMore, isFalse);
    controller.dispose();
  });

  test('empty pages and first-load errors remain distinguishable', () async {
    var shouldFail = true;
    final controller = PagedListController<String>(
      loadPage: ({required page, required pageSize}) async {
        if (shouldFail) throw StateError('backend unavailable');
        return const PaginatedList<String>(
          data: [],
          total: 0,
          page: 1,
          pageSize: 20,
        );
      },
    );

    await controller.load();
    expect(controller.status, PagedListStatus.error);
    expect(controller.items, isEmpty);
    shouldFail = false;
    await controller.refresh();
    expect(controller.status, PagedListStatus.empty);
    expect(controller.error, isNull);
    controller.dispose();
  });

  test('refresh errors preserve loaded data as stale', () async {
    var shouldFail = false;
    final controller = PagedListController<String>(
      loadPage: ({required page, required pageSize}) async {
        if (shouldFail) throw StateError('temporary outage');
        return const PaginatedList<String>(
          data: ['cached row'],
          total: 1,
          page: 1,
          pageSize: 20,
        );
      },
    );

    await controller.load();
    shouldFail = true;
    await controller.refresh();
    expect(controller.status, PagedListStatus.stale);
    expect(controller.isStale, isTrue);
    expect(controller.items, ['cached row']);
    controller.dispose();
  });
}
