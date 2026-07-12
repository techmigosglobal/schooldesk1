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

    expect(find.text('Aarav'), findsOneWidget);
    expect(find.text('Diya'), findsOneWidget);
    expect(find.text('Selected: 0'), findsOneWidget);

    await tester.tap(find.text('Diya'));
    await tester.pumpAndSettle();

    expect(find.text('Selected: 1'), findsOneWidget);
  });
}
