import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schooldesk1/core/widgets/loading_skeleton_widget.dart';

void main() {
  group('LoadingSkeletonWidget', () {
    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: LoadingSkeletonWidget())),
      );

      expect(find.byType(LoadingSkeletonWidget), findsOneWidget);
    });

    testWidgets('renders with custom item count', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: LoadingSkeletonWidget(itemCount: 3)),
        ),
      );

      expect(find.byType(LoadingSkeletonWidget), findsOneWidget);
    });

    testWidgets('renders shimmer containers', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: LoadingSkeletonWidget(itemCount: 2)),
        ),
      );

      // Should render Container widgets for skeleton items
      expect(find.byType(Container), findsWidgets);
    });
  });
}
