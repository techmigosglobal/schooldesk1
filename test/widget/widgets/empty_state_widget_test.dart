import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schooldesk1/core/widgets/empty_state_widget.dart';

void main() {
  group('EmptyStateWidget', () {
    testWidgets('renders with required title', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: EmptyStateWidget(title: 'No Data Found')),
        ),
      );

      expect(find.text('No Data Found'), findsOneWidget);
    });

    testWidgets('renders with subtitle when provided', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmptyStateWidget(
              title: 'No Students',
              subtitle: 'Add students to get started',
            ),
          ),
        ),
      );

      expect(find.text('No Students'), findsOneWidget);
      expect(find.text('Add students to get started'), findsOneWidget);
    });

    testWidgets('shows action button when onAction provided', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyStateWidget(
              title: 'No Records',
              actionLabel: 'Add New',
              onAction: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Add New'), findsOneWidget);
      await tester.tap(find.text('Add New'));
      expect(tapped, isTrue);
    });

    testWidgets('does not show button when onAction is null', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmptyStateWidget(title: 'No Records', actionLabel: 'Add New'),
          ),
        ),
      );

      // Button should not appear without onAction callback
      expect(find.text('Add New'), findsNothing);
    });
  });
}
