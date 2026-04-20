// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'register_device_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$RegisterDeviceResponse extends RegisterDeviceResponse {
  @override
  final String deviceId;
  @override
  final String deviceJwt;
  @override
  final DateTime registeredAt;
  @override
  final int realmKeyVersion;

  factory _$RegisterDeviceResponse(
          [void Function(RegisterDeviceResponseBuilder)? updates]) =>
      (RegisterDeviceResponseBuilder()..update(updates))._build();

  _$RegisterDeviceResponse._(
      {required this.deviceId,
      required this.deviceJwt,
      required this.registeredAt,
      required this.realmKeyVersion})
      : super._();
  @override
  RegisterDeviceResponse rebuild(
          void Function(RegisterDeviceResponseBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  RegisterDeviceResponseBuilder toBuilder() =>
      RegisterDeviceResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is RegisterDeviceResponse &&
        deviceId == other.deviceId &&
        deviceJwt == other.deviceJwt &&
        registeredAt == other.registeredAt &&
        realmKeyVersion == other.realmKeyVersion;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, deviceId.hashCode);
    _$hash = $jc(_$hash, deviceJwt.hashCode);
    _$hash = $jc(_$hash, registeredAt.hashCode);
    _$hash = $jc(_$hash, realmKeyVersion.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'RegisterDeviceResponse')
          ..add('deviceId', deviceId)
          ..add('deviceJwt', deviceJwt)
          ..add('registeredAt', registeredAt)
          ..add('realmKeyVersion', realmKeyVersion))
        .toString();
  }
}

class RegisterDeviceResponseBuilder
    implements Builder<RegisterDeviceResponse, RegisterDeviceResponseBuilder> {
  _$RegisterDeviceResponse? _$v;

  String? _deviceId;
  String? get deviceId => _$this._deviceId;
  set deviceId(String? deviceId) => _$this._deviceId = deviceId;

  String? _deviceJwt;
  String? get deviceJwt => _$this._deviceJwt;
  set deviceJwt(String? deviceJwt) => _$this._deviceJwt = deviceJwt;

  DateTime? _registeredAt;
  DateTime? get registeredAt => _$this._registeredAt;
  set registeredAt(DateTime? registeredAt) =>
      _$this._registeredAt = registeredAt;

  int? _realmKeyVersion;
  int? get realmKeyVersion => _$this._realmKeyVersion;
  set realmKeyVersion(int? realmKeyVersion) =>
      _$this._realmKeyVersion = realmKeyVersion;

  RegisterDeviceResponseBuilder() {
    RegisterDeviceResponse._defaults(this);
  }

  RegisterDeviceResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _deviceId = $v.deviceId;
      _deviceJwt = $v.deviceJwt;
      _registeredAt = $v.registeredAt;
      _realmKeyVersion = $v.realmKeyVersion;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(RegisterDeviceResponse other) {
    _$v = other as _$RegisterDeviceResponse;
  }

  @override
  void update(void Function(RegisterDeviceResponseBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  RegisterDeviceResponse build() => _build();

  _$RegisterDeviceResponse _build() {
    final _$result = _$v ??
        _$RegisterDeviceResponse._(
          deviceId: BuiltValueNullFieldError.checkNotNull(
              deviceId, r'RegisterDeviceResponse', 'deviceId'),
          deviceJwt: BuiltValueNullFieldError.checkNotNull(
              deviceJwt, r'RegisterDeviceResponse', 'deviceJwt'),
          registeredAt: BuiltValueNullFieldError.checkNotNull(
              registeredAt, r'RegisterDeviceResponse', 'registeredAt'),
          realmKeyVersion: BuiltValueNullFieldError.checkNotNull(
              realmKeyVersion, r'RegisterDeviceResponse', 'realmKeyVersion'),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
