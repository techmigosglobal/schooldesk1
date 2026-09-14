import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('parent dashboard keeps school feed stable during background refresh', () {
    final source = File(
      'lib/features/dashboard/presentation/screens/parent_dashboard_screen/parent_dashboard_screen.dart',
    ).readAsStringSync();

    expect(source, contains('bool includeFeedPosts = true'));
    expect(source, contains('includeFeedPosts: false'));
    expect(source, contains('final feedResult = includeFeedPosts'));
    expect(source, contains('feedResult?.page == null'));
    expect(source, contains('.whereType<Map>()'));
  });
}
