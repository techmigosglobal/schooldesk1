import 'dart:io';

import 'package:test/test.dart';

void main() {
  group('PDF reports, concessions, and public gallery contracts', () {
    test('server report exports accept and generate PDF artifacts only', () {
      final source = File(
        'supabase/functions/api/handlers/uploads.ts',
      ).readAsStringSync();

      expect(source, contains('Only PDF report exports are supported'));
      expect(source, contains("application/pdf"));
      expect(source, contains(".pdf"));
      expect(source, isNot(contains('text/csv')));
    });

    test('academic year reports are PDF-only and open a preview first', () {
      final source = File(
        'lib/features/academics/presentation/screens/'
        'academic_management_screen/principal_academic_years_screen.dart',
      ).readAsStringSync();

      expect(source, contains("static const String _format = 'pdf'"));
      expect(source, contains("Text('PDF report')"));
      expect(source, contains('PdfService.getInstance().previewDocument'));
      expect(source, isNot(contains("'csv', 'xlsx', 'pdf'")));
    });

    test('concessions are searchable, editable, and invoice-validated', () {
      final screen = File(
        'lib/features/finance/presentation/screens/admin_fees_screen/'
        'admin_fees_screen.dart',
      ).readAsStringSync();
      final handler = File(
        'supabase/functions/api/handlers/fees.ts',
      ).readAsStringSync();

      expect(screen, contains('Search student, ID, invoice, or fee item'));
      expect(screen, contains('_openEditConcessionDialog'));
      expect(screen, contains('Edit concession'));
      expect(
        handler,
        contains('concession must not exceed the outstanding balance'),
      );
      expect(handler, contains('student_id'));
      expect(handler, contains('invoice_id'));
    });

    test(
      'approved school-gallery event media is normalized for public web',
      () {
        final handler = File(
          'supabase/functions/api/handlers/website.ts',
        ).readAsStringSync();
        final website = File(
          'schooldesk-web/app/gallery/page.tsx',
        ).readAsStringSync();

        expect(handler, contains('eventGalleryRows'));
        expect(handler, contains('SCHOOL_GALLERY'));
        expect(handler, contains('media_type'));
        expect(website, contains('isVideo'));
        expect(website, contains('gallery-media'));
      },
    );
  });
}
