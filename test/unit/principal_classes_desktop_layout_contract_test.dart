import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Class Hub uses a desktop-specific directory instead of mobile cards', () {
    final screen = File(
      'lib/features/academics/presentation/screens/principal_classes_screen/principal_classes_screen.dart',
    ).readAsStringSync();

    final desktopLayout = screen.substring(
      screen.indexOf('Widget _buildDesktopLayout()'),
      screen.indexOf('Widget _buildDesktopDetailPane()'),
    );

    expect(desktopLayout, contains('masterWidth: 380'));
    expect(desktopLayout, contains('_DesktopClassHubMasterHeader'));
    expect(desktopLayout, contains('_DesktopClassHubFilterBar'));
    expect(desktopLayout, contains('_DesktopClassHubSummaryBar'));
    expect(desktopLayout, contains('_DesktopClassHubListItem'));
    expect(desktopLayout, isNot(contains('_ClassesDirectoryMetricStrip')));
    expect(desktopLayout, isNot(contains('_ClassesDirectoryClassCard')));
  });

  test(
    'Class Hub desktop details provide labeled actions and responsive tools',
    () {
      final screen = File(
        'lib/features/academics/presentation/screens/principal_classes_screen/principal_classes_screen.dart',
      ).readAsStringSync();

      expect(screen, contains('Class workspace'));
      expect(screen, contains('Edit class'));
      expect(screen, contains('_DesktopClassHubActionGrid'));
      expect(
        screen,
        contains('final columns = constraints.maxWidth >= 920 ? 3 : 2'),
      );
    },
  );
}
