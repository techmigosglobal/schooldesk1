// lib/features/finance/data/models/payment_models.dart

import 'package:freezed_annotation/freezed_annotation.dart';

part 'payment_models.freezed.dart';
part 'payment_models.g.dart';

@freezed
class StudentInfo with _$StudentInfo {
  const factory StudentInfo({
    required String studentId,
    required String name,
    required String className,
    required String sectionName,
    required String rollNo,
  }) = _StudentInfo;

  factory StudentInfo.fromJson(Map<String, dynamic> json) =>
      _$StudentInfoFromJson(json);
}

@freezed
class FeeInvoice with _$FeeInvoice {
  const factory FeeInvoice({
    required String invoiceId,
    required String title,
    required double payableAmount,
    required double paidAmount,
    required double dueAmount,
    required DateTime dueDate,
    required String status,
  }) = _FeeInvoice;

  factory FeeInvoice.fromJson(Map<String, dynamic> json) =>
      _$FeeInvoiceFromJson(json);
}

@freezed
class FeeSummary with _$FeeSummary {
  const factory FeeSummary({
    required String studentId,
    required String studentName,
    required double totalDue,
    required double totalPaid,
    required String currency,
    required List<FeeInvoice> invoices,
  }) = _FeeSummary;

  factory FeeSummary.fromJson(Map<String, dynamic> json) =>
      _$FeeSummaryFromJson(json);
}

@freezed
class CreatePaymentOrderRequest with _$CreatePaymentOrderRequest {
  const factory CreatePaymentOrderRequest({
    required String studentId,
    required List<String> invoiceIds,
  }) = _CreatePaymentOrderRequest;

  factory CreatePaymentOrderRequest.fromJson(Map<String, dynamic> json) =>
      _$CreatePaymentOrderRequestFromJson(json);
}

@freezed
class Prefill with _$Prefill {
  const factory Prefill({
    required String name,
    required String email,
    required String contact,
  }) = _Prefill;

  factory Prefill.fromJson(Map<String, dynamic> json) =>
      _$PrefillFromJson(json);
}

@freezed
class CreatePaymentOrderResponse with _$CreatePaymentOrderResponse {
  const factory CreatePaymentOrderResponse({
    required String keyId,
    required String razorpayOrderId,
    required String paymentOrderId,
    required int amount,
    required double displayAmount,
    required String currency,
    required String studentName,
    required String description,
    required Prefill prefill,
  }) = _CreatePaymentOrderResponse;

  factory CreatePaymentOrderResponse.fromJson(Map<String, dynamic> json) =>
      _$CreatePaymentOrderResponseFromJson(json);
}

@freezed
class VerifyPaymentRequest with _$VerifyPaymentRequest {
  const factory VerifyPaymentRequest({
    required String paymentOrderId,
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) = _VerifyPaymentRequest;

  factory VerifyPaymentRequest.fromJson(Map<String, dynamic> json) =>
      _$VerifyPaymentRequestFromJson(json);
}

@freezed
class ReceiptInfo with _$ReceiptInfo {
  const factory ReceiptInfo({
    required String receiptId,
    required String receiptNo,
    required double amount,
    required DateTime paidAt,
  }) = _ReceiptInfo;

  factory ReceiptInfo.fromJson(Map<String, dynamic> json) =>
      _$ReceiptInfoFromJson(json);
}

@freezed
class VerifyPaymentResponse with _$VerifyPaymentResponse {
  const factory VerifyPaymentResponse({
    required String status,
    required String message,
    required ReceiptInfo receipt,
  }) = _VerifyPaymentResponse;

  factory VerifyPaymentResponse.fromJson(Map<String, dynamic> json) =>
      _$VerifyPaymentResponseFromJson(json);
}

@freezed
class PaymentHistory with _$PaymentHistory {
  const factory PaymentHistory({
    required String receiptId,
    required String receiptNo,
    required String studentName,
    required double amount,
    required String paymentMode,
    required DateTime paidAt,
    required String status,
  }) = _PaymentHistory;

  factory PaymentHistory.fromJson(Map<String, dynamic> json) =>
      _$PaymentHistoryFromJson(json);
}

@freezed
class PaymentHistoryResponse with _$PaymentHistoryResponse {
  const factory PaymentHistoryResponse({
    required List<PaymentHistory> payments,
    required PaginationInfo pagination,
  }) = _PaymentHistoryResponse;

  factory PaymentHistoryResponse.fromJson(Map<String, dynamic> json) =>
      _$PaymentHistoryResponseFromJson(json);
}

@freezed
class PaginationInfo with _$PaginationInfo {
  const factory PaginationInfo({
    required int total,
    required int page,
    required int pageSize,
    required int totalPages,
  }) = _PaginationInfo;

  factory PaginationInfo.fromJson(Map<String, dynamic> json) =>
      _$PaginationInfoFromJson(json);
}

@freezed
class ReceiptDetails with _$ReceiptDetails {
  const factory ReceiptDetails({
    required String receiptNo,
    required String studentName,
    required String parentName,
    required double amount,
    required String paymentMode,
    required DateTime paidAt,
  }) = _ReceiptDetails;

  factory ReceiptDetails.fromJson(Map<String, dynamic> json) =>
      _$ReceiptDetailsFromJson(json);
}

@freezed
class ApiResponse<T> with _$ApiResponse<T> {
  const factory ApiResponse({
    required bool success,
    required T data,
    String? error,
  }) = _ApiResponse<T>;

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Object?) fromJsonT,
  ) =>
      _$ApiResponseFromJson(json, fromJsonT);
}
