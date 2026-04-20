// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'register_device_body.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$RegisterDeviceBody extends RegisterDeviceBody {
  @override
  final String devicePublicKey;
  @override
  final String platform;
  @override
  final String attestationBlob;
  @override
  final String appVersion;
  @override
  final String attestationNonce;

  factory _$RegisterDeviceBody(
          [void Function(RegisterDeviceBodyBuilder)? updates]) =>
      (RegisterDeviceBodyBuilder()..update(updates))._build();

  _$RegisterDeviceBody._(
      {required this.devicePublicKey,
      required this.platform,
      required this.attestationBlob,
      required this.appVersion,
      required this.attestationNonce})
      : super._();
  @override
  RegisterDeviceBody rebuild(
          void Function(RegisterDeviceBodyBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  RegisterDeviceBodyBuilder toBuilder() =>
      RegisterDeviceBodyBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is RegisterDeviceBody &&
        devicePublicKey == other.devicePublicKey &&
        platform == other.platform &&
        attestationBlob == other.attestationBlob &&
        appVersion == other.appVersion &&
        attestationNonce == other.attestationNonce;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, devicePublicKey.hashCode);
    _$hash = $jc(_$hash, platform.hashCode);
    _$hash = $jc(_$hash, attestationBlob.hashCode);
    _$hash = $jc(_$hash, appVersion.hashCode);
    _$hash = $jc(_$hash, attestationNonce.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'RegisterDeviceBody')
          ..add('devicePublicKey', devicePublicKey)
          ..add('platform', platform)
          ..add('attestationBlob', attestationBlob)
          ..add('appVersion', appVersion)
          ..add('attestationNonce', attestationNonce))
        .toString();
  }
}

class RegisterDeviceBodyBuilder
    implements Builder<RegisterDeviceBody, RegisterDeviceBodyBuilder> {
  _$RegisterDeviceBody? _$v;

  String? _devicePublicKey;
  String? get devicePublicKey => _$this._devicePublicKey;
  set devicePublicKey(String? devicePublicKey) =>
      _$this._devicePublicKey = devicePublicKey;

  String? _platform;
  String? get platform => _$this._platform;
  set platform(String? platform) => _$this._platform = platform;

  String? _attestationBlob;
  String? get attestationBlob => _$this._attestationBlob;
  set attestationBlob(String? attestationBlob) =>
      _$this._attestationBlob = attestationBlob;

  String? _appVersion;
  String? get appVersion => _$this._appVersion;
  set appVersion(String? appVersion) => _$this._appVersion = appVersion;

  String? _attestationNonce;
  String? get attestationNonce => _$this._attestationNonce;
  set attestationNonce(String? attestationNonce) =>
      _$this._attestationNonce = attestationNonce;

  RegisterDeviceBodyBuilder() {
    RegisterDeviceBody._defaults(this);
  }

  RegisterDeviceBodyBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _devicePublicKey = $v.devicePublicKey;
      _platform = $v.platform;
      _attestationBlob = $v.attestationBlob;
      _appVersion = $v.appVersion;
      _attestationNonce = $v.attestationNonce;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(RegisterDeviceBody other) {
    _$v = other as _$RegisterDeviceBody;
  }

  @override
  void update(void Function(RegisterDeviceBodyBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  RegisterDeviceBody build() => _build();

  _$RegisterDeviceBody _build() {
    final _$result = _$v ??
        _$RegisterDeviceBody._(
          devicePublicKey: BuiltValueNullFieldError.checkNotNull(
              devicePublicKey, r'RegisterDeviceBody', 'devicePublicKey'),
          platform: BuiltValueNullFieldError.checkNotNull(
              platform, r'RegisterDeviceBody', 'platform'),
          attestationBlob: BuiltValueNullFieldError.checkNotNull(
              attestationBlob, r'RegisterDeviceBody', 'attestationBlob'),
          appVersion: BuiltValueNullFieldError.checkNotNull(
              appVersion, r'RegisterDeviceBody', 'appVersion'),
          attestationNonce: BuiltValueNullFieldError.checkNotNull(
              attestationNonce, r'RegisterDeviceBody', 'attestationNonce'),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
