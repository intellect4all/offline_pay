// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'push_token_delete_body.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$PushTokenDeleteBody extends PushTokenDeleteBody {
  @override
  final String fcmToken;

  factory _$PushTokenDeleteBody(
          [void Function(PushTokenDeleteBodyBuilder)? updates]) =>
      (PushTokenDeleteBodyBuilder()..update(updates))._build();

  _$PushTokenDeleteBody._({required this.fcmToken}) : super._();
  @override
  PushTokenDeleteBody rebuild(
          void Function(PushTokenDeleteBodyBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  PushTokenDeleteBodyBuilder toBuilder() =>
      PushTokenDeleteBodyBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is PushTokenDeleteBody && fcmToken == other.fcmToken;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, fcmToken.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'PushTokenDeleteBody')
          ..add('fcmToken', fcmToken))
        .toString();
  }
}

class PushTokenDeleteBodyBuilder
    implements Builder<PushTokenDeleteBody, PushTokenDeleteBodyBuilder> {
  _$PushTokenDeleteBody? _$v;

  String? _fcmToken;
  String? get fcmToken => _$this._fcmToken;
  set fcmToken(String? fcmToken) => _$this._fcmToken = fcmToken;

  PushTokenDeleteBodyBuilder() {
    PushTokenDeleteBody._defaults(this);
  }

  PushTokenDeleteBodyBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _fcmToken = $v.fcmToken;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(PushTokenDeleteBody other) {
    _$v = other as _$PushTokenDeleteBody;
  }

  @override
  void update(void Function(PushTokenDeleteBodyBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  PushTokenDeleteBody build() => _build();

  _$PushTokenDeleteBody _build() {
    final _$result = _$v ??
        _$PushTokenDeleteBody._(
          fcmToken: BuiltValueNullFieldError.checkNotNull(
              fcmToken, r'PushTokenDeleteBody', 'fcmToken'),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
