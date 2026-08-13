part of '../backend_api_client.dart';

extension IssuesApi on BackendApiClient {
  Future<List<Map<String, dynamic>>> getIssues({String? status}) async {
    try {
      final response = await _get(
        '/issues',
        queryParameters: {
          if (status != null && status.isNotEmpty) 'status': status,
        },
      );
      final data = _asMap(response.data);
      final payload = _asMap(data['data']);
      if (data['success'] == true) return _asListMap(payload['data']);
      throw ServerException(
        message: data['message'] ?? data['error'] ?? 'Unable to load issues',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> createIssue(Map<String, dynamic> body) async {
    try {
      final response = await _dio.post('/issues', data: body);
      final data = _asMap(response.data);
      if (data['success'] == true) return _asMap(data['data']);
      throw ServerException(
        message: data['message'] ?? data['error'] ?? 'Unable to raise issue',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> createIssueWithAttachments(
    Map<String, dynamic> body,
    List<Map<String, dynamic>> files,
  ) async {
    try {
      final attachments = <MultipartFile>[];
      for (final file in files) {
        final name = '${file['name'] ?? 'attachment'}';
        final bytes = file['bytes'];
        final path = '${file['path'] ?? ''}'.trim();
        final mimeType = '${file['mime_type'] ?? ''}'.trim();
        if (bytes is Uint8List) {
          attachments.add(
            MultipartFile.fromBytes(
              bytes,
              filename: name,
              contentType: _resolveMediaType(mimeType, name),
            ),
          );
        } else if (path.isNotEmpty) {
          attachments.add(
            await MultipartFile.fromFile(
              path,
              filename: name,
              contentType: _resolveMediaType(mimeType, name),
            ),
          );
        } else {
          throw const ServerException(
            message: 'Attachment data is unavailable. Please choose it again.',
          );
        }
      }
      final response = await _dio.post(
        '/issues/with-attachments',
        data: FormData.fromMap({...body, 'files': attachments}),
      );
      final data = _asMap(response.data);
      if (data['success'] == true) return _asMap(data['data']);
      throw ServerException(
        message: data['message'] ?? data['error'] ?? 'Unable to raise issue',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> uploadIssueAttachment(
    String issueId,
    String path,
    String filename, {
    Uint8List? fileBytes,
    String? mimeType,
  }) async {
    try {
      final response = await _dio.post(
        '/issues/$issueId/attachments',
        data: FormData.fromMap({
          'file': await _multipartUpload(
            filePath: path,
            fileBytes: fileBytes,
            filename: filename,
            contentType: _resolveMediaType(mimeType, filename),
          ),
        }),
      );
      final data = _asMap(response.data);
      if (data['success'] == true) return _asMap(data['data']);
      throw ServerException(
        message:
            data['message'] ?? data['error'] ?? 'Unable to upload attachment',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<String> issueAttachmentUrl(String issueId, String attachmentId) async {
    try {
      final response = await _get(
        '/issues/$issueId/attachments/$attachmentId/url',
      );
      final data = _asMap(response.data);
      final url = '${_asMap(data['data'])['url'] ?? ''}'.trim();
      if (data['success'] == true && url.isNotEmpty) return url;
      throw ServerException(
        message: data['message'] ?? data['error'] ?? 'Attachment unavailable',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> updateIssue(
    String issueId, {
    required String status,
    String resolutionNote = '',
  }) async {
    try {
      final response = await _dio.patch(
        '/issues/$issueId',
        data: {
          'status': status,
          if (resolutionNote.isNotEmpty) 'resolution_note': resolutionNote,
        },
      );
      final data = _asMap(response.data);
      if (data['success'] == true) return _asMap(data['data']);
      throw ServerException(
        message: data['message'] ?? data['error'] ?? 'Unable to update issue',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }
}
