import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:schooldesk1/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Android document picker and PDF share chooser complete', (
    tester,
  ) async {
    try {
      await _startTestApp(tester);

      developer.log('ANDROID_QA: opening PDF document picker');
      final picked = await tester.runAsync(
        () => FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: const ['pdf'],
        ),
      );
      expect(picked, isNotNull);
      expect(picked!.files.single.name, 'SchoolDesk-QA.pdf');

      final pdfBytes = await _buildSyntheticPdf(tester);
      developer.log('ANDROID_QA: opening PDF share chooser');
      await tester.runAsync(
        () => Printing.sharePdf(
          bytes: pdfBytes,
          filename: 'SchoolDesk-QA.pdf',
        ),
      );
    } finally {
      app.disposeAppSemanticsHandleForTesting();
    }
  });

  testWidgets('Android print preview opens for a synthetic PDF', (
    tester,
  ) async {
    try {
      await _startTestApp(tester);
      final pdfBytes = await _buildSyntheticPdf(tester);
      developer.log('ANDROID_QA: opening Android print preview');
      await tester.runAsync(
        () => Printing.layoutPdf(
          onLayout: (_) async => pdfBytes,
          name: 'SchoolDesk-QA.pdf',
        ),
      );
    } finally {
      app.disposeAppSemanticsHandleForTesting();
    }
  });
}

Future<void> _startTestApp(WidgetTester tester) async {
  final originalErrorWidgetBuilder = ErrorWidget.builder;
  final originalFlutterErrorHandler = FlutterError.onError;
  app.main();
  try {
    for (var attempt = 0; attempt < 50; attempt++) {
      await tester.pump(const Duration(milliseconds: 500));
      if (find.byType(app.MyApp).evaluate().isNotEmpty) break;
    }
  } finally {
    ErrorWidget.builder = originalErrorWidgetBuilder;
    FlutterError.onError = originalFlutterErrorHandler;
  }
}

Future<Uint8List> _buildSyntheticPdf(WidgetTester tester) async {
  final pdfBytes = await tester.runAsync(() async {
    final document = pw.Document();
    document.addPage(
      pw.Page(
        build: (_) => pw.Center(child: pw.Text('Synthetic SchoolDesk QA')),
      ),
    );
    return document.save();
  });
  expect(pdfBytes, isNotNull);
  return pdfBytes!;
}
