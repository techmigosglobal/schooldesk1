import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schooldesk1/core/repositories/repository_state.dart';
import 'package:schooldesk1/core/widgets/repository_state_view.dart';

void main() {
  testWidgets(
    'refresh preserves content without an offline warning; recovery removes status',
    (tester) async {
      Widget view(RepositoryState<String> state) => MaterialApp(
        home: Scaffold(
          body: SchoolDeskRepositoryStateView<String>(
            state: state,
            onRetry: () {},
            data: (v) => Text(v),
          ),
        ),
      );
      await tester.pumpWidget(
        view(
          const RepositoryState.loading(
            data: 'Saved attendance',
            source: RepositorySource.cache,
            isStale: true,
            isRefreshing: true,
          ),
        ),
      );
      expect(find.text('Saved attendance'), findsOneWidget);
      expect(find.textContaining('Showing saved data'), findsNothing);
      await tester.pumpWidget(
        view(
          const RepositoryState(
            data: 'Saved attendance',
            source: RepositorySource.cache,
            isStale: true,
            error: 'Failed request',
          ),
        ),
      );
      expect(find.text('Saved attendance'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(tester.getSize(find.byType(Material).last).height, lessThan(150));
      await tester.pumpWidget(
        view(
          const RepositoryState(
            data: 'Fresh attendance',
            source: RepositorySource.remote,
          ),
        ),
      );
      expect(find.text('Retry'), findsNothing);
      expect(find.text('Fresh attendance'), findsOneWidget);
    },
  );
}
