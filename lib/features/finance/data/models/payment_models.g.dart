// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payment_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CreateRazorpayOrderRequest _$CreateRazorpayOrderRequestFromJson(
  Map<String, dynamic> json,
) => _CreateRazorpayOrderRequest(
  studentId: json['student_id'] as String,
  invoiceIds: (json['invoice_ids'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
);

Map<String, dynamic> _$CreateRazorpayOrderRequestToJson(
  _CreateRazorpayOrderRequest instance,
) => <String, dynamic>{
  'student_id': instance.studentId,
  'invoice_ids': instance.invoiceIds,
};

_CreateRazorpayOrderResponse _$CreateRazorpayOrderResponseFromJson(
  Map<String, dynamic> json,
) => _CreateRazorpayOrderResponse(
  paymentOrderId: json['payment_order_id'] as String,
  razorpayOrderId: json['razorpay_order_id'] as String,
  amount: (json['amount'] as num).toDouble(),
  currency: json['currency'] as String,
);

Map<String, dynamic> _$CreateRazorpayOrderResponseToJson(
  _CreateRazorpayOrderResponse instance,
) => <String, dynamic>{
  'payment_order_id': instance.paymentOrderId,
  'razorpay_order_id': instance.razorpayOrderId,
  'amount': instance.amount,
  'currency': instance.currency,
};

_VerifyRazorpayPaymentRequest _$VerifyRazorpayPaymentRequestFromJson(
  Map<String, dynamic> json,
) => _VerifyRazorpayPaymentRequest(
  paymentOrderId: json['payment_order_id'] as String,
  razorpayOrderId: json['razorpay_order_id'] as String,
  razorpayPaymentId: json['razorpay_payment_id'] as String,
  razorpaySignature: json['razorpay_signature'] as String,
);

Map<String, dynamic> _$VerifyRazorpayPaymentRequestToJson(
  _VerifyRazorpayPaymentRequest instance,
) => <String, dynamic>{
  'payment_order_id': instance.paymentOrderId,
  'razorpay_order_id': instance.razorpayOrderId,
  'razorpay_payment_id': instance.razorpayPaymentId,
  'razorpay_signature': instance.razorpaySignature,
};
