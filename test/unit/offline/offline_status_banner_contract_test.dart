import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('offline status banner exposes an accessible retry action', () {
    final source = File(
      'lib/core/offline/offline_status_banner.dart',
    ).readAsStringSync();

    expect(source, contains("import 'dart:async';"));
    expect(source, contains('unawaited(sync.syncNow())'));
    expect(source, contains("label: 'Retry sync'"));
    expect(source, contains('tooltip: \'Retry sync\''));
    expect(source, contains('liveRegion: true'));
  });
}
