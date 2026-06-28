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

  Future<List<Map<String, dynamic>>> getFeeStructures({
    String? academicYearId,
    String? gradeId,
    String? sectionId,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (academicYearId != null) {
        queryParams['academic_year_id'] = academicYearId;
      }
      if (gradeId != null) {
        queryParams['grade_id'] = gradeId;
      }
      if (sectionId != null) {
        queryParams['section_id'] = sectionId;
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
    String sectionId = '',
    required String feeCategoryId,
    required double amount,
    int dueDay = 10,
    double lateFinePerDay = 0,
    int installmentCount = 3,
    String installmentMethod = 'equal',
    String effectiveFrom = '',
    List<Map<String, dynamic>> installments = const [],
    bool replaceExisting = false,
  }) async {
    try {
      final response = await _dio.post(
        '/fees/structures',
        data: {
          'academic_year_id': academicYearId.trim(),
          'grade_id': gradeId.trim(),
          if (sectionId.trim().isNotEmpty) 'section_id': sectionId.trim(),
          'fee_category_id': feeCategoryId.trim(),
          'amount': amount,
          'due_day': dueDay,
          'late_fine_per_day': lateFinePerDay,
          'installment_count': installmentCount,
          'installment_method': installmentMethod.trim(),
          if (effectiveFrom.trim().isNotEmpty)
            'effective_from': effectiveFrom.trim(),
          if (installments.isNotEmpty) 'installments': installments,
          'replace_existing': replaceExisting,
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
    String? sectionId,
    String? feeCategoryId,
    double? amount,
    int? dueDay,
    double? lateFinePerDay,
    int? installmentCount,
    String? installmentMethod,
    String? effectiveFrom,
    List<Map<String, dynamic>>? installments,
  }) async {
    try {
      final payload = <String, dynamic>{};
      if (academicYearId != null) payload['academic_year_id'] = academicYearId;
      if (gradeId != null) payload['grade_id'] = gradeId;
      if (sectionId != null) payload['section_id'] = sectionId;
      if (feeCategoryId != null) payload['fee_category_id'] = feeCategoryId;
      if (amount != null) payload['amount'] = amount;
      if (dueDay != null) payload['due_day'] = dueDay;
      if (lateFinePerDay != null) {
        payload['late_fine_per_day'] = lateFinePerDay;
      }
      if (installmentCount != null) {
        payload['installment_count'] = installmentCount;
      }
      if (installmentMethod != null) {
        payload['installment_method'] = installmentMethod;
      }
      if (effectiveFrom != null) {
        payload['effective_from'] = effectiveFrom;
      }
      if (installments != null) {
        payload['installments'] = installments;
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

  Future<void> deleteFeeStructure(
    String structureId, {
    bool removePending = false,
  }) async {
    try {
      final response = await _dio.delete(
        '/fees/structures/${structureId.trim()}',
        queryParameters: {if (removePending) 'remove_pending': 'true'},
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

  Future<Map<String, dynamic>> rolloverFeeStructures({
    required String fromAcademicYearId,
    required String toAcademicYearId,
    bool overwrite = false,
  }) async {
    try {
      final response = await _dio.post(
        '/fees/structures/rollover',
        data: {
          'from_academic_year_id': fromAcademicYearId.trim(),
          'to_academic_year_id': toAcademicYearId.trim(),
          'overwrite': overwrite,
        },
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return Map<String, dynamic>.from(data['data'] as Map? ?? {});
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to rollover fee structures',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> previewFeeInvoiceSync(String structureId) async {
    try {
      final response = await _dio.post(
        '/fees/structures/${structureId.trim()}/invoice-sync/preview',
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return Map<String, dynamic>.from(data['data'] as Map? ?? {});
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to preview invoice sync',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> applyFeeInvoiceSync(
    String structureId, {
    bool includePartiallyPaid = false,
  }) async {
    try {
      final response = await _dio.post(
        '/fees/structures/${structureId.trim()}/invoice-sync/apply',
        data: {'include_partially_paid': includePartiallyPaid},
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return Map<String, dynamic>.from(data['data'] as Map? ?? {});
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to apply invoice sync',
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

  Future<Map<String, dynamic>> getInvoiceDetail(String invoiceId) async {
    try {
      final response = await _dio.get(
        '/fees/invoices/${invoiceId.trim()}',
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return Map<String, dynamic>.from(data['data'] as Map? ?? {});
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to get invoice detail',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> updateInvoice(
    String invoiceId, {
    String? dueDate,
    double? totalAmount,
    double? concessionAmount,
    String? concessionReason,
    double? fineAmount,
    String? status,
    String? notes,
  }) async {
    try {
      final payload = <String, dynamic>{};
      if (dueDate != null) payload['due_date'] = dueDate;
      if (totalAmount != null) payload['total_amount'] = totalAmount;
      if (concessionAmount != null) {
        payload['concession_amount'] = concessionAmount;
      }
      if (concessionReason != null) {
        payload['concession_reason'] = concessionReason;
      }
      if (fineAmount != null) payload['fine_amount'] = fineAmount;
      if (status != null) payload['status'] = status;
      if (notes != null) payload['notes'] = notes;
      final response = await _dio.put(
        '/fees/invoices/${invoiceId.trim()}',
        data: payload,
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return Map<String, dynamic>.from(data['data'] as Map? ?? {});
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to update invoice',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> updateInvoiceInstallment(
    String invoiceId, {
    String? dueDate,
    double? amount,
    String? status,
  }) async {
    return updateInvoice(
      invoiceId,
      dueDate: dueDate,
      totalAmount: amount,
      status: status,
    );
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
