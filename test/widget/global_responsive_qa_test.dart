import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schooldesk1/core/theme/app_theme.dart';
import 'package:schooldesk1/core/widgets/erp_components.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final profiles = <_ResponsiveProfile>[
    const _ResponsiveProfile(name: 'small Android phone', size: Size(320, 640)),
    const _ResponsiveProfile(
      name: 'medium Android phone',
      size: Size(390, 844),
    ),
    const _ResponsiveProfile(name: 'large Android phone', size: Size(430, 932)),
    const _ResponsiveProfile(name: 'tablet', size: Size(800, 1280)),
    const _ResponsiveProfile(name: 'foldable', size: Size(673, 841)),
    const _ResponsiveProfile(name: 'landscape phone', size: Size(844, 390)),
    const _ResponsiveProfile(
      name: 'increased display size',
      size: Size(300, 620),
    ),
    const _ResponsiveProfile(
      name: 'increased font size',
      size: Size(390, 844),
      textScale: 1.3,
    ),
    const _ResponsiveProfile(
      name: 'keyboard open state',
      size: Size(390, 844),
      viewInsets: EdgeInsets.only(bottom: 320),
    ),
  ];

  for (final profile in profiles) {
    testWidgets(
      'global components avoid responsive breakage on ${profile.name}',
      (tester) async {
        final errors = <FlutterErrorDetails>[];
        final previousOnError = FlutterError.onError;
        FlutterError.onError = errors.add;

        await tester.binding.setSurfaceSize(profile.size);
        try {
          await tester.pumpWidget(_ResponsiveQaHarness(profile: profile));
          await tester.pumpAndSettle();

          expect(
            errors.where((error) {
              final text = error.exceptionAsString().toLowerCase();
              return text.contains('overflowed') ||
                  text.contains('renderflex') ||
                  text.contains('boxconstraints forces an infinite');
            }),
            isEmpty,
            reason: 'Responsive errors in ${profile.name}',
          );
          expect(tester.takeException(), isNull);

          final navHeight = tester
              .getSize(find.byType(SchoolDeskBottomNavigationBar))
              .height;
          expect(navHeight, greaterThanOrEqualTo(72));
          expect(navHeight, lessThanOrEqualTo(104));

          final cardCount = find.byType(SchoolDeskCard).evaluate().length;
          expect(cardCount, greaterThan(0));
          for (var index = 0; index < cardCount; index += 1) {
            final rect = tester.getRect(find.byType(SchoolDeskCard).at(index));
            expect(rect.left, greaterThanOrEqualTo(0));
            expect(rect.right, lessThanOrEqualTo(profile.size.width + 0.5));
            expect(rect.width, greaterThan(64));
          }
        } finally {
          FlutterError.onError = previousOnError;
          await tester.binding.setSurfaceSize(null);
        }
      },
    );
  }
}

class _ResponsiveProfile {
  final String name;
  final Size size;
  final double textScale;
  final EdgeInsets viewInsets;

  const _ResponsiveProfile({
    required this.name,
    required this.size,
    this.textScale = 1.0,
    this.viewInsets = EdgeInsets.zero,
  });
}

class _ResponsiveQaHarness extends StatelessWidget {
  final _ResponsiveProfile profile;

