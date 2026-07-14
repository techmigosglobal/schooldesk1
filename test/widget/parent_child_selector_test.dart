import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:schooldesk1/core/widgets/parent_child_selector.dart';

void main() {
  testWidgets('shows a photo-led button per child and updates selection', (
    tester,
  ) async {
    var selected = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: Column(
              children: [
                ParentChildSelector(
                  children: const [
                    {
                      'id': 'child-1',
                      'name': 'Aarav Sharma',
                      'class': 'Grade 4',
                      'section': 'A',
                    },
                    {
                      'id': 'child-2',
                      'name': 'Diya Sharma',
                      'class': 'Grade 2',
                      'section': 'B',
                    },
                  ],
                  selectedIndex: selected,
                  onSelected: (index) => setState(() => selected = index),
                ),
                Text('Selected: $selected'),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('Aarav Sharma'), findsOneWidget);
    expect(find.text('Diya Sharma'), findsOneWidget);
    expect(find.text('Selected: 0'), findsOneWidget);

    await tester.tap(find.text('Diya Sharma'));
    await tester.pumpAndSettle();

    expect(find.text('Selected: 1'), findsOneWidget);
  });

  testWidgets('shows class and section names from the linked student record', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ParentChildSelector(
            children: [
              {
                'id': 'child-1',
                'name': 'Aarav Sharma',
                'section': {
                  'id': '16c92c3d-4207-47a9-9a98-a8df3c60e341',
                  'section_name': 'A',
                  'grade': {'id': 'grade-4', 'grade_name': '4'},
                },
              },
            ],
            selectedIndex: 0,
            onSelected: _ignoreSelection,
          ),
        ),
      ),
    );

    expect(find.text('Class 4 • Section A'), findsOneWidget);
    expect(find.textContaining('16c92c3d'), findsNothing);
  });
}

void _ignoreSelection(int _) {}
