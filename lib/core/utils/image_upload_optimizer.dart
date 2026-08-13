import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:image/image.dart' as img;

enum ImageUploadPreset { portrait, branding, content }

/// The result passed to multipart upload methods. The original byte count is
/// retained for diagnostics; only [bytes] are uploaded.
class OptimizedImageUpload {
  final Uint8List bytes;
  final String filename;
  final String mimeType;
  final int originalSize;
  final int optimizedSize;

  const OptimizedImageUpload({
    required this.bytes,
    required this.filename,
    required this.mimeType,
    required this.originalSize,
    required this.optimizedSize,
  });
}

class ImageUploadException implements Exception {
  final String message;

  const ImageUploadException(this.message);

  @override
  String toString() => message;
}

/// Decodes and compresses new image uploads before they reach Storage.
///
/// This deliberately does not touch PDFs, office files, videos, or existing
/// Storage objects. A caller must opt into this helper for an image input.
class ImageUploadOptimizer {
  ImageUploadOptimizer._();

  static const int portraitMaxDimension = 1024;
  static const int brandingMaxDimension = 1600;
  static const int contentMaxDimension = 2048;
  static const int portraitMaxBytes = 1 * 1024 * 1024;
  static const int brandingMaxBytes = 2 * 1024 * 1024;
  static const int contentMaxBytes = 3 * 1024 * 1024;

  static Future<OptimizedImageUpload> fromXFile(
    XFile file, {
    required ImageUploadPreset preset,
    String? mimeType,
    int? maxBytes,
  }) async {
    final bytes = await file.readAsBytes();
    return fromBytes(
      bytes,
      filename: file.name,
      mimeType: mimeType ?? file.mimeType,
      preset: preset,
      maxBytes: maxBytes,
    );
  }

  static Future<OptimizedImageUpload> fromPath(
    String path, {
    required String filename,
    required ImageUploadPreset preset,
    String? mimeType,
    int? maxBytes,
  }) async {
    final cleanPath = path.trim();
    if (cleanPath.isEmpty) {
      throw const ImageUploadException('Please choose an image again.');
    }
    return fromXFile(
      XFile(cleanPath, name: filename, mimeType: mimeType),
      preset: preset,
      mimeType: mimeType,
      maxBytes: maxBytes,
    );
  }

  static OptimizedImageUpload fromBytes(
    Uint8List source, {
    required String filename,
    required ImageUploadPreset preset,
    String? mimeType,
    int? maxBytes,
  }) {
    if (source.isEmpty) {
      throw const ImageUploadException('The selected image is empty.');
    }
    final originalMime = _mimeTypeFor(filename, mimeType);
    if (!isImage(filename, originalMime)) {
      throw const ImageUploadException(
        'This file is not a supported image. Documents and videos are uploaded separately.',
      );
    }

    img.Image? decoded;
    try {
      decoded = img.decodeImage(source);
    } on Object {
      throw const ImageUploadException(
        'This image could not be decoded. Please choose a JPG or PNG image.',
      );
    }
    if (decoded == null || decoded.width <= 0 || decoded.height <= 0) {
      throw const ImageUploadException(
        'This image could not be decoded. Please choose a JPG or PNG image.',
      );
    }

    final oriented = img.bakeOrientation(decoded);
    final maxDimension = _maxDimension(preset);
    final resized = _resizeIfNeeded(oriented, maxDimension);
    final keepPng = oriented.hasAlpha || originalMime == 'image/png';
    final encoded = keepPng
        ? img.encodePng(resized, level: 6)
        : img.encodeJpg(resized, quality: _quality(preset));
    final optimized = Uint8List.fromList(encoded);
    final byteLimit = maxBytes ?? _maxBytes(preset);

    // PNG compression can be larger than a small original. Keeping the
    // original in that case avoids needless expansion while retaining alpha.
    final outputBytes = optimized.length <= source.length ? optimized : source;
    final outputMime = keepPng ? 'image/png' : 'image/jpeg';
    final outputName = _filenameFor(filename, outputMime);

    if (outputBytes.length > byteLimit) {
      throw ImageUploadException(
        'This image is still too large after compression (${_formatBytes(outputBytes.length)}). '
        'Please choose a smaller image.',
      );
    }

    return OptimizedImageUpload(
      bytes: Uint8List.fromList(outputBytes),
      filename: outputName,
      mimeType: outputMime,
      originalSize: source.length,
      optimizedSize: outputBytes.length,
    );
  }

  static bool isImage(String filename, [String? mimeType]) {
    final mime = mimeType?.trim().toLowerCase() ?? '';
    if (mime.startsWith('image/')) return true;
    final lower = filename.toLowerCase().split('?').first;
    return const [
      '.jpg',
      '.jpeg',
      '.png',
      '.webp',
      '.gif',
      '.heic',
      '.heif',
    ].any(lower.endsWith);
  }

  static String mimeTypeForFilename(String filename) =>
      _mimeTypeFor(filename, null);

  static int _maxDimension(ImageUploadPreset preset) => switch (preset) {
    ImageUploadPreset.portrait => portraitMaxDimension,
    ImageUploadPreset.branding => brandingMaxDimension,
    ImageUploadPreset.content => contentMaxDimension,
  };

  static int _maxBytes(ImageUploadPreset preset) => switch (preset) {
    ImageUploadPreset.portrait => portraitMaxBytes,
    ImageUploadPreset.branding => brandingMaxBytes,
    ImageUploadPreset.content => contentMaxBytes,
  };

  static int _quality(ImageUploadPreset preset) => switch (preset) {
    ImageUploadPreset.portrait => 82,
    ImageUploadPreset.branding => 85,
    ImageUploadPreset.content => 80,
  };

  static img.Image _resizeIfNeeded(img.Image source, int maxDimension) {
    if (source.width <= maxDimension && source.height <= maxDimension) {
      return source;
    }
    final landscape = source.width >= source.height;
    return img.copyResize(
      source,
      width: landscape ? maxDimension : null,
      height: landscape ? null : maxDimension,
      interpolation: img.Interpolation.average,
    );
  }

  static String _mimeTypeFor(String filename, String? supplied) {
    final explicit = supplied?.trim().toLowerCase() ?? '';
    if (explicit.isNotEmpty && explicit != 'application/octet-stream') {
      return explicit;
    }
    final lower = filename.toLowerCase().split('?').first;
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.heic')) return 'image/heic';
    if (lower.endsWith('.heif')) return 'image/heif';
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.doc')) return 'application/msword';
    if (lower.endsWith('.docx')) {
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    }
    if (lower.endsWith('.xls')) return 'application/vnd.ms-excel';
    if (lower.endsWith('.xlsx')) {
      return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    }
    if (lower.endsWith('.mp4')) return 'video/mp4';
    return 'application/octet-stream';
  }

  static String _filenameFor(String filename, String mimeType) {
    final clean = filename.trim().isEmpty
        ? 'schooldesk-image'
        : filename.trim();
    final dot = clean.lastIndexOf('.');
    final stem = dot > 0 ? clean.substring(0, dot) : clean;
    return '$stem.${mimeType == 'image/png' ? 'png' : 'jpg'}';
  }

  static String _formatBytes(int value) {
    if (value >= 1024 * 1024) {
      return '${(value / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(value / 1024).toStringAsFixed(0)} KB';
  }
}
