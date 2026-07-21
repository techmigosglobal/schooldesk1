import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schooldesk1/core/widgets/custom_error_widget.dart';
import 'package:schooldesk1/main.dart' as app;

void main() {
  test('every framework error receives the visible application boundary', () {
    final widget = app.buildSchoolDeskErrorWidget(
      FlutterErrorDetails(exception: StateError('test failure')),
    );

    expect(widget, isA<CustomErrorWidget>());
  });
}
