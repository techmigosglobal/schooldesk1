part of '../backend_api_client.dart';

extension BackendFeesApi on BackendApiClient {
  // ─── Fees ───────────────────────────────────────────────────────────────────

  Future<List<FeeInvoiceModel>> getStudentFees(String studentId) async {
    try {
      final response = await _dio.get('/students/$studentId/fees');
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return (data['data'] as List)
            .map((e) => FeeInvoiceModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      throw ServerException(message: data['error'] ?? 'Failed to get fees');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

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

  Future<List<Map<String, dynamic>>> getFeeStructures({
    String? academicYearId,
    String? gradeId,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (academicYearId != null) {
        queryParams['academic_year_id'] = academicYearId;
      }
      if (gradeId != null) {
        queryParams['grade_id'] = gradeId;
      }
      final response = await _dio.get(
        '/fees/structures',
        queryParameters: queryParams,
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return _asListMap(data['data']);
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to get fee structures',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<Map<String, dynamic>>> getInvoices({
    String? studentId,
    String? status,
    int page = 1,
    int pageSize = 100,
  }) async {
    return (await getInvoicesPage(
      studentId: studentId,
      status: status,
      page: page,
      pageSize: pageSize,
    )).data;
  }

  Future<PaginatedList<Map<String, dynamic>>> getInvoicesPage({
    String? studentId,
    String? status,
    int page = 1,
    int pageSize = 100,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'page_size': pageSize,
      };
      if (studentId != null) queryParams['student_id'] = studentId;
      if (status != null) queryParams['status'] = status;
      final response = await _dio.get(
        '/fees/invoices',
        queryParameters: queryParams,
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return PaginatedList<Map<String, dynamic>>(
          data: _asListMap(data['data']),
          total: _asInt(data['total']),
          page: _asInt(data['page'], fallback: page),
          pageSize: _asInt(data['page_size'], fallback: pageSize),
        );
      }
      throw ServerException(message: data['error'] ?? 'Failed to get invoices');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }
}
