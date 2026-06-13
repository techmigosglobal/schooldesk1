import 'package:freezed_annotation/freezed_annotation.dart';

part 'payment_models.freezed.dart';
part 'payment_models.g.dart';

@freezed
abstract class CreateRazorpayOrderRequest with _$CreateRazorpayOrderRequest {
  const factory CreateRazorpayOrderRequest({
    @JsonKey(name: 'student_id') required String studentId,
    @JsonKey(name: 'invoice_ids') required List<String> invoiceIds,
  }) = _CreateRazorpayOrderRequest;

  factory CreateRazorpayOrderRequest.fromJson(Map<String, dynamic> json) =>
      _$CreateRazorpayOrderRequestFromJson(json);
}

@freezed
abstract class CreateRazorpayOrderResponse with _$CreateRazorpayOrderResponse {
  const factory CreateRazorpayOrderResponse({
    @JsonKey(name: 'payment_order_id') required String paymentOrderId,
    @JsonKey(name: 'razorpay_order_id') required String razorpayOrderId,
    required double amount,
    required String currency,
  }) = _CreateRazorpayOrderResponse;

  factory CreateRazorpayOrderResponse.fromJson(Map<String, dynamic> json) =>
      _$CreateRazorpayOrderResponseFromJson(json);
}

@freezed
abstract class VerifyRazorpayPaymentRequest with _$VerifyRazorpayPaymentRequest {
  const factory VerifyRazorpayPaymentRequest({
    @JsonKey(name: 'payment_order_id') required String paymentOrderId,
    @JsonKey(name: 'razorpay_order_id') required String razorpayOrderId,
    @JsonKey(name: 'razorpay_payment_id') required String razorpayPaymentId,
    @JsonKey(name: 'razorpay_signature') required String razorpaySignature,
  }) = _VerifyRazorpayPaymentRequest;

  factory VerifyRazorpayPaymentRequest.fromJson(Map<String, dynamic> json) =>
      _$VerifyRazorpayPaymentRequestFromJson(json);
}
