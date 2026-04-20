// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recover_device_body.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$RecoverDeviceBody extends RecoverDeviceBody {
  @override
  final String userId;
  @override
  final String recoveryProof;
  @override
  final String newDevicePublicKey;
  @override
  final String platform;
  @override
  final String attestationBlob;
  @override
  final String appVersion;

  factory _$RecoverDeviceBody(
          [void Function(RecoverDeviceBodyBuilder)? updates]) =>
      (RecoverDeviceBodyBuilder()..update(updates))._build();

  _$RecoverDeviceBody._(
      {required this.userId,
      required this.recoveryProof,
      required this.newDevicePublicKey,
      required this.platform,
      required this.attestationBlob,
      required this.appVersion})
      : super._();
  @override
  RecoverDeviceBody rebuild(void Function(RecoverDeviceBodyBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  RecoverDeviceBodyBuilder toBuilder() =>
      RecoverDeviceBodyBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is RecoverDeviceBody &&
        userId == other.userId &&
        recoveryProof == other.recoveryProof &&
        newDevicePublicKey == other.newDevicePublicKey &&
        platform == other.platform &&
        attestationBlob == other.attestationBlob &&
        appVersion == other.appVersion;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, userId.hashCode);
    _$hash = $jc(_$hash, recoveryProof.hashCode);
    _$hash = $jc(_$hash, newDevicePublicKey.hashCode);
    _$hash = $jc(_$hash, platform.hashCode);
    _$hash = $jc(_$hash, attestationBlob.hashCode);
    _$hash = $jc(_$hash, appVersion.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'RecoverDeviceBody')
          ..add('userId', userId)
          ..add('recoveryProof', recoveryProof)
          ..add('newDevicePublicKey', newDevicePublicKey)
          ..add('platform', platform)
          ..add('attestationBlob', attestationBlob)
          ..add('appVersion', appVersion))
        .toString();
  }
}

class RecoverDeviceBodyBuilder
    implements Builder<RecoverDeviceBody, RecoverDeviceBodyBuilder> {
  _$RecoverDeviceBody? _$v;

  String? _userId;
  String? get userId => _$this._userId;
  set userId(String? userId) => _$this._userId = userId;

  String? _recoveryProof;
  String? get recoveryProof => _$this._recoveryProof;
  set recoveryProof(String? recoveryProof) =>
      _$this._recoveryProof = recoveryProof;

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

  RecoverDeviceBodyBuilder() {
    RecoverDeviceBody._defaults(this);
  }

  RecoverDeviceBodyBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _userId = $v.userId;
      _recoveryProof = $v.recoveryProof;
      _newDevicePublicKey = $v.newDevicePublicKey;
      _platform = $v.platform;
      _attestationBlob = $v.attestationBlob;
      _appVersion = $v.appVersion;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(RecoverDeviceBody other) {
    _$v = other as _$RecoverDeviceBody;
  }

  @override
  void update(void Function(RecoverDeviceBodyBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  RecoverDeviceBody build() => _build();

  _$RecoverDeviceBody _build() {
    final _$result = _$v ??
        _$RecoverDeviceBody._(
          userId: BuiltValueNullFieldError.checkNotNull(
              userId, r'RecoverDeviceBody', 'userId'),
          recoveryProof: BuiltValueNullFieldError.checkNotNull(
              recoveryProof, r'RecoverDeviceBody', 'recoveryProof'),
          newDevicePublicKey: BuiltValueNullFieldError.checkNotNull(
              newDevicePublicKey, r'RecoverDeviceBody', 'newDevicePublicKey'),
          platform: BuiltValueNullFieldError.checkNotNull(
              platform, r'RecoverDeviceBody', 'platform'),
          attestationBlob: BuiltValueNullFieldError.checkNotNull(
              attestationBlob, r'RecoverDeviceBody', 'attestationBlob'),
          appVersion: BuiltValueNullFieldError.checkNotNull(
              appVersion, r'RecoverDeviceBody', 'appVersion'),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
