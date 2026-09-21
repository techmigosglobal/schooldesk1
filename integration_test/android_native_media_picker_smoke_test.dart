import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:integration_test/integration_test.dart';
import 'package:schooldesk1/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Android camera and gallery intents open and cancel', (
    tester,
  ) async {
    try {
      await _startTestApp(tester);

      developer.log('ANDROID_QA: opening camera intent; do not capture');
      final cameraResult = await tester.runAsync(
        () => ImagePicker().pickImage(source: ImageSource.camera),
      );
      expect(cameraResult, isNull);

      developer.log('ANDROID_QA: opening gallery picker; do not select');
      final galleryResult = await tester.runAsync(
        () => ImagePicker().pickImage(source: ImageSource.gallery),
      );
      expect(galleryResult, isNull);
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
