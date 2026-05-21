import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schooldesk1/presentation/approval_center_screen/approval_center_screen.dart';
import 'package:schooldesk1/presentation/approval_center_screen/widgets/approval_item_widget.dart';
import 'package:schooldesk1/theme/app_theme.dart';

void main() {
  Future<List<FlutterErrorDetails>> collectFlutterErrors(
    WidgetTester tester,
    Widget child,
  ) async {
    final errors = <FlutterErrorDetails>[];
    final previousOnError = FlutterError.onError;
    FlutterError.onError = errors.add;

    await tester.binding.setSurfaceSize(const Size(360, 800));
    try {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(360, 800),
              textScaler: TextScaler.linear(1.35),
            ),
            child: Scaffold(body: child),
          ),
        ),
      );
      await tester.pump();
    } finally {
      FlutterError.onError = previousOnError;
      await tester.binding.setSurfaceSize(null);
    }
    return errors;
  }

  testWidgets('approval item avoids overflow on narrow phone widths', (
    tester,
  ) async {
    final errors = await collectFlutterErrors(
      tester,
      ListView(
        padding: const EdgeInsets.all(12),
        children: [
          ApprovalItemWidget(
            approval: ApprovalModel(
              id: 'approval-class-1',
              type: ApprovalType.classApproval,
              requesterName: 'admin@operations.long-school-domain.example',
              requesterRole: 'School Admin',
              requesterClass: 'Class 8 Section A with extended label',
              submittedDate: '2026-05-09',
              summary:
                  'Create Class 8 with sections A and B for the current academic year',
              details:
                  'Admin requested a class creation workflow. Principal approval should create the backend grade and section rows without making the card overflow on a phone.',
              status: 'pending',
              decisionPath: '/class-approvals/approval-class-1',
            ),
            onApprove: () {},
            onReject: (_) {},
          ),
        ],
      ),
    );

    expect(
      errors.where((e) => e.exceptionAsString().contains('overflowed')),
      isEmpty,
    );
  });
}
