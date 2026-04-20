// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_session_public_key.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$DeviceSessionPublicKey extends DeviceSessionPublicKey {
  @override
  final String keyId;
  @override
  final String publicKey;
  @override
  final DateTime activeFrom;
  @override
  final DateTime? retiredAt;

  factory _$DeviceSessionPublicKey(
          [void Function(DeviceSessionPublicKeyBuilder)? updates]) =>
      (DeviceSessionPublicKeyBuilder()..update(updates))._build();

  _$DeviceSessionPublicKey._(
      {required this.keyId,
      required this.publicKey,
      required this.activeFrom,
      this.retiredAt})
      : super._();
  @override
  DeviceSessionPublicKey rebuild(
          void Function(DeviceSessionPublicKeyBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  DeviceSessionPublicKeyBuilder toBuilder() =>
      DeviceSessionPublicKeyBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is DeviceSessionPublicKey &&
        keyId == other.keyId &&
        publicKey == other.publicKey &&
        activeFrom == other.activeFrom &&
        retiredAt == other.retiredAt;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, keyId.hashCode);
    _$hash = $jc(_$hash, publicKey.hashCode);
    _$hash = $jc(_$hash, activeFrom.hashCode);
    _$hash = $jc(_$hash, retiredAt.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'DeviceSessionPublicKey')
          ..add('keyId', keyId)
          ..add('publicKey', publicKey)
          ..add('activeFrom', activeFrom)
          ..add('retiredAt', retiredAt))
        .toString();
  }
}

class DeviceSessionPublicKeyBuilder
    implements Builder<DeviceSessionPublicKey, DeviceSessionPublicKeyBuilder> {
  _$DeviceSessionPublicKey? _$v;

  String? _keyId;
  String? get keyId => _$this._keyId;
  set keyId(String? keyId) => _$this._keyId = keyId;

  String? _publicKey;
  String? get publicKey => _$this._publicKey;
  set publicKey(String? publicKey) => _$this._publicKey = publicKey;

  DateTime? _activeFrom;
  DateTime? get activeFrom => _$this._activeFrom;
  set activeFrom(DateTime? activeFrom) => _$this._activeFrom = activeFrom;

  DateTime? _retiredAt;
  DateTime? get retiredAt => _$this._retiredAt;
  set retiredAt(DateTime? retiredAt) => _$this._retiredAt = retiredAt;

  DeviceSessionPublicKeyBuilder() {
    DeviceSessionPublicKey._defaults(this);
  }

  DeviceSessionPublicKeyBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _keyId = $v.keyId;
      _publicKey = $v.publicKey;
      _activeFrom = $v.activeFrom;
      _retiredAt = $v.retiredAt;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(DeviceSessionPublicKey other) {
    _$v = other as _$DeviceSessionPublicKey;
  }

  @override
  void update(void Function(DeviceSessionPublicKeyBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  DeviceSessionPublicKey build() => _build();

  _$DeviceSessionPublicKey _build() {
    final _$result = _$v ??
        _$DeviceSessionPublicKey._(
          keyId: BuiltValueNullFieldError.checkNotNull(
              keyId, r'DeviceSessionPublicKey', 'keyId'),
          publicKey: BuiltValueNullFieldError.checkNotNull(
              publicKey, r'DeviceSessionPublicKey', 'publicKey'),
          activeFrom: BuiltValueNullFieldError.checkNotNull(
              activeFrom, r'DeviceSessionPublicKey', 'activeFrom'),
          retiredAt: retiredAt,
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
