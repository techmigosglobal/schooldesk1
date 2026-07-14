import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:schooldesk1/core/theme/app_theme.dart';
import 'package:schooldesk1/features/finance/presentation/screens/admin_fees_screen/admin_fee_form_screens.dart';
import 'package:schooldesk1/features/shared/data/models/backend_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  test('treats a prefilled create form as creation, not an edit', () {
    const seededCreate = AdminFeeStructureFormArgs(
      academicYears: [],
      grades: [],
      sections: [],
      feeCategories: [],
      feeStructure: {'academic_year_id': 'year-1', 'grade_id': 'grade-1'},
      ownerRole: 'principal',
    );
    const existingStructure = AdminFeeStructureFormArgs(
      academicYears: [],
      grades: [],
      sections: [],
      feeCategories: [],
      feeStructure: {'structure_id': 'fee-structure-1'},
      ownerRole: 'principal',
    );

    expect(seededCreate.isEditing, isFalse);
    expect(existingStructure.isEditing, isTrue);
  });

  testWidgets('updates the payment preview as the due day is edited', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const AdminFeeStructureFormScreen(args: _editingArgs),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('INR 12 | Monthly | due day 10'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(1), '11');
    await tester.pump();

    expect(find.text('INR 12 | Monthly | due day 11'), findsOneWidget);
  });
}

const _editingArgs = AdminFeeStructureFormArgs(
  academicYears: [
    AcademicYearModel(
      id: 'year-1',
      schoolId: 'school-1',
      yearLabel: '2026-27',
      startDate: '2026-06-01',
      endDate: '2027-03-31',
      isCurrent: true,
      status: 'active',
    ),
  ],
  grades: [
    GradeModel(
      id: 'grade-1',
      schoolId: 'school-1',
      gradeNumber: 5,
      gradeName: 'Class 5',
    ),
  ],
  sections: [
    SectionModel(
      id: 'section-1',
      gradeId: 'grade-1',
      gradeName: 'Class 5',
      academicYearId: 'year-1',
      sectionName: 'A',
      classTeacherId: '',
      classTeacherName: '',
      roomId: '',
      roomNumber: '',
      roomType: '',
      capacity: 30,
    ),
  ],
  feeCategories: [
    {'id': 'tuition', 'category_name': 'Tuition Fee', 'frequency': 'monthly'},
  ],
  feeStructure: {
    'id': 'structure-1',
    'academic_year_id': 'year-1',
    'grade_id': 'grade-1',
    'section_id': 'section-1',
    'fee_category_id': 'tuition',
    'amount': 12,
    'frequency': 'monthly',
    'due_day': 10,
    'late_fine_per_day': 1,
  },
  ownerRole: 'principal',
);
