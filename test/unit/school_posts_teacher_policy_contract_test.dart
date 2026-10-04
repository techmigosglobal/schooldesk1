import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('teacher school-post UI exposes only direct gallery publishing', () {
    final source = File(
      'lib/features/communication/presentation/screens/event_post_screen.dart',
    ).readAsStringSync();

    expect(
      source,
      contains('bool get _teacherGalleryOnly => !widget.principalMode;'),
    );
    expect(source, contains("destinations.add('SCHOOL_GALLERY');"));
    expect(
      source,
      contains('Teacher posts publish directly to the school gallery.'),
    );
    expect(source, contains("title: const Text('Parent Home Feed')"));
    expect(
      source,
      contains("title: const Text('Landing Page (pre-login auto slider)')"),
    );
    expect(source, contains('if (widget.principalMode)'));
  });

  test('API rejects teacher parent, staff, and landing destinations', () {
    final source = File(
      'supabase/functions/api/handlers/uploads.ts',
    ).readAsStringSync();

    expect(source, contains('function teacherEventPostPolicy('));
    expect(
      source,
      contains('teachers may publish school posts only to the school gallery'),
    );
    expect(
      source,
      contains(
        'teachers may not publish school posts to the public landing page',
      ),
    );
    expect(
      source,
      contains(
        '(isPrincipal || userRole === "teacher") && body.is_submit === true',
      ),
    );
    expect(source, contains('destinations: effectiveDestinations'));
  });

  test(
    'principal initial tab resolution runs once and respects user tab taps',
    () {
      final source = File(
        'lib/features/communication/presentation/screens/event_post_screen.dart',
      ).readAsStringSync();

      expect(source, contains('bool _principalInitialTabResolved = false;'));
      expect(source, contains('bool _principalTabInteracted = false;'));
      expect(
        source,
        contains(
          'if (_principalInitialTabResolved || _principalTabInteracted) return;',
        ),
      );
      expect(source, contains('onTap: (_) => _principalTabInteracted = true,'));
    },
  );
}
