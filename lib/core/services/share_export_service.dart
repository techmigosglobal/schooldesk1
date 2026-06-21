import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ShareExportService {
  const ShareExportService();

  Future<void> shareBytes({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
    required String title,
    String? subject,
    String? text,
  }) async {
    final safeFileName = _safeFileName(fileName);
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/$safeFileName');
    await file.writeAsBytes(bytes, flush: true);

    await SharePlus.instance.share(
      ShareParams(
        title: title,
        subject: subject,
        text: text,
        files: [XFile(file.path, mimeType: mimeType, name: safeFileName)],
        fileNameOverrides: [safeFileName],
      ),
    );
  }

  String _safeFileName(String fileName) {
    final trimmed = fileName.trim();
    if (trimmed.isEmpty ||
        trimmed.contains('/') ||
        trimmed.contains('\\') ||
        trimmed.contains('..')) {
      throw ArgumentError.value(
        fileName,
        'fileName',
        'Invalid export file name',
      );
    }
    return trimmed;
  }
}
