import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('parent dashboard keeps school feed stable during background refresh', () {
    final source = File(
      'lib/features/dashboard/presentation/screens/parent_dashboard_screen/parent_dashboard_screen.dart',
    ).readAsStringSync();

    expect(source, contains('bool includeFeedPosts = true'));
    expect(source, contains('includeFeedPosts: false'));
    expect(source, contains('onFeedRetry: _loadFeed'));
    expect(source, contains('await _showSnapshot(snapshot, scope)'));
    expect(source, contains('_repository.loadFeed().timeout(_loadTimeout)'));
    expect(source, contains('.whereType<Map>()'));
  });
}
