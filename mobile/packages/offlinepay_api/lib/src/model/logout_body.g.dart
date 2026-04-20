// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'logout_body.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$LogoutBody extends LogoutBody {
  @override
  final String refreshToken;

  factory _$LogoutBody([void Function(LogoutBodyBuilder)? updates]) =>
      (LogoutBodyBuilder()..update(updates))._build();

  _$LogoutBody._({required this.refreshToken}) : super._();
  @override
  LogoutBody rebuild(void Function(LogoutBodyBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  LogoutBodyBuilder toBuilder() => LogoutBodyBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is LogoutBody && refreshToken == other.refreshToken;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, refreshToken.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'LogoutBody')
          ..add('refreshToken', refreshToken))
        .toString();
  }
}

class LogoutBodyBuilder implements Builder<LogoutBody, LogoutBodyBuilder> {
  _$LogoutBody? _$v;

  String? _refreshToken;
  String? get refreshToken => _$this._refreshToken;
  set refreshToken(String? refreshToken) => _$this._refreshToken = refreshToken;

  LogoutBodyBuilder() {
    LogoutBody._defaults(this);
  }

  LogoutBodyBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _refreshToken = $v.refreshToken;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(LogoutBody other) {
    _$v = other as _$LogoutBody;
  }

  @override
  void update(void Function(LogoutBodyBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  LogoutBody build() => _build();

  _$LogoutBody _build() {
    final _$result = _$v ??
        _$LogoutBody._(
          refreshToken: BuiltValueNullFieldError.checkNotNull(
              refreshToken, r'LogoutBody', 'refreshToken'),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
