import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('gallery JSON filters and approval notifications use the deployed API', () {
    final handler = File(
      'supabase/functions/api/handlers/uploads.ts',
    ).readAsStringSync();

    expect(
      handler,
      contains('.contains("destinations", JSON.stringify(["SCHOOL_GALLERY"]))'),
    );
    expect(
      handler,
      contains('.contains("destinations", JSON.stringify(["PARENTS_HOME"]))'),
    );
    expect(
      handler,
      contains('.contains("destinations", JSON.stringify(["SCHOOL_LANDING"]))'),
    );
    expect(handler, contains('notifyUsersByRole(svc, school, "parent", galleryPayload)'));
    expect(handler, contains('notifyUsersByRole(svc, school, "teacher", {'));
    expect(handler, contains(r'excludeUserId: `${existing.created_by ?? ""}`'));
    expect(handler, contains('triggerPushProcessing(eventIds)'));
  });
}
