// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'deactivate_device_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$DeactivateDeviceResponse extends DeactivateDeviceResponse {
  @override
  final DateTime deactivatedAt;

  factory _$DeactivateDeviceResponse(
          [void Function(DeactivateDeviceResponseBuilder)? updates]) =>
      (DeactivateDeviceResponseBuilder()..update(updates))._build();

  _$DeactivateDeviceResponse._({required this.deactivatedAt}) : super._();
  @override
  DeactivateDeviceResponse rebuild(
          void Function(DeactivateDeviceResponseBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  DeactivateDeviceResponseBuilder toBuilder() =>
      DeactivateDeviceResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is DeactivateDeviceResponse &&
        deactivatedAt == other.deactivatedAt;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, deactivatedAt.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'DeactivateDeviceResponse')
          ..add('deactivatedAt', deactivatedAt))
        .toString();
  }
}

class DeactivateDeviceResponseBuilder
    implements
        Builder<DeactivateDeviceResponse, DeactivateDeviceResponseBuilder> {
  _$DeactivateDeviceResponse? _$v;

  DateTime? _deactivatedAt;
  DateTime? get deactivatedAt => _$this._deactivatedAt;
  set deactivatedAt(DateTime? deactivatedAt) =>
      _$this._deactivatedAt = deactivatedAt;

  DeactivateDeviceResponseBuilder() {
    DeactivateDeviceResponse._defaults(this);
  }

  DeactivateDeviceResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _deactivatedAt = $v.deactivatedAt;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(DeactivateDeviceResponse other) {
    _$v = other as _$DeactivateDeviceResponse;
  }

  @override
  void update(void Function(DeactivateDeviceResponseBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  DeactivateDeviceResponse build() => _build();

  _$DeactivateDeviceResponse _build() {
    final _$result = _$v ??
        _$DeactivateDeviceResponse._(
          deactivatedAt: BuiltValueNullFieldError.checkNotNull(
              deactivatedAt, r'DeactivateDeviceResponse', 'deactivatedAt'),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
