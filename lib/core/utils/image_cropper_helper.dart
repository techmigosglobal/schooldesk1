import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:schooldesk1/core/utils/extensions.dart';

class SchoolDeskImageCropper {
  SchoolDeskImageCropper._();

  /// Crops an image to the exact portrait ratio used by the pre-login
  /// landing-page slider.
  static Future<String?> cropLandingPortraitImage({
    required BuildContext context,
    required String sourcePath,
    String title = 'Crop landing image (9:16)',
    int maxWidth = 1080,
    int maxHeight = 1920,
  }) async {
    const preset = _FixedAspectRatioPreset(name: '9x16', ratioX: 9, ratioY: 16);
    final cropped = await ImageCropper().cropImage(
      sourcePath: sourcePath,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      aspectRatio: const CropAspectRatio(ratioX: 9, ratioY: 16),
      compressFormat: sourcePath.toLowerCase().endsWith('.png')
          ? ImageCompressFormat.png
          : ImageCompressFormat.jpg,
      compressQuality: 88,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: title,
          toolbarColor: const Color(0xFF0F6EA8),
          toolbarWidgetColor: context.appTheme.surface,
          activeControlsWidgetColor: const Color(0xFF0887F2),
          backgroundColor: const Color(0xFFEFF8FD),
          initAspectRatio: preset,
          lockAspectRatio: true,
          aspectRatioPresets: [preset],
        ),
        IOSUiSettings(
          title: title,
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
          aspectRatioPickerButtonHidden: true,
          aspectRatioPresets: [preset],
        ),
        WebUiSettings(
          context: context,
          presentStyle: WebPresentStyle.dialog,
          size: const CropperSize(width: 420, height: 720),
          viewwMode: WebViewMode.mode_1,
        ),
      ],
    );
    return cropped?.path;
  }

  static Future<String?> cropSquareImage({
    required BuildContext context,
    required String sourcePath,
    required String title,
    CropStyle cropStyle = CropStyle.circle,
    int maxSize = 900,
  }) async {
    final cropped = await ImageCropper().cropImage(
      sourcePath: sourcePath,
      maxWidth: maxSize,
      maxHeight: maxSize,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      compressFormat: sourcePath.toLowerCase().endsWith('.png')
          ? ImageCompressFormat.png
          : ImageCompressFormat.jpg,
      compressQuality: 88,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: title,
          toolbarColor: const Color(0xFF0F6EA8),
          toolbarWidgetColor: context.appTheme.surface,
          activeControlsWidgetColor: const Color(0xFF0887F2),
          backgroundColor: const Color(0xFFEFF8FD),
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true,
          cropStyle: cropStyle,
          aspectRatioPresets: const [CropAspectRatioPreset.square],
        ),
        IOSUiSettings(
          title: title,
          doneButtonTitle: 'Use',
          cancelButtonTitle: 'Cancel',
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
          aspectRatioPickerButtonHidden: true,
          cropStyle: cropStyle,
          aspectRatioPresets: const [CropAspectRatioPreset.square],
        ),
        WebUiSettings(
          context: context,
          presentStyle: WebPresentStyle.dialog,
          size: const CropperSize(width: 420, height: 420),
          viewwMode: WebViewMode.mode_1,
        ),
      ],
    );
    return cropped?.path;
  }
}

class _FixedAspectRatioPreset implements CropAspectRatioPresetData {
  const _FixedAspectRatioPreset({
    required this.name,
    required this.ratioX,
    required this.ratioY,
  });

  @override
  final String name;
  final int ratioX;
  final int ratioY;

  @override
  (int, int) get data => (ratioX, ratioY);
}
