// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rotate_device_body.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$RotateDeviceBody extends RotateDeviceBody {
  @override
  final String oldDeviceId;
  @override
  final String newDevicePublicKey;
  @override
  final String platform;
  @override
  final String attestationBlob;
  @override
  final String appVersion;

  factory _$RotateDeviceBody(
          [void Function(RotateDeviceBodyBuilder)? updates]) =>
      (RotateDeviceBodyBuilder()..update(updates))._build();

  _$RotateDeviceBody._(
      {required this.oldDeviceId,
      required this.newDevicePublicKey,
      required this.platform,
      required this.attestationBlob,
      required this.appVersion})
      : super._();
  @override
  RotateDeviceBody rebuild(void Function(RotateDeviceBodyBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  RotateDeviceBodyBuilder toBuilder() =>
      RotateDeviceBodyBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is RotateDeviceBody &&
        oldDeviceId == other.oldDeviceId &&
        newDevicePublicKey == other.newDevicePublicKey &&
        platform == other.platform &&
        attestationBlob == other.attestationBlob &&
        appVersion == other.appVersion;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, oldDeviceId.hashCode);
    _$hash = $jc(_$hash, newDevicePublicKey.hashCode);
    _$hash = $jc(_$hash, platform.hashCode);
    _$hash = $jc(_$hash, attestationBlob.hashCode);
    _$hash = $jc(_$hash, appVersion.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'RotateDeviceBody')
          ..add('oldDeviceId', oldDeviceId)
          ..add('newDevicePublicKey', newDevicePublicKey)
          ..add('platform', platform)
          ..add('attestationBlob', attestationBlob)
          ..add('appVersion', appVersion))
        .toString();
  }
}

class RotateDeviceBodyBuilder
    implements Builder<RotateDeviceBody, RotateDeviceBodyBuilder> {
  _$RotateDeviceBody? _$v;

  String? _oldDeviceId;
  String? get oldDeviceId => _$this._oldDeviceId;
  set oldDeviceId(String? oldDeviceId) => _$this._oldDeviceId = oldDeviceId;

  String? _newDevicePublicKey;
  String? get newDevicePublicKey => _$this._newDevicePublicKey;
  set newDevicePublicKey(String? newDevicePublicKey) =>
      _$this._newDevicePublicKey = newDevicePublicKey;

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

  RotateDeviceBodyBuilder() {
    RotateDeviceBody._defaults(this);
  }

  RotateDeviceBodyBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _oldDeviceId = $v.oldDeviceId;
      _newDevicePublicKey = $v.newDevicePublicKey;
      _platform = $v.platform;
      _attestationBlob = $v.attestationBlob;
      _appVersion = $v.appVersion;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(RotateDeviceBody other) {
    _$v = other as _$RotateDeviceBody;
  }

  @override
  void update(void Function(RotateDeviceBodyBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  RotateDeviceBody build() => _build();

  _$RotateDeviceBody _build() {
    final _$result = _$v ??
        _$RotateDeviceBody._(
          oldDeviceId: BuiltValueNullFieldError.checkNotNull(
              oldDeviceId, r'RotateDeviceBody', 'oldDeviceId'),
          newDevicePublicKey: BuiltValueNullFieldError.checkNotNull(
              newDevicePublicKey, r'RotateDeviceBody', 'newDevicePublicKey'),
          platform: BuiltValueNullFieldError.checkNotNull(
              platform, r'RotateDeviceBody', 'platform'),
          attestationBlob: BuiltValueNullFieldError.checkNotNull(
              attestationBlob, r'RotateDeviceBody', 'attestationBlob'),
          appVersion: BuiltValueNullFieldError.checkNotNull(
              appVersion, r'RotateDeviceBody', 'appVersion'),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
