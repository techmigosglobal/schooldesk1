import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:schooldesk1/core/utils/image_upload_optimizer.dart';

void main() {
  test('compresses JPEG photos and respects the content dimensions', () {
    final sourceImage = img.Image(width: 3200, height: 1800);
    for (var y = 0; y < sourceImage.height; y += 1) {
      for (var x = 0; x < sourceImage.width; x += 1) {
        sourceImage.setPixelRgb(x, y, x % 251, y % 241, (x + y) % 239);
      }
    }
    final source = Uint8List.fromList(img.encodeJpg(sourceImage, quality: 100));

    final result = ImageUploadOptimizer.fromBytes(
      source,
      filename: 'activity-photo.jpeg',
      mimeType: 'image/jpeg',
      preset: ImageUploadPreset.content,
    );
    final decoded = img.decodeImage(result.bytes)!;

    expect(result.mimeType, 'image/jpeg');
    expect(result.filename, 'activity-photo.jpg');
    expect(result.originalSize, source.length);
    expect(result.optimizedSize, lessThan(source.length));
    expect(decoded.width, lessThanOrEqualTo(2048));
    expect(decoded.height, lessThanOrEqualTo(2048));
  });

  test('keeps transparent branding images as PNG', () {
    final sourceImage = img.Image(width: 120, height: 80, numChannels: 4);
    for (final pixel in sourceImage) {
      pixel.r = 10;
      pixel.g = 110;
      pixel.b = 190;
      pixel.a = 0;
    }
    sourceImage.getPixel(40, 30).a = 255;
    final source = Uint8List.fromList(img.encodePng(sourceImage));

    final result = ImageUploadOptimizer.fromBytes(
      source,
      filename: 'school-logo.png',
      mimeType: 'image/png',
      preset: ImageUploadPreset.branding,
    );
    final decoded = img.decodeImage(result.bytes)!;

    expect(result.mimeType, 'image/png');
    expect(result.filename, 'school-logo.png');
    expect(decoded.hasAlpha, isTrue);
    expect(decoded.getPixel(0, 0).a, 0);
    expect(decoded.getPixel(40, 30).a, 255);
  });

  test('rejects undecodable and still-oversized images', () {
    expect(
      () => ImageUploadOptimizer.fromBytes(
        Uint8List.fromList([1, 2, 3]),
        filename: 'broken.jpg',
        mimeType: 'image/jpeg',
        preset: ImageUploadPreset.portrait,
      ),
      throwsA(isA<ImageUploadException>()),
    );

    final largeEnough = Uint8List.fromList(
      img.encodeJpg(img.Image(width: 64, height: 64), quality: 100),
    );
    expect(
      () => ImageUploadOptimizer.fromBytes(
        largeEnough,
        filename: 'large-logo.png',
        mimeType: 'image/jpeg',
        preset: ImageUploadPreset.branding,
        maxBytes: 1,
      ),
      throwsA(isA<ImageUploadException>()),
    );
  });
}
