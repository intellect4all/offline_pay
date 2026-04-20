// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'forgot_password_reset_body.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$ForgotPasswordResetBody extends ForgotPasswordResetBody {
  @override
  final String email;
  @override
  final String code;
  @override
  final String newPassword;

  factory _$ForgotPasswordResetBody(
          [void Function(ForgotPasswordResetBodyBuilder)? updates]) =>
      (ForgotPasswordResetBodyBuilder()..update(updates))._build();

  _$ForgotPasswordResetBody._(
      {required this.email, required this.code, required this.newPassword})
      : super._();
  @override
  ForgotPasswordResetBody rebuild(
          void Function(ForgotPasswordResetBodyBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  ForgotPasswordResetBodyBuilder toBuilder() =>
      ForgotPasswordResetBodyBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is ForgotPasswordResetBody &&
        email == other.email &&
        code == other.code &&
        newPassword == other.newPassword;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, email.hashCode);
    _$hash = $jc(_$hash, code.hashCode);
    _$hash = $jc(_$hash, newPassword.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'ForgotPasswordResetBody')
          ..add('email', email)
          ..add('code', code)
          ..add('newPassword', newPassword))
        .toString();
  }
}

class ForgotPasswordResetBodyBuilder
    implements
        Builder<ForgotPasswordResetBody, ForgotPasswordResetBodyBuilder> {
  _$ForgotPasswordResetBody? _$v;

  String? _email;
  String? get email => _$this._email;
  set email(String? email) => _$this._email = email;

  String? _code;
  String? get code => _$this._code;
  set code(String? code) => _$this._code = code;

  String? _newPassword;
  String? get newPassword => _$this._newPassword;
  set newPassword(String? newPassword) => _$this._newPassword = newPassword;

  ForgotPasswordResetBodyBuilder() {
    ForgotPasswordResetBody._defaults(this);
  }

  ForgotPasswordResetBodyBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _email = $v.email;
      _code = $v.code;
      _newPassword = $v.newPassword;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(ForgotPasswordResetBody other) {
    _$v = other as _$ForgotPasswordResetBody;
  }

  @override
  void update(void Function(ForgotPasswordResetBodyBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  ForgotPasswordResetBody build() => _build();

  _$ForgotPasswordResetBody _build() {
    final _$result = _$v ??
        _$ForgotPasswordResetBody._(
          email: BuiltValueNullFieldError.checkNotNull(
              email, r'ForgotPasswordResetBody', 'email'),
          code: BuiltValueNullFieldError.checkNotNull(
              code, r'ForgotPasswordResetBody', 'code'),
          newPassword: BuiltValueNullFieldError.checkNotNull(
              newPassword, r'ForgotPasswordResetBody', 'newPassword'),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
