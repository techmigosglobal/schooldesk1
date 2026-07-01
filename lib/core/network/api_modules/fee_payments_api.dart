part of '../backend_api_client.dart';

extension BackendFeePaymentsApi on BackendApiClient {
  Future<void> recordPayment(PaymentRequest request) async {
    try {
      final response = await _dio.post(
        '/fees/payments',
        data: request.toJson(),
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] != true) {
        throw ServerException(
          message: data['error'] ?? 'Failed to record payment',
        );
      }
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> submitParentPaymentRequest(
    PaymentRequest request, {
    String? remarks,
  }) async {
    try {
      final payload = request.toParentPaymentRequestJson();
      if (remarks != null && remarks.trim().isNotEmpty) {
        payload['remarks'] = remarks.trim();
      }
      final response = await _dio.post('/fees/payment-requests', data: payload);
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return Map<String, dynamic>.from(data['data'] as Map);
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to submit payment request',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<Map<String, dynamic>>> getParentStudentFees(
    String studentId, {
    int? refreshNonce,
  }) async {
    try {
      final response = await _dio.get(
        '/parent/students/${studentId.trim()}/fees',
        queryParameters: {
          if (refreshNonce != null) 'refresh_nonce': refreshNonce,
        },
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return _asListMap(data['data']);
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to load student fees',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> createFeePaymentIntent({
    required String invoiceId,
    required String paymentMethod,
    int selectedMonths = 0,
    int selectedTerms = 0,
    String remarks = '',
  }) async {
    try {
      final response = await _dio.post(
        '/fees/payments/intent',
        data: {
          'invoice_id': invoiceId.trim(),
          'payment_method': paymentMethod.trim(),
          if (selectedMonths > 0) 'selected_months': selectedMonths,
          if (selectedTerms > 0) 'selected_terms': selectedTerms,
          if (remarks.trim().isNotEmpty) 'remarks': remarks.trim(),
        },
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return Map<String, dynamic>.from(data['data'] as Map? ?? {});
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to create payment intent',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> submitFeePaymentProof({
    String paymentRequestId = '',
    String requestReference = '',
    required String studentFeeId,
    required double amount,
    required String paymentMethod,
    required String transactionRef,
    required String screenshotPath,
    required String screenshotName,
    int selectedMonths = 0,
    int selectedTerms = 0,
    String remarks = '',
  }) async {
    try {
      final response = await _dio.post(
        '/fees/payments/submit',
        data: FormData.fromMap({
          'student_fee_id': studentFeeId.trim(),
          if (paymentRequestId.trim().isNotEmpty)
            'payment_request_id': paymentRequestId.trim(),
          if (requestReference.trim().isNotEmpty)
            'request_reference': requestReference.trim(),
          'amount': amount.toStringAsFixed(2),
          'payment_method': paymentMethod.trim(),
          'transaction_ref': transactionRef.trim(),
          if (selectedMonths > 0) 'selected_months': selectedMonths,
          if (selectedTerms > 0) 'selected_terms': selectedTerms,
          if (remarks.trim().isNotEmpty) 'remarks': remarks.trim(),
          'screenshot': await MultipartFile.fromFile(
            screenshotPath,
            filename: screenshotName,
          ),
        }),
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return Map<String, dynamic>.from(data['data'] as Map? ?? {});
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to submit payment proof',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> resubmitFeePaymentProof({
    required String id,
    required String transactionRef,
    required String screenshotPath,
    required String screenshotName,
    String remarks = '',
  }) async {
    try {
      final response = await _dio.patch(
        '/fees/payments/$id/resubmit',
        data: FormData.fromMap({
          'transaction_ref': transactionRef.trim(),
          if (remarks.trim().isNotEmpty) 'remarks': remarks.trim(),
          'screenshot': await MultipartFile.fromFile(
            screenshotPath,
            filename: screenshotName,
          ),
        }),
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return Map<String, dynamic>.from(data['data'] as Map? ?? {});
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to resubmit payment proof',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getPaymentConfig({
    String invoiceId = '',
    int? refreshNonce,
  }) async {
    try {
      final response = await _dio.get(
        '/fees/payment-config',
        queryParameters: {
          if (invoiceId.trim().isNotEmpty) 'invoice_id': invoiceId.trim(),
          if (refreshNonce != null) 'refresh_nonce': refreshNonce,
        },
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return Map<String, dynamic>.from(data['data'] as Map);
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to load payment configuration',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<Map<String, dynamic>>> getParentPaymentRequests({
    String? studentId,
    String? invoiceId,
    String? status,
    int page = 1,
    int pageSize = 100,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'page_size': pageSize,
      };
      if (studentId != null && studentId.trim().isNotEmpty) {
        queryParams['student_id'] = studentId.trim();
      }
      if (invoiceId != null && invoiceId.trim().isNotEmpty) {
        queryParams['invoice_id'] = invoiceId.trim();
      }
      if (status != null && status.trim().isNotEmpty) {
        queryParams['status'] = status.trim();
      }
      final response = await _dio.get(
        '/fees/payment-requests',
        queryParameters: queryParams,
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return _asListMap(data['data']);
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to load payment requests',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> decideParentPaymentRequest(
    String id, {
    required String status,
    String adminRemarks = '',
  }) async {
    try {
      final response = await _dio.put(
        '/fees/payment-requests/$id/decision',
        data: {
          'status': status,
          if (adminRemarks.trim().isNotEmpty)
            'admin_remarks': adminRemarks.trim(),
        },
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return Map<String, dynamic>.from(data['data'] as Map);
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to update payment request',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> updatePaymentConfig({
    required String upiId,
    required String payeeName,
    String merchantCode = '',
    String qrNote = '',
    String qrImageUrl = '',
    bool? upiEnabled,
  }) async {
    try {
      final response = await _dio.put(
        '/fees/payment-config',
        data: {
          'upi_id': upiId.trim(),
          'payee_name': payeeName.trim(),
          'merchant_code': merchantCode.trim(),
          'qr_note': qrNote.trim(),
          'qr_image_url': qrImageUrl.trim(),
          'upi_enabled':
              upiEnabled ??
              (upiId.trim().isNotEmpty || qrImageUrl.trim().isNotEmpty),
        },
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return Map<String, dynamic>.from(data['data'] as Map? ?? {});
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to update payment configuration',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> uploadPaymentQr({
    required String path,
    required String fileName,
  }) async {
    try {
      final response = await _dio.post(
        '/fees/payment-config/qr',
        data: FormData.fromMap({
          'file': await MultipartFile.fromFile(path, filename: fileName),
        }),
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return Map<String, dynamic>.from(data['data'] as Map? ?? {});
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to upload payment QR',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<Map<String, dynamic>>> getPaymentConfigs() async {
    try {
      final response = await _dio.get('/fees/payment-configs');
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) return _asListMap(data['data']);
      throw ServerException(
        message: data['error'] ?? 'Failed to load payment configurations',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> createPaymentConfig({
    String scope = 'school',
    String gradeId = '',
    String sectionId = '',
    required String upiId,
    required String payeeName,
    String merchantCode = '',
    String qrNote = '',
    String qrImageUrl = '',
    bool? upiEnabled,
  }) async {
    try {
      final response = await _dio.post(
        '/fees/payment-configs',
        data: {
          'scope': scope.trim(),
          if (gradeId.trim().isNotEmpty) 'grade_id': gradeId.trim(),
          if (sectionId.trim().isNotEmpty) 'section_id': sectionId.trim(),
          'upi_id': upiId.trim(),
          'payee_name': payeeName.trim(),
          'merchant_code': merchantCode.trim(),
          'qr_note': qrNote.trim(),
          'qr_image_url': qrImageUrl.trim(),
          'upi_enabled':
              upiEnabled ??
              (upiId.trim().isNotEmpty || qrImageUrl.trim().isNotEmpty),
        },
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return Map<String, dynamic>.from(data['data'] as Map? ?? {});
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to create payment configuration',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> updateScopedPaymentConfig(
    String id, {
    String scope = 'school',
    String gradeId = '',
    String sectionId = '',
    required String upiId,
    required String payeeName,
    String merchantCode = '',
    String qrNote = '',
    String qrImageUrl = '',
    bool? upiEnabled,
  }) async {
    try {
      final response = await _dio.put(
        '/fees/payment-configs/${id.trim()}',
        data: {
          'scope': scope.trim(),
          if (gradeId.trim().isNotEmpty) 'grade_id': gradeId.trim(),
          if (sectionId.trim().isNotEmpty) 'section_id': sectionId.trim(),
          'upi_id': upiId.trim(),
          'payee_name': payeeName.trim(),
          'merchant_code': merchantCode.trim(),
          'qr_note': qrNote.trim(),
          'qr_image_url': qrImageUrl.trim(),
          'upi_enabled':
              upiEnabled ??
              (upiId.trim().isNotEmpty || qrImageUrl.trim().isNotEmpty),
        },
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return Map<String, dynamic>.from(data['data'] as Map? ?? {});
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to update payment configuration',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> uploadScopedPaymentQr({
    required String id,
    required String path,
    required String fileName,
  }) async {
    try {
      final response = await _dio.post(
        '/fees/payment-configs/${id.trim()}/qr',
        data: FormData.fromMap({
          'file': await MultipartFile.fromFile(path, filename: fileName),
        }),
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return Map<String, dynamic>.from(data['data'] as Map? ?? {});
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to upload payment QR',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }
}
