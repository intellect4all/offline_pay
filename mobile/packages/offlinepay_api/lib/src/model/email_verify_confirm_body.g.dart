// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'email_verify_confirm_body.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$EmailVerifyConfirmBody extends EmailVerifyConfirmBody {
  @override
  final String code;

  factory _$EmailVerifyConfirmBody(
          [void Function(EmailVerifyConfirmBodyBuilder)? updates]) =>
      (EmailVerifyConfirmBodyBuilder()..update(updates))._build();

  _$EmailVerifyConfirmBody._({required this.code}) : super._();
  @override
  EmailVerifyConfirmBody rebuild(
          void Function(EmailVerifyConfirmBodyBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  EmailVerifyConfirmBodyBuilder toBuilder() =>
      EmailVerifyConfirmBodyBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is EmailVerifyConfirmBody && code == other.code;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, code.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'EmailVerifyConfirmBody')
          ..add('code', code))
        .toString();
  }
}

class EmailVerifyConfirmBodyBuilder
    implements Builder<EmailVerifyConfirmBody, EmailVerifyConfirmBodyBuilder> {
  _$EmailVerifyConfirmBody? _$v;

  String? _code;
  String? get code => _$this._code;
  set code(String? code) => _$this._code = code;

  EmailVerifyConfirmBodyBuilder() {
    EmailVerifyConfirmBody._defaults(this);
  }

  EmailVerifyConfirmBodyBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _code = $v.code;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(EmailVerifyConfirmBody other) {
    _$v = other as _$EmailVerifyConfirmBody;
  }

  @override
  void update(void Function(EmailVerifyConfirmBodyBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  EmailVerifyConfirmBody build() => _build();

  _$EmailVerifyConfirmBody _build() {
    final _$result = _$v ??
        _$EmailVerifyConfirmBody._(
          code: BuiltValueNullFieldError.checkNotNull(
              code, r'EmailVerifyConfirmBody', 'code'),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
