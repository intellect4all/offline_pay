// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'forgot_password_request_body.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$ForgotPasswordRequestBody extends ForgotPasswordRequestBody {
  @override
  final String email;

  factory _$ForgotPasswordRequestBody(
          [void Function(ForgotPasswordRequestBodyBuilder)? updates]) =>
      (ForgotPasswordRequestBodyBuilder()..update(updates))._build();

  _$ForgotPasswordRequestBody._({required this.email}) : super._();
  @override
  ForgotPasswordRequestBody rebuild(
          void Function(ForgotPasswordRequestBodyBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  ForgotPasswordRequestBodyBuilder toBuilder() =>
      ForgotPasswordRequestBodyBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is ForgotPasswordRequestBody && email == other.email;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, email.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'ForgotPasswordRequestBody')
          ..add('email', email))
        .toString();
  }
}

class ForgotPasswordRequestBodyBuilder
    implements
        Builder<ForgotPasswordRequestBody, ForgotPasswordRequestBodyBuilder> {
  _$ForgotPasswordRequestBody? _$v;

  String? _email;
  String? get email => _$this._email;
  set email(String? email) => _$this._email = email;

  ForgotPasswordRequestBodyBuilder() {
    ForgotPasswordRequestBody._defaults(this);
  }

  ForgotPasswordRequestBodyBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _email = $v.email;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(ForgotPasswordRequestBody other) {
    _$v = other as _$ForgotPasswordRequestBody;
  }

  @override
  void update(void Function(ForgotPasswordRequestBodyBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  ForgotPasswordRequestBody build() => _build();

  _$ForgotPasswordRequestBody _build() {
    final _$result = _$v ??
        _$ForgotPasswordRequestBody._(
          email: BuiltValueNullFieldError.checkNotNull(
              email, r'ForgotPasswordRequestBody', 'email'),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
