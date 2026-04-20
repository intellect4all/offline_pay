// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'revoke_device_body.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$RevokeDeviceBody extends RevokeDeviceBody {
  @override
  final String reason;

  factory _$RevokeDeviceBody(
          [void Function(RevokeDeviceBodyBuilder)? updates]) =>
      (RevokeDeviceBodyBuilder()..update(updates))._build();

  _$RevokeDeviceBody._({required this.reason}) : super._();
  @override
  RevokeDeviceBody rebuild(void Function(RevokeDeviceBodyBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  RevokeDeviceBodyBuilder toBuilder() =>
      RevokeDeviceBodyBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is RevokeDeviceBody && reason == other.reason;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, reason.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'RevokeDeviceBody')
          ..add('reason', reason))
        .toString();
  }
}

class RevokeDeviceBodyBuilder
    implements Builder<RevokeDeviceBody, RevokeDeviceBodyBuilder> {
  _$RevokeDeviceBody? _$v;

  String? _reason;
  String? get reason => _$this._reason;
  set reason(String? reason) => _$this._reason = reason;

  RevokeDeviceBodyBuilder() {
    RevokeDeviceBody._defaults(this);
  }

  RevokeDeviceBodyBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _reason = $v.reason;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(RevokeDeviceBody other) {
    _$v = other as _$RevokeDeviceBody;
  }

  @override
  void update(void Function(RevokeDeviceBodyBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  RevokeDeviceBody build() => _build();

  _$RevokeDeviceBody _build() {
    final _$result = _$v ??
        _$RevokeDeviceBody._(
          reason: BuiltValueNullFieldError.checkNotNull(
              reason, r'RevokeDeviceBody', 'reason'),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
