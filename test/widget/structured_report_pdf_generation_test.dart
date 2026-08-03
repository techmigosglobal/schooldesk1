import 'package:flutter_test/flutter_test.dart';
import 'package:schooldesk1/core/services/pdf_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('generates a structured report PDF with real report sections', (
    tester,
  ) async {
    final bytes = await PdfService.getInstance().generateStructuredReport(
      reportTitle: 'Attendance Report',
      period: 'August 2026',
      scope: 'Arish Ville - branch-scoped report',
      schoolName: 'Arish Ville',
      schoolAddress: 'Branch address',
      metrics: const [
        {'label': 'Students', 'value': '62'},
        {'label': 'Average', 'value': '88.4%'},
      ],
      tables: const [
        {
          'title': 'Attendance by class / section',
          'headers': ['Class / section', 'Students', 'Present', 'Attendance'],
          'rows': [
            ['Playgroup - A', '12', '11', '91.7%'],
          ],
          'weights': [2.3, 1, 1, 1.2],
        },
      ],
    );

    expect(bytes.length, greaterThan(1000));
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });
}
