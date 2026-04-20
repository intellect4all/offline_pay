// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'revoke_device_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$RevokeDeviceResponse extends RevokeDeviceResponse {
  @override
  final DateTime revokedAt;

  factory _$RevokeDeviceResponse(
          [void Function(RevokeDeviceResponseBuilder)? updates]) =>
      (RevokeDeviceResponseBuilder()..update(updates))._build();

  _$RevokeDeviceResponse._({required this.revokedAt}) : super._();
  @override
  RevokeDeviceResponse rebuild(
          void Function(RevokeDeviceResponseBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  RevokeDeviceResponseBuilder toBuilder() =>
      RevokeDeviceResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is RevokeDeviceResponse && revokedAt == other.revokedAt;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, revokedAt.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'RevokeDeviceResponse')
          ..add('revokedAt', revokedAt))
        .toString();
  }
}

class RevokeDeviceResponseBuilder
    implements Builder<RevokeDeviceResponse, RevokeDeviceResponseBuilder> {
  _$RevokeDeviceResponse? _$v;

  DateTime? _revokedAt;
  DateTime? get revokedAt => _$this._revokedAt;
  set revokedAt(DateTime? revokedAt) => _$this._revokedAt = revokedAt;

  RevokeDeviceResponseBuilder() {
    RevokeDeviceResponse._defaults(this);
  }

  RevokeDeviceResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _revokedAt = $v.revokedAt;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(RevokeDeviceResponse other) {
    _$v = other as _$RevokeDeviceResponse;
  }

  @override
  void update(void Function(RevokeDeviceResponseBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  RevokeDeviceResponse build() => _build();

  _$RevokeDeviceResponse _build() {
    final _$result = _$v ??
        _$RevokeDeviceResponse._(
          revokedAt: BuiltValueNullFieldError.checkNotNull(
              revokedAt, r'RevokeDeviceResponse', 'revokedAt'),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
