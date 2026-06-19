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

  Future<Map<String, dynamic>> getPaymentConfig() async {
    try {
      final response = await _dio.get('/fees/payment-config');
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

  Future<List<Map<String, dynamic>>> getFeeCategories() async {
    try {
      final response = await _dio.get('/fees/categories');
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return _asListMap(data['data']);
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to get fee categories',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> createFeeCategory({
    required String categoryName,
    required String frequency,
    bool isRefundable = false,
  }) async {
    try {
      final response = await _dio.post(
        '/fees/categories',
        data: {
          'category_name': categoryName.trim(),
          'frequency': frequency.trim(),
          'is_refundable': isRefundable,
        },
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return Map<String, dynamic>.from(data['data'] as Map? ?? {});
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to create fee category',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> createFeeStructure({
    required String academicYearId,
    required String gradeId,
    required String feeCategoryId,
    required double amount,
    int dueDay = 10,
    double lateFinePerDay = 0,
    int installmentCount = 3,
  }) async {
    try {
      final response = await _dio.post(
        '/fees/structures',
        data: {
          'academic_year_id': academicYearId.trim(),
          'grade_id': gradeId.trim(),
          'fee_category_id': feeCategoryId.trim(),
          'amount': amount,
          'due_day': dueDay,
          'late_fine_per_day': lateFinePerDay,
          'installment_count': installmentCount,
        },
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return Map<String, dynamic>.from(data['data'] as Map? ?? {});
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to create fee structure',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> updateFeeStructure(
    String structureId, {
    String? academicYearId,
    String? gradeId,
    String? feeCategoryId,
    double? amount,
    int? dueDay,
    double? lateFinePerDay,
    int? installmentCount,
  }) async {
    try {
      final payload = <String, dynamic>{};
      if (academicYearId != null) payload['academic_year_id'] = academicYearId;
      if (gradeId != null) payload['grade_id'] = gradeId;
      if (feeCategoryId != null) payload['fee_category_id'] = feeCategoryId;
      if (amount != null) payload['amount'] = amount;
      if (dueDay != null) payload['due_day'] = dueDay;
      if (lateFinePerDay != null) {
        payload['late_fine_per_day'] = lateFinePerDay;
      }
      if (installmentCount != null) {
        payload['installment_count'] = installmentCount;
      }
      final response = await _dio.put(
        '/fees/structures/${structureId.trim()}',
        data: payload,
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return Map<String, dynamic>.from(data['data'] as Map? ?? {});
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to update fee structure',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> deleteFeeStructure(String structureId) async {
    try {
      final response = await _dio.delete(
        '/fees/structures/${structureId.trim()}',
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) return;
      throw ServerException(
        message: data['error'] ?? 'Failed to delete fee structure',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<Map<String, dynamic>>> getInvoices({
    String? studentId,
    String? status,
    String? academicYearId,
    String? gradeId,
    String? sectionId,
    String? termId,
    int page = 1,
    int pageSize = 100,
  }) async {
    return (await getInvoicesPage(
      studentId: studentId,
      status: status,
      academicYearId: academicYearId,
      gradeId: gradeId,
      sectionId: sectionId,
      termId: termId,
      page: page,
      pageSize: pageSize,
    )).data;
  }

  Future<PaginatedList<Map<String, dynamic>>> getInvoicesPage({
    String? studentId,
    String? status,
    String? academicYearId,
    String? gradeId,
    String? sectionId,
    String? termId,
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
      if (academicYearId != null) {
        queryParams['academic_year_id'] = academicYearId;
      }
      if (gradeId != null) queryParams['grade_id'] = gradeId;
      if (sectionId != null) queryParams['section_id'] = sectionId;
      if (termId != null) queryParams['term_id'] = termId;
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

  Future<Map<String, dynamic>> generateFeeInvoices({
    required String academicYearId,
    required String gradeId,
    String sectionId = '',
    String studentId = '',
    String invoiceDate = '',
    required String dueDate,
    String invoiceLabel = '',
    String termId = '',
    bool includeOneTime = false,
    bool includeYearly = false,
    int installmentCount = 0,
  }) async {
    try {
      final response = await _dio.post(
        '/fees/invoices/generate',
        data: {
          'academic_year_id': academicYearId.trim(),
          'grade_id': gradeId.trim(),
          'section_id': sectionId.trim(),
          'student_id': studentId.trim(),
          if (invoiceDate.trim().isNotEmpty) 'invoice_date': invoiceDate.trim(),
          'due_date': dueDate.trim(),
          'invoice_label': invoiceLabel.trim(),
          'term_id': termId.trim(),
          'include_one_time': includeOneTime,
          'include_yearly': includeYearly,
          if (installmentCount > 0) 'installment_count': installmentCount,
        },
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return Map<String, dynamic>.from(data['data'] as Map? ?? {});
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to generate fee invoices',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }
}
