// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rotate_device_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$RotateDeviceResponse extends RotateDeviceResponse {
  @override
  final String newDeviceId;
  @override
  final String deviceJwt;
  @override
  final DateTime rotatedAt;
  @override
  final int realmKeyVersion;

  factory _$RotateDeviceResponse(
          [void Function(RotateDeviceResponseBuilder)? updates]) =>
      (RotateDeviceResponseBuilder()..update(updates))._build();

  _$RotateDeviceResponse._(
      {required this.newDeviceId,
      required this.deviceJwt,
      required this.rotatedAt,
      required this.realmKeyVersion})
      : super._();
  @override
  RotateDeviceResponse rebuild(
          void Function(RotateDeviceResponseBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  RotateDeviceResponseBuilder toBuilder() =>
      RotateDeviceResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is RotateDeviceResponse &&
        newDeviceId == other.newDeviceId &&
        deviceJwt == other.deviceJwt &&
        rotatedAt == other.rotatedAt &&
        realmKeyVersion == other.realmKeyVersion;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, newDeviceId.hashCode);
    _$hash = $jc(_$hash, deviceJwt.hashCode);
    _$hash = $jc(_$hash, rotatedAt.hashCode);
    _$hash = $jc(_$hash, realmKeyVersion.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'RotateDeviceResponse')
          ..add('newDeviceId', newDeviceId)
          ..add('deviceJwt', deviceJwt)
          ..add('rotatedAt', rotatedAt)
          ..add('realmKeyVersion', realmKeyVersion))
        .toString();
  }
}

class RotateDeviceResponseBuilder
    implements Builder<RotateDeviceResponse, RotateDeviceResponseBuilder> {
  _$RotateDeviceResponse? _$v;

  String? _newDeviceId;
  String? get newDeviceId => _$this._newDeviceId;
  set newDeviceId(String? newDeviceId) => _$this._newDeviceId = newDeviceId;

  String? _deviceJwt;
  String? get deviceJwt => _$this._deviceJwt;
  set deviceJwt(String? deviceJwt) => _$this._deviceJwt = deviceJwt;

  DateTime? _rotatedAt;
  DateTime? get rotatedAt => _$this._rotatedAt;
  set rotatedAt(DateTime? rotatedAt) => _$this._rotatedAt = rotatedAt;

  int? _realmKeyVersion;
  int? get realmKeyVersion => _$this._realmKeyVersion;
  set realmKeyVersion(int? realmKeyVersion) =>
      _$this._realmKeyVersion = realmKeyVersion;

  RotateDeviceResponseBuilder() {
    RotateDeviceResponse._defaults(this);
  }

  RotateDeviceResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _newDeviceId = $v.newDeviceId;
      _deviceJwt = $v.deviceJwt;
      _rotatedAt = $v.rotatedAt;
      _realmKeyVersion = $v.realmKeyVersion;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(RotateDeviceResponse other) {
    _$v = other as _$RotateDeviceResponse;
  }

  @override
  void update(void Function(RotateDeviceResponseBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  RotateDeviceResponse build() => _build();

  _$RotateDeviceResponse _build() {
    final _$result = _$v ??
        _$RotateDeviceResponse._(
          newDeviceId: BuiltValueNullFieldError.checkNotNull(
              newDeviceId, r'RotateDeviceResponse', 'newDeviceId'),
          deviceJwt: BuiltValueNullFieldError.checkNotNull(
              deviceJwt, r'RotateDeviceResponse', 'deviceJwt'),
          rotatedAt: BuiltValueNullFieldError.checkNotNull(
              rotatedAt, r'RotateDeviceResponse', 'rotatedAt'),
          realmKeyVersion: BuiltValueNullFieldError.checkNotNull(
              realmKeyVersion, r'RotateDeviceResponse', 'realmKeyVersion'),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
