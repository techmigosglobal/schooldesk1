import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schooldesk1/presentation/student_oversight_screen/widgets/student_summary_cards_widget.dart';
import 'package:schooldesk1/theme/app_theme.dart';

void main() {
  testWidgets('StudentSummaryCardsWidget avoids overflow on phone widths', (
    tester,
  ) async {
    final errors = <FlutterErrorDetails>[];
    final previousOnError = FlutterError.onError;
    FlutterError.onError = errors.add;

    await tester.binding.setSurfaceSize(const Size(360, 800));
    try {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const MediaQuery(
            data: MediaQueryData(
              size: Size(360, 800),
              textScaler: TextScaler.linear(1.35),
            ),
            child: Scaffold(
              body: SingleChildScrollView(
                child: StudentSummaryCardsWidget(
                  totalStudents: 128,
                  alertStudents: 12,
                  topperStudents: 8,
                  feeDefaulters: 5,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    } finally {
      FlutterError.onError = previousOnError;
      await tester.binding.setSurfaceSize(null);
    }

    expect(
      errors.where((e) => e.exceptionAsString().contains('overflowed')),
      isEmpty,
    );
  });
}
