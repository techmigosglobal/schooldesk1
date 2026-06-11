// lib/features/finance/presentation/providers/parent_fees_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:schooldesk1/core/network/api_modules/http_client.dart';
import '../../data/datasources/parent_fees_remote_datasource.dart';
import '../../data/models/payment_models.dart';
import '../../data/repositories/parent_fees_repository.dart';

// Datasource Provider
final parentFeesRemoteDataSourceProvider =
    Provider<ParentFeesRemoteDataSource>((ref) {
  final httpClient = ref.watch(httpClientProvider);
  return ParentFeesRemoteDataSourceImpl(httpClient: httpClient);
});

// Repository Provider
final parentFeesRepositoryProvider =
    Provider<ParentFeesRepository>((ref) {
  final datasource = ref.watch(parentFeesRemoteDataSourceProvider);
  return ParentFeesRepositoryImpl(remoteDataSource: datasource);
});

// Get My Students Provider
final getMyStudentsProvider =
    FutureProvider<List<StudentInfo>>((ref) async {
  final repository = ref.watch(parentFeesRepositoryProvider);
  final result = await repository.getMyStudents();
  return result.fold(
    (failure) => throw Exception(failure.message),
    (students) => students,
  );
});

// Selected Student Provider
final selectedStudentProvider = StateProvider<StudentInfo?>((ref) => null);

// Get Fee Summary Provider - depends on selected student
final getFeeSummaryProvider =
    FutureProvider<FeeSummary>((ref) async {
  final selectedStudent = ref.watch(selectedStudentProvider);
  final repository = ref.watch(parentFeesRepositoryProvider);

  if (selectedStudent == null) {
    throw Exception('No student selected');
  }

  final result = await repository.getStudentFeeSummary(selectedStudent.studentId);
  return result.fold(
    (failure) => throw Exception(failure.message),
    (summary) => summary,
  );
});

// Selected Invoices for Payment Provider
final selectedInvoicesProvider = StateProvider<Set<String>>((ref) => {});

// Payment Order Creation Provider
final createPaymentOrderProvider =
    FutureProvider.family<CreatePaymentOrderResponse, 
      (String studentId, List<String> invoiceIds)>((ref, params) async {
  final (studentId, invoiceIds) = params;
  final repository = ref.watch(parentFeesRepositoryProvider);
  
  final result = await repository.createPaymentOrder(studentId, invoiceIds);
  return result.fold(
    (failure) => throw Exception(failure.message),
    (response) => response,
  );
});

// Payment Verification Provider
final verifyPaymentProvider =
    FutureProvider.family<VerifyPaymentResponse, VerifyPaymentRequest>(
      (ref, request) async {
  final repository = ref.watch(parentFeesRepositoryProvider);
  
  final result = await repository.verifyPayment(request);
  return result.fold(
    (failure) => throw Exception(failure.message),
    (response) => response,
  );
});

// Payment History Provider
final getPaymentHistoryProvider = FutureProvider.family<
    PaymentHistoryResponse,
    ({int page, int pageSize})>((ref, params) async {
  final repository = ref.watch(parentFeesRepositoryProvider);
  
  final result = await repository.getPaymentHistory(
    page: params.page,
    pageSize: params.pageSize,
  );
  return result.fold(
    (failure) => throw Exception(failure.message),
    (history) => history,
  );
});

// Receipt Details Provider
final getReceiptProvider = FutureProvider.family<ReceiptDetails, String>(
  (ref, receiptId) async {
    final repository = ref.watch(parentFeesRepositoryProvider);
    
    final result = await repository.getReceipt(receiptId);
    return result.fold(
      (failure) => throw Exception(failure.message),
      (receipt) => receipt,
    );
  },
);

// Payment Processing State Provider
final paymentProcessingStateProvider = StateProvider<PaymentProcessingState>((ref) {
  return PaymentProcessingState.initial();
});

// Update Payment Processing State Provider
final updatePaymentProcessingStateProvider = StateNotifierProvider<
    PaymentProcessingStateNotifier,
    PaymentProcessingState>((ref) {
  return PaymentProcessingStateNotifier();
});

class PaymentProcessingStateNotifier extends StateNotifier<PaymentProcessingState> {
  PaymentProcessingStateNotifier() : super(PaymentProcessingState.initial());

  void setLoading(bool isLoading) {
    state = state.copyWith(isLoading: isLoading);
  }

  void setSuccess(VerifyPaymentResponse response) {
    state = state.copyWith(
      isLoading: false,
      isSuccess: true,
      verifyResponse: response,
    );
  }

  void setError(String message) {
    state = state.copyWith(
      isLoading: false,
      isSuccess: false,
      errorMessage: message,
    );
  }

  void reset() {
    state = PaymentProcessingState.initial();
  }
}

class PaymentProcessingState {
  final bool isLoading;
  final bool isSuccess;
  final String? errorMessage;
  final VerifyPaymentResponse? verifyResponse;

  PaymentProcessingState({
    required this.isLoading,
    required this.isSuccess,
    this.errorMessage,
    this.verifyResponse,
  });

  factory PaymentProcessingState.initial() {
    return PaymentProcessingState(
      isLoading: false,
      isSuccess: false,
      errorMessage: null,
      verifyResponse: null,
    );
  }

  PaymentProcessingState copyWith({
    bool? isLoading,
    bool? isSuccess,
    String? errorMessage,
    VerifyPaymentResponse? verifyResponse,
  }) {
    return PaymentProcessingState(
      isLoading: isLoading ?? this.isLoading,
      isSuccess: isSuccess ?? this.isSuccess,
      errorMessage: errorMessage ?? this.errorMessage,
      verifyResponse: verifyResponse ?? this.verifyResponse,
    );
  }
}
