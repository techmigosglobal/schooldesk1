import 'package:flutter_test/flutter_test.dart';

import 'package:schooldesk1/core/utils/secure_media_cache.dart';

void main() {
  test('secure cache allows only scoped feed and profile media', () {
    expect(
      SecureSelectiveMediaCache.isCacheablePrivateMedia(
        'https://r2.example/event-posts/school/post/image.jpg',
      ),
      isTrue,
    );
    expect(
      SecureSelectiveMediaCache.isCacheablePrivateMedia(
        'https://r2.example/avatars/school/user/avatar.jpg',
      ),
      isTrue,
    );
  });

  test('secure cache excludes operational and financial media', () {
    for (final value in [
      'https://r2.example/payment-proofs/school/proof.jpg',
      'https://r2.example/student-documents/school/report.pdf',
      'https://r2.example/school-signatures/school/signature.png',
      'https://r2.example/help-tutorial-videos/video.mp4',
      'https://r2.example/issue-attachments/school/issue.mp4',
    ]) {
      expect(
        SecureSelectiveMediaCache.isCacheablePrivateMedia(value),
        isFalse,
        reason: value,
      );
    }
  });
}