  const _ResponsiveQaHarness({required this.profile});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: MediaQuery(
        data: MediaQueryData(
          size: profile.size,
          textScaler: TextScaler.linear(profile.textScale),
          viewInsets: profile.viewInsets,
          padding: const EdgeInsets.only(top: 24),
        ),
        child: Scaffold(
          resizeToAvoidBottomInset: true,
          appBar: const SchoolDeskAppBar(
            title: 'Operations Dashboard',
            subtitle: 'Long campus name and active academic session',
          ),
          bottomNavigationBar: SchoolDeskBottomNavigationBar(
            items: [
              SchoolDeskBottomNavItem(
                label: 'Home',
                icon: Icons.home_outlined,
                activeIcon: Icons.home_rounded,
                selected: true,
                onTap: () {},
              ),
              SchoolDeskBottomNavItem(
                label: 'Global Search',
                icon: Icons.search_rounded,
                activeIcon: Icons.manage_search_rounded,
                selected: false,
                onTap: () {},
              ),
              SchoolDeskBottomNavItem(
                label: 'Inbox Alerts',
                icon: Icons.mail_outline_rounded,
                activeIcon: Icons.mail_rounded,
                selected: false,
                badgeCount: 128,
                onTap: () {},
              ),
              SchoolDeskBottomNavItem(
                label: 'Profile Settings',
                icon: Icons.account_circle_outlined,
                activeIcon: Icons.account_circle_rounded,
                selected: false,
                onTap: () {},
              ),
            ],
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SchoolDeskPageHeader(
                    title: 'Responsive QA Validation',
                    subtitle:
                        'Checks dense ERP content, long labels, card alignment, search, forms, and actions.',
                    actions: [
                      SchoolDeskButton.outlined(
                        label: 'Export monthly report',
                        icon: Icons.download_rounded,
                        onPressed: null,
                      ),
                    ],
                  ),
                  const SchoolDeskDataToolbar(
                    searchLabel: 'Search very long student or staff record',
                  ),
                  const SizedBox(height: 16),
                  SchoolDeskResponsiveGrid(
                    children: [
                      for (final item in _stats)
                        SchoolDeskStatBox(
                          label: item.label,
                          value: item.value,
                          icon: item.icon,
                          caption: item.caption,
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const SchoolDeskSectionCard(
                    title: 'Section Balance And Card Alignment',
                    subtitle:
                        'This section intentionally includes a long subtitle to validate wrapping without zooming.',
                    child: Column(
                      children: [
                        SchoolDeskTextField(
                          label: 'Official full name',
                          hint: 'Enter name',
                          prefixIcon: Icons.person_outline_rounded,
                        ),
                        SizedBox(height: 16),
                        SchoolDeskTextField(
                          label: 'Detailed remarks for accessibility scaling',
                          hint: 'Enter remarks',
                          prefixIcon: Icons.notes_rounded,
                          maxLines: 3,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SchoolDeskCard(
                    child: Column(
                      children: [
                        for (final item in _listItems)
                          SchoolDeskListTile(
                            title: item.label,
                            subtitle: item.caption,
                            leadingIcon: item.icon,
                            trailing: const Icon(Icons.chevron_right_rounded),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(height: profile.viewInsets.bottom + 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

const _stats = [
  _QaItem(
    label: 'Total students across active sections',
    value: '1,248',
    caption: 'Updated today',
    icon: Icons.school_outlined,
  ),
  _QaItem(
    label: 'Pending approval workflows',
    value: '18',
    caption: 'Needs review',
    icon: Icons.rule_folder_outlined,
  ),
  _QaItem(
    label: 'Attendance exceptions',
    value: '42',
    caption: 'Live backend',
    icon: Icons.fact_check_outlined,
  ),
  _QaItem(
    label: 'Fee follow-ups',
    value: '9',
    caption: 'This week',
    icon: Icons.account_balance_wallet_outlined,
  ),
];

const _listItems = [
  _QaItem(
    label: 'Class 8 Section A with extended label',
    caption: 'Homeroom, attendance, and fee summary available',
    icon: Icons.groups_outlined,
  ),
  _QaItem(
    label: 'Parent meeting escalation queue',
    caption: 'Long subtitle should wrap without clipping or row overflow',
    icon: Icons.support_agent_rounded,
  ),
  _QaItem(
    label: 'Transport and facility announcement',
    caption: 'Shared list-tile density must match card density',
    icon: Icons.campaign_outlined,
  ),
];

class _QaItem {
  final String label;
  final String value;
  final String caption;
  final IconData icon;

  const _QaItem({
    required this.label,
    this.value = '',
    required this.caption,
    required this.icon,
  });
}
