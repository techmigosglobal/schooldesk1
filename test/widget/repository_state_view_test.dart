import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:schooldesk1/core/repositories/repository_state.dart';
import 'package:schooldesk1/core/widgets/repository_state_view.dart';

void main() {
  Widget host(RepositoryState<List<String>> state, {VoidCallback? retry}) {
    return MaterialApp(
      home: SchoolDeskRepositoryStateView<List<String>>(
        state: state,
        onRetry: retry ?? () {},
        data: (items) => Text(items.join(',')),
      ),
    );
  }

  testWidgets('renders loading and retryable error states', (tester) async {
    await tester.pumpWidget(
      host(const RepositoryState<List<String>>.loading()),
    );
    expect(find.bySemanticsLabel('Loading…'), findsOneWidget);

    await tester.pumpWidget(
      host(
        const RepositoryState<List<String>>.error(error: 'request failed'),
      ),
    );
    expect(find.text('Unable to load data'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('keeps stale cached data visible with non-color status', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const RepositoryState<List<String>>(
          data: ['cached row'],
          source: RepositorySource.cache,
          isStale: true,
        ),
      ),
    );
    expect(find.text('cached row'), findsOneWidget);
    expect(find.text('Showing saved data'), findsOneWidget);
    expect(find.text('Refresh'), findsOneWidget);
  });

  testWidgets('renders empty state with retry action', (tester) async {
    var retried = false;
    await tester.pumpWidget(
      host(
        const RepositoryState<List<String>>.empty(),
        retry: () => retried = true,
      ),
    );
    expect(find.text('Nothing here yet'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    expect(retried, isTrue);
  });
}
