import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schooldesk1/widgets/status_badge_widget.dart';

void main() {
  group('StatusBadgeWidget', () {
    testWidgets('renders status text', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: StatusBadgeWidget(status: 'Active')),
        ),
      );

      expect(find.text('Active'), findsOneWidget);
    });

    testWidgets('renders Pending status', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: StatusBadgeWidget(status: 'Pending')),
        ),
      );

      expect(find.text('Pending'), findsOneWidget);
    });

    testWidgets('renders Approved status', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: StatusBadgeWidget(status: 'Approved')),
        ),
      );

      expect(find.text('Approved'), findsOneWidget);
    });

    testWidgets('renders Rejected status', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: StatusBadgeWidget(status: 'Rejected')),
        ),
      );

      expect(find.text('Rejected'), findsOneWidget);
    });

    testWidgets('renders Paid status', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: StatusBadgeWidget(status: 'Paid')),
        ),
      );

      expect(find.text('Paid'), findsOneWidget);
    });

    testWidgets('renders Overdue status', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: StatusBadgeWidget(status: 'Overdue')),
        ),
      );

      expect(find.text('Overdue'), findsOneWidget);
    });

    testWidgets('is a widget (not null)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: StatusBadgeWidget(status: 'Unknown')),
        ),
      );

      expect(find.byType(StatusBadgeWidget), findsOneWidget);
    });
  });
}
