part of '../backend_api_client.dart';

extension BackendFeesApi on BackendApiClient {
  // ─── Fees ───────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getFeeReceiptPayload(String receiptId) async {
    try {
      final response = await _get('/fees/receipts/${receiptId.trim()}');
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return Map<String, dynamic>.from(data['data'] as Map? ?? {});
      }
      throw ServerException(message: data['error'] ?? 'Failed to load receipt');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<FeeInvoiceModel>> getStudentFees(String studentId) async {
    try {
      final response = await _get('/students/$studentId/fees');
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
    int page = 1,
    int pageSize = 20,
  }) async {
    return (await getFeeStructuresPage(
      academicYearId: academicYearId,
      gradeId: gradeId,
      sectionId: sectionId,
      page: page,
      pageSize: pageSize,
    )).data;
  }

  Future<PaginatedList<Map<String, dynamic>>> getFeeStructuresPage({
    String? academicYearId,
    String? gradeId,
    String? sectionId,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'page_size': pageSize,
      };
      if (academicYearId != null) {
        queryParams['academic_year_id'] = academicYearId;
      }
      if (gradeId != null) {
        queryParams['grade_id'] = gradeId;
      }
      if (sectionId != null) {
        queryParams['section_id'] = sectionId;
      }
      final response = await _get(
        '/fees/structures',
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
      throw ServerException(
        message: data['error'] ?? 'Failed to get fee structures',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<Map<String, dynamic>>> getFeeCategories() async {
    try {
      final response = await _get('/fees/categories');
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

  Future<PaginatedList<Map<String, dynamic>>> getFeeConcessionsPage({
    String? studentId,
    String? invoiceId,
    String? status,
    String? search,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final response = await _get(
        '/fees/concessions',
        queryParameters: {
          'page': page,
          'page_size': pageSize,
          if (studentId != null && studentId.trim().isNotEmpty)
            'student_id': studentId.trim(),
          if (invoiceId != null && invoiceId.trim().isNotEmpty)
            'invoice_id': invoiceId.trim(),
          if (status != null && status.trim().isNotEmpty)
            'status': status.trim(),
          if (search != null && search.trim().isNotEmpty) 'q': search.trim(),
        },
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
      throw ServerException(
        message: data['error'] ?? 'Failed to load concessions',
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
    String frequency = 'term',
    String feeType = '',
    String billingMode = '',
    int priority = 0,
    bool isActive = true,
    int dueDay = 10,
    double lateFinePerDay = 0,
    String effectiveFrom = '',
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
          'frequency': frequency.trim().isEmpty ? 'term' : frequency.trim(),
          if (feeType.trim().isNotEmpty) 'fee_type': feeType.trim(),
          if (billingMode.trim().isNotEmpty) 'billing_mode': billingMode.trim(),
          if (priority > 0) 'priority': priority,
          'is_active': isActive,
          'due_day': dueDay,
          'late_fine_per_day': lateFinePerDay,
          if (effectiveFrom.trim().isNotEmpty)
            'effective_from': effectiveFrom.trim(),
          'replace_existing': replaceExisting,
        },
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        await _deleteCachedPaths([
          r'/fees/structures',
          r'/fees/invoices',
          r'/students',
          r'/principal/classes',
          r'/dashboard/',
        ]);
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
    String? frequency,
    String? feeType,
    String? billingMode,
    int? priority,
    bool? isActive,
    int? dueDay,
    double? lateFinePerDay,
    String? effectiveFrom,
  }) async {
    try {
      final payload = <String, dynamic>{};
      if (academicYearId != null) payload['academic_year_id'] = academicYearId;
      if (gradeId != null) payload['grade_id'] = gradeId;
      if (sectionId != null) payload['section_id'] = sectionId;
      if (feeCategoryId != null) payload['fee_category_id'] = feeCategoryId;
      if (amount != null) payload['amount'] = amount;
      if (frequency != null) payload['frequency'] = frequency.trim();
      if (feeType != null) payload['fee_type'] = feeType;
      if (billingMode != null) payload['billing_mode'] = billingMode;
      if (priority != null) payload['priority'] = priority;
      if (isActive != null) payload['is_active'] = isActive;
      if (dueDay != null) payload['due_day'] = dueDay;
      if (lateFinePerDay != null) {
        payload['late_fine_per_day'] = lateFinePerDay;
      }
      if (effectiveFrom != null) {
        payload['effective_from'] = effectiveFrom;
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
    bool removePending = true,
  }) async {
    try {
      final response = await _dio.delete(
        '/fees/structures/${structureId.trim()}',
        queryParameters: {'remove_pending': removePending},
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        // Invalidate fee-related cache so _loadData() sees fresh totals.
        await _deleteCachedPaths([
          r'/fees/structures',
          r'/fees/invoices',
          r'/fees/concessions',
          r'/dashboard/',
        ]);
        return;
      }
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
        await _deleteCachedPaths([
          r'/fees/structures',
          r'/fees/invoices',
          r'/students',
          r'/principal/classes',
          r'/dashboard/',
        ]);
        return Map<String, dynamic>.from(data['data'] as Map? ?? {});
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to apply invoice sync',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> applyLateFineAdjustments() async {
    try {
      final response = await _dio.post('/fees/invoices/late-fines/apply');
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return Map<String, dynamic>.from(data['data'] as Map? ?? {});
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to apply late fine adjustments',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<Map<String, dynamic>>> getInvoices({
    String? studentId,
    String? search,
    String? status,
    String? academicYearId,
    String? gradeId,
    String? sectionId,
    String? termId,
    bool due = false,
    bool overdue = false,
    bool outstanding = false,
    int? refreshNonce,
    int page = 1,
    int pageSize = 20,
  }) async {
    return (await getInvoicesPage(
      studentId: studentId,
      search: search,
      status: status,
      academicYearId: academicYearId,
      gradeId: gradeId,
      sectionId: sectionId,
      termId: termId,
      due: due,
      overdue: overdue,
      outstanding: outstanding,
      refreshNonce: refreshNonce,
      page: page,
      pageSize: pageSize,
    )).data;
  }

  Future<PaginatedList<Map<String, dynamic>>> getInvoicesPage({
    String? studentId,
    String? search,
    String? status,
    String? academicYearId,
    String? gradeId,
    String? sectionId,
    String? termId,
    bool due = false,
    bool overdue = false,
    bool outstanding = false,
    int? refreshNonce,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'page_size': pageSize,
      };
      if (studentId != null) queryParams['student_id'] = studentId;
      if (search != null && search.trim().isNotEmpty) {
        queryParams['search'] = search.trim();
      }
      if (status != null) queryParams['status'] = status;
      if (academicYearId != null) {
        queryParams['academic_year_id'] = academicYearId;
      }
      if (gradeId != null) queryParams['grade_id'] = gradeId;
      if (sectionId != null) queryParams['section_id'] = sectionId;
      if (termId != null) queryParams['term_id'] = termId;
      if (due) queryParams['due'] = 'true';
      if (overdue) queryParams['overdue'] = 'true';
      if (outstanding) queryParams['outstanding'] = 'true';
      if (refreshNonce != null) queryParams['refresh_nonce'] = refreshNonce;
      final response = await _get(
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
      final response = await _get('/fees/invoices/${invoiceId.trim()}');
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

  Future<Map<String, dynamic>> getFeeDashboardSummary({
    String? academicYearId,
  }) async {
    try {
      final response = await _get(
        '/fees/summary',
        queryParameters: {
          if (academicYearId != null && academicYearId.trim().isNotEmpty)
            'academic_year_id': academicYearId.trim(),
        },
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) return _asMap(data['data']);
      throw ServerException(
        message: data['error'] ?? 'Failed to load fee dashboard summary',
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
    bool includeOneTime = false,
    bool includeYearly = false,
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
          'include_one_time': includeOneTime,
          'include_yearly': includeYearly,
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
