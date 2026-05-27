// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'schooldesk_api_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ApiEnvelope {

 bool get success; String? get code; String? get message; dynamic get data; String? get error; dynamic get details;@JsonKey(name: 'request_id') String? get requestId;
/// Create a copy of ApiEnvelope
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ApiEnvelopeCopyWith<ApiEnvelope> get copyWith => _$ApiEnvelopeCopyWithImpl<ApiEnvelope>(this as ApiEnvelope, _$identity);

  /// Serializes this ApiEnvelope to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ApiEnvelope&&(identical(other.success, success) || other.success == success)&&(identical(other.code, code) || other.code == code)&&(identical(other.message, message) || other.message == message)&&const DeepCollectionEquality().equals(other.data, data)&&(identical(other.error, error) || other.error == error)&&const DeepCollectionEquality().equals(other.details, details)&&(identical(other.requestId, requestId) || other.requestId == requestId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,success,code,message,const DeepCollectionEquality().hash(data),error,const DeepCollectionEquality().hash(details),requestId);

@override
String toString() {
  return 'ApiEnvelope(success: $success, code: $code, message: $message, data: $data, error: $error, details: $details, requestId: $requestId)';
}


}

/// @nodoc
abstract mixin class $ApiEnvelopeCopyWith<$Res>  {
  factory $ApiEnvelopeCopyWith(ApiEnvelope value, $Res Function(ApiEnvelope) _then) = _$ApiEnvelopeCopyWithImpl;
@useResult
$Res call({
 bool success, String? code, String? message, dynamic data, String? error, dynamic details,@JsonKey(name: 'request_id') String? requestId
});




}
/// @nodoc
class _$ApiEnvelopeCopyWithImpl<$Res>
    implements $ApiEnvelopeCopyWith<$Res> {
  _$ApiEnvelopeCopyWithImpl(this._self, this._then);

  final ApiEnvelope _self;
  final $Res Function(ApiEnvelope) _then;

/// Create a copy of ApiEnvelope
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? success = null,Object? code = freezed,Object? message = freezed,Object? data = freezed,Object? error = freezed,Object? details = freezed,Object? requestId = freezed,}) {
  return _then(_self.copyWith(
success: null == success ? _self.success : success // ignore: cast_nullable_to_non_nullable
as bool,code: freezed == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String?,message: freezed == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String?,data: freezed == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as dynamic,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,details: freezed == details ? _self.details : details // ignore: cast_nullable_to_non_nullable
as dynamic,requestId: freezed == requestId ? _self.requestId : requestId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [ApiEnvelope].
extension ApiEnvelopePatterns on ApiEnvelope {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ApiEnvelope value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ApiEnvelope() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ApiEnvelope value)  $default,){
final _that = this;
switch (_that) {
case _ApiEnvelope():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ApiEnvelope value)?  $default,){
final _that = this;
switch (_that) {
case _ApiEnvelope() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool success,  String? code,  String? message,  dynamic data,  String? error,  dynamic details, @JsonKey(name: 'request_id')  String? requestId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ApiEnvelope() when $default != null:
return $default(_that.success,_that.code,_that.message,_that.data,_that.error,_that.details,_that.requestId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool success,  String? code,  String? message,  dynamic data,  String? error,  dynamic details, @JsonKey(name: 'request_id')  String? requestId)  $default,) {final _that = this;
switch (_that) {
case _ApiEnvelope():
return $default(_that.success,_that.code,_that.message,_that.data,_that.error,_that.details,_that.requestId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool success,  String? code,  String? message,  dynamic data,  String? error,  dynamic details, @JsonKey(name: 'request_id')  String? requestId)?  $default,) {final _that = this;
switch (_that) {
case _ApiEnvelope() when $default != null:
return $default(_that.success,_that.code,_that.message,_that.data,_that.error,_that.details,_that.requestId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ApiEnvelope implements ApiEnvelope {
  const _ApiEnvelope({this.success = false, this.code, this.message, this.data, this.error, this.details, @JsonKey(name: 'request_id') this.requestId});
  factory _ApiEnvelope.fromJson(Map<String, dynamic> json) => _$ApiEnvelopeFromJson(json);

@override@JsonKey() final  bool success;
@override final  String? code;
@override final  String? message;
@override final  dynamic data;
@override final  String? error;
@override final  dynamic details;
@override@JsonKey(name: 'request_id') final  String? requestId;

/// Create a copy of ApiEnvelope
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ApiEnvelopeCopyWith<_ApiEnvelope> get copyWith => __$ApiEnvelopeCopyWithImpl<_ApiEnvelope>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ApiEnvelopeToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ApiEnvelope&&(identical(other.success, success) || other.success == success)&&(identical(other.code, code) || other.code == code)&&(identical(other.message, message) || other.message == message)&&const DeepCollectionEquality().equals(other.data, data)&&(identical(other.error, error) || other.error == error)&&const DeepCollectionEquality().equals(other.details, details)&&(identical(other.requestId, requestId) || other.requestId == requestId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,success,code,message,const DeepCollectionEquality().hash(data),error,const DeepCollectionEquality().hash(details),requestId);

@override
String toString() {
  return 'ApiEnvelope(success: $success, code: $code, message: $message, data: $data, error: $error, details: $details, requestId: $requestId)';
}


}

/// @nodoc
abstract mixin class _$ApiEnvelopeCopyWith<$Res> implements $ApiEnvelopeCopyWith<$Res> {
  factory _$ApiEnvelopeCopyWith(_ApiEnvelope value, $Res Function(_ApiEnvelope) _then) = __$ApiEnvelopeCopyWithImpl;
@override @useResult
$Res call({
 bool success, String? code, String? message, dynamic data, String? error, dynamic details,@JsonKey(name: 'request_id') String? requestId
});




}
/// @nodoc
class __$ApiEnvelopeCopyWithImpl<$Res>
    implements _$ApiEnvelopeCopyWith<$Res> {
  __$ApiEnvelopeCopyWithImpl(this._self, this._then);

  final _ApiEnvelope _self;
  final $Res Function(_ApiEnvelope) _then;

/// Create a copy of ApiEnvelope
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? success = null,Object? code = freezed,Object? message = freezed,Object? data = freezed,Object? error = freezed,Object? details = freezed,Object? requestId = freezed,}) {
  return _then(_ApiEnvelope(
success: null == success ? _self.success : success // ignore: cast_nullable_to_non_nullable
as bool,code: freezed == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String?,message: freezed == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String?,data: freezed == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as dynamic,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,details: freezed == details ? _self.details : details // ignore: cast_nullable_to_non_nullable
as dynamic,requestId: freezed == requestId ? _self.requestId : requestId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$PaginatedEnvelope {

 bool get success; List<dynamic> get data; int get page;@JsonKey(name: 'page_size') int get pageSize; int get total;@JsonKey(name: 'total_pages') int get totalPages;
/// Create a copy of PaginatedEnvelope
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PaginatedEnvelopeCopyWith<PaginatedEnvelope> get copyWith => _$PaginatedEnvelopeCopyWithImpl<PaginatedEnvelope>(this as PaginatedEnvelope, _$identity);

  /// Serializes this PaginatedEnvelope to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PaginatedEnvelope&&(identical(other.success, success) || other.success == success)&&const DeepCollectionEquality().equals(other.data, data)&&(identical(other.page, page) || other.page == page)&&(identical(other.pageSize, pageSize) || other.pageSize == pageSize)&&(identical(other.total, total) || other.total == total)&&(identical(other.totalPages, totalPages) || other.totalPages == totalPages));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,success,const DeepCollectionEquality().hash(data),page,pageSize,total,totalPages);

@override
String toString() {
  return 'PaginatedEnvelope(success: $success, data: $data, page: $page, pageSize: $pageSize, total: $total, totalPages: $totalPages)';
}


}

/// @nodoc
abstract mixin class $PaginatedEnvelopeCopyWith<$Res>  {
  factory $PaginatedEnvelopeCopyWith(PaginatedEnvelope value, $Res Function(PaginatedEnvelope) _then) = _$PaginatedEnvelopeCopyWithImpl;
@useResult
$Res call({
 bool success, List<dynamic> data, int page,@JsonKey(name: 'page_size') int pageSize, int total,@JsonKey(name: 'total_pages') int totalPages
});




}
/// @nodoc
class _$PaginatedEnvelopeCopyWithImpl<$Res>
    implements $PaginatedEnvelopeCopyWith<$Res> {
  _$PaginatedEnvelopeCopyWithImpl(this._self, this._then);

  final PaginatedEnvelope _self;
  final $Res Function(PaginatedEnvelope) _then;

/// Create a copy of PaginatedEnvelope
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? success = null,Object? data = null,Object? page = null,Object? pageSize = null,Object? total = null,Object? totalPages = null,}) {
  return _then(_self.copyWith(
success: null == success ? _self.success : success // ignore: cast_nullable_to_non_nullable
as bool,data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as List<dynamic>,page: null == page ? _self.page : page // ignore: cast_nullable_to_non_nullable
as int,pageSize: null == pageSize ? _self.pageSize : pageSize // ignore: cast_nullable_to_non_nullable
as int,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,totalPages: null == totalPages ? _self.totalPages : totalPages // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [PaginatedEnvelope].
extension PaginatedEnvelopePatterns on PaginatedEnvelope {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PaginatedEnvelope value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PaginatedEnvelope() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PaginatedEnvelope value)  $default,){
final _that = this;
switch (_that) {
case _PaginatedEnvelope():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PaginatedEnvelope value)?  $default,){
final _that = this;
switch (_that) {
case _PaginatedEnvelope() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool success,  List<dynamic> data,  int page, @JsonKey(name: 'page_size')  int pageSize,  int total, @JsonKey(name: 'total_pages')  int totalPages)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PaginatedEnvelope() when $default != null:
return $default(_that.success,_that.data,_that.page,_that.pageSize,_that.total,_that.totalPages);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool success,  List<dynamic> data,  int page, @JsonKey(name: 'page_size')  int pageSize,  int total, @JsonKey(name: 'total_pages')  int totalPages)  $default,) {final _that = this;
switch (_that) {
case _PaginatedEnvelope():
return $default(_that.success,_that.data,_that.page,_that.pageSize,_that.total,_that.totalPages);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool success,  List<dynamic> data,  int page, @JsonKey(name: 'page_size')  int pageSize,  int total, @JsonKey(name: 'total_pages')  int totalPages)?  $default,) {final _that = this;
switch (_that) {
case _PaginatedEnvelope() when $default != null:
return $default(_that.success,_that.data,_that.page,_that.pageSize,_that.total,_that.totalPages);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PaginatedEnvelope implements PaginatedEnvelope {
  const _PaginatedEnvelope({this.success = false, final  List<dynamic> data = const <dynamic>[], this.page = 1, @JsonKey(name: 'page_size') this.pageSize = 20, this.total = 0, @JsonKey(name: 'total_pages') this.totalPages = 0}): _data = data;
  factory _PaginatedEnvelope.fromJson(Map<String, dynamic> json) => _$PaginatedEnvelopeFromJson(json);

@override@JsonKey() final  bool success;
 final  List<dynamic> _data;
@override@JsonKey() List<dynamic> get data {
  if (_data is EqualUnmodifiableListView) return _data;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_data);
}

@override@JsonKey() final  int page;
@override@JsonKey(name: 'page_size') final  int pageSize;
@override@JsonKey() final  int total;
@override@JsonKey(name: 'total_pages') final  int totalPages;

/// Create a copy of PaginatedEnvelope
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PaginatedEnvelopeCopyWith<_PaginatedEnvelope> get copyWith => __$PaginatedEnvelopeCopyWithImpl<_PaginatedEnvelope>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PaginatedEnvelopeToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PaginatedEnvelope&&(identical(other.success, success) || other.success == success)&&const DeepCollectionEquality().equals(other._data, _data)&&(identical(other.page, page) || other.page == page)&&(identical(other.pageSize, pageSize) || other.pageSize == pageSize)&&(identical(other.total, total) || other.total == total)&&(identical(other.totalPages, totalPages) || other.totalPages == totalPages));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,success,const DeepCollectionEquality().hash(_data),page,pageSize,total,totalPages);

@override
String toString() {
  return 'PaginatedEnvelope(success: $success, data: $data, page: $page, pageSize: $pageSize, total: $total, totalPages: $totalPages)';
}


}

/// @nodoc
abstract mixin class _$PaginatedEnvelopeCopyWith<$Res> implements $PaginatedEnvelopeCopyWith<$Res> {
  factory _$PaginatedEnvelopeCopyWith(_PaginatedEnvelope value, $Res Function(_PaginatedEnvelope) _then) = __$PaginatedEnvelopeCopyWithImpl;
@override @useResult
$Res call({
 bool success, List<dynamic> data, int page,@JsonKey(name: 'page_size') int pageSize, int total,@JsonKey(name: 'total_pages') int totalPages
});




}
/// @nodoc
class __$PaginatedEnvelopeCopyWithImpl<$Res>
    implements _$PaginatedEnvelopeCopyWith<$Res> {
  __$PaginatedEnvelopeCopyWithImpl(this._self, this._then);

  final _PaginatedEnvelope _self;
  final $Res Function(_PaginatedEnvelope) _then;

/// Create a copy of PaginatedEnvelope
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? success = null,Object? data = null,Object? page = null,Object? pageSize = null,Object? total = null,Object? totalPages = null,}) {
  return _then(_PaginatedEnvelope(
success: null == success ? _self.success : success // ignore: cast_nullable_to_non_nullable
as bool,data: null == data ? _self._data : data // ignore: cast_nullable_to_non_nullable
as List<dynamic>,page: null == page ? _self.page : page // ignore: cast_nullable_to_non_nullable
as int,pageSize: null == pageSize ? _self.pageSize : pageSize // ignore: cast_nullable_to_non_nullable
as int,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,totalPages: null == totalPages ? _self.totalPages : totalPages // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$LoginRequestDto {

 String? get username; String? get email; String get password;
/// Create a copy of LoginRequestDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LoginRequestDtoCopyWith<LoginRequestDto> get copyWith => _$LoginRequestDtoCopyWithImpl<LoginRequestDto>(this as LoginRequestDto, _$identity);

  /// Serializes this LoginRequestDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LoginRequestDto&&(identical(other.username, username) || other.username == username)&&(identical(other.email, email) || other.email == email)&&(identical(other.password, password) || other.password == password));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,username,email,password);

@override
String toString() {
  return 'LoginRequestDto(username: $username, email: $email, password: $password)';
}


}

/// @nodoc
abstract mixin class $LoginRequestDtoCopyWith<$Res>  {
  factory $LoginRequestDtoCopyWith(LoginRequestDto value, $Res Function(LoginRequestDto) _then) = _$LoginRequestDtoCopyWithImpl;
@useResult
$Res call({
 String? username, String? email, String password
});




}
/// @nodoc
class _$LoginRequestDtoCopyWithImpl<$Res>
    implements $LoginRequestDtoCopyWith<$Res> {
  _$LoginRequestDtoCopyWithImpl(this._self, this._then);

  final LoginRequestDto _self;
  final $Res Function(LoginRequestDto) _then;

/// Create a copy of LoginRequestDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? username = freezed,Object? email = freezed,Object? password = null,}) {
  return _then(_self.copyWith(
username: freezed == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String?,email: freezed == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String?,password: null == password ? _self.password : password // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [LoginRequestDto].
extension LoginRequestDtoPatterns on LoginRequestDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LoginRequestDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LoginRequestDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LoginRequestDto value)  $default,){
final _that = this;
switch (_that) {
case _LoginRequestDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LoginRequestDto value)?  $default,){
final _that = this;
switch (_that) {
case _LoginRequestDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? username,  String? email,  String password)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LoginRequestDto() when $default != null:
return $default(_that.username,_that.email,_that.password);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? username,  String? email,  String password)  $default,) {final _that = this;
switch (_that) {
case _LoginRequestDto():
return $default(_that.username,_that.email,_that.password);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? username,  String? email,  String password)?  $default,) {final _that = this;
switch (_that) {
case _LoginRequestDto() when $default != null:
return $default(_that.username,_that.email,_that.password);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LoginRequestDto implements LoginRequestDto {
  const _LoginRequestDto({this.username, this.email, required this.password});
  factory _LoginRequestDto.fromJson(Map<String, dynamic> json) => _$LoginRequestDtoFromJson(json);

@override final  String? username;
@override final  String? email;
@override final  String password;

/// Create a copy of LoginRequestDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LoginRequestDtoCopyWith<_LoginRequestDto> get copyWith => __$LoginRequestDtoCopyWithImpl<_LoginRequestDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LoginRequestDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LoginRequestDto&&(identical(other.username, username) || other.username == username)&&(identical(other.email, email) || other.email == email)&&(identical(other.password, password) || other.password == password));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,username,email,password);

@override
String toString() {
  return 'LoginRequestDto(username: $username, email: $email, password: $password)';
}


}

/// @nodoc
abstract mixin class _$LoginRequestDtoCopyWith<$Res> implements $LoginRequestDtoCopyWith<$Res> {
  factory _$LoginRequestDtoCopyWith(_LoginRequestDto value, $Res Function(_LoginRequestDto) _then) = __$LoginRequestDtoCopyWithImpl;
@override @useResult
$Res call({
 String? username, String? email, String password
});




}
/// @nodoc
class __$LoginRequestDtoCopyWithImpl<$Res>
    implements _$LoginRequestDtoCopyWith<$Res> {
  __$LoginRequestDtoCopyWithImpl(this._self, this._then);

  final _LoginRequestDto _self;
  final $Res Function(_LoginRequestDto) _then;

/// Create a copy of LoginRequestDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? username = freezed,Object? email = freezed,Object? password = null,}) {
  return _then(_LoginRequestDto(
username: freezed == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String?,email: freezed == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String?,password: null == password ? _self.password : password // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$UserDto {

 String? get id; String? get username; String? get name; String? get email; String? get phone;@JsonKey(name: 'school_id') String? get schoolId;@JsonKey(name: 'role_id') String? get roleId;@JsonKey(name: 'role_name') String? get roleName;@JsonKey(name: 'linked_type') String? get linkedType;@JsonKey(name: 'linked_id') String? get linkedId;@JsonKey(name: 'is_active') bool? get isActive;@JsonKey(name: 'is_verified') bool? get isVerified;
/// Create a copy of UserDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UserDtoCopyWith<UserDto> get copyWith => _$UserDtoCopyWithImpl<UserDto>(this as UserDto, _$identity);

  /// Serializes this UserDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UserDto&&(identical(other.id, id) || other.id == id)&&(identical(other.username, username) || other.username == username)&&(identical(other.name, name) || other.name == name)&&(identical(other.email, email) || other.email == email)&&(identical(other.phone, phone) || other.phone == phone)&&(identical(other.schoolId, schoolId) || other.schoolId == schoolId)&&(identical(other.roleId, roleId) || other.roleId == roleId)&&(identical(other.roleName, roleName) || other.roleName == roleName)&&(identical(other.linkedType, linkedType) || other.linkedType == linkedType)&&(identical(other.linkedId, linkedId) || other.linkedId == linkedId)&&(identical(other.isActive, isActive) || other.isActive == isActive)&&(identical(other.isVerified, isVerified) || other.isVerified == isVerified));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,username,name,email,phone,schoolId,roleId,roleName,linkedType,linkedId,isActive,isVerified);

@override
String toString() {
  return 'UserDto(id: $id, username: $username, name: $name, email: $email, phone: $phone, schoolId: $schoolId, roleId: $roleId, roleName: $roleName, linkedType: $linkedType, linkedId: $linkedId, isActive: $isActive, isVerified: $isVerified)';
}


}

/// @nodoc
abstract mixin class $UserDtoCopyWith<$Res>  {
  factory $UserDtoCopyWith(UserDto value, $Res Function(UserDto) _then) = _$UserDtoCopyWithImpl;
@useResult
$Res call({
 String? id, String? username, String? name, String? email, String? phone,@JsonKey(name: 'school_id') String? schoolId,@JsonKey(name: 'role_id') String? roleId,@JsonKey(name: 'role_name') String? roleName,@JsonKey(name: 'linked_type') String? linkedType,@JsonKey(name: 'linked_id') String? linkedId,@JsonKey(name: 'is_active') bool? isActive,@JsonKey(name: 'is_verified') bool? isVerified
});




}
/// @nodoc
class _$UserDtoCopyWithImpl<$Res>
    implements $UserDtoCopyWith<$Res> {
  _$UserDtoCopyWithImpl(this._self, this._then);

  final UserDto _self;
  final $Res Function(UserDto) _then;

/// Create a copy of UserDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = freezed,Object? username = freezed,Object? name = freezed,Object? email = freezed,Object? phone = freezed,Object? schoolId = freezed,Object? roleId = freezed,Object? roleName = freezed,Object? linkedType = freezed,Object? linkedId = freezed,Object? isActive = freezed,Object? isVerified = freezed,}) {
  return _then(_self.copyWith(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,username: freezed == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String?,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,email: freezed == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String?,phone: freezed == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String?,schoolId: freezed == schoolId ? _self.schoolId : schoolId // ignore: cast_nullable_to_non_nullable
as String?,roleId: freezed == roleId ? _self.roleId : roleId // ignore: cast_nullable_to_non_nullable
as String?,roleName: freezed == roleName ? _self.roleName : roleName // ignore: cast_nullable_to_non_nullable
as String?,linkedType: freezed == linkedType ? _self.linkedType : linkedType // ignore: cast_nullable_to_non_nullable
as String?,linkedId: freezed == linkedId ? _self.linkedId : linkedId // ignore: cast_nullable_to_non_nullable
as String?,isActive: freezed == isActive ? _self.isActive : isActive // ignore: cast_nullable_to_non_nullable
as bool?,isVerified: freezed == isVerified ? _self.isVerified : isVerified // ignore: cast_nullable_to_non_nullable
as bool?,
  ));
}

}


/// Adds pattern-matching-related methods to [UserDto].
extension UserDtoPatterns on UserDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UserDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UserDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UserDto value)  $default,){
final _that = this;
switch (_that) {
case _UserDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UserDto value)?  $default,){
final _that = this;
switch (_that) {
case _UserDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? id,  String? username,  String? name,  String? email,  String? phone, @JsonKey(name: 'school_id')  String? schoolId, @JsonKey(name: 'role_id')  String? roleId, @JsonKey(name: 'role_name')  String? roleName, @JsonKey(name: 'linked_type')  String? linkedType, @JsonKey(name: 'linked_id')  String? linkedId, @JsonKey(name: 'is_active')  bool? isActive, @JsonKey(name: 'is_verified')  bool? isVerified)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UserDto() when $default != null:
return $default(_that.id,_that.username,_that.name,_that.email,_that.phone,_that.schoolId,_that.roleId,_that.roleName,_that.linkedType,_that.linkedId,_that.isActive,_that.isVerified);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? id,  String? username,  String? name,  String? email,  String? phone, @JsonKey(name: 'school_id')  String? schoolId, @JsonKey(name: 'role_id')  String? roleId, @JsonKey(name: 'role_name')  String? roleName, @JsonKey(name: 'linked_type')  String? linkedType, @JsonKey(name: 'linked_id')  String? linkedId, @JsonKey(name: 'is_active')  bool? isActive, @JsonKey(name: 'is_verified')  bool? isVerified)  $default,) {final _that = this;
switch (_that) {
case _UserDto():
return $default(_that.id,_that.username,_that.name,_that.email,_that.phone,_that.schoolId,_that.roleId,_that.roleName,_that.linkedType,_that.linkedId,_that.isActive,_that.isVerified);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? id,  String? username,  String? name,  String? email,  String? phone, @JsonKey(name: 'school_id')  String? schoolId, @JsonKey(name: 'role_id')  String? roleId, @JsonKey(name: 'role_name')  String? roleName, @JsonKey(name: 'linked_type')  String? linkedType, @JsonKey(name: 'linked_id')  String? linkedId, @JsonKey(name: 'is_active')  bool? isActive, @JsonKey(name: 'is_verified')  bool? isVerified)?  $default,) {final _that = this;
switch (_that) {
case _UserDto() when $default != null:
return $default(_that.id,_that.username,_that.name,_that.email,_that.phone,_that.schoolId,_that.roleId,_that.roleName,_that.linkedType,_that.linkedId,_that.isActive,_that.isVerified);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _UserDto implements UserDto {
  const _UserDto({this.id, this.username, this.name, this.email, this.phone, @JsonKey(name: 'school_id') this.schoolId, @JsonKey(name: 'role_id') this.roleId, @JsonKey(name: 'role_name') this.roleName, @JsonKey(name: 'linked_type') this.linkedType, @JsonKey(name: 'linked_id') this.linkedId, @JsonKey(name: 'is_active') this.isActive, @JsonKey(name: 'is_verified') this.isVerified});
  factory _UserDto.fromJson(Map<String, dynamic> json) => _$UserDtoFromJson(json);

@override final  String? id;
@override final  String? username;
@override final  String? name;
@override final  String? email;
@override final  String? phone;
@override@JsonKey(name: 'school_id') final  String? schoolId;
@override@JsonKey(name: 'role_id') final  String? roleId;
@override@JsonKey(name: 'role_name') final  String? roleName;
@override@JsonKey(name: 'linked_type') final  String? linkedType;
@override@JsonKey(name: 'linked_id') final  String? linkedId;
@override@JsonKey(name: 'is_active') final  bool? isActive;
@override@JsonKey(name: 'is_verified') final  bool? isVerified;

/// Create a copy of UserDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UserDtoCopyWith<_UserDto> get copyWith => __$UserDtoCopyWithImpl<_UserDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$UserDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UserDto&&(identical(other.id, id) || other.id == id)&&(identical(other.username, username) || other.username == username)&&(identical(other.name, name) || other.name == name)&&(identical(other.email, email) || other.email == email)&&(identical(other.phone, phone) || other.phone == phone)&&(identical(other.schoolId, schoolId) || other.schoolId == schoolId)&&(identical(other.roleId, roleId) || other.roleId == roleId)&&(identical(other.roleName, roleName) || other.roleName == roleName)&&(identical(other.linkedType, linkedType) || other.linkedType == linkedType)&&(identical(other.linkedId, linkedId) || other.linkedId == linkedId)&&(identical(other.isActive, isActive) || other.isActive == isActive)&&(identical(other.isVerified, isVerified) || other.isVerified == isVerified));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,username,name,email,phone,schoolId,roleId,roleName,linkedType,linkedId,isActive,isVerified);

@override
String toString() {
  return 'UserDto(id: $id, username: $username, name: $name, email: $email, phone: $phone, schoolId: $schoolId, roleId: $roleId, roleName: $roleName, linkedType: $linkedType, linkedId: $linkedId, isActive: $isActive, isVerified: $isVerified)';
}


}

/// @nodoc
abstract mixin class _$UserDtoCopyWith<$Res> implements $UserDtoCopyWith<$Res> {
  factory _$UserDtoCopyWith(_UserDto value, $Res Function(_UserDto) _then) = __$UserDtoCopyWithImpl;
@override @useResult
$Res call({
 String? id, String? username, String? name, String? email, String? phone,@JsonKey(name: 'school_id') String? schoolId,@JsonKey(name: 'role_id') String? roleId,@JsonKey(name: 'role_name') String? roleName,@JsonKey(name: 'linked_type') String? linkedType,@JsonKey(name: 'linked_id') String? linkedId,@JsonKey(name: 'is_active') bool? isActive,@JsonKey(name: 'is_verified') bool? isVerified
});




}
/// @nodoc
class __$UserDtoCopyWithImpl<$Res>
    implements _$UserDtoCopyWith<$Res> {
  __$UserDtoCopyWithImpl(this._self, this._then);

  final _UserDto _self;
  final $Res Function(_UserDto) _then;

/// Create a copy of UserDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = freezed,Object? username = freezed,Object? name = freezed,Object? email = freezed,Object? phone = freezed,Object? schoolId = freezed,Object? roleId = freezed,Object? roleName = freezed,Object? linkedType = freezed,Object? linkedId = freezed,Object? isActive = freezed,Object? isVerified = freezed,}) {
  return _then(_UserDto(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,username: freezed == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String?,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,email: freezed == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String?,phone: freezed == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String?,schoolId: freezed == schoolId ? _self.schoolId : schoolId // ignore: cast_nullable_to_non_nullable
as String?,roleId: freezed == roleId ? _self.roleId : roleId // ignore: cast_nullable_to_non_nullable
as String?,roleName: freezed == roleName ? _self.roleName : roleName // ignore: cast_nullable_to_non_nullable
as String?,linkedType: freezed == linkedType ? _self.linkedType : linkedType // ignore: cast_nullable_to_non_nullable
as String?,linkedId: freezed == linkedId ? _self.linkedId : linkedId // ignore: cast_nullable_to_non_nullable
as String?,isActive: freezed == isActive ? _self.isActive : isActive // ignore: cast_nullable_to_non_nullable
as bool?,isVerified: freezed == isVerified ? _self.isVerified : isVerified // ignore: cast_nullable_to_non_nullable
as bool?,
  ));
}


}


/// @nodoc
mixin _$LoginPayloadDto {

 String? get token;@JsonKey(name: 'refresh_token') String? get refreshToken;@JsonKey(name: 'expires_at') int? get expiresAt; UserDto? get user;
/// Create a copy of LoginPayloadDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LoginPayloadDtoCopyWith<LoginPayloadDto> get copyWith => _$LoginPayloadDtoCopyWithImpl<LoginPayloadDto>(this as LoginPayloadDto, _$identity);

  /// Serializes this LoginPayloadDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LoginPayloadDto&&(identical(other.token, token) || other.token == token)&&(identical(other.refreshToken, refreshToken) || other.refreshToken == refreshToken)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt)&&(identical(other.user, user) || other.user == user));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,token,refreshToken,expiresAt,user);

@override
String toString() {
  return 'LoginPayloadDto(token: $token, refreshToken: $refreshToken, expiresAt: $expiresAt, user: $user)';
}


}

/// @nodoc
abstract mixin class $LoginPayloadDtoCopyWith<$Res>  {
  factory $LoginPayloadDtoCopyWith(LoginPayloadDto value, $Res Function(LoginPayloadDto) _then) = _$LoginPayloadDtoCopyWithImpl;
@useResult
$Res call({
 String? token,@JsonKey(name: 'refresh_token') String? refreshToken,@JsonKey(name: 'expires_at') int? expiresAt, UserDto? user
});


$UserDtoCopyWith<$Res>? get user;

}
/// @nodoc
class _$LoginPayloadDtoCopyWithImpl<$Res>
    implements $LoginPayloadDtoCopyWith<$Res> {
  _$LoginPayloadDtoCopyWithImpl(this._self, this._then);

  final LoginPayloadDto _self;
  final $Res Function(LoginPayloadDto) _then;

/// Create a copy of LoginPayloadDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? token = freezed,Object? refreshToken = freezed,Object? expiresAt = freezed,Object? user = freezed,}) {
  return _then(_self.copyWith(
token: freezed == token ? _self.token : token // ignore: cast_nullable_to_non_nullable
as String?,refreshToken: freezed == refreshToken ? _self.refreshToken : refreshToken // ignore: cast_nullable_to_non_nullable
as String?,expiresAt: freezed == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as int?,user: freezed == user ? _self.user : user // ignore: cast_nullable_to_non_nullable
as UserDto?,
  ));
}
/// Create a copy of LoginPayloadDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserDtoCopyWith<$Res>? get user {
    if (_self.user == null) {
    return null;
  }

  return $UserDtoCopyWith<$Res>(_self.user!, (value) {
    return _then(_self.copyWith(user: value));
  });
}
}


/// Adds pattern-matching-related methods to [LoginPayloadDto].
extension LoginPayloadDtoPatterns on LoginPayloadDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LoginPayloadDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LoginPayloadDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LoginPayloadDto value)  $default,){
final _that = this;
switch (_that) {
case _LoginPayloadDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LoginPayloadDto value)?  $default,){
final _that = this;
switch (_that) {
case _LoginPayloadDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? token, @JsonKey(name: 'refresh_token')  String? refreshToken, @JsonKey(name: 'expires_at')  int? expiresAt,  UserDto? user)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LoginPayloadDto() when $default != null:
return $default(_that.token,_that.refreshToken,_that.expiresAt,_that.user);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? token, @JsonKey(name: 'refresh_token')  String? refreshToken, @JsonKey(name: 'expires_at')  int? expiresAt,  UserDto? user)  $default,) {final _that = this;
switch (_that) {
case _LoginPayloadDto():
return $default(_that.token,_that.refreshToken,_that.expiresAt,_that.user);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? token, @JsonKey(name: 'refresh_token')  String? refreshToken, @JsonKey(name: 'expires_at')  int? expiresAt,  UserDto? user)?  $default,) {final _that = this;
switch (_that) {
case _LoginPayloadDto() when $default != null:
return $default(_that.token,_that.refreshToken,_that.expiresAt,_that.user);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LoginPayloadDto implements LoginPayloadDto {
  const _LoginPayloadDto({this.token, @JsonKey(name: 'refresh_token') this.refreshToken, @JsonKey(name: 'expires_at') this.expiresAt, this.user});
  factory _LoginPayloadDto.fromJson(Map<String, dynamic> json) => _$LoginPayloadDtoFromJson(json);

@override final  String? token;
@override@JsonKey(name: 'refresh_token') final  String? refreshToken;
@override@JsonKey(name: 'expires_at') final  int? expiresAt;
@override final  UserDto? user;

/// Create a copy of LoginPayloadDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LoginPayloadDtoCopyWith<_LoginPayloadDto> get copyWith => __$LoginPayloadDtoCopyWithImpl<_LoginPayloadDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LoginPayloadDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LoginPayloadDto&&(identical(other.token, token) || other.token == token)&&(identical(other.refreshToken, refreshToken) || other.refreshToken == refreshToken)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt)&&(identical(other.user, user) || other.user == user));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,token,refreshToken,expiresAt,user);

@override
String toString() {
  return 'LoginPayloadDto(token: $token, refreshToken: $refreshToken, expiresAt: $expiresAt, user: $user)';
}


}

/// @nodoc
abstract mixin class _$LoginPayloadDtoCopyWith<$Res> implements $LoginPayloadDtoCopyWith<$Res> {
  factory _$LoginPayloadDtoCopyWith(_LoginPayloadDto value, $Res Function(_LoginPayloadDto) _then) = __$LoginPayloadDtoCopyWithImpl;
@override @useResult
$Res call({
 String? token,@JsonKey(name: 'refresh_token') String? refreshToken,@JsonKey(name: 'expires_at') int? expiresAt, UserDto? user
});


@override $UserDtoCopyWith<$Res>? get user;

}
/// @nodoc
class __$LoginPayloadDtoCopyWithImpl<$Res>
    implements _$LoginPayloadDtoCopyWith<$Res> {
  __$LoginPayloadDtoCopyWithImpl(this._self, this._then);

  final _LoginPayloadDto _self;
  final $Res Function(_LoginPayloadDto) _then;

/// Create a copy of LoginPayloadDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? token = freezed,Object? refreshToken = freezed,Object? expiresAt = freezed,Object? user = freezed,}) {
  return _then(_LoginPayloadDto(
token: freezed == token ? _self.token : token // ignore: cast_nullable_to_non_nullable
as String?,refreshToken: freezed == refreshToken ? _self.refreshToken : refreshToken // ignore: cast_nullable_to_non_nullable
as String?,expiresAt: freezed == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as int?,user: freezed == user ? _self.user : user // ignore: cast_nullable_to_non_nullable
as UserDto?,
  ));
}

/// Create a copy of LoginPayloadDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserDtoCopyWith<$Res>? get user {
    if (_self.user == null) {
    return null;
  }

  return $UserDtoCopyWith<$Res>(_self.user!, (value) {
    return _then(_self.copyWith(user: value));
  });
}
}


/// @nodoc
mixin _$TablesMdClassDto {

 String? get id;@JsonKey(name: 'class_id') String? get classId;@JsonKey(name: 'school_id') String? get schoolId;@JsonKey(name: 'academic_year_id') String? get academicYearId;@JsonKey(name: 'class_name') String? get className;@JsonKey(name: 'class_code') String? get classCode;@JsonKey(name: 'section_id') String? get sectionId;@JsonKey(name: 'class_teacher_id') String? get classTeacherId;@JsonKey(name: 'room_id') String? get roomId; String? get medium;@JsonKey(name: 'sort_order') int? get sortOrder;@JsonKey(name: 'is_active') bool? get isActive;
/// Create a copy of TablesMdClassDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TablesMdClassDtoCopyWith<TablesMdClassDto> get copyWith => _$TablesMdClassDtoCopyWithImpl<TablesMdClassDto>(this as TablesMdClassDto, _$identity);

  /// Serializes this TablesMdClassDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TablesMdClassDto&&(identical(other.id, id) || other.id == id)&&(identical(other.classId, classId) || other.classId == classId)&&(identical(other.schoolId, schoolId) || other.schoolId == schoolId)&&(identical(other.academicYearId, academicYearId) || other.academicYearId == academicYearId)&&(identical(other.className, className) || other.className == className)&&(identical(other.classCode, classCode) || other.classCode == classCode)&&(identical(other.sectionId, sectionId) || other.sectionId == sectionId)&&(identical(other.classTeacherId, classTeacherId) || other.classTeacherId == classTeacherId)&&(identical(other.roomId, roomId) || other.roomId == roomId)&&(identical(other.medium, medium) || other.medium == medium)&&(identical(other.sortOrder, sortOrder) || other.sortOrder == sortOrder)&&(identical(other.isActive, isActive) || other.isActive == isActive));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,classId,schoolId,academicYearId,className,classCode,sectionId,classTeacherId,roomId,medium,sortOrder,isActive);

@override
String toString() {
  return 'TablesMdClassDto(id: $id, classId: $classId, schoolId: $schoolId, academicYearId: $academicYearId, className: $className, classCode: $classCode, sectionId: $sectionId, classTeacherId: $classTeacherId, roomId: $roomId, medium: $medium, sortOrder: $sortOrder, isActive: $isActive)';
}


}

/// @nodoc
abstract mixin class $TablesMdClassDtoCopyWith<$Res>  {
  factory $TablesMdClassDtoCopyWith(TablesMdClassDto value, $Res Function(TablesMdClassDto) _then) = _$TablesMdClassDtoCopyWithImpl;
@useResult
$Res call({
 String? id,@JsonKey(name: 'class_id') String? classId,@JsonKey(name: 'school_id') String? schoolId,@JsonKey(name: 'academic_year_id') String? academicYearId,@JsonKey(name: 'class_name') String? className,@JsonKey(name: 'class_code') String? classCode,@JsonKey(name: 'section_id') String? sectionId,@JsonKey(name: 'class_teacher_id') String? classTeacherId,@JsonKey(name: 'room_id') String? roomId, String? medium,@JsonKey(name: 'sort_order') int? sortOrder,@JsonKey(name: 'is_active') bool? isActive
});




}
/// @nodoc
class _$TablesMdClassDtoCopyWithImpl<$Res>
    implements $TablesMdClassDtoCopyWith<$Res> {
  _$TablesMdClassDtoCopyWithImpl(this._self, this._then);

  final TablesMdClassDto _self;
  final $Res Function(TablesMdClassDto) _then;

/// Create a copy of TablesMdClassDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = freezed,Object? classId = freezed,Object? schoolId = freezed,Object? academicYearId = freezed,Object? className = freezed,Object? classCode = freezed,Object? sectionId = freezed,Object? classTeacherId = freezed,Object? roomId = freezed,Object? medium = freezed,Object? sortOrder = freezed,Object? isActive = freezed,}) {
  return _then(_self.copyWith(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,classId: freezed == classId ? _self.classId : classId // ignore: cast_nullable_to_non_nullable
as String?,schoolId: freezed == schoolId ? _self.schoolId : schoolId // ignore: cast_nullable_to_non_nullable
as String?,academicYearId: freezed == academicYearId ? _self.academicYearId : academicYearId // ignore: cast_nullable_to_non_nullable
as String?,className: freezed == className ? _self.className : className // ignore: cast_nullable_to_non_nullable
as String?,classCode: freezed == classCode ? _self.classCode : classCode // ignore: cast_nullable_to_non_nullable
as String?,sectionId: freezed == sectionId ? _self.sectionId : sectionId // ignore: cast_nullable_to_non_nullable
as String?,classTeacherId: freezed == classTeacherId ? _self.classTeacherId : classTeacherId // ignore: cast_nullable_to_non_nullable
as String?,roomId: freezed == roomId ? _self.roomId : roomId // ignore: cast_nullable_to_non_nullable
as String?,medium: freezed == medium ? _self.medium : medium // ignore: cast_nullable_to_non_nullable
as String?,sortOrder: freezed == sortOrder ? _self.sortOrder : sortOrder // ignore: cast_nullable_to_non_nullable
as int?,isActive: freezed == isActive ? _self.isActive : isActive // ignore: cast_nullable_to_non_nullable
as bool?,
  ));
}

}


/// Adds pattern-matching-related methods to [TablesMdClassDto].
extension TablesMdClassDtoPatterns on TablesMdClassDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TablesMdClassDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TablesMdClassDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TablesMdClassDto value)  $default,){
final _that = this;
switch (_that) {
case _TablesMdClassDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TablesMdClassDto value)?  $default,){
final _that = this;
switch (_that) {
case _TablesMdClassDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? id, @JsonKey(name: 'class_id')  String? classId, @JsonKey(name: 'school_id')  String? schoolId, @JsonKey(name: 'academic_year_id')  String? academicYearId, @JsonKey(name: 'class_name')  String? className, @JsonKey(name: 'class_code')  String? classCode, @JsonKey(name: 'section_id')  String? sectionId, @JsonKey(name: 'class_teacher_id')  String? classTeacherId, @JsonKey(name: 'room_id')  String? roomId,  String? medium, @JsonKey(name: 'sort_order')  int? sortOrder, @JsonKey(name: 'is_active')  bool? isActive)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TablesMdClassDto() when $default != null:
return $default(_that.id,_that.classId,_that.schoolId,_that.academicYearId,_that.className,_that.classCode,_that.sectionId,_that.classTeacherId,_that.roomId,_that.medium,_that.sortOrder,_that.isActive);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? id, @JsonKey(name: 'class_id')  String? classId, @JsonKey(name: 'school_id')  String? schoolId, @JsonKey(name: 'academic_year_id')  String? academicYearId, @JsonKey(name: 'class_name')  String? className, @JsonKey(name: 'class_code')  String? classCode, @JsonKey(name: 'section_id')  String? sectionId, @JsonKey(name: 'class_teacher_id')  String? classTeacherId, @JsonKey(name: 'room_id')  String? roomId,  String? medium, @JsonKey(name: 'sort_order')  int? sortOrder, @JsonKey(name: 'is_active')  bool? isActive)  $default,) {final _that = this;
switch (_that) {
case _TablesMdClassDto():
return $default(_that.id,_that.classId,_that.schoolId,_that.academicYearId,_that.className,_that.classCode,_that.sectionId,_that.classTeacherId,_that.roomId,_that.medium,_that.sortOrder,_that.isActive);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? id, @JsonKey(name: 'class_id')  String? classId, @JsonKey(name: 'school_id')  String? schoolId, @JsonKey(name: 'academic_year_id')  String? academicYearId, @JsonKey(name: 'class_name')  String? className, @JsonKey(name: 'class_code')  String? classCode, @JsonKey(name: 'section_id')  String? sectionId, @JsonKey(name: 'class_teacher_id')  String? classTeacherId, @JsonKey(name: 'room_id')  String? roomId,  String? medium, @JsonKey(name: 'sort_order')  int? sortOrder, @JsonKey(name: 'is_active')  bool? isActive)?  $default,) {final _that = this;
switch (_that) {
case _TablesMdClassDto() when $default != null:
return $default(_that.id,_that.classId,_that.schoolId,_that.academicYearId,_that.className,_that.classCode,_that.sectionId,_that.classTeacherId,_that.roomId,_that.medium,_that.sortOrder,_that.isActive);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TablesMdClassDto implements TablesMdClassDto {
  const _TablesMdClassDto({this.id, @JsonKey(name: 'class_id') this.classId, @JsonKey(name: 'school_id') this.schoolId, @JsonKey(name: 'academic_year_id') this.academicYearId, @JsonKey(name: 'class_name') this.className, @JsonKey(name: 'class_code') this.classCode, @JsonKey(name: 'section_id') this.sectionId, @JsonKey(name: 'class_teacher_id') this.classTeacherId, @JsonKey(name: 'room_id') this.roomId, this.medium, @JsonKey(name: 'sort_order') this.sortOrder, @JsonKey(name: 'is_active') this.isActive});
  factory _TablesMdClassDto.fromJson(Map<String, dynamic> json) => _$TablesMdClassDtoFromJson(json);

@override final  String? id;
@override@JsonKey(name: 'class_id') final  String? classId;
@override@JsonKey(name: 'school_id') final  String? schoolId;
@override@JsonKey(name: 'academic_year_id') final  String? academicYearId;
@override@JsonKey(name: 'class_name') final  String? className;
@override@JsonKey(name: 'class_code') final  String? classCode;
@override@JsonKey(name: 'section_id') final  String? sectionId;
@override@JsonKey(name: 'class_teacher_id') final  String? classTeacherId;
@override@JsonKey(name: 'room_id') final  String? roomId;
@override final  String? medium;
@override@JsonKey(name: 'sort_order') final  int? sortOrder;
@override@JsonKey(name: 'is_active') final  bool? isActive;

/// Create a copy of TablesMdClassDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TablesMdClassDtoCopyWith<_TablesMdClassDto> get copyWith => __$TablesMdClassDtoCopyWithImpl<_TablesMdClassDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TablesMdClassDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TablesMdClassDto&&(identical(other.id, id) || other.id == id)&&(identical(other.classId, classId) || other.classId == classId)&&(identical(other.schoolId, schoolId) || other.schoolId == schoolId)&&(identical(other.academicYearId, academicYearId) || other.academicYearId == academicYearId)&&(identical(other.className, className) || other.className == className)&&(identical(other.classCode, classCode) || other.classCode == classCode)&&(identical(other.sectionId, sectionId) || other.sectionId == sectionId)&&(identical(other.classTeacherId, classTeacherId) || other.classTeacherId == classTeacherId)&&(identical(other.roomId, roomId) || other.roomId == roomId)&&(identical(other.medium, medium) || other.medium == medium)&&(identical(other.sortOrder, sortOrder) || other.sortOrder == sortOrder)&&(identical(other.isActive, isActive) || other.isActive == isActive));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,classId,schoolId,academicYearId,className,classCode,sectionId,classTeacherId,roomId,medium,sortOrder,isActive);

@override
String toString() {
  return 'TablesMdClassDto(id: $id, classId: $classId, schoolId: $schoolId, academicYearId: $academicYearId, className: $className, classCode: $classCode, sectionId: $sectionId, classTeacherId: $classTeacherId, roomId: $roomId, medium: $medium, sortOrder: $sortOrder, isActive: $isActive)';
}


}

/// @nodoc
abstract mixin class _$TablesMdClassDtoCopyWith<$Res> implements $TablesMdClassDtoCopyWith<$Res> {
  factory _$TablesMdClassDtoCopyWith(_TablesMdClassDto value, $Res Function(_TablesMdClassDto) _then) = __$TablesMdClassDtoCopyWithImpl;
@override @useResult
$Res call({
 String? id,@JsonKey(name: 'class_id') String? classId,@JsonKey(name: 'school_id') String? schoolId,@JsonKey(name: 'academic_year_id') String? academicYearId,@JsonKey(name: 'class_name') String? className,@JsonKey(name: 'class_code') String? classCode,@JsonKey(name: 'section_id') String? sectionId,@JsonKey(name: 'class_teacher_id') String? classTeacherId,@JsonKey(name: 'room_id') String? roomId, String? medium,@JsonKey(name: 'sort_order') int? sortOrder,@JsonKey(name: 'is_active') bool? isActive
});




}
/// @nodoc
class __$TablesMdClassDtoCopyWithImpl<$Res>
    implements _$TablesMdClassDtoCopyWith<$Res> {
  __$TablesMdClassDtoCopyWithImpl(this._self, this._then);

  final _TablesMdClassDto _self;
  final $Res Function(_TablesMdClassDto) _then;

/// Create a copy of TablesMdClassDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = freezed,Object? classId = freezed,Object? schoolId = freezed,Object? academicYearId = freezed,Object? className = freezed,Object? classCode = freezed,Object? sectionId = freezed,Object? classTeacherId = freezed,Object? roomId = freezed,Object? medium = freezed,Object? sortOrder = freezed,Object? isActive = freezed,}) {
  return _then(_TablesMdClassDto(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,classId: freezed == classId ? _self.classId : classId // ignore: cast_nullable_to_non_nullable
as String?,schoolId: freezed == schoolId ? _self.schoolId : schoolId // ignore: cast_nullable_to_non_nullable
as String?,academicYearId: freezed == academicYearId ? _self.academicYearId : academicYearId // ignore: cast_nullable_to_non_nullable
as String?,className: freezed == className ? _self.className : className // ignore: cast_nullable_to_non_nullable
as String?,classCode: freezed == classCode ? _self.classCode : classCode // ignore: cast_nullable_to_non_nullable
as String?,sectionId: freezed == sectionId ? _self.sectionId : sectionId // ignore: cast_nullable_to_non_nullable
as String?,classTeacherId: freezed == classTeacherId ? _self.classTeacherId : classTeacherId // ignore: cast_nullable_to_non_nullable
as String?,roomId: freezed == roomId ? _self.roomId : roomId // ignore: cast_nullable_to_non_nullable
as String?,medium: freezed == medium ? _self.medium : medium // ignore: cast_nullable_to_non_nullable
as String?,sortOrder: freezed == sortOrder ? _self.sortOrder : sortOrder // ignore: cast_nullable_to_non_nullable
as int?,isActive: freezed == isActive ? _self.isActive : isActive // ignore: cast_nullable_to_non_nullable
as bool?,
  ));
}


}


/// @nodoc
mixin _$TablesMdAttendanceDto {

 String? get id;@JsonKey(name: 'attendance_id') String? get attendanceId;@JsonKey(name: 'school_id') String? get schoolId;@JsonKey(name: 'academic_year_id') String? get academicYearId;@JsonKey(name: 'attendance_type') String? get attendanceType;@JsonKey(name: 'student_id') String? get studentId;@JsonKey(name: 'staff_id') String? get staffId;@JsonKey(name: 'class_id') String? get classId;@JsonKey(name: 'section_id') String? get sectionId;@JsonKey(name: 'attendance_date') dynamic get attendanceDate; String? get status;@JsonKey(name: 'marked_by') String? get markedBy; String? get remarks;
/// Create a copy of TablesMdAttendanceDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TablesMdAttendanceDtoCopyWith<TablesMdAttendanceDto> get copyWith => _$TablesMdAttendanceDtoCopyWithImpl<TablesMdAttendanceDto>(this as TablesMdAttendanceDto, _$identity);

  /// Serializes this TablesMdAttendanceDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TablesMdAttendanceDto&&(identical(other.id, id) || other.id == id)&&(identical(other.attendanceId, attendanceId) || other.attendanceId == attendanceId)&&(identical(other.schoolId, schoolId) || other.schoolId == schoolId)&&(identical(other.academicYearId, academicYearId) || other.academicYearId == academicYearId)&&(identical(other.attendanceType, attendanceType) || other.attendanceType == attendanceType)&&(identical(other.studentId, studentId) || other.studentId == studentId)&&(identical(other.staffId, staffId) || other.staffId == staffId)&&(identical(other.classId, classId) || other.classId == classId)&&(identical(other.sectionId, sectionId) || other.sectionId == sectionId)&&const DeepCollectionEquality().equals(other.attendanceDate, attendanceDate)&&(identical(other.status, status) || other.status == status)&&(identical(other.markedBy, markedBy) || other.markedBy == markedBy)&&(identical(other.remarks, remarks) || other.remarks == remarks));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,attendanceId,schoolId,academicYearId,attendanceType,studentId,staffId,classId,sectionId,const DeepCollectionEquality().hash(attendanceDate),status,markedBy,remarks);

@override
String toString() {
  return 'TablesMdAttendanceDto(id: $id, attendanceId: $attendanceId, schoolId: $schoolId, academicYearId: $academicYearId, attendanceType: $attendanceType, studentId: $studentId, staffId: $staffId, classId: $classId, sectionId: $sectionId, attendanceDate: $attendanceDate, status: $status, markedBy: $markedBy, remarks: $remarks)';
}


}

/// @nodoc
abstract mixin class $TablesMdAttendanceDtoCopyWith<$Res>  {
  factory $TablesMdAttendanceDtoCopyWith(TablesMdAttendanceDto value, $Res Function(TablesMdAttendanceDto) _then) = _$TablesMdAttendanceDtoCopyWithImpl;
@useResult
$Res call({
 String? id,@JsonKey(name: 'attendance_id') String? attendanceId,@JsonKey(name: 'school_id') String? schoolId,@JsonKey(name: 'academic_year_id') String? academicYearId,@JsonKey(name: 'attendance_type') String? attendanceType,@JsonKey(name: 'student_id') String? studentId,@JsonKey(name: 'staff_id') String? staffId,@JsonKey(name: 'class_id') String? classId,@JsonKey(name: 'section_id') String? sectionId,@JsonKey(name: 'attendance_date') dynamic attendanceDate, String? status,@JsonKey(name: 'marked_by') String? markedBy, String? remarks
});




}
/// @nodoc
class _$TablesMdAttendanceDtoCopyWithImpl<$Res>
    implements $TablesMdAttendanceDtoCopyWith<$Res> {
  _$TablesMdAttendanceDtoCopyWithImpl(this._self, this._then);

  final TablesMdAttendanceDto _self;
  final $Res Function(TablesMdAttendanceDto) _then;

/// Create a copy of TablesMdAttendanceDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = freezed,Object? attendanceId = freezed,Object? schoolId = freezed,Object? academicYearId = freezed,Object? attendanceType = freezed,Object? studentId = freezed,Object? staffId = freezed,Object? classId = freezed,Object? sectionId = freezed,Object? attendanceDate = freezed,Object? status = freezed,Object? markedBy = freezed,Object? remarks = freezed,}) {
  return _then(_self.copyWith(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,attendanceId: freezed == attendanceId ? _self.attendanceId : attendanceId // ignore: cast_nullable_to_non_nullable
as String?,schoolId: freezed == schoolId ? _self.schoolId : schoolId // ignore: cast_nullable_to_non_nullable
as String?,academicYearId: freezed == academicYearId ? _self.academicYearId : academicYearId // ignore: cast_nullable_to_non_nullable
as String?,attendanceType: freezed == attendanceType ? _self.attendanceType : attendanceType // ignore: cast_nullable_to_non_nullable
as String?,studentId: freezed == studentId ? _self.studentId : studentId // ignore: cast_nullable_to_non_nullable
as String?,staffId: freezed == staffId ? _self.staffId : staffId // ignore: cast_nullable_to_non_nullable
as String?,classId: freezed == classId ? _self.classId : classId // ignore: cast_nullable_to_non_nullable
as String?,sectionId: freezed == sectionId ? _self.sectionId : sectionId // ignore: cast_nullable_to_non_nullable
as String?,attendanceDate: freezed == attendanceDate ? _self.attendanceDate : attendanceDate // ignore: cast_nullable_to_non_nullable
as dynamic,status: freezed == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String?,markedBy: freezed == markedBy ? _self.markedBy : markedBy // ignore: cast_nullable_to_non_nullable
as String?,remarks: freezed == remarks ? _self.remarks : remarks // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [TablesMdAttendanceDto].
extension TablesMdAttendanceDtoPatterns on TablesMdAttendanceDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TablesMdAttendanceDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TablesMdAttendanceDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TablesMdAttendanceDto value)  $default,){
final _that = this;
switch (_that) {
case _TablesMdAttendanceDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TablesMdAttendanceDto value)?  $default,){
final _that = this;
switch (_that) {
case _TablesMdAttendanceDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? id, @JsonKey(name: 'attendance_id')  String? attendanceId, @JsonKey(name: 'school_id')  String? schoolId, @JsonKey(name: 'academic_year_id')  String? academicYearId, @JsonKey(name: 'attendance_type')  String? attendanceType, @JsonKey(name: 'student_id')  String? studentId, @JsonKey(name: 'staff_id')  String? staffId, @JsonKey(name: 'class_id')  String? classId, @JsonKey(name: 'section_id')  String? sectionId, @JsonKey(name: 'attendance_date')  dynamic attendanceDate,  String? status, @JsonKey(name: 'marked_by')  String? markedBy,  String? remarks)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TablesMdAttendanceDto() when $default != null:
return $default(_that.id,_that.attendanceId,_that.schoolId,_that.academicYearId,_that.attendanceType,_that.studentId,_that.staffId,_that.classId,_that.sectionId,_that.attendanceDate,_that.status,_that.markedBy,_that.remarks);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? id, @JsonKey(name: 'attendance_id')  String? attendanceId, @JsonKey(name: 'school_id')  String? schoolId, @JsonKey(name: 'academic_year_id')  String? academicYearId, @JsonKey(name: 'attendance_type')  String? attendanceType, @JsonKey(name: 'student_id')  String? studentId, @JsonKey(name: 'staff_id')  String? staffId, @JsonKey(name: 'class_id')  String? classId, @JsonKey(name: 'section_id')  String? sectionId, @JsonKey(name: 'attendance_date')  dynamic attendanceDate,  String? status, @JsonKey(name: 'marked_by')  String? markedBy,  String? remarks)  $default,) {final _that = this;
switch (_that) {
case _TablesMdAttendanceDto():
return $default(_that.id,_that.attendanceId,_that.schoolId,_that.academicYearId,_that.attendanceType,_that.studentId,_that.staffId,_that.classId,_that.sectionId,_that.attendanceDate,_that.status,_that.markedBy,_that.remarks);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? id, @JsonKey(name: 'attendance_id')  String? attendanceId, @JsonKey(name: 'school_id')  String? schoolId, @JsonKey(name: 'academic_year_id')  String? academicYearId, @JsonKey(name: 'attendance_type')  String? attendanceType, @JsonKey(name: 'student_id')  String? studentId, @JsonKey(name: 'staff_id')  String? staffId, @JsonKey(name: 'class_id')  String? classId, @JsonKey(name: 'section_id')  String? sectionId, @JsonKey(name: 'attendance_date')  dynamic attendanceDate,  String? status, @JsonKey(name: 'marked_by')  String? markedBy,  String? remarks)?  $default,) {final _that = this;
switch (_that) {
case _TablesMdAttendanceDto() when $default != null:
return $default(_that.id,_that.attendanceId,_that.schoolId,_that.academicYearId,_that.attendanceType,_that.studentId,_that.staffId,_that.classId,_that.sectionId,_that.attendanceDate,_that.status,_that.markedBy,_that.remarks);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TablesMdAttendanceDto implements TablesMdAttendanceDto {
  const _TablesMdAttendanceDto({this.id, @JsonKey(name: 'attendance_id') this.attendanceId, @JsonKey(name: 'school_id') this.schoolId, @JsonKey(name: 'academic_year_id') this.academicYearId, @JsonKey(name: 'attendance_type') this.attendanceType, @JsonKey(name: 'student_id') this.studentId, @JsonKey(name: 'staff_id') this.staffId, @JsonKey(name: 'class_id') this.classId, @JsonKey(name: 'section_id') this.sectionId, @JsonKey(name: 'attendance_date') this.attendanceDate, this.status, @JsonKey(name: 'marked_by') this.markedBy, this.remarks});
  factory _TablesMdAttendanceDto.fromJson(Map<String, dynamic> json) => _$TablesMdAttendanceDtoFromJson(json);

@override final  String? id;
@override@JsonKey(name: 'attendance_id') final  String? attendanceId;
@override@JsonKey(name: 'school_id') final  String? schoolId;
@override@JsonKey(name: 'academic_year_id') final  String? academicYearId;
@override@JsonKey(name: 'attendance_type') final  String? attendanceType;
@override@JsonKey(name: 'student_id') final  String? studentId;
@override@JsonKey(name: 'staff_id') final  String? staffId;
@override@JsonKey(name: 'class_id') final  String? classId;
@override@JsonKey(name: 'section_id') final  String? sectionId;
@override@JsonKey(name: 'attendance_date') final  dynamic attendanceDate;
@override final  String? status;
@override@JsonKey(name: 'marked_by') final  String? markedBy;
@override final  String? remarks;

/// Create a copy of TablesMdAttendanceDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TablesMdAttendanceDtoCopyWith<_TablesMdAttendanceDto> get copyWith => __$TablesMdAttendanceDtoCopyWithImpl<_TablesMdAttendanceDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TablesMdAttendanceDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TablesMdAttendanceDto&&(identical(other.id, id) || other.id == id)&&(identical(other.attendanceId, attendanceId) || other.attendanceId == attendanceId)&&(identical(other.schoolId, schoolId) || other.schoolId == schoolId)&&(identical(other.academicYearId, academicYearId) || other.academicYearId == academicYearId)&&(identical(other.attendanceType, attendanceType) || other.attendanceType == attendanceType)&&(identical(other.studentId, studentId) || other.studentId == studentId)&&(identical(other.staffId, staffId) || other.staffId == staffId)&&(identical(other.classId, classId) || other.classId == classId)&&(identical(other.sectionId, sectionId) || other.sectionId == sectionId)&&const DeepCollectionEquality().equals(other.attendanceDate, attendanceDate)&&(identical(other.status, status) || other.status == status)&&(identical(other.markedBy, markedBy) || other.markedBy == markedBy)&&(identical(other.remarks, remarks) || other.remarks == remarks));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,attendanceId,schoolId,academicYearId,attendanceType,studentId,staffId,classId,sectionId,const DeepCollectionEquality().hash(attendanceDate),status,markedBy,remarks);

@override
String toString() {
  return 'TablesMdAttendanceDto(id: $id, attendanceId: $attendanceId, schoolId: $schoolId, academicYearId: $academicYearId, attendanceType: $attendanceType, studentId: $studentId, staffId: $staffId, classId: $classId, sectionId: $sectionId, attendanceDate: $attendanceDate, status: $status, markedBy: $markedBy, remarks: $remarks)';
}


}

/// @nodoc
abstract mixin class _$TablesMdAttendanceDtoCopyWith<$Res> implements $TablesMdAttendanceDtoCopyWith<$Res> {
  factory _$TablesMdAttendanceDtoCopyWith(_TablesMdAttendanceDto value, $Res Function(_TablesMdAttendanceDto) _then) = __$TablesMdAttendanceDtoCopyWithImpl;
@override @useResult
$Res call({
 String? id,@JsonKey(name: 'attendance_id') String? attendanceId,@JsonKey(name: 'school_id') String? schoolId,@JsonKey(name: 'academic_year_id') String? academicYearId,@JsonKey(name: 'attendance_type') String? attendanceType,@JsonKey(name: 'student_id') String? studentId,@JsonKey(name: 'staff_id') String? staffId,@JsonKey(name: 'class_id') String? classId,@JsonKey(name: 'section_id') String? sectionId,@JsonKey(name: 'attendance_date') dynamic attendanceDate, String? status,@JsonKey(name: 'marked_by') String? markedBy, String? remarks
});




}
/// @nodoc
class __$TablesMdAttendanceDtoCopyWithImpl<$Res>
    implements _$TablesMdAttendanceDtoCopyWith<$Res> {
  __$TablesMdAttendanceDtoCopyWithImpl(this._self, this._then);

  final _TablesMdAttendanceDto _self;
  final $Res Function(_TablesMdAttendanceDto) _then;

/// Create a copy of TablesMdAttendanceDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = freezed,Object? attendanceId = freezed,Object? schoolId = freezed,Object? academicYearId = freezed,Object? attendanceType = freezed,Object? studentId = freezed,Object? staffId = freezed,Object? classId = freezed,Object? sectionId = freezed,Object? attendanceDate = freezed,Object? status = freezed,Object? markedBy = freezed,Object? remarks = freezed,}) {
  return _then(_TablesMdAttendanceDto(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,attendanceId: freezed == attendanceId ? _self.attendanceId : attendanceId // ignore: cast_nullable_to_non_nullable
as String?,schoolId: freezed == schoolId ? _self.schoolId : schoolId // ignore: cast_nullable_to_non_nullable
as String?,academicYearId: freezed == academicYearId ? _self.academicYearId : academicYearId // ignore: cast_nullable_to_non_nullable
as String?,attendanceType: freezed == attendanceType ? _self.attendanceType : attendanceType // ignore: cast_nullable_to_non_nullable
as String?,studentId: freezed == studentId ? _self.studentId : studentId // ignore: cast_nullable_to_non_nullable
as String?,staffId: freezed == staffId ? _self.staffId : staffId // ignore: cast_nullable_to_non_nullable
as String?,classId: freezed == classId ? _self.classId : classId // ignore: cast_nullable_to_non_nullable
as String?,sectionId: freezed == sectionId ? _self.sectionId : sectionId // ignore: cast_nullable_to_non_nullable
as String?,attendanceDate: freezed == attendanceDate ? _self.attendanceDate : attendanceDate // ignore: cast_nullable_to_non_nullable
as dynamic,status: freezed == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String?,markedBy: freezed == markedBy ? _self.markedBy : markedBy // ignore: cast_nullable_to_non_nullable
as String?,remarks: freezed == remarks ? _self.remarks : remarks // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$TablesMdFeeDto {

 String? get id;@JsonKey(name: 'fee_id') String? get feeId;@JsonKey(name: 'school_id') String? get schoolId;@JsonKey(name: 'academic_year_id') String? get academicYearId;@JsonKey(name: 'student_id') String? get studentId;@JsonKey(name: 'class_id') String? get classId;@JsonKey(name: 'section_id') String? get sectionId;@JsonKey(name: 'fee_type_id') String? get feeTypeId;@JsonKey(name: 'invoice_no') String? get invoiceNo;@JsonKey(name: 'receipt_no') String? get receiptNo;@JsonKey(name: 'due_date') dynamic get dueDate; num? get amount;@JsonKey(name: 'discount_amount') num? get discountAmount;@JsonKey(name: 'fine_amount') num? get fineAmount;@JsonKey(name: 'paid_amount') num? get paidAmount;@JsonKey(name: 'balance_amount') num? get balanceAmount;@JsonKey(name: 'payment_mode') String? get paymentMode;@JsonKey(name: 'payment_status') String? get paymentStatus;@JsonKey(name: 'transaction_id') String? get transactionId; String? get remarks;
/// Create a copy of TablesMdFeeDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TablesMdFeeDtoCopyWith<TablesMdFeeDto> get copyWith => _$TablesMdFeeDtoCopyWithImpl<TablesMdFeeDto>(this as TablesMdFeeDto, _$identity);

  /// Serializes this TablesMdFeeDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TablesMdFeeDto&&(identical(other.id, id) || other.id == id)&&(identical(other.feeId, feeId) || other.feeId == feeId)&&(identical(other.schoolId, schoolId) || other.schoolId == schoolId)&&(identical(other.academicYearId, academicYearId) || other.academicYearId == academicYearId)&&(identical(other.studentId, studentId) || other.studentId == studentId)&&(identical(other.classId, classId) || other.classId == classId)&&(identical(other.sectionId, sectionId) || other.sectionId == sectionId)&&(identical(other.feeTypeId, feeTypeId) || other.feeTypeId == feeTypeId)&&(identical(other.invoiceNo, invoiceNo) || other.invoiceNo == invoiceNo)&&(identical(other.receiptNo, receiptNo) || other.receiptNo == receiptNo)&&const DeepCollectionEquality().equals(other.dueDate, dueDate)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.discountAmount, discountAmount) || other.discountAmount == discountAmount)&&(identical(other.fineAmount, fineAmount) || other.fineAmount == fineAmount)&&(identical(other.paidAmount, paidAmount) || other.paidAmount == paidAmount)&&(identical(other.balanceAmount, balanceAmount) || other.balanceAmount == balanceAmount)&&(identical(other.paymentMode, paymentMode) || other.paymentMode == paymentMode)&&(identical(other.paymentStatus, paymentStatus) || other.paymentStatus == paymentStatus)&&(identical(other.transactionId, transactionId) || other.transactionId == transactionId)&&(identical(other.remarks, remarks) || other.remarks == remarks));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,feeId,schoolId,academicYearId,studentId,classId,sectionId,feeTypeId,invoiceNo,receiptNo,const DeepCollectionEquality().hash(dueDate),amount,discountAmount,fineAmount,paidAmount,balanceAmount,paymentMode,paymentStatus,transactionId,remarks]);

@override
String toString() {
  return 'TablesMdFeeDto(id: $id, feeId: $feeId, schoolId: $schoolId, academicYearId: $academicYearId, studentId: $studentId, classId: $classId, sectionId: $sectionId, feeTypeId: $feeTypeId, invoiceNo: $invoiceNo, receiptNo: $receiptNo, dueDate: $dueDate, amount: $amount, discountAmount: $discountAmount, fineAmount: $fineAmount, paidAmount: $paidAmount, balanceAmount: $balanceAmount, paymentMode: $paymentMode, paymentStatus: $paymentStatus, transactionId: $transactionId, remarks: $remarks)';
}


}

/// @nodoc
abstract mixin class $TablesMdFeeDtoCopyWith<$Res>  {
  factory $TablesMdFeeDtoCopyWith(TablesMdFeeDto value, $Res Function(TablesMdFeeDto) _then) = _$TablesMdFeeDtoCopyWithImpl;
@useResult
$Res call({
 String? id,@JsonKey(name: 'fee_id') String? feeId,@JsonKey(name: 'school_id') String? schoolId,@JsonKey(name: 'academic_year_id') String? academicYearId,@JsonKey(name: 'student_id') String? studentId,@JsonKey(name: 'class_id') String? classId,@JsonKey(name: 'section_id') String? sectionId,@JsonKey(name: 'fee_type_id') String? feeTypeId,@JsonKey(name: 'invoice_no') String? invoiceNo,@JsonKey(name: 'receipt_no') String? receiptNo,@JsonKey(name: 'due_date') dynamic dueDate, num? amount,@JsonKey(name: 'discount_amount') num? discountAmount,@JsonKey(name: 'fine_amount') num? fineAmount,@JsonKey(name: 'paid_amount') num? paidAmount,@JsonKey(name: 'balance_amount') num? balanceAmount,@JsonKey(name: 'payment_mode') String? paymentMode,@JsonKey(name: 'payment_status') String? paymentStatus,@JsonKey(name: 'transaction_id') String? transactionId, String? remarks
});




}
/// @nodoc
class _$TablesMdFeeDtoCopyWithImpl<$Res>
    implements $TablesMdFeeDtoCopyWith<$Res> {
  _$TablesMdFeeDtoCopyWithImpl(this._self, this._then);

  final TablesMdFeeDto _self;
  final $Res Function(TablesMdFeeDto) _then;

/// Create a copy of TablesMdFeeDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = freezed,Object? feeId = freezed,Object? schoolId = freezed,Object? academicYearId = freezed,Object? studentId = freezed,Object? classId = freezed,Object? sectionId = freezed,Object? feeTypeId = freezed,Object? invoiceNo = freezed,Object? receiptNo = freezed,Object? dueDate = freezed,Object? amount = freezed,Object? discountAmount = freezed,Object? fineAmount = freezed,Object? paidAmount = freezed,Object? balanceAmount = freezed,Object? paymentMode = freezed,Object? paymentStatus = freezed,Object? transactionId = freezed,Object? remarks = freezed,}) {
  return _then(_self.copyWith(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,feeId: freezed == feeId ? _self.feeId : feeId // ignore: cast_nullable_to_non_nullable
as String?,schoolId: freezed == schoolId ? _self.schoolId : schoolId // ignore: cast_nullable_to_non_nullable
as String?,academicYearId: freezed == academicYearId ? _self.academicYearId : academicYearId // ignore: cast_nullable_to_non_nullable
as String?,studentId: freezed == studentId ? _self.studentId : studentId // ignore: cast_nullable_to_non_nullable
as String?,classId: freezed == classId ? _self.classId : classId // ignore: cast_nullable_to_non_nullable
as String?,sectionId: freezed == sectionId ? _self.sectionId : sectionId // ignore: cast_nullable_to_non_nullable
as String?,feeTypeId: freezed == feeTypeId ? _self.feeTypeId : feeTypeId // ignore: cast_nullable_to_non_nullable
as String?,invoiceNo: freezed == invoiceNo ? _self.invoiceNo : invoiceNo // ignore: cast_nullable_to_non_nullable
as String?,receiptNo: freezed == receiptNo ? _self.receiptNo : receiptNo // ignore: cast_nullable_to_non_nullable
as String?,dueDate: freezed == dueDate ? _self.dueDate : dueDate // ignore: cast_nullable_to_non_nullable
as dynamic,amount: freezed == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as num?,discountAmount: freezed == discountAmount ? _self.discountAmount : discountAmount // ignore: cast_nullable_to_non_nullable
as num?,fineAmount: freezed == fineAmount ? _self.fineAmount : fineAmount // ignore: cast_nullable_to_non_nullable
as num?,paidAmount: freezed == paidAmount ? _self.paidAmount : paidAmount // ignore: cast_nullable_to_non_nullable
as num?,balanceAmount: freezed == balanceAmount ? _self.balanceAmount : balanceAmount // ignore: cast_nullable_to_non_nullable
as num?,paymentMode: freezed == paymentMode ? _self.paymentMode : paymentMode // ignore: cast_nullable_to_non_nullable
as String?,paymentStatus: freezed == paymentStatus ? _self.paymentStatus : paymentStatus // ignore: cast_nullable_to_non_nullable
as String?,transactionId: freezed == transactionId ? _self.transactionId : transactionId // ignore: cast_nullable_to_non_nullable
as String?,remarks: freezed == remarks ? _self.remarks : remarks // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [TablesMdFeeDto].
extension TablesMdFeeDtoPatterns on TablesMdFeeDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TablesMdFeeDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TablesMdFeeDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TablesMdFeeDto value)  $default,){
final _that = this;
switch (_that) {
case _TablesMdFeeDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TablesMdFeeDto value)?  $default,){
final _that = this;
switch (_that) {
case _TablesMdFeeDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? id, @JsonKey(name: 'fee_id')  String? feeId, @JsonKey(name: 'school_id')  String? schoolId, @JsonKey(name: 'academic_year_id')  String? academicYearId, @JsonKey(name: 'student_id')  String? studentId, @JsonKey(name: 'class_id')  String? classId, @JsonKey(name: 'section_id')  String? sectionId, @JsonKey(name: 'fee_type_id')  String? feeTypeId, @JsonKey(name: 'invoice_no')  String? invoiceNo, @JsonKey(name: 'receipt_no')  String? receiptNo, @JsonKey(name: 'due_date')  dynamic dueDate,  num? amount, @JsonKey(name: 'discount_amount')  num? discountAmount, @JsonKey(name: 'fine_amount')  num? fineAmount, @JsonKey(name: 'paid_amount')  num? paidAmount, @JsonKey(name: 'balance_amount')  num? balanceAmount, @JsonKey(name: 'payment_mode')  String? paymentMode, @JsonKey(name: 'payment_status')  String? paymentStatus, @JsonKey(name: 'transaction_id')  String? transactionId,  String? remarks)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TablesMdFeeDto() when $default != null:
return $default(_that.id,_that.feeId,_that.schoolId,_that.academicYearId,_that.studentId,_that.classId,_that.sectionId,_that.feeTypeId,_that.invoiceNo,_that.receiptNo,_that.dueDate,_that.amount,_that.discountAmount,_that.fineAmount,_that.paidAmount,_that.balanceAmount,_that.paymentMode,_that.paymentStatus,_that.transactionId,_that.remarks);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? id, @JsonKey(name: 'fee_id')  String? feeId, @JsonKey(name: 'school_id')  String? schoolId, @JsonKey(name: 'academic_year_id')  String? academicYearId, @JsonKey(name: 'student_id')  String? studentId, @JsonKey(name: 'class_id')  String? classId, @JsonKey(name: 'section_id')  String? sectionId, @JsonKey(name: 'fee_type_id')  String? feeTypeId, @JsonKey(name: 'invoice_no')  String? invoiceNo, @JsonKey(name: 'receipt_no')  String? receiptNo, @JsonKey(name: 'due_date')  dynamic dueDate,  num? amount, @JsonKey(name: 'discount_amount')  num? discountAmount, @JsonKey(name: 'fine_amount')  num? fineAmount, @JsonKey(name: 'paid_amount')  num? paidAmount, @JsonKey(name: 'balance_amount')  num? balanceAmount, @JsonKey(name: 'payment_mode')  String? paymentMode, @JsonKey(name: 'payment_status')  String? paymentStatus, @JsonKey(name: 'transaction_id')  String? transactionId,  String? remarks)  $default,) {final _that = this;
switch (_that) {
case _TablesMdFeeDto():
return $default(_that.id,_that.feeId,_that.schoolId,_that.academicYearId,_that.studentId,_that.classId,_that.sectionId,_that.feeTypeId,_that.invoiceNo,_that.receiptNo,_that.dueDate,_that.amount,_that.discountAmount,_that.fineAmount,_that.paidAmount,_that.balanceAmount,_that.paymentMode,_that.paymentStatus,_that.transactionId,_that.remarks);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? id, @JsonKey(name: 'fee_id')  String? feeId, @JsonKey(name: 'school_id')  String? schoolId, @JsonKey(name: 'academic_year_id')  String? academicYearId, @JsonKey(name: 'student_id')  String? studentId, @JsonKey(name: 'class_id')  String? classId, @JsonKey(name: 'section_id')  String? sectionId, @JsonKey(name: 'fee_type_id')  String? feeTypeId, @JsonKey(name: 'invoice_no')  String? invoiceNo, @JsonKey(name: 'receipt_no')  String? receiptNo, @JsonKey(name: 'due_date')  dynamic dueDate,  num? amount, @JsonKey(name: 'discount_amount')  num? discountAmount, @JsonKey(name: 'fine_amount')  num? fineAmount, @JsonKey(name: 'paid_amount')  num? paidAmount, @JsonKey(name: 'balance_amount')  num? balanceAmount, @JsonKey(name: 'payment_mode')  String? paymentMode, @JsonKey(name: 'payment_status')  String? paymentStatus, @JsonKey(name: 'transaction_id')  String? transactionId,  String? remarks)?  $default,) {final _that = this;
switch (_that) {
case _TablesMdFeeDto() when $default != null:
return $default(_that.id,_that.feeId,_that.schoolId,_that.academicYearId,_that.studentId,_that.classId,_that.sectionId,_that.feeTypeId,_that.invoiceNo,_that.receiptNo,_that.dueDate,_that.amount,_that.discountAmount,_that.fineAmount,_that.paidAmount,_that.balanceAmount,_that.paymentMode,_that.paymentStatus,_that.transactionId,_that.remarks);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TablesMdFeeDto implements TablesMdFeeDto {
  const _TablesMdFeeDto({this.id, @JsonKey(name: 'fee_id') this.feeId, @JsonKey(name: 'school_id') this.schoolId, @JsonKey(name: 'academic_year_id') this.academicYearId, @JsonKey(name: 'student_id') this.studentId, @JsonKey(name: 'class_id') this.classId, @JsonKey(name: 'section_id') this.sectionId, @JsonKey(name: 'fee_type_id') this.feeTypeId, @JsonKey(name: 'invoice_no') this.invoiceNo, @JsonKey(name: 'receipt_no') this.receiptNo, @JsonKey(name: 'due_date') this.dueDate, this.amount, @JsonKey(name: 'discount_amount') this.discountAmount, @JsonKey(name: 'fine_amount') this.fineAmount, @JsonKey(name: 'paid_amount') this.paidAmount, @JsonKey(name: 'balance_amount') this.balanceAmount, @JsonKey(name: 'payment_mode') this.paymentMode, @JsonKey(name: 'payment_status') this.paymentStatus, @JsonKey(name: 'transaction_id') this.transactionId, this.remarks});
  factory _TablesMdFeeDto.fromJson(Map<String, dynamic> json) => _$TablesMdFeeDtoFromJson(json);

@override final  String? id;
@override@JsonKey(name: 'fee_id') final  String? feeId;
@override@JsonKey(name: 'school_id') final  String? schoolId;
@override@JsonKey(name: 'academic_year_id') final  String? academicYearId;
@override@JsonKey(name: 'student_id') final  String? studentId;
@override@JsonKey(name: 'class_id') final  String? classId;
@override@JsonKey(name: 'section_id') final  String? sectionId;
@override@JsonKey(name: 'fee_type_id') final  String? feeTypeId;
@override@JsonKey(name: 'invoice_no') final  String? invoiceNo;
@override@JsonKey(name: 'receipt_no') final  String? receiptNo;
@override@JsonKey(name: 'due_date') final  dynamic dueDate;
@override final  num? amount;
@override@JsonKey(name: 'discount_amount') final  num? discountAmount;
@override@JsonKey(name: 'fine_amount') final  num? fineAmount;
@override@JsonKey(name: 'paid_amount') final  num? paidAmount;
@override@JsonKey(name: 'balance_amount') final  num? balanceAmount;
@override@JsonKey(name: 'payment_mode') final  String? paymentMode;
@override@JsonKey(name: 'payment_status') final  String? paymentStatus;
@override@JsonKey(name: 'transaction_id') final  String? transactionId;
@override final  String? remarks;

/// Create a copy of TablesMdFeeDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TablesMdFeeDtoCopyWith<_TablesMdFeeDto> get copyWith => __$TablesMdFeeDtoCopyWithImpl<_TablesMdFeeDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TablesMdFeeDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TablesMdFeeDto&&(identical(other.id, id) || other.id == id)&&(identical(other.feeId, feeId) || other.feeId == feeId)&&(identical(other.schoolId, schoolId) || other.schoolId == schoolId)&&(identical(other.academicYearId, academicYearId) || other.academicYearId == academicYearId)&&(identical(other.studentId, studentId) || other.studentId == studentId)&&(identical(other.classId, classId) || other.classId == classId)&&(identical(other.sectionId, sectionId) || other.sectionId == sectionId)&&(identical(other.feeTypeId, feeTypeId) || other.feeTypeId == feeTypeId)&&(identical(other.invoiceNo, invoiceNo) || other.invoiceNo == invoiceNo)&&(identical(other.receiptNo, receiptNo) || other.receiptNo == receiptNo)&&const DeepCollectionEquality().equals(other.dueDate, dueDate)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.discountAmount, discountAmount) || other.discountAmount == discountAmount)&&(identical(other.fineAmount, fineAmount) || other.fineAmount == fineAmount)&&(identical(other.paidAmount, paidAmount) || other.paidAmount == paidAmount)&&(identical(other.balanceAmount, balanceAmount) || other.balanceAmount == balanceAmount)&&(identical(other.paymentMode, paymentMode) || other.paymentMode == paymentMode)&&(identical(other.paymentStatus, paymentStatus) || other.paymentStatus == paymentStatus)&&(identical(other.transactionId, transactionId) || other.transactionId == transactionId)&&(identical(other.remarks, remarks) || other.remarks == remarks));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,feeId,schoolId,academicYearId,studentId,classId,sectionId,feeTypeId,invoiceNo,receiptNo,const DeepCollectionEquality().hash(dueDate),amount,discountAmount,fineAmount,paidAmount,balanceAmount,paymentMode,paymentStatus,transactionId,remarks]);

@override
String toString() {
  return 'TablesMdFeeDto(id: $id, feeId: $feeId, schoolId: $schoolId, academicYearId: $academicYearId, studentId: $studentId, classId: $classId, sectionId: $sectionId, feeTypeId: $feeTypeId, invoiceNo: $invoiceNo, receiptNo: $receiptNo, dueDate: $dueDate, amount: $amount, discountAmount: $discountAmount, fineAmount: $fineAmount, paidAmount: $paidAmount, balanceAmount: $balanceAmount, paymentMode: $paymentMode, paymentStatus: $paymentStatus, transactionId: $transactionId, remarks: $remarks)';
}


}

/// @nodoc
abstract mixin class _$TablesMdFeeDtoCopyWith<$Res> implements $TablesMdFeeDtoCopyWith<$Res> {
  factory _$TablesMdFeeDtoCopyWith(_TablesMdFeeDto value, $Res Function(_TablesMdFeeDto) _then) = __$TablesMdFeeDtoCopyWithImpl;
@override @useResult
$Res call({
 String? id,@JsonKey(name: 'fee_id') String? feeId,@JsonKey(name: 'school_id') String? schoolId,@JsonKey(name: 'academic_year_id') String? academicYearId,@JsonKey(name: 'student_id') String? studentId,@JsonKey(name: 'class_id') String? classId,@JsonKey(name: 'section_id') String? sectionId,@JsonKey(name: 'fee_type_id') String? feeTypeId,@JsonKey(name: 'invoice_no') String? invoiceNo,@JsonKey(name: 'receipt_no') String? receiptNo,@JsonKey(name: 'due_date') dynamic dueDate, num? amount,@JsonKey(name: 'discount_amount') num? discountAmount,@JsonKey(name: 'fine_amount') num? fineAmount,@JsonKey(name: 'paid_amount') num? paidAmount,@JsonKey(name: 'balance_amount') num? balanceAmount,@JsonKey(name: 'payment_mode') String? paymentMode,@JsonKey(name: 'payment_status') String? paymentStatus,@JsonKey(name: 'transaction_id') String? transactionId, String? remarks
});




}
/// @nodoc
class __$TablesMdFeeDtoCopyWithImpl<$Res>
    implements _$TablesMdFeeDtoCopyWith<$Res> {
  __$TablesMdFeeDtoCopyWithImpl(this._self, this._then);

  final _TablesMdFeeDto _self;
  final $Res Function(_TablesMdFeeDto) _then;

/// Create a copy of TablesMdFeeDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = freezed,Object? feeId = freezed,Object? schoolId = freezed,Object? academicYearId = freezed,Object? studentId = freezed,Object? classId = freezed,Object? sectionId = freezed,Object? feeTypeId = freezed,Object? invoiceNo = freezed,Object? receiptNo = freezed,Object? dueDate = freezed,Object? amount = freezed,Object? discountAmount = freezed,Object? fineAmount = freezed,Object? paidAmount = freezed,Object? balanceAmount = freezed,Object? paymentMode = freezed,Object? paymentStatus = freezed,Object? transactionId = freezed,Object? remarks = freezed,}) {
  return _then(_TablesMdFeeDto(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,feeId: freezed == feeId ? _self.feeId : feeId // ignore: cast_nullable_to_non_nullable
as String?,schoolId: freezed == schoolId ? _self.schoolId : schoolId // ignore: cast_nullable_to_non_nullable
as String?,academicYearId: freezed == academicYearId ? _self.academicYearId : academicYearId // ignore: cast_nullable_to_non_nullable
as String?,studentId: freezed == studentId ? _self.studentId : studentId // ignore: cast_nullable_to_non_nullable
as String?,classId: freezed == classId ? _self.classId : classId // ignore: cast_nullable_to_non_nullable
as String?,sectionId: freezed == sectionId ? _self.sectionId : sectionId // ignore: cast_nullable_to_non_nullable
as String?,feeTypeId: freezed == feeTypeId ? _self.feeTypeId : feeTypeId // ignore: cast_nullable_to_non_nullable
as String?,invoiceNo: freezed == invoiceNo ? _self.invoiceNo : invoiceNo // ignore: cast_nullable_to_non_nullable
as String?,receiptNo: freezed == receiptNo ? _self.receiptNo : receiptNo // ignore: cast_nullable_to_non_nullable
as String?,dueDate: freezed == dueDate ? _self.dueDate : dueDate // ignore: cast_nullable_to_non_nullable
as dynamic,amount: freezed == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as num?,discountAmount: freezed == discountAmount ? _self.discountAmount : discountAmount // ignore: cast_nullable_to_non_nullable
as num?,fineAmount: freezed == fineAmount ? _self.fineAmount : fineAmount // ignore: cast_nullable_to_non_nullable
as num?,paidAmount: freezed == paidAmount ? _self.paidAmount : paidAmount // ignore: cast_nullable_to_non_nullable
as num?,balanceAmount: freezed == balanceAmount ? _self.balanceAmount : balanceAmount // ignore: cast_nullable_to_non_nullable
as num?,paymentMode: freezed == paymentMode ? _self.paymentMode : paymentMode // ignore: cast_nullable_to_non_nullable
as String?,paymentStatus: freezed == paymentStatus ? _self.paymentStatus : paymentStatus // ignore: cast_nullable_to_non_nullable
as String?,transactionId: freezed == transactionId ? _self.transactionId : transactionId // ignore: cast_nullable_to_non_nullable
as String?,remarks: freezed == remarks ? _self.remarks : remarks // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$ExamDto {

 String? get id;@JsonKey(name: 'school_id') String? get schoolId;@JsonKey(name: 'academic_year_id') String? get academicYearId;@JsonKey(name: 'term_id') String? get termId;@JsonKey(name: 'exam_type_id') String? get examTypeId;@JsonKey(name: 'exam_name') String? get examName;@JsonKey(name: 'start_date') dynamic get startDate;@JsonKey(name: 'end_date') dynamic get endDate;@JsonKey(name: 'is_published') bool? get isPublished; List<ExamScheduleDto> get schedules;
/// Create a copy of ExamDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ExamDtoCopyWith<ExamDto> get copyWith => _$ExamDtoCopyWithImpl<ExamDto>(this as ExamDto, _$identity);

  /// Serializes this ExamDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ExamDto&&(identical(other.id, id) || other.id == id)&&(identical(other.schoolId, schoolId) || other.schoolId == schoolId)&&(identical(other.academicYearId, academicYearId) || other.academicYearId == academicYearId)&&(identical(other.termId, termId) || other.termId == termId)&&(identical(other.examTypeId, examTypeId) || other.examTypeId == examTypeId)&&(identical(other.examName, examName) || other.examName == examName)&&const DeepCollectionEquality().equals(other.startDate, startDate)&&const DeepCollectionEquality().equals(other.endDate, endDate)&&(identical(other.isPublished, isPublished) || other.isPublished == isPublished)&&const DeepCollectionEquality().equals(other.schedules, schedules));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,schoolId,academicYearId,termId,examTypeId,examName,const DeepCollectionEquality().hash(startDate),const DeepCollectionEquality().hash(endDate),isPublished,const DeepCollectionEquality().hash(schedules));

@override
String toString() {
  return 'ExamDto(id: $id, schoolId: $schoolId, academicYearId: $academicYearId, termId: $termId, examTypeId: $examTypeId, examName: $examName, startDate: $startDate, endDate: $endDate, isPublished: $isPublished, schedules: $schedules)';
}


}

/// @nodoc
abstract mixin class $ExamDtoCopyWith<$Res>  {
  factory $ExamDtoCopyWith(ExamDto value, $Res Function(ExamDto) _then) = _$ExamDtoCopyWithImpl;
@useResult
$Res call({
 String? id,@JsonKey(name: 'school_id') String? schoolId,@JsonKey(name: 'academic_year_id') String? academicYearId,@JsonKey(name: 'term_id') String? termId,@JsonKey(name: 'exam_type_id') String? examTypeId,@JsonKey(name: 'exam_name') String? examName,@JsonKey(name: 'start_date') dynamic startDate,@JsonKey(name: 'end_date') dynamic endDate,@JsonKey(name: 'is_published') bool? isPublished, List<ExamScheduleDto> schedules
});




}
/// @nodoc
class _$ExamDtoCopyWithImpl<$Res>
    implements $ExamDtoCopyWith<$Res> {
  _$ExamDtoCopyWithImpl(this._self, this._then);

  final ExamDto _self;
  final $Res Function(ExamDto) _then;

/// Create a copy of ExamDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = freezed,Object? schoolId = freezed,Object? academicYearId = freezed,Object? termId = freezed,Object? examTypeId = freezed,Object? examName = freezed,Object? startDate = freezed,Object? endDate = freezed,Object? isPublished = freezed,Object? schedules = null,}) {
  return _then(_self.copyWith(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,schoolId: freezed == schoolId ? _self.schoolId : schoolId // ignore: cast_nullable_to_non_nullable
as String?,academicYearId: freezed == academicYearId ? _self.academicYearId : academicYearId // ignore: cast_nullable_to_non_nullable
as String?,termId: freezed == termId ? _self.termId : termId // ignore: cast_nullable_to_non_nullable
as String?,examTypeId: freezed == examTypeId ? _self.examTypeId : examTypeId // ignore: cast_nullable_to_non_nullable
as String?,examName: freezed == examName ? _self.examName : examName // ignore: cast_nullable_to_non_nullable
as String?,startDate: freezed == startDate ? _self.startDate : startDate // ignore: cast_nullable_to_non_nullable
as dynamic,endDate: freezed == endDate ? _self.endDate : endDate // ignore: cast_nullable_to_non_nullable
as dynamic,isPublished: freezed == isPublished ? _self.isPublished : isPublished // ignore: cast_nullable_to_non_nullable
as bool?,schedules: null == schedules ? _self.schedules : schedules // ignore: cast_nullable_to_non_nullable
as List<ExamScheduleDto>,
  ));
}

}


/// Adds pattern-matching-related methods to [ExamDto].
extension ExamDtoPatterns on ExamDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ExamDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ExamDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ExamDto value)  $default,){
final _that = this;
switch (_that) {
case _ExamDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ExamDto value)?  $default,){
final _that = this;
switch (_that) {
case _ExamDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? id, @JsonKey(name: 'school_id')  String? schoolId, @JsonKey(name: 'academic_year_id')  String? academicYearId, @JsonKey(name: 'term_id')  String? termId, @JsonKey(name: 'exam_type_id')  String? examTypeId, @JsonKey(name: 'exam_name')  String? examName, @JsonKey(name: 'start_date')  dynamic startDate, @JsonKey(name: 'end_date')  dynamic endDate, @JsonKey(name: 'is_published')  bool? isPublished,  List<ExamScheduleDto> schedules)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ExamDto() when $default != null:
return $default(_that.id,_that.schoolId,_that.academicYearId,_that.termId,_that.examTypeId,_that.examName,_that.startDate,_that.endDate,_that.isPublished,_that.schedules);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? id, @JsonKey(name: 'school_id')  String? schoolId, @JsonKey(name: 'academic_year_id')  String? academicYearId, @JsonKey(name: 'term_id')  String? termId, @JsonKey(name: 'exam_type_id')  String? examTypeId, @JsonKey(name: 'exam_name')  String? examName, @JsonKey(name: 'start_date')  dynamic startDate, @JsonKey(name: 'end_date')  dynamic endDate, @JsonKey(name: 'is_published')  bool? isPublished,  List<ExamScheduleDto> schedules)  $default,) {final _that = this;
switch (_that) {
case _ExamDto():
return $default(_that.id,_that.schoolId,_that.academicYearId,_that.termId,_that.examTypeId,_that.examName,_that.startDate,_that.endDate,_that.isPublished,_that.schedules);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? id, @JsonKey(name: 'school_id')  String? schoolId, @JsonKey(name: 'academic_year_id')  String? academicYearId, @JsonKey(name: 'term_id')  String? termId, @JsonKey(name: 'exam_type_id')  String? examTypeId, @JsonKey(name: 'exam_name')  String? examName, @JsonKey(name: 'start_date')  dynamic startDate, @JsonKey(name: 'end_date')  dynamic endDate, @JsonKey(name: 'is_published')  bool? isPublished,  List<ExamScheduleDto> schedules)?  $default,) {final _that = this;
switch (_that) {
case _ExamDto() when $default != null:
return $default(_that.id,_that.schoolId,_that.academicYearId,_that.termId,_that.examTypeId,_that.examName,_that.startDate,_that.endDate,_that.isPublished,_that.schedules);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ExamDto implements ExamDto {
  const _ExamDto({this.id, @JsonKey(name: 'school_id') this.schoolId, @JsonKey(name: 'academic_year_id') this.academicYearId, @JsonKey(name: 'term_id') this.termId, @JsonKey(name: 'exam_type_id') this.examTypeId, @JsonKey(name: 'exam_name') this.examName, @JsonKey(name: 'start_date') this.startDate, @JsonKey(name: 'end_date') this.endDate, @JsonKey(name: 'is_published') this.isPublished, final  List<ExamScheduleDto> schedules = const <ExamScheduleDto>[]}): _schedules = schedules;
  factory _ExamDto.fromJson(Map<String, dynamic> json) => _$ExamDtoFromJson(json);

@override final  String? id;
@override@JsonKey(name: 'school_id') final  String? schoolId;
@override@JsonKey(name: 'academic_year_id') final  String? academicYearId;
@override@JsonKey(name: 'term_id') final  String? termId;
@override@JsonKey(name: 'exam_type_id') final  String? examTypeId;
@override@JsonKey(name: 'exam_name') final  String? examName;
@override@JsonKey(name: 'start_date') final  dynamic startDate;
@override@JsonKey(name: 'end_date') final  dynamic endDate;
@override@JsonKey(name: 'is_published') final  bool? isPublished;
 final  List<ExamScheduleDto> _schedules;
@override@JsonKey() List<ExamScheduleDto> get schedules {
  if (_schedules is EqualUnmodifiableListView) return _schedules;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_schedules);
}


/// Create a copy of ExamDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ExamDtoCopyWith<_ExamDto> get copyWith => __$ExamDtoCopyWithImpl<_ExamDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ExamDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ExamDto&&(identical(other.id, id) || other.id == id)&&(identical(other.schoolId, schoolId) || other.schoolId == schoolId)&&(identical(other.academicYearId, academicYearId) || other.academicYearId == academicYearId)&&(identical(other.termId, termId) || other.termId == termId)&&(identical(other.examTypeId, examTypeId) || other.examTypeId == examTypeId)&&(identical(other.examName, examName) || other.examName == examName)&&const DeepCollectionEquality().equals(other.startDate, startDate)&&const DeepCollectionEquality().equals(other.endDate, endDate)&&(identical(other.isPublished, isPublished) || other.isPublished == isPublished)&&const DeepCollectionEquality().equals(other._schedules, _schedules));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,schoolId,academicYearId,termId,examTypeId,examName,const DeepCollectionEquality().hash(startDate),const DeepCollectionEquality().hash(endDate),isPublished,const DeepCollectionEquality().hash(_schedules));

@override
String toString() {
  return 'ExamDto(id: $id, schoolId: $schoolId, academicYearId: $academicYearId, termId: $termId, examTypeId: $examTypeId, examName: $examName, startDate: $startDate, endDate: $endDate, isPublished: $isPublished, schedules: $schedules)';
}


}

/// @nodoc
abstract mixin class _$ExamDtoCopyWith<$Res> implements $ExamDtoCopyWith<$Res> {
  factory _$ExamDtoCopyWith(_ExamDto value, $Res Function(_ExamDto) _then) = __$ExamDtoCopyWithImpl;
@override @useResult
$Res call({
 String? id,@JsonKey(name: 'school_id') String? schoolId,@JsonKey(name: 'academic_year_id') String? academicYearId,@JsonKey(name: 'term_id') String? termId,@JsonKey(name: 'exam_type_id') String? examTypeId,@JsonKey(name: 'exam_name') String? examName,@JsonKey(name: 'start_date') dynamic startDate,@JsonKey(name: 'end_date') dynamic endDate,@JsonKey(name: 'is_published') bool? isPublished, List<ExamScheduleDto> schedules
});




}
/// @nodoc
class __$ExamDtoCopyWithImpl<$Res>
    implements _$ExamDtoCopyWith<$Res> {
  __$ExamDtoCopyWithImpl(this._self, this._then);

  final _ExamDto _self;
  final $Res Function(_ExamDto) _then;

/// Create a copy of ExamDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = freezed,Object? schoolId = freezed,Object? academicYearId = freezed,Object? termId = freezed,Object? examTypeId = freezed,Object? examName = freezed,Object? startDate = freezed,Object? endDate = freezed,Object? isPublished = freezed,Object? schedules = null,}) {
  return _then(_ExamDto(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,schoolId: freezed == schoolId ? _self.schoolId : schoolId // ignore: cast_nullable_to_non_nullable
as String?,academicYearId: freezed == academicYearId ? _self.academicYearId : academicYearId // ignore: cast_nullable_to_non_nullable
as String?,termId: freezed == termId ? _self.termId : termId // ignore: cast_nullable_to_non_nullable
as String?,examTypeId: freezed == examTypeId ? _self.examTypeId : examTypeId // ignore: cast_nullable_to_non_nullable
as String?,examName: freezed == examName ? _self.examName : examName // ignore: cast_nullable_to_non_nullable
as String?,startDate: freezed == startDate ? _self.startDate : startDate // ignore: cast_nullable_to_non_nullable
as dynamic,endDate: freezed == endDate ? _self.endDate : endDate // ignore: cast_nullable_to_non_nullable
as dynamic,isPublished: freezed == isPublished ? _self.isPublished : isPublished // ignore: cast_nullable_to_non_nullable
as bool?,schedules: null == schedules ? _self._schedules : schedules // ignore: cast_nullable_to_non_nullable
as List<ExamScheduleDto>,
  ));
}


}


/// @nodoc
mixin _$ExamScheduleDto {

 String? get id;@JsonKey(name: 'exam_id') String? get examId;@JsonKey(name: 'grade_id') String? get gradeId;@JsonKey(name: 'section_id') String? get sectionId;@JsonKey(name: 'subject_id') String? get subjectId;@JsonKey(name: 'exam_date') dynamic get examDate;@JsonKey(name: 'start_time') String? get startTime;@JsonKey(name: 'end_time') String? get endTime;@JsonKey(name: 'max_marks') int? get maxMarks;@JsonKey(name: 'pass_marks') int? get passMarks;@JsonKey(name: 'room_id') String? get roomId;
/// Create a copy of ExamScheduleDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ExamScheduleDtoCopyWith<ExamScheduleDto> get copyWith => _$ExamScheduleDtoCopyWithImpl<ExamScheduleDto>(this as ExamScheduleDto, _$identity);

  /// Serializes this ExamScheduleDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ExamScheduleDto&&(identical(other.id, id) || other.id == id)&&(identical(other.examId, examId) || other.examId == examId)&&(identical(other.gradeId, gradeId) || other.gradeId == gradeId)&&(identical(other.sectionId, sectionId) || other.sectionId == sectionId)&&(identical(other.subjectId, subjectId) || other.subjectId == subjectId)&&const DeepCollectionEquality().equals(other.examDate, examDate)&&(identical(other.startTime, startTime) || other.startTime == startTime)&&(identical(other.endTime, endTime) || other.endTime == endTime)&&(identical(other.maxMarks, maxMarks) || other.maxMarks == maxMarks)&&(identical(other.passMarks, passMarks) || other.passMarks == passMarks)&&(identical(other.roomId, roomId) || other.roomId == roomId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,examId,gradeId,sectionId,subjectId,const DeepCollectionEquality().hash(examDate),startTime,endTime,maxMarks,passMarks,roomId);

@override
String toString() {
  return 'ExamScheduleDto(id: $id, examId: $examId, gradeId: $gradeId, sectionId: $sectionId, subjectId: $subjectId, examDate: $examDate, startTime: $startTime, endTime: $endTime, maxMarks: $maxMarks, passMarks: $passMarks, roomId: $roomId)';
}


}

/// @nodoc
abstract mixin class $ExamScheduleDtoCopyWith<$Res>  {
  factory $ExamScheduleDtoCopyWith(ExamScheduleDto value, $Res Function(ExamScheduleDto) _then) = _$ExamScheduleDtoCopyWithImpl;
@useResult
$Res call({
 String? id,@JsonKey(name: 'exam_id') String? examId,@JsonKey(name: 'grade_id') String? gradeId,@JsonKey(name: 'section_id') String? sectionId,@JsonKey(name: 'subject_id') String? subjectId,@JsonKey(name: 'exam_date') dynamic examDate,@JsonKey(name: 'start_time') String? startTime,@JsonKey(name: 'end_time') String? endTime,@JsonKey(name: 'max_marks') int? maxMarks,@JsonKey(name: 'pass_marks') int? passMarks,@JsonKey(name: 'room_id') String? roomId
});




}
/// @nodoc
class _$ExamScheduleDtoCopyWithImpl<$Res>
    implements $ExamScheduleDtoCopyWith<$Res> {
  _$ExamScheduleDtoCopyWithImpl(this._self, this._then);

  final ExamScheduleDto _self;
  final $Res Function(ExamScheduleDto) _then;

/// Create a copy of ExamScheduleDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = freezed,Object? examId = freezed,Object? gradeId = freezed,Object? sectionId = freezed,Object? subjectId = freezed,Object? examDate = freezed,Object? startTime = freezed,Object? endTime = freezed,Object? maxMarks = freezed,Object? passMarks = freezed,Object? roomId = freezed,}) {
  return _then(_self.copyWith(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,examId: freezed == examId ? _self.examId : examId // ignore: cast_nullable_to_non_nullable
as String?,gradeId: freezed == gradeId ? _self.gradeId : gradeId // ignore: cast_nullable_to_non_nullable
as String?,sectionId: freezed == sectionId ? _self.sectionId : sectionId // ignore: cast_nullable_to_non_nullable
as String?,subjectId: freezed == subjectId ? _self.subjectId : subjectId // ignore: cast_nullable_to_non_nullable
as String?,examDate: freezed == examDate ? _self.examDate : examDate // ignore: cast_nullable_to_non_nullable
as dynamic,startTime: freezed == startTime ? _self.startTime : startTime // ignore: cast_nullable_to_non_nullable
as String?,endTime: freezed == endTime ? _self.endTime : endTime // ignore: cast_nullable_to_non_nullable
as String?,maxMarks: freezed == maxMarks ? _self.maxMarks : maxMarks // ignore: cast_nullable_to_non_nullable
as int?,passMarks: freezed == passMarks ? _self.passMarks : passMarks // ignore: cast_nullable_to_non_nullable
as int?,roomId: freezed == roomId ? _self.roomId : roomId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [ExamScheduleDto].
extension ExamScheduleDtoPatterns on ExamScheduleDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ExamScheduleDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ExamScheduleDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ExamScheduleDto value)  $default,){
final _that = this;
switch (_that) {
case _ExamScheduleDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ExamScheduleDto value)?  $default,){
final _that = this;
switch (_that) {
case _ExamScheduleDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? id, @JsonKey(name: 'exam_id')  String? examId, @JsonKey(name: 'grade_id')  String? gradeId, @JsonKey(name: 'section_id')  String? sectionId, @JsonKey(name: 'subject_id')  String? subjectId, @JsonKey(name: 'exam_date')  dynamic examDate, @JsonKey(name: 'start_time')  String? startTime, @JsonKey(name: 'end_time')  String? endTime, @JsonKey(name: 'max_marks')  int? maxMarks, @JsonKey(name: 'pass_marks')  int? passMarks, @JsonKey(name: 'room_id')  String? roomId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ExamScheduleDto() when $default != null:
return $default(_that.id,_that.examId,_that.gradeId,_that.sectionId,_that.subjectId,_that.examDate,_that.startTime,_that.endTime,_that.maxMarks,_that.passMarks,_that.roomId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? id, @JsonKey(name: 'exam_id')  String? examId, @JsonKey(name: 'grade_id')  String? gradeId, @JsonKey(name: 'section_id')  String? sectionId, @JsonKey(name: 'subject_id')  String? subjectId, @JsonKey(name: 'exam_date')  dynamic examDate, @JsonKey(name: 'start_time')  String? startTime, @JsonKey(name: 'end_time')  String? endTime, @JsonKey(name: 'max_marks')  int? maxMarks, @JsonKey(name: 'pass_marks')  int? passMarks, @JsonKey(name: 'room_id')  String? roomId)  $default,) {final _that = this;
switch (_that) {
case _ExamScheduleDto():
return $default(_that.id,_that.examId,_that.gradeId,_that.sectionId,_that.subjectId,_that.examDate,_that.startTime,_that.endTime,_that.maxMarks,_that.passMarks,_that.roomId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? id, @JsonKey(name: 'exam_id')  String? examId, @JsonKey(name: 'grade_id')  String? gradeId, @JsonKey(name: 'section_id')  String? sectionId, @JsonKey(name: 'subject_id')  String? subjectId, @JsonKey(name: 'exam_date')  dynamic examDate, @JsonKey(name: 'start_time')  String? startTime, @JsonKey(name: 'end_time')  String? endTime, @JsonKey(name: 'max_marks')  int? maxMarks, @JsonKey(name: 'pass_marks')  int? passMarks, @JsonKey(name: 'room_id')  String? roomId)?  $default,) {final _that = this;
switch (_that) {
case _ExamScheduleDto() when $default != null:
return $default(_that.id,_that.examId,_that.gradeId,_that.sectionId,_that.subjectId,_that.examDate,_that.startTime,_that.endTime,_that.maxMarks,_that.passMarks,_that.roomId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ExamScheduleDto implements ExamScheduleDto {
  const _ExamScheduleDto({this.id, @JsonKey(name: 'exam_id') this.examId, @JsonKey(name: 'grade_id') this.gradeId, @JsonKey(name: 'section_id') this.sectionId, @JsonKey(name: 'subject_id') this.subjectId, @JsonKey(name: 'exam_date') this.examDate, @JsonKey(name: 'start_time') this.startTime, @JsonKey(name: 'end_time') this.endTime, @JsonKey(name: 'max_marks') this.maxMarks, @JsonKey(name: 'pass_marks') this.passMarks, @JsonKey(name: 'room_id') this.roomId});
  factory _ExamScheduleDto.fromJson(Map<String, dynamic> json) => _$ExamScheduleDtoFromJson(json);

@override final  String? id;
@override@JsonKey(name: 'exam_id') final  String? examId;
@override@JsonKey(name: 'grade_id') final  String? gradeId;
@override@JsonKey(name: 'section_id') final  String? sectionId;
@override@JsonKey(name: 'subject_id') final  String? subjectId;
@override@JsonKey(name: 'exam_date') final  dynamic examDate;
@override@JsonKey(name: 'start_time') final  String? startTime;
@override@JsonKey(name: 'end_time') final  String? endTime;
@override@JsonKey(name: 'max_marks') final  int? maxMarks;
@override@JsonKey(name: 'pass_marks') final  int? passMarks;
@override@JsonKey(name: 'room_id') final  String? roomId;

/// Create a copy of ExamScheduleDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ExamScheduleDtoCopyWith<_ExamScheduleDto> get copyWith => __$ExamScheduleDtoCopyWithImpl<_ExamScheduleDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ExamScheduleDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ExamScheduleDto&&(identical(other.id, id) || other.id == id)&&(identical(other.examId, examId) || other.examId == examId)&&(identical(other.gradeId, gradeId) || other.gradeId == gradeId)&&(identical(other.sectionId, sectionId) || other.sectionId == sectionId)&&(identical(other.subjectId, subjectId) || other.subjectId == subjectId)&&const DeepCollectionEquality().equals(other.examDate, examDate)&&(identical(other.startTime, startTime) || other.startTime == startTime)&&(identical(other.endTime, endTime) || other.endTime == endTime)&&(identical(other.maxMarks, maxMarks) || other.maxMarks == maxMarks)&&(identical(other.passMarks, passMarks) || other.passMarks == passMarks)&&(identical(other.roomId, roomId) || other.roomId == roomId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,examId,gradeId,sectionId,subjectId,const DeepCollectionEquality().hash(examDate),startTime,endTime,maxMarks,passMarks,roomId);

@override
String toString() {
  return 'ExamScheduleDto(id: $id, examId: $examId, gradeId: $gradeId, sectionId: $sectionId, subjectId: $subjectId, examDate: $examDate, startTime: $startTime, endTime: $endTime, maxMarks: $maxMarks, passMarks: $passMarks, roomId: $roomId)';
}


}

/// @nodoc
abstract mixin class _$ExamScheduleDtoCopyWith<$Res> implements $ExamScheduleDtoCopyWith<$Res> {
  factory _$ExamScheduleDtoCopyWith(_ExamScheduleDto value, $Res Function(_ExamScheduleDto) _then) = __$ExamScheduleDtoCopyWithImpl;
@override @useResult
$Res call({
 String? id,@JsonKey(name: 'exam_id') String? examId,@JsonKey(name: 'grade_id') String? gradeId,@JsonKey(name: 'section_id') String? sectionId,@JsonKey(name: 'subject_id') String? subjectId,@JsonKey(name: 'exam_date') dynamic examDate,@JsonKey(name: 'start_time') String? startTime,@JsonKey(name: 'end_time') String? endTime,@JsonKey(name: 'max_marks') int? maxMarks,@JsonKey(name: 'pass_marks') int? passMarks,@JsonKey(name: 'room_id') String? roomId
});




}
/// @nodoc
class __$ExamScheduleDtoCopyWithImpl<$Res>
    implements _$ExamScheduleDtoCopyWith<$Res> {
  __$ExamScheduleDtoCopyWithImpl(this._self, this._then);

  final _ExamScheduleDto _self;
  final $Res Function(_ExamScheduleDto) _then;

/// Create a copy of ExamScheduleDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = freezed,Object? examId = freezed,Object? gradeId = freezed,Object? sectionId = freezed,Object? subjectId = freezed,Object? examDate = freezed,Object? startTime = freezed,Object? endTime = freezed,Object? maxMarks = freezed,Object? passMarks = freezed,Object? roomId = freezed,}) {
  return _then(_ExamScheduleDto(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,examId: freezed == examId ? _self.examId : examId // ignore: cast_nullable_to_non_nullable
as String?,gradeId: freezed == gradeId ? _self.gradeId : gradeId // ignore: cast_nullable_to_non_nullable
as String?,sectionId: freezed == sectionId ? _self.sectionId : sectionId // ignore: cast_nullable_to_non_nullable
as String?,subjectId: freezed == subjectId ? _self.subjectId : subjectId // ignore: cast_nullable_to_non_nullable
as String?,examDate: freezed == examDate ? _self.examDate : examDate // ignore: cast_nullable_to_non_nullable
as dynamic,startTime: freezed == startTime ? _self.startTime : startTime // ignore: cast_nullable_to_non_nullable
as String?,endTime: freezed == endTime ? _self.endTime : endTime // ignore: cast_nullable_to_non_nullable
as String?,maxMarks: freezed == maxMarks ? _self.maxMarks : maxMarks // ignore: cast_nullable_to_non_nullable
as int?,passMarks: freezed == passMarks ? _self.passMarks : passMarks // ignore: cast_nullable_to_non_nullable
as int?,roomId: freezed == roomId ? _self.roomId : roomId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$StudentMarkDto {

 String? get id;@JsonKey(name: 'exam_schedule_id') String? get examScheduleId;@JsonKey(name: 'student_id') String? get studentId;@JsonKey(name: 'enrollment_id') String? get enrollmentId;@JsonKey(name: 'marks_obtained') num? get marksObtained;@JsonKey(name: 'grade_label') String? get gradeLabel;@JsonKey(name: 'is_absent') bool? get isAbsent;@JsonKey(name: 'is_exempted') bool? get isExempted;
/// Create a copy of StudentMarkDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StudentMarkDtoCopyWith<StudentMarkDto> get copyWith => _$StudentMarkDtoCopyWithImpl<StudentMarkDto>(this as StudentMarkDto, _$identity);

  /// Serializes this StudentMarkDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StudentMarkDto&&(identical(other.id, id) || other.id == id)&&(identical(other.examScheduleId, examScheduleId) || other.examScheduleId == examScheduleId)&&(identical(other.studentId, studentId) || other.studentId == studentId)&&(identical(other.enrollmentId, enrollmentId) || other.enrollmentId == enrollmentId)&&(identical(other.marksObtained, marksObtained) || other.marksObtained == marksObtained)&&(identical(other.gradeLabel, gradeLabel) || other.gradeLabel == gradeLabel)&&(identical(other.isAbsent, isAbsent) || other.isAbsent == isAbsent)&&(identical(other.isExempted, isExempted) || other.isExempted == isExempted));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,examScheduleId,studentId,enrollmentId,marksObtained,gradeLabel,isAbsent,isExempted);

@override
String toString() {
  return 'StudentMarkDto(id: $id, examScheduleId: $examScheduleId, studentId: $studentId, enrollmentId: $enrollmentId, marksObtained: $marksObtained, gradeLabel: $gradeLabel, isAbsent: $isAbsent, isExempted: $isExempted)';
}


}

/// @nodoc
abstract mixin class $StudentMarkDtoCopyWith<$Res>  {
  factory $StudentMarkDtoCopyWith(StudentMarkDto value, $Res Function(StudentMarkDto) _then) = _$StudentMarkDtoCopyWithImpl;
@useResult
$Res call({
 String? id,@JsonKey(name: 'exam_schedule_id') String? examScheduleId,@JsonKey(name: 'student_id') String? studentId,@JsonKey(name: 'enrollment_id') String? enrollmentId,@JsonKey(name: 'marks_obtained') num? marksObtained,@JsonKey(name: 'grade_label') String? gradeLabel,@JsonKey(name: 'is_absent') bool? isAbsent,@JsonKey(name: 'is_exempted') bool? isExempted
});




}
/// @nodoc
class _$StudentMarkDtoCopyWithImpl<$Res>
    implements $StudentMarkDtoCopyWith<$Res> {
  _$StudentMarkDtoCopyWithImpl(this._self, this._then);

  final StudentMarkDto _self;
  final $Res Function(StudentMarkDto) _then;

/// Create a copy of StudentMarkDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = freezed,Object? examScheduleId = freezed,Object? studentId = freezed,Object? enrollmentId = freezed,Object? marksObtained = freezed,Object? gradeLabel = freezed,Object? isAbsent = freezed,Object? isExempted = freezed,}) {
  return _then(_self.copyWith(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,examScheduleId: freezed == examScheduleId ? _self.examScheduleId : examScheduleId // ignore: cast_nullable_to_non_nullable
as String?,studentId: freezed == studentId ? _self.studentId : studentId // ignore: cast_nullable_to_non_nullable
as String?,enrollmentId: freezed == enrollmentId ? _self.enrollmentId : enrollmentId // ignore: cast_nullable_to_non_nullable
as String?,marksObtained: freezed == marksObtained ? _self.marksObtained : marksObtained // ignore: cast_nullable_to_non_nullable
as num?,gradeLabel: freezed == gradeLabel ? _self.gradeLabel : gradeLabel // ignore: cast_nullable_to_non_nullable
as String?,isAbsent: freezed == isAbsent ? _self.isAbsent : isAbsent // ignore: cast_nullable_to_non_nullable
as bool?,isExempted: freezed == isExempted ? _self.isExempted : isExempted // ignore: cast_nullable_to_non_nullable
as bool?,
  ));
}

}


/// Adds pattern-matching-related methods to [StudentMarkDto].
extension StudentMarkDtoPatterns on StudentMarkDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _StudentMarkDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _StudentMarkDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _StudentMarkDto value)  $default,){
final _that = this;
switch (_that) {
case _StudentMarkDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _StudentMarkDto value)?  $default,){
final _that = this;
switch (_that) {
case _StudentMarkDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? id, @JsonKey(name: 'exam_schedule_id')  String? examScheduleId, @JsonKey(name: 'student_id')  String? studentId, @JsonKey(name: 'enrollment_id')  String? enrollmentId, @JsonKey(name: 'marks_obtained')  num? marksObtained, @JsonKey(name: 'grade_label')  String? gradeLabel, @JsonKey(name: 'is_absent')  bool? isAbsent, @JsonKey(name: 'is_exempted')  bool? isExempted)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _StudentMarkDto() when $default != null:
return $default(_that.id,_that.examScheduleId,_that.studentId,_that.enrollmentId,_that.marksObtained,_that.gradeLabel,_that.isAbsent,_that.isExempted);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? id, @JsonKey(name: 'exam_schedule_id')  String? examScheduleId, @JsonKey(name: 'student_id')  String? studentId, @JsonKey(name: 'enrollment_id')  String? enrollmentId, @JsonKey(name: 'marks_obtained')  num? marksObtained, @JsonKey(name: 'grade_label')  String? gradeLabel, @JsonKey(name: 'is_absent')  bool? isAbsent, @JsonKey(name: 'is_exempted')  bool? isExempted)  $default,) {final _that = this;
switch (_that) {
case _StudentMarkDto():
return $default(_that.id,_that.examScheduleId,_that.studentId,_that.enrollmentId,_that.marksObtained,_that.gradeLabel,_that.isAbsent,_that.isExempted);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? id, @JsonKey(name: 'exam_schedule_id')  String? examScheduleId, @JsonKey(name: 'student_id')  String? studentId, @JsonKey(name: 'enrollment_id')  String? enrollmentId, @JsonKey(name: 'marks_obtained')  num? marksObtained, @JsonKey(name: 'grade_label')  String? gradeLabel, @JsonKey(name: 'is_absent')  bool? isAbsent, @JsonKey(name: 'is_exempted')  bool? isExempted)?  $default,) {final _that = this;
switch (_that) {
case _StudentMarkDto() when $default != null:
return $default(_that.id,_that.examScheduleId,_that.studentId,_that.enrollmentId,_that.marksObtained,_that.gradeLabel,_that.isAbsent,_that.isExempted);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _StudentMarkDto implements StudentMarkDto {
  const _StudentMarkDto({this.id, @JsonKey(name: 'exam_schedule_id') this.examScheduleId, @JsonKey(name: 'student_id') this.studentId, @JsonKey(name: 'enrollment_id') this.enrollmentId, @JsonKey(name: 'marks_obtained') this.marksObtained, @JsonKey(name: 'grade_label') this.gradeLabel, @JsonKey(name: 'is_absent') this.isAbsent, @JsonKey(name: 'is_exempted') this.isExempted});
  factory _StudentMarkDto.fromJson(Map<String, dynamic> json) => _$StudentMarkDtoFromJson(json);

@override final  String? id;
@override@JsonKey(name: 'exam_schedule_id') final  String? examScheduleId;
@override@JsonKey(name: 'student_id') final  String? studentId;
@override@JsonKey(name: 'enrollment_id') final  String? enrollmentId;
@override@JsonKey(name: 'marks_obtained') final  num? marksObtained;
@override@JsonKey(name: 'grade_label') final  String? gradeLabel;
@override@JsonKey(name: 'is_absent') final  bool? isAbsent;
@override@JsonKey(name: 'is_exempted') final  bool? isExempted;

/// Create a copy of StudentMarkDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StudentMarkDtoCopyWith<_StudentMarkDto> get copyWith => __$StudentMarkDtoCopyWithImpl<_StudentMarkDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$StudentMarkDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _StudentMarkDto&&(identical(other.id, id) || other.id == id)&&(identical(other.examScheduleId, examScheduleId) || other.examScheduleId == examScheduleId)&&(identical(other.studentId, studentId) || other.studentId == studentId)&&(identical(other.enrollmentId, enrollmentId) || other.enrollmentId == enrollmentId)&&(identical(other.marksObtained, marksObtained) || other.marksObtained == marksObtained)&&(identical(other.gradeLabel, gradeLabel) || other.gradeLabel == gradeLabel)&&(identical(other.isAbsent, isAbsent) || other.isAbsent == isAbsent)&&(identical(other.isExempted, isExempted) || other.isExempted == isExempted));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,examScheduleId,studentId,enrollmentId,marksObtained,gradeLabel,isAbsent,isExempted);

@override
String toString() {
  return 'StudentMarkDto(id: $id, examScheduleId: $examScheduleId, studentId: $studentId, enrollmentId: $enrollmentId, marksObtained: $marksObtained, gradeLabel: $gradeLabel, isAbsent: $isAbsent, isExempted: $isExempted)';
}


}

/// @nodoc
abstract mixin class _$StudentMarkDtoCopyWith<$Res> implements $StudentMarkDtoCopyWith<$Res> {
  factory _$StudentMarkDtoCopyWith(_StudentMarkDto value, $Res Function(_StudentMarkDto) _then) = __$StudentMarkDtoCopyWithImpl;
@override @useResult
$Res call({
 String? id,@JsonKey(name: 'exam_schedule_id') String? examScheduleId,@JsonKey(name: 'student_id') String? studentId,@JsonKey(name: 'enrollment_id') String? enrollmentId,@JsonKey(name: 'marks_obtained') num? marksObtained,@JsonKey(name: 'grade_label') String? gradeLabel,@JsonKey(name: 'is_absent') bool? isAbsent,@JsonKey(name: 'is_exempted') bool? isExempted
});




}
/// @nodoc
class __$StudentMarkDtoCopyWithImpl<$Res>
    implements _$StudentMarkDtoCopyWith<$Res> {
  __$StudentMarkDtoCopyWithImpl(this._self, this._then);

  final _StudentMarkDto _self;
  final $Res Function(_StudentMarkDto) _then;

/// Create a copy of StudentMarkDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = freezed,Object? examScheduleId = freezed,Object? studentId = freezed,Object? enrollmentId = freezed,Object? marksObtained = freezed,Object? gradeLabel = freezed,Object? isAbsent = freezed,Object? isExempted = freezed,}) {
  return _then(_StudentMarkDto(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,examScheduleId: freezed == examScheduleId ? _self.examScheduleId : examScheduleId // ignore: cast_nullable_to_non_nullable
as String?,studentId: freezed == studentId ? _self.studentId : studentId // ignore: cast_nullable_to_non_nullable
as String?,enrollmentId: freezed == enrollmentId ? _self.enrollmentId : enrollmentId // ignore: cast_nullable_to_non_nullable
as String?,marksObtained: freezed == marksObtained ? _self.marksObtained : marksObtained // ignore: cast_nullable_to_non_nullable
as num?,gradeLabel: freezed == gradeLabel ? _self.gradeLabel : gradeLabel // ignore: cast_nullable_to_non_nullable
as String?,isAbsent: freezed == isAbsent ? _self.isAbsent : isAbsent // ignore: cast_nullable_to_non_nullable
as bool?,isExempted: freezed == isExempted ? _self.isExempted : isExempted // ignore: cast_nullable_to_non_nullable
as bool?,
  ));
}


}


/// @nodoc
mixin _$HomeworkDto {

 String? get id;@JsonKey(name: 'homework_id') String? get homeworkId;@JsonKey(name: 'school_id') String? get schoolId;@JsonKey(name: 'academic_year_id') String? get academicYearId;@JsonKey(name: 'class_id') String? get classId;@JsonKey(name: 'section_id') String? get sectionId;@JsonKey(name: 'subject_id') String? get subjectId;@JsonKey(name: 'staff_id') String? get staffId;@JsonKey(name: 'student_id') String? get studentId; String? get title; String? get description;@JsonKey(name: 'assigned_date') dynamic get assignedDate;@JsonKey(name: 'submission_date') dynamic get submissionDate;@JsonKey(name: 'attachment_url') String? get attachmentUrl;@JsonKey(name: 'submission_mode') String? get submissionMode; String? get status;
/// Create a copy of HomeworkDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$HomeworkDtoCopyWith<HomeworkDto> get copyWith => _$HomeworkDtoCopyWithImpl<HomeworkDto>(this as HomeworkDto, _$identity);

  /// Serializes this HomeworkDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is HomeworkDto&&(identical(other.id, id) || other.id == id)&&(identical(other.homeworkId, homeworkId) || other.homeworkId == homeworkId)&&(identical(other.schoolId, schoolId) || other.schoolId == schoolId)&&(identical(other.academicYearId, academicYearId) || other.academicYearId == academicYearId)&&(identical(other.classId, classId) || other.classId == classId)&&(identical(other.sectionId, sectionId) || other.sectionId == sectionId)&&(identical(other.subjectId, subjectId) || other.subjectId == subjectId)&&(identical(other.staffId, staffId) || other.staffId == staffId)&&(identical(other.studentId, studentId) || other.studentId == studentId)&&(identical(other.title, title) || other.title == title)&&(identical(other.description, description) || other.description == description)&&const DeepCollectionEquality().equals(other.assignedDate, assignedDate)&&const DeepCollectionEquality().equals(other.submissionDate, submissionDate)&&(identical(other.attachmentUrl, attachmentUrl) || other.attachmentUrl == attachmentUrl)&&(identical(other.submissionMode, submissionMode) || other.submissionMode == submissionMode)&&(identical(other.status, status) || other.status == status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,homeworkId,schoolId,academicYearId,classId,sectionId,subjectId,staffId,studentId,title,description,const DeepCollectionEquality().hash(assignedDate),const DeepCollectionEquality().hash(submissionDate),attachmentUrl,submissionMode,status);

@override
String toString() {
  return 'HomeworkDto(id: $id, homeworkId: $homeworkId, schoolId: $schoolId, academicYearId: $academicYearId, classId: $classId, sectionId: $sectionId, subjectId: $subjectId, staffId: $staffId, studentId: $studentId, title: $title, description: $description, assignedDate: $assignedDate, submissionDate: $submissionDate, attachmentUrl: $attachmentUrl, submissionMode: $submissionMode, status: $status)';
}


}

/// @nodoc
abstract mixin class $HomeworkDtoCopyWith<$Res>  {
  factory $HomeworkDtoCopyWith(HomeworkDto value, $Res Function(HomeworkDto) _then) = _$HomeworkDtoCopyWithImpl;
@useResult
$Res call({
 String? id,@JsonKey(name: 'homework_id') String? homeworkId,@JsonKey(name: 'school_id') String? schoolId,@JsonKey(name: 'academic_year_id') String? academicYearId,@JsonKey(name: 'class_id') String? classId,@JsonKey(name: 'section_id') String? sectionId,@JsonKey(name: 'subject_id') String? subjectId,@JsonKey(name: 'staff_id') String? staffId,@JsonKey(name: 'student_id') String? studentId, String? title, String? description,@JsonKey(name: 'assigned_date') dynamic assignedDate,@JsonKey(name: 'submission_date') dynamic submissionDate,@JsonKey(name: 'attachment_url') String? attachmentUrl,@JsonKey(name: 'submission_mode') String? submissionMode, String? status
});




}
/// @nodoc
class _$HomeworkDtoCopyWithImpl<$Res>
    implements $HomeworkDtoCopyWith<$Res> {
  _$HomeworkDtoCopyWithImpl(this._self, this._then);

  final HomeworkDto _self;
  final $Res Function(HomeworkDto) _then;

/// Create a copy of HomeworkDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = freezed,Object? homeworkId = freezed,Object? schoolId = freezed,Object? academicYearId = freezed,Object? classId = freezed,Object? sectionId = freezed,Object? subjectId = freezed,Object? staffId = freezed,Object? studentId = freezed,Object? title = freezed,Object? description = freezed,Object? assignedDate = freezed,Object? submissionDate = freezed,Object? attachmentUrl = freezed,Object? submissionMode = freezed,Object? status = freezed,}) {
  return _then(_self.copyWith(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,homeworkId: freezed == homeworkId ? _self.homeworkId : homeworkId // ignore: cast_nullable_to_non_nullable
as String?,schoolId: freezed == schoolId ? _self.schoolId : schoolId // ignore: cast_nullable_to_non_nullable
as String?,academicYearId: freezed == academicYearId ? _self.academicYearId : academicYearId // ignore: cast_nullable_to_non_nullable
as String?,classId: freezed == classId ? _self.classId : classId // ignore: cast_nullable_to_non_nullable
as String?,sectionId: freezed == sectionId ? _self.sectionId : sectionId // ignore: cast_nullable_to_non_nullable
as String?,subjectId: freezed == subjectId ? _self.subjectId : subjectId // ignore: cast_nullable_to_non_nullable
as String?,staffId: freezed == staffId ? _self.staffId : staffId // ignore: cast_nullable_to_non_nullable
as String?,studentId: freezed == studentId ? _self.studentId : studentId // ignore: cast_nullable_to_non_nullable
as String?,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,assignedDate: freezed == assignedDate ? _self.assignedDate : assignedDate // ignore: cast_nullable_to_non_nullable
as dynamic,submissionDate: freezed == submissionDate ? _self.submissionDate : submissionDate // ignore: cast_nullable_to_non_nullable
as dynamic,attachmentUrl: freezed == attachmentUrl ? _self.attachmentUrl : attachmentUrl // ignore: cast_nullable_to_non_nullable
as String?,submissionMode: freezed == submissionMode ? _self.submissionMode : submissionMode // ignore: cast_nullable_to_non_nullable
as String?,status: freezed == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [HomeworkDto].
extension HomeworkDtoPatterns on HomeworkDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _HomeworkDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _HomeworkDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _HomeworkDto value)  $default,){
final _that = this;
switch (_that) {
case _HomeworkDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _HomeworkDto value)?  $default,){
final _that = this;
switch (_that) {
case _HomeworkDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? id, @JsonKey(name: 'homework_id')  String? homeworkId, @JsonKey(name: 'school_id')  String? schoolId, @JsonKey(name: 'academic_year_id')  String? academicYearId, @JsonKey(name: 'class_id')  String? classId, @JsonKey(name: 'section_id')  String? sectionId, @JsonKey(name: 'subject_id')  String? subjectId, @JsonKey(name: 'staff_id')  String? staffId, @JsonKey(name: 'student_id')  String? studentId,  String? title,  String? description, @JsonKey(name: 'assigned_date')  dynamic assignedDate, @JsonKey(name: 'submission_date')  dynamic submissionDate, @JsonKey(name: 'attachment_url')  String? attachmentUrl, @JsonKey(name: 'submission_mode')  String? submissionMode,  String? status)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _HomeworkDto() when $default != null:
return $default(_that.id,_that.homeworkId,_that.schoolId,_that.academicYearId,_that.classId,_that.sectionId,_that.subjectId,_that.staffId,_that.studentId,_that.title,_that.description,_that.assignedDate,_that.submissionDate,_that.attachmentUrl,_that.submissionMode,_that.status);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? id, @JsonKey(name: 'homework_id')  String? homeworkId, @JsonKey(name: 'school_id')  String? schoolId, @JsonKey(name: 'academic_year_id')  String? academicYearId, @JsonKey(name: 'class_id')  String? classId, @JsonKey(name: 'section_id')  String? sectionId, @JsonKey(name: 'subject_id')  String? subjectId, @JsonKey(name: 'staff_id')  String? staffId, @JsonKey(name: 'student_id')  String? studentId,  String? title,  String? description, @JsonKey(name: 'assigned_date')  dynamic assignedDate, @JsonKey(name: 'submission_date')  dynamic submissionDate, @JsonKey(name: 'attachment_url')  String? attachmentUrl, @JsonKey(name: 'submission_mode')  String? submissionMode,  String? status)  $default,) {final _that = this;
switch (_that) {
case _HomeworkDto():
return $default(_that.id,_that.homeworkId,_that.schoolId,_that.academicYearId,_that.classId,_that.sectionId,_that.subjectId,_that.staffId,_that.studentId,_that.title,_that.description,_that.assignedDate,_that.submissionDate,_that.attachmentUrl,_that.submissionMode,_that.status);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? id, @JsonKey(name: 'homework_id')  String? homeworkId, @JsonKey(name: 'school_id')  String? schoolId, @JsonKey(name: 'academic_year_id')  String? academicYearId, @JsonKey(name: 'class_id')  String? classId, @JsonKey(name: 'section_id')  String? sectionId, @JsonKey(name: 'subject_id')  String? subjectId, @JsonKey(name: 'staff_id')  String? staffId, @JsonKey(name: 'student_id')  String? studentId,  String? title,  String? description, @JsonKey(name: 'assigned_date')  dynamic assignedDate, @JsonKey(name: 'submission_date')  dynamic submissionDate, @JsonKey(name: 'attachment_url')  String? attachmentUrl, @JsonKey(name: 'submission_mode')  String? submissionMode,  String? status)?  $default,) {final _that = this;
switch (_that) {
case _HomeworkDto() when $default != null:
return $default(_that.id,_that.homeworkId,_that.schoolId,_that.academicYearId,_that.classId,_that.sectionId,_that.subjectId,_that.staffId,_that.studentId,_that.title,_that.description,_that.assignedDate,_that.submissionDate,_that.attachmentUrl,_that.submissionMode,_that.status);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _HomeworkDto implements HomeworkDto {
  const _HomeworkDto({this.id, @JsonKey(name: 'homework_id') this.homeworkId, @JsonKey(name: 'school_id') this.schoolId, @JsonKey(name: 'academic_year_id') this.academicYearId, @JsonKey(name: 'class_id') this.classId, @JsonKey(name: 'section_id') this.sectionId, @JsonKey(name: 'subject_id') this.subjectId, @JsonKey(name: 'staff_id') this.staffId, @JsonKey(name: 'student_id') this.studentId, this.title, this.description, @JsonKey(name: 'assigned_date') this.assignedDate, @JsonKey(name: 'submission_date') this.submissionDate, @JsonKey(name: 'attachment_url') this.attachmentUrl, @JsonKey(name: 'submission_mode') this.submissionMode, this.status});
  factory _HomeworkDto.fromJson(Map<String, dynamic> json) => _$HomeworkDtoFromJson(json);

@override final  String? id;
@override@JsonKey(name: 'homework_id') final  String? homeworkId;
@override@JsonKey(name: 'school_id') final  String? schoolId;
@override@JsonKey(name: 'academic_year_id') final  String? academicYearId;
@override@JsonKey(name: 'class_id') final  String? classId;
@override@JsonKey(name: 'section_id') final  String? sectionId;
@override@JsonKey(name: 'subject_id') final  String? subjectId;
@override@JsonKey(name: 'staff_id') final  String? staffId;
@override@JsonKey(name: 'student_id') final  String? studentId;
@override final  String? title;
@override final  String? description;
@override@JsonKey(name: 'assigned_date') final  dynamic assignedDate;
@override@JsonKey(name: 'submission_date') final  dynamic submissionDate;
@override@JsonKey(name: 'attachment_url') final  String? attachmentUrl;
@override@JsonKey(name: 'submission_mode') final  String? submissionMode;
@override final  String? status;

/// Create a copy of HomeworkDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$HomeworkDtoCopyWith<_HomeworkDto> get copyWith => __$HomeworkDtoCopyWithImpl<_HomeworkDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$HomeworkDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _HomeworkDto&&(identical(other.id, id) || other.id == id)&&(identical(other.homeworkId, homeworkId) || other.homeworkId == homeworkId)&&(identical(other.schoolId, schoolId) || other.schoolId == schoolId)&&(identical(other.academicYearId, academicYearId) || other.academicYearId == academicYearId)&&(identical(other.classId, classId) || other.classId == classId)&&(identical(other.sectionId, sectionId) || other.sectionId == sectionId)&&(identical(other.subjectId, subjectId) || other.subjectId == subjectId)&&(identical(other.staffId, staffId) || other.staffId == staffId)&&(identical(other.studentId, studentId) || other.studentId == studentId)&&(identical(other.title, title) || other.title == title)&&(identical(other.description, description) || other.description == description)&&const DeepCollectionEquality().equals(other.assignedDate, assignedDate)&&const DeepCollectionEquality().equals(other.submissionDate, submissionDate)&&(identical(other.attachmentUrl, attachmentUrl) || other.attachmentUrl == attachmentUrl)&&(identical(other.submissionMode, submissionMode) || other.submissionMode == submissionMode)&&(identical(other.status, status) || other.status == status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,homeworkId,schoolId,academicYearId,classId,sectionId,subjectId,staffId,studentId,title,description,const DeepCollectionEquality().hash(assignedDate),const DeepCollectionEquality().hash(submissionDate),attachmentUrl,submissionMode,status);

@override
String toString() {
  return 'HomeworkDto(id: $id, homeworkId: $homeworkId, schoolId: $schoolId, academicYearId: $academicYearId, classId: $classId, sectionId: $sectionId, subjectId: $subjectId, staffId: $staffId, studentId: $studentId, title: $title, description: $description, assignedDate: $assignedDate, submissionDate: $submissionDate, attachmentUrl: $attachmentUrl, submissionMode: $submissionMode, status: $status)';
}


}

/// @nodoc
abstract mixin class _$HomeworkDtoCopyWith<$Res> implements $HomeworkDtoCopyWith<$Res> {
  factory _$HomeworkDtoCopyWith(_HomeworkDto value, $Res Function(_HomeworkDto) _then) = __$HomeworkDtoCopyWithImpl;
@override @useResult
$Res call({
 String? id,@JsonKey(name: 'homework_id') String? homeworkId,@JsonKey(name: 'school_id') String? schoolId,@JsonKey(name: 'academic_year_id') String? academicYearId,@JsonKey(name: 'class_id') String? classId,@JsonKey(name: 'section_id') String? sectionId,@JsonKey(name: 'subject_id') String? subjectId,@JsonKey(name: 'staff_id') String? staffId,@JsonKey(name: 'student_id') String? studentId, String? title, String? description,@JsonKey(name: 'assigned_date') dynamic assignedDate,@JsonKey(name: 'submission_date') dynamic submissionDate,@JsonKey(name: 'attachment_url') String? attachmentUrl,@JsonKey(name: 'submission_mode') String? submissionMode, String? status
});




}
/// @nodoc
class __$HomeworkDtoCopyWithImpl<$Res>
    implements _$HomeworkDtoCopyWith<$Res> {
  __$HomeworkDtoCopyWithImpl(this._self, this._then);

  final _HomeworkDto _self;
  final $Res Function(_HomeworkDto) _then;

/// Create a copy of HomeworkDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = freezed,Object? homeworkId = freezed,Object? schoolId = freezed,Object? academicYearId = freezed,Object? classId = freezed,Object? sectionId = freezed,Object? subjectId = freezed,Object? staffId = freezed,Object? studentId = freezed,Object? title = freezed,Object? description = freezed,Object? assignedDate = freezed,Object? submissionDate = freezed,Object? attachmentUrl = freezed,Object? submissionMode = freezed,Object? status = freezed,}) {
  return _then(_HomeworkDto(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,homeworkId: freezed == homeworkId ? _self.homeworkId : homeworkId // ignore: cast_nullable_to_non_nullable
as String?,schoolId: freezed == schoolId ? _self.schoolId : schoolId // ignore: cast_nullable_to_non_nullable
as String?,academicYearId: freezed == academicYearId ? _self.academicYearId : academicYearId // ignore: cast_nullable_to_non_nullable
as String?,classId: freezed == classId ? _self.classId : classId // ignore: cast_nullable_to_non_nullable
as String?,sectionId: freezed == sectionId ? _self.sectionId : sectionId // ignore: cast_nullable_to_non_nullable
as String?,subjectId: freezed == subjectId ? _self.subjectId : subjectId // ignore: cast_nullable_to_non_nullable
as String?,staffId: freezed == staffId ? _self.staffId : staffId // ignore: cast_nullable_to_non_nullable
as String?,studentId: freezed == studentId ? _self.studentId : studentId // ignore: cast_nullable_to_non_nullable
as String?,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,assignedDate: freezed == assignedDate ? _self.assignedDate : assignedDate // ignore: cast_nullable_to_non_nullable
as dynamic,submissionDate: freezed == submissionDate ? _self.submissionDate : submissionDate // ignore: cast_nullable_to_non_nullable
as dynamic,attachmentUrl: freezed == attachmentUrl ? _self.attachmentUrl : attachmentUrl // ignore: cast_nullable_to_non_nullable
as String?,submissionMode: freezed == submissionMode ? _self.submissionMode : submissionMode // ignore: cast_nullable_to_non_nullable
as String?,status: freezed == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$LeaveDto {

 String? get id;@JsonKey(name: 'leave_id') String? get leaveId;@JsonKey(name: 'school_id') String? get schoolId;@JsonKey(name: 'user_type') String? get userType;@JsonKey(name: 'student_id') String? get studentId;@JsonKey(name: 'staff_id') String? get staffId;@JsonKey(name: 'leave_type_id') String? get leaveTypeId;@JsonKey(name: 'from_date') dynamic get fromDate;@JsonKey(name: 'to_date') dynamic get toDate;@JsonKey(name: 'total_days') num? get totalDays; String? get reason;@JsonKey(name: 'approval_status') String? get approvalStatus;@JsonKey(name: 'approved_by') String? get approvedBy;@JsonKey(name: 'approved_at') dynamic get approvedAt; String? get remarks;
/// Create a copy of LeaveDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LeaveDtoCopyWith<LeaveDto> get copyWith => _$LeaveDtoCopyWithImpl<LeaveDto>(this as LeaveDto, _$identity);

  /// Serializes this LeaveDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LeaveDto&&(identical(other.id, id) || other.id == id)&&(identical(other.leaveId, leaveId) || other.leaveId == leaveId)&&(identical(other.schoolId, schoolId) || other.schoolId == schoolId)&&(identical(other.userType, userType) || other.userType == userType)&&(identical(other.studentId, studentId) || other.studentId == studentId)&&(identical(other.staffId, staffId) || other.staffId == staffId)&&(identical(other.leaveTypeId, leaveTypeId) || other.leaveTypeId == leaveTypeId)&&const DeepCollectionEquality().equals(other.fromDate, fromDate)&&const DeepCollectionEquality().equals(other.toDate, toDate)&&(identical(other.totalDays, totalDays) || other.totalDays == totalDays)&&(identical(other.reason, reason) || other.reason == reason)&&(identical(other.approvalStatus, approvalStatus) || other.approvalStatus == approvalStatus)&&(identical(other.approvedBy, approvedBy) || other.approvedBy == approvedBy)&&const DeepCollectionEquality().equals(other.approvedAt, approvedAt)&&(identical(other.remarks, remarks) || other.remarks == remarks));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,leaveId,schoolId,userType,studentId,staffId,leaveTypeId,const DeepCollectionEquality().hash(fromDate),const DeepCollectionEquality().hash(toDate),totalDays,reason,approvalStatus,approvedBy,const DeepCollectionEquality().hash(approvedAt),remarks);

@override
String toString() {
  return 'LeaveDto(id: $id, leaveId: $leaveId, schoolId: $schoolId, userType: $userType, studentId: $studentId, staffId: $staffId, leaveTypeId: $leaveTypeId, fromDate: $fromDate, toDate: $toDate, totalDays: $totalDays, reason: $reason, approvalStatus: $approvalStatus, approvedBy: $approvedBy, approvedAt: $approvedAt, remarks: $remarks)';
}


}

/// @nodoc
abstract mixin class $LeaveDtoCopyWith<$Res>  {
  factory $LeaveDtoCopyWith(LeaveDto value, $Res Function(LeaveDto) _then) = _$LeaveDtoCopyWithImpl;
@useResult
$Res call({
 String? id,@JsonKey(name: 'leave_id') String? leaveId,@JsonKey(name: 'school_id') String? schoolId,@JsonKey(name: 'user_type') String? userType,@JsonKey(name: 'student_id') String? studentId,@JsonKey(name: 'staff_id') String? staffId,@JsonKey(name: 'leave_type_id') String? leaveTypeId,@JsonKey(name: 'from_date') dynamic fromDate,@JsonKey(name: 'to_date') dynamic toDate,@JsonKey(name: 'total_days') num? totalDays, String? reason,@JsonKey(name: 'approval_status') String? approvalStatus,@JsonKey(name: 'approved_by') String? approvedBy,@JsonKey(name: 'approved_at') dynamic approvedAt, String? remarks
});




}
/// @nodoc
class _$LeaveDtoCopyWithImpl<$Res>
    implements $LeaveDtoCopyWith<$Res> {
  _$LeaveDtoCopyWithImpl(this._self, this._then);

  final LeaveDto _self;
  final $Res Function(LeaveDto) _then;

/// Create a copy of LeaveDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = freezed,Object? leaveId = freezed,Object? schoolId = freezed,Object? userType = freezed,Object? studentId = freezed,Object? staffId = freezed,Object? leaveTypeId = freezed,Object? fromDate = freezed,Object? toDate = freezed,Object? totalDays = freezed,Object? reason = freezed,Object? approvalStatus = freezed,Object? approvedBy = freezed,Object? approvedAt = freezed,Object? remarks = freezed,}) {
  return _then(_self.copyWith(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,leaveId: freezed == leaveId ? _self.leaveId : leaveId // ignore: cast_nullable_to_non_nullable
as String?,schoolId: freezed == schoolId ? _self.schoolId : schoolId // ignore: cast_nullable_to_non_nullable
as String?,userType: freezed == userType ? _self.userType : userType // ignore: cast_nullable_to_non_nullable
as String?,studentId: freezed == studentId ? _self.studentId : studentId // ignore: cast_nullable_to_non_nullable
as String?,staffId: freezed == staffId ? _self.staffId : staffId // ignore: cast_nullable_to_non_nullable
as String?,leaveTypeId: freezed == leaveTypeId ? _self.leaveTypeId : leaveTypeId // ignore: cast_nullable_to_non_nullable
as String?,fromDate: freezed == fromDate ? _self.fromDate : fromDate // ignore: cast_nullable_to_non_nullable
as dynamic,toDate: freezed == toDate ? _self.toDate : toDate // ignore: cast_nullable_to_non_nullable
as dynamic,totalDays: freezed == totalDays ? _self.totalDays : totalDays // ignore: cast_nullable_to_non_nullable
as num?,reason: freezed == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String?,approvalStatus: freezed == approvalStatus ? _self.approvalStatus : approvalStatus // ignore: cast_nullable_to_non_nullable
as String?,approvedBy: freezed == approvedBy ? _self.approvedBy : approvedBy // ignore: cast_nullable_to_non_nullable
as String?,approvedAt: freezed == approvedAt ? _self.approvedAt : approvedAt // ignore: cast_nullable_to_non_nullable
as dynamic,remarks: freezed == remarks ? _self.remarks : remarks // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [LeaveDto].
extension LeaveDtoPatterns on LeaveDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LeaveDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LeaveDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LeaveDto value)  $default,){
final _that = this;
switch (_that) {
case _LeaveDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LeaveDto value)?  $default,){
final _that = this;
switch (_that) {
case _LeaveDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? id, @JsonKey(name: 'leave_id')  String? leaveId, @JsonKey(name: 'school_id')  String? schoolId, @JsonKey(name: 'user_type')  String? userType, @JsonKey(name: 'student_id')  String? studentId, @JsonKey(name: 'staff_id')  String? staffId, @JsonKey(name: 'leave_type_id')  String? leaveTypeId, @JsonKey(name: 'from_date')  dynamic fromDate, @JsonKey(name: 'to_date')  dynamic toDate, @JsonKey(name: 'total_days')  num? totalDays,  String? reason, @JsonKey(name: 'approval_status')  String? approvalStatus, @JsonKey(name: 'approved_by')  String? approvedBy, @JsonKey(name: 'approved_at')  dynamic approvedAt,  String? remarks)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LeaveDto() when $default != null:
return $default(_that.id,_that.leaveId,_that.schoolId,_that.userType,_that.studentId,_that.staffId,_that.leaveTypeId,_that.fromDate,_that.toDate,_that.totalDays,_that.reason,_that.approvalStatus,_that.approvedBy,_that.approvedAt,_that.remarks);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? id, @JsonKey(name: 'leave_id')  String? leaveId, @JsonKey(name: 'school_id')  String? schoolId, @JsonKey(name: 'user_type')  String? userType, @JsonKey(name: 'student_id')  String? studentId, @JsonKey(name: 'staff_id')  String? staffId, @JsonKey(name: 'leave_type_id')  String? leaveTypeId, @JsonKey(name: 'from_date')  dynamic fromDate, @JsonKey(name: 'to_date')  dynamic toDate, @JsonKey(name: 'total_days')  num? totalDays,  String? reason, @JsonKey(name: 'approval_status')  String? approvalStatus, @JsonKey(name: 'approved_by')  String? approvedBy, @JsonKey(name: 'approved_at')  dynamic approvedAt,  String? remarks)  $default,) {final _that = this;
switch (_that) {
case _LeaveDto():
return $default(_that.id,_that.leaveId,_that.schoolId,_that.userType,_that.studentId,_that.staffId,_that.leaveTypeId,_that.fromDate,_that.toDate,_that.totalDays,_that.reason,_that.approvalStatus,_that.approvedBy,_that.approvedAt,_that.remarks);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? id, @JsonKey(name: 'leave_id')  String? leaveId, @JsonKey(name: 'school_id')  String? schoolId, @JsonKey(name: 'user_type')  String? userType, @JsonKey(name: 'student_id')  String? studentId, @JsonKey(name: 'staff_id')  String? staffId, @JsonKey(name: 'leave_type_id')  String? leaveTypeId, @JsonKey(name: 'from_date')  dynamic fromDate, @JsonKey(name: 'to_date')  dynamic toDate, @JsonKey(name: 'total_days')  num? totalDays,  String? reason, @JsonKey(name: 'approval_status')  String? approvalStatus, @JsonKey(name: 'approved_by')  String? approvedBy, @JsonKey(name: 'approved_at')  dynamic approvedAt,  String? remarks)?  $default,) {final _that = this;
switch (_that) {
case _LeaveDto() when $default != null:
return $default(_that.id,_that.leaveId,_that.schoolId,_that.userType,_that.studentId,_that.staffId,_that.leaveTypeId,_that.fromDate,_that.toDate,_that.totalDays,_that.reason,_that.approvalStatus,_that.approvedBy,_that.approvedAt,_that.remarks);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LeaveDto implements LeaveDto {
  const _LeaveDto({this.id, @JsonKey(name: 'leave_id') this.leaveId, @JsonKey(name: 'school_id') this.schoolId, @JsonKey(name: 'user_type') this.userType, @JsonKey(name: 'student_id') this.studentId, @JsonKey(name: 'staff_id') this.staffId, @JsonKey(name: 'leave_type_id') this.leaveTypeId, @JsonKey(name: 'from_date') this.fromDate, @JsonKey(name: 'to_date') this.toDate, @JsonKey(name: 'total_days') this.totalDays, this.reason, @JsonKey(name: 'approval_status') this.approvalStatus, @JsonKey(name: 'approved_by') this.approvedBy, @JsonKey(name: 'approved_at') this.approvedAt, this.remarks});
  factory _LeaveDto.fromJson(Map<String, dynamic> json) => _$LeaveDtoFromJson(json);

@override final  String? id;
@override@JsonKey(name: 'leave_id') final  String? leaveId;
@override@JsonKey(name: 'school_id') final  String? schoolId;
@override@JsonKey(name: 'user_type') final  String? userType;
@override@JsonKey(name: 'student_id') final  String? studentId;
@override@JsonKey(name: 'staff_id') final  String? staffId;
@override@JsonKey(name: 'leave_type_id') final  String? leaveTypeId;
@override@JsonKey(name: 'from_date') final  dynamic fromDate;
@override@JsonKey(name: 'to_date') final  dynamic toDate;
@override@JsonKey(name: 'total_days') final  num? totalDays;
@override final  String? reason;
@override@JsonKey(name: 'approval_status') final  String? approvalStatus;
@override@JsonKey(name: 'approved_by') final  String? approvedBy;
@override@JsonKey(name: 'approved_at') final  dynamic approvedAt;
@override final  String? remarks;

/// Create a copy of LeaveDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LeaveDtoCopyWith<_LeaveDto> get copyWith => __$LeaveDtoCopyWithImpl<_LeaveDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LeaveDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LeaveDto&&(identical(other.id, id) || other.id == id)&&(identical(other.leaveId, leaveId) || other.leaveId == leaveId)&&(identical(other.schoolId, schoolId) || other.schoolId == schoolId)&&(identical(other.userType, userType) || other.userType == userType)&&(identical(other.studentId, studentId) || other.studentId == studentId)&&(identical(other.staffId, staffId) || other.staffId == staffId)&&(identical(other.leaveTypeId, leaveTypeId) || other.leaveTypeId == leaveTypeId)&&const DeepCollectionEquality().equals(other.fromDate, fromDate)&&const DeepCollectionEquality().equals(other.toDate, toDate)&&(identical(other.totalDays, totalDays) || other.totalDays == totalDays)&&(identical(other.reason, reason) || other.reason == reason)&&(identical(other.approvalStatus, approvalStatus) || other.approvalStatus == approvalStatus)&&(identical(other.approvedBy, approvedBy) || other.approvedBy == approvedBy)&&const DeepCollectionEquality().equals(other.approvedAt, approvedAt)&&(identical(other.remarks, remarks) || other.remarks == remarks));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,leaveId,schoolId,userType,studentId,staffId,leaveTypeId,const DeepCollectionEquality().hash(fromDate),const DeepCollectionEquality().hash(toDate),totalDays,reason,approvalStatus,approvedBy,const DeepCollectionEquality().hash(approvedAt),remarks);

@override
String toString() {
  return 'LeaveDto(id: $id, leaveId: $leaveId, schoolId: $schoolId, userType: $userType, studentId: $studentId, staffId: $staffId, leaveTypeId: $leaveTypeId, fromDate: $fromDate, toDate: $toDate, totalDays: $totalDays, reason: $reason, approvalStatus: $approvalStatus, approvedBy: $approvedBy, approvedAt: $approvedAt, remarks: $remarks)';
}


}

/// @nodoc
abstract mixin class _$LeaveDtoCopyWith<$Res> implements $LeaveDtoCopyWith<$Res> {
  factory _$LeaveDtoCopyWith(_LeaveDto value, $Res Function(_LeaveDto) _then) = __$LeaveDtoCopyWithImpl;
@override @useResult
$Res call({
 String? id,@JsonKey(name: 'leave_id') String? leaveId,@JsonKey(name: 'school_id') String? schoolId,@JsonKey(name: 'user_type') String? userType,@JsonKey(name: 'student_id') String? studentId,@JsonKey(name: 'staff_id') String? staffId,@JsonKey(name: 'leave_type_id') String? leaveTypeId,@JsonKey(name: 'from_date') dynamic fromDate,@JsonKey(name: 'to_date') dynamic toDate,@JsonKey(name: 'total_days') num? totalDays, String? reason,@JsonKey(name: 'approval_status') String? approvalStatus,@JsonKey(name: 'approved_by') String? approvedBy,@JsonKey(name: 'approved_at') dynamic approvedAt, String? remarks
});




}
/// @nodoc
class __$LeaveDtoCopyWithImpl<$Res>
    implements _$LeaveDtoCopyWith<$Res> {
  __$LeaveDtoCopyWithImpl(this._self, this._then);

  final _LeaveDto _self;
  final $Res Function(_LeaveDto) _then;

/// Create a copy of LeaveDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = freezed,Object? leaveId = freezed,Object? schoolId = freezed,Object? userType = freezed,Object? studentId = freezed,Object? staffId = freezed,Object? leaveTypeId = freezed,Object? fromDate = freezed,Object? toDate = freezed,Object? totalDays = freezed,Object? reason = freezed,Object? approvalStatus = freezed,Object? approvedBy = freezed,Object? approvedAt = freezed,Object? remarks = freezed,}) {
  return _then(_LeaveDto(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,leaveId: freezed == leaveId ? _self.leaveId : leaveId // ignore: cast_nullable_to_non_nullable
as String?,schoolId: freezed == schoolId ? _self.schoolId : schoolId // ignore: cast_nullable_to_non_nullable
as String?,userType: freezed == userType ? _self.userType : userType // ignore: cast_nullable_to_non_nullable
as String?,studentId: freezed == studentId ? _self.studentId : studentId // ignore: cast_nullable_to_non_nullable
as String?,staffId: freezed == staffId ? _self.staffId : staffId // ignore: cast_nullable_to_non_nullable
as String?,leaveTypeId: freezed == leaveTypeId ? _self.leaveTypeId : leaveTypeId // ignore: cast_nullable_to_non_nullable
as String?,fromDate: freezed == fromDate ? _self.fromDate : fromDate // ignore: cast_nullable_to_non_nullable
as dynamic,toDate: freezed == toDate ? _self.toDate : toDate // ignore: cast_nullable_to_non_nullable
as dynamic,totalDays: freezed == totalDays ? _self.totalDays : totalDays // ignore: cast_nullable_to_non_nullable
as num?,reason: freezed == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String?,approvalStatus: freezed == approvalStatus ? _self.approvalStatus : approvalStatus // ignore: cast_nullable_to_non_nullable
as String?,approvedBy: freezed == approvedBy ? _self.approvedBy : approvedBy // ignore: cast_nullable_to_non_nullable
as String?,approvedAt: freezed == approvedAt ? _self.approvedAt : approvedAt // ignore: cast_nullable_to_non_nullable
as dynamic,remarks: freezed == remarks ? _self.remarks : remarks // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$NotificationDto {

 String? get id;@JsonKey(name: 'notification_id') String? get notificationId;@JsonKey(name: 'notification_log_id') String? get notificationLogId;@JsonKey(name: 'school_id') String? get schoolId; String? get title; String? get message; String? get body;@JsonKey(name: 'notification_type') String? get notificationType; String? get type;@JsonKey(name: 'target_role') String? get targetRole;@JsonKey(name: 'target_user_id') String? get targetUserId; String? get priority; String? get route;@JsonKey(name: 'reference_type') String? get referenceType;@JsonKey(name: 'reference_id') String? get referenceId;@JsonKey(name: 'is_read') bool? get isRead;@JsonKey(name: 'read_at') dynamic get readAt;@JsonKey(name: 'sent_at') dynamic get sentAt;
/// Create a copy of NotificationDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NotificationDtoCopyWith<NotificationDto> get copyWith => _$NotificationDtoCopyWithImpl<NotificationDto>(this as NotificationDto, _$identity);

  /// Serializes this NotificationDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NotificationDto&&(identical(other.id, id) || other.id == id)&&(identical(other.notificationId, notificationId) || other.notificationId == notificationId)&&(identical(other.notificationLogId, notificationLogId) || other.notificationLogId == notificationLogId)&&(identical(other.schoolId, schoolId) || other.schoolId == schoolId)&&(identical(other.title, title) || other.title == title)&&(identical(other.message, message) || other.message == message)&&(identical(other.body, body) || other.body == body)&&(identical(other.notificationType, notificationType) || other.notificationType == notificationType)&&(identical(other.type, type) || other.type == type)&&(identical(other.targetRole, targetRole) || other.targetRole == targetRole)&&(identical(other.targetUserId, targetUserId) || other.targetUserId == targetUserId)&&(identical(other.priority, priority) || other.priority == priority)&&(identical(other.route, route) || other.route == route)&&(identical(other.referenceType, referenceType) || other.referenceType == referenceType)&&(identical(other.referenceId, referenceId) || other.referenceId == referenceId)&&(identical(other.isRead, isRead) || other.isRead == isRead)&&const DeepCollectionEquality().equals(other.readAt, readAt)&&const DeepCollectionEquality().equals(other.sentAt, sentAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,notificationId,notificationLogId,schoolId,title,message,body,notificationType,type,targetRole,targetUserId,priority,route,referenceType,referenceId,isRead,const DeepCollectionEquality().hash(readAt),const DeepCollectionEquality().hash(sentAt));

@override
String toString() {
  return 'NotificationDto(id: $id, notificationId: $notificationId, notificationLogId: $notificationLogId, schoolId: $schoolId, title: $title, message: $message, body: $body, notificationType: $notificationType, type: $type, targetRole: $targetRole, targetUserId: $targetUserId, priority: $priority, route: $route, referenceType: $referenceType, referenceId: $referenceId, isRead: $isRead, readAt: $readAt, sentAt: $sentAt)';
}


}

/// @nodoc
abstract mixin class $NotificationDtoCopyWith<$Res>  {
  factory $NotificationDtoCopyWith(NotificationDto value, $Res Function(NotificationDto) _then) = _$NotificationDtoCopyWithImpl;
@useResult
$Res call({
 String? id,@JsonKey(name: 'notification_id') String? notificationId,@JsonKey(name: 'notification_log_id') String? notificationLogId,@JsonKey(name: 'school_id') String? schoolId, String? title, String? message, String? body,@JsonKey(name: 'notification_type') String? notificationType, String? type,@JsonKey(name: 'target_role') String? targetRole,@JsonKey(name: 'target_user_id') String? targetUserId, String? priority, String? route,@JsonKey(name: 'reference_type') String? referenceType,@JsonKey(name: 'reference_id') String? referenceId,@JsonKey(name: 'is_read') bool? isRead,@JsonKey(name: 'read_at') dynamic readAt,@JsonKey(name: 'sent_at') dynamic sentAt
});




}
/// @nodoc
class _$NotificationDtoCopyWithImpl<$Res>
    implements $NotificationDtoCopyWith<$Res> {
  _$NotificationDtoCopyWithImpl(this._self, this._then);

  final NotificationDto _self;
  final $Res Function(NotificationDto) _then;

/// Create a copy of NotificationDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = freezed,Object? notificationId = freezed,Object? notificationLogId = freezed,Object? schoolId = freezed,Object? title = freezed,Object? message = freezed,Object? body = freezed,Object? notificationType = freezed,Object? type = freezed,Object? targetRole = freezed,Object? targetUserId = freezed,Object? priority = freezed,Object? route = freezed,Object? referenceType = freezed,Object? referenceId = freezed,Object? isRead = freezed,Object? readAt = freezed,Object? sentAt = freezed,}) {
  return _then(_self.copyWith(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,notificationId: freezed == notificationId ? _self.notificationId : notificationId // ignore: cast_nullable_to_non_nullable
as String?,notificationLogId: freezed == notificationLogId ? _self.notificationLogId : notificationLogId // ignore: cast_nullable_to_non_nullable
as String?,schoolId: freezed == schoolId ? _self.schoolId : schoolId // ignore: cast_nullable_to_non_nullable
as String?,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,message: freezed == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String?,body: freezed == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String?,notificationType: freezed == notificationType ? _self.notificationType : notificationType // ignore: cast_nullable_to_non_nullable
as String?,type: freezed == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String?,targetRole: freezed == targetRole ? _self.targetRole : targetRole // ignore: cast_nullable_to_non_nullable
as String?,targetUserId: freezed == targetUserId ? _self.targetUserId : targetUserId // ignore: cast_nullable_to_non_nullable
as String?,priority: freezed == priority ? _self.priority : priority // ignore: cast_nullable_to_non_nullable
as String?,route: freezed == route ? _self.route : route // ignore: cast_nullable_to_non_nullable
as String?,referenceType: freezed == referenceType ? _self.referenceType : referenceType // ignore: cast_nullable_to_non_nullable
as String?,referenceId: freezed == referenceId ? _self.referenceId : referenceId // ignore: cast_nullable_to_non_nullable
as String?,isRead: freezed == isRead ? _self.isRead : isRead // ignore: cast_nullable_to_non_nullable
as bool?,readAt: freezed == readAt ? _self.readAt : readAt // ignore: cast_nullable_to_non_nullable
as dynamic,sentAt: freezed == sentAt ? _self.sentAt : sentAt // ignore: cast_nullable_to_non_nullable
as dynamic,
  ));
}

}


/// Adds pattern-matching-related methods to [NotificationDto].
extension NotificationDtoPatterns on NotificationDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _NotificationDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _NotificationDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _NotificationDto value)  $default,){
final _that = this;
switch (_that) {
case _NotificationDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _NotificationDto value)?  $default,){
final _that = this;
switch (_that) {
case _NotificationDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? id, @JsonKey(name: 'notification_id')  String? notificationId, @JsonKey(name: 'notification_log_id')  String? notificationLogId, @JsonKey(name: 'school_id')  String? schoolId,  String? title,  String? message,  String? body, @JsonKey(name: 'notification_type')  String? notificationType,  String? type, @JsonKey(name: 'target_role')  String? targetRole, @JsonKey(name: 'target_user_id')  String? targetUserId,  String? priority,  String? route, @JsonKey(name: 'reference_type')  String? referenceType, @JsonKey(name: 'reference_id')  String? referenceId, @JsonKey(name: 'is_read')  bool? isRead, @JsonKey(name: 'read_at')  dynamic readAt, @JsonKey(name: 'sent_at')  dynamic sentAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _NotificationDto() when $default != null:
return $default(_that.id,_that.notificationId,_that.notificationLogId,_that.schoolId,_that.title,_that.message,_that.body,_that.notificationType,_that.type,_that.targetRole,_that.targetUserId,_that.priority,_that.route,_that.referenceType,_that.referenceId,_that.isRead,_that.readAt,_that.sentAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? id, @JsonKey(name: 'notification_id')  String? notificationId, @JsonKey(name: 'notification_log_id')  String? notificationLogId, @JsonKey(name: 'school_id')  String? schoolId,  String? title,  String? message,  String? body, @JsonKey(name: 'notification_type')  String? notificationType,  String? type, @JsonKey(name: 'target_role')  String? targetRole, @JsonKey(name: 'target_user_id')  String? targetUserId,  String? priority,  String? route, @JsonKey(name: 'reference_type')  String? referenceType, @JsonKey(name: 'reference_id')  String? referenceId, @JsonKey(name: 'is_read')  bool? isRead, @JsonKey(name: 'read_at')  dynamic readAt, @JsonKey(name: 'sent_at')  dynamic sentAt)  $default,) {final _that = this;
switch (_that) {
case _NotificationDto():
return $default(_that.id,_that.notificationId,_that.notificationLogId,_that.schoolId,_that.title,_that.message,_that.body,_that.notificationType,_that.type,_that.targetRole,_that.targetUserId,_that.priority,_that.route,_that.referenceType,_that.referenceId,_that.isRead,_that.readAt,_that.sentAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? id, @JsonKey(name: 'notification_id')  String? notificationId, @JsonKey(name: 'notification_log_id')  String? notificationLogId, @JsonKey(name: 'school_id')  String? schoolId,  String? title,  String? message,  String? body, @JsonKey(name: 'notification_type')  String? notificationType,  String? type, @JsonKey(name: 'target_role')  String? targetRole, @JsonKey(name: 'target_user_id')  String? targetUserId,  String? priority,  String? route, @JsonKey(name: 'reference_type')  String? referenceType, @JsonKey(name: 'reference_id')  String? referenceId, @JsonKey(name: 'is_read')  bool? isRead, @JsonKey(name: 'read_at')  dynamic readAt, @JsonKey(name: 'sent_at')  dynamic sentAt)?  $default,) {final _that = this;
switch (_that) {
case _NotificationDto() when $default != null:
return $default(_that.id,_that.notificationId,_that.notificationLogId,_that.schoolId,_that.title,_that.message,_that.body,_that.notificationType,_that.type,_that.targetRole,_that.targetUserId,_that.priority,_that.route,_that.referenceType,_that.referenceId,_that.isRead,_that.readAt,_that.sentAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _NotificationDto implements NotificationDto {
  const _NotificationDto({this.id, @JsonKey(name: 'notification_id') this.notificationId, @JsonKey(name: 'notification_log_id') this.notificationLogId, @JsonKey(name: 'school_id') this.schoolId, this.title, this.message, this.body, @JsonKey(name: 'notification_type') this.notificationType, this.type, @JsonKey(name: 'target_role') this.targetRole, @JsonKey(name: 'target_user_id') this.targetUserId, this.priority, this.route, @JsonKey(name: 'reference_type') this.referenceType, @JsonKey(name: 'reference_id') this.referenceId, @JsonKey(name: 'is_read') this.isRead, @JsonKey(name: 'read_at') this.readAt, @JsonKey(name: 'sent_at') this.sentAt});
  factory _NotificationDto.fromJson(Map<String, dynamic> json) => _$NotificationDtoFromJson(json);

@override final  String? id;
@override@JsonKey(name: 'notification_id') final  String? notificationId;
@override@JsonKey(name: 'notification_log_id') final  String? notificationLogId;
@override@JsonKey(name: 'school_id') final  String? schoolId;
@override final  String? title;
@override final  String? message;
@override final  String? body;
@override@JsonKey(name: 'notification_type') final  String? notificationType;
@override final  String? type;
@override@JsonKey(name: 'target_role') final  String? targetRole;
@override@JsonKey(name: 'target_user_id') final  String? targetUserId;
@override final  String? priority;
@override final  String? route;
@override@JsonKey(name: 'reference_type') final  String? referenceType;
@override@JsonKey(name: 'reference_id') final  String? referenceId;
@override@JsonKey(name: 'is_read') final  bool? isRead;
@override@JsonKey(name: 'read_at') final  dynamic readAt;
@override@JsonKey(name: 'sent_at') final  dynamic sentAt;

/// Create a copy of NotificationDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$NotificationDtoCopyWith<_NotificationDto> get copyWith => __$NotificationDtoCopyWithImpl<_NotificationDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$NotificationDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _NotificationDto&&(identical(other.id, id) || other.id == id)&&(identical(other.notificationId, notificationId) || other.notificationId == notificationId)&&(identical(other.notificationLogId, notificationLogId) || other.notificationLogId == notificationLogId)&&(identical(other.schoolId, schoolId) || other.schoolId == schoolId)&&(identical(other.title, title) || other.title == title)&&(identical(other.message, message) || other.message == message)&&(identical(other.body, body) || other.body == body)&&(identical(other.notificationType, notificationType) || other.notificationType == notificationType)&&(identical(other.type, type) || other.type == type)&&(identical(other.targetRole, targetRole) || other.targetRole == targetRole)&&(identical(other.targetUserId, targetUserId) || other.targetUserId == targetUserId)&&(identical(other.priority, priority) || other.priority == priority)&&(identical(other.route, route) || other.route == route)&&(identical(other.referenceType, referenceType) || other.referenceType == referenceType)&&(identical(other.referenceId, referenceId) || other.referenceId == referenceId)&&(identical(other.isRead, isRead) || other.isRead == isRead)&&const DeepCollectionEquality().equals(other.readAt, readAt)&&const DeepCollectionEquality().equals(other.sentAt, sentAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,notificationId,notificationLogId,schoolId,title,message,body,notificationType,type,targetRole,targetUserId,priority,route,referenceType,referenceId,isRead,const DeepCollectionEquality().hash(readAt),const DeepCollectionEquality().hash(sentAt));

@override
String toString() {
  return 'NotificationDto(id: $id, notificationId: $notificationId, notificationLogId: $notificationLogId, schoolId: $schoolId, title: $title, message: $message, body: $body, notificationType: $notificationType, type: $type, targetRole: $targetRole, targetUserId: $targetUserId, priority: $priority, route: $route, referenceType: $referenceType, referenceId: $referenceId, isRead: $isRead, readAt: $readAt, sentAt: $sentAt)';
}


}

/// @nodoc
abstract mixin class _$NotificationDtoCopyWith<$Res> implements $NotificationDtoCopyWith<$Res> {
  factory _$NotificationDtoCopyWith(_NotificationDto value, $Res Function(_NotificationDto) _then) = __$NotificationDtoCopyWithImpl;
@override @useResult
$Res call({
 String? id,@JsonKey(name: 'notification_id') String? notificationId,@JsonKey(name: 'notification_log_id') String? notificationLogId,@JsonKey(name: 'school_id') String? schoolId, String? title, String? message, String? body,@JsonKey(name: 'notification_type') String? notificationType, String? type,@JsonKey(name: 'target_role') String? targetRole,@JsonKey(name: 'target_user_id') String? targetUserId, String? priority, String? route,@JsonKey(name: 'reference_type') String? referenceType,@JsonKey(name: 'reference_id') String? referenceId,@JsonKey(name: 'is_read') bool? isRead,@JsonKey(name: 'read_at') dynamic readAt,@JsonKey(name: 'sent_at') dynamic sentAt
});




}
/// @nodoc
class __$NotificationDtoCopyWithImpl<$Res>
    implements _$NotificationDtoCopyWith<$Res> {
  __$NotificationDtoCopyWithImpl(this._self, this._then);

  final _NotificationDto _self;
  final $Res Function(_NotificationDto) _then;

/// Create a copy of NotificationDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = freezed,Object? notificationId = freezed,Object? notificationLogId = freezed,Object? schoolId = freezed,Object? title = freezed,Object? message = freezed,Object? body = freezed,Object? notificationType = freezed,Object? type = freezed,Object? targetRole = freezed,Object? targetUserId = freezed,Object? priority = freezed,Object? route = freezed,Object? referenceType = freezed,Object? referenceId = freezed,Object? isRead = freezed,Object? readAt = freezed,Object? sentAt = freezed,}) {
  return _then(_NotificationDto(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,notificationId: freezed == notificationId ? _self.notificationId : notificationId // ignore: cast_nullable_to_non_nullable
as String?,notificationLogId: freezed == notificationLogId ? _self.notificationLogId : notificationLogId // ignore: cast_nullable_to_non_nullable
as String?,schoolId: freezed == schoolId ? _self.schoolId : schoolId // ignore: cast_nullable_to_non_nullable
as String?,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,message: freezed == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String?,body: freezed == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String?,notificationType: freezed == notificationType ? _self.notificationType : notificationType // ignore: cast_nullable_to_non_nullable
as String?,type: freezed == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String?,targetRole: freezed == targetRole ? _self.targetRole : targetRole // ignore: cast_nullable_to_non_nullable
as String?,targetUserId: freezed == targetUserId ? _self.targetUserId : targetUserId // ignore: cast_nullable_to_non_nullable
as String?,priority: freezed == priority ? _self.priority : priority // ignore: cast_nullable_to_non_nullable
as String?,route: freezed == route ? _self.route : route // ignore: cast_nullable_to_non_nullable
as String?,referenceType: freezed == referenceType ? _self.referenceType : referenceType // ignore: cast_nullable_to_non_nullable
as String?,referenceId: freezed == referenceId ? _self.referenceId : referenceId // ignore: cast_nullable_to_non_nullable
as String?,isRead: freezed == isRead ? _self.isRead : isRead // ignore: cast_nullable_to_non_nullable
as bool?,readAt: freezed == readAt ? _self.readAt : readAt // ignore: cast_nullable_to_non_nullable
as dynamic,sentAt: freezed == sentAt ? _self.sentAt : sentAt // ignore: cast_nullable_to_non_nullable
as dynamic,
  ));
}


}


/// @nodoc
mixin _$HolidayDto {

 String? get id;@JsonKey(name: 'holiday_id') String? get holidayId;@JsonKey(name: 'school_id') String? get schoolId;@JsonKey(name: 'holiday_name') String? get holidayName;@JsonKey(name: 'holiday_type') String? get holidayType;@JsonKey(name: 'start_date') dynamic get startDate;@JsonKey(name: 'end_date') dynamic get endDate; String? get description;@JsonKey(name: 'is_optional') bool? get isOptional;@JsonKey(name: 'applicable_for') String? get applicableFor; String? get status;
/// Create a copy of HolidayDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$HolidayDtoCopyWith<HolidayDto> get copyWith => _$HolidayDtoCopyWithImpl<HolidayDto>(this as HolidayDto, _$identity);

  /// Serializes this HolidayDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is HolidayDto&&(identical(other.id, id) || other.id == id)&&(identical(other.holidayId, holidayId) || other.holidayId == holidayId)&&(identical(other.schoolId, schoolId) || other.schoolId == schoolId)&&(identical(other.holidayName, holidayName) || other.holidayName == holidayName)&&(identical(other.holidayType, holidayType) || other.holidayType == holidayType)&&const DeepCollectionEquality().equals(other.startDate, startDate)&&const DeepCollectionEquality().equals(other.endDate, endDate)&&(identical(other.description, description) || other.description == description)&&(identical(other.isOptional, isOptional) || other.isOptional == isOptional)&&(identical(other.applicableFor, applicableFor) || other.applicableFor == applicableFor)&&(identical(other.status, status) || other.status == status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,holidayId,schoolId,holidayName,holidayType,const DeepCollectionEquality().hash(startDate),const DeepCollectionEquality().hash(endDate),description,isOptional,applicableFor,status);

@override
String toString() {
  return 'HolidayDto(id: $id, holidayId: $holidayId, schoolId: $schoolId, holidayName: $holidayName, holidayType: $holidayType, startDate: $startDate, endDate: $endDate, description: $description, isOptional: $isOptional, applicableFor: $applicableFor, status: $status)';
}


}

/// @nodoc
abstract mixin class $HolidayDtoCopyWith<$Res>  {
  factory $HolidayDtoCopyWith(HolidayDto value, $Res Function(HolidayDto) _then) = _$HolidayDtoCopyWithImpl;
@useResult
$Res call({
 String? id,@JsonKey(name: 'holiday_id') String? holidayId,@JsonKey(name: 'school_id') String? schoolId,@JsonKey(name: 'holiday_name') String? holidayName,@JsonKey(name: 'holiday_type') String? holidayType,@JsonKey(name: 'start_date') dynamic startDate,@JsonKey(name: 'end_date') dynamic endDate, String? description,@JsonKey(name: 'is_optional') bool? isOptional,@JsonKey(name: 'applicable_for') String? applicableFor, String? status
});




}
/// @nodoc
class _$HolidayDtoCopyWithImpl<$Res>
    implements $HolidayDtoCopyWith<$Res> {
  _$HolidayDtoCopyWithImpl(this._self, this._then);

  final HolidayDto _self;
  final $Res Function(HolidayDto) _then;

/// Create a copy of HolidayDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = freezed,Object? holidayId = freezed,Object? schoolId = freezed,Object? holidayName = freezed,Object? holidayType = freezed,Object? startDate = freezed,Object? endDate = freezed,Object? description = freezed,Object? isOptional = freezed,Object? applicableFor = freezed,Object? status = freezed,}) {
  return _then(_self.copyWith(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,holidayId: freezed == holidayId ? _self.holidayId : holidayId // ignore: cast_nullable_to_non_nullable
as String?,schoolId: freezed == schoolId ? _self.schoolId : schoolId // ignore: cast_nullable_to_non_nullable
as String?,holidayName: freezed == holidayName ? _self.holidayName : holidayName // ignore: cast_nullable_to_non_nullable
as String?,holidayType: freezed == holidayType ? _self.holidayType : holidayType // ignore: cast_nullable_to_non_nullable
as String?,startDate: freezed == startDate ? _self.startDate : startDate // ignore: cast_nullable_to_non_nullable
as dynamic,endDate: freezed == endDate ? _self.endDate : endDate // ignore: cast_nullable_to_non_nullable
as dynamic,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,isOptional: freezed == isOptional ? _self.isOptional : isOptional // ignore: cast_nullable_to_non_nullable
as bool?,applicableFor: freezed == applicableFor ? _self.applicableFor : applicableFor // ignore: cast_nullable_to_non_nullable
as String?,status: freezed == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [HolidayDto].
extension HolidayDtoPatterns on HolidayDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _HolidayDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _HolidayDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _HolidayDto value)  $default,){
final _that = this;
switch (_that) {
case _HolidayDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _HolidayDto value)?  $default,){
final _that = this;
switch (_that) {
case _HolidayDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? id, @JsonKey(name: 'holiday_id')  String? holidayId, @JsonKey(name: 'school_id')  String? schoolId, @JsonKey(name: 'holiday_name')  String? holidayName, @JsonKey(name: 'holiday_type')  String? holidayType, @JsonKey(name: 'start_date')  dynamic startDate, @JsonKey(name: 'end_date')  dynamic endDate,  String? description, @JsonKey(name: 'is_optional')  bool? isOptional, @JsonKey(name: 'applicable_for')  String? applicableFor,  String? status)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _HolidayDto() when $default != null:
return $default(_that.id,_that.holidayId,_that.schoolId,_that.holidayName,_that.holidayType,_that.startDate,_that.endDate,_that.description,_that.isOptional,_that.applicableFor,_that.status);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? id, @JsonKey(name: 'holiday_id')  String? holidayId, @JsonKey(name: 'school_id')  String? schoolId, @JsonKey(name: 'holiday_name')  String? holidayName, @JsonKey(name: 'holiday_type')  String? holidayType, @JsonKey(name: 'start_date')  dynamic startDate, @JsonKey(name: 'end_date')  dynamic endDate,  String? description, @JsonKey(name: 'is_optional')  bool? isOptional, @JsonKey(name: 'applicable_for')  String? applicableFor,  String? status)  $default,) {final _that = this;
switch (_that) {
case _HolidayDto():
return $default(_that.id,_that.holidayId,_that.schoolId,_that.holidayName,_that.holidayType,_that.startDate,_that.endDate,_that.description,_that.isOptional,_that.applicableFor,_that.status);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? id, @JsonKey(name: 'holiday_id')  String? holidayId, @JsonKey(name: 'school_id')  String? schoolId, @JsonKey(name: 'holiday_name')  String? holidayName, @JsonKey(name: 'holiday_type')  String? holidayType, @JsonKey(name: 'start_date')  dynamic startDate, @JsonKey(name: 'end_date')  dynamic endDate,  String? description, @JsonKey(name: 'is_optional')  bool? isOptional, @JsonKey(name: 'applicable_for')  String? applicableFor,  String? status)?  $default,) {final _that = this;
switch (_that) {
case _HolidayDto() when $default != null:
return $default(_that.id,_that.holidayId,_that.schoolId,_that.holidayName,_that.holidayType,_that.startDate,_that.endDate,_that.description,_that.isOptional,_that.applicableFor,_that.status);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _HolidayDto implements HolidayDto {
  const _HolidayDto({this.id, @JsonKey(name: 'holiday_id') this.holidayId, @JsonKey(name: 'school_id') this.schoolId, @JsonKey(name: 'holiday_name') this.holidayName, @JsonKey(name: 'holiday_type') this.holidayType, @JsonKey(name: 'start_date') this.startDate, @JsonKey(name: 'end_date') this.endDate, this.description, @JsonKey(name: 'is_optional') this.isOptional, @JsonKey(name: 'applicable_for') this.applicableFor, this.status});
  factory _HolidayDto.fromJson(Map<String, dynamic> json) => _$HolidayDtoFromJson(json);

@override final  String? id;
@override@JsonKey(name: 'holiday_id') final  String? holidayId;
@override@JsonKey(name: 'school_id') final  String? schoolId;
@override@JsonKey(name: 'holiday_name') final  String? holidayName;
@override@JsonKey(name: 'holiday_type') final  String? holidayType;
@override@JsonKey(name: 'start_date') final  dynamic startDate;
@override@JsonKey(name: 'end_date') final  dynamic endDate;
@override final  String? description;
@override@JsonKey(name: 'is_optional') final  bool? isOptional;
@override@JsonKey(name: 'applicable_for') final  String? applicableFor;
@override final  String? status;

/// Create a copy of HolidayDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$HolidayDtoCopyWith<_HolidayDto> get copyWith => __$HolidayDtoCopyWithImpl<_HolidayDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$HolidayDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _HolidayDto&&(identical(other.id, id) || other.id == id)&&(identical(other.holidayId, holidayId) || other.holidayId == holidayId)&&(identical(other.schoolId, schoolId) || other.schoolId == schoolId)&&(identical(other.holidayName, holidayName) || other.holidayName == holidayName)&&(identical(other.holidayType, holidayType) || other.holidayType == holidayType)&&const DeepCollectionEquality().equals(other.startDate, startDate)&&const DeepCollectionEquality().equals(other.endDate, endDate)&&(identical(other.description, description) || other.description == description)&&(identical(other.isOptional, isOptional) || other.isOptional == isOptional)&&(identical(other.applicableFor, applicableFor) || other.applicableFor == applicableFor)&&(identical(other.status, status) || other.status == status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,holidayId,schoolId,holidayName,holidayType,const DeepCollectionEquality().hash(startDate),const DeepCollectionEquality().hash(endDate),description,isOptional,applicableFor,status);

@override
String toString() {
  return 'HolidayDto(id: $id, holidayId: $holidayId, schoolId: $schoolId, holidayName: $holidayName, holidayType: $holidayType, startDate: $startDate, endDate: $endDate, description: $description, isOptional: $isOptional, applicableFor: $applicableFor, status: $status)';
}


}

/// @nodoc
abstract mixin class _$HolidayDtoCopyWith<$Res> implements $HolidayDtoCopyWith<$Res> {
  factory _$HolidayDtoCopyWith(_HolidayDto value, $Res Function(_HolidayDto) _then) = __$HolidayDtoCopyWithImpl;
@override @useResult
$Res call({
 String? id,@JsonKey(name: 'holiday_id') String? holidayId,@JsonKey(name: 'school_id') String? schoolId,@JsonKey(name: 'holiday_name') String? holidayName,@JsonKey(name: 'holiday_type') String? holidayType,@JsonKey(name: 'start_date') dynamic startDate,@JsonKey(name: 'end_date') dynamic endDate, String? description,@JsonKey(name: 'is_optional') bool? isOptional,@JsonKey(name: 'applicable_for') String? applicableFor, String? status
});




}
/// @nodoc
class __$HolidayDtoCopyWithImpl<$Res>
    implements _$HolidayDtoCopyWith<$Res> {
  __$HolidayDtoCopyWithImpl(this._self, this._then);

  final _HolidayDto _self;
  final $Res Function(_HolidayDto) _then;

/// Create a copy of HolidayDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = freezed,Object? holidayId = freezed,Object? schoolId = freezed,Object? holidayName = freezed,Object? holidayType = freezed,Object? startDate = freezed,Object? endDate = freezed,Object? description = freezed,Object? isOptional = freezed,Object? applicableFor = freezed,Object? status = freezed,}) {
  return _then(_HolidayDto(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,holidayId: freezed == holidayId ? _self.holidayId : holidayId // ignore: cast_nullable_to_non_nullable
as String?,schoolId: freezed == schoolId ? _self.schoolId : schoolId // ignore: cast_nullable_to_non_nullable
as String?,holidayName: freezed == holidayName ? _self.holidayName : holidayName // ignore: cast_nullable_to_non_nullable
as String?,holidayType: freezed == holidayType ? _self.holidayType : holidayType // ignore: cast_nullable_to_non_nullable
as String?,startDate: freezed == startDate ? _self.startDate : startDate // ignore: cast_nullable_to_non_nullable
as dynamic,endDate: freezed == endDate ? _self.endDate : endDate // ignore: cast_nullable_to_non_nullable
as dynamic,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,isOptional: freezed == isOptional ? _self.isOptional : isOptional // ignore: cast_nullable_to_non_nullable
as bool?,applicableFor: freezed == applicableFor ? _self.applicableFor : applicableFor // ignore: cast_nullable_to_non_nullable
as String?,status: freezed == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$EventDto {

 String? get id;@JsonKey(name: 'event_id') String? get eventId;@JsonKey(name: 'school_id') String? get schoolId;@JsonKey(name: 'event_name') String? get eventName;@JsonKey(name: 'event_type') String? get eventType; String? get description;@JsonKey(name: 'start_date') dynamic get startDate;@JsonKey(name: 'end_date') dynamic get endDate;@JsonKey(name: 'start_time') String? get startTime;@JsonKey(name: 'end_time') String? get endTime; String? get venue;@JsonKey(name: 'organizer_id') String? get organizerId;@JsonKey(name: 'audience_type') String? get audienceType;@JsonKey(name: 'attachment_url') String? get attachmentUrl; String? get status;@JsonKey(name: 'is_holiday') bool? get isHoliday;@JsonKey(name: 'academic_year_id') String? get academicYearId;
/// Create a copy of EventDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EventDtoCopyWith<EventDto> get copyWith => _$EventDtoCopyWithImpl<EventDto>(this as EventDto, _$identity);

  /// Serializes this EventDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is EventDto&&(identical(other.id, id) || other.id == id)&&(identical(other.eventId, eventId) || other.eventId == eventId)&&(identical(other.schoolId, schoolId) || other.schoolId == schoolId)&&(identical(other.eventName, eventName) || other.eventName == eventName)&&(identical(other.eventType, eventType) || other.eventType == eventType)&&(identical(other.description, description) || other.description == description)&&const DeepCollectionEquality().equals(other.startDate, startDate)&&const DeepCollectionEquality().equals(other.endDate, endDate)&&(identical(other.startTime, startTime) || other.startTime == startTime)&&(identical(other.endTime, endTime) || other.endTime == endTime)&&(identical(other.venue, venue) || other.venue == venue)&&(identical(other.organizerId, organizerId) || other.organizerId == organizerId)&&(identical(other.audienceType, audienceType) || other.audienceType == audienceType)&&(identical(other.attachmentUrl, attachmentUrl) || other.attachmentUrl == attachmentUrl)&&(identical(other.status, status) || other.status == status)&&(identical(other.isHoliday, isHoliday) || other.isHoliday == isHoliday)&&(identical(other.academicYearId, academicYearId) || other.academicYearId == academicYearId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,eventId,schoolId,eventName,eventType,description,const DeepCollectionEquality().hash(startDate),const DeepCollectionEquality().hash(endDate),startTime,endTime,venue,organizerId,audienceType,attachmentUrl,status,isHoliday,academicYearId);

@override
String toString() {
  return 'EventDto(id: $id, eventId: $eventId, schoolId: $schoolId, eventName: $eventName, eventType: $eventType, description: $description, startDate: $startDate, endDate: $endDate, startTime: $startTime, endTime: $endTime, venue: $venue, organizerId: $organizerId, audienceType: $audienceType, attachmentUrl: $attachmentUrl, status: $status, isHoliday: $isHoliday, academicYearId: $academicYearId)';
}


}

/// @nodoc
abstract mixin class $EventDtoCopyWith<$Res>  {
  factory $EventDtoCopyWith(EventDto value, $Res Function(EventDto) _then) = _$EventDtoCopyWithImpl;
@useResult
$Res call({
 String? id,@JsonKey(name: 'event_id') String? eventId,@JsonKey(name: 'school_id') String? schoolId,@JsonKey(name: 'event_name') String? eventName,@JsonKey(name: 'event_type') String? eventType, String? description,@JsonKey(name: 'start_date') dynamic startDate,@JsonKey(name: 'end_date') dynamic endDate,@JsonKey(name: 'start_time') String? startTime,@JsonKey(name: 'end_time') String? endTime, String? venue,@JsonKey(name: 'organizer_id') String? organizerId,@JsonKey(name: 'audience_type') String? audienceType,@JsonKey(name: 'attachment_url') String? attachmentUrl, String? status,@JsonKey(name: 'is_holiday') bool? isHoliday,@JsonKey(name: 'academic_year_id') String? academicYearId
});




}
/// @nodoc
class _$EventDtoCopyWithImpl<$Res>
    implements $EventDtoCopyWith<$Res> {
  _$EventDtoCopyWithImpl(this._self, this._then);

  final EventDto _self;
  final $Res Function(EventDto) _then;

/// Create a copy of EventDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = freezed,Object? eventId = freezed,Object? schoolId = freezed,Object? eventName = freezed,Object? eventType = freezed,Object? description = freezed,Object? startDate = freezed,Object? endDate = freezed,Object? startTime = freezed,Object? endTime = freezed,Object? venue = freezed,Object? organizerId = freezed,Object? audienceType = freezed,Object? attachmentUrl = freezed,Object? status = freezed,Object? isHoliday = freezed,Object? academicYearId = freezed,}) {
  return _then(_self.copyWith(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,eventId: freezed == eventId ? _self.eventId : eventId // ignore: cast_nullable_to_non_nullable
as String?,schoolId: freezed == schoolId ? _self.schoolId : schoolId // ignore: cast_nullable_to_non_nullable
as String?,eventName: freezed == eventName ? _self.eventName : eventName // ignore: cast_nullable_to_non_nullable
as String?,eventType: freezed == eventType ? _self.eventType : eventType // ignore: cast_nullable_to_non_nullable
as String?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,startDate: freezed == startDate ? _self.startDate : startDate // ignore: cast_nullable_to_non_nullable
as dynamic,endDate: freezed == endDate ? _self.endDate : endDate // ignore: cast_nullable_to_non_nullable
as dynamic,startTime: freezed == startTime ? _self.startTime : startTime // ignore: cast_nullable_to_non_nullable
as String?,endTime: freezed == endTime ? _self.endTime : endTime // ignore: cast_nullable_to_non_nullable
as String?,venue: freezed == venue ? _self.venue : venue // ignore: cast_nullable_to_non_nullable
as String?,organizerId: freezed == organizerId ? _self.organizerId : organizerId // ignore: cast_nullable_to_non_nullable
as String?,audienceType: freezed == audienceType ? _self.audienceType : audienceType // ignore: cast_nullable_to_non_nullable
as String?,attachmentUrl: freezed == attachmentUrl ? _self.attachmentUrl : attachmentUrl // ignore: cast_nullable_to_non_nullable
as String?,status: freezed == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String?,isHoliday: freezed == isHoliday ? _self.isHoliday : isHoliday // ignore: cast_nullable_to_non_nullable
as bool?,academicYearId: freezed == academicYearId ? _self.academicYearId : academicYearId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [EventDto].
extension EventDtoPatterns on EventDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _EventDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _EventDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _EventDto value)  $default,){
final _that = this;
switch (_that) {
case _EventDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _EventDto value)?  $default,){
final _that = this;
switch (_that) {
case _EventDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? id, @JsonKey(name: 'event_id')  String? eventId, @JsonKey(name: 'school_id')  String? schoolId, @JsonKey(name: 'event_name')  String? eventName, @JsonKey(name: 'event_type')  String? eventType,  String? description, @JsonKey(name: 'start_date')  dynamic startDate, @JsonKey(name: 'end_date')  dynamic endDate, @JsonKey(name: 'start_time')  String? startTime, @JsonKey(name: 'end_time')  String? endTime,  String? venue, @JsonKey(name: 'organizer_id')  String? organizerId, @JsonKey(name: 'audience_type')  String? audienceType, @JsonKey(name: 'attachment_url')  String? attachmentUrl,  String? status, @JsonKey(name: 'is_holiday')  bool? isHoliday, @JsonKey(name: 'academic_year_id')  String? academicYearId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _EventDto() when $default != null:
return $default(_that.id,_that.eventId,_that.schoolId,_that.eventName,_that.eventType,_that.description,_that.startDate,_that.endDate,_that.startTime,_that.endTime,_that.venue,_that.organizerId,_that.audienceType,_that.attachmentUrl,_that.status,_that.isHoliday,_that.academicYearId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? id, @JsonKey(name: 'event_id')  String? eventId, @JsonKey(name: 'school_id')  String? schoolId, @JsonKey(name: 'event_name')  String? eventName, @JsonKey(name: 'event_type')  String? eventType,  String? description, @JsonKey(name: 'start_date')  dynamic startDate, @JsonKey(name: 'end_date')  dynamic endDate, @JsonKey(name: 'start_time')  String? startTime, @JsonKey(name: 'end_time')  String? endTime,  String? venue, @JsonKey(name: 'organizer_id')  String? organizerId, @JsonKey(name: 'audience_type')  String? audienceType, @JsonKey(name: 'attachment_url')  String? attachmentUrl,  String? status, @JsonKey(name: 'is_holiday')  bool? isHoliday, @JsonKey(name: 'academic_year_id')  String? academicYearId)  $default,) {final _that = this;
switch (_that) {
case _EventDto():
return $default(_that.id,_that.eventId,_that.schoolId,_that.eventName,_that.eventType,_that.description,_that.startDate,_that.endDate,_that.startTime,_that.endTime,_that.venue,_that.organizerId,_that.audienceType,_that.attachmentUrl,_that.status,_that.isHoliday,_that.academicYearId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? id, @JsonKey(name: 'event_id')  String? eventId, @JsonKey(name: 'school_id')  String? schoolId, @JsonKey(name: 'event_name')  String? eventName, @JsonKey(name: 'event_type')  String? eventType,  String? description, @JsonKey(name: 'start_date')  dynamic startDate, @JsonKey(name: 'end_date')  dynamic endDate, @JsonKey(name: 'start_time')  String? startTime, @JsonKey(name: 'end_time')  String? endTime,  String? venue, @JsonKey(name: 'organizer_id')  String? organizerId, @JsonKey(name: 'audience_type')  String? audienceType, @JsonKey(name: 'attachment_url')  String? attachmentUrl,  String? status, @JsonKey(name: 'is_holiday')  bool? isHoliday, @JsonKey(name: 'academic_year_id')  String? academicYearId)?  $default,) {final _that = this;
switch (_that) {
case _EventDto() when $default != null:
return $default(_that.id,_that.eventId,_that.schoolId,_that.eventName,_that.eventType,_that.description,_that.startDate,_that.endDate,_that.startTime,_that.endTime,_that.venue,_that.organizerId,_that.audienceType,_that.attachmentUrl,_that.status,_that.isHoliday,_that.academicYearId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _EventDto implements EventDto {
  const _EventDto({this.id, @JsonKey(name: 'event_id') this.eventId, @JsonKey(name: 'school_id') this.schoolId, @JsonKey(name: 'event_name') this.eventName, @JsonKey(name: 'event_type') this.eventType, this.description, @JsonKey(name: 'start_date') this.startDate, @JsonKey(name: 'end_date') this.endDate, @JsonKey(name: 'start_time') this.startTime, @JsonKey(name: 'end_time') this.endTime, this.venue, @JsonKey(name: 'organizer_id') this.organizerId, @JsonKey(name: 'audience_type') this.audienceType, @JsonKey(name: 'attachment_url') this.attachmentUrl, this.status, @JsonKey(name: 'is_holiday') this.isHoliday, @JsonKey(name: 'academic_year_id') this.academicYearId});
  factory _EventDto.fromJson(Map<String, dynamic> json) => _$EventDtoFromJson(json);

@override final  String? id;
@override@JsonKey(name: 'event_id') final  String? eventId;
@override@JsonKey(name: 'school_id') final  String? schoolId;
@override@JsonKey(name: 'event_name') final  String? eventName;
@override@JsonKey(name: 'event_type') final  String? eventType;
@override final  String? description;
@override@JsonKey(name: 'start_date') final  dynamic startDate;
@override@JsonKey(name: 'end_date') final  dynamic endDate;
@override@JsonKey(name: 'start_time') final  String? startTime;
@override@JsonKey(name: 'end_time') final  String? endTime;
@override final  String? venue;
@override@JsonKey(name: 'organizer_id') final  String? organizerId;
@override@JsonKey(name: 'audience_type') final  String? audienceType;
@override@JsonKey(name: 'attachment_url') final  String? attachmentUrl;
@override final  String? status;
@override@JsonKey(name: 'is_holiday') final  bool? isHoliday;
@override@JsonKey(name: 'academic_year_id') final  String? academicYearId;

/// Create a copy of EventDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$EventDtoCopyWith<_EventDto> get copyWith => __$EventDtoCopyWithImpl<_EventDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$EventDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _EventDto&&(identical(other.id, id) || other.id == id)&&(identical(other.eventId, eventId) || other.eventId == eventId)&&(identical(other.schoolId, schoolId) || other.schoolId == schoolId)&&(identical(other.eventName, eventName) || other.eventName == eventName)&&(identical(other.eventType, eventType) || other.eventType == eventType)&&(identical(other.description, description) || other.description == description)&&const DeepCollectionEquality().equals(other.startDate, startDate)&&const DeepCollectionEquality().equals(other.endDate, endDate)&&(identical(other.startTime, startTime) || other.startTime == startTime)&&(identical(other.endTime, endTime) || other.endTime == endTime)&&(identical(other.venue, venue) || other.venue == venue)&&(identical(other.organizerId, organizerId) || other.organizerId == organizerId)&&(identical(other.audienceType, audienceType) || other.audienceType == audienceType)&&(identical(other.attachmentUrl, attachmentUrl) || other.attachmentUrl == attachmentUrl)&&(identical(other.status, status) || other.status == status)&&(identical(other.isHoliday, isHoliday) || other.isHoliday == isHoliday)&&(identical(other.academicYearId, academicYearId) || other.academicYearId == academicYearId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,eventId,schoolId,eventName,eventType,description,const DeepCollectionEquality().hash(startDate),const DeepCollectionEquality().hash(endDate),startTime,endTime,venue,organizerId,audienceType,attachmentUrl,status,isHoliday,academicYearId);

@override
String toString() {
  return 'EventDto(id: $id, eventId: $eventId, schoolId: $schoolId, eventName: $eventName, eventType: $eventType, description: $description, startDate: $startDate, endDate: $endDate, startTime: $startTime, endTime: $endTime, venue: $venue, organizerId: $organizerId, audienceType: $audienceType, attachmentUrl: $attachmentUrl, status: $status, isHoliday: $isHoliday, academicYearId: $academicYearId)';
}


}

/// @nodoc
abstract mixin class _$EventDtoCopyWith<$Res> implements $EventDtoCopyWith<$Res> {
  factory _$EventDtoCopyWith(_EventDto value, $Res Function(_EventDto) _then) = __$EventDtoCopyWithImpl;
@override @useResult
$Res call({
 String? id,@JsonKey(name: 'event_id') String? eventId,@JsonKey(name: 'school_id') String? schoolId,@JsonKey(name: 'event_name') String? eventName,@JsonKey(name: 'event_type') String? eventType, String? description,@JsonKey(name: 'start_date') dynamic startDate,@JsonKey(name: 'end_date') dynamic endDate,@JsonKey(name: 'start_time') String? startTime,@JsonKey(name: 'end_time') String? endTime, String? venue,@JsonKey(name: 'organizer_id') String? organizerId,@JsonKey(name: 'audience_type') String? audienceType,@JsonKey(name: 'attachment_url') String? attachmentUrl, String? status,@JsonKey(name: 'is_holiday') bool? isHoliday,@JsonKey(name: 'academic_year_id') String? academicYearId
});




}
/// @nodoc
class __$EventDtoCopyWithImpl<$Res>
    implements _$EventDtoCopyWith<$Res> {
  __$EventDtoCopyWithImpl(this._self, this._then);

  final _EventDto _self;
  final $Res Function(_EventDto) _then;

/// Create a copy of EventDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = freezed,Object? eventId = freezed,Object? schoolId = freezed,Object? eventName = freezed,Object? eventType = freezed,Object? description = freezed,Object? startDate = freezed,Object? endDate = freezed,Object? startTime = freezed,Object? endTime = freezed,Object? venue = freezed,Object? organizerId = freezed,Object? audienceType = freezed,Object? attachmentUrl = freezed,Object? status = freezed,Object? isHoliday = freezed,Object? academicYearId = freezed,}) {
  return _then(_EventDto(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,eventId: freezed == eventId ? _self.eventId : eventId // ignore: cast_nullable_to_non_nullable
as String?,schoolId: freezed == schoolId ? _self.schoolId : schoolId // ignore: cast_nullable_to_non_nullable
as String?,eventName: freezed == eventName ? _self.eventName : eventName // ignore: cast_nullable_to_non_nullable
as String?,eventType: freezed == eventType ? _self.eventType : eventType // ignore: cast_nullable_to_non_nullable
as String?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,startDate: freezed == startDate ? _self.startDate : startDate // ignore: cast_nullable_to_non_nullable
as dynamic,endDate: freezed == endDate ? _self.endDate : endDate // ignore: cast_nullable_to_non_nullable
as dynamic,startTime: freezed == startTime ? _self.startTime : startTime // ignore: cast_nullable_to_non_nullable
as String?,endTime: freezed == endTime ? _self.endTime : endTime // ignore: cast_nullable_to_non_nullable
as String?,venue: freezed == venue ? _self.venue : venue // ignore: cast_nullable_to_non_nullable
as String?,organizerId: freezed == organizerId ? _self.organizerId : organizerId // ignore: cast_nullable_to_non_nullable
as String?,audienceType: freezed == audienceType ? _self.audienceType : audienceType // ignore: cast_nullable_to_non_nullable
as String?,attachmentUrl: freezed == attachmentUrl ? _self.attachmentUrl : attachmentUrl // ignore: cast_nullable_to_non_nullable
as String?,status: freezed == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String?,isHoliday: freezed == isHoliday ? _self.isHoliday : isHoliday // ignore: cast_nullable_to_non_nullable
as bool?,academicYearId: freezed == academicYearId ? _self.academicYearId : academicYearId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$ApprovalRequestDto {

 String? get id;@JsonKey(name: 'approval_id') String? get approvalId;@JsonKey(name: 'school_id') String? get schoolId;@JsonKey(name: 'request_type') String? get requestType;@JsonKey(name: 'module_name') String? get moduleName;@JsonKey(name: 'reference_table') String? get referenceTable;@JsonKey(name: 'reference_id') String? get referenceId; String? get title; String? get description; String? get priority;@JsonKey(name: 'approval_status') String? get approvalStatus;@JsonKey(name: 'approved_by') String? get approvedBy;@JsonKey(name: 'approved_at') dynamic get approvedAt;
/// Create a copy of ApprovalRequestDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ApprovalRequestDtoCopyWith<ApprovalRequestDto> get copyWith => _$ApprovalRequestDtoCopyWithImpl<ApprovalRequestDto>(this as ApprovalRequestDto, _$identity);

  /// Serializes this ApprovalRequestDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ApprovalRequestDto&&(identical(other.id, id) || other.id == id)&&(identical(other.approvalId, approvalId) || other.approvalId == approvalId)&&(identical(other.schoolId, schoolId) || other.schoolId == schoolId)&&(identical(other.requestType, requestType) || other.requestType == requestType)&&(identical(other.moduleName, moduleName) || other.moduleName == moduleName)&&(identical(other.referenceTable, referenceTable) || other.referenceTable == referenceTable)&&(identical(other.referenceId, referenceId) || other.referenceId == referenceId)&&(identical(other.title, title) || other.title == title)&&(identical(other.description, description) || other.description == description)&&(identical(other.priority, priority) || other.priority == priority)&&(identical(other.approvalStatus, approvalStatus) || other.approvalStatus == approvalStatus)&&(identical(other.approvedBy, approvedBy) || other.approvedBy == approvedBy)&&const DeepCollectionEquality().equals(other.approvedAt, approvedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,approvalId,schoolId,requestType,moduleName,referenceTable,referenceId,title,description,priority,approvalStatus,approvedBy,const DeepCollectionEquality().hash(approvedAt));

@override
String toString() {
  return 'ApprovalRequestDto(id: $id, approvalId: $approvalId, schoolId: $schoolId, requestType: $requestType, moduleName: $moduleName, referenceTable: $referenceTable, referenceId: $referenceId, title: $title, description: $description, priority: $priority, approvalStatus: $approvalStatus, approvedBy: $approvedBy, approvedAt: $approvedAt)';
}


}

/// @nodoc
abstract mixin class $ApprovalRequestDtoCopyWith<$Res>  {
  factory $ApprovalRequestDtoCopyWith(ApprovalRequestDto value, $Res Function(ApprovalRequestDto) _then) = _$ApprovalRequestDtoCopyWithImpl;
@useResult
$Res call({
 String? id,@JsonKey(name: 'approval_id') String? approvalId,@JsonKey(name: 'school_id') String? schoolId,@JsonKey(name: 'request_type') String? requestType,@JsonKey(name: 'module_name') String? moduleName,@JsonKey(name: 'reference_table') String? referenceTable,@JsonKey(name: 'reference_id') String? referenceId, String? title, String? description, String? priority,@JsonKey(name: 'approval_status') String? approvalStatus,@JsonKey(name: 'approved_by') String? approvedBy,@JsonKey(name: 'approved_at') dynamic approvedAt
});




}
/// @nodoc
class _$ApprovalRequestDtoCopyWithImpl<$Res>
    implements $ApprovalRequestDtoCopyWith<$Res> {
  _$ApprovalRequestDtoCopyWithImpl(this._self, this._then);

  final ApprovalRequestDto _self;
  final $Res Function(ApprovalRequestDto) _then;

/// Create a copy of ApprovalRequestDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = freezed,Object? approvalId = freezed,Object? schoolId = freezed,Object? requestType = freezed,Object? moduleName = freezed,Object? referenceTable = freezed,Object? referenceId = freezed,Object? title = freezed,Object? description = freezed,Object? priority = freezed,Object? approvalStatus = freezed,Object? approvedBy = freezed,Object? approvedAt = freezed,}) {
  return _then(_self.copyWith(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,approvalId: freezed == approvalId ? _self.approvalId : approvalId // ignore: cast_nullable_to_non_nullable
as String?,schoolId: freezed == schoolId ? _self.schoolId : schoolId // ignore: cast_nullable_to_non_nullable
as String?,requestType: freezed == requestType ? _self.requestType : requestType // ignore: cast_nullable_to_non_nullable
as String?,moduleName: freezed == moduleName ? _self.moduleName : moduleName // ignore: cast_nullable_to_non_nullable
as String?,referenceTable: freezed == referenceTable ? _self.referenceTable : referenceTable // ignore: cast_nullable_to_non_nullable
as String?,referenceId: freezed == referenceId ? _self.referenceId : referenceId // ignore: cast_nullable_to_non_nullable
as String?,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,priority: freezed == priority ? _self.priority : priority // ignore: cast_nullable_to_non_nullable
as String?,approvalStatus: freezed == approvalStatus ? _self.approvalStatus : approvalStatus // ignore: cast_nullable_to_non_nullable
as String?,approvedBy: freezed == approvedBy ? _self.approvedBy : approvedBy // ignore: cast_nullable_to_non_nullable
as String?,approvedAt: freezed == approvedAt ? _self.approvedAt : approvedAt // ignore: cast_nullable_to_non_nullable
as dynamic,
  ));
}

}


/// Adds pattern-matching-related methods to [ApprovalRequestDto].
extension ApprovalRequestDtoPatterns on ApprovalRequestDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ApprovalRequestDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ApprovalRequestDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ApprovalRequestDto value)  $default,){
final _that = this;
switch (_that) {
case _ApprovalRequestDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ApprovalRequestDto value)?  $default,){
final _that = this;
switch (_that) {
case _ApprovalRequestDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? id, @JsonKey(name: 'approval_id')  String? approvalId, @JsonKey(name: 'school_id')  String? schoolId, @JsonKey(name: 'request_type')  String? requestType, @JsonKey(name: 'module_name')  String? moduleName, @JsonKey(name: 'reference_table')  String? referenceTable, @JsonKey(name: 'reference_id')  String? referenceId,  String? title,  String? description,  String? priority, @JsonKey(name: 'approval_status')  String? approvalStatus, @JsonKey(name: 'approved_by')  String? approvedBy, @JsonKey(name: 'approved_at')  dynamic approvedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ApprovalRequestDto() when $default != null:
return $default(_that.id,_that.approvalId,_that.schoolId,_that.requestType,_that.moduleName,_that.referenceTable,_that.referenceId,_that.title,_that.description,_that.priority,_that.approvalStatus,_that.approvedBy,_that.approvedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? id, @JsonKey(name: 'approval_id')  String? approvalId, @JsonKey(name: 'school_id')  String? schoolId, @JsonKey(name: 'request_type')  String? requestType, @JsonKey(name: 'module_name')  String? moduleName, @JsonKey(name: 'reference_table')  String? referenceTable, @JsonKey(name: 'reference_id')  String? referenceId,  String? title,  String? description,  String? priority, @JsonKey(name: 'approval_status')  String? approvalStatus, @JsonKey(name: 'approved_by')  String? approvedBy, @JsonKey(name: 'approved_at')  dynamic approvedAt)  $default,) {final _that = this;
switch (_that) {
case _ApprovalRequestDto():
return $default(_that.id,_that.approvalId,_that.schoolId,_that.requestType,_that.moduleName,_that.referenceTable,_that.referenceId,_that.title,_that.description,_that.priority,_that.approvalStatus,_that.approvedBy,_that.approvedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? id, @JsonKey(name: 'approval_id')  String? approvalId, @JsonKey(name: 'school_id')  String? schoolId, @JsonKey(name: 'request_type')  String? requestType, @JsonKey(name: 'module_name')  String? moduleName, @JsonKey(name: 'reference_table')  String? referenceTable, @JsonKey(name: 'reference_id')  String? referenceId,  String? title,  String? description,  String? priority, @JsonKey(name: 'approval_status')  String? approvalStatus, @JsonKey(name: 'approved_by')  String? approvedBy, @JsonKey(name: 'approved_at')  dynamic approvedAt)?  $default,) {final _that = this;
switch (_that) {
case _ApprovalRequestDto() when $default != null:
return $default(_that.id,_that.approvalId,_that.schoolId,_that.requestType,_that.moduleName,_that.referenceTable,_that.referenceId,_that.title,_that.description,_that.priority,_that.approvalStatus,_that.approvedBy,_that.approvedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ApprovalRequestDto implements ApprovalRequestDto {
  const _ApprovalRequestDto({this.id, @JsonKey(name: 'approval_id') this.approvalId, @JsonKey(name: 'school_id') this.schoolId, @JsonKey(name: 'request_type') this.requestType, @JsonKey(name: 'module_name') this.moduleName, @JsonKey(name: 'reference_table') this.referenceTable, @JsonKey(name: 'reference_id') this.referenceId, this.title, this.description, this.priority, @JsonKey(name: 'approval_status') this.approvalStatus, @JsonKey(name: 'approved_by') this.approvedBy, @JsonKey(name: 'approved_at') this.approvedAt});
  factory _ApprovalRequestDto.fromJson(Map<String, dynamic> json) => _$ApprovalRequestDtoFromJson(json);

@override final  String? id;
@override@JsonKey(name: 'approval_id') final  String? approvalId;
@override@JsonKey(name: 'school_id') final  String? schoolId;
@override@JsonKey(name: 'request_type') final  String? requestType;
@override@JsonKey(name: 'module_name') final  String? moduleName;
@override@JsonKey(name: 'reference_table') final  String? referenceTable;
@override@JsonKey(name: 'reference_id') final  String? referenceId;
@override final  String? title;
@override final  String? description;
@override final  String? priority;
@override@JsonKey(name: 'approval_status') final  String? approvalStatus;
@override@JsonKey(name: 'approved_by') final  String? approvedBy;
@override@JsonKey(name: 'approved_at') final  dynamic approvedAt;

/// Create a copy of ApprovalRequestDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ApprovalRequestDtoCopyWith<_ApprovalRequestDto> get copyWith => __$ApprovalRequestDtoCopyWithImpl<_ApprovalRequestDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ApprovalRequestDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ApprovalRequestDto&&(identical(other.id, id) || other.id == id)&&(identical(other.approvalId, approvalId) || other.approvalId == approvalId)&&(identical(other.schoolId, schoolId) || other.schoolId == schoolId)&&(identical(other.requestType, requestType) || other.requestType == requestType)&&(identical(other.moduleName, moduleName) || other.moduleName == moduleName)&&(identical(other.referenceTable, referenceTable) || other.referenceTable == referenceTable)&&(identical(other.referenceId, referenceId) || other.referenceId == referenceId)&&(identical(other.title, title) || other.title == title)&&(identical(other.description, description) || other.description == description)&&(identical(other.priority, priority) || other.priority == priority)&&(identical(other.approvalStatus, approvalStatus) || other.approvalStatus == approvalStatus)&&(identical(other.approvedBy, approvedBy) || other.approvedBy == approvedBy)&&const DeepCollectionEquality().equals(other.approvedAt, approvedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,approvalId,schoolId,requestType,moduleName,referenceTable,referenceId,title,description,priority,approvalStatus,approvedBy,const DeepCollectionEquality().hash(approvedAt));

@override
String toString() {
  return 'ApprovalRequestDto(id: $id, approvalId: $approvalId, schoolId: $schoolId, requestType: $requestType, moduleName: $moduleName, referenceTable: $referenceTable, referenceId: $referenceId, title: $title, description: $description, priority: $priority, approvalStatus: $approvalStatus, approvedBy: $approvedBy, approvedAt: $approvedAt)';
}


}

/// @nodoc
abstract mixin class _$ApprovalRequestDtoCopyWith<$Res> implements $ApprovalRequestDtoCopyWith<$Res> {
  factory _$ApprovalRequestDtoCopyWith(_ApprovalRequestDto value, $Res Function(_ApprovalRequestDto) _then) = __$ApprovalRequestDtoCopyWithImpl;
@override @useResult
$Res call({
 String? id,@JsonKey(name: 'approval_id') String? approvalId,@JsonKey(name: 'school_id') String? schoolId,@JsonKey(name: 'request_type') String? requestType,@JsonKey(name: 'module_name') String? moduleName,@JsonKey(name: 'reference_table') String? referenceTable,@JsonKey(name: 'reference_id') String? referenceId, String? title, String? description, String? priority,@JsonKey(name: 'approval_status') String? approvalStatus,@JsonKey(name: 'approved_by') String? approvedBy,@JsonKey(name: 'approved_at') dynamic approvedAt
});




}
/// @nodoc
class __$ApprovalRequestDtoCopyWithImpl<$Res>
    implements _$ApprovalRequestDtoCopyWith<$Res> {
  __$ApprovalRequestDtoCopyWithImpl(this._self, this._then);

  final _ApprovalRequestDto _self;
  final $Res Function(_ApprovalRequestDto) _then;

/// Create a copy of ApprovalRequestDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = freezed,Object? approvalId = freezed,Object? schoolId = freezed,Object? requestType = freezed,Object? moduleName = freezed,Object? referenceTable = freezed,Object? referenceId = freezed,Object? title = freezed,Object? description = freezed,Object? priority = freezed,Object? approvalStatus = freezed,Object? approvedBy = freezed,Object? approvedAt = freezed,}) {
  return _then(_ApprovalRequestDto(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,approvalId: freezed == approvalId ? _self.approvalId : approvalId // ignore: cast_nullable_to_non_nullable
as String?,schoolId: freezed == schoolId ? _self.schoolId : schoolId // ignore: cast_nullable_to_non_nullable
as String?,requestType: freezed == requestType ? _self.requestType : requestType // ignore: cast_nullable_to_non_nullable
as String?,moduleName: freezed == moduleName ? _self.moduleName : moduleName // ignore: cast_nullable_to_non_nullable
as String?,referenceTable: freezed == referenceTable ? _self.referenceTable : referenceTable // ignore: cast_nullable_to_non_nullable
as String?,referenceId: freezed == referenceId ? _self.referenceId : referenceId // ignore: cast_nullable_to_non_nullable
as String?,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,priority: freezed == priority ? _self.priority : priority // ignore: cast_nullable_to_non_nullable
as String?,approvalStatus: freezed == approvalStatus ? _self.approvalStatus : approvalStatus // ignore: cast_nullable_to_non_nullable
as String?,approvedBy: freezed == approvedBy ? _self.approvedBy : approvedBy // ignore: cast_nullable_to_non_nullable
as String?,approvedAt: freezed == approvedAt ? _self.approvedAt : approvedAt // ignore: cast_nullable_to_non_nullable
as dynamic,
  ));
}


}


/// @nodoc
mixin _$CommunicationDto {

 String? get id;@JsonKey(name: 'message_id') String? get messageId;@JsonKey(name: 'school_id') String? get schoolId;@JsonKey(name: 'sender_id') String? get senderId;@JsonKey(name: 'sender_role') String? get senderRole;@JsonKey(name: 'receiver_id') String? get receiverId;@JsonKey(name: 'receiver_role') String? get receiverRole;@JsonKey(name: 'student_id') String? get studentId;@JsonKey(name: 'message_type') String? get messageType;@JsonKey(name: 'message_content') String? get messageContent;@JsonKey(name: 'attachment_url') String? get attachmentUrl;@JsonKey(name: 'is_read') bool? get isRead;@JsonKey(name: 'sent_at') dynamic get sentAt;
/// Create a copy of CommunicationDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CommunicationDtoCopyWith<CommunicationDto> get copyWith => _$CommunicationDtoCopyWithImpl<CommunicationDto>(this as CommunicationDto, _$identity);

  /// Serializes this CommunicationDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CommunicationDto&&(identical(other.id, id) || other.id == id)&&(identical(other.messageId, messageId) || other.messageId == messageId)&&(identical(other.schoolId, schoolId) || other.schoolId == schoolId)&&(identical(other.senderId, senderId) || other.senderId == senderId)&&(identical(other.senderRole, senderRole) || other.senderRole == senderRole)&&(identical(other.receiverId, receiverId) || other.receiverId == receiverId)&&(identical(other.receiverRole, receiverRole) || other.receiverRole == receiverRole)&&(identical(other.studentId, studentId) || other.studentId == studentId)&&(identical(other.messageType, messageType) || other.messageType == messageType)&&(identical(other.messageContent, messageContent) || other.messageContent == messageContent)&&(identical(other.attachmentUrl, attachmentUrl) || other.attachmentUrl == attachmentUrl)&&(identical(other.isRead, isRead) || other.isRead == isRead)&&const DeepCollectionEquality().equals(other.sentAt, sentAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,messageId,schoolId,senderId,senderRole,receiverId,receiverRole,studentId,messageType,messageContent,attachmentUrl,isRead,const DeepCollectionEquality().hash(sentAt));

@override
String toString() {
  return 'CommunicationDto(id: $id, messageId: $messageId, schoolId: $schoolId, senderId: $senderId, senderRole: $senderRole, receiverId: $receiverId, receiverRole: $receiverRole, studentId: $studentId, messageType: $messageType, messageContent: $messageContent, attachmentUrl: $attachmentUrl, isRead: $isRead, sentAt: $sentAt)';
}


}

/// @nodoc
abstract mixin class $CommunicationDtoCopyWith<$Res>  {
  factory $CommunicationDtoCopyWith(CommunicationDto value, $Res Function(CommunicationDto) _then) = _$CommunicationDtoCopyWithImpl;
@useResult
$Res call({
 String? id,@JsonKey(name: 'message_id') String? messageId,@JsonKey(name: 'school_id') String? schoolId,@JsonKey(name: 'sender_id') String? senderId,@JsonKey(name: 'sender_role') String? senderRole,@JsonKey(name: 'receiver_id') String? receiverId,@JsonKey(name: 'receiver_role') String? receiverRole,@JsonKey(name: 'student_id') String? studentId,@JsonKey(name: 'message_type') String? messageType,@JsonKey(name: 'message_content') String? messageContent,@JsonKey(name: 'attachment_url') String? attachmentUrl,@JsonKey(name: 'is_read') bool? isRead,@JsonKey(name: 'sent_at') dynamic sentAt
});




}
/// @nodoc
class _$CommunicationDtoCopyWithImpl<$Res>
    implements $CommunicationDtoCopyWith<$Res> {
  _$CommunicationDtoCopyWithImpl(this._self, this._then);

  final CommunicationDto _self;
  final $Res Function(CommunicationDto) _then;

/// Create a copy of CommunicationDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = freezed,Object? messageId = freezed,Object? schoolId = freezed,Object? senderId = freezed,Object? senderRole = freezed,Object? receiverId = freezed,Object? receiverRole = freezed,Object? studentId = freezed,Object? messageType = freezed,Object? messageContent = freezed,Object? attachmentUrl = freezed,Object? isRead = freezed,Object? sentAt = freezed,}) {
  return _then(_self.copyWith(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,messageId: freezed == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as String?,schoolId: freezed == schoolId ? _self.schoolId : schoolId // ignore: cast_nullable_to_non_nullable
as String?,senderId: freezed == senderId ? _self.senderId : senderId // ignore: cast_nullable_to_non_nullable
as String?,senderRole: freezed == senderRole ? _self.senderRole : senderRole // ignore: cast_nullable_to_non_nullable
as String?,receiverId: freezed == receiverId ? _self.receiverId : receiverId // ignore: cast_nullable_to_non_nullable
as String?,receiverRole: freezed == receiverRole ? _self.receiverRole : receiverRole // ignore: cast_nullable_to_non_nullable
as String?,studentId: freezed == studentId ? _self.studentId : studentId // ignore: cast_nullable_to_non_nullable
as String?,messageType: freezed == messageType ? _self.messageType : messageType // ignore: cast_nullable_to_non_nullable
as String?,messageContent: freezed == messageContent ? _self.messageContent : messageContent // ignore: cast_nullable_to_non_nullable
as String?,attachmentUrl: freezed == attachmentUrl ? _self.attachmentUrl : attachmentUrl // ignore: cast_nullable_to_non_nullable
as String?,isRead: freezed == isRead ? _self.isRead : isRead // ignore: cast_nullable_to_non_nullable
as bool?,sentAt: freezed == sentAt ? _self.sentAt : sentAt // ignore: cast_nullable_to_non_nullable
as dynamic,
  ));
}

}


/// Adds pattern-matching-related methods to [CommunicationDto].
extension CommunicationDtoPatterns on CommunicationDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CommunicationDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CommunicationDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CommunicationDto value)  $default,){
final _that = this;
switch (_that) {
case _CommunicationDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CommunicationDto value)?  $default,){
final _that = this;
switch (_that) {
case _CommunicationDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? id, @JsonKey(name: 'message_id')  String? messageId, @JsonKey(name: 'school_id')  String? schoolId, @JsonKey(name: 'sender_id')  String? senderId, @JsonKey(name: 'sender_role')  String? senderRole, @JsonKey(name: 'receiver_id')  String? receiverId, @JsonKey(name: 'receiver_role')  String? receiverRole, @JsonKey(name: 'student_id')  String? studentId, @JsonKey(name: 'message_type')  String? messageType, @JsonKey(name: 'message_content')  String? messageContent, @JsonKey(name: 'attachment_url')  String? attachmentUrl, @JsonKey(name: 'is_read')  bool? isRead, @JsonKey(name: 'sent_at')  dynamic sentAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CommunicationDto() when $default != null:
return $default(_that.id,_that.messageId,_that.schoolId,_that.senderId,_that.senderRole,_that.receiverId,_that.receiverRole,_that.studentId,_that.messageType,_that.messageContent,_that.attachmentUrl,_that.isRead,_that.sentAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? id, @JsonKey(name: 'message_id')  String? messageId, @JsonKey(name: 'school_id')  String? schoolId, @JsonKey(name: 'sender_id')  String? senderId, @JsonKey(name: 'sender_role')  String? senderRole, @JsonKey(name: 'receiver_id')  String? receiverId, @JsonKey(name: 'receiver_role')  String? receiverRole, @JsonKey(name: 'student_id')  String? studentId, @JsonKey(name: 'message_type')  String? messageType, @JsonKey(name: 'message_content')  String? messageContent, @JsonKey(name: 'attachment_url')  String? attachmentUrl, @JsonKey(name: 'is_read')  bool? isRead, @JsonKey(name: 'sent_at')  dynamic sentAt)  $default,) {final _that = this;
switch (_that) {
case _CommunicationDto():
return $default(_that.id,_that.messageId,_that.schoolId,_that.senderId,_that.senderRole,_that.receiverId,_that.receiverRole,_that.studentId,_that.messageType,_that.messageContent,_that.attachmentUrl,_that.isRead,_that.sentAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? id, @JsonKey(name: 'message_id')  String? messageId, @JsonKey(name: 'school_id')  String? schoolId, @JsonKey(name: 'sender_id')  String? senderId, @JsonKey(name: 'sender_role')  String? senderRole, @JsonKey(name: 'receiver_id')  String? receiverId, @JsonKey(name: 'receiver_role')  String? receiverRole, @JsonKey(name: 'student_id')  String? studentId, @JsonKey(name: 'message_type')  String? messageType, @JsonKey(name: 'message_content')  String? messageContent, @JsonKey(name: 'attachment_url')  String? attachmentUrl, @JsonKey(name: 'is_read')  bool? isRead, @JsonKey(name: 'sent_at')  dynamic sentAt)?  $default,) {final _that = this;
switch (_that) {
case _CommunicationDto() when $default != null:
return $default(_that.id,_that.messageId,_that.schoolId,_that.senderId,_that.senderRole,_that.receiverId,_that.receiverRole,_that.studentId,_that.messageType,_that.messageContent,_that.attachmentUrl,_that.isRead,_that.sentAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CommunicationDto implements CommunicationDto {
  const _CommunicationDto({this.id, @JsonKey(name: 'message_id') this.messageId, @JsonKey(name: 'school_id') this.schoolId, @JsonKey(name: 'sender_id') this.senderId, @JsonKey(name: 'sender_role') this.senderRole, @JsonKey(name: 'receiver_id') this.receiverId, @JsonKey(name: 'receiver_role') this.receiverRole, @JsonKey(name: 'student_id') this.studentId, @JsonKey(name: 'message_type') this.messageType, @JsonKey(name: 'message_content') this.messageContent, @JsonKey(name: 'attachment_url') this.attachmentUrl, @JsonKey(name: 'is_read') this.isRead, @JsonKey(name: 'sent_at') this.sentAt});
  factory _CommunicationDto.fromJson(Map<String, dynamic> json) => _$CommunicationDtoFromJson(json);

@override final  String? id;
@override@JsonKey(name: 'message_id') final  String? messageId;
@override@JsonKey(name: 'school_id') final  String? schoolId;
@override@JsonKey(name: 'sender_id') final  String? senderId;
@override@JsonKey(name: 'sender_role') final  String? senderRole;
@override@JsonKey(name: 'receiver_id') final  String? receiverId;
@override@JsonKey(name: 'receiver_role') final  String? receiverRole;
@override@JsonKey(name: 'student_id') final  String? studentId;
@override@JsonKey(name: 'message_type') final  String? messageType;
@override@JsonKey(name: 'message_content') final  String? messageContent;
@override@JsonKey(name: 'attachment_url') final  String? attachmentUrl;
@override@JsonKey(name: 'is_read') final  bool? isRead;
@override@JsonKey(name: 'sent_at') final  dynamic sentAt;

/// Create a copy of CommunicationDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CommunicationDtoCopyWith<_CommunicationDto> get copyWith => __$CommunicationDtoCopyWithImpl<_CommunicationDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CommunicationDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CommunicationDto&&(identical(other.id, id) || other.id == id)&&(identical(other.messageId, messageId) || other.messageId == messageId)&&(identical(other.schoolId, schoolId) || other.schoolId == schoolId)&&(identical(other.senderId, senderId) || other.senderId == senderId)&&(identical(other.senderRole, senderRole) || other.senderRole == senderRole)&&(identical(other.receiverId, receiverId) || other.receiverId == receiverId)&&(identical(other.receiverRole, receiverRole) || other.receiverRole == receiverRole)&&(identical(other.studentId, studentId) || other.studentId == studentId)&&(identical(other.messageType, messageType) || other.messageType == messageType)&&(identical(other.messageContent, messageContent) || other.messageContent == messageContent)&&(identical(other.attachmentUrl, attachmentUrl) || other.attachmentUrl == attachmentUrl)&&(identical(other.isRead, isRead) || other.isRead == isRead)&&const DeepCollectionEquality().equals(other.sentAt, sentAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,messageId,schoolId,senderId,senderRole,receiverId,receiverRole,studentId,messageType,messageContent,attachmentUrl,isRead,const DeepCollectionEquality().hash(sentAt));

@override
String toString() {
  return 'CommunicationDto(id: $id, messageId: $messageId, schoolId: $schoolId, senderId: $senderId, senderRole: $senderRole, receiverId: $receiverId, receiverRole: $receiverRole, studentId: $studentId, messageType: $messageType, messageContent: $messageContent, attachmentUrl: $attachmentUrl, isRead: $isRead, sentAt: $sentAt)';
}


}

/// @nodoc
abstract mixin class _$CommunicationDtoCopyWith<$Res> implements $CommunicationDtoCopyWith<$Res> {
  factory _$CommunicationDtoCopyWith(_CommunicationDto value, $Res Function(_CommunicationDto) _then) = __$CommunicationDtoCopyWithImpl;
@override @useResult
$Res call({
 String? id,@JsonKey(name: 'message_id') String? messageId,@JsonKey(name: 'school_id') String? schoolId,@JsonKey(name: 'sender_id') String? senderId,@JsonKey(name: 'sender_role') String? senderRole,@JsonKey(name: 'receiver_id') String? receiverId,@JsonKey(name: 'receiver_role') String? receiverRole,@JsonKey(name: 'student_id') String? studentId,@JsonKey(name: 'message_type') String? messageType,@JsonKey(name: 'message_content') String? messageContent,@JsonKey(name: 'attachment_url') String? attachmentUrl,@JsonKey(name: 'is_read') bool? isRead,@JsonKey(name: 'sent_at') dynamic sentAt
});




}
/// @nodoc
class __$CommunicationDtoCopyWithImpl<$Res>
    implements _$CommunicationDtoCopyWith<$Res> {
  __$CommunicationDtoCopyWithImpl(this._self, this._then);

  final _CommunicationDto _self;
  final $Res Function(_CommunicationDto) _then;

/// Create a copy of CommunicationDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = freezed,Object? messageId = freezed,Object? schoolId = freezed,Object? senderId = freezed,Object? senderRole = freezed,Object? receiverId = freezed,Object? receiverRole = freezed,Object? studentId = freezed,Object? messageType = freezed,Object? messageContent = freezed,Object? attachmentUrl = freezed,Object? isRead = freezed,Object? sentAt = freezed,}) {
  return _then(_CommunicationDto(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,messageId: freezed == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as String?,schoolId: freezed == schoolId ? _self.schoolId : schoolId // ignore: cast_nullable_to_non_nullable
as String?,senderId: freezed == senderId ? _self.senderId : senderId // ignore: cast_nullable_to_non_nullable
as String?,senderRole: freezed == senderRole ? _self.senderRole : senderRole // ignore: cast_nullable_to_non_nullable
as String?,receiverId: freezed == receiverId ? _self.receiverId : receiverId // ignore: cast_nullable_to_non_nullable
as String?,receiverRole: freezed == receiverRole ? _self.receiverRole : receiverRole // ignore: cast_nullable_to_non_nullable
as String?,studentId: freezed == studentId ? _self.studentId : studentId // ignore: cast_nullable_to_non_nullable
as String?,messageType: freezed == messageType ? _self.messageType : messageType // ignore: cast_nullable_to_non_nullable
as String?,messageContent: freezed == messageContent ? _self.messageContent : messageContent // ignore: cast_nullable_to_non_nullable
as String?,attachmentUrl: freezed == attachmentUrl ? _self.attachmentUrl : attachmentUrl // ignore: cast_nullable_to_non_nullable
as String?,isRead: freezed == isRead ? _self.isRead : isRead // ignore: cast_nullable_to_non_nullable
as bool?,sentAt: freezed == sentAt ? _self.sentAt : sentAt // ignore: cast_nullable_to_non_nullable
as dynamic,
  ));
}


}


/// @nodoc
mixin _$PrincipalReportDto {

 String? get id;@JsonKey(name: 'report_id') String? get reportId;@JsonKey(name: 'school_id') String? get schoolId;@JsonKey(name: 'report_name') String? get reportName;@JsonKey(name: 'report_type') String? get reportType;@JsonKey(name: 'module_name') String? get moduleName;@JsonKey(name: 'generated_by') String? get generatedBy;@JsonKey(name: 'generated_role') String? get generatedRole;@JsonKey(name: 'report_status') String? get reportStatus;@JsonKey(name: 'report_file_url') String? get reportFileUrl;@JsonKey(name: 'total_records') int? get totalRecords;
/// Create a copy of PrincipalReportDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PrincipalReportDtoCopyWith<PrincipalReportDto> get copyWith => _$PrincipalReportDtoCopyWithImpl<PrincipalReportDto>(this as PrincipalReportDto, _$identity);

  /// Serializes this PrincipalReportDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PrincipalReportDto&&(identical(other.id, id) || other.id == id)&&(identical(other.reportId, reportId) || other.reportId == reportId)&&(identical(other.schoolId, schoolId) || other.schoolId == schoolId)&&(identical(other.reportName, reportName) || other.reportName == reportName)&&(identical(other.reportType, reportType) || other.reportType == reportType)&&(identical(other.moduleName, moduleName) || other.moduleName == moduleName)&&(identical(other.generatedBy, generatedBy) || other.generatedBy == generatedBy)&&(identical(other.generatedRole, generatedRole) || other.generatedRole == generatedRole)&&(identical(other.reportStatus, reportStatus) || other.reportStatus == reportStatus)&&(identical(other.reportFileUrl, reportFileUrl) || other.reportFileUrl == reportFileUrl)&&(identical(other.totalRecords, totalRecords) || other.totalRecords == totalRecords));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,reportId,schoolId,reportName,reportType,moduleName,generatedBy,generatedRole,reportStatus,reportFileUrl,totalRecords);

@override
String toString() {
  return 'PrincipalReportDto(id: $id, reportId: $reportId, schoolId: $schoolId, reportName: $reportName, reportType: $reportType, moduleName: $moduleName, generatedBy: $generatedBy, generatedRole: $generatedRole, reportStatus: $reportStatus, reportFileUrl: $reportFileUrl, totalRecords: $totalRecords)';
}


}

/// @nodoc
abstract mixin class $PrincipalReportDtoCopyWith<$Res>  {
  factory $PrincipalReportDtoCopyWith(PrincipalReportDto value, $Res Function(PrincipalReportDto) _then) = _$PrincipalReportDtoCopyWithImpl;
@useResult
$Res call({
 String? id,@JsonKey(name: 'report_id') String? reportId,@JsonKey(name: 'school_id') String? schoolId,@JsonKey(name: 'report_name') String? reportName,@JsonKey(name: 'report_type') String? reportType,@JsonKey(name: 'module_name') String? moduleName,@JsonKey(name: 'generated_by') String? generatedBy,@JsonKey(name: 'generated_role') String? generatedRole,@JsonKey(name: 'report_status') String? reportStatus,@JsonKey(name: 'report_file_url') String? reportFileUrl,@JsonKey(name: 'total_records') int? totalRecords
});




}
/// @nodoc
class _$PrincipalReportDtoCopyWithImpl<$Res>
    implements $PrincipalReportDtoCopyWith<$Res> {
  _$PrincipalReportDtoCopyWithImpl(this._self, this._then);

  final PrincipalReportDto _self;
  final $Res Function(PrincipalReportDto) _then;

/// Create a copy of PrincipalReportDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = freezed,Object? reportId = freezed,Object? schoolId = freezed,Object? reportName = freezed,Object? reportType = freezed,Object? moduleName = freezed,Object? generatedBy = freezed,Object? generatedRole = freezed,Object? reportStatus = freezed,Object? reportFileUrl = freezed,Object? totalRecords = freezed,}) {
  return _then(_self.copyWith(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,reportId: freezed == reportId ? _self.reportId : reportId // ignore: cast_nullable_to_non_nullable
as String?,schoolId: freezed == schoolId ? _self.schoolId : schoolId // ignore: cast_nullable_to_non_nullable
as String?,reportName: freezed == reportName ? _self.reportName : reportName // ignore: cast_nullable_to_non_nullable
as String?,reportType: freezed == reportType ? _self.reportType : reportType // ignore: cast_nullable_to_non_nullable
as String?,moduleName: freezed == moduleName ? _self.moduleName : moduleName // ignore: cast_nullable_to_non_nullable
as String?,generatedBy: freezed == generatedBy ? _self.generatedBy : generatedBy // ignore: cast_nullable_to_non_nullable
as String?,generatedRole: freezed == generatedRole ? _self.generatedRole : generatedRole // ignore: cast_nullable_to_non_nullable
as String?,reportStatus: freezed == reportStatus ? _self.reportStatus : reportStatus // ignore: cast_nullable_to_non_nullable
as String?,reportFileUrl: freezed == reportFileUrl ? _self.reportFileUrl : reportFileUrl // ignore: cast_nullable_to_non_nullable
as String?,totalRecords: freezed == totalRecords ? _self.totalRecords : totalRecords // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [PrincipalReportDto].
extension PrincipalReportDtoPatterns on PrincipalReportDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PrincipalReportDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PrincipalReportDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PrincipalReportDto value)  $default,){
final _that = this;
switch (_that) {
case _PrincipalReportDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PrincipalReportDto value)?  $default,){
final _that = this;
switch (_that) {
case _PrincipalReportDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? id, @JsonKey(name: 'report_id')  String? reportId, @JsonKey(name: 'school_id')  String? schoolId, @JsonKey(name: 'report_name')  String? reportName, @JsonKey(name: 'report_type')  String? reportType, @JsonKey(name: 'module_name')  String? moduleName, @JsonKey(name: 'generated_by')  String? generatedBy, @JsonKey(name: 'generated_role')  String? generatedRole, @JsonKey(name: 'report_status')  String? reportStatus, @JsonKey(name: 'report_file_url')  String? reportFileUrl, @JsonKey(name: 'total_records')  int? totalRecords)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PrincipalReportDto() when $default != null:
return $default(_that.id,_that.reportId,_that.schoolId,_that.reportName,_that.reportType,_that.moduleName,_that.generatedBy,_that.generatedRole,_that.reportStatus,_that.reportFileUrl,_that.totalRecords);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? id, @JsonKey(name: 'report_id')  String? reportId, @JsonKey(name: 'school_id')  String? schoolId, @JsonKey(name: 'report_name')  String? reportName, @JsonKey(name: 'report_type')  String? reportType, @JsonKey(name: 'module_name')  String? moduleName, @JsonKey(name: 'generated_by')  String? generatedBy, @JsonKey(name: 'generated_role')  String? generatedRole, @JsonKey(name: 'report_status')  String? reportStatus, @JsonKey(name: 'report_file_url')  String? reportFileUrl, @JsonKey(name: 'total_records')  int? totalRecords)  $default,) {final _that = this;
switch (_that) {
case _PrincipalReportDto():
return $default(_that.id,_that.reportId,_that.schoolId,_that.reportName,_that.reportType,_that.moduleName,_that.generatedBy,_that.generatedRole,_that.reportStatus,_that.reportFileUrl,_that.totalRecords);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? id, @JsonKey(name: 'report_id')  String? reportId, @JsonKey(name: 'school_id')  String? schoolId, @JsonKey(name: 'report_name')  String? reportName, @JsonKey(name: 'report_type')  String? reportType, @JsonKey(name: 'module_name')  String? moduleName, @JsonKey(name: 'generated_by')  String? generatedBy, @JsonKey(name: 'generated_role')  String? generatedRole, @JsonKey(name: 'report_status')  String? reportStatus, @JsonKey(name: 'report_file_url')  String? reportFileUrl, @JsonKey(name: 'total_records')  int? totalRecords)?  $default,) {final _that = this;
switch (_that) {
case _PrincipalReportDto() when $default != null:
return $default(_that.id,_that.reportId,_that.schoolId,_that.reportName,_that.reportType,_that.moduleName,_that.generatedBy,_that.generatedRole,_that.reportStatus,_that.reportFileUrl,_that.totalRecords);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PrincipalReportDto implements PrincipalReportDto {
  const _PrincipalReportDto({this.id, @JsonKey(name: 'report_id') this.reportId, @JsonKey(name: 'school_id') this.schoolId, @JsonKey(name: 'report_name') this.reportName, @JsonKey(name: 'report_type') this.reportType, @JsonKey(name: 'module_name') this.moduleName, @JsonKey(name: 'generated_by') this.generatedBy, @JsonKey(name: 'generated_role') this.generatedRole, @JsonKey(name: 'report_status') this.reportStatus, @JsonKey(name: 'report_file_url') this.reportFileUrl, @JsonKey(name: 'total_records') this.totalRecords});
  factory _PrincipalReportDto.fromJson(Map<String, dynamic> json) => _$PrincipalReportDtoFromJson(json);

@override final  String? id;
@override@JsonKey(name: 'report_id') final  String? reportId;
@override@JsonKey(name: 'school_id') final  String? schoolId;
@override@JsonKey(name: 'report_name') final  String? reportName;
@override@JsonKey(name: 'report_type') final  String? reportType;
@override@JsonKey(name: 'module_name') final  String? moduleName;
@override@JsonKey(name: 'generated_by') final  String? generatedBy;
@override@JsonKey(name: 'generated_role') final  String? generatedRole;
@override@JsonKey(name: 'report_status') final  String? reportStatus;
@override@JsonKey(name: 'report_file_url') final  String? reportFileUrl;
@override@JsonKey(name: 'total_records') final  int? totalRecords;

/// Create a copy of PrincipalReportDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PrincipalReportDtoCopyWith<_PrincipalReportDto> get copyWith => __$PrincipalReportDtoCopyWithImpl<_PrincipalReportDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PrincipalReportDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PrincipalReportDto&&(identical(other.id, id) || other.id == id)&&(identical(other.reportId, reportId) || other.reportId == reportId)&&(identical(other.schoolId, schoolId) || other.schoolId == schoolId)&&(identical(other.reportName, reportName) || other.reportName == reportName)&&(identical(other.reportType, reportType) || other.reportType == reportType)&&(identical(other.moduleName, moduleName) || other.moduleName == moduleName)&&(identical(other.generatedBy, generatedBy) || other.generatedBy == generatedBy)&&(identical(other.generatedRole, generatedRole) || other.generatedRole == generatedRole)&&(identical(other.reportStatus, reportStatus) || other.reportStatus == reportStatus)&&(identical(other.reportFileUrl, reportFileUrl) || other.reportFileUrl == reportFileUrl)&&(identical(other.totalRecords, totalRecords) || other.totalRecords == totalRecords));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,reportId,schoolId,reportName,reportType,moduleName,generatedBy,generatedRole,reportStatus,reportFileUrl,totalRecords);

@override
String toString() {
  return 'PrincipalReportDto(id: $id, reportId: $reportId, schoolId: $schoolId, reportName: $reportName, reportType: $reportType, moduleName: $moduleName, generatedBy: $generatedBy, generatedRole: $generatedRole, reportStatus: $reportStatus, reportFileUrl: $reportFileUrl, totalRecords: $totalRecords)';
}


}

/// @nodoc
abstract mixin class _$PrincipalReportDtoCopyWith<$Res> implements $PrincipalReportDtoCopyWith<$Res> {
  factory _$PrincipalReportDtoCopyWith(_PrincipalReportDto value, $Res Function(_PrincipalReportDto) _then) = __$PrincipalReportDtoCopyWithImpl;
@override @useResult
$Res call({
 String? id,@JsonKey(name: 'report_id') String? reportId,@JsonKey(name: 'school_id') String? schoolId,@JsonKey(name: 'report_name') String? reportName,@JsonKey(name: 'report_type') String? reportType,@JsonKey(name: 'module_name') String? moduleName,@JsonKey(name: 'generated_by') String? generatedBy,@JsonKey(name: 'generated_role') String? generatedRole,@JsonKey(name: 'report_status') String? reportStatus,@JsonKey(name: 'report_file_url') String? reportFileUrl,@JsonKey(name: 'total_records') int? totalRecords
});




}
/// @nodoc
class __$PrincipalReportDtoCopyWithImpl<$Res>
    implements _$PrincipalReportDtoCopyWith<$Res> {
  __$PrincipalReportDtoCopyWithImpl(this._self, this._then);

  final _PrincipalReportDto _self;
  final $Res Function(_PrincipalReportDto) _then;

/// Create a copy of PrincipalReportDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = freezed,Object? reportId = freezed,Object? schoolId = freezed,Object? reportName = freezed,Object? reportType = freezed,Object? moduleName = freezed,Object? generatedBy = freezed,Object? generatedRole = freezed,Object? reportStatus = freezed,Object? reportFileUrl = freezed,Object? totalRecords = freezed,}) {
  return _then(_PrincipalReportDto(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,reportId: freezed == reportId ? _self.reportId : reportId // ignore: cast_nullable_to_non_nullable
as String?,schoolId: freezed == schoolId ? _self.schoolId : schoolId // ignore: cast_nullable_to_non_nullable
as String?,reportName: freezed == reportName ? _self.reportName : reportName // ignore: cast_nullable_to_non_nullable
as String?,reportType: freezed == reportType ? _self.reportType : reportType // ignore: cast_nullable_to_non_nullable
as String?,moduleName: freezed == moduleName ? _self.moduleName : moduleName // ignore: cast_nullable_to_non_nullable
as String?,generatedBy: freezed == generatedBy ? _self.generatedBy : generatedBy // ignore: cast_nullable_to_non_nullable
as String?,generatedRole: freezed == generatedRole ? _self.generatedRole : generatedRole // ignore: cast_nullable_to_non_nullable
as String?,reportStatus: freezed == reportStatus ? _self.reportStatus : reportStatus // ignore: cast_nullable_to_non_nullable
as String?,reportFileUrl: freezed == reportFileUrl ? _self.reportFileUrl : reportFileUrl // ignore: cast_nullable_to_non_nullable
as String?,totalRecords: freezed == totalRecords ? _self.totalRecords : totalRecords // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}


/// @nodoc
mixin _$DashboardDto {

 String? get role; Map<String, dynamic> get metrics; Map<String, dynamic> get fees;@JsonKey(name: 'today_attendance') Map<String, dynamic> get todayAttendance; List<dynamic> get children;@JsonKey(name: 'assigned_classes') List<dynamic> get assignedClasses;@JsonKey(name: 'staff_id') String? get staffId;
/// Create a copy of DashboardDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DashboardDtoCopyWith<DashboardDto> get copyWith => _$DashboardDtoCopyWithImpl<DashboardDto>(this as DashboardDto, _$identity);

  /// Serializes this DashboardDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DashboardDto&&(identical(other.role, role) || other.role == role)&&const DeepCollectionEquality().equals(other.metrics, metrics)&&const DeepCollectionEquality().equals(other.fees, fees)&&const DeepCollectionEquality().equals(other.todayAttendance, todayAttendance)&&const DeepCollectionEquality().equals(other.children, children)&&const DeepCollectionEquality().equals(other.assignedClasses, assignedClasses)&&(identical(other.staffId, staffId) || other.staffId == staffId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,role,const DeepCollectionEquality().hash(metrics),const DeepCollectionEquality().hash(fees),const DeepCollectionEquality().hash(todayAttendance),const DeepCollectionEquality().hash(children),const DeepCollectionEquality().hash(assignedClasses),staffId);

@override
String toString() {
  return 'DashboardDto(role: $role, metrics: $metrics, fees: $fees, todayAttendance: $todayAttendance, children: $children, assignedClasses: $assignedClasses, staffId: $staffId)';
}


}

/// @nodoc
abstract mixin class $DashboardDtoCopyWith<$Res>  {
  factory $DashboardDtoCopyWith(DashboardDto value, $Res Function(DashboardDto) _then) = _$DashboardDtoCopyWithImpl;
@useResult
$Res call({
 String? role, Map<String, dynamic> metrics, Map<String, dynamic> fees,@JsonKey(name: 'today_attendance') Map<String, dynamic> todayAttendance, List<dynamic> children,@JsonKey(name: 'assigned_classes') List<dynamic> assignedClasses,@JsonKey(name: 'staff_id') String? staffId
});




}
/// @nodoc
class _$DashboardDtoCopyWithImpl<$Res>
    implements $DashboardDtoCopyWith<$Res> {
  _$DashboardDtoCopyWithImpl(this._self, this._then);

  final DashboardDto _self;
  final $Res Function(DashboardDto) _then;

/// Create a copy of DashboardDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? role = freezed,Object? metrics = null,Object? fees = null,Object? todayAttendance = null,Object? children = null,Object? assignedClasses = null,Object? staffId = freezed,}) {
  return _then(_self.copyWith(
role: freezed == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String?,metrics: null == metrics ? _self.metrics : metrics // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,fees: null == fees ? _self.fees : fees // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,todayAttendance: null == todayAttendance ? _self.todayAttendance : todayAttendance // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,children: null == children ? _self.children : children // ignore: cast_nullable_to_non_nullable
as List<dynamic>,assignedClasses: null == assignedClasses ? _self.assignedClasses : assignedClasses // ignore: cast_nullable_to_non_nullable
as List<dynamic>,staffId: freezed == staffId ? _self.staffId : staffId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [DashboardDto].
extension DashboardDtoPatterns on DashboardDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DashboardDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DashboardDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DashboardDto value)  $default,){
final _that = this;
switch (_that) {
case _DashboardDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DashboardDto value)?  $default,){
final _that = this;
switch (_that) {
case _DashboardDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? role,  Map<String, dynamic> metrics,  Map<String, dynamic> fees, @JsonKey(name: 'today_attendance')  Map<String, dynamic> todayAttendance,  List<dynamic> children, @JsonKey(name: 'assigned_classes')  List<dynamic> assignedClasses, @JsonKey(name: 'staff_id')  String? staffId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DashboardDto() when $default != null:
return $default(_that.role,_that.metrics,_that.fees,_that.todayAttendance,_that.children,_that.assignedClasses,_that.staffId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? role,  Map<String, dynamic> metrics,  Map<String, dynamic> fees, @JsonKey(name: 'today_attendance')  Map<String, dynamic> todayAttendance,  List<dynamic> children, @JsonKey(name: 'assigned_classes')  List<dynamic> assignedClasses, @JsonKey(name: 'staff_id')  String? staffId)  $default,) {final _that = this;
switch (_that) {
case _DashboardDto():
return $default(_that.role,_that.metrics,_that.fees,_that.todayAttendance,_that.children,_that.assignedClasses,_that.staffId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? role,  Map<String, dynamic> metrics,  Map<String, dynamic> fees, @JsonKey(name: 'today_attendance')  Map<String, dynamic> todayAttendance,  List<dynamic> children, @JsonKey(name: 'assigned_classes')  List<dynamic> assignedClasses, @JsonKey(name: 'staff_id')  String? staffId)?  $default,) {final _that = this;
switch (_that) {
case _DashboardDto() when $default != null:
return $default(_that.role,_that.metrics,_that.fees,_that.todayAttendance,_that.children,_that.assignedClasses,_that.staffId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DashboardDto implements DashboardDto {
  const _DashboardDto({this.role, final  Map<String, dynamic> metrics = const <String, dynamic>{}, final  Map<String, dynamic> fees = const <String, dynamic>{}, @JsonKey(name: 'today_attendance') final  Map<String, dynamic> todayAttendance = const <String, dynamic>{}, final  List<dynamic> children = const <dynamic>[], @JsonKey(name: 'assigned_classes') final  List<dynamic> assignedClasses = const <dynamic>[], @JsonKey(name: 'staff_id') this.staffId}): _metrics = metrics,_fees = fees,_todayAttendance = todayAttendance,_children = children,_assignedClasses = assignedClasses;
  factory _DashboardDto.fromJson(Map<String, dynamic> json) => _$DashboardDtoFromJson(json);

@override final  String? role;
 final  Map<String, dynamic> _metrics;
@override@JsonKey() Map<String, dynamic> get metrics {
  if (_metrics is EqualUnmodifiableMapView) return _metrics;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_metrics);
}

 final  Map<String, dynamic> _fees;
@override@JsonKey() Map<String, dynamic> get fees {
  if (_fees is EqualUnmodifiableMapView) return _fees;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_fees);
}

 final  Map<String, dynamic> _todayAttendance;
@override@JsonKey(name: 'today_attendance') Map<String, dynamic> get todayAttendance {
  if (_todayAttendance is EqualUnmodifiableMapView) return _todayAttendance;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_todayAttendance);
}

 final  List<dynamic> _children;
@override@JsonKey() List<dynamic> get children {
  if (_children is EqualUnmodifiableListView) return _children;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_children);
}

 final  List<dynamic> _assignedClasses;
@override@JsonKey(name: 'assigned_classes') List<dynamic> get assignedClasses {
  if (_assignedClasses is EqualUnmodifiableListView) return _assignedClasses;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_assignedClasses);
}

@override@JsonKey(name: 'staff_id') final  String? staffId;

/// Create a copy of DashboardDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DashboardDtoCopyWith<_DashboardDto> get copyWith => __$DashboardDtoCopyWithImpl<_DashboardDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DashboardDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DashboardDto&&(identical(other.role, role) || other.role == role)&&const DeepCollectionEquality().equals(other._metrics, _metrics)&&const DeepCollectionEquality().equals(other._fees, _fees)&&const DeepCollectionEquality().equals(other._todayAttendance, _todayAttendance)&&const DeepCollectionEquality().equals(other._children, _children)&&const DeepCollectionEquality().equals(other._assignedClasses, _assignedClasses)&&(identical(other.staffId, staffId) || other.staffId == staffId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,role,const DeepCollectionEquality().hash(_metrics),const DeepCollectionEquality().hash(_fees),const DeepCollectionEquality().hash(_todayAttendance),const DeepCollectionEquality().hash(_children),const DeepCollectionEquality().hash(_assignedClasses),staffId);

@override
String toString() {
  return 'DashboardDto(role: $role, metrics: $metrics, fees: $fees, todayAttendance: $todayAttendance, children: $children, assignedClasses: $assignedClasses, staffId: $staffId)';
}


}

/// @nodoc
abstract mixin class _$DashboardDtoCopyWith<$Res> implements $DashboardDtoCopyWith<$Res> {
  factory _$DashboardDtoCopyWith(_DashboardDto value, $Res Function(_DashboardDto) _then) = __$DashboardDtoCopyWithImpl;
@override @useResult
$Res call({
 String? role, Map<String, dynamic> metrics, Map<String, dynamic> fees,@JsonKey(name: 'today_attendance') Map<String, dynamic> todayAttendance, List<dynamic> children,@JsonKey(name: 'assigned_classes') List<dynamic> assignedClasses,@JsonKey(name: 'staff_id') String? staffId
});




}
/// @nodoc
class __$DashboardDtoCopyWithImpl<$Res>
    implements _$DashboardDtoCopyWith<$Res> {
  __$DashboardDtoCopyWithImpl(this._self, this._then);

  final _DashboardDto _self;
  final $Res Function(_DashboardDto) _then;

/// Create a copy of DashboardDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? role = freezed,Object? metrics = null,Object? fees = null,Object? todayAttendance = null,Object? children = null,Object? assignedClasses = null,Object? staffId = freezed,}) {
  return _then(_DashboardDto(
role: freezed == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String?,metrics: null == metrics ? _self._metrics : metrics // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,fees: null == fees ? _self._fees : fees // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,todayAttendance: null == todayAttendance ? _self._todayAttendance : todayAttendance // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,children: null == children ? _self._children : children // ignore: cast_nullable_to_non_nullable
as List<dynamic>,assignedClasses: null == assignedClasses ? _self._assignedClasses : assignedClasses // ignore: cast_nullable_to_non_nullable
as List<dynamic>,staffId: freezed == staffId ? _self.staffId : staffId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$StudentDto {

 String? get id;@JsonKey(name: 'school_id') String? get schoolId;@JsonKey(name: 'student_code') String? get studentCode;@JsonKey(name: 'admission_number') String? get admissionNumber;@JsonKey(name: 'first_name') String? get firstName;@JsonKey(name: 'last_name') String? get lastName;@JsonKey(name: 'current_section_id') String? get currentSectionId; String? get status;
/// Create a copy of StudentDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StudentDtoCopyWith<StudentDto> get copyWith => _$StudentDtoCopyWithImpl<StudentDto>(this as StudentDto, _$identity);

  /// Serializes this StudentDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StudentDto&&(identical(other.id, id) || other.id == id)&&(identical(other.schoolId, schoolId) || other.schoolId == schoolId)&&(identical(other.studentCode, studentCode) || other.studentCode == studentCode)&&(identical(other.admissionNumber, admissionNumber) || other.admissionNumber == admissionNumber)&&(identical(other.firstName, firstName) || other.firstName == firstName)&&(identical(other.lastName, lastName) || other.lastName == lastName)&&(identical(other.currentSectionId, currentSectionId) || other.currentSectionId == currentSectionId)&&(identical(other.status, status) || other.status == status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,schoolId,studentCode,admissionNumber,firstName,lastName,currentSectionId,status);

@override
String toString() {
  return 'StudentDto(id: $id, schoolId: $schoolId, studentCode: $studentCode, admissionNumber: $admissionNumber, firstName: $firstName, lastName: $lastName, currentSectionId: $currentSectionId, status: $status)';
}


}

/// @nodoc
abstract mixin class $StudentDtoCopyWith<$Res>  {
  factory $StudentDtoCopyWith(StudentDto value, $Res Function(StudentDto) _then) = _$StudentDtoCopyWithImpl;
@useResult
$Res call({
 String? id,@JsonKey(name: 'school_id') String? schoolId,@JsonKey(name: 'student_code') String? studentCode,@JsonKey(name: 'admission_number') String? admissionNumber,@JsonKey(name: 'first_name') String? firstName,@JsonKey(name: 'last_name') String? lastName,@JsonKey(name: 'current_section_id') String? currentSectionId, String? status
});




}
/// @nodoc
class _$StudentDtoCopyWithImpl<$Res>
    implements $StudentDtoCopyWith<$Res> {
  _$StudentDtoCopyWithImpl(this._self, this._then);

  final StudentDto _self;
  final $Res Function(StudentDto) _then;

/// Create a copy of StudentDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = freezed,Object? schoolId = freezed,Object? studentCode = freezed,Object? admissionNumber = freezed,Object? firstName = freezed,Object? lastName = freezed,Object? currentSectionId = freezed,Object? status = freezed,}) {
  return _then(_self.copyWith(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,schoolId: freezed == schoolId ? _self.schoolId : schoolId // ignore: cast_nullable_to_non_nullable
as String?,studentCode: freezed == studentCode ? _self.studentCode : studentCode // ignore: cast_nullable_to_non_nullable
as String?,admissionNumber: freezed == admissionNumber ? _self.admissionNumber : admissionNumber // ignore: cast_nullable_to_non_nullable
as String?,firstName: freezed == firstName ? _self.firstName : firstName // ignore: cast_nullable_to_non_nullable
as String?,lastName: freezed == lastName ? _self.lastName : lastName // ignore: cast_nullable_to_non_nullable
as String?,currentSectionId: freezed == currentSectionId ? _self.currentSectionId : currentSectionId // ignore: cast_nullable_to_non_nullable
as String?,status: freezed == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [StudentDto].
extension StudentDtoPatterns on StudentDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _StudentDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _StudentDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _StudentDto value)  $default,){
final _that = this;
switch (_that) {
case _StudentDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _StudentDto value)?  $default,){
final _that = this;
switch (_that) {
case _StudentDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? id, @JsonKey(name: 'school_id')  String? schoolId, @JsonKey(name: 'student_code')  String? studentCode, @JsonKey(name: 'admission_number')  String? admissionNumber, @JsonKey(name: 'first_name')  String? firstName, @JsonKey(name: 'last_name')  String? lastName, @JsonKey(name: 'current_section_id')  String? currentSectionId,  String? status)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _StudentDto() when $default != null:
return $default(_that.id,_that.schoolId,_that.studentCode,_that.admissionNumber,_that.firstName,_that.lastName,_that.currentSectionId,_that.status);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? id, @JsonKey(name: 'school_id')  String? schoolId, @JsonKey(name: 'student_code')  String? studentCode, @JsonKey(name: 'admission_number')  String? admissionNumber, @JsonKey(name: 'first_name')  String? firstName, @JsonKey(name: 'last_name')  String? lastName, @JsonKey(name: 'current_section_id')  String? currentSectionId,  String? status)  $default,) {final _that = this;
switch (_that) {
case _StudentDto():
return $default(_that.id,_that.schoolId,_that.studentCode,_that.admissionNumber,_that.firstName,_that.lastName,_that.currentSectionId,_that.status);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? id, @JsonKey(name: 'school_id')  String? schoolId, @JsonKey(name: 'student_code')  String? studentCode, @JsonKey(name: 'admission_number')  String? admissionNumber, @JsonKey(name: 'first_name')  String? firstName, @JsonKey(name: 'last_name')  String? lastName, @JsonKey(name: 'current_section_id')  String? currentSectionId,  String? status)?  $default,) {final _that = this;
switch (_that) {
case _StudentDto() when $default != null:
return $default(_that.id,_that.schoolId,_that.studentCode,_that.admissionNumber,_that.firstName,_that.lastName,_that.currentSectionId,_that.status);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _StudentDto implements StudentDto {
  const _StudentDto({this.id, @JsonKey(name: 'school_id') this.schoolId, @JsonKey(name: 'student_code') this.studentCode, @JsonKey(name: 'admission_number') this.admissionNumber, @JsonKey(name: 'first_name') this.firstName, @JsonKey(name: 'last_name') this.lastName, @JsonKey(name: 'current_section_id') this.currentSectionId, this.status});
  factory _StudentDto.fromJson(Map<String, dynamic> json) => _$StudentDtoFromJson(json);

@override final  String? id;
@override@JsonKey(name: 'school_id') final  String? schoolId;
@override@JsonKey(name: 'student_code') final  String? studentCode;
@override@JsonKey(name: 'admission_number') final  String? admissionNumber;
@override@JsonKey(name: 'first_name') final  String? firstName;
@override@JsonKey(name: 'last_name') final  String? lastName;
@override@JsonKey(name: 'current_section_id') final  String? currentSectionId;
@override final  String? status;

/// Create a copy of StudentDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StudentDtoCopyWith<_StudentDto> get copyWith => __$StudentDtoCopyWithImpl<_StudentDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$StudentDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _StudentDto&&(identical(other.id, id) || other.id == id)&&(identical(other.schoolId, schoolId) || other.schoolId == schoolId)&&(identical(other.studentCode, studentCode) || other.studentCode == studentCode)&&(identical(other.admissionNumber, admissionNumber) || other.admissionNumber == admissionNumber)&&(identical(other.firstName, firstName) || other.firstName == firstName)&&(identical(other.lastName, lastName) || other.lastName == lastName)&&(identical(other.currentSectionId, currentSectionId) || other.currentSectionId == currentSectionId)&&(identical(other.status, status) || other.status == status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,schoolId,studentCode,admissionNumber,firstName,lastName,currentSectionId,status);

@override
String toString() {
  return 'StudentDto(id: $id, schoolId: $schoolId, studentCode: $studentCode, admissionNumber: $admissionNumber, firstName: $firstName, lastName: $lastName, currentSectionId: $currentSectionId, status: $status)';
}


}

/// @nodoc
abstract mixin class _$StudentDtoCopyWith<$Res> implements $StudentDtoCopyWith<$Res> {
  factory _$StudentDtoCopyWith(_StudentDto value, $Res Function(_StudentDto) _then) = __$StudentDtoCopyWithImpl;
@override @useResult
$Res call({
 String? id,@JsonKey(name: 'school_id') String? schoolId,@JsonKey(name: 'student_code') String? studentCode,@JsonKey(name: 'admission_number') String? admissionNumber,@JsonKey(name: 'first_name') String? firstName,@JsonKey(name: 'last_name') String? lastName,@JsonKey(name: 'current_section_id') String? currentSectionId, String? status
});




}
/// @nodoc
class __$StudentDtoCopyWithImpl<$Res>
    implements _$StudentDtoCopyWith<$Res> {
  __$StudentDtoCopyWithImpl(this._self, this._then);

  final _StudentDto _self;
  final $Res Function(_StudentDto) _then;

/// Create a copy of StudentDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = freezed,Object? schoolId = freezed,Object? studentCode = freezed,Object? admissionNumber = freezed,Object? firstName = freezed,Object? lastName = freezed,Object? currentSectionId = freezed,Object? status = freezed,}) {
  return _then(_StudentDto(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,schoolId: freezed == schoolId ? _self.schoolId : schoolId // ignore: cast_nullable_to_non_nullable
as String?,studentCode: freezed == studentCode ? _self.studentCode : studentCode // ignore: cast_nullable_to_non_nullable
as String?,admissionNumber: freezed == admissionNumber ? _self.admissionNumber : admissionNumber // ignore: cast_nullable_to_non_nullable
as String?,firstName: freezed == firstName ? _self.firstName : firstName // ignore: cast_nullable_to_non_nullable
as String?,lastName: freezed == lastName ? _self.lastName : lastName // ignore: cast_nullable_to_non_nullable
as String?,currentSectionId: freezed == currentSectionId ? _self.currentSectionId : currentSectionId // ignore: cast_nullable_to_non_nullable
as String?,status: freezed == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$StaffDto {

 String? get id;@JsonKey(name: 'school_id') String? get schoolId;@JsonKey(name: 'staff_code') String? get staffCode;@JsonKey(name: 'first_name') String? get firstName;@JsonKey(name: 'last_name') String? get lastName; String? get email; String? get phone; String? get designation; String? get status;
/// Create a copy of StaffDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StaffDtoCopyWith<StaffDto> get copyWith => _$StaffDtoCopyWithImpl<StaffDto>(this as StaffDto, _$identity);

  /// Serializes this StaffDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StaffDto&&(identical(other.id, id) || other.id == id)&&(identical(other.schoolId, schoolId) || other.schoolId == schoolId)&&(identical(other.staffCode, staffCode) || other.staffCode == staffCode)&&(identical(other.firstName, firstName) || other.firstName == firstName)&&(identical(other.lastName, lastName) || other.lastName == lastName)&&(identical(other.email, email) || other.email == email)&&(identical(other.phone, phone) || other.phone == phone)&&(identical(other.designation, designation) || other.designation == designation)&&(identical(other.status, status) || other.status == status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,schoolId,staffCode,firstName,lastName,email,phone,designation,status);

@override
String toString() {
  return 'StaffDto(id: $id, schoolId: $schoolId, staffCode: $staffCode, firstName: $firstName, lastName: $lastName, email: $email, phone: $phone, designation: $designation, status: $status)';
}


}

/// @nodoc
abstract mixin class $StaffDtoCopyWith<$Res>  {
  factory $StaffDtoCopyWith(StaffDto value, $Res Function(StaffDto) _then) = _$StaffDtoCopyWithImpl;
@useResult
$Res call({
 String? id,@JsonKey(name: 'school_id') String? schoolId,@JsonKey(name: 'staff_code') String? staffCode,@JsonKey(name: 'first_name') String? firstName,@JsonKey(name: 'last_name') String? lastName, String? email, String? phone, String? designation, String? status
});




}
/// @nodoc
class _$StaffDtoCopyWithImpl<$Res>
    implements $StaffDtoCopyWith<$Res> {
  _$StaffDtoCopyWithImpl(this._self, this._then);

  final StaffDto _self;
  final $Res Function(StaffDto) _then;

/// Create a copy of StaffDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = freezed,Object? schoolId = freezed,Object? staffCode = freezed,Object? firstName = freezed,Object? lastName = freezed,Object? email = freezed,Object? phone = freezed,Object? designation = freezed,Object? status = freezed,}) {
  return _then(_self.copyWith(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,schoolId: freezed == schoolId ? _self.schoolId : schoolId // ignore: cast_nullable_to_non_nullable
as String?,staffCode: freezed == staffCode ? _self.staffCode : staffCode // ignore: cast_nullable_to_non_nullable
as String?,firstName: freezed == firstName ? _self.firstName : firstName // ignore: cast_nullable_to_non_nullable
as String?,lastName: freezed == lastName ? _self.lastName : lastName // ignore: cast_nullable_to_non_nullable
as String?,email: freezed == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String?,phone: freezed == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String?,designation: freezed == designation ? _self.designation : designation // ignore: cast_nullable_to_non_nullable
as String?,status: freezed == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [StaffDto].
extension StaffDtoPatterns on StaffDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _StaffDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _StaffDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _StaffDto value)  $default,){
final _that = this;
switch (_that) {
case _StaffDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _StaffDto value)?  $default,){
final _that = this;
switch (_that) {
case _StaffDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? id, @JsonKey(name: 'school_id')  String? schoolId, @JsonKey(name: 'staff_code')  String? staffCode, @JsonKey(name: 'first_name')  String? firstName, @JsonKey(name: 'last_name')  String? lastName,  String? email,  String? phone,  String? designation,  String? status)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _StaffDto() when $default != null:
return $default(_that.id,_that.schoolId,_that.staffCode,_that.firstName,_that.lastName,_that.email,_that.phone,_that.designation,_that.status);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? id, @JsonKey(name: 'school_id')  String? schoolId, @JsonKey(name: 'staff_code')  String? staffCode, @JsonKey(name: 'first_name')  String? firstName, @JsonKey(name: 'last_name')  String? lastName,  String? email,  String? phone,  String? designation,  String? status)  $default,) {final _that = this;
switch (_that) {
case _StaffDto():
return $default(_that.id,_that.schoolId,_that.staffCode,_that.firstName,_that.lastName,_that.email,_that.phone,_that.designation,_that.status);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? id, @JsonKey(name: 'school_id')  String? schoolId, @JsonKey(name: 'staff_code')  String? staffCode, @JsonKey(name: 'first_name')  String? firstName, @JsonKey(name: 'last_name')  String? lastName,  String? email,  String? phone,  String? designation,  String? status)?  $default,) {final _that = this;
switch (_that) {
case _StaffDto() when $default != null:
return $default(_that.id,_that.schoolId,_that.staffCode,_that.firstName,_that.lastName,_that.email,_that.phone,_that.designation,_that.status);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _StaffDto implements StaffDto {
  const _StaffDto({this.id, @JsonKey(name: 'school_id') this.schoolId, @JsonKey(name: 'staff_code') this.staffCode, @JsonKey(name: 'first_name') this.firstName, @JsonKey(name: 'last_name') this.lastName, this.email, this.phone, this.designation, this.status});
  factory _StaffDto.fromJson(Map<String, dynamic> json) => _$StaffDtoFromJson(json);

@override final  String? id;
@override@JsonKey(name: 'school_id') final  String? schoolId;
@override@JsonKey(name: 'staff_code') final  String? staffCode;
@override@JsonKey(name: 'first_name') final  String? firstName;
@override@JsonKey(name: 'last_name') final  String? lastName;
@override final  String? email;
@override final  String? phone;
@override final  String? designation;
@override final  String? status;

/// Create a copy of StaffDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StaffDtoCopyWith<_StaffDto> get copyWith => __$StaffDtoCopyWithImpl<_StaffDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$StaffDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _StaffDto&&(identical(other.id, id) || other.id == id)&&(identical(other.schoolId, schoolId) || other.schoolId == schoolId)&&(identical(other.staffCode, staffCode) || other.staffCode == staffCode)&&(identical(other.firstName, firstName) || other.firstName == firstName)&&(identical(other.lastName, lastName) || other.lastName == lastName)&&(identical(other.email, email) || other.email == email)&&(identical(other.phone, phone) || other.phone == phone)&&(identical(other.designation, designation) || other.designation == designation)&&(identical(other.status, status) || other.status == status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,schoolId,staffCode,firstName,lastName,email,phone,designation,status);

@override
String toString() {
  return 'StaffDto(id: $id, schoolId: $schoolId, staffCode: $staffCode, firstName: $firstName, lastName: $lastName, email: $email, phone: $phone, designation: $designation, status: $status)';
}


}

/// @nodoc
abstract mixin class _$StaffDtoCopyWith<$Res> implements $StaffDtoCopyWith<$Res> {
  factory _$StaffDtoCopyWith(_StaffDto value, $Res Function(_StaffDto) _then) = __$StaffDtoCopyWithImpl;
@override @useResult
$Res call({
 String? id,@JsonKey(name: 'school_id') String? schoolId,@JsonKey(name: 'staff_code') String? staffCode,@JsonKey(name: 'first_name') String? firstName,@JsonKey(name: 'last_name') String? lastName, String? email, String? phone, String? designation, String? status
});




}
/// @nodoc
class __$StaffDtoCopyWithImpl<$Res>
    implements _$StaffDtoCopyWith<$Res> {
  __$StaffDtoCopyWithImpl(this._self, this._then);

  final _StaffDto _self;
  final $Res Function(_StaffDto) _then;

/// Create a copy of StaffDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = freezed,Object? schoolId = freezed,Object? staffCode = freezed,Object? firstName = freezed,Object? lastName = freezed,Object? email = freezed,Object? phone = freezed,Object? designation = freezed,Object? status = freezed,}) {
  return _then(_StaffDto(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,schoolId: freezed == schoolId ? _self.schoolId : schoolId // ignore: cast_nullable_to_non_nullable
as String?,staffCode: freezed == staffCode ? _self.staffCode : staffCode // ignore: cast_nullable_to_non_nullable
as String?,firstName: freezed == firstName ? _self.firstName : firstName // ignore: cast_nullable_to_non_nullable
as String?,lastName: freezed == lastName ? _self.lastName : lastName // ignore: cast_nullable_to_non_nullable
as String?,email: freezed == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String?,phone: freezed == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String?,designation: freezed == designation ? _self.designation : designation // ignore: cast_nullable_to_non_nullable
as String?,status: freezed == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$AttendanceSessionDto {

 String? get id;@JsonKey(name: 'section_id') String? get sectionId;@JsonKey(name: 'subject_id') String? get subjectId;@JsonKey(name: 'staff_id') String? get staffId; dynamic get date;@JsonKey(name: 'period_number') int? get periodNumber;@JsonKey(name: 'total_students') int? get totalStudents;@JsonKey(name: 'present_count') int? get presentCount;@JsonKey(name: 'is_finalized') bool? get isFinalized;
/// Create a copy of AttendanceSessionDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AttendanceSessionDtoCopyWith<AttendanceSessionDto> get copyWith => _$AttendanceSessionDtoCopyWithImpl<AttendanceSessionDto>(this as AttendanceSessionDto, _$identity);

  /// Serializes this AttendanceSessionDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AttendanceSessionDto&&(identical(other.id, id) || other.id == id)&&(identical(other.sectionId, sectionId) || other.sectionId == sectionId)&&(identical(other.subjectId, subjectId) || other.subjectId == subjectId)&&(identical(other.staffId, staffId) || other.staffId == staffId)&&const DeepCollectionEquality().equals(other.date, date)&&(identical(other.periodNumber, periodNumber) || other.periodNumber == periodNumber)&&(identical(other.totalStudents, totalStudents) || other.totalStudents == totalStudents)&&(identical(other.presentCount, presentCount) || other.presentCount == presentCount)&&(identical(other.isFinalized, isFinalized) || other.isFinalized == isFinalized));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,sectionId,subjectId,staffId,const DeepCollectionEquality().hash(date),periodNumber,totalStudents,presentCount,isFinalized);

@override
String toString() {
  return 'AttendanceSessionDto(id: $id, sectionId: $sectionId, subjectId: $subjectId, staffId: $staffId, date: $date, periodNumber: $periodNumber, totalStudents: $totalStudents, presentCount: $presentCount, isFinalized: $isFinalized)';
}


}

/// @nodoc
abstract mixin class $AttendanceSessionDtoCopyWith<$Res>  {
  factory $AttendanceSessionDtoCopyWith(AttendanceSessionDto value, $Res Function(AttendanceSessionDto) _then) = _$AttendanceSessionDtoCopyWithImpl;
@useResult
$Res call({
 String? id,@JsonKey(name: 'section_id') String? sectionId,@JsonKey(name: 'subject_id') String? subjectId,@JsonKey(name: 'staff_id') String? staffId, dynamic date,@JsonKey(name: 'period_number') int? periodNumber,@JsonKey(name: 'total_students') int? totalStudents,@JsonKey(name: 'present_count') int? presentCount,@JsonKey(name: 'is_finalized') bool? isFinalized
});




}
/// @nodoc
class _$AttendanceSessionDtoCopyWithImpl<$Res>
    implements $AttendanceSessionDtoCopyWith<$Res> {
  _$AttendanceSessionDtoCopyWithImpl(this._self, this._then);

  final AttendanceSessionDto _self;
  final $Res Function(AttendanceSessionDto) _then;

/// Create a copy of AttendanceSessionDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = freezed,Object? sectionId = freezed,Object? subjectId = freezed,Object? staffId = freezed,Object? date = freezed,Object? periodNumber = freezed,Object? totalStudents = freezed,Object? presentCount = freezed,Object? isFinalized = freezed,}) {
  return _then(_self.copyWith(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,sectionId: freezed == sectionId ? _self.sectionId : sectionId // ignore: cast_nullable_to_non_nullable
as String?,subjectId: freezed == subjectId ? _self.subjectId : subjectId // ignore: cast_nullable_to_non_nullable
as String?,staffId: freezed == staffId ? _self.staffId : staffId // ignore: cast_nullable_to_non_nullable
as String?,date: freezed == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as dynamic,periodNumber: freezed == periodNumber ? _self.periodNumber : periodNumber // ignore: cast_nullable_to_non_nullable
as int?,totalStudents: freezed == totalStudents ? _self.totalStudents : totalStudents // ignore: cast_nullable_to_non_nullable
as int?,presentCount: freezed == presentCount ? _self.presentCount : presentCount // ignore: cast_nullable_to_non_nullable
as int?,isFinalized: freezed == isFinalized ? _self.isFinalized : isFinalized // ignore: cast_nullable_to_non_nullable
as bool?,
  ));
}

}


/// Adds pattern-matching-related methods to [AttendanceSessionDto].
extension AttendanceSessionDtoPatterns on AttendanceSessionDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AttendanceSessionDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AttendanceSessionDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AttendanceSessionDto value)  $default,){
final _that = this;
switch (_that) {
case _AttendanceSessionDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AttendanceSessionDto value)?  $default,){
final _that = this;
switch (_that) {
case _AttendanceSessionDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? id, @JsonKey(name: 'section_id')  String? sectionId, @JsonKey(name: 'subject_id')  String? subjectId, @JsonKey(name: 'staff_id')  String? staffId,  dynamic date, @JsonKey(name: 'period_number')  int? periodNumber, @JsonKey(name: 'total_students')  int? totalStudents, @JsonKey(name: 'present_count')  int? presentCount, @JsonKey(name: 'is_finalized')  bool? isFinalized)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AttendanceSessionDto() when $default != null:
return $default(_that.id,_that.sectionId,_that.subjectId,_that.staffId,_that.date,_that.periodNumber,_that.totalStudents,_that.presentCount,_that.isFinalized);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? id, @JsonKey(name: 'section_id')  String? sectionId, @JsonKey(name: 'subject_id')  String? subjectId, @JsonKey(name: 'staff_id')  String? staffId,  dynamic date, @JsonKey(name: 'period_number')  int? periodNumber, @JsonKey(name: 'total_students')  int? totalStudents, @JsonKey(name: 'present_count')  int? presentCount, @JsonKey(name: 'is_finalized')  bool? isFinalized)  $default,) {final _that = this;
switch (_that) {
case _AttendanceSessionDto():
return $default(_that.id,_that.sectionId,_that.subjectId,_that.staffId,_that.date,_that.periodNumber,_that.totalStudents,_that.presentCount,_that.isFinalized);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? id, @JsonKey(name: 'section_id')  String? sectionId, @JsonKey(name: 'subject_id')  String? subjectId, @JsonKey(name: 'staff_id')  String? staffId,  dynamic date, @JsonKey(name: 'period_number')  int? periodNumber, @JsonKey(name: 'total_students')  int? totalStudents, @JsonKey(name: 'present_count')  int? presentCount, @JsonKey(name: 'is_finalized')  bool? isFinalized)?  $default,) {final _that = this;
switch (_that) {
case _AttendanceSessionDto() when $default != null:
return $default(_that.id,_that.sectionId,_that.subjectId,_that.staffId,_that.date,_that.periodNumber,_that.totalStudents,_that.presentCount,_that.isFinalized);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AttendanceSessionDto implements AttendanceSessionDto {
  const _AttendanceSessionDto({this.id, @JsonKey(name: 'section_id') this.sectionId, @JsonKey(name: 'subject_id') this.subjectId, @JsonKey(name: 'staff_id') this.staffId, this.date, @JsonKey(name: 'period_number') this.periodNumber, @JsonKey(name: 'total_students') this.totalStudents, @JsonKey(name: 'present_count') this.presentCount, @JsonKey(name: 'is_finalized') this.isFinalized});
  factory _AttendanceSessionDto.fromJson(Map<String, dynamic> json) => _$AttendanceSessionDtoFromJson(json);

@override final  String? id;
@override@JsonKey(name: 'section_id') final  String? sectionId;
@override@JsonKey(name: 'subject_id') final  String? subjectId;
@override@JsonKey(name: 'staff_id') final  String? staffId;
@override final  dynamic date;
@override@JsonKey(name: 'period_number') final  int? periodNumber;
@override@JsonKey(name: 'total_students') final  int? totalStudents;
@override@JsonKey(name: 'present_count') final  int? presentCount;
@override@JsonKey(name: 'is_finalized') final  bool? isFinalized;

/// Create a copy of AttendanceSessionDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AttendanceSessionDtoCopyWith<_AttendanceSessionDto> get copyWith => __$AttendanceSessionDtoCopyWithImpl<_AttendanceSessionDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AttendanceSessionDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AttendanceSessionDto&&(identical(other.id, id) || other.id == id)&&(identical(other.sectionId, sectionId) || other.sectionId == sectionId)&&(identical(other.subjectId, subjectId) || other.subjectId == subjectId)&&(identical(other.staffId, staffId) || other.staffId == staffId)&&const DeepCollectionEquality().equals(other.date, date)&&(identical(other.periodNumber, periodNumber) || other.periodNumber == periodNumber)&&(identical(other.totalStudents, totalStudents) || other.totalStudents == totalStudents)&&(identical(other.presentCount, presentCount) || other.presentCount == presentCount)&&(identical(other.isFinalized, isFinalized) || other.isFinalized == isFinalized));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,sectionId,subjectId,staffId,const DeepCollectionEquality().hash(date),periodNumber,totalStudents,presentCount,isFinalized);

@override
String toString() {
  return 'AttendanceSessionDto(id: $id, sectionId: $sectionId, subjectId: $subjectId, staffId: $staffId, date: $date, periodNumber: $periodNumber, totalStudents: $totalStudents, presentCount: $presentCount, isFinalized: $isFinalized)';
}


}

/// @nodoc
abstract mixin class _$AttendanceSessionDtoCopyWith<$Res> implements $AttendanceSessionDtoCopyWith<$Res> {
  factory _$AttendanceSessionDtoCopyWith(_AttendanceSessionDto value, $Res Function(_AttendanceSessionDto) _then) = __$AttendanceSessionDtoCopyWithImpl;
@override @useResult
$Res call({
 String? id,@JsonKey(name: 'section_id') String? sectionId,@JsonKey(name: 'subject_id') String? subjectId,@JsonKey(name: 'staff_id') String? staffId, dynamic date,@JsonKey(name: 'period_number') int? periodNumber,@JsonKey(name: 'total_students') int? totalStudents,@JsonKey(name: 'present_count') int? presentCount,@JsonKey(name: 'is_finalized') bool? isFinalized
});




}
/// @nodoc
class __$AttendanceSessionDtoCopyWithImpl<$Res>
    implements _$AttendanceSessionDtoCopyWith<$Res> {
  __$AttendanceSessionDtoCopyWithImpl(this._self, this._then);

  final _AttendanceSessionDto _self;
  final $Res Function(_AttendanceSessionDto) _then;

/// Create a copy of AttendanceSessionDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = freezed,Object? sectionId = freezed,Object? subjectId = freezed,Object? staffId = freezed,Object? date = freezed,Object? periodNumber = freezed,Object? totalStudents = freezed,Object? presentCount = freezed,Object? isFinalized = freezed,}) {
  return _then(_AttendanceSessionDto(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,sectionId: freezed == sectionId ? _self.sectionId : sectionId // ignore: cast_nullable_to_non_nullable
as String?,subjectId: freezed == subjectId ? _self.subjectId : subjectId // ignore: cast_nullable_to_non_nullable
as String?,staffId: freezed == staffId ? _self.staffId : staffId // ignore: cast_nullable_to_non_nullable
as String?,date: freezed == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as dynamic,periodNumber: freezed == periodNumber ? _self.periodNumber : periodNumber // ignore: cast_nullable_to_non_nullable
as int?,totalStudents: freezed == totalStudents ? _self.totalStudents : totalStudents // ignore: cast_nullable_to_non_nullable
as int?,presentCount: freezed == presentCount ? _self.presentCount : presentCount // ignore: cast_nullable_to_non_nullable
as int?,isFinalized: freezed == isFinalized ? _self.isFinalized : isFinalized // ignore: cast_nullable_to_non_nullable
as bool?,
  ));
}


}


/// @nodoc
mixin _$FeeInvoiceDto {

 String? get id;@JsonKey(name: 'student_id') String? get studentId;@JsonKey(name: 'academic_year_id') String? get academicYearId;@JsonKey(name: 'invoice_number') String? get invoiceNumber;@JsonKey(name: 'due_date') dynamic get dueDate;@JsonKey(name: 'total_amount') num? get totalAmount;@JsonKey(name: 'paid_amount') num? get paidAmount; num? get balance; String? get status;
/// Create a copy of FeeInvoiceDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FeeInvoiceDtoCopyWith<FeeInvoiceDto> get copyWith => _$FeeInvoiceDtoCopyWithImpl<FeeInvoiceDto>(this as FeeInvoiceDto, _$identity);

  /// Serializes this FeeInvoiceDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FeeInvoiceDto&&(identical(other.id, id) || other.id == id)&&(identical(other.studentId, studentId) || other.studentId == studentId)&&(identical(other.academicYearId, academicYearId) || other.academicYearId == academicYearId)&&(identical(other.invoiceNumber, invoiceNumber) || other.invoiceNumber == invoiceNumber)&&const DeepCollectionEquality().equals(other.dueDate, dueDate)&&(identical(other.totalAmount, totalAmount) || other.totalAmount == totalAmount)&&(identical(other.paidAmount, paidAmount) || other.paidAmount == paidAmount)&&(identical(other.balance, balance) || other.balance == balance)&&(identical(other.status, status) || other.status == status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,studentId,academicYearId,invoiceNumber,const DeepCollectionEquality().hash(dueDate),totalAmount,paidAmount,balance,status);

@override
String toString() {
  return 'FeeInvoiceDto(id: $id, studentId: $studentId, academicYearId: $academicYearId, invoiceNumber: $invoiceNumber, dueDate: $dueDate, totalAmount: $totalAmount, paidAmount: $paidAmount, balance: $balance, status: $status)';
}


}

/// @nodoc
abstract mixin class $FeeInvoiceDtoCopyWith<$Res>  {
  factory $FeeInvoiceDtoCopyWith(FeeInvoiceDto value, $Res Function(FeeInvoiceDto) _then) = _$FeeInvoiceDtoCopyWithImpl;
@useResult
$Res call({
 String? id,@JsonKey(name: 'student_id') String? studentId,@JsonKey(name: 'academic_year_id') String? academicYearId,@JsonKey(name: 'invoice_number') String? invoiceNumber,@JsonKey(name: 'due_date') dynamic dueDate,@JsonKey(name: 'total_amount') num? totalAmount,@JsonKey(name: 'paid_amount') num? paidAmount, num? balance, String? status
});




}
/// @nodoc
class _$FeeInvoiceDtoCopyWithImpl<$Res>
    implements $FeeInvoiceDtoCopyWith<$Res> {
  _$FeeInvoiceDtoCopyWithImpl(this._self, this._then);

  final FeeInvoiceDto _self;
  final $Res Function(FeeInvoiceDto) _then;

/// Create a copy of FeeInvoiceDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = freezed,Object? studentId = freezed,Object? academicYearId = freezed,Object? invoiceNumber = freezed,Object? dueDate = freezed,Object? totalAmount = freezed,Object? paidAmount = freezed,Object? balance = freezed,Object? status = freezed,}) {
  return _then(_self.copyWith(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,studentId: freezed == studentId ? _self.studentId : studentId // ignore: cast_nullable_to_non_nullable
as String?,academicYearId: freezed == academicYearId ? _self.academicYearId : academicYearId // ignore: cast_nullable_to_non_nullable
as String?,invoiceNumber: freezed == invoiceNumber ? _self.invoiceNumber : invoiceNumber // ignore: cast_nullable_to_non_nullable
as String?,dueDate: freezed == dueDate ? _self.dueDate : dueDate // ignore: cast_nullable_to_non_nullable
as dynamic,totalAmount: freezed == totalAmount ? _self.totalAmount : totalAmount // ignore: cast_nullable_to_non_nullable
as num?,paidAmount: freezed == paidAmount ? _self.paidAmount : paidAmount // ignore: cast_nullable_to_non_nullable
as num?,balance: freezed == balance ? _self.balance : balance // ignore: cast_nullable_to_non_nullable
as num?,status: freezed == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [FeeInvoiceDto].
extension FeeInvoiceDtoPatterns on FeeInvoiceDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FeeInvoiceDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FeeInvoiceDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FeeInvoiceDto value)  $default,){
final _that = this;
switch (_that) {
case _FeeInvoiceDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FeeInvoiceDto value)?  $default,){
final _that = this;
switch (_that) {
case _FeeInvoiceDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? id, @JsonKey(name: 'student_id')  String? studentId, @JsonKey(name: 'academic_year_id')  String? academicYearId, @JsonKey(name: 'invoice_number')  String? invoiceNumber, @JsonKey(name: 'due_date')  dynamic dueDate, @JsonKey(name: 'total_amount')  num? totalAmount, @JsonKey(name: 'paid_amount')  num? paidAmount,  num? balance,  String? status)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FeeInvoiceDto() when $default != null:
return $default(_that.id,_that.studentId,_that.academicYearId,_that.invoiceNumber,_that.dueDate,_that.totalAmount,_that.paidAmount,_that.balance,_that.status);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? id, @JsonKey(name: 'student_id')  String? studentId, @JsonKey(name: 'academic_year_id')  String? academicYearId, @JsonKey(name: 'invoice_number')  String? invoiceNumber, @JsonKey(name: 'due_date')  dynamic dueDate, @JsonKey(name: 'total_amount')  num? totalAmount, @JsonKey(name: 'paid_amount')  num? paidAmount,  num? balance,  String? status)  $default,) {final _that = this;
switch (_that) {
case _FeeInvoiceDto():
return $default(_that.id,_that.studentId,_that.academicYearId,_that.invoiceNumber,_that.dueDate,_that.totalAmount,_that.paidAmount,_that.balance,_that.status);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? id, @JsonKey(name: 'student_id')  String? studentId, @JsonKey(name: 'academic_year_id')  String? academicYearId, @JsonKey(name: 'invoice_number')  String? invoiceNumber, @JsonKey(name: 'due_date')  dynamic dueDate, @JsonKey(name: 'total_amount')  num? totalAmount, @JsonKey(name: 'paid_amount')  num? paidAmount,  num? balance,  String? status)?  $default,) {final _that = this;
switch (_that) {
case _FeeInvoiceDto() when $default != null:
return $default(_that.id,_that.studentId,_that.academicYearId,_that.invoiceNumber,_that.dueDate,_that.totalAmount,_that.paidAmount,_that.balance,_that.status);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _FeeInvoiceDto implements FeeInvoiceDto {
  const _FeeInvoiceDto({this.id, @JsonKey(name: 'student_id') this.studentId, @JsonKey(name: 'academic_year_id') this.academicYearId, @JsonKey(name: 'invoice_number') this.invoiceNumber, @JsonKey(name: 'due_date') this.dueDate, @JsonKey(name: 'total_amount') this.totalAmount, @JsonKey(name: 'paid_amount') this.paidAmount, this.balance, this.status});
  factory _FeeInvoiceDto.fromJson(Map<String, dynamic> json) => _$FeeInvoiceDtoFromJson(json);

@override final  String? id;
@override@JsonKey(name: 'student_id') final  String? studentId;
@override@JsonKey(name: 'academic_year_id') final  String? academicYearId;
@override@JsonKey(name: 'invoice_number') final  String? invoiceNumber;
@override@JsonKey(name: 'due_date') final  dynamic dueDate;
@override@JsonKey(name: 'total_amount') final  num? totalAmount;
@override@JsonKey(name: 'paid_amount') final  num? paidAmount;
@override final  num? balance;
@override final  String? status;

/// Create a copy of FeeInvoiceDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FeeInvoiceDtoCopyWith<_FeeInvoiceDto> get copyWith => __$FeeInvoiceDtoCopyWithImpl<_FeeInvoiceDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FeeInvoiceDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FeeInvoiceDto&&(identical(other.id, id) || other.id == id)&&(identical(other.studentId, studentId) || other.studentId == studentId)&&(identical(other.academicYearId, academicYearId) || other.academicYearId == academicYearId)&&(identical(other.invoiceNumber, invoiceNumber) || other.invoiceNumber == invoiceNumber)&&const DeepCollectionEquality().equals(other.dueDate, dueDate)&&(identical(other.totalAmount, totalAmount) || other.totalAmount == totalAmount)&&(identical(other.paidAmount, paidAmount) || other.paidAmount == paidAmount)&&(identical(other.balance, balance) || other.balance == balance)&&(identical(other.status, status) || other.status == status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,studentId,academicYearId,invoiceNumber,const DeepCollectionEquality().hash(dueDate),totalAmount,paidAmount,balance,status);

@override
String toString() {
  return 'FeeInvoiceDto(id: $id, studentId: $studentId, academicYearId: $academicYearId, invoiceNumber: $invoiceNumber, dueDate: $dueDate, totalAmount: $totalAmount, paidAmount: $paidAmount, balance: $balance, status: $status)';
}


}

/// @nodoc
abstract mixin class _$FeeInvoiceDtoCopyWith<$Res> implements $FeeInvoiceDtoCopyWith<$Res> {
  factory _$FeeInvoiceDtoCopyWith(_FeeInvoiceDto value, $Res Function(_FeeInvoiceDto) _then) = __$FeeInvoiceDtoCopyWithImpl;
@override @useResult
$Res call({
 String? id,@JsonKey(name: 'student_id') String? studentId,@JsonKey(name: 'academic_year_id') String? academicYearId,@JsonKey(name: 'invoice_number') String? invoiceNumber,@JsonKey(name: 'due_date') dynamic dueDate,@JsonKey(name: 'total_amount') num? totalAmount,@JsonKey(name: 'paid_amount') num? paidAmount, num? balance, String? status
});




}
/// @nodoc
class __$FeeInvoiceDtoCopyWithImpl<$Res>
    implements _$FeeInvoiceDtoCopyWith<$Res> {
  __$FeeInvoiceDtoCopyWithImpl(this._self, this._then);

  final _FeeInvoiceDto _self;
  final $Res Function(_FeeInvoiceDto) _then;

/// Create a copy of FeeInvoiceDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = freezed,Object? studentId = freezed,Object? academicYearId = freezed,Object? invoiceNumber = freezed,Object? dueDate = freezed,Object? totalAmount = freezed,Object? paidAmount = freezed,Object? balance = freezed,Object? status = freezed,}) {
  return _then(_FeeInvoiceDto(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,studentId: freezed == studentId ? _self.studentId : studentId // ignore: cast_nullable_to_non_nullable
as String?,academicYearId: freezed == academicYearId ? _self.academicYearId : academicYearId // ignore: cast_nullable_to_non_nullable
as String?,invoiceNumber: freezed == invoiceNumber ? _self.invoiceNumber : invoiceNumber // ignore: cast_nullable_to_non_nullable
as String?,dueDate: freezed == dueDate ? _self.dueDate : dueDate // ignore: cast_nullable_to_non_nullable
as dynamic,totalAmount: freezed == totalAmount ? _self.totalAmount : totalAmount // ignore: cast_nullable_to_non_nullable
as num?,paidAmount: freezed == paidAmount ? _self.paidAmount : paidAmount // ignore: cast_nullable_to_non_nullable
as num?,balance: freezed == balance ? _self.balance : balance // ignore: cast_nullable_to_non_nullable
as num?,status: freezed == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$PaymentDto {

 String? get id;@JsonKey(name: 'invoice_id') String? get invoiceId;@JsonKey(name: 'student_id') String? get studentId; num? get amount;@JsonKey(name: 'payment_mode') String? get paymentMode;@JsonKey(name: 'transaction_id') String? get transactionId;@JsonKey(name: 'paid_at') dynamic get paidAt;
/// Create a copy of PaymentDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PaymentDtoCopyWith<PaymentDto> get copyWith => _$PaymentDtoCopyWithImpl<PaymentDto>(this as PaymentDto, _$identity);

  /// Serializes this PaymentDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PaymentDto&&(identical(other.id, id) || other.id == id)&&(identical(other.invoiceId, invoiceId) || other.invoiceId == invoiceId)&&(identical(other.studentId, studentId) || other.studentId == studentId)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.paymentMode, paymentMode) || other.paymentMode == paymentMode)&&(identical(other.transactionId, transactionId) || other.transactionId == transactionId)&&const DeepCollectionEquality().equals(other.paidAt, paidAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,invoiceId,studentId,amount,paymentMode,transactionId,const DeepCollectionEquality().hash(paidAt));

@override
String toString() {
  return 'PaymentDto(id: $id, invoiceId: $invoiceId, studentId: $studentId, amount: $amount, paymentMode: $paymentMode, transactionId: $transactionId, paidAt: $paidAt)';
}


}

/// @nodoc
abstract mixin class $PaymentDtoCopyWith<$Res>  {
  factory $PaymentDtoCopyWith(PaymentDto value, $Res Function(PaymentDto) _then) = _$PaymentDtoCopyWithImpl;
@useResult
$Res call({
 String? id,@JsonKey(name: 'invoice_id') String? invoiceId,@JsonKey(name: 'student_id') String? studentId, num? amount,@JsonKey(name: 'payment_mode') String? paymentMode,@JsonKey(name: 'transaction_id') String? transactionId,@JsonKey(name: 'paid_at') dynamic paidAt
});




}
/// @nodoc
class _$PaymentDtoCopyWithImpl<$Res>
    implements $PaymentDtoCopyWith<$Res> {
  _$PaymentDtoCopyWithImpl(this._self, this._then);

  final PaymentDto _self;
  final $Res Function(PaymentDto) _then;

/// Create a copy of PaymentDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = freezed,Object? invoiceId = freezed,Object? studentId = freezed,Object? amount = freezed,Object? paymentMode = freezed,Object? transactionId = freezed,Object? paidAt = freezed,}) {
  return _then(_self.copyWith(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,invoiceId: freezed == invoiceId ? _self.invoiceId : invoiceId // ignore: cast_nullable_to_non_nullable
as String?,studentId: freezed == studentId ? _self.studentId : studentId // ignore: cast_nullable_to_non_nullable
as String?,amount: freezed == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as num?,paymentMode: freezed == paymentMode ? _self.paymentMode : paymentMode // ignore: cast_nullable_to_non_nullable
as String?,transactionId: freezed == transactionId ? _self.transactionId : transactionId // ignore: cast_nullable_to_non_nullable
as String?,paidAt: freezed == paidAt ? _self.paidAt : paidAt // ignore: cast_nullable_to_non_nullable
as dynamic,
  ));
}

}


/// Adds pattern-matching-related methods to [PaymentDto].
extension PaymentDtoPatterns on PaymentDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PaymentDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PaymentDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PaymentDto value)  $default,){
final _that = this;
switch (_that) {
case _PaymentDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PaymentDto value)?  $default,){
final _that = this;
switch (_that) {
case _PaymentDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? id, @JsonKey(name: 'invoice_id')  String? invoiceId, @JsonKey(name: 'student_id')  String? studentId,  num? amount, @JsonKey(name: 'payment_mode')  String? paymentMode, @JsonKey(name: 'transaction_id')  String? transactionId, @JsonKey(name: 'paid_at')  dynamic paidAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PaymentDto() when $default != null:
return $default(_that.id,_that.invoiceId,_that.studentId,_that.amount,_that.paymentMode,_that.transactionId,_that.paidAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? id, @JsonKey(name: 'invoice_id')  String? invoiceId, @JsonKey(name: 'student_id')  String? studentId,  num? amount, @JsonKey(name: 'payment_mode')  String? paymentMode, @JsonKey(name: 'transaction_id')  String? transactionId, @JsonKey(name: 'paid_at')  dynamic paidAt)  $default,) {final _that = this;
switch (_that) {
case _PaymentDto():
return $default(_that.id,_that.invoiceId,_that.studentId,_that.amount,_that.paymentMode,_that.transactionId,_that.paidAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? id, @JsonKey(name: 'invoice_id')  String? invoiceId, @JsonKey(name: 'student_id')  String? studentId,  num? amount, @JsonKey(name: 'payment_mode')  String? paymentMode, @JsonKey(name: 'transaction_id')  String? transactionId, @JsonKey(name: 'paid_at')  dynamic paidAt)?  $default,) {final _that = this;
switch (_that) {
case _PaymentDto() when $default != null:
return $default(_that.id,_that.invoiceId,_that.studentId,_that.amount,_that.paymentMode,_that.transactionId,_that.paidAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PaymentDto implements PaymentDto {
  const _PaymentDto({this.id, @JsonKey(name: 'invoice_id') this.invoiceId, @JsonKey(name: 'student_id') this.studentId, this.amount, @JsonKey(name: 'payment_mode') this.paymentMode, @JsonKey(name: 'transaction_id') this.transactionId, @JsonKey(name: 'paid_at') this.paidAt});
  factory _PaymentDto.fromJson(Map<String, dynamic> json) => _$PaymentDtoFromJson(json);

@override final  String? id;
@override@JsonKey(name: 'invoice_id') final  String? invoiceId;
@override@JsonKey(name: 'student_id') final  String? studentId;
@override final  num? amount;
@override@JsonKey(name: 'payment_mode') final  String? paymentMode;
@override@JsonKey(name: 'transaction_id') final  String? transactionId;
@override@JsonKey(name: 'paid_at') final  dynamic paidAt;

/// Create a copy of PaymentDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PaymentDtoCopyWith<_PaymentDto> get copyWith => __$PaymentDtoCopyWithImpl<_PaymentDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PaymentDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PaymentDto&&(identical(other.id, id) || other.id == id)&&(identical(other.invoiceId, invoiceId) || other.invoiceId == invoiceId)&&(identical(other.studentId, studentId) || other.studentId == studentId)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.paymentMode, paymentMode) || other.paymentMode == paymentMode)&&(identical(other.transactionId, transactionId) || other.transactionId == transactionId)&&const DeepCollectionEquality().equals(other.paidAt, paidAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,invoiceId,studentId,amount,paymentMode,transactionId,const DeepCollectionEquality().hash(paidAt));

@override
String toString() {
  return 'PaymentDto(id: $id, invoiceId: $invoiceId, studentId: $studentId, amount: $amount, paymentMode: $paymentMode, transactionId: $transactionId, paidAt: $paidAt)';
}


}

/// @nodoc
abstract mixin class _$PaymentDtoCopyWith<$Res> implements $PaymentDtoCopyWith<$Res> {
  factory _$PaymentDtoCopyWith(_PaymentDto value, $Res Function(_PaymentDto) _then) = __$PaymentDtoCopyWithImpl;
@override @useResult
$Res call({
 String? id,@JsonKey(name: 'invoice_id') String? invoiceId,@JsonKey(name: 'student_id') String? studentId, num? amount,@JsonKey(name: 'payment_mode') String? paymentMode,@JsonKey(name: 'transaction_id') String? transactionId,@JsonKey(name: 'paid_at') dynamic paidAt
});




}
/// @nodoc
class __$PaymentDtoCopyWithImpl<$Res>
    implements _$PaymentDtoCopyWith<$Res> {
  __$PaymentDtoCopyWithImpl(this._self, this._then);

  final _PaymentDto _self;
  final $Res Function(_PaymentDto) _then;

/// Create a copy of PaymentDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = freezed,Object? invoiceId = freezed,Object? studentId = freezed,Object? amount = freezed,Object? paymentMode = freezed,Object? transactionId = freezed,Object? paidAt = freezed,}) {
  return _then(_PaymentDto(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,invoiceId: freezed == invoiceId ? _self.invoiceId : invoiceId // ignore: cast_nullable_to_non_nullable
as String?,studentId: freezed == studentId ? _self.studentId : studentId // ignore: cast_nullable_to_non_nullable
as String?,amount: freezed == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as num?,paymentMode: freezed == paymentMode ? _self.paymentMode : paymentMode // ignore: cast_nullable_to_non_nullable
as String?,transactionId: freezed == transactionId ? _self.transactionId : transactionId // ignore: cast_nullable_to_non_nullable
as String?,paidAt: freezed == paidAt ? _self.paidAt : paidAt // ignore: cast_nullable_to_non_nullable
as dynamic,
  ));
}


}


/// @nodoc
mixin _$ParentPaymentRequestDto {

 String? get id;@JsonKey(name: 'invoice_id') String? get invoiceId;@JsonKey(name: 'student_id') String? get studentId;@JsonKey(name: 'parent_user_id') String? get parentUserId; num? get amount; String? get status; String? get remarks;
/// Create a copy of ParentPaymentRequestDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ParentPaymentRequestDtoCopyWith<ParentPaymentRequestDto> get copyWith => _$ParentPaymentRequestDtoCopyWithImpl<ParentPaymentRequestDto>(this as ParentPaymentRequestDto, _$identity);

  /// Serializes this ParentPaymentRequestDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ParentPaymentRequestDto&&(identical(other.id, id) || other.id == id)&&(identical(other.invoiceId, invoiceId) || other.invoiceId == invoiceId)&&(identical(other.studentId, studentId) || other.studentId == studentId)&&(identical(other.parentUserId, parentUserId) || other.parentUserId == parentUserId)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.status, status) || other.status == status)&&(identical(other.remarks, remarks) || other.remarks == remarks));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,invoiceId,studentId,parentUserId,amount,status,remarks);

@override
String toString() {
  return 'ParentPaymentRequestDto(id: $id, invoiceId: $invoiceId, studentId: $studentId, parentUserId: $parentUserId, amount: $amount, status: $status, remarks: $remarks)';
}


}

/// @nodoc
abstract mixin class $ParentPaymentRequestDtoCopyWith<$Res>  {
  factory $ParentPaymentRequestDtoCopyWith(ParentPaymentRequestDto value, $Res Function(ParentPaymentRequestDto) _then) = _$ParentPaymentRequestDtoCopyWithImpl;
@useResult
$Res call({
 String? id,@JsonKey(name: 'invoice_id') String? invoiceId,@JsonKey(name: 'student_id') String? studentId,@JsonKey(name: 'parent_user_id') String? parentUserId, num? amount, String? status, String? remarks
});




}
/// @nodoc
class _$ParentPaymentRequestDtoCopyWithImpl<$Res>
    implements $ParentPaymentRequestDtoCopyWith<$Res> {
  _$ParentPaymentRequestDtoCopyWithImpl(this._self, this._then);

  final ParentPaymentRequestDto _self;
  final $Res Function(ParentPaymentRequestDto) _then;

/// Create a copy of ParentPaymentRequestDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = freezed,Object? invoiceId = freezed,Object? studentId = freezed,Object? parentUserId = freezed,Object? amount = freezed,Object? status = freezed,Object? remarks = freezed,}) {
  return _then(_self.copyWith(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,invoiceId: freezed == invoiceId ? _self.invoiceId : invoiceId // ignore: cast_nullable_to_non_nullable
as String?,studentId: freezed == studentId ? _self.studentId : studentId // ignore: cast_nullable_to_non_nullable
as String?,parentUserId: freezed == parentUserId ? _self.parentUserId : parentUserId // ignore: cast_nullable_to_non_nullable
as String?,amount: freezed == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as num?,status: freezed == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String?,remarks: freezed == remarks ? _self.remarks : remarks // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [ParentPaymentRequestDto].
extension ParentPaymentRequestDtoPatterns on ParentPaymentRequestDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ParentPaymentRequestDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ParentPaymentRequestDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ParentPaymentRequestDto value)  $default,){
final _that = this;
switch (_that) {
case _ParentPaymentRequestDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ParentPaymentRequestDto value)?  $default,){
final _that = this;
switch (_that) {
case _ParentPaymentRequestDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? id, @JsonKey(name: 'invoice_id')  String? invoiceId, @JsonKey(name: 'student_id')  String? studentId, @JsonKey(name: 'parent_user_id')  String? parentUserId,  num? amount,  String? status,  String? remarks)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ParentPaymentRequestDto() when $default != null:
return $default(_that.id,_that.invoiceId,_that.studentId,_that.parentUserId,_that.amount,_that.status,_that.remarks);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? id, @JsonKey(name: 'invoice_id')  String? invoiceId, @JsonKey(name: 'student_id')  String? studentId, @JsonKey(name: 'parent_user_id')  String? parentUserId,  num? amount,  String? status,  String? remarks)  $default,) {final _that = this;
switch (_that) {
case _ParentPaymentRequestDto():
return $default(_that.id,_that.invoiceId,_that.studentId,_that.parentUserId,_that.amount,_that.status,_that.remarks);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? id, @JsonKey(name: 'invoice_id')  String? invoiceId, @JsonKey(name: 'student_id')  String? studentId, @JsonKey(name: 'parent_user_id')  String? parentUserId,  num? amount,  String? status,  String? remarks)?  $default,) {final _that = this;
switch (_that) {
case _ParentPaymentRequestDto() when $default != null:
return $default(_that.id,_that.invoiceId,_that.studentId,_that.parentUserId,_that.amount,_that.status,_that.remarks);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ParentPaymentRequestDto implements ParentPaymentRequestDto {
  const _ParentPaymentRequestDto({this.id, @JsonKey(name: 'invoice_id') this.invoiceId, @JsonKey(name: 'student_id') this.studentId, @JsonKey(name: 'parent_user_id') this.parentUserId, this.amount, this.status, this.remarks});
  factory _ParentPaymentRequestDto.fromJson(Map<String, dynamic> json) => _$ParentPaymentRequestDtoFromJson(json);

@override final  String? id;
@override@JsonKey(name: 'invoice_id') final  String? invoiceId;
@override@JsonKey(name: 'student_id') final  String? studentId;
@override@JsonKey(name: 'parent_user_id') final  String? parentUserId;
@override final  num? amount;
@override final  String? status;
@override final  String? remarks;

/// Create a copy of ParentPaymentRequestDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ParentPaymentRequestDtoCopyWith<_ParentPaymentRequestDto> get copyWith => __$ParentPaymentRequestDtoCopyWithImpl<_ParentPaymentRequestDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ParentPaymentRequestDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ParentPaymentRequestDto&&(identical(other.id, id) || other.id == id)&&(identical(other.invoiceId, invoiceId) || other.invoiceId == invoiceId)&&(identical(other.studentId, studentId) || other.studentId == studentId)&&(identical(other.parentUserId, parentUserId) || other.parentUserId == parentUserId)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.status, status) || other.status == status)&&(identical(other.remarks, remarks) || other.remarks == remarks));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,invoiceId,studentId,parentUserId,amount,status,remarks);

@override
String toString() {
  return 'ParentPaymentRequestDto(id: $id, invoiceId: $invoiceId, studentId: $studentId, parentUserId: $parentUserId, amount: $amount, status: $status, remarks: $remarks)';
}


}

/// @nodoc
abstract mixin class _$ParentPaymentRequestDtoCopyWith<$Res> implements $ParentPaymentRequestDtoCopyWith<$Res> {
  factory _$ParentPaymentRequestDtoCopyWith(_ParentPaymentRequestDto value, $Res Function(_ParentPaymentRequestDto) _then) = __$ParentPaymentRequestDtoCopyWithImpl;
@override @useResult
$Res call({
 String? id,@JsonKey(name: 'invoice_id') String? invoiceId,@JsonKey(name: 'student_id') String? studentId,@JsonKey(name: 'parent_user_id') String? parentUserId, num? amount, String? status, String? remarks
});




}
/// @nodoc
class __$ParentPaymentRequestDtoCopyWithImpl<$Res>
    implements _$ParentPaymentRequestDtoCopyWith<$Res> {
  __$ParentPaymentRequestDtoCopyWithImpl(this._self, this._then);

  final _ParentPaymentRequestDto _self;
  final $Res Function(_ParentPaymentRequestDto) _then;

/// Create a copy of ParentPaymentRequestDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = freezed,Object? invoiceId = freezed,Object? studentId = freezed,Object? parentUserId = freezed,Object? amount = freezed,Object? status = freezed,Object? remarks = freezed,}) {
  return _then(_ParentPaymentRequestDto(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,invoiceId: freezed == invoiceId ? _self.invoiceId : invoiceId // ignore: cast_nullable_to_non_nullable
as String?,studentId: freezed == studentId ? _self.studentId : studentId // ignore: cast_nullable_to_non_nullable
as String?,parentUserId: freezed == parentUserId ? _self.parentUserId : parentUserId // ignore: cast_nullable_to_non_nullable
as String?,amount: freezed == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as num?,status: freezed == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String?,remarks: freezed == remarks ? _self.remarks : remarks // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$MessageConversationDto {

 String? get id;@JsonKey(name: 'school_id') String? get schoolId;@JsonKey(name: 'teacher_id') String? get teacherId;@JsonKey(name: 'parent_id') String? get parentId;@JsonKey(name: 'student_id') String? get studentId; String? get title;@JsonKey(name: 'last_message') String? get lastMessage;@JsonKey(name: 'last_message_time') dynamic get lastMessageTime;
/// Create a copy of MessageConversationDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MessageConversationDtoCopyWith<MessageConversationDto> get copyWith => _$MessageConversationDtoCopyWithImpl<MessageConversationDto>(this as MessageConversationDto, _$identity);

  /// Serializes this MessageConversationDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MessageConversationDto&&(identical(other.id, id) || other.id == id)&&(identical(other.schoolId, schoolId) || other.schoolId == schoolId)&&(identical(other.teacherId, teacherId) || other.teacherId == teacherId)&&(identical(other.parentId, parentId) || other.parentId == parentId)&&(identical(other.studentId, studentId) || other.studentId == studentId)&&(identical(other.title, title) || other.title == title)&&(identical(other.lastMessage, lastMessage) || other.lastMessage == lastMessage)&&const DeepCollectionEquality().equals(other.lastMessageTime, lastMessageTime));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,schoolId,teacherId,parentId,studentId,title,lastMessage,const DeepCollectionEquality().hash(lastMessageTime));

@override
String toString() {
  return 'MessageConversationDto(id: $id, schoolId: $schoolId, teacherId: $teacherId, parentId: $parentId, studentId: $studentId, title: $title, lastMessage: $lastMessage, lastMessageTime: $lastMessageTime)';
}


}

/// @nodoc
abstract mixin class $MessageConversationDtoCopyWith<$Res>  {
  factory $MessageConversationDtoCopyWith(MessageConversationDto value, $Res Function(MessageConversationDto) _then) = _$MessageConversationDtoCopyWithImpl;
@useResult
$Res call({
 String? id,@JsonKey(name: 'school_id') String? schoolId,@JsonKey(name: 'teacher_id') String? teacherId,@JsonKey(name: 'parent_id') String? parentId,@JsonKey(name: 'student_id') String? studentId, String? title,@JsonKey(name: 'last_message') String? lastMessage,@JsonKey(name: 'last_message_time') dynamic lastMessageTime
});




}
/// @nodoc
class _$MessageConversationDtoCopyWithImpl<$Res>
    implements $MessageConversationDtoCopyWith<$Res> {
  _$MessageConversationDtoCopyWithImpl(this._self, this._then);

  final MessageConversationDto _self;
  final $Res Function(MessageConversationDto) _then;

/// Create a copy of MessageConversationDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = freezed,Object? schoolId = freezed,Object? teacherId = freezed,Object? parentId = freezed,Object? studentId = freezed,Object? title = freezed,Object? lastMessage = freezed,Object? lastMessageTime = freezed,}) {
  return _then(_self.copyWith(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,schoolId: freezed == schoolId ? _self.schoolId : schoolId // ignore: cast_nullable_to_non_nullable
as String?,teacherId: freezed == teacherId ? _self.teacherId : teacherId // ignore: cast_nullable_to_non_nullable
as String?,parentId: freezed == parentId ? _self.parentId : parentId // ignore: cast_nullable_to_non_nullable
as String?,studentId: freezed == studentId ? _self.studentId : studentId // ignore: cast_nullable_to_non_nullable
as String?,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,lastMessage: freezed == lastMessage ? _self.lastMessage : lastMessage // ignore: cast_nullable_to_non_nullable
as String?,lastMessageTime: freezed == lastMessageTime ? _self.lastMessageTime : lastMessageTime // ignore: cast_nullable_to_non_nullable
as dynamic,
  ));
}

}


/// Adds pattern-matching-related methods to [MessageConversationDto].
extension MessageConversationDtoPatterns on MessageConversationDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MessageConversationDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MessageConversationDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MessageConversationDto value)  $default,){
final _that = this;
switch (_that) {
case _MessageConversationDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MessageConversationDto value)?  $default,){
final _that = this;
switch (_that) {
case _MessageConversationDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? id, @JsonKey(name: 'school_id')  String? schoolId, @JsonKey(name: 'teacher_id')  String? teacherId, @JsonKey(name: 'parent_id')  String? parentId, @JsonKey(name: 'student_id')  String? studentId,  String? title, @JsonKey(name: 'last_message')  String? lastMessage, @JsonKey(name: 'last_message_time')  dynamic lastMessageTime)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MessageConversationDto() when $default != null:
return $default(_that.id,_that.schoolId,_that.teacherId,_that.parentId,_that.studentId,_that.title,_that.lastMessage,_that.lastMessageTime);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? id, @JsonKey(name: 'school_id')  String? schoolId, @JsonKey(name: 'teacher_id')  String? teacherId, @JsonKey(name: 'parent_id')  String? parentId, @JsonKey(name: 'student_id')  String? studentId,  String? title, @JsonKey(name: 'last_message')  String? lastMessage, @JsonKey(name: 'last_message_time')  dynamic lastMessageTime)  $default,) {final _that = this;
switch (_that) {
case _MessageConversationDto():
return $default(_that.id,_that.schoolId,_that.teacherId,_that.parentId,_that.studentId,_that.title,_that.lastMessage,_that.lastMessageTime);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? id, @JsonKey(name: 'school_id')  String? schoolId, @JsonKey(name: 'teacher_id')  String? teacherId, @JsonKey(name: 'parent_id')  String? parentId, @JsonKey(name: 'student_id')  String? studentId,  String? title, @JsonKey(name: 'last_message')  String? lastMessage, @JsonKey(name: 'last_message_time')  dynamic lastMessageTime)?  $default,) {final _that = this;
switch (_that) {
case _MessageConversationDto() when $default != null:
return $default(_that.id,_that.schoolId,_that.teacherId,_that.parentId,_that.studentId,_that.title,_that.lastMessage,_that.lastMessageTime);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MessageConversationDto implements MessageConversationDto {
  const _MessageConversationDto({this.id, @JsonKey(name: 'school_id') this.schoolId, @JsonKey(name: 'teacher_id') this.teacherId, @JsonKey(name: 'parent_id') this.parentId, @JsonKey(name: 'student_id') this.studentId, this.title, @JsonKey(name: 'last_message') this.lastMessage, @JsonKey(name: 'last_message_time') this.lastMessageTime});
  factory _MessageConversationDto.fromJson(Map<String, dynamic> json) => _$MessageConversationDtoFromJson(json);

@override final  String? id;
@override@JsonKey(name: 'school_id') final  String? schoolId;
@override@JsonKey(name: 'teacher_id') final  String? teacherId;
@override@JsonKey(name: 'parent_id') final  String? parentId;
@override@JsonKey(name: 'student_id') final  String? studentId;
@override final  String? title;
@override@JsonKey(name: 'last_message') final  String? lastMessage;
@override@JsonKey(name: 'last_message_time') final  dynamic lastMessageTime;

/// Create a copy of MessageConversationDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MessageConversationDtoCopyWith<_MessageConversationDto> get copyWith => __$MessageConversationDtoCopyWithImpl<_MessageConversationDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MessageConversationDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MessageConversationDto&&(identical(other.id, id) || other.id == id)&&(identical(other.schoolId, schoolId) || other.schoolId == schoolId)&&(identical(other.teacherId, teacherId) || other.teacherId == teacherId)&&(identical(other.parentId, parentId) || other.parentId == parentId)&&(identical(other.studentId, studentId) || other.studentId == studentId)&&(identical(other.title, title) || other.title == title)&&(identical(other.lastMessage, lastMessage) || other.lastMessage == lastMessage)&&const DeepCollectionEquality().equals(other.lastMessageTime, lastMessageTime));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,schoolId,teacherId,parentId,studentId,title,lastMessage,const DeepCollectionEquality().hash(lastMessageTime));

@override
String toString() {
  return 'MessageConversationDto(id: $id, schoolId: $schoolId, teacherId: $teacherId, parentId: $parentId, studentId: $studentId, title: $title, lastMessage: $lastMessage, lastMessageTime: $lastMessageTime)';
}


}

/// @nodoc
abstract mixin class _$MessageConversationDtoCopyWith<$Res> implements $MessageConversationDtoCopyWith<$Res> {
  factory _$MessageConversationDtoCopyWith(_MessageConversationDto value, $Res Function(_MessageConversationDto) _then) = __$MessageConversationDtoCopyWithImpl;
@override @useResult
$Res call({
 String? id,@JsonKey(name: 'school_id') String? schoolId,@JsonKey(name: 'teacher_id') String? teacherId,@JsonKey(name: 'parent_id') String? parentId,@JsonKey(name: 'student_id') String? studentId, String? title,@JsonKey(name: 'last_message') String? lastMessage,@JsonKey(name: 'last_message_time') dynamic lastMessageTime
});




}
/// @nodoc
class __$MessageConversationDtoCopyWithImpl<$Res>
    implements _$MessageConversationDtoCopyWith<$Res> {
  __$MessageConversationDtoCopyWithImpl(this._self, this._then);

  final _MessageConversationDto _self;
  final $Res Function(_MessageConversationDto) _then;

/// Create a copy of MessageConversationDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = freezed,Object? schoolId = freezed,Object? teacherId = freezed,Object? parentId = freezed,Object? studentId = freezed,Object? title = freezed,Object? lastMessage = freezed,Object? lastMessageTime = freezed,}) {
  return _then(_MessageConversationDto(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,schoolId: freezed == schoolId ? _self.schoolId : schoolId // ignore: cast_nullable_to_non_nullable
as String?,teacherId: freezed == teacherId ? _self.teacherId : teacherId // ignore: cast_nullable_to_non_nullable
as String?,parentId: freezed == parentId ? _self.parentId : parentId // ignore: cast_nullable_to_non_nullable
as String?,studentId: freezed == studentId ? _self.studentId : studentId // ignore: cast_nullable_to_non_nullable
as String?,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,lastMessage: freezed == lastMessage ? _self.lastMessage : lastMessage // ignore: cast_nullable_to_non_nullable
as String?,lastMessageTime: freezed == lastMessageTime ? _self.lastMessageTime : lastMessageTime // ignore: cast_nullable_to_non_nullable
as dynamic,
  ));
}


}


/// @nodoc
mixin _$MessageDto {

 String? get id;@JsonKey(name: 'conversation_id') String? get conversationId;@JsonKey(name: 'sender_id') String? get senderId;@JsonKey(name: 'sender_role') String? get senderRole;@JsonKey(name: 'sender_name') String? get senderName; String? get body;@JsonKey(name: 'is_read') bool? get isRead;@JsonKey(name: 'sent_at') dynamic get sentAt;
/// Create a copy of MessageDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MessageDtoCopyWith<MessageDto> get copyWith => _$MessageDtoCopyWithImpl<MessageDto>(this as MessageDto, _$identity);

  /// Serializes this MessageDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MessageDto&&(identical(other.id, id) || other.id == id)&&(identical(other.conversationId, conversationId) || other.conversationId == conversationId)&&(identical(other.senderId, senderId) || other.senderId == senderId)&&(identical(other.senderRole, senderRole) || other.senderRole == senderRole)&&(identical(other.senderName, senderName) || other.senderName == senderName)&&(identical(other.body, body) || other.body == body)&&(identical(other.isRead, isRead) || other.isRead == isRead)&&const DeepCollectionEquality().equals(other.sentAt, sentAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,conversationId,senderId,senderRole,senderName,body,isRead,const DeepCollectionEquality().hash(sentAt));

@override
String toString() {
  return 'MessageDto(id: $id, conversationId: $conversationId, senderId: $senderId, senderRole: $senderRole, senderName: $senderName, body: $body, isRead: $isRead, sentAt: $sentAt)';
}


}

/// @nodoc
abstract mixin class $MessageDtoCopyWith<$Res>  {
  factory $MessageDtoCopyWith(MessageDto value, $Res Function(MessageDto) _then) = _$MessageDtoCopyWithImpl;
@useResult
$Res call({
 String? id,@JsonKey(name: 'conversation_id') String? conversationId,@JsonKey(name: 'sender_id') String? senderId,@JsonKey(name: 'sender_role') String? senderRole,@JsonKey(name: 'sender_name') String? senderName, String? body,@JsonKey(name: 'is_read') bool? isRead,@JsonKey(name: 'sent_at') dynamic sentAt
});




}
/// @nodoc
class _$MessageDtoCopyWithImpl<$Res>
    implements $MessageDtoCopyWith<$Res> {
  _$MessageDtoCopyWithImpl(this._self, this._then);

  final MessageDto _self;
  final $Res Function(MessageDto) _then;

/// Create a copy of MessageDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = freezed,Object? conversationId = freezed,Object? senderId = freezed,Object? senderRole = freezed,Object? senderName = freezed,Object? body = freezed,Object? isRead = freezed,Object? sentAt = freezed,}) {
  return _then(_self.copyWith(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,conversationId: freezed == conversationId ? _self.conversationId : conversationId // ignore: cast_nullable_to_non_nullable
as String?,senderId: freezed == senderId ? _self.senderId : senderId // ignore: cast_nullable_to_non_nullable
as String?,senderRole: freezed == senderRole ? _self.senderRole : senderRole // ignore: cast_nullable_to_non_nullable
as String?,senderName: freezed == senderName ? _self.senderName : senderName // ignore: cast_nullable_to_non_nullable
as String?,body: freezed == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String?,isRead: freezed == isRead ? _self.isRead : isRead // ignore: cast_nullable_to_non_nullable
as bool?,sentAt: freezed == sentAt ? _self.sentAt : sentAt // ignore: cast_nullable_to_non_nullable
as dynamic,
  ));
}

}


/// Adds pattern-matching-related methods to [MessageDto].
extension MessageDtoPatterns on MessageDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MessageDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MessageDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MessageDto value)  $default,){
final _that = this;
switch (_that) {
case _MessageDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MessageDto value)?  $default,){
final _that = this;
switch (_that) {
case _MessageDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? id, @JsonKey(name: 'conversation_id')  String? conversationId, @JsonKey(name: 'sender_id')  String? senderId, @JsonKey(name: 'sender_role')  String? senderRole, @JsonKey(name: 'sender_name')  String? senderName,  String? body, @JsonKey(name: 'is_read')  bool? isRead, @JsonKey(name: 'sent_at')  dynamic sentAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MessageDto() when $default != null:
return $default(_that.id,_that.conversationId,_that.senderId,_that.senderRole,_that.senderName,_that.body,_that.isRead,_that.sentAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? id, @JsonKey(name: 'conversation_id')  String? conversationId, @JsonKey(name: 'sender_id')  String? senderId, @JsonKey(name: 'sender_role')  String? senderRole, @JsonKey(name: 'sender_name')  String? senderName,  String? body, @JsonKey(name: 'is_read')  bool? isRead, @JsonKey(name: 'sent_at')  dynamic sentAt)  $default,) {final _that = this;
switch (_that) {
case _MessageDto():
return $default(_that.id,_that.conversationId,_that.senderId,_that.senderRole,_that.senderName,_that.body,_that.isRead,_that.sentAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? id, @JsonKey(name: 'conversation_id')  String? conversationId, @JsonKey(name: 'sender_id')  String? senderId, @JsonKey(name: 'sender_role')  String? senderRole, @JsonKey(name: 'sender_name')  String? senderName,  String? body, @JsonKey(name: 'is_read')  bool? isRead, @JsonKey(name: 'sent_at')  dynamic sentAt)?  $default,) {final _that = this;
switch (_that) {
case _MessageDto() when $default != null:
return $default(_that.id,_that.conversationId,_that.senderId,_that.senderRole,_that.senderName,_that.body,_that.isRead,_that.sentAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MessageDto implements MessageDto {
  const _MessageDto({this.id, @JsonKey(name: 'conversation_id') this.conversationId, @JsonKey(name: 'sender_id') this.senderId, @JsonKey(name: 'sender_role') this.senderRole, @JsonKey(name: 'sender_name') this.senderName, this.body, @JsonKey(name: 'is_read') this.isRead, @JsonKey(name: 'sent_at') this.sentAt});
  factory _MessageDto.fromJson(Map<String, dynamic> json) => _$MessageDtoFromJson(json);

@override final  String? id;
@override@JsonKey(name: 'conversation_id') final  String? conversationId;
@override@JsonKey(name: 'sender_id') final  String? senderId;
@override@JsonKey(name: 'sender_role') final  String? senderRole;
@override@JsonKey(name: 'sender_name') final  String? senderName;
@override final  String? body;
@override@JsonKey(name: 'is_read') final  bool? isRead;
@override@JsonKey(name: 'sent_at') final  dynamic sentAt;

/// Create a copy of MessageDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MessageDtoCopyWith<_MessageDto> get copyWith => __$MessageDtoCopyWithImpl<_MessageDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MessageDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MessageDto&&(identical(other.id, id) || other.id == id)&&(identical(other.conversationId, conversationId) || other.conversationId == conversationId)&&(identical(other.senderId, senderId) || other.senderId == senderId)&&(identical(other.senderRole, senderRole) || other.senderRole == senderRole)&&(identical(other.senderName, senderName) || other.senderName == senderName)&&(identical(other.body, body) || other.body == body)&&(identical(other.isRead, isRead) || other.isRead == isRead)&&const DeepCollectionEquality().equals(other.sentAt, sentAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,conversationId,senderId,senderRole,senderName,body,isRead,const DeepCollectionEquality().hash(sentAt));

@override
String toString() {
  return 'MessageDto(id: $id, conversationId: $conversationId, senderId: $senderId, senderRole: $senderRole, senderName: $senderName, body: $body, isRead: $isRead, sentAt: $sentAt)';
}


}

/// @nodoc
abstract mixin class _$MessageDtoCopyWith<$Res> implements $MessageDtoCopyWith<$Res> {
  factory _$MessageDtoCopyWith(_MessageDto value, $Res Function(_MessageDto) _then) = __$MessageDtoCopyWithImpl;
@override @useResult
$Res call({
 String? id,@JsonKey(name: 'conversation_id') String? conversationId,@JsonKey(name: 'sender_id') String? senderId,@JsonKey(name: 'sender_role') String? senderRole,@JsonKey(name: 'sender_name') String? senderName, String? body,@JsonKey(name: 'is_read') bool? isRead,@JsonKey(name: 'sent_at') dynamic sentAt
});




}
/// @nodoc
class __$MessageDtoCopyWithImpl<$Res>
    implements _$MessageDtoCopyWith<$Res> {
  __$MessageDtoCopyWithImpl(this._self, this._then);

  final _MessageDto _self;
  final $Res Function(_MessageDto) _then;

/// Create a copy of MessageDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = freezed,Object? conversationId = freezed,Object? senderId = freezed,Object? senderRole = freezed,Object? senderName = freezed,Object? body = freezed,Object? isRead = freezed,Object? sentAt = freezed,}) {
  return _then(_MessageDto(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,conversationId: freezed == conversationId ? _self.conversationId : conversationId // ignore: cast_nullable_to_non_nullable
as String?,senderId: freezed == senderId ? _self.senderId : senderId // ignore: cast_nullable_to_non_nullable
as String?,senderRole: freezed == senderRole ? _self.senderRole : senderRole // ignore: cast_nullable_to_non_nullable
as String?,senderName: freezed == senderName ? _self.senderName : senderName // ignore: cast_nullable_to_non_nullable
as String?,body: freezed == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String?,isRead: freezed == isRead ? _self.isRead : isRead // ignore: cast_nullable_to_non_nullable
as bool?,sentAt: freezed == sentAt ? _self.sentAt : sentAt // ignore: cast_nullable_to_non_nullable
as dynamic,
  ));
}


}

// dart format on
