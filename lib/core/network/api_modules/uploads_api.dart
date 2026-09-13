part of '../backend_api_client.dart';

extension BackendUploadsApi on BackendApiClient {
  Future<String> uploadFile(
    String filePath, {
    required String filename,
    Uint8List? fileBytes,
    String? mimeType,
    String folder = 'uploads',
    String entityType = '',
    String entityId = '',
    bool private = true,
  }) async {
    final result = await uploadFileResult(
      filePath,
      filename: filename,
      fileBytes: fileBytes,
      mimeType: mimeType,
      folder: folder,
      entityType: entityType,
      entityId: entityId,
      private: private,
    );
    return result['url']?.toString() ?? '';
  }

  Future<Map<String, dynamic>> uploadFileResult(
    String filePath, {
    required String filename,
    Uint8List? fileBytes,
    String? mimeType,
    String folder = 'uploads',
    String entityType = '',
    String entityId = '',
    bool private = true,
  }) async {
    var uploadFilename = filename;
    var uploadMimeType = mimeType;
    var uploadBytes = fileBytes;
    try {
      if (ImageUploadOptimizer.isImage(filename, mimeType)) {
        final optimized = uploadBytes != null
            ? ImageUploadOptimizer.fromBytes(
                uploadBytes,
                filename: filename,
                mimeType: mimeType,
                preset: ImageUploadPreset.content,
              )
            : await ImageUploadOptimizer.fromPath(
                filePath,
                filename: filename,
                mimeType: mimeType,
                preset: ImageUploadPreset.content,
              );
        uploadFilename = optimized.filename;
        uploadMimeType = optimized.mimeType;
        uploadBytes = optimized.bytes;
      }
      final formData = FormData.fromMap({
        'folder': folder,
        'entity_type': entityType,
        'entity_id': entityId,
        'private': private,
        'file': await _multipartUpload(
          filePath: filePath,
          fileBytes: uploadBytes,
          filename: uploadFilename,
          contentType: _resolveMediaType(uploadMimeType, uploadFilename),
        ),
      });
      final response = await _dio.post('/uploads', data: formData);
      final data = _asMap(response.data);
      final nested = _asMap(data['data']);
      final url = _firstNonEmpty([data['url'], nested['url']]);
      if (url.isNotEmpty) {
        return {
          'url': url,
          'storage_ref': _firstNonEmpty([
            nested['path'],
            nested['storage_ref'],
            data['path'],
          ]),
        };
      }
      throw ServerException(message: data['error'] ?? 'Upload failed');
    } on DioException catch (e) {
      final sync = offlineSync;
      if (sync != null && OfflineSyncEngine.isTransportFailure(e)) {
        final queued = await sync.enqueueFileUpload(
          path: '/uploads',
          fields: {
            'folder': folder,
            'entity_type': entityType,
            'entity_id': entityId,
            'private': private,
          },
          fieldName: 'file',
          fileName: uploadFilename,
          mimeType: uploadMimeType,
          filePath: filePath,
          fileBytes: uploadBytes,
          idempotencyKey: e.requestOptions.headers['Idempotency-Key']
              ?.toString(),
        );
        if (queued != null) {
          return {'url': queued.placeholder, 'storage_ref': queued.placeholder};
        }
      }
      throw _handleError(e);
    }
  }
}

DioMediaType? _resolveMediaType(String? mimeType, String filename) {
  final mime = mimeType?.trim() ?? '';
  if (mime.isNotEmpty) {
    final parts = mime.split('/');
    if (parts.length == 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return DioMediaType(parts[0], parts[1]);
    }
  }
  switch (filename.split('.').last.toLowerCase()) {
    case 'mp4':
      return DioMediaType('video', 'mp4');
    case 'mov':
      return DioMediaType('video', 'quicktime');
    case 'm4v':
      return DioMediaType('video', 'x-m4v');
    case 'webm':
      return DioMediaType('video', 'webm');
    case 'jpg':
    case 'jpeg':
      return DioMediaType('image', 'jpeg');
    case 'png':
      return DioMediaType('image', 'png');
    case 'webp':
      return DioMediaType('image', 'webp');
    case 'gif':
      return DioMediaType('image', 'gif');
    case 'heic':
      return DioMediaType('image', 'heic');
    case 'pdf':
      return DioMediaType('application', 'pdf');
    default:
      return null;
  }
}
