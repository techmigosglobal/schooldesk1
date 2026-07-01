import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ui issue polish keeps mobile FABs and filter chips usable', () {
    final complaints = File(
      'lib/features/communication/presentation/screens/complaint_management_screen/complaint_management_screen.dart',
    ).readAsStringSync();
    final students = File(
      'lib/features/people/presentation/screens/admin_students_screen/admin_students_screen.dart',
    ).readAsStringSync();
    final fees = File(
      'lib/features/finance/presentation/screens/admin_fees_screen/admin_fees_screen.dart',
    ).readAsStringSync();
    final parentFees = File(
      'lib/features/finance/presentation/screens/parent_fees_screen/parent_fees_screen.dart',
    ).readAsStringSync();
    final oversightFilters = File(
      'lib/features/people/presentation/screens/student_oversight_screen/widgets/student_filter_bar_widget.dart',
    ).readAsStringSync();
    final pdfService = File(
      'lib/core/services/pdf_service.dart',
    ).readAsStringSync();

    expect(complaints, contains('FloatingActionButton.extended'));
    expect(complaints, contains('FloatingActionButtonLocation.endFloat'));
    expect(complaints, isNot(contains('DashboardFabWidget')));

    for (final source in [students, fees]) {
      expect(source, contains('FloatingActionButtonLocation.endFloat'));
    }

    for (final source in [students, oversightFilters]) {
      expect(
        source,
        contains('backgroundColor: context.appTheme.surfaceVariant'),
      );
      expect(source, contains('MaterialTapTargetSize.shrinkWrap'));
    }
    expect(
      students,
      contains('selectedColor: context.appTheme.primaryContainer'),
    );
    expect(
      oversightFilters,
      contains('selectedColor: context.appTheme.primary'),
    );

    for (final source in [fees, parentFees]) {
      expect(source, contains('previewDocument('));
      expect(source, isNot(contains('Printing.layoutPdf')));
    }
    expect(pdfService, contains('PdfPreview('));
    expect(pdfService, contains('Printing.sharePdf'));
  });

  test('share exports use temporary files instead of in-memory XFiles', () {
    final shareService = File('lib/core/services/share_export_service.dart');
    final staffQr = File(
      'lib/core/widgets/staff_qr_attendance_panel.dart',
    ).readAsStringSync();
    final oversight = File(
      'lib/features/people/presentation/screens/student_oversight_screen/student_oversight_screen.dart',
    ).readAsStringSync();

    expect(shareService.existsSync(), isTrue);
    final source = shareService.readAsStringSync();
    expect(source, contains('class ShareExportService'));
    expect(source, contains('getTemporaryDirectory()'));
    expect(source, contains('XFile(file.path'));
    expect(source, contains('SharePlus.instance.share'));
    expect(source, contains('_safeFileName(fileName)'));
    expect(source, contains("trimmed.contains('/')"));
    expect(source, contains("trimmed.contains('\\\\')"));
    expect(source, contains("trimmed.contains('..')"));

    for (final source in [staffQr, oversight]) {
      expect(source, contains('ShareExportService'));
      expect(source, contains('shareBytes('));
      expect(source, isNot(contains('XFile.fromData')));
    }
  });

  test(
    'event calendar keeps compact text readable and shows created event month',
    () {
      final calendar = File(
        'lib/features/calendar/presentation/screens/events_calendar_screen/events_calendar_screen.dart',
      ).readAsStringSync();

      expect(calendar, contains('_EventFormResult'));
      expect(calendar, contains('_selectedMonth = saved.startDate.month'));
      expect(calendar, contains('_filter = _EventFilter.month'));
      expect(calendar, contains('Event created and calendar refreshed'));
      expect(calendar, contains('_ResponsivePickerGrid'));
      expect(calendar, contains('_buildSelectedDayAgenda()'));
      expect(calendar, contains('No entries on this day'));
      expect(calendar, contains("label: Text('Agenda')"));
      expect(calendar, contains('class _CalendarDateCell'));
      expect(
        calendar,
        contains('constraints: const BoxConstraints(minHeight: 68)'),
      );
      expect(calendar, contains('showModalBottomSheet<void>('));
      expect(calendar, contains('TextOverflow.ellipsis'));
    },
  );

  test('teacher leave request form resolves direct route context', () {
    final leaveForm = File(
      'lib/features/leave/presentation/screens/teacher_leave_screen/teacher_leave_request_form_screen.dart',
    ).readAsStringSync();

    expect(leaveForm, contains('_resolveStaffIdFromDashboard'));
    expect(
      leaveForm,
      contains("BackendApiClient.instance.getDashboard('teacher')"),
    );
    expect(leaveForm, isNot(contains('Open from Teacher module')));
    expect(leaveForm, isNot(contains('Teacher module context required')));
    expect(leaveForm, contains('Submit leave for principal approval'));
  });

  test('staff details assigned classes empty state stays readable', () {
    final staffScreen = File(
      'lib/features/people/presentation/screens/staff_management_screen/staff_management_screen.dart',
    ).readAsStringSync();

    expect(staffScreen, contains("title: 'Assigned Classes'"));
    expect(staffScreen, contains('width: double.infinity'));
    expect(staffScreen, contains('BoxConstraints(maxWidth: 240)'));
    expect(
      staffScreen,
      contains("visibleValues.first.toLowerCase() == 'not assigned'"),
    );
    expect(staffScreen, contains('Color(0xFF1E3A8A)'));
    expect(staffScreen, contains('Icons.info_outline_rounded'));
    expect(staffScreen, contains('No classes assigned'));
  });

  test('parent workflow shortcuts and fee payment controls stay readable', () {
    final parentDashboard = File(
      'lib/features/dashboard/presentation/screens/parent_dashboard_screen/parent_dashboard_screen.dart',
    ).readAsStringSync();

    expect(parentDashboard, contains("class _ParentWorkflowShortcuts"));
    expect(parentDashboard, contains('Wrap('));
    expect(parentDashboard, contains("ActionChip("));
    expect(parentDashboard, contains("'Pay Fees'"));
    expect(parentDashboard, contains("'Leave'"));
    expect(parentDashboard, isNot(contains("label: 'Academic\\nProgress'")));
    expect(parentDashboard, isNot(contains("label: 'Leave\\nRequest'")));

    final parentPaymentForm = File(
      'lib/features/finance/presentation/screens/parent_fees_screen/parent_payment_request_form_screen.dart',
    ).readAsStringSync();
    expect(
      parentPaymentForm,
      contains('selectedColor: context.appTheme.primary'),
    );
    expect(
      parentPaymentForm,
      contains('backgroundColor: context.appTheme.surface'),
    );
    expect(parentPaymentForm, contains('side: BorderSide'));
    expect(parentPaymentForm, contains('checkmarkColor: Colors.white'));
    expect(parentPaymentForm, contains('context.appTheme.onSurface'));

    expect(parentPaymentForm, contains('Selected fee breakdown'));
    expect(parentPaymentForm, contains('Submit Payment for Verification INR'));
    expect(parentPaymentForm, contains('Pay Now'));
    expect(parentPaymentForm, contains('Confirm Payment'));
  });

  test('source-only documentation contract is enforced', () {
    for (final path in ['README.md', 'docs/PRD.md', 'docs/SPEC.md']) {
      expect(File(path).existsSync(), isTrue, reason: '$path should exist');
    }

    final root = Directory.current.path;
    final markdownFiles = Directory.current
        .listSync(recursive: true)
        .whereType<File>()
        .map((file) => file.path.replaceFirst('$root/', ''))
        .where((path) => path.endsWith('.md'))
        .toSet();

    expect(
      markdownFiles,
      containsAll({
        'README.md',
        'docs/PRD.md',
        'docs/SPEC.md',
        'docs/teacher-principal-workflow-improvements.md',
      }),
    );
    expect(
      Directory('.github/workflows').existsSync()
          ? Directory('.github/workflows').listSync()
          : const <FileSystemEntity>[],
      isEmpty,
    );
  });
}
