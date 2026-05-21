import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';

class SchoolDeskImageCropper {
  SchoolDeskImageCropper._();

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
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 88,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: title,
          toolbarColor: const Color(0xFF0F6EA8),
          toolbarWidgetColor: Colors.white,
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
