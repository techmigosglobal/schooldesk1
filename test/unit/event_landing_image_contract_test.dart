import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'event posts allow feed video while keeping landing posts image-only',
    () {
      final screen = File(
        'lib/features/communication/presentation/screens/event_post_screen.dart',
      ).readAsStringSync();
      final handler = File(
        'supabase/functions/api/handlers/uploads.ts',
      ).readAsStringSync();

      expect(screen, contains('Landing Page (pre-login auto slider)'));
      expect(screen, contains("label: const Text('Pick Video')"));
      expect(screen, contains("destinations.add('SCHOOL_LANDING')"));
      expect(handler, contains('Event posts accept images and videos only'));
      expect(handler, contains('Landing page posts accept images only'));
      expect(
        handler,
        contains('Landing page posts require at least one image'),
      );
      expect(
        handler,
        contains('return normalizeDestinations(value, visibility)'),
      );
      expect(
        handler,
        isNot(
          contains(
            "set destinations = '[\"PARENTS_HOME\",\"SCHOOL_GALLERY\"]'",
          ),
        ),
      );
    },
  );
}
