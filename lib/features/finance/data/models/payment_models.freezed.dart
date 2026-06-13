// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'payment_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CreateRazorpayOrderRequest {

@JsonKey(name: 'student_id') String get studentId;@JsonKey(name: 'invoice_ids') List<String> get invoiceIds;
/// Create a copy of CreateRazorpayOrderRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CreateRazorpayOrderRequestCopyWith<CreateRazorpayOrderRequest> get copyWith => _$CreateRazorpayOrderRequestCopyWithImpl<CreateRazorpayOrderRequest>(this as CreateRazorpayOrderRequest, _$identity);

  /// Serializes this CreateRazorpayOrderRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CreateRazorpayOrderRequest&&(identical(other.studentId, studentId) || other.studentId == studentId)&&const DeepCollectionEquality().equals(other.invoiceIds, invoiceIds));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,studentId,const DeepCollectionEquality().hash(invoiceIds));

@override
String toString() {
  return 'CreateRazorpayOrderRequest(studentId: $studentId, invoiceIds: $invoiceIds)';
}


}

/// @nodoc
abstract mixin class $CreateRazorpayOrderRequestCopyWith<$Res>  {
  factory $CreateRazorpayOrderRequestCopyWith(CreateRazorpayOrderRequest value, $Res Function(CreateRazorpayOrderRequest) _then) = _$CreateRazorpayOrderRequestCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'student_id') String studentId,@JsonKey(name: 'invoice_ids') List<String> invoiceIds
});




}
/// @nodoc
class _$CreateRazorpayOrderRequestCopyWithImpl<$Res>
    implements $CreateRazorpayOrderRequestCopyWith<$Res> {
  _$CreateRazorpayOrderRequestCopyWithImpl(this._self, this._then);

  final CreateRazorpayOrderRequest _self;
  final $Res Function(CreateRazorpayOrderRequest) _then;

/// Create a copy of CreateRazorpayOrderRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? studentId = null,Object? invoiceIds = null,}) {
  return _then(_self.copyWith(
studentId: null == studentId ? _self.studentId : studentId // ignore: cast_nullable_to_non_nullable
as String,invoiceIds: null == invoiceIds ? _self.invoiceIds : invoiceIds // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

}


/// Adds pattern-matching-related methods to [CreateRazorpayOrderRequest].
extension CreateRazorpayOrderRequestPatterns on CreateRazorpayOrderRequest {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CreateRazorpayOrderRequest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CreateRazorpayOrderRequest() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CreateRazorpayOrderRequest value)  $default,){
final _that = this;
switch (_that) {
case _CreateRazorpayOrderRequest():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CreateRazorpayOrderRequest value)?  $default,){
final _that = this;
switch (_that) {
case _CreateRazorpayOrderRequest() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'student_id')  String studentId, @JsonKey(name: 'invoice_ids')  List<String> invoiceIds)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CreateRazorpayOrderRequest() when $default != null:
return $default(_that.studentId,_that.invoiceIds);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'student_id')  String studentId, @JsonKey(name: 'invoice_ids')  List<String> invoiceIds)  $default,) {final _that = this;
switch (_that) {
case _CreateRazorpayOrderRequest():
return $default(_that.studentId,_that.invoiceIds);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'student_id')  String studentId, @JsonKey(name: 'invoice_ids')  List<String> invoiceIds)?  $default,) {final _that = this;
switch (_that) {
case _CreateRazorpayOrderRequest() when $default != null:
return $default(_that.studentId,_that.invoiceIds);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CreateRazorpayOrderRequest implements CreateRazorpayOrderRequest {
  const _CreateRazorpayOrderRequest({@JsonKey(name: 'student_id') required this.studentId, @JsonKey(name: 'invoice_ids') required final  List<String> invoiceIds}): _invoiceIds = invoiceIds;
  factory _CreateRazorpayOrderRequest.fromJson(Map<String, dynamic> json) => _$CreateRazorpayOrderRequestFromJson(json);

@override@JsonKey(name: 'student_id') final  String studentId;
 final  List<String> _invoiceIds;
@override@JsonKey(name: 'invoice_ids') List<String> get invoiceIds {
  if (_invoiceIds is EqualUnmodifiableListView) return _invoiceIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_invoiceIds);
}


/// Create a copy of CreateRazorpayOrderRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CreateRazorpayOrderRequestCopyWith<_CreateRazorpayOrderRequest> get copyWith => __$CreateRazorpayOrderRequestCopyWithImpl<_CreateRazorpayOrderRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CreateRazorpayOrderRequestToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CreateRazorpayOrderRequest&&(identical(other.studentId, studentId) || other.studentId == studentId)&&const DeepCollectionEquality().equals(other._invoiceIds, _invoiceIds));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,studentId,const DeepCollectionEquality().hash(_invoiceIds));

@override
String toString() {
  return 'CreateRazorpayOrderRequest(studentId: $studentId, invoiceIds: $invoiceIds)';
}


}

/// @nodoc
abstract mixin class _$CreateRazorpayOrderRequestCopyWith<$Res> implements $CreateRazorpayOrderRequestCopyWith<$Res> {
  factory _$CreateRazorpayOrderRequestCopyWith(_CreateRazorpayOrderRequest value, $Res Function(_CreateRazorpayOrderRequest) _then) = __$CreateRazorpayOrderRequestCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'student_id') String studentId,@JsonKey(name: 'invoice_ids') List<String> invoiceIds
});




}
/// @nodoc
class __$CreateRazorpayOrderRequestCopyWithImpl<$Res>
    implements _$CreateRazorpayOrderRequestCopyWith<$Res> {
  __$CreateRazorpayOrderRequestCopyWithImpl(this._self, this._then);

  final _CreateRazorpayOrderRequest _self;
  final $Res Function(_CreateRazorpayOrderRequest) _then;

/// Create a copy of CreateRazorpayOrderRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? studentId = null,Object? invoiceIds = null,}) {
  return _then(_CreateRazorpayOrderRequest(
studentId: null == studentId ? _self.studentId : studentId // ignore: cast_nullable_to_non_nullable
as String,invoiceIds: null == invoiceIds ? _self._invoiceIds : invoiceIds // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}


/// @nodoc
mixin _$CreateRazorpayOrderResponse {

@JsonKey(name: 'payment_order_id') String get paymentOrderId;@JsonKey(name: 'razorpay_order_id') String get razorpayOrderId; double get amount; String get currency;
/// Create a copy of CreateRazorpayOrderResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CreateRazorpayOrderResponseCopyWith<CreateRazorpayOrderResponse> get copyWith => _$CreateRazorpayOrderResponseCopyWithImpl<CreateRazorpayOrderResponse>(this as CreateRazorpayOrderResponse, _$identity);

  /// Serializes this CreateRazorpayOrderResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CreateRazorpayOrderResponse&&(identical(other.paymentOrderId, paymentOrderId) || other.paymentOrderId == paymentOrderId)&&(identical(other.razorpayOrderId, razorpayOrderId) || other.razorpayOrderId == razorpayOrderId)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.currency, currency) || other.currency == currency));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,paymentOrderId,razorpayOrderId,amount,currency);

@override
String toString() {
  return 'CreateRazorpayOrderResponse(paymentOrderId: $paymentOrderId, razorpayOrderId: $razorpayOrderId, amount: $amount, currency: $currency)';
}


}

/// @nodoc
abstract mixin class $CreateRazorpayOrderResponseCopyWith<$Res>  {
  factory $CreateRazorpayOrderResponseCopyWith(CreateRazorpayOrderResponse value, $Res Function(CreateRazorpayOrderResponse) _then) = _$CreateRazorpayOrderResponseCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'payment_order_id') String paymentOrderId,@JsonKey(name: 'razorpay_order_id') String razorpayOrderId, double amount, String currency
});




}
/// @nodoc
class _$CreateRazorpayOrderResponseCopyWithImpl<$Res>
    implements $CreateRazorpayOrderResponseCopyWith<$Res> {
  _$CreateRazorpayOrderResponseCopyWithImpl(this._self, this._then);

  final CreateRazorpayOrderResponse _self;
  final $Res Function(CreateRazorpayOrderResponse) _then;

/// Create a copy of CreateRazorpayOrderResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? paymentOrderId = null,Object? razorpayOrderId = null,Object? amount = null,Object? currency = null,}) {
  return _then(_self.copyWith(
paymentOrderId: null == paymentOrderId ? _self.paymentOrderId : paymentOrderId // ignore: cast_nullable_to_non_nullable
as String,razorpayOrderId: null == razorpayOrderId ? _self.razorpayOrderId : razorpayOrderId // ignore: cast_nullable_to_non_nullable
as String,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as double,currency: null == currency ? _self.currency : currency // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [CreateRazorpayOrderResponse].
extension CreateRazorpayOrderResponsePatterns on CreateRazorpayOrderResponse {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CreateRazorpayOrderResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CreateRazorpayOrderResponse() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CreateRazorpayOrderResponse value)  $default,){
final _that = this;
switch (_that) {
case _CreateRazorpayOrderResponse():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CreateRazorpayOrderResponse value)?  $default,){
final _that = this;
switch (_that) {
case _CreateRazorpayOrderResponse() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'payment_order_id')  String paymentOrderId, @JsonKey(name: 'razorpay_order_id')  String razorpayOrderId,  double amount,  String currency)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CreateRazorpayOrderResponse() when $default != null:
return $default(_that.paymentOrderId,_that.razorpayOrderId,_that.amount,_that.currency);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'payment_order_id')  String paymentOrderId, @JsonKey(name: 'razorpay_order_id')  String razorpayOrderId,  double amount,  String currency)  $default,) {final _that = this;
switch (_that) {
case _CreateRazorpayOrderResponse():
return $default(_that.paymentOrderId,_that.razorpayOrderId,_that.amount,_that.currency);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'payment_order_id')  String paymentOrderId, @JsonKey(name: 'razorpay_order_id')  String razorpayOrderId,  double amount,  String currency)?  $default,) {final _that = this;
switch (_that) {
case _CreateRazorpayOrderResponse() when $default != null:
return $default(_that.paymentOrderId,_that.razorpayOrderId,_that.amount,_that.currency);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CreateRazorpayOrderResponse implements CreateRazorpayOrderResponse {
  const _CreateRazorpayOrderResponse({@JsonKey(name: 'payment_order_id') required this.paymentOrderId, @JsonKey(name: 'razorpay_order_id') required this.razorpayOrderId, required this.amount, required this.currency});
  factory _CreateRazorpayOrderResponse.fromJson(Map<String, dynamic> json) => _$CreateRazorpayOrderResponseFromJson(json);

@override@JsonKey(name: 'payment_order_id') final  String paymentOrderId;
@override@JsonKey(name: 'razorpay_order_id') final  String razorpayOrderId;
@override final  double amount;
@override final  String currency;

/// Create a copy of CreateRazorpayOrderResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CreateRazorpayOrderResponseCopyWith<_CreateRazorpayOrderResponse> get copyWith => __$CreateRazorpayOrderResponseCopyWithImpl<_CreateRazorpayOrderResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CreateRazorpayOrderResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CreateRazorpayOrderResponse&&(identical(other.paymentOrderId, paymentOrderId) || other.paymentOrderId == paymentOrderId)&&(identical(other.razorpayOrderId, razorpayOrderId) || other.razorpayOrderId == razorpayOrderId)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.currency, currency) || other.currency == currency));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,paymentOrderId,razorpayOrderId,amount,currency);

@override
String toString() {
  return 'CreateRazorpayOrderResponse(paymentOrderId: $paymentOrderId, razorpayOrderId: $razorpayOrderId, amount: $amount, currency: $currency)';
}


}

/// @nodoc
abstract mixin class _$CreateRazorpayOrderResponseCopyWith<$Res> implements $CreateRazorpayOrderResponseCopyWith<$Res> {
  factory _$CreateRazorpayOrderResponseCopyWith(_CreateRazorpayOrderResponse value, $Res Function(_CreateRazorpayOrderResponse) _then) = __$CreateRazorpayOrderResponseCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'payment_order_id') String paymentOrderId,@JsonKey(name: 'razorpay_order_id') String razorpayOrderId, double amount, String currency
});




}
/// @nodoc
class __$CreateRazorpayOrderResponseCopyWithImpl<$Res>
    implements _$CreateRazorpayOrderResponseCopyWith<$Res> {
  __$CreateRazorpayOrderResponseCopyWithImpl(this._self, this._then);

  final _CreateRazorpayOrderResponse _self;
  final $Res Function(_CreateRazorpayOrderResponse) _then;

/// Create a copy of CreateRazorpayOrderResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? paymentOrderId = null,Object? razorpayOrderId = null,Object? amount = null,Object? currency = null,}) {
  return _then(_CreateRazorpayOrderResponse(
paymentOrderId: null == paymentOrderId ? _self.paymentOrderId : paymentOrderId // ignore: cast_nullable_to_non_nullable
as String,razorpayOrderId: null == razorpayOrderId ? _self.razorpayOrderId : razorpayOrderId // ignore: cast_nullable_to_non_nullable
as String,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as double,currency: null == currency ? _self.currency : currency // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$VerifyRazorpayPaymentRequest {

@JsonKey(name: 'payment_order_id') String get paymentOrderId;@JsonKey(name: 'razorpay_order_id') String get razorpayOrderId;@JsonKey(name: 'razorpay_payment_id') String get razorpayPaymentId;@JsonKey(name: 'razorpay_signature') String get razorpaySignature;
/// Create a copy of VerifyRazorpayPaymentRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VerifyRazorpayPaymentRequestCopyWith<VerifyRazorpayPaymentRequest> get copyWith => _$VerifyRazorpayPaymentRequestCopyWithImpl<VerifyRazorpayPaymentRequest>(this as VerifyRazorpayPaymentRequest, _$identity);

  /// Serializes this VerifyRazorpayPaymentRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VerifyRazorpayPaymentRequest&&(identical(other.paymentOrderId, paymentOrderId) || other.paymentOrderId == paymentOrderId)&&(identical(other.razorpayOrderId, razorpayOrderId) || other.razorpayOrderId == razorpayOrderId)&&(identical(other.razorpayPaymentId, razorpayPaymentId) || other.razorpayPaymentId == razorpayPaymentId)&&(identical(other.razorpaySignature, razorpaySignature) || other.razorpaySignature == razorpaySignature));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,paymentOrderId,razorpayOrderId,razorpayPaymentId,razorpaySignature);

@override
String toString() {
  return 'VerifyRazorpayPaymentRequest(paymentOrderId: $paymentOrderId, razorpayOrderId: $razorpayOrderId, razorpayPaymentId: $razorpayPaymentId, razorpaySignature: $razorpaySignature)';
}


}

/// @nodoc
abstract mixin class $VerifyRazorpayPaymentRequestCopyWith<$Res>  {
  factory $VerifyRazorpayPaymentRequestCopyWith(VerifyRazorpayPaymentRequest value, $Res Function(VerifyRazorpayPaymentRequest) _then) = _$VerifyRazorpayPaymentRequestCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'payment_order_id') String paymentOrderId,@JsonKey(name: 'razorpay_order_id') String razorpayOrderId,@JsonKey(name: 'razorpay_payment_id') String razorpayPaymentId,@JsonKey(name: 'razorpay_signature') String razorpaySignature
});




}
/// @nodoc
class _$VerifyRazorpayPaymentRequestCopyWithImpl<$Res>
    implements $VerifyRazorpayPaymentRequestCopyWith<$Res> {
  _$VerifyRazorpayPaymentRequestCopyWithImpl(this._self, this._then);

  final VerifyRazorpayPaymentRequest _self;
  final $Res Function(VerifyRazorpayPaymentRequest) _then;

/// Create a copy of VerifyRazorpayPaymentRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? paymentOrderId = null,Object? razorpayOrderId = null,Object? razorpayPaymentId = null,Object? razorpaySignature = null,}) {
  return _then(_self.copyWith(
paymentOrderId: null == paymentOrderId ? _self.paymentOrderId : paymentOrderId // ignore: cast_nullable_to_non_nullable
as String,razorpayOrderId: null == razorpayOrderId ? _self.razorpayOrderId : razorpayOrderId // ignore: cast_nullable_to_non_nullable
as String,razorpayPaymentId: null == razorpayPaymentId ? _self.razorpayPaymentId : razorpayPaymentId // ignore: cast_nullable_to_non_nullable
as String,razorpaySignature: null == razorpaySignature ? _self.razorpaySignature : razorpaySignature // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [VerifyRazorpayPaymentRequest].
extension VerifyRazorpayPaymentRequestPatterns on VerifyRazorpayPaymentRequest {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VerifyRazorpayPaymentRequest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VerifyRazorpayPaymentRequest() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VerifyRazorpayPaymentRequest value)  $default,){
final _that = this;
switch (_that) {
case _VerifyRazorpayPaymentRequest():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VerifyRazorpayPaymentRequest value)?  $default,){
final _that = this;
switch (_that) {
case _VerifyRazorpayPaymentRequest() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'payment_order_id')  String paymentOrderId, @JsonKey(name: 'razorpay_order_id')  String razorpayOrderId, @JsonKey(name: 'razorpay_payment_id')  String razorpayPaymentId, @JsonKey(name: 'razorpay_signature')  String razorpaySignature)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VerifyRazorpayPaymentRequest() when $default != null:
return $default(_that.paymentOrderId,_that.razorpayOrderId,_that.razorpayPaymentId,_that.razorpaySignature);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'payment_order_id')  String paymentOrderId, @JsonKey(name: 'razorpay_order_id')  String razorpayOrderId, @JsonKey(name: 'razorpay_payment_id')  String razorpayPaymentId, @JsonKey(name: 'razorpay_signature')  String razorpaySignature)  $default,) {final _that = this;
switch (_that) {
case _VerifyRazorpayPaymentRequest():
return $default(_that.paymentOrderId,_that.razorpayOrderId,_that.razorpayPaymentId,_that.razorpaySignature);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'payment_order_id')  String paymentOrderId, @JsonKey(name: 'razorpay_order_id')  String razorpayOrderId, @JsonKey(name: 'razorpay_payment_id')  String razorpayPaymentId, @JsonKey(name: 'razorpay_signature')  String razorpaySignature)?  $default,) {final _that = this;
switch (_that) {
case _VerifyRazorpayPaymentRequest() when $default != null:
return $default(_that.paymentOrderId,_that.razorpayOrderId,_that.razorpayPaymentId,_that.razorpaySignature);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _VerifyRazorpayPaymentRequest implements VerifyRazorpayPaymentRequest {
  const _VerifyRazorpayPaymentRequest({@JsonKey(name: 'payment_order_id') required this.paymentOrderId, @JsonKey(name: 'razorpay_order_id') required this.razorpayOrderId, @JsonKey(name: 'razorpay_payment_id') required this.razorpayPaymentId, @JsonKey(name: 'razorpay_signature') required this.razorpaySignature});
  factory _VerifyRazorpayPaymentRequest.fromJson(Map<String, dynamic> json) => _$VerifyRazorpayPaymentRequestFromJson(json);

@override@JsonKey(name: 'payment_order_id') final  String paymentOrderId;
@override@JsonKey(name: 'razorpay_order_id') final  String razorpayOrderId;
@override@JsonKey(name: 'razorpay_payment_id') final  String razorpayPaymentId;
@override@JsonKey(name: 'razorpay_signature') final  String razorpaySignature;

/// Create a copy of VerifyRazorpayPaymentRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VerifyRazorpayPaymentRequestCopyWith<_VerifyRazorpayPaymentRequest> get copyWith => __$VerifyRazorpayPaymentRequestCopyWithImpl<_VerifyRazorpayPaymentRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$VerifyRazorpayPaymentRequestToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VerifyRazorpayPaymentRequest&&(identical(other.paymentOrderId, paymentOrderId) || other.paymentOrderId == paymentOrderId)&&(identical(other.razorpayOrderId, razorpayOrderId) || other.razorpayOrderId == razorpayOrderId)&&(identical(other.razorpayPaymentId, razorpayPaymentId) || other.razorpayPaymentId == razorpayPaymentId)&&(identical(other.razorpaySignature, razorpaySignature) || other.razorpaySignature == razorpaySignature));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,paymentOrderId,razorpayOrderId,razorpayPaymentId,razorpaySignature);

@override
String toString() {
  return 'VerifyRazorpayPaymentRequest(paymentOrderId: $paymentOrderId, razorpayOrderId: $razorpayOrderId, razorpayPaymentId: $razorpayPaymentId, razorpaySignature: $razorpaySignature)';
}


}

/// @nodoc
abstract mixin class _$VerifyRazorpayPaymentRequestCopyWith<$Res> implements $VerifyRazorpayPaymentRequestCopyWith<$Res> {
  factory _$VerifyRazorpayPaymentRequestCopyWith(_VerifyRazorpayPaymentRequest value, $Res Function(_VerifyRazorpayPaymentRequest) _then) = __$VerifyRazorpayPaymentRequestCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'payment_order_id') String paymentOrderId,@JsonKey(name: 'razorpay_order_id') String razorpayOrderId,@JsonKey(name: 'razorpay_payment_id') String razorpayPaymentId,@JsonKey(name: 'razorpay_signature') String razorpaySignature
});




}
/// @nodoc
class __$VerifyRazorpayPaymentRequestCopyWithImpl<$Res>
    implements _$VerifyRazorpayPaymentRequestCopyWith<$Res> {
  __$VerifyRazorpayPaymentRequestCopyWithImpl(this._self, this._then);

  final _VerifyRazorpayPaymentRequest _self;
  final $Res Function(_VerifyRazorpayPaymentRequest) _then;

/// Create a copy of VerifyRazorpayPaymentRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? paymentOrderId = null,Object? razorpayOrderId = null,Object? razorpayPaymentId = null,Object? razorpaySignature = null,}) {
  return _then(_VerifyRazorpayPaymentRequest(
paymentOrderId: null == paymentOrderId ? _self.paymentOrderId : paymentOrderId // ignore: cast_nullable_to_non_nullable
as String,razorpayOrderId: null == razorpayOrderId ? _self.razorpayOrderId : razorpayOrderId // ignore: cast_nullable_to_non_nullable
as String,razorpayPaymentId: null == razorpayPaymentId ? _self.razorpayPaymentId : razorpayPaymentId // ignore: cast_nullable_to_non_nullable
as String,razorpaySignature: null == razorpaySignature ? _self.razorpaySignature : razorpaySignature // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
